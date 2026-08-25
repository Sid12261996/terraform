#####################
# Provider & Authentication
#####################

variable "oci_region" {
  description = "OCI region for all resources"
  type        = string
  default     = "us-ashburn-1"
}

variable "oci_tenancy_ocid" {
  description = "OCI Tenancy OCID"
  type        = string
}

variable "oci_user_ocid" {
  description = "OCI User OCID (for API key auth)"
  type        = string
  default     = ""
}

variable "oci_fingerprint" {
  description = "OCI API Key Fingerprint"
  type        = string
  default     = ""
}

variable "oci_private_key_path" {
  description = "Path to OCI API Private Key PEM file"
  type        = string
  default     = ""
}

variable "oci_private_key_passphrase" {
  description = "Passphrase for OCI API Private Key (if encrypted)"
  type        = string
  default     = ""
  sensitive   = true
}

#####################
# Compartment Hierarchy
#####################

variable "root_compartment_ocid" {
  description = "Root compartment OCID (usually tenancy)"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "environment_compartment_ocid" {
  description = "Environment-level compartment OCID (created by identity module if not provided)"
  type        = string
  default     = ""
}

variable "network_compartment_ocid" {
  description = "Network functional compartment OCID"
  type        = string
  default     = ""
}

variable "compute_compartment_ocid" {
  description = "Compute functional compartment OCID"
  type        = string
  default     = ""
}

variable "database_compartment_ocid" {
  description = "Database functional compartment OCID"
  type        = string
  default     = ""
}

variable "identity_compartment_ocid" {
  description = "Identity functional compartment OCID"
  type        = string
  default     = ""
}

variable "lb_compartment_ocid" {
  description = "Load Balancer functional compartment OCID"
  type        = string
  default     = ""
}

#####################
# Tagging
#####################

variable "tag_namespace_name" {
  description = "Tag namespace name for governance tags"
  type        = string
  default     = "governance"
}

variable "defined_tag_keys" {
  description = "Defined tag keys in the governance namespace"
  type        = list(string)
  default     = ["environment", "owner", "cost-center", "project"]
}

variable "common_tags" {
  description = "Common tags applied to all resources (freeform)"
  type        = map(string)
  default     = {}
}

variable "owner_tag" {
  description = "Owner tag value"
  type        = string
  default     = "platform-team"
}

variable "cost_center_tag" {
  description = "Cost center tag value"
  type        = string
  default     = "engineering"
}

variable "project_tag" {
  description = "Project tag value"
  type        = string
  default     = "oci-full-stack"
}

variable "tag_defaults" {
  description = "Tag defaults to apply on compartments"
  type        = map(map(string))
  default     = {}
}

#####################
# Identity & IAM
#####################

variable "admin_groups" {
  description = "Map of admin group names to compartment OCIDs they manage"
  type        = map(list(string))
  default = {
    "terraform-admins" = []
    "developers"       = []
    "network-admins"   = []
    "db-admins"        = []
  }
}

variable "dynamic_groups" {
  description = "Map of dynamic group names to matching rules"
  type        = map(string)
  default = {
    "instance-principals" = "ALL {instance.compartment.id = 'ROOT_COMPARTMENT_OCID'}"
  }
}

#####################
# Network
#####################

variable "vcn_cidr_block" {
  description = "CIDR block for the VCN"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vcn_dns_label" {
  description = "DNS label for the VCN"
  type        = string
  default     = "vcn"
}

variable "public_subnet_cidrs" {
  description = "Map of AD name to public subnet CIDR"
  type        = map(string)
  default = {
    "AD-1" = "10.0.1.0/24"
    "AD-2" = "10.0.2.0/24"
    "AD-3" = "10.0.3.0/24"
  }
}

variable "private_subnet_cidrs" {
  description = "Map of AD name to private subnet CIDR"
  type        = map(string)
  default = {
    "AD-1" = "10.0.11.0/24"
    "AD-2" = "10.0.12.0/24"
    "AD-3" = "10.0.13.0/24"
  }
}

variable "security_list_rules" {
  description = "Security list ingress/egress rules"
  type = object({
    ingress = list(object({
      protocol  = string
      source    = string
      stateless = bool
      ports = object({
        min = number
        max = number
      })
      description = optional(string)
    }))
    egress = list(object({
      protocol  = string
      destination = string
      stateless = bool
      ports = object({
        min = number
        max = number
      })
      description = optional(string)
    }))
  })
  default = {
    ingress = [
      { protocol = "6", source = "0.0.0.0/0", stateless = false, ports = { min = 22, max = 22 }, description = "SSH" },
      { protocol = "6", source = "0.0.0.0/0", stateless = false, ports = { min = 80, max = 80 }, description = "HTTP" },
      { protocol = "6", source = "0.0.0.0/0", stateless = false, ports = { min = 443, max = 443 }, description = "HTTPS" }
    ]
    egress = [
      { protocol = "all", destination = "0.0.0.0/0", stateless = false, ports = { min = 0, max = 0 }, description = "All egress" }
    ]
  }
}

variable "nsg_rules" {
  description = "Network Security Group rules per tier"
  type = map(object({
    ingress = list(object({
      protocol  = string
      source    = string
      stateless = bool
      ports = object({
        min = number
        max = number
      })
      description = optional(string)
    }))
    egress = list(object({
      protocol  = string
      destination = string
      stateless = bool
      ports = object({
        min = number
        max = number
      })
      description = optional(string)
    }))
  }))
  default = {
    "app" = {
      ingress = [
        { protocol = "6", source = "10.0.0.0/16", stateless = false, ports = { min = 80, max = 80 }, description = "HTTP from VCN" },
        { protocol = "6", source = "10.0.0.0/16", stateless = false, ports = { min = 443, max = 443 }, description = "HTTPS from VCN" },
        { protocol = "6", source = "10.0.0.0/16", stateless = false, ports = { min = 22, max = 22 }, description = "SSH from VCN" }
      ]
      egress = [
        { protocol = "all", destination = "0.0.0.0/0", stateless = false, ports = { min = 0, max = 0 }, description = "All egress" }
      ]
    }
    "db" = {
      ingress = [
        { protocol = "6", source = "10.0.0.0/16", stateless = false, ports = { min = 1521, max = 1521 }, description = "Oracle DB from VCN" },
        { protocol = "6", source = "10.0.0.0/16", stateless = false, ports = { min = 2484, max = 2484 }, description = "Oracle DB SSL from VCN" }
      ]
      egress = [
        { protocol = "all", destination = "0.0.0.0/0", stateless = false, ports = { min = 0, max = 0 }, description = "All egress" }
      ]
    }
    "lb" = {
      ingress = [
        { protocol = "6", source = "0.0.0.0/0", stateless = false, ports = { min = 80, max = 80 }, description = "HTTP from Internet" },
        { protocol = "6", source = "0.0.0.0/0", stateless = false, ports = { min = 443, max = 443 }, description = "HTTPS from Internet" }
      ]
      egress = [
        { protocol = "all", destination = "10.0.0.0/16", stateless = false, ports = { min = 0, max = 0 }, description = "To VCN backends" }
      ]
    }
  }
}

variable "dhcp_dns_type" {
  description = "DHCP DNS type (VcnLocal, Internet, Custom)"
  type        = string
  default     = "VcnLocal"
}

variable "dhcp_custom_dns" {
  description = "Custom DNS server IPs (when dhcp_dns_type is Custom)"
  type        = list(string)
  default     = []
}

variable "dhcp_search_domain" {
  description = "DHCP search domain"
  type        = string
  default     = ""
}

#####################
# Compute
#####################

variable "instance_shapes" {
  description = "Map of instance pool names to shape configs"
  type = map(object({
    shape                    = string
    ocpus                    = number
    memory_in_gbs            = number
    shape_config_ocpus       = optional(number)
    shape_config_memory_in_gbs = optional(number)
  }))
  default = {
    "app-server" = {
      shape       = "VM.Standard.E4.Flex"
      ocpus       = 2
      memory_in_gbs = 16
    }
  }
}

variable "instance_images" {
  description = "Map of instance pool names to image OCIDs"
  type        = map(string)
  default     = {}
}

variable "instance_counts" {
  description = "Map of instance pool names to count"
  type        = map(number)
  default = {
    "app-server" = 2
  }
}

variable "ssh_public_keys" {
  description = "List of SSH public keys to inject into instances"
  type        = list(string)
  default     = []
}

variable "instance_metadata" {
  description = "Instance metadata key-value pairs"
  type        = map(string)
  default     = {}
}

variable "user_data" {
  description = "Cloud-init user data script (base64 encoded)"
  type        = string
  default     = ""
}

#####################
# Load Balancer
#####################

variable "create_public_lb" {
  description = "Create public load balancer"
  type        = bool
  default     = true
}

variable "public_lb_shape" {
  description = "Public LB shape (flexible or fixed)"
  type        = string
  default     = "flexible"
}

variable "public_lb_min_bw" {
  description = "Public LB minimum bandwidth (Mbps)"
  type        = number
  default     = 100
}

variable "public_lb_max_bw" {
  description = "Public LB maximum bandwidth (Mbps)"
  type        = number
  default     = 8000
}

variable "create_private_lb" {
  description = "Create private load balancer"
  type        = bool
  default     = true
}

variable "private_lb_shape" {
  description = "Private LB shape (flexible or fixed)"
  type        = string
  default     = "flexible"
}

variable "private_lb_min_bw" {
  description = "Private LB minimum bandwidth (Mbps)"
  type        = number
  default     = 100
}

variable "private_lb_max_bw" {
  description = "Private LB maximum bandwidth (Mbps)"
  type        = number
  default     = 4000
}

variable "backend_port" {
  description = "Backend server port"
  type        = number
  default     = 8080
}

variable "health_check_protocol" {
  description = "Health check protocol (HTTP, TCP)"
  type        = string
  default     = "HTTP"
}

variable "health_check_path" {
  description = "Health check path (for HTTP)"
  type        = string
  default     = "/health"
}

variable "health_check_port" {
  description = "Health check port"
  type        = number
  default     = 8080
}

variable "health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 30
}

