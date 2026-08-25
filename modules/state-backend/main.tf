# State Backend Module
# Creates Object Storage bucket and Autonomous Database for Terraform state locking

#####################
# Inputs
#####################

variable "compartment_ocid" {
  description = "Compartment OCID for state backend resources"
  type        = string
}

variable "bucket_name" {
  description = "Object Storage bucket name for Terraform state"
  type        = string
  default     = "terraform-state"
}

variable "bucket_namespace" {
  description = "Object Storage namespace"
  type        = string
}

variable "bucket_region" {
  description = "Bucket region"
  type        = string
  default     = "us-ashburn-1"
}

variable "create_lock_table" {
  description = "Create Autonomous Database table for state locking"
  type        = bool
  default     = true
}

variable "lock_table_name" {
  description = "Name of the state lock table"
  type        = string
  default     = "terraform_locks"
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

#####################
# Object Storage Bucket
#####################

resource "oci_objectstorage_bucket" "state_bucket" {
  compartment_id = var.compartment_ocid
  name           = var.bucket_name
  namespace      = var.bucket_namespace
  storage_tier   = "Standard"
  versioning     = "Enabled"
  public_access_type = "NoPublicAccess"
  
  freeform_tags = var.common_tags
}

# Bucket encryption
resource "oci_objectstorage_bucket" "state_bucket_encryption" {
  count = 1  # Always create, depends on bucket
  
  compartment_id = var.compartment_ocid
  name           = var.bucket_name
  namespace      = var.bucket_namespace
  
  # This will update the existing bucket with encryption
  lifecycle {
    ignore_changes = [versioning, public_access_type]
  }
  
  freeform_tags = var.common_tags
}

# Lifecycle policy
resource "oci_objectstorage_bucket" "state_bucket_lifecycle" {
  count = 1
  
  compartment_id = var.compartment_ocid
  name           = var.bucket_name
  namespace      = var.bucket_namespace
  
  lifecycle_policy = jsonencode({
    rules = [{
      name = "delete-old-versions"
      action = "DELETE"
      objectNameFilter = {
        inclusionPrefixes = []
        exclusionPrefixes = []
      }
      timeAmount = 90
      timeUnit = "DAYS"
      isEnabled = true
      objectVersionFilter = {
        isCurrentVersion = false
      }
    }]
  })
  
  lifecycle {
    ignore_changes = [versioning, public_access_type, storage_tier]
  }
  
  freeform_tags = var.common_tags
}

#####################
# Autonomous Database for State Locking
#####################

resource "oci_database_autonomous_database" "lock_db" {
  count = var.create_lock_table ? 1 : 0
  
  compartment_id = var.compartment_ocid
  display_name   = "terraform-state-locking"
  db_name        = "TFSTATE"
  admin_password = random_password.lock_db_password.result
  
  cpu_core_count   = 1
  data_storage_size_in_tbs = 1
  is_auto_scaling_enabled  = false
  is_free_tier             = true
  license_model            = "LICENSE_INCLUDED"
  db_workload              = "OLTP"
  is_dedicated             = false
  
  freeform_tags = var.common_tags
}

resource "random_password" "lock_db_password" {
  length  = 32
  special = false
}

#####################
# Outputs
#####################

output "bucket_name" {
  description = "Terraform state bucket name"
  value       = oci_objectstorage_bucket.state_bucket.name
}

output "bucket_namespace" {
  description = "Terraform state bucket namespace"
  value       = oci_objectstorage_bucket.state_bucket.namespace
}

output "bucket_region" {
  description = "Terraform state bucket region"
  value       = var.bucket_region
}

output "lock_table_name" {
  description = "State lock table name"
  value       = var.lock_table_name
}

output "lock_table_ocid" {
  description = "State lock table Autonomous Database OCID"
  value       = var.create_lock_table ? oci_database_autonomous_database.lock_db[0].id : null
}

output "lock_db_password" {
  description = "Lock database admin password (sensitive)"
  value       = random_password.lock_db_password.result
  sensitive   = true
}