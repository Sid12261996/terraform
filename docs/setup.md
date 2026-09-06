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
./scripts/bootstrap-state.sh --new-key --set-github
```

It creates the Object Storage bucket, mints an Object Storage *customer
secret key*, and pushes both into the repository's Actions variables and
secrets. The secret is displayed by OCI exactly once, so the script never
tries to read one back.

Re-runnable. The bucket is left alone if it exists, and no key is minted
unless you ask:

| Flag | Effect |
|---|---|
| *(none)* | create the bucket, report what is already configured |
| `--new-key` | also mint a customer secret key |
| `--rotate` | remove existing keys first (OCI caps them at two per user) |
| `--set-github` | write the results to GitHub instead of printing them |
| `--bucket NAME` | use a different bucket name |

If you lose the secret, `--new-key --rotate --set-github` replaces it.

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

`--set-github` in step 2 handles the state ones. The rest, once:

```bash
gh secret set SSH_PUBLIC_KEY  < ~/.ssh/immich.pub
gh secret set OCI_PRIVATE_KEY < ~/.oci/oci_api_key.pem
gh secret set OCI_TENANCY_OCID --body "$(oci iam compartment list --query 'data[0]."compartment-id"' --raw-output)"
gh secret set OCI_USER_OCID    --body "$(oci iam user list --query 'data[0].id' --raw-output)"
gh secret set OCI_FINGERPRINT  --body "<fingerprint from the OCI console>"
```

The workflow checks all of them up front and names whichever are missing,
rather than failing partway through an apply.

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

## Starting over

If a previous pipeline ran without remote state, the tenancy may hold
resources Terraform no longer knows about. Find them and remove them:

```bash
./scripts/list-orphans.sh                    # what exists
./scripts/cleanup-orphans.sh                 # dry run
./scripts/cleanup-orphans.sh --apply --all   # delete it
```

Both are re-runnable; deletions that fail because something still references
the resource are reported, so run again until `list-orphans.sh` is clean.

## Troubleshooting

**`Out of host capacity`** — Ampere A1 is heavily contended. It is not a
configuration error; retry the workflow, or lower `instance_ocpus`.

**`LimitExceeded`** — you are asking for more than step 1 reported.

**Immich is not responding yet** — first boot pulls several GB of images.
Watch it: `ssh ubuntu@<ip> 'sudo tail -f /var/log/immich-bootstrap.log'`.

**`NotImplemented: AWS chunked encoding not supported`** — OCI's
S3-compatible endpoint rejects the trailing checksum the AWS SDK sends by
default. The workflow disables it with `AWS_REQUEST_CHECKSUM_CALCULATION`
and `AWS_RESPONSE_CHECKSUM_VALIDATION`; export both as `when_required` if
you are running Terraform by hand.

**`Error acquiring the state lock`** — a previous run died holding it.
Check nobody is mid-apply, then
`terraform force-unlock <id>`.
