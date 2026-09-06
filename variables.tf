#####################
# Authentication
#####################

variable "tenancy_ocid" {
  description = "OCID of the tenancy."
  type        = string
}

variable "region" {
  description = "OCI region to deploy into."
  type        = string
}

variable "compartment_ocid" {
  description = "Compartment to create resources in. Defaults to the tenancy root."
  type        = string
  default     = ""
}

variable "user_ocid" {
  description = "OCID of the API user. Empty falls back to ~/.oci/config."
  type        = string
  default     = ""
}

variable "fingerprint" {
  description = "Fingerprint of the API signing key."
  type        = string
  default     = ""
}

variable "private_key" {
  description = "PEM contents of the API signing key."
  type        = string
  default     = ""
  sensitive   = true
}

#####################
# Naming
#####################

variable "name_prefix" {
  description = "Prefix for every resource name. Keep it short and unique."
  type        = string
  default     = "immich"
}

#####################
# Network
#####################

variable "vcn_cidr" {
  description = "CIDR block for the VCN."
  type        = string
  default     = "10.30.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the single public subnet."
  type        = string
  default     = "10.30.1.0/24"
}

variable "ssh_ingress_cidr" {
  description = "CIDR allowed to reach SSH. Narrow this to your own IP if you can."
  type        = string
  default     = "0.0.0.0/0"
}

#####################
# Compute
#####################

variable "instance_ocpus" {
  description = <<-EOT
    OCPUs for the Immich instance. The Always Free Ampere allowance is capped
    per tenancy; exceeding it fails the apply with a limit error. Check yours
    with: oci limits value list --service-name compute \
      --query 'data[?name==`standard-a1-core-regional-count`]'
  EOT
  type        = number
  default     = 2
}

variable "instance_memory_gb" {
  description = "Memory (GB) for the Immich instance. Ampere allows 6 GB per OCPU."
  type        = number
  default     = 12
}

variable "boot_volume_gb" {
  description = "Boot volume size. Counts against the 200 GB Always Free block storage total."
  type        = number
  default     = 50
}

variable "data_volume_gb" {
  description = <<-EOT
    Block volume for the Immich photo library and its Postgres data.
    boot_volume_gb + data_volume_gb must stay within the Always Free 200 GB
    block storage total, or the volume creation fails.
  EOT
  type        = number
  default     = 150
}

variable "ssh_public_key" {
  description = "SSH public key authorized on the instance. Required - without it the instance is unreachable."
  type        = string

  validation {
    condition     = can(regex("^(ssh-rsa|ssh-ed25519|ecdsa-sha2-) ", var.ssh_public_key))
    error_message = "ssh_public_key must be an OpenSSH public key, e.g. the contents of ~/.ssh/id_ed25519.pub."
  }
}

#####################
# Immich
#####################

variable "immich_version" {
  description = "Immich release tag to run, or 'release' for the latest."
  type        = string
  default     = "release"
}

variable "library_mount" {
  description = "Mount point for the data volume that holds the Immich library."
  type        = string
  default     = "/srv/immich"
}

variable "domain_name" {
  description = <<-EOT
    Public DNS name pointing at the instance. When set, Caddy obtains a
    Let's Encrypt certificate and serves Immich over HTTPS. When empty,
    Immich is served over plain HTTP on port 80.
  EOT
  type        = string
  default     = ""
}

variable "acme_email" {
  description = "Contact address for Let's Encrypt. Only used when domain_name is set."
  type        = string
  default     = ""
}

#####################
# Tagging
#####################

variable "tags" {
  description = "Freeform tags applied to every resource."
  type        = map(string)
  default = {
    managed_by = "terraform"
    app        = "immich"
  }
}

variable "availability_domain_index" {
  description = <<-EOT
    Which availability domain to place the instance in. Ampere A1 capacity is
    frequently exhausted in a given AD; if the apply fails with "Out of host
    capacity", try the next index. Single-AD regions only accept 0.
  EOT
  type        = number
  default     = 0
}
