# Network Module
# Creates VCN, subnets, gateways, route tables, security lists, NSGs, DHCP options

#####################
# Inputs
#####################

variable "compartment_ocid" {
  description = "Compartment OCID for network resources"
  type        = string
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
  type        = list(object({
    name = string
  }))
  default     = []
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

#####################
# VCN
#####################

resource "oci_core_vcn" "main" {
  compartment_id = var.compartment_ocid
  cidr_block     = var.vcn_cidr_block
  dns_label      = var.vcn_dns_label
  display_name   = var.vcn_display_name
  freeform_tags  = var.common_tags
}

#####################
# Internet Gateway
#####################

resource "oci_core_internet_gateway" "igw" {
  count         = var.create_internet_gateway ? 1 : 0
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.vcn_display_name}-igw"
  is_enabled     = true
  freeform_tags  = var.common_tags
}

#####################
# NAT Gateway
#####################

resource "oci_core_nat_gateway" "nat" {
  count         = var.create_nat_gateway ? 1 : 0
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.vcn_display_name}-nat"
  block_traffic  = false
  freeform_tags  = var.common_tags
}

#####################
# Service Gateway
#####################

resource "oci_core_service_gateway" "sgw" {
  count         = var.create_service_gateway ? 1 : 0
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.vcn_display_name}-sgw"
  services = [{
    service_name = "All ${var.oci_region} Services in Oracle Services Network"
  }]
  freeform_tags = var.common_tags
}

#####################
# Route Tables
#####################

# Public route table (with IGW)
resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.vcn_display_name}-public-rt"
  
  route_rules = concat([
    {
      network_entity_id = oci_core_internet_gateway.igw[0].id
      destination       = "0.0.0.0/0"
      destination_type  = "CIDR_BLOCK"
      description       = "Internet Gateway"
    }
  ], var.create_service_gateway ? [{
    network_entity_id = oci_core_service_gateway.sgw[0].id
    destination       = "All ${var.oci_region} Services in Oracle Services Network"
    destination_type  = "SERVICE_CIDR_BLOCK"
    description       = "Service Gateway"
  }] : [])
  
  freeform_tags = var.common_tags
}

# Private route table (with NAT GW and SGW)
resource "oci_core_route_table" "private" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.vcn_display_name}-private-rt"
  
  route_rules = concat(
    var.create_nat_gateway ? [{
      network_entity_id = oci_core_nat_gateway.nat[0].id
      destination       = "0.0.0.0/0"
      destination_type  = "CIDR_BLOCK"
      description       = "NAT Gateway"
    }] : [],
    var.create_service_gateway ? [{
      network_entity_id = oci_core_service_gateway.sgw[0].id
      destination       = "All ${var.oci_region} Services in Oracle Services Network"
      destination_type  = "SERVICE_CIDR_BLOCK"
      description       = "Service Gateway"
    }] : []
  )
  
  freeform_tags = var.common_tags
}

#####################
# Security Lists
#####################

resource "oci_core_security_list" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.vcn_display_name}-public-sl"
  
  ingress_security_rules = [
    for rule in var.security_list_rules.ingress : {
      protocol  = rule.protocol
      source    = rule.source
      stateless = rule.stateless
      tcp_options = rule.protocol == "6" ? {
        destination_port_range = { min = rule.ports.min, max = rule.ports.max }
      } : null
      udp_options = rule.protocol == "17" ? {
        destination_port_range = { min = rule.ports.min, max = rule.ports.max }
      } : null
      icmp_options = rule.protocol == "1" ? {
        type = rule.ports.min
        code = rule.ports.max
      } : null
      description = rule.description
    }
  ]
  
  egress_security_rules = [
    for rule in var.security_list_rules.egress : {
      protocol  = rule.protocol
      destination = rule.destination
      stateless = rule.stateless
      tcp_options = rule.protocol == "6" ? {
        destination_port_range = { min = rule.ports.min, max = rule.ports.max }
      } : null
      udp_options = rule.protocol == "17" ? {
        destination_port_range = { min = rule.ports.min, max = rule.ports.max }
      } : null
      icmp_options = rule.protocol == "1" ? {
        type = rule.ports.min
        code = rule.ports.max
      } : null
      description = rule.description
    }
  ]
  
  freeform_tags = var.common_tags
}

#####################
# Network Security Groups
#####################

resource "oci_core_network_security_group" "app" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.vcn_display_name}-app-nsg"
  freeform_tags  = var.common_tags
}

resource "oci_core_network_security_group" "db" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.vcn_display_name}-db-nsg"
  freeform_tags  = var.common_tags
}

