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

# Service permission required by object lifecycle policies
# (docs.oracle.com/en-us/iaas/Content/Object/Tasks/usinglifecyclepolicies.htm).
# Without this the lifecycle PUT fails with 400-InsufficientServicePermissions.
resource "oci_identity_policy" "objectstorage_service" {
  compartment_id = var.compartment_ocid
  name           = "state-bucket-object-lifecycle"
  description    = "Allow Object Storage service to execute lifecycle policies on the state bucket"

  statements = [
    "Allow service objectstorage-${var.bucket_region} to manage object-family in compartment id ${var.compartment_ocid}"
  ]

  freeform_tags = var.common_tags
}

# IAM policies propagate asynchronously; wait so the lifecycle PUT below
# does not race the grant above.
resource "time_sleep" "wait_for_objectstorage_policy" {
  create_duration = "60s"

  depends_on = [oci_identity_policy.objectstorage_service]
}

# Object lifecycle policy: delete non-current object versions after 90 days
resource "oci_objectstorage_object_lifecycle_policy" "state_bucket" {
  namespace = var.bucket_namespace
  bucket    = oci_objectstorage_bucket.state_bucket.name

  depends_on = [time_sleep.wait_for_objectstorage_policy]

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

  # ECPU compute model is the only one accepted for new Autonomous
  # Databases; Always Free tier allows 2 ECPU.
  compute_model            = "ECPU"
  compute_count            = 2
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
