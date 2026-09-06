#!/usr/bin/env bash
# Creates the Object Storage bucket that holds Terraform state, plus the
# customer secret key the S3-compatible backend authenticates with.
#
# This has to happen outside Terraform: Terraform cannot store its state in a
# bucket that it has not created yet.
set -euo pipefail

BUCKET="${1:-terraform-state-immich}"

TENANCY="$(oci iam compartment list --query 'data[0]."compartment-id"' --raw-output)"
NAMESPACE="$(oci os ns get --query 'data' --raw-output)"
REGION="$(oci iam region-subscription list --query 'data[0]."region-name"' --raw-output)"
USER_OCID="$(oci iam user list --query 'data[0].id' --raw-output)"

echo "Tenancy   : ${TENANCY}"
echo "Namespace : ${NAMESPACE}"
echo "Region    : ${REGION}"
echo

if oci os bucket get --name "${BUCKET}" >/dev/null 2>&1; then
  echo "Bucket '${BUCKET}' already exists; leaving it alone."
else
  echo "Creating bucket '${BUCKET}'..."
  oci os bucket create \
    --name "${BUCKET}" \
    --compartment-id "${TENANCY}" \
    --versioning Enabled \
    >/dev/null
  echo "Created (versioning on, so a corrupted state can be rolled back)."
fi

echo
echo "Creating an Object Storage customer secret key..."
KEY_JSON="$(oci iam customer-secret-key create \
  --user-id "${USER_OCID}" \
  --display-name "terraform-state-$(date +%Y%m%d)" 2>/dev/null)"

ACCESS_KEY="$(echo "${KEY_JSON}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["data"]["id"])')"
SECRET_KEY="$(echo "${KEY_JSON}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["data"]["key"])')"

cat <<TXT

================ Store these in GitHub ================
The secret key is displayed once and cannot be retrieved again.

  gh variable set TF_STATE_BUCKET    --body "${BUCKET}"
  gh variable set TF_STATE_NAMESPACE --body "${NAMESPACE}"
  gh variable set OCI_REGION         --body "${REGION}"

  gh secret set OCI_S3_ACCESS_KEY_ID     --body "${ACCESS_KEY}"
  gh secret set OCI_S3_SECRET_ACCESS_KEY --body "${SECRET_KEY}"
=======================================================

To use the same state locally:

  cat > backend.auto.hcl <<HCL
  bucket = "${BUCKET}"
  region = "${REGION}"
  endpoints = { s3 = "https://${NAMESPACE}.compat.objectstorage.${REGION}.oraclecloud.com" }
  HCL
  export AWS_ACCESS_KEY_ID="${ACCESS_KEY}"
  export AWS_SECRET_ACCESS_KEY='${SECRET_KEY}'
  terraform init -backend-config=backend.auto.hcl
TXT
