# Sizing for this tenancy. Verify against ./scripts/check-limits.sh before
# changing anything here - the Always Free allowance is per tenancy and an
# over-request fails the apply rather than silently downgrading.

name_prefix = "immich"

# The tenancy allows 2 OCPU / 12 GB of Ampere A1, but asking for all of it
# was refused with "Out of host capacity" five times running. A smaller
# request fits into a partly-used host, so take half and grow later - flex
# shapes resize in place, so this is not a decision we are stuck with.
instance_ocpus     = 1
instance_memory_gb = 6

# Block storage allowance: 200 GB total, boot volume included.
boot_volume_gb = 50
data_volume_gb = 150

immich_version = "release"

# Set both to serve Immich over HTTPS. Create the A record pointing at the
# instance's public IP first, or the certificate request will fail.
# domain_name = "photos.example.com"
# acme_email  = "you@example.com"

# Narrow this to your own address once you have confirmed SSH works.
# ssh_ingress_cidr = "203.0.113.4/32"