variable "ssl_certificate_id" {
  description = "OCI Certificates service certificate OCID for HTTPS"
  type        = string
  default     = ""
}

#####################
# Database
#####################

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
  default = {
    display_name             = "atp-db"
    db_name                  = "ATP_DB"
    admin_password           = ""
    cpu_core_count           = 2
    data_storage_size_in_tbs = 1
    is_auto_scaling_enabled  = true
    is_free_tier             = false
    license_model            = "LICENSE_INCLUDED"
    nsg_ids                  = []
    subnet_id                = ""
    private_endpoint_label   = ""
    private_endpoint_ip      = ""
  }
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
  default = {
    display_name             = "adw-db"
    db_name                  = "ADW_DB"
    admin_password           = ""
    cpu_core_count           = 2
    data_storage_size_in_tbs = 1
    is_auto_scaling_enabled  = true
    is_free_tier             = false
    license_model            = "LICENSE_INCLUDED"
    nsg_ids                  = []
    subnet_id                = ""
    private_endpoint_label   = ""
    private_endpoint_ip      = ""
  }
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
  default = {
    display_name                = "db-system"
    shape                       = "VM.Standard.E4.Flex"
    node_count                  = 2
    db_version                  = "19c"
    admin_password              = ""
    license_model               = "LICENSE_INCLUDED"
    storage_management          = "LVM"
    data_storage_size_in_gbs    = 256
    nsg_ids                     = []
    subnet_id                   = ""
    availability_domain         = ""
    enable_dataguard            = false
    standby_availability_domain = ""
  }
}

variable "backup_retention_days" {
  description = "Backup retention period in days"
  type        = number
  default     = 30
}

#####################
# State Backend
#####################

variable "state_bucket_name" {
  description = "Object Storage bucket name for Terraform state"
  type        = string
  default     = "terraform-state"
}

variable "state_bucket_namespace" {
  description = "Object Storage namespace"
  type        = string
}

variable "create_state_lock_table" {
  description = "Create Autonomous Database table for state locking"
  type        = bool
  default     = true
}

variable "state_lock_table_name" {
  description = "Name of the state lock table"
  type        = string
  default     = "terraform_locks"
}

#####################
# Outputs
#####################

variable "output_sensitive_values" {
  description = "Whether to output sensitive values (passwords, keys)"
  type        = bool
  default     = false
}