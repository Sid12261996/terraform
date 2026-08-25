# Staging Environment Configuration
# Usage: terraform apply -var-file=staging.tfvars

#####################
# Environment
#####################
environment = "staging"

#####################
# Compartment (will be created if not provided)
#####################
# root_compartment_ocid = "ocid1.tenancy.oc1..xxxxx"  # Set via TF_VAR or GitHub secret

#####################
# Network
#####################
vcn_cidr_block = "10.10.0.0/16"
vcn_dns_label  = "stgvcn"

public_subnet_cidrs = {
  "AD-1" = "10.10.1.0/24"
  "AD-2" = "10.10.2.0/24"
  "AD-3" = "10.10.3.0/24"
}

private_subnet_cidrs = {
  "AD-1" = "10.10.11.0/24"
  "AD-2" = "10.10.12.0/24"
  "AD-3" = "10.10.13.0/24"
}

#####################
# Compute - Medium sizes for staging
#####################
instance_shapes = {
  "app-server" = {
    shape       = "VM.Standard.E4.Flex"
    ocpus       = 2
    memory_in_gbs = 16
  }
}

instance_counts = {
  "app-server" = 2
}

ssh_public_keys = [
  # "ssh-rsa AAAAB3NzaC1yc2E... user@host"
]

#####################
# Load Balancer
#####################
create_public_lb  = true
public_lb_min_bw  = 100
public_lb_max_bw  = 1000

create_private_lb = true
private_lb_min_bw = 100
private_lb_max_bw = 500

#####################
# Database
#####################
create_atp = true
atp_config = {
  display_name             = "staging-atp"
  db_name                  = "STGATP"
  admin_password           = ""  # Set via TF_VAR_atp_admin_password
  cpu_core_count           = 2
  data_storage_size_in_tbs = 1
  is_auto_scaling_enabled  = true
  is_free_tier             = false
  license_model            = "LICENSE_INCLUDED"
}

create_adw = false
create_db_system = false

#####################
# Tagging
#####################
owner_tag       = "platform-team"
cost_center_tag = "engineering-staging"
project_tag     = "oci-staging"

common_tags = {
  "Environment" = "staging"
  "ManagedBy"   = "terraform"
}

#####################
# State Backend
#####################
state_bucket_name = "terraform-state-staging"