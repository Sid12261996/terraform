# Database Module
# Creates Autonomous Database (ATP/ADW) and DB Systems

#####################
# Inputs
#####################

variable "compartment_ocid" {
  description = "Compartment OCID for database resources"
  type        = string
}

variable "create_atp" {
  description = "Create Autonomous Transaction Processing database"
  type        = bool
  default     = true
}

variable "atp_config" {
  description = "ATP configuration"
  type = object({
    display_name        = string
    db_name             = string
    admin_password      = string
    cpu_core_count      = number
    data_storage_size_in_tbs = number
    is_auto_scaling_enabled = bool
    is_free_tier        = bool
    license_model       = string
    nsg_ids             = list(string)
    subnet_id           = string
    private_endpoint_label = optional(string)
    private_endpoint_ip   = optional(string)
  })
}

variable "create_adw" {
  description = "Create Autonomous Data Warehouse database"
  type        = bool
  default     = false
}

variable "adw_config" {
  description = "ADW configuration"
  type = object({
    display_name        = string
    db_name             = string
    admin_password      = string
    cpu_core_count      = number
    data_storage_size_in_tbs = number
    is_auto_scaling_enabled = bool
    is_free_tier        = bool
    license_model       = string
    nsg_ids             = list(string)
    subnet_id           = string
    private_endpoint_label = optional(string)
    private_endpoint_ip   = optional(string)
  })
}

variable "create_db_system" {
  description = "Create DB System (VM or Bare Metal)"
  type        = bool
  default     = false
}

variable "db_system_config" {
  description = "DB System configuration"
  type = object({
    display_name           = string
    shape                  = string
    node_count             = number
    db_version             = string
    admin_password         = string
    license_model          = string
    storage_management     = string
    data_storage_size_in_gbs = number
    nsg_ids                = list(string)
    subnet_id              = string
    availability_domain    = string
    enable_dataguard       = bool
    standby_availability_domain = optional(string)
  })
}

variable "subnet_ocids" {
  description = "Subnet OCIDs"
  type        = map(string)
}

variable "nsg_ocids" {
  description = "NSG OCIDs"
  type        = list(string)
  default     = []
}

