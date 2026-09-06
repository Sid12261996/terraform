provider "oci" {
  region       = var.region
  tenancy_ocid = var.tenancy_ocid

  # API-key auth. In CI these come from repository secrets; locally they are
  # left empty and the provider falls back to ~/.oci/config.
  user_ocid   = var.user_ocid != "" ? var.user_ocid : null
  fingerprint = var.fingerprint != "" ? var.fingerprint : null
  private_key = var.private_key != "" ? var.private_key : null
}
