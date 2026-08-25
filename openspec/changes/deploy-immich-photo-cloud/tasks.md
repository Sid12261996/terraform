## 1. Module extensions (additive, gated by empty defaults)

- [x] 1.1 In `modules/compute`, replace the hardcoded `shape = "VM.Standard.E4.Flex"` image data source with a per-pool architecture-aware lookup (A1 → Oracle Linux aarch64, E4 → x86_64); explicit `instance_images[pool]` still takes precedence. Verify with `terraform validate` and a plan for an existing env showing no image changes to current pools.
- [x] 1.2 In `modules/compute`, add an optional per-pool `data_volumes` map (`size_in_gbs`) creating `oci_core_volume` + paravirtualized `oci_core_volume_attachment` with preservation on instance replacement; no volume when unset. Verify: `terraform validate` + plan shows zero resources when map is absent.
- [x] 1.3 In `modules/load-balancer`, add optional `additional_routes` / `route_backends` maps creating one backend set + HTTP listener per named route with its own health check (protocol/port/url_path); confirm default backend set/listeners untouched in plan output.
- [x] 1.4 Run `terraform fmt -recursive && terraform validate` and a dev-env plan; verify plan reports no changes to existing dev resources.

## 2. App assets — new repo folder convention

- [x] 2.1 Create `apps/immich/cloud-init.yml.tftpl`: Docker install (docker-ce on Oracle Linux), one-time format/mount of the block volume at `/srv/apps/immich` via fstab `nofail`, then run the official Immich install script (`curl -o- https://raw.githubusercontent.com/immich-app/immich/main/install.sh | bash`) from `/srv/apps/immich/app`. Verify template renders valid YAML and idempotence guard prevents re-formatting.
- [x] 2.2 Create `apps/immich/.env.example` with pinned copies of upstream defaults plus documented overrides: `UPLOAD_LOCATION=/srv/apps/immich/library`, `IMMICH_VERSION` pin guidance. Verify keys match the vendored docker-compose.yml.
- [x] 2.3 Vendor pinned upstream `docker-compose.yml` into `apps/immich/` for review/diffing against what the script downloads. Verify it matches the release referenced in `.env.example`.
- [x] 2.4 Write `apps/immich/README.md`: purpose, first-boot behavior, data locations (`/srv/apps/immich/library`), SSH/docker-log triage, expansion procedure for the volume, note that Immich flags script installs experimental. Verify instructions match cloud-init template.

## 3. Root wiring

- [x] 3.1 Add `var.apps_immich` object variable (`enabled=false`, shape/ocpus/memory, `data_volume_size_gb=200`, mount/install paths) in `variables.tf`; wire immich pool entry, data volume, and user-data render in `main.tf`. Verify `terraform validate`.
- [x] 3.2 Add NSG rule allowing public-subnet CIDRs → app NSG on TCP 2283 only when enabled; keep instance private (`assign_public_ip=false`). Verify prod plan contains exactly this rule.
- [x] 3.3 Wire LB route `immich`: listener 2283 → backends (immich private IP :2283), health check HTTP `/api/server/ping`, interval 30s × 3 retries. Verify plan adds backend set + listener without touching default ones.
- [x] 3.4 Add gated outputs in `outputs.tf`: `immich_url` (`http://<public_lb_ip>:2283`), `immich_instance_private_ip`, `immich_data_volume_ocid`; null when disabled. Verify `terraform validate` and that dev plan renders nulls.

## 4. Environment configuration

- [x] 4.1 Enable the app in `prod.tfvars` only (`enabled=true`, A1.Flex 4 OCPU / 24 GB, `data_volume_size_gb=200`, NSG rule source CIDRs). Verify `git diff --stat` shows dev/staging tfvars untouched.
- [x] 4.2 Confirm `terraform plan -var-file=prod.tfvars` creates exactly: 1 A1 instance, 1 block volume + attachment, 1 backend set, 1 listener, 1 NSG rule; and `terraform plan -var-file=dev.tfvars` reports no changes.

## 5. Deploy & verify end-to-end

- [ ] 5.1 Apply to prod (`terraform apply -var-file=prod.tfvars`) after plan review; capture `terraform output immich_url`.
- [ ] 5.2 Open the output URL and complete Immich's admin signup; upload a test photo and confirm it lands under `/srv/apps/immich/library` on the instance. Verify LB health check reports the immich backend healthy.
- [ ] 5.3 Reboot the instance once and verify Docker + Immich containers return automatically and the URL keeps serving (persistence requirement).
- [ ] 5.4 Document actual URL/outputs in `docs/` or the change summary and decide on the optional backup-policy hook (design open question) with the operator.
