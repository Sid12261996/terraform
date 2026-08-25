# Compute Module Variables

variable "compartment_ocid" {
  description = "Compartment OCID for compute resources"
  type        = string
}

variable "instance_shapes" {
  description = "Map of instance pool names to shape configs"
  type = map(object({
    shape                      = string
    ocpus                      = number
    memory_in_gbs              = number
    shape_config_ocpus         = optional(number)
    shape_config_memory_in_gbs = optional(number)
  }))
}

variable "instance_images" {
  description = "Map of instance pool names to image OCIDs"
  type        = map(string)
  default     = {}
}

variable "instance_counts" {
  description = "Map of instance pool names to count"
  type        = map(number)
}

variable "subnet_ocids" {
  description = "Subnet OCIDs for instance placement"
  type        = map(string)
}

variable "nsg_ocids" {
  description = "NSG OCIDs to attach to instances"
  type        = list(string)
  default     = []
}

variable "assign_public_ip" {
  description = "Assign public IP to instances"
  type        = bool
  default     = false
}

variable "ssh_public_keys" {
  description = "List of SSH public keys to inject"
  type        = list(string)
  default     = []
}

variable "instance_metadata" {
  description = "Instance metadata key-value pairs"
  type        = map(string)
  default     = {}
}

variable "user_data" {
  description = "Cloud-init user data (base64 encoded)"
  type        = string
  default     = ""
}

variable "availability_domains" {
  description = "List of availability domains"
  type = list(object({
    name = string
  }))
  default = []
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
variable "instance_user_data" {
  description = "Per-pool cloud-init user data overrides (base64 encoded); falls back to user_data for unlisted pools"
  type        = map(string)
  default     = {}
}

variable "data_volumes" {
  description = "Per-pool dedicated block volumes. Only supported for pools using individual instances (count >= 1). Volumes survive instance replacement."
  type = map(object({
    size_in_gbs = number
  }))
  default = {}
}
