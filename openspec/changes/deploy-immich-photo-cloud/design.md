## Context

The stack already provisions identity, network, compute, load balancer, and state backend per environment (`dev.tfvars` / `staging.tfvars` / `prod.tfvars`). Compute instances land in private subnets; the public LB fronts them through a single flattened backend set on one port. The compute module hardcodes an `VM.Standard.E4.Flex` image filter for its default image lookup and has no block volume support. See `proposal.md` for motivation.

Constraints that shape the design:
- Prod-only rollout (user decision); dev/staging must stay byte-for-byte unchanged.
- Ampere A1.Flex is arm64 — x86 image OCIDs fail at launch.
- Immich serves on port 2283; existing app-server backends use 8080 — one shared `backend_port` cannot serve both.
- The official install script downloads `docker-compose.yml` + `.env` into `./immich-app` relative to CWD and requires Docker preinstalled.

## Goals / Non-Goals

**Goals:**
- One dedicated Immich server in prod: A1.Flex 4 OCPU / 24 GB, private subnet, 200 GB data volume.
- Repeatable app onboarding via a repo-level `apps/<name>/` convention.
- First-boot automation: Docker install → official Immich install script → library on the mounted volume.
- Public access through the existing public LB with a dedicated route; machine URL emitted as Terraform output.

**Non-Goals:**
- TLS/HTTPS, custom domains, or reverse-proxy setup (future change).
- Automated backups/monitoring/alerting (a backup-policy hook variable is provided, disabled by default).
- Multi-instance HA or auto-scaling for Immich.
- Deploying Immich to dev/staging.
- Changes to ATP/database resources.

## Decisions

### D1: Dedicated single-purpose instance per app
Each app gets its own instance pool entry rather than co-locating containers on the shared `app-server`. Rationale: blast-radius isolation, independent shape/sizing (arm64 free tier vs paid E4), simpler lifecycle. Alternative rejected: adding Immich to the existing pool — would force x86 sizing on all apps and mix stateful photo data with generic app servers.

### D2: Shape-keyed config under a gated `immich` map, not new top-level vars
Introduce one object variable (e.g., `var.apps_immich`) holding `enabled`, `shape`/`ocpus`/`memory`, `data_volume_size_gb = 200`, `library_mount = "/srv/apps/immich"`, `install_dir`. Default `enabled = false`; only `prod.tfvars` enables it. This keeps dev/staging tfvars untouched and gives future apps a copyable pattern. Alternative rejected: separate flat variables — clutters root variables and invites cross-env drift.

### D3: Architecture-aware image selection in `modules/compute`
Replace the hardcoded `shape = "VM.Standard.E4.Flex"` filter in the module's image data source with a per-pool lookup keyed by the pool's shape (A1 → Oracle Linux aarch64; E4 → x86_64). Explicit `instance_images[pool]` entries still win. Rationale: prevents launching x86 images on arm64 shapes — today's failure mode for any A1 pool. Alternative rejected: pinning an aarch64 image OCID in tfvars only — brittle across regions and image rotations, and leaves the trap for the next user.

### D4: Block volume attach + cloud-init format/mount
Add to `modules/compute`: optional `data_volumes` map (per pool: `size_in_gbs`, attachment type paravirtualized). Cloud-init (from `apps/immich/cloud-init.yml.tftpl`) formats the volume once (guard against re-formatting by checking for an existing filesystem) and mounts it at `/srv/apps/immich` via `/etc/fstab` with `nofail`. Volume gets `preserve = true` semantics by living outside the instance's delete-on-termination boot volume. Alternatives considered: expanding boot volume instead — mixes OS and irreplaceable photos, complicates replacement; OCI File Storage — costs more than block storage for a single-node workload.

### D5: Install script honored, assets vendored for reproducibility
Cloud-init installs Docker (Oracle Linux docker-ce repo), then runs `curl -o- https://raw.githubusercontent.com/immich-app/immich/main/install.sh | bash` from `/srv/apps/immich/app` so `docker-compose.yml`/`.env` land there. We additionally commit pinned copies of `docker-compose.yml` and `example.env` as `.env.example` under `apps/immich/` (with `UPLOAD_LOCATION=/srv/apps/immich/library`, `IMMICH_VERSION=release` documented) so operators can review/pin versions; a `immich_version` variable lets users pin a release tag in the env template. Rationale: user explicitly requested the script flow; vendoring mitigates its experimental/unpinned nature. Alternative rejected: hand-authoring compose from scratch — diverges from the requested upstream flow.

### D6: Generic "additional service routes" in `modules/load-balancer`
Add optional map var `additional_routes` (`name → { listener_port, protocol, backend_port, health_check_protocol/port/path }`), each creating one backend set + listener; backends sourced from a parallel `route_backends` map of private IPs. Root wiring feeds the immich instance IP with port 2283 and health path `/api/server/ping` (Immich's canonical ping endpoint returning HTTP 200). Existing default backend set/listeners untouched. Alternative rejected: hardcoding an "immich backend set" inside the module — leaks app knowledge into infra plumbing; swapping the public LB for direct public IP — contradicts the chosen exposure model.

### D7: NSG rule scoped to LB subnets
One ingress rule appended to prod's `nsg_rules`: source = public subnet CIDRs (10.20.1.0/24, 10.20.2.0/24, 10.20.3.0/24), destination = app NSG, TCP 2283. SSH continues to follow existing rules; instance keeps `assign_public_ip = false`.

### D8: Outputs carry the URL
Root outputs: `immich_url = "http://${oci public_lb_ips[0]}:2283"`, `immich_instance_private_ip`, `immich_data_volume_ocid`. Gated with conditional expression so non-prod applies output nothing.

## Risks / Trade-offs

- [Immich marks the script method experimental] → Vendored compose/env templates in `apps/immich/` make drift reviewable; version-pinning variable documented; README notes the Compose-recommended alternative.
- [First-boot script failure is invisible until someone checks] → Health check keeps the backend out of rotation if Immich never comes up; README documents `ssh + docker logs` triage; cloud-init logs persisted to `/var/log/cloud-init-output.log`.
- [LB health check flaps while containers start (~1 min)] → Generous interval/retries on the immich route (e.g., 30 s × 3) so late-starting ML container doesn't drain the backend permanently.
- [x86-on-arm64 launch failures regress later] → D3 makes architecture matching default behavior, covered by plan-time data source rather than runtime failure.
- [200 GB fills up] → Block volumes expand online without detach; growth alerting explicitly out of scope (Non-Goals).
- [Photo data loss] → Volume survives instance replacement (D4); optional OCI backup-policy hook variable provided but off by default — operator decides.
- [HTTP-only exposure] → Acceptable for initial rollout on a non-default port; TLS deferred to a follow-up change (Non-Goals).

## Migration Plan

1. Merge module extensions first (compute image/volume, LB routes) — additive, no behavior change for existing pools/routes since everything is gated behind empty defaults.
2. Add `apps/immich/` assets and root wiring; enable only in `prod.tfvars`.
3. `terraform plan -var-file=prod.tfvars` → expect exactly: 1 instance, 1 block volume + attachment, 1 backend set, 1 listener, 1 NSG rule, outputs.
4. Apply; verify `terraform output immich_url` responds with the Immich onboarding page; complete first-run admin signup immediately (port 2283 is internet-facing via the LB).
5. Rollback: set `enabled = false` (or targeted destroy of immich-scoped resources) and apply; the data volume uses `preserve_on_delete` semantics so photos survive accidental teardown.

## Open Questions

- Whether to enable the optional backup policy for the 200 GB volume at rollout time (default off; operator call during apply).
