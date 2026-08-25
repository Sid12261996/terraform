# State Backend Module Variables

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