resource "oci_core_network_security_group" "lb" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.vcn_display_name}-lb-nsg"
  freeform_tags  = var.common_tags
}

# NSG Security Rules
resource "oci_core_network_security_group_security_rule" "app_ingress" {
  for_each = { for i, rule in var.nsg_rules["app"].ingress : i => rule }
  
  network_security_group_id = oci_core_network_security_group.app.id
  direction                 = "INGRESS"
  protocol                  = each.value.protocol
  source                    = each.value.source
  source_type               = "CIDR_BLOCK"
  stateless                 = each.value.stateless
  tcp_options = each.value.protocol == "6" ? {
    destination_port_range = { min = each.value.ports.min, max = each.value.ports.max }
  } : null
  udp_options = each.value.protocol == "17" ? {
    destination_port_range = { min = each.value.ports.min, max = each.value.ports.max }
  } : null
  icmp_options = each.value.protocol == "1" ? {
    type = each.value.ports.min
    code = each.value.ports.max
  } : null
  description = each.value.description
}

resource "oci_core_network_security_group_security_rule" "app_egress" {
  for_each = { for i, rule in var.nsg_rules["app"].egress : i => rule }
  
  network_security_group_id = oci_core_network_security_group.app.id
  direction                 = "EGRESS"
  protocol                  = each.value.protocol
  destination               = each.value.destination
  destination_type          = "CIDR_BLOCK"
  stateless                 = each.value.stateless
  tcp_options = each.value.protocol == "6" ? {
    destination_port_range = { min = each.value.ports.min, max = each.value.ports.max }
  } : null
  udp_options = each.value.protocol == "17" ? {
    destination_port_range = { min = each.value.ports.min, max = each.value.ports.max }
  } : null
  icmp_options = each.value.protocol == "1" ? {
    type = each.value.ports.min
    code = each.value.ports.max
  } : null
  description = each.value.description
}

resource "oci_core_network_security_group_security_rule" "db_ingress" {
  for_each = { for i, rule in var.nsg_rules["db"].ingress : i => rule }
  
  network_security_group_id = oci_core_network_security_group.db.id
  direction                 = "INGRESS"
  protocol                  = each.value.protocol
  source                    = each.value.source
  source_type               = "CIDR_BLOCK"
  stateless                 = each.value.stateless
  tcp_options = each.value.protocol == "6" ? {
    destination_port_range = { min = each.value.ports.min, max = each.value.ports.max }
  } : null
  udp_options = each.value.protocol == "17" ? {
    destination_port_range = { min = each.value.ports.min, max = each.value.ports.max }
  } : null
  icmp_options = each.value.protocol == "1" ? {
    type = each.value.ports.min
    code = each.value.ports.max
  } : null
  description = each.value.description
}

resource "oci_core_network_security_group_security_rule" "db_egress" {
  for_each = { for i, rule in var.nsg_rules["db"].egress : i => rule }
  
  network_security_group_id = oci_core_network_security_group.db.id
  direction                 = "EGRESS"
  protocol                  = each.value.protocol
  destination               = each.value.destination
  destination_type          = "CIDR_BLOCK"
  stateless                 = each.value.stateless
  tcp_options = each.value.protocol == "6" ? {
    destination_port_range = { min = each.value.ports.min, max = each.value.ports.max }
  } : null
  udp_options = each.value.protocol == "17" ? {
    destination_port_range = { min = each.value.ports.min, max = each.value.ports.max }
  } : null
  icmp_options = each.value.protocol == "1" ? {
    type = each.value.ports.min
    code = each.value.ports.max
  } : null
  description = each.value.description
}

resource "oci_core_network_security_group_security_rule" "lb_ingress" {
  for_each = { for i, rule in var.nsg_rules["lb"].ingress : i => rule }
  
  network_security_group_id = oci_core_network_security_group.lb.id
  direction                 = "INGRESS"
  protocol                  = each.value.protocol
  source                    = each.value.source
  source_type               = "CIDR_BLOCK"
  stateless                 = each.value.stateless
  tcp_options = each.value.protocol == "6" ? {
    destination_port_range = { min = each.value.ports.min, max = each.value.ports.max }
  } : null
  udp_options = each.value.protocol == "17" ? {
    destination_port_range = { min = each.value.ports.min, max = each.value.ports.max }
  } : null
  icmp_options = each.value.protocol == "1" ? {
    type = each.value.ports.min
    code = each.value.ports.max
  } : null
  description = each.value.description
}

