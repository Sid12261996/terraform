# Production Environment Configuration
# Usage: terraform apply -var-file=prod.tfvars

#####################
# Environment
#####################
environment = "prod"

#####################
# Compartment (will be created if not provided)
#####################
# root_compartment_ocid = "ocid1.tenancy.oc1..xxxxx"  # Set via TF_VAR or GitHub secret

#####################
# Network
#####################
vcn_cidr_block = "10.20.0.0/16"
vcn_dns_label  = "prodvcn"

public_subnet_cidrs = {
  "AD-1" = "10.20.1.0/24"
  "AD-2" = "10.20.2.0/24"
  "AD-3" = "10.20.3.0/24"
}

private_subnet_cidrs = {
  "AD-1" = "10.20.11.0/24"
  "AD-2" = "10.20.12.0/24"
  "AD-3" = "10.20.13.0/24"
}

#####################
# Compute - the Immich app instance below (apps_immich) is the only
# workload; no separate generic instance pool is needed, and this
# tenancy's Always-Free Ampere allowance (4 OCPU/24GB total) is already
# fully spent on that one instance.
#####################
instance_shapes = {}

instance_counts = {}

ssh_public_keys = [
  # "ssh-rsa AAAAB3NzaC1yc2E... user@host"
]

#####################
# Load Balancer - sized to the Always Free flexible-LB allowance
# (a single LB at 10 Mbps). Immich's public route rides the same LB;
# nothing sends traffic to a private LB, so it stays disabled.
#####################
create_public_lb = true
public_lb_min_bw = 10
public_lb_max_bw = 100

create_private_lb = false
private_lb_min_bw = 10
private_lb_max_bw = 10

#####################
# Database - Always Free Autonomous Database (2 ECPU, 20GB storage)
#####################
create_atp = true
atp_config = {
  display_name             = "prod-atp"
  db_name                  = "PRODATP"
  admin_password           = "" # Empty = Terraform generates one (see database module output generated_admin_passwords); or set explicitly here
  cpu_core_count           = 1
  data_storage_size_in_tbs = 1
  is_auto_scaling_enabled  = false
  is_free_tier             = true
  license_model            = "LICENSE_INCLUDED"
}

create_adw       = false
create_db_system = false

#####################
# Tagging
#####################
owner_tag       = "platform-team"
cost_center_tag = "engineering-prod"
project_tag     = "oci-prod"

common_tags = {
  "Environment" = "production"
  "ManagedBy"   = "terraform"
  "Criticality" = "high"
}

#####################
# State Backend
#####################
state_bucket_name = "terraform-state-prod"
#####################
# Apps - Immich photo library
# See apps/immich/README.md for operation, data locations, and upgrades
#####################
apps_immich = {
  enabled             = true
  shape               = "VM.Standard.A1.Flex"
  ocpus               = 4
  memory_in_gbs       = 24
  data_volume_size_gb = 200
  library_mount       = "/srv/apps/immich"
  install_dir         = "/srv/apps/immich/app"
  immich_version      = "release"
  allowed_lb_cidrs    = ["10.20.1.0/24", "10.20.2.0/24", "10.20.3.0/24"]
}
