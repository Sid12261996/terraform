# One-time setup

Everything below is done once. After that, `git push` deploys.

## 0. Prerequisites

- An OCI tenancy (the Always Free tier is enough).
- The [OCI CLI](https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm),
  authenticated: `oci setup config`.
- An SSH key pair. If you do not have one:
  `ssh-keygen -t ed25519 -C "immich" -f ~/.ssh/immich`

## 1. Know your tenancy's real limits

Always Free allowances differ per tenancy. A configuration that asks for more
than yours will fail the apply, so check first:

```bash
./scripts/check-limits.sh
```

Set `instance_ocpus`, `instance_memory_gb`, `boot_volume_gb` and
`data_volume_gb` to fit what it reports. `boot_volume_gb + data_volume_gb`
must not exceed the block storage total.

## 2. Create the state bucket and its credentials

Terraform needs somewhere to record what it created. Without this, every run
starts blind and builds a second copy of everything.

```bash
./scripts/bootstrap-state.sh
```

It creates the Object Storage bucket and an Object Storage *customer secret
key*, then prints the values to store in GitHub. The secret is shown once.

## 3. Store the configuration in GitHub

Repository **variables** (Settings -> Secrets and variables -> Actions -> Variables):

| Name | Value |
|---|---|
| `OCI_REGION` | e.g. `ap-hyderabad-1` |
| `TF_STATE_BUCKET` | bucket name from step 2 |
| `TF_STATE_NAMESPACE` | Object Storage namespace from step 2 |
| `OCI_COMPARTMENT_OCID` | compartment to deploy into (optional; defaults to tenancy root) |

Repository **secrets**:

| Name | Value |
|---|---|
| `OCI_TENANCY_OCID` | `oci iam compartment list --query 'data[0]."compartment-id"'` |
| `OCI_USER_OCID` | your user OCID |
| `OCI_FINGERPRINT` | API key fingerprint |
| `OCI_PRIVATE_KEY` | full PEM contents of the API private key |
| `SSH_PUBLIC_KEY` | contents of `~/.ssh/immich.pub` |
| `OCI_S3_ACCESS_KEY_ID` | from step 2 |
| `OCI_S3_SECRET_ACCESS_KEY` | from step 2 |

`gh` can set them all:

```bash
gh variable set OCI_REGION --body "ap-hyderabad-1"
gh secret   set SSH_PUBLIC_KEY < ~/.ssh/immich.pub
gh secret   set OCI_PRIVATE_KEY < ~/.oci/oci_api_key.pem
# ...and so on
```

## 4. Deploy

Push to `main`, or run the **Terraform** workflow manually. Pull requests get
a plan comment and change nothing.

## 5. Point a domain at it (optional)

Read the public IP from the workflow summary, create an `A` record for it,
then set `domain_name` and `acme_email` in `terraform.tfvars` and push. Caddy
requests a Let's Encrypt certificate on the next boot.

Without a domain, Immich is served over plain **HTTP**. Fine for a first look,
but do not upload a real photo library to it — the session cookie crosses the
internet unencrypted.

## Troubleshooting

**`Out of host capacity`** — Ampere A1 is heavily contended. It is not a
configuration error; retry the workflow, or lower `instance_ocpus`.

**`LimitExceeded`** — you are asking for more than step 1 reported.

**Immich is not responding yet** — first boot pulls several GB of images.
Watch it: `ssh ubuntu@<ip> 'sudo tail -f /var/log/immich-bootstrap.log'`.