resource "oci_core_network_security_group_security_rule" "lb_egress" {
  for_each = { for i, rule in var.nsg_rules["lb"].egress : i => rule }
  
  network_security_group_id = oci_core_network_security_group.lb.id
  direction                 = "EGRESS"
  protocol                  = each.value.protocol
  destination               = each.value.destination
  destination_type          = "CIDR_BLOCK"
  stateless                 = each.value.stateless
  tcp_options = each.value.protocol == "6" ? {
    destination_port_range = { min = each.value.ports.min, max = each.value.ports.max }
  } : null
  udp_options = each.value.protocol == "17" ? {
    destination_port_range = { min = each.value.ports.min, max = each.value.ports.max }
  } : null
  icmp_options = each.value.protocol == "1" ? {
    type = each.value.ports.min
    code = each.value.ports.max
  } : null
  description = each.value.description
}

#####################
# Subnets
#####################

# Public subnets (one per AD)
resource "oci_core_subnet" "public" {
  for_each = var.public_subnet_cidrs
  
  compartment_id        = var.compartment_ocid
  vcn_id                = oci_core_vcn.main.id
  cidr_block            = each.value
  display_name          = "${var.vcn_display_name}-public-${each.key}"
  dns_label             = "public${each.key}"
  availability_domain   = each.key
  route_table_id        = oci_core_route_table.public.id
  security_list_ids     = [oci_core_security_list.public.id]
  dhcp_options_id       = oci_core_dhcp_options.main.id
  prohibit_public_ip_on_vnic = false
  freeform_tags         = var.common_tags
}

# Private subnets (one per AD)
resource "oci_core_subnet" "private" {
  for_each = var.private_subnet_cidrs
  
  compartment_id        = var.compartment_ocid
  vcn_id                = oci_core_vcn.main.id
  cidr_block            = each.value
  display_name          = "${var.vcn_display_name}-private-${each.key}"
  dns_label             = "private${each.key}"
  availability_domain   = each.key
  route_table_id        = oci_core_route_table.private.id
  security_list_ids     = [oci_core_security_list.public.id]
  dhcp_options_id       = oci_core_dhcp_options.main.id
  prohibit_public_ip_on_vnic = true
  freeform_tags         = var.common_tags
}

#####################
# DHCP Options
#####################

resource "oci_core_dhcp_options" "main" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.vcn_display_name}-dhcp"
  
  options = {
    dhcp_dns_type = var.dhcp_dns_type
    custom_dns_servers = var.dhcp_dns_type == "Custom" ? var.dhcp_custom_dns : []
    search_domain = var.dhcp_search_domain
  }
  
  freeform_tags = var.common_tags
}

#####################
# Outputs
#####################

output "vcn_id" {
  description = "VCN OCID"
  value       = oci_core_vcn.main.id
}

output "vcn_cidr_block" {
  description = "VCN CIDR block"
  value       = oci_core_vcn.main.cidr_block
}

output "public_subnet_ocids" {
  description = "Public subnet OCIDs by AD"
  value       = { for k, v in oci_core_subnet.public : k => v.id }
}

output "private_subnet_ocids" {
  description = "Private subnet OCIDs by AD"
  value       = { for k, v in oci_core_subnet.private : k => v.id }
}

output "internet_gateway_id" {
  description = "Internet Gateway OCID"
  value       = var.create_internet_gateway ? oci_core_internet_gateway.igw[0].id : null
}

output "nat_gateway_id" {
  description = "NAT Gateway OCID"
  value       = var.create_nat_gateway ? oci_core_nat_gateway.nat[0].id : null
}

output "service_gateway_id" {
  description = "Service Gateway OCID"
  value       = var.create_service_gateway ? oci_core_service_gateway.sgw[0].id : null
}

output "route_table_ocids" {
  description = "Route table OCIDs"
  value = {
    public  = oci_core_route_table.public.id
    private = oci_core_route_table.private.id
  }
}

output "security_list_ocids" {
  description = "Security list OCIDs"
  value = {
    public = oci_core_security_list.public.id
  }
}

output "app_nsg_ocid" {
  description = "App NSG OCID"
  value       = oci_core_network_security_group.app.id
}

output "db_nsg_ocid" {
  description = "DB NSG OCID"
  value       = oci_core_network_security_group.db.id
}

output "lb_nsg_ocid" {
  description = "LB NSG OCID"
  value       = oci_core_network_security_group.lb.id
}

output "dhcp_options_id" {
  description = "DHCP options OCID"
  value       = oci_core_dhcp_options.main.id
}