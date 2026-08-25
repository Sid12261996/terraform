# Database Module Variables

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