# State Backend Module
# Creates Object Storage bucket and Autonomous Database for Terraform state locking

#####################
# Inputs
#####################

#####################
# Object Storage Bucket
#####################

resource "oci_objectstorage_bucket" "state_bucket" {
  compartment_id        = var.compartment_ocid
  name                  = var.bucket_name
  namespace             = var.bucket_namespace
  storage_tier          = "Standard"
  versioning            = "Enabled"
  access_type           = "NoPublicAccess"
  object_events_enabled = true # CKV_OCI_7: allow bucket to emit object events

  freeform_tags = var.common_tags
}

# Object lifecycle policy: delete non-current object versions after 90 days
resource "oci_objectstorage_object_lifecycle_policy" "state_bucket" {
  namespace = var.bucket_namespace
  bucket    = oci_objectstorage_bucket.state_bucket.name

  rules {
    name        = "delete-old-versions"
    action      = "DELETE"
    time_amount = 90
    time_unit   = "DAYS"
    is_enabled  = true

    object_name_filter {
      inclusion_prefixes = []
      exclusion_patterns = []
    }
  }
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

  cpu_core_count           = 1
  data_storage_size_in_tbs = 1
  is_auto_scaling_enabled  = false
  is_free_tier             = true
  license_model            = "LICENSE_INCLUDED"
  db_workload              = "OLTP"
  is_dedicated             = false

  freeform_tags = var.common_tags
}

# Autonomous Database admin password: 12-30 chars, must include upper,
# lower, and numeric characters per OCI password policy
resource "random_password" "lock_db_password" {
  length      = 24
  special     = false
  min_upper   = 2
  min_lower   = 2
  min_numeric = 2
}

#####################
# Outputs
#####################
