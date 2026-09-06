# Immich on Oracle Cloud

Runs [Immich](https://immich.app) — a self-hosted photo library — on a single
Oracle Cloud Always Free ARM instance, provisioned by Terraform and deployed
by GitHub Actions.

## What it builds

Eight resources, and nothing else:

```
VCN ── internet gateway ── route table ── security list (22/80/443)
 └── public subnet
      └── VM.Standard.A1.Flex instance  (Ubuntu 22.04 arm64)
           ├── boot volume               50 GB
           └── block volume             150 GB  → /srv/immich
                                                   ├── library/   photos
                                                   ├── postgres/  database
                                                   └── app/       compose files
```

cloud-init installs Docker, mounts the block volume, and starts the official
Immich compose stack behind Caddy. Photos and the database live on the block
volume, so replacing the instance does not touch them.

## Getting started

Follow [docs/setup.md](docs/setup.md). In short:

```bash
./scripts/check-limits.sh      # what your tenancy actually allows
./scripts/bootstrap-state.sh   # state bucket + credentials
# store the printed values as GitHub secrets/variables, then push
```

## Design notes

**Remote state is mandatory, not optional.** Terraform's record of what it
built lives in an Object Storage bucket via the S3-compatible API, with
native `use_lockfile` locking. An earlier version of this repository ran CI
with `terraform init -backend=false`; every run began with no state, rebuilt
the whole stack, and abandoned the previous run's resources. Ten VCNs and two
databases accumulated that way against a limit of two and one. If state is
ever unavailable, the right response is to fix the backend, never to apply
without it.

**Sizes are tenancy facts, not preferences.** Always Free allowances vary.
`scripts/check-limits.sh` reads the real numbers; `terraform.tfvars` should
match them.

**No load balancer.** The free flexible load balancer is capped at 10 Mbps,
which is a poor fit for uploading photos. Caddy on the instance terminates TLS
instead, and the instance holds the public IP directly.

**No managed database.** Immich ships its own tuned Postgres (with the vector
extensions it needs) in its compose stack. An Autonomous Database cannot serve
that role.

**Ampere capacity is contended.** `Out of host capacity` at apply time is an
Oracle-side shortage, not a bug here. Re-run the workflow; it is idempotent.

## Operating it

```bash
ssh ubuntu@<ip>
sudo tail -f /var/log/immich-bootstrap.log     # first-boot progress
cd /srv/immich/app && sudo docker compose ps   # container status
```

Upgrade Immich by bumping `immich_version` and re-running the bootstrap:

```bash
sudo /usr/local/sbin/immich-bootstrap.sh
```

Destroy everything via the **Terraform** workflow with `destroy: true`. The
data volume carries `prevent_destroy`, so removing the photo library is a
deliberate two-step act.
