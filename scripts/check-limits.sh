#!/usr/bin/env bash
# Reports the Always Free allowances that this configuration depends on.
# Run before the first deploy: these differ per tenancy, and asking for more
# than you have fails the apply.
set -euo pipefail

TENANCY="$(oci iam compartment list --query 'data[0]."compartment-id"' --raw-output)"

limit() {
  oci limits value list -c "$TENANCY" --service-name "$1" --all \
    --query "data[?name=='$2'].value | [0]" --raw-output 2>/dev/null
}

A1_CORES="$(limit compute standard-a1-core-regional-count)"
A1_MEM="$(limit compute standard-a1-memory-regional-count)"
STORAGE="$(limit block-storage total-storage-gb)"
VCNS="$(limit vcn vcn-count)"

VCNS_USED="$(oci limits resource-availability get --service-name vcn \
  --limit-name vcn-count -c "$TENANCY" --query 'data.used' --raw-output 2>/dev/null || echo '?')"

cat <<TXT
Tenancy limits
--------------
  Ampere A1 cores    : ${A1_CORES:-unknown}      -> instance_ocpus must be <= this
  Ampere A1 memory   : ${A1_MEM:-unknown} GB     -> instance_memory_gb must be <= this
  Block storage total: ${STORAGE:-unknown} GB    -> boot_volume_gb + data_volume_gb must be <= this
  VCNs               : ${VCNS_USED}/${VCNS:-unknown} used

Suggested terraform.tfvars
--------------------------
  instance_ocpus     = ${A1_CORES:-2}
  instance_memory_gb = ${A1_MEM:-12}
  boot_volume_gb     = 50
  data_volume_gb     = $(( ${STORAGE:-200} - 50 ))
TXT

if [ "${VCNS_USED}" != "?" ] && [ "${VCNS:-0}" != "unknown" ] \
   && [ "${VCNS_USED}" -ge "${VCNS:-0}" ] 2>/dev/null; then
  echo
  echo "WARNING: the VCN limit is already reached. Creating another one will fail."
  echo "         Remove unused VCNs first: ./scripts/list-orphans.sh"
fi
