# Network Module Variables

variable "compartment_ocid" {
  description = "Compartment OCID for network resources"
  type        = string
}

variable "oci_region" {
  description = "OCI region"
  type        = string
  default     = "us-ashburn-1"
}

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

variable "vcn_display_name" {
  description = "Display name for the VCN"
  type        = string
  default     = "main-vcn"
}

variable "public_subnet_cidrs" {
  description = "Map of AD name to public subnet CIDR"
  type        = map(string)
}

variable "private_subnet_cidrs" {
  description = "Map of AD name to private subnet CIDR"
  type        = map(string)
}

variable "create_internet_gateway" {
  description = "Create Internet Gateway"
  type        = bool
  default     = true
}

variable "create_nat_gateway" {
  description = "Create NAT Gateway"
  type        = bool
  default     = true
}

variable "create_service_gateway" {
  description = "Create Service Gateway"
  type        = bool
  default     = true
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
      protocol    = string
      destination = string
      stateless   = bool
      ports = object({
        min = number
        max = number
      })
      description = optional(string)
    }))
  })
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
      protocol    = string
      destination = string
      stateless   = bool
      ports = object({
        min = number
        max = number
      })
      description = optional(string)
    }))
  }))
}

variable "dhcp_dns_type" {
  description = "DHCP DNS type (VcnLocal, Internet, Custom)"
  type        = string
  default     = "VcnLocal"
}

variable "dhcp_custom_dns" {
  description = "Custom DNS server IPs"
  type        = list(string)
  default     = []
}

variable "dhcp_search_domain" {
  description = "DHCP search domain"
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