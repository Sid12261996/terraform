#!/usr/bin/env bash
# Creates the Object Storage bucket that holds Terraform state, plus the
# customer secret key the S3-compatible backend authenticates with.
#
# This cannot live in Terraform: Terraform will not store its state in a
# bucket it has not created yet.
#
# Re-runnable. An existing bucket is left alone. OCI caps customer secret
# keys at two per user and never shows a secret twice, so a new key is only
# minted when asked for:
#
#   ./scripts/bootstrap-state.sh                  # create bucket, reuse keys
#   ./scripts/bootstrap-state.sh --new-key        # also mint a fresh key
#   ./scripts/bootstrap-state.sh --new-key --rotate  # ...and drop the old ones
#
# Pass --set-github to push the results straight into the repo's Actions
# variables and secrets with `gh`.
set -euo pipefail

BUCKET="${TF_STATE_BUCKET:-terraform-state-immich}"
NEW_KEY=false
ROTATE=false
SET_GITHUB=false

while [ $# -gt 0 ]; do
  case "$1" in
    --new-key)    NEW_KEY=true ;;
    --rotate)     ROTATE=true; NEW_KEY=true ;;
    --set-github) SET_GITHUB=true ;;
    --bucket)     shift; BUCKET="$1" ;;
    -h|--help)    sed -n '2,20p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
  shift
done

need() { command -v "$1" >/dev/null 2>&1 || { echo "required tool not found: $1" >&2; exit 1; }; }
need oci
need python3
$SET_GITHUB && need gh

TENANCY="$(oci iam compartment list --query 'data[0]."compartment-id"' --raw-output)"
NAMESPACE="$(oci os ns get --query 'data' --raw-output)"
REGION="$(oci iam region-subscription list --query 'data[0]."region-name"' --raw-output)"
USER_OCID="$(oci iam user list --query 'data[0].id' --raw-output)"

echo "Tenancy   : ${TENANCY: -12}"
echo "Namespace : ${NAMESPACE}"
echo "Region    : ${REGION}"
echo "Bucket    : ${BUCKET}"
echo

#####################
# Bucket
#####################

if oci os bucket get --name "${BUCKET}" >/dev/null 2>&1; then
  echo "Bucket already exists; leaving it as is."
else
  echo "Creating bucket..."
  oci os bucket create \
    --name "${BUCKET}" \
    --compartment-id "${TENANCY}" \
    --versioning Enabled >/dev/null
  echo "Created, with versioning on so a corrupted state can be rolled back."
fi

#####################
# Customer secret key
#####################

# A user with no keys returns an empty result rather than 0, so normalise.
EXISTING="$(oci iam customer-secret-key list --user-id "${USER_OCID}" \
  --query 'length(data[?"lifecycle-state"==`ACTIVE`])' --raw-output 2>/dev/null || true)"
[[ "${EXISTING}" =~ ^[0-9]+$ ]] || EXISTING=0
echo "Existing active customer secret keys: ${EXISTING} (OCI allows 2)"

if ! $NEW_KEY; then
  if [ "${EXISTING}" -gt 0 ]; then
    echo
    echo "Reusing the existing key. Its secret cannot be read back from OCI -"
    echo "if you no longer have it, re-run with --new-key."
  else
    echo
    echo "No key exists yet. Re-run with --new-key to create one."
  fi
  ACCESS_KEY=""
  SECRET_KEY=""
else
  if $ROTATE && [ "${EXISTING}" -gt 0 ]; then
    echo "Removing existing keys first (--rotate)..."
    for k in $(oci iam customer-secret-key list --user-id "${USER_OCID}" \
                 --query 'data[?"lifecycle-state"==`ACTIVE`].id' --raw-output \
                 2>/dev/null | tr -d '[]", ' | grep -v '^$'); do
      oci iam customer-secret-key delete --user-id "${USER_OCID}" \
        --customer-secret-key-id "$k" --force >/dev/null 2>&1 \
        && echo "  removed ${k: -12}"
    done
  elif [ "${EXISTING}" -ge 2 ]; then
    echo "Already at the two-key limit. Re-run with --rotate to replace them." >&2
    exit 1
  fi

  echo "Creating a customer secret key..."
  KEY_JSON="$(oci iam customer-secret-key create \
    --user-id "${USER_OCID}" \
    --display-name "terraform-state-$(date +%Y%m%d%H%M)")"
  ACCESS_KEY="$(printf '%s' "${KEY_JSON}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["data"]["id"])')"
  SECRET_KEY="$(printf '%s' "${KEY_JSON}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["data"]["key"])')"
fi

#####################
# Report / publish
#####################

if $SET_GITHUB; then
  echo
  echo "Setting GitHub Actions variables..."
  gh variable set TF_STATE_BUCKET    --body "${BUCKET}"
  gh variable set TF_STATE_NAMESPACE --body "${NAMESPACE}"
  gh variable set OCI_REGION         --body "${REGION}"
  if [ -n "${ACCESS_KEY}" ]; then
    echo "Setting GitHub Actions secrets..."
    gh secret set OCI_S3_ACCESS_KEY_ID     --body "${ACCESS_KEY}"
    gh secret set OCI_S3_SECRET_ACCESS_KEY --body "${SECRET_KEY}"
  else
    echo "No new key was created, so the S3 secrets were left untouched."
  fi
  echo "Done."
else
  cat <<TXT

================ Store these in GitHub ================
  gh variable set TF_STATE_BUCKET    --body "${BUCKET}"
  gh variable set TF_STATE_NAMESPACE --body "${NAMESPACE}"
  gh variable set OCI_REGION         --body "${REGION}"
TXT
  if [ -n "${ACCESS_KEY}" ]; then
    cat <<TXT
  gh secret set OCI_S3_ACCESS_KEY_ID     --body "${ACCESS_KEY}"
  gh secret set OCI_S3_SECRET_ACCESS_KEY --body "${SECRET_KEY}"

The secret above is shown once and cannot be retrieved again.
TXT
  fi
  echo "======================================================="
  echo
  echo "Re-run with --set-github to apply all of that automatically."
fi

#####################
# Local backend config
#####################

cat > backend.auto.hcl <<HCL
bucket = "${BUCKET}"
region = "${REGION}"
endpoints = {
  s3 = "https://${NAMESPACE}.compat.objectstorage.${REGION}.oraclecloud.com"
}
HCL
echo
echo "Wrote backend.auto.hcl (gitignored) for local use:"
echo "  export AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=..."
echo "  terraform init -backend-config=backend.auto.hcl"
