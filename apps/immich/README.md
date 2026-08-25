# Immich (self-hosted photo library)

[Immich](https://immich.app) is an open-source, self-hosted Google Photos replacement. This directory is the repo-side home for its deployment assets; it follows the `apps/<app-name>/` convention for every application hosted by this stack.

## Files

| File | Purpose |
|------|---------|
| `cloud-init.yml.tftpl` | Terraform template rendered into the instance's first-boot user data |
| `docker-compose.yml` | Vendored copy of upstream's release compose file (for review/diffing against what the install script downloads) |
| `.env.example` | Reviewed copy of the environment the bootstrap writes, including our storage overrides |

## First-boot behavior

1. Docker CE + compose plugin are installed (Docker's CentOS 8 repo, compatible with Oracle Linux).
2. The dedicated block volume is located (largest non-root disk), formatted **once** (guarded via `blkid` so it never re-formats a populated volume), mounted at `/srv/apps/immich`, and persisted in `/etc/fstab` with `nofail`.
3. The official Immich install script (`https://docs.immich.app/install/script`) runs from `/srv/apps/immich/app`, producing `/srv/apps/immich/app/immich-app/`.
4. The generated `.env` is rewritten: `UPLOAD_LOCATION=/srv/apps/immich/library`, `DB_DATA_LOCATION=/srv/apps/immich/postgres`, `IMMICH_VERSION` from Terraform config, and a random `DB_PASSWORD` if unset.
5. Containers start; Immich serves on local port 2283.

Bootstrap log: `/var/log/immich-bootstrap.log`. Re-run manually any time:

```bash
sudo bash /usr/local/sbin/immich-bootstrap.sh
```

## Access

The instance has no public IP. Traffic goes through the public load balancer listener on port 2283; after `terraform apply` read the URL from:

```bash
terraform output immich_url   # http://<lb-public-ip>:2283
```

Complete admin signup immediately after first access — port 2283 is internet-facing via the LB until you do.

## Data locations on the server

| Path | Contents |
|------|----------|
| `/srv/apps/immich/library` | Uploaded photos/videos (Immich `UPLOAD_LOCATION`) |
| `/srv/apps/immich/postgres` | Postgres data files (`DB_DATA_LOCATION`) |
| `/srv/apps/immich/app/immich-app/` | Compose project (`.env`, `docker-compose.yml`) |

## Troubleshooting

```bash
ssh opc@<private-ip>                       # from a host with VCN access
cat /var/log/immich-bootstrap.log          # first-boot installer log
sudo docker compose ps                     # container states
sudo docker logs immich_server --tail 100  # app logs
sudo docker logs immich_machine_learning --tail 100
```

If the LB reports the backend unhealthy, containers are likely still starting (ML image pulls can take minutes on first boot); re-check after a few minutes.

## Version pinning & upgrades

Immich marks the **install-script method experimental** (they recommend plain Docker Compose). We keep the script flow but vendor the release `docker-compose.yml` and `.env.example` here so drift is reviewable. Upstream releases move fast and may require DB migrations — read https://immich.app/releases before changing `IMMICH_VERSION`. To pin:

1. Set `apps_immich.immich_version = "v1.xx.x"` in `prod.tfvars`
2. Update the vendored `docker-compose.yml` from that release tag
3. On the server: re-run bootstrap, then `docker compose up --remove-orphans -d`

## Expanding storage

The block volume expands online without detaching:

```bash
# 1. terraform: increase apps_immich.data_volume_size_gb, apply
# 2. on the server:
sudo dnf -y install cloud-utils-growpart   # if needed
sudo growpart /dev/sdb 1                   # adjust device/partition as shown by lsblk
sudo resize2fs /dev/sdb1
df -h /srv/apps/immich
```

## Known trade-offs

- Script installs are experimental per upstream docs — mitigated by the vendored assets above.
- HTTP only for now (TLS/custom domain is a future change).
- Volume backup policy hook exists but backups are not automated yet.