variable "backup_retention_days" {
  description = "Backup retention period in days"
  type        = number
  default     = 30
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

#####################
# Autonomous Transaction Processing
#####################

resource "oci_database_autonomous_database" "atp" {
  count = var.create_atp ? 1 : 0
  
  compartment_id = var.compartment_ocid
  display_name   = var.atp_config.display_name
  db_name        = var.atp_config.db_name
  admin_password = var.atp_config.admin_password
  
  cpu_core_count   = var.atp_config.cpu_core_count
  data_storage_size_in_tbs = var.atp_config.data_storage_size_in_tbs
  is_auto_scaling_enabled  = var.atp_config.is_auto_scaling_enabled
  is_free_tier             = var.atp_config.is_free_tier
  license_model            = var.atp_config.license_model
  
  db_workload = "OLTP"
  is_dedicated = false
  
  nsg_ids = var.atp_config.nsg_ids
  subnet_id = var.atp_config.subnet_id
  
  private_endpoint_label = var.atp_config.private_endpoint_label
  private_endpoint_ip    = var.atp_config.private_endpoint_ip
  
  is_preview_version_with_service_terms_accepted = false
  whitelisted_ips = []
  
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
  
  cpu_core_count   = var.adw_config.cpu_core_count
  data_storage_size_in_tbs = var.adw_config.data_storage_size_in_tbs
  is_auto_scaling_enabled  = var.adw_config.is_auto_scaling_enabled
  is_free_tier             = var.adw_config.is_free_tier
  license_model            = var.adw_config.license_model
  
  db_workload = "DW"
  is_dedicated = false
  
  nsg_ids = var.adw_config.nsg_ids
  subnet_id = var.adw_config.subnet_id
  
  private_endpoint_label = var.adw_config.private_endpoint_label
  private_endpoint_ip    = var.adw_config.private_endpoint_ip
  
  freeform_tags = var.common_tags
}

#####################
# DB System
#####################

resource "oci_database_db_system" "db_system" {
  count = var.create_db_system ? 1 : 0
  
  compartment_id = var.compartment_ocid
  display_name   = var.db_system_config.display_name
  shape          = var.db_system_config.shape
  node_count     = var.db_system_config.node_count
  db_version     = var.db_system_config.db_version
  admin_password = var.db_system_config.admin_password
  license_model  = var.db_system_config.license_model
  storage_management = var.db_system_config.storage_management
  data_storage_size_in_gbs = var.db_system_config.data_storage_size_in_gbs
  
  availability_domain = var.db_system_config.availability_domain
  subnet_id = var.db_system_config.subnet_id
  nsg_ids = var.db_system_config.nsg_ids
  
  # Data Guard
  dataguard_role = var.db_system_config.enable_dataguard ? "PRIMARY" : "DISABLED"
  
  freeform_tags = var.common_tags
}

# Standby DB System for Data Guard
resource "oci_database_db_system" "standby_db_system" {
  count = var.create_db_system && var.db_system_config.enable_dataguard ? 1 : 0
  
  compartment_id = var.compartment_ocid
  display_name   = "${var.db_system_config.display_name}-standby"
  shape          = var.db_system_config.shape
  node_count     = var.db_system_config.node_count
  db_version     = var.db_system_config.db_version
  admin_password = var.db_system_config.admin_password
  license_model  = var.db_system_config.license_model
  storage_management = var.db_system_config.storage_management
  data_storage_size_in_gbs = var.db_system_config.data_storage_size_in_gbs
  
  availability_domain = var.db_system_config.standby_availability_domain != "" ? var.db_system_config.standby_availability_domain : var.db_system_config.availability_domain
  subnet_id = var.db_system_config.subnet_id
  nsg_ids = var.db_system_config.nsg_ids
  
  dataguard_role = "STANDBY"
  source_db_system_id = oci_database_db_system.db_system[0].id
  
  freeform_tags = var.common_tags
}

#####################
# Backup Configuration
#####################

resource "oci_database_autonomous_database_backup" "atp_backup" {
  count = var.create_atp ? 1 : 0
  
  autonomous_database_id = oci_database_autonomous_database.atp[0].id
  display_name = "${var.atp_config.display_name}-backup"
  type = "FULL"
  is_automatic = false
}

resource "oci_database_autonomous_database_backup" "adw_backup" {
  count = var.create_adw ? 1 : 0
  
  autonomous_database_id = oci_database_autonomous_database.adw[0].id
  display_name = "${var.adw_config.display_name}-backup"
  type = "FULL"
  is_automatic = false
}

#####################
# Wallet Generation
#####################

data "oci_database_autonomous_database_wallet" "atp_wallet" {
  count = var.create_atp ? 1 : 0
  
  autonomous_database_id = oci_database_autonomous_database.atp[0].id
  password = var.atp_config.admin_password
}

data "oci_database_autonomous_database_wallet" "adw_wallet" {
  count = var.create_adw ? 1 : 0
  
  autonomous_database_id = oci_database_autonomous_database.adw[0].id
  password = var.adw_config.admin_password
}

#####################
# Connection Strings
#####################

data "oci_database_autonomous_database_connection_strings" "atp_connections" {
  count = var.create_atp ? 1 : 0
  
  autonomous_database_id = oci_database_autonomous_database.atp[0].id
}

data "oci_database_autonomous_database_connection_strings" "adw_connections" {
  count = var.create_adw ? 1 : 0
  
  autonomous_database_id = oci_database_autonomous_database.adw[0].id
}

#####################
# Outputs
#####################

output "atp_database" {
  description = "ATP database details"
  value = var.create_atp ? {
    id = oci_database_autonomous_database.atp[0].id
    display_name = oci_database_autonomous_database.atp[0].display_name
    db_name = oci_database_autonomous_database.atp[0].db_name
    connection_strings = oci_database_autonomous_database.atp[0].connection_strings
    lifecycle_state = oci_database_autonomous_database.atp[0].lifecycle_state
    private_endpoint_ip = oci_database_autonomous_database.atp[0].private_endpoint_ip
    private_endpoint_label = oci_database_autonomous_database.atp[0].private_endpoint_label
  } : null
  sensitive = true
}

output "adw_database" {
  description = "ADW database details"
  value = var.create_adw ? {
    id = oci_database_autonomous_database.adw[0].id
    display_name = oci_database_autonomous_database.adw[0].display_name
    db_name = oci_database_autonomous_database.adw[0].db_name
    connection_strings = oci_database_autonomous_database.adw[0].connection_strings
    lifecycle_state = oci_database_autonomous_database.adw[0].lifecycle_state
    private_endpoint_ip = oci_database_autonomous_database.adw[0].private_endpoint_ip
    private_endpoint_label = oci_database_autonomous_database.adw[0].private_endpoint_label
  } : null
  sensitive = true
}

output "db_system" {
  description = "DB System details"
  value = var.create_db_system ? {
    id = oci_database_db_system.db_system[0].id
    display_name = oci_database_db_system.db_system[0].display_name
    shape = oci_database_db_system.db_system[0].shape
    node_count = oci_database_db_system.db_system[0].node_count
    lifecycle_state = oci_database_db_system.db_system[0].lifecycle_state
    standby_id = var.db_system_config.enable_dataguard ? oci_database_db_system.standby_db_system[0].id : null
  } : null
  sensitive = true
}

output "wallets" {
  description = "Database wallet files (base64 encoded)"
  value = {
    atp = var.create_atp ? base64encode(data.oci_database_autonomous_database_wallet.atp_wallet[0].wallet) : null
    adw = var.create_adw ? base64encode(data.oci_database_autonomous_database_wallet.adw_wallet[0].wallet) : null
  }
  sensitive = true
}

output "connection_strings" {
  description = "Database connection strings"
  value = {
    atp = var.create_atp ? oci_database_autonomous_database_connection_strings.atp_connections[0].connection_strings : null
    adw = var.create_adw ? oci_database_autonomous_database_connection_strings.adw_connections[0].connection_strings : null
  }
  sensitive = true
}