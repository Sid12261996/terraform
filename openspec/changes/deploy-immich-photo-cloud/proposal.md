# Proposal: Deploy Immich Photo Cloud on OCI

## Why

The repo already provisions a full OCI stack (network, compute, load balancer), but nothing useful runs on it. We want a private, self-hosted Google Photos replacement using open-source Immich, deployed through the same Terraform workflow, with the machine URL surfaced after apply so photos can be uploaded immediately.

## What Changes

- Add an **`apps/` directory convention** at the repo root: each self-hosted application lives in `apps/<app-name>/` with its deployment assets (cloud-init template, env template, README). First entry: `apps/immich/`.
- Provision a dedicated **Immich server** in prod only: OCI **Ampere A1.Flex** (4 OCPU / 24 GB RAM, arm64), placed in the existing private subnets behind the existing NSG model.
- Attach a dedicated **200 GB block volume** to the Immich server for the photo library, formatted and mounted at `/srv/apps/immich` via cloud-init (expandable later without data loss).
- Bootstrap the instance with **Docker** and run the official **Immich install script** (`curl -o- https://raw.githubusercontent.com/immich-app/immich/main/install.sh | bash`) via cloud-init, storing library data on the mounted volume.
- Extend the **public load balancer** with a dedicated backend set + HTTP listener on port 2283 routing to the Immich server (existing listeners/backend set untouched).
- Open the required **NSG rule** allowing the public LB subnets to reach the Immich instance on 2283.
- Emit Terraform outputs including the ready-to-use **machine URL** (`http://<lb-public-ip>:2283`) and SSH hints.

## Capabilities

### New Capabilities

- `oci/apps`: Self-hosted application workloads on OCI — repo-side `apps/<name>/` layout, per-app provisioning profile (shape, memory, data volume), automated first-boot installation, health-checked exposure through the public load balancer, and post-apply URL outputs. Initial app: Immich photo library.

### Modified Capabilities

- `oci/compute`: New requirements for architecture-aware image selection (arm64 shapes must launch arm64 images) and dedicated block volume attach/format/mount lifecycle for app data.
- `oci/load-balancer`: New requirement for additional named backend sets and listeners so multiple services (e.g., app servers on 8080, Immich on 2283) share one public LB.

## Impact

- **Code**: `main.tf` (wire immich pool, LB backend set/listener wiring), `variables.tf` / `outputs.tf`, `prod.tfvars` (immich shape, volume size, NSG rules, user_data reference), new `apps/immich/*`, minor extension of `modules/compute` (per-shape image data source, block volume resource + attachment) and `modules/load-balancer` (additional backend sets/listeners map).
- **Infra**: 1 × VM.Standard.A1.Flex (4 OCPU / 24 GB) in prod, 1 × 200 GB block volume, 2 LB resources (backend set, listener), 1 NSG rule. Always-free-eligible shape; LB bandwidth already provisioned.
- **Dependencies**: Docker Engine on the instance (installed by cloud-init); Immich release artifacts pulled at first boot; Oracle Linux aarch64 image.
- **Risk**: Immich docs flag the install-script method as experimental (recommended path is plain Docker Compose); we honor the requested script method but pin/vendored compose assets live in `apps/immich/` for reproducibility. Health check uses Immich's `/api/server/ping`.
