#!/usr/bin/env bash
# Read-only inventory of what actually exists in the tenancy.
#
# Runs without state, so it is the way to see resources that Terraform has
# lost track of - for example after a CI pipeline applied without a remote
# backend and leaked a copy of the stack on every run.
set -euo pipefail

TENANCY="$(oci iam compartment list --query 'data[0]."compartment-id"' --raw-output)"

mapfile -t COMPARTMENTS < <(
  { echo "${TENANCY}"
    oci iam compartment list --compartment-id-in-subtree true --all \
      --query 'data[?"lifecycle-state"==`ACTIVE`].id' --raw-output 2>/dev/null \
      | tr -d '[]," ' | grep -v '^$'
  } | sort -u
)

# Counts live resources only. OCI keeps terminated ones listable for a while,
# and counting those makes a clean tenancy look full.
count() { # service subcommand
  local total=0 n
  for c in "${COMPARTMENTS[@]}"; do
    n="$(oci $1 list -c "$c" --all \
      --query 'length(data[?"lifecycle-state"==null || !contains([`TERMINATED`,`TERMINATING`,`DELETED`,`DELETING`,`FAILED`], "lifecycle-state")])' \
      2>/dev/null || echo 0)"
    [[ "$n" =~ ^[0-9]+$ ]] || n=0
    total=$(( total + n ))
  done
  echo "$total"
}

echo "Inventory across $(( ${#COMPARTMENTS[@]} )) compartments"
echo "----------------------------------------"
printf '  %-22s %s\n' "VCNs"              "$(count 'network vcn')"
printf '  %-22s %s\n' "Subnets"           "$(count 'network subnet')"
printf '  %-22s %s\n' "Internet gateways" "$(count 'network internet-gateway')"
printf '  %-22s %s\n' "NAT gateways"      "$(count 'network nat-gateway')"
printf '  %-22s %s\n' "Service gateways"  "$(count 'network service-gateway')"
printf '  %-22s %s\n' "Instances"         "$(count 'compute instance')"
printf '  %-22s %s\n' "Block volumes"     "$(count 'bv volume')"
printf '  %-22s %s\n' "Load balancers"    "$(count 'lb load-balancer')"
printf '  %-22s %s\n' "Autonomous DBs"    "$(count 'db autonomous-database')"
printf '  %-22s %s\n' "Instance configs"  "$(count 'compute-management instance-configuration')"
printf '  %-22s %s\n' "Instance pools"    "$(count 'compute-management instance-pool')"

echo
echo "Compare against ./scripts/check-limits.sh. Anything far above what this"
echo "configuration declares (1 VCN, 1 subnet, 1 instance, 1 volume) is a leak"
echo "from a stateless apply and can be removed."
