# State Backend Module Outputs

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