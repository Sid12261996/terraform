# Database Module
# Creates Autonomous Database (ATP/ADW) and DB Systems

#####################
# Inputs
#####################

#####################
# Autonomous Transaction Processing
#####################

resource "oci_database_autonomous_database" "atp" {
  count = var.create_atp ? 1 : 0

  compartment_id = var.compartment_ocid
  display_name   = var.atp_config.display_name
  db_name        = var.atp_config.db_name
  admin_password = var.atp_config.admin_password

  cpu_core_count           = var.atp_config.cpu_core_count
  data_storage_size_in_tbs = var.atp_config.data_storage_size_in_tbs
  is_auto_scaling_enabled  = var.atp_config.is_auto_scaling_enabled
  is_free_tier             = var.atp_config.is_free_tier
  license_model            = var.atp_config.license_model

  db_workload  = "OLTP"
  is_dedicated = false

  nsg_ids   = var.atp_config.nsg_ids
  subnet_id = var.atp_config.subnet_id

  private_endpoint_label = var.atp_config.private_endpoint_label
  private_endpoint_ip    = var.atp_config.private_endpoint_ip

  is_preview_version_with_service_terms_accepted = false
  whitelisted_ips                                = []

  freeform_tags = var.common_tags
}

#####################
# Autonomous Data Warehouse
#####################

resource "oci_database_autonomous_database" "adw" {
  count = var.create_adw ? 1 : 0

  compartment_id = var.compartment_ocid
  display_name   = var.adw_config.display_name
  db_name        = var.adw_config.db_name
  admin_password = var.adw_config.admin_password

  cpu_core_count           = var.adw_config.cpu_core_count
  data_storage_size_in_tbs = var.adw_config.data_storage_size_in_tbs
  is_auto_scaling_enabled  = var.adw_config.is_auto_scaling_enabled
  is_free_tier             = var.adw_config.is_free_tier
  license_model            = var.adw_config.license_model

  db_workload  = "DW"
  is_dedicated = false

  nsg_ids   = var.adw_config.nsg_ids
  subnet_id = var.adw_config.subnet_id

  private_endpoint_label = var.adw_config.private_endpoint_label
  private_endpoint_ip    = var.adw_config.private_endpoint_ip

  freeform_tags = var.common_tags
}

#####################
# DB System
#####################

locals {
  # DNS-safe hostname derived from the display name
  db_hostname = substr(replace(lower(var.db_system_config.display_name), "/[^a-z0-9-]/", "-"), 0, 30)
}

resource "oci_database_db_system" "db_system" {
  count = var.create_db_system ? 1 : 0

  availability_domain = var.db_system_config.availability_domain
  compartment_id      = var.compartment_ocid
  display_name        = var.db_system_config.display_name
  shape               = var.db_system_config.shape
  subnet_id           = var.db_system_config.subnet_id

  hostname                = local.db_hostname
  ssh_public_keys         = var.ssh_public_keys
  node_count              = var.db_system_config.node_count
  license_model           = var.db_system_config.license_model
  data_storage_size_in_gb = var.db_system_config.data_storage_size_in_gbs
  nsg_ids                 = var.db_system_config.nsg_ids

  db_home {
    display_name = "${var.db_system_config.display_name}-dbhome"
    db_version   = var.db_system_config.db_version

    database {
      admin_password = var.db_system_config.admin_password
      db_name        = replace(local.db_hostname, "-", "")
    }
  }

  freeform_tags = var.common_tags
}

# Standby DB System for Data Guard
resource "oci_database_db_system" "standby_db_system" {
  count = var.create_db_system && var.db_system_config.enable_dataguard ? 1 : 0

  availability_domain = var.db_system_config.standby_availability_domain != "" ? var.db_system_config.standby_availability_domain : var.db_system_config.availability_domain
  compartment_id      = var.compartment_ocid
  display_name        = "${var.db_system_config.display_name}-standby"
  shape               = var.db_system_config.shape
  subnet_id           = var.db_system_config.subnet_id

  hostname                = "${local.db_hostname}-sb"
  ssh_public_keys         = var.ssh_public_keys
  node_count              = var.db_system_config.node_count
  license_model           = var.db_system_config.license_model
  data_storage_size_in_gb = var.db_system_config.data_storage_size_in_gbs
  nsg_ids                 = var.db_system_config.nsg_ids

  source_db_system_id = oci_database_db_system.db_system[0].id

  db_home {
    display_name = "${var.db_system_config.display_name}-standby-dbhome"
    db_version   = var.db_system_config.db_version

    database {
      admin_password = var.db_system_config.admin_password
      db_name        = replace(local.db_hostname, "-", "")
    }
  }

  freeform_tags = var.common_tags
}

#####################
# Backup Configuration
#####################

resource "oci_database_autonomous_database_backup" "atp_backup" {
  count = var.create_atp ? 1 : 0

  autonomous_database_id = oci_database_autonomous_database.atp[0].id
  display_name           = "${var.atp_config.display_name}-backup"
}

resource "oci_database_autonomous_database_backup" "adw_backup" {
  count = var.create_adw ? 1 : 0

  autonomous_database_id = oci_database_autonomous_database.adw[0].id
  display_name           = "${var.adw_config.display_name}-backup"
}

#####################
# Wallet Generation
#####################

data "oci_database_autonomous_database_wallet" "atp_wallet" {
  count = var.create_atp ? 1 : 0

  autonomous_database_id = oci_database_autonomous_database.atp[0].id
  password               = var.atp_config.admin_password
  base64_encode_content  = true
}

data "oci_database_autonomous_database_wallet" "adw_wallet" {
  count = var.create_adw ? 1 : 0

  autonomous_database_id = oci_database_autonomous_database.adw[0].id
  password               = var.adw_config.admin_password
  base64_encode_content  = true
}

#####################
# Outputs
#####################
