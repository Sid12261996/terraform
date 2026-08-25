# Identity Module Variables

variable "root_compartment_ocid" {
  description = "Root compartment OCID (usually tenancy)"
  type        = string
}

variable "environment_compartment_name" {
  description = "Name for environment compartment"
  type        = string
}

variable "functional_compartment_names" {
  description = "List of functional compartment names to create"
  type        = list(string)
  default     = ["network", "compute", "database", "identity", "lb"]
}

variable "admin_groups" {
  description = "Map of admin group names to compartment OCIDs they manage"
  type        = map(list(string))
  default     = {}
}

variable "dynamic_groups" {
  description = "Map of dynamic group names to matching rules"
  type        = map(string)
  default     = {}
}

variable "tag_namespace_name" {
  description = "Tag namespace name"
  type        = string
  default     = "governance"
}

variable "tag_keys" {
  description = "Defined tag keys in the namespace"
  type        = list(string)
  default     = ["environment", "owner", "cost-center", "project"]
}

variable "tag_defaults" {
  description = "Tag defaults to apply on compartments"
  type        = map(map(string))
  default     = {}
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}