# OCI Provider Configuration with Multiple Authentication Methods
# This file provides provider configuration supporting:
# 1. Instance Principals (when running in OCI)
# 2. API Keys (local development, GitHub Actions hosted runners)
# 3. Resource Principals (for OCI Functions, etc.)
# 4. Security Token (for OIDC federation)

#####################
# Provider: OCI
#####################

provider "oci" {
  # Region - required
  region = var.oci_region

  # Tenancy OCID - required for all auth methods
  tenancy_ocid = var.oci_tenancy_ocid

  # =============================================
  # Authentication Method 1: Instance Principals
  # Used when running on OCI Compute, OKE, GitHub Actions self-hosted in OCI
  # =============================================
  # No additional configuration needed - automatically detected
  # when running on an OCI instance with instance principal enabled
  
  # =============================================
  # Authentication Method 2: API Key (Config File)
  # Used for local development and GitHub-hosted runners
  # =============================================
  # Configured via:
  # - user_ocid, fingerprint, private_key_path, private_key_passphrase
  # - OR via ~/.oci/config file (DEFAULT profile)
  
  user_ocid           = var.oci_user_ocid != "" ? var.oci_user_ocid : null
  fingerprint         = var.oci_fingerprint != "" ? var.oci_fingerprint : null
  private_key_path    = var.oci_private_key_path != "" ? var.oci_private_key_path : null
  private_key_passphrase = var.oci_private_key_passphrase != "" ? var.oci_private_key_passphrase : null

  # =============================================
  # Authentication Method 3: Security Token (OIDC)
  # For GitHub Actions OIDC federation (future)
  # =============================================
  # security_token_file = var.oci_security_token_file
  # private_key_file    = var.oci_private_key_file

  # =============================================
  # Retry Configuration
  # =============================================
  max_retries = 3

  # =============================================
  # Logging (for debugging)
  # =============================================
  # log_requests = true
}

#####################
# Provider: TLS (for generating self-signed certs if needed)
#####################

provider "tls" {}

#####################
# Provider: Random (for generating passwords, IDs)
#####################

provider "random" {}

#####################
# Provider: Time (for time-based resources)
#####################

provider "time" {}

#####################
# Aliased Providers (for multi-region if needed in future)
#####################

# provider "oci" {
#   alias  = "home_region"
#   region = var.oci_home_region
#   tenancy_ocid = var.oci_tenancy_ocid
# }

#####################
# Data Sources for Provider Validation
#####################

data "oci_identity_tenancy" "current" {}

# Verify provider can authenticate and list availability domains
data "oci_identity_availability_domains" "validate" {
  compartment_id = var.root_compartment_ocid
}

#####################
# Output Provider Info
#####################

output "provider_auth_method" {
  description = "Detected authentication method"
  value = var.oci_user_ocid != "" ? "api_key" : "instance_principal"
}

output "provider_region" {
  description = "Configured OCI region"
  value = var.oci_region
}

output "provider_tenancy" {
  description = "Configured tenancy OCID"
  value = var.oci_tenancy_ocid
}

output "available_ads" {
  description = "Available availability domains"
  value = data.oci_identity_availability_domains.validate.availability_domains[*].name
}