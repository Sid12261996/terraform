#!/usr/bin/env bash
# Removes infrastructure that Terraform state has lost track of.
#
# Dry run by default: prints what it would delete and exits. Pass --apply to
# actually delete. Nothing here is recoverable, so read the dry run first.
#
#   ./scripts/cleanup-orphans.sh                 # show
#   ./scripts/cleanup-orphans.sh --apply         # delete networks + instance configs
#   ./scripts/cleanup-orphans.sh --apply --all   # also load balancers and databases
set -euo pipefail

APPLY=false
ALL=false
for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=true ;;
    --all)   ALL=true ;;
    *) echo "unknown flag: $arg" >&2; exit 2 ;;
  esac
done

$APPLY || echo "DRY RUN - nothing will be deleted. Re-run with --apply to act."
echo

TENANCY="$(oci iam compartment list --query 'data[0]."compartment-id"' --raw-output)"
mapfile -t COMPARTMENTS < <(
  { echo "${TENANCY}"
    oci iam compartment list --compartment-id-in-subtree true --all \
      --query 'data[?"lifecycle-state"==`ACTIVE`].id' --raw-output 2>/dev/null \
      | tr -d '[]," ' | grep -v '^$'
  } | sort -u
)

run() { # description, then command
  local desc="$1"; shift
  if $APPLY; then
    echo "  deleting ${desc}"
    "$@" >/dev/null 2>&1 || echo "    (failed; likely already gone or still in use)"
  else
    echo "  would delete ${desc}"
  fi
}

ids() { oci $1 list -c "$2" --all --query 'data[].id' --raw-output 2>/dev/null | tr -d '[]", ' | grep -v '^$' || true; }

echo "== Instance configurations and pools =="
for c in "${COMPARTMENTS[@]}"; do
  for id in $(ids 'compute-management instance-pool' "$c"); do
    run "instance pool ${id: -12}" oci compute-management instance-pool terminate --instance-pool-id "$id" --force
  done
  for id in $(ids 'compute-management instance-configuration' "$c"); do
    run "instance config ${id: -12}" oci compute-management instance-configuration delete --instance-configuration-id "$id" --force
  done
done

if $ALL; then
  echo "== Load balancers =="
  for c in "${COMPARTMENTS[@]}"; do
    for id in $(ids 'lb load-balancer' "$c"); do
      run "load balancer ${id: -12}" oci lb load-balancer delete --load-balancer-id "$id" --force
    done
  done

  echo "== Autonomous databases =="
  for c in "${COMPARTMENTS[@]}"; do
    for id in $(ids 'db autonomous-database' "$c"); do
      run "autonomous db ${id: -12}" oci db autonomous-database delete --autonomous-database-id "$id" --force
    done
  done
fi

echo "== VCNs and their contents =="
# Order matters: a VCN will not delete while anything still references it.
for c in "${COMPARTMENTS[@]}"; do
  for vcn in $(ids 'network vcn' "$c"); do
    echo "VCN ${vcn: -12}"

    for s in $(oci network subnet list -c "$c" --vcn-id "$vcn" --all --query 'data[].id' --raw-output 2>/dev/null | tr -d '[]", ' | grep -v '^$'); do
      run "  subnet ${s: -12}" oci network subnet delete --subnet-id "$s" --force
    done

    # Route tables and security lists must be emptied of references and the
    # VCN's defaults cannot be deleted at all, so skip anything named "Default".
    for rt in $(oci network route-table list -c "$c" --vcn-id "$vcn" --all --query 'data[?!starts_with("display-name", `Default`)].id' --raw-output 2>/dev/null | tr -d '[]", ' | grep -v '^$'); do
      run "  route table ${rt: -12}" oci network route-table delete --rt-id "$rt" --force
    done
    for sl in $(oci network security-list list -c "$c" --vcn-id "$vcn" --all --query 'data[?!starts_with("display-name", `Default`)].id' --raw-output 2>/dev/null | tr -d '[]", ' | grep -v '^$'); do
      run "  security list ${sl: -12}" oci network security-list delete --security-list-id "$sl" --force
    done
    for nsg in $(oci network nsg list -c "$c" --vcn-id "$vcn" --all --query 'data[].id' --raw-output 2>/dev/null | tr -d '[]", ' | grep -v '^$'); do
      run "  NSG ${nsg: -12}" oci network nsg delete --nsg-id "$nsg" --force
    done

    for g in $(oci network internet-gateway list -c "$c" --vcn-id "$vcn" --all --query 'data[].id' --raw-output 2>/dev/null | tr -d '[]", ' | grep -v '^$'); do
      run "  internet gateway ${g: -12}" oci network internet-gateway delete --ig-id "$g" --force
    done
    for g in $(oci network nat-gateway list -c "$c" --vcn-id "$vcn" --all --query 'data[].id' --raw-output 2>/dev/null | tr -d '[]", ' | grep -v '^$'); do
      run "  NAT gateway ${g: -12}" oci network nat-gateway delete --nat-gateway-id "$g" --force
    done
    for g in $(oci network service-gateway list -c "$c" --vcn-id "$vcn" --all --query 'data[].id' --raw-output 2>/dev/null | tr -d '[]", ' | grep -v '^$'); do
      run "  service gateway ${g: -12}" oci network service-gateway delete --service-gateway-id "$g" --force
    done
    for d in $(oci network dhcp-options list -c "$c" --vcn-id "$vcn" --all --query 'data[?!starts_with("display-name", `Default`)].id' --raw-output 2>/dev/null | tr -d '[]", ' | grep -v '^$'); do
      run "  DHCP options ${d: -12}" oci network dhcp-options delete --dhcp-id "$d" --force
    done

    run "  VCN ${vcn: -12}" oci network vcn delete --vcn-id "$vcn" --force
  done
done

echo
$APPLY && echo "Done. Re-check with ./scripts/list-orphans.sh" \
       || echo "Nothing was deleted. Re-run with --apply when the list looks right."
