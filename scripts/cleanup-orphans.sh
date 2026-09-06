#!/usr/bin/env bash
# Removes infrastructure that Terraform state has lost track of.
#
# Dry run by default: prints what it would delete and exits. Pass --apply to
# act. Re-runnable - anything already gone is skipped, so it is safe to run
# repeatedly until ./scripts/list-orphans.sh comes back clean.
#
#   ./scripts/cleanup-orphans.sh                 # show what would go
#   ./scripts/cleanup-orphans.sh --apply         # networks + instances + configs
#   ./scripts/cleanup-orphans.sh --apply --all   # also volumes, LBs, databases
#
# Extending it: add a line to STANDALONE_RESOURCES or VCN_CHILDREN below.
# Each line is  list-command | delete-command | id-flag | label  and the
# script works out the rest.
set -euo pipefail

APPLY=false
ALL=false
for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=true ;;
    --all)   ALL=true ;;
    -h|--help) sed -n '2,18p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) echo "unknown flag: $arg" >&2; exit 2 ;;
  esac
done

#####################
# What to delete
#####################

# Resources that live directly in a compartment.
# Kept in dependency order: things that reference others come first.
STANDALONE_RESOURCES=(
  "compute-management instance-pool|terminate|--instance-pool-id|instance pool"
  "compute instance|terminate|--instance-id|instance"
  "compute-management instance-configuration|delete|--instance-configuration-id|instance configuration"
)

# Only touched with --all: these either hold data or are slow to recreate.
DESTRUCTIVE_RESOURCES=(
  "lb load-balancer|delete|--load-balancer-id|load balancer"
  "network-load-balancer network-load-balancer|delete|--network-load-balancer-id|network load balancer"
  "bv volume|delete|--volume-id|block volume"
  "bv boot-volume|delete|--boot-volume-id|boot volume"
  "db autonomous-database|delete|--autonomous-database-id|autonomous database"
)

# Everything inside a VCN, in the order the API will accept.
# A VCN refuses to delete while any of these still reference it.
VCN_CHILDREN=(
  "network subnet|delete|--subnet-id|subnet"
  "network nsg|delete|--nsg-id|network security group"
  "network internet-gateway|delete|--ig-id|internet gateway"
  "network nat-gateway|delete|--nat-gateway-id|NAT gateway"
  "network service-gateway|delete|--service-gateway-id|service gateway"
  "network local-peering-gateway|delete|--local-peering-gateway-id|local peering gateway"
  "network drg-attachment|delete|--drg-attachment-id|DRG attachment"
  "network route-table|delete|--rt-id|route table"
  "network security-list|delete|--security-list-id|security list"
  "network dhcp-options|delete|--dhcp-id|DHCP options"
)

#####################
# Plumbing
#####################

DELETED=0
SKIPPED=0

$APPLY || echo "DRY RUN - nothing will be deleted. Re-run with --apply to act."
echo

TENANCY="$(oci iam compartment list --query 'data[0]."compartment-id"' --raw-output)"

mapfile -t COMPARTMENTS < <(
  { echo "${TENANCY}"
    oci iam compartment list --compartment-id-in-subtree true --all \
      --query 'data[?"lifecycle-state"==`ACTIVE`].id' --raw-output 2>/dev/null \
      | tr -d '[]", ' | grep -v '^$'
  } | sort -u
)

# Lists resource OCIDs, dropping OCI's undeletable defaults and anything
# already terminated. Extra args (e.g. --vcn-id) are passed through.
list_ids() {
  local cmd="$1"; shift
  oci $cmd list --all "$@" \
    --query 'data[?"lifecycle-state"==null || !contains([`TERMINATED`,`TERMINATING`,`DELETED`,`DELETING`,`FAILED`], "lifecycle-state")] | [?!starts_with("display-name" || `x`, `Default`)].id' \
    --raw-output 2>/dev/null | tr -d '[]", ' | grep -v '^$' || true
}

delete_one() {
  local cmd="$1" sub="$2" flag="$3" label="$4" id="$5" indent="${6:-}"
  if ! $APPLY; then
    echo "${indent}  would delete ${label} ${id: -12}"
    return
  fi
  if oci $cmd $sub $flag "$id" --force >/dev/null 2>&1; then
    echo "${indent}  deleted ${label} ${id: -12}"
    DELETED=$(( DELETED + 1 ))
  else
    echo "${indent}  skipped ${label} ${id: -12} (in use, already gone, or not permitted)"
    SKIPPED=$(( SKIPPED + 1 ))
  fi
}

# Walks one resource spec across every compartment.
sweep() {
  local spec="$1"
  IFS='|' read -r cmd sub flag label <<< "$spec"
  local c id
  for c in "${COMPARTMENTS[@]}"; do
    for id in $(list_ids "$cmd" -c "$c"); do
      delete_one "$cmd" "$sub" "$flag" "$label" "$id" ""
    done
  done
}

#####################
# Sweep
#####################

echo "== Compute =="
for spec in "${STANDALONE_RESOURCES[@]}"; do sweep "$spec"; done

if $ALL; then
  echo "== Volumes, load balancers, databases =="
  for spec in "${DESTRUCTIVE_RESOURCES[@]}"; do sweep "$spec"; done
else
  echo "== Volumes, load balancers, databases: skipped (pass --all) =="
fi

echo "== Networks =="
for c in "${COMPARTMENTS[@]}"; do
  for vcn in $(list_ids "network vcn" -c "$c"); do
    echo "VCN ${vcn: -12}"
    for spec in "${VCN_CHILDREN[@]}"; do
      IFS='|' read -r cmd sub flag label <<< "$spec"
      for id in $(list_ids "$cmd" -c "$c" --vcn-id "$vcn"); do
        delete_one "$cmd" "$sub" "$flag" "$label" "$id" "  "
      done
    done
    delete_one "network vcn" delete --vcn-id "VCN" "$vcn" ""
  done
done

echo
if $APPLY; then
  echo "Deleted ${DELETED}, skipped ${SKIPPED}."
  echo "Resources that were still in use may need a second pass - this script"
  echo "is safe to re-run. Verify with ./scripts/list-orphans.sh"
else
  echo "Nothing was deleted. Re-run with --apply when the list looks right."
fi
