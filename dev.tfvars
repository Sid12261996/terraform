# Development Environment Configuration
# Usage: terraform apply -var-file=dev.tfvars

#####################
# Environment
#####################
environment = "dev"

#####################
# Compartment (will be created if not provided)
#####################
# root_compartment_ocid = "ocid1.tenancy.oc1..xxxxx"  # Set via TF_VAR or GitHub secret

#####################
# Network
#####################
vcn_cidr_block = "10.0.0.0/16"
vcn_dns_label  = "devvcn"

public_subnet_cidrs = {
  "AD-1" = "10.0.1.0/24"
  "AD-2" = "10.0.2.0/24"
  "AD-3" = "10.0.3.0/24"
}

private_subnet_cidrs = {
  "AD-1" = "10.0.11.0/24"
  "AD-2" = "10.0.12.0/24"
  "AD-3" = "10.0.13.0/24"
}

#####################
# Compute - Small sizes for dev
#####################
instance_shapes = {
  "app-server" = {
    shape         = "VM.Standard.E4.Flex"
    ocpus         = 1
    memory_in_gbs = 8
  }
}

instance_counts = {
  "app-server" = 1
}

# SSH keys - add your public key here or via TF_VAR
ssh_public_keys = [
  # "ssh-rsa AAAAB3NzaC1yc2E... user@host"
]

#####################
# Load Balancer - Minimal for dev
#####################
create_public_lb = true
public_lb_min_bw = 10
public_lb_max_bw = 100

create_private_lb = false

#####################
# Database - Free tier for dev
#####################
create_atp = true
atp_config = {
  display_name             = "dev-atp"
  db_name                  = "DEVATP"
  admin_password           = "" # Set via TF_VAR_atp_admin_password
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
owner_tag       = "dev-team"
cost_center_tag = "engineering-dev"
project_tag     = "oci-dev"

common_tags = {
  "Environment" = "development"
  "ManagedBy"   = "terraform"
}

#####################
# State Backend
#####################
state_bucket_name = "terraform-state-dev"