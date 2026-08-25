# Network Module
# Creates VCN, subnets, gateways, route tables, security lists, NSGs, DHCP options

#####################
# Inputs
#####################

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
  count          = var.create_internet_gateway ? 1 : 0
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.vcn_display_name}-igw"
  enabled        = true
  freeform_tags  = var.common_tags
}

#####################
# NAT Gateway
#####################

resource "oci_core_nat_gateway" "nat" {
  count          = var.create_nat_gateway ? 1 : 0
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.vcn_display_name}-nat"
  block_traffic  = false
  freeform_tags  = var.common_tags
}

#####################
# Service Gateway
#####################

# "All <region> Services in Oracle Services Network" service
data "oci_core_services" "all_osn" {}

#####################
# Route Tables
#####################

locals {
  # The Oracle Services Network entry covering all services for this region.
  # Null when the API returns nothing, which disables service-gateway
  # dependent resources instead of failing plan.
  osn_service = one([
    for s in data.oci_core_services.all_osn.services :
    {
      id   = s.id
      name = s.name
    } if can(regex("All .* Services [Ii]n Oracle Services Network", s.name))
  ])

  create_sgw = var.create_service_gateway && local.osn_service != null ? true : false

  # Route to Oracle Services Network via the Service Gateway.
  # The destination must be the service name exactly as returned by the API.
  sgw_route_rule = {
    network_entity_id = local.create_sgw ? oci_core_service_gateway.sgw[0].id : ""
    destination       = local.osn_service != null ? local.osn_service.name : ""
    destination_type  = "SERVICE_CIDR_BLOCK"
    description       = "Service Gateway"
  }
}

resource "oci_core_service_gateway" "sgw" {
  count          = local.create_sgw ? 1 : 0
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.vcn_display_name}-sgw"

  services {
    service_id = local.osn_service.id
  }

  freeform_tags = var.common_tags
}

# Public route table (with IGW)
resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.vcn_display_name}-public-rt"

  dynamic "route_rules" {
    for_each = concat([
      {
        network_entity_id = oci_core_internet_gateway.igw[0].id
        destination       = "0.0.0.0/0"
        destination_type  = "CIDR_BLOCK"
        description       = "Default route via Internet Gateway"
      }],
      local.create_sgw ? [local.sgw_route_rule] : []
    )
    iterator = rule
    content {
      network_entity_id = rule.value.network_entity_id
      destination       = rule.value.destination
      destination_type  = rule.value.destination_type
      description       = rule.value.description
    }
  }

  freeform_tags = var.common_tags
}

# Private route table (with NAT GW and SGW)
resource "oci_core_route_table" "private" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.vcn_display_name}-private-rt"

  dynamic "route_rules" {
    for_each = concat(
      var.create_nat_gateway ? [{
        network_entity_id = oci_core_nat_gateway.nat[0].id
        destination       = "0.0.0.0/0"
        destination_type  = "CIDR_BLOCK"
        description       = "Default route via NAT Gateway"
      }] : [],
      local.create_sgw ? [local.sgw_route_rule] : []
    )
    iterator = rule
    content {
      network_entity_id = rule.value.network_entity_id
      destination       = rule.value.destination
      destination_type  = rule.value.destination_type
      description       = rule.value.description
    }
  }

  freeform_tags = var.common_tags
}

#####################
# Security Lists
#####################

resource "oci_core_security_list" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.vcn_display_name}-public-sl"

  dynamic "ingress_security_rules" {
    for_each = var.security_list_rules.ingress
    iterator = rule
    content {
      protocol    = rule.value.protocol
      source      = rule.value.source
      source_type = "CIDR_BLOCK"
      stateless   = rule.value.stateless
      description = rule.value.description

      dynamic "tcp_options" {
        for_each = rule.value.protocol == "6" ? [rule.value.ports] : []
        content {
          min = tcp_options.value.min
          max = tcp_options.value.max
        }
      }

      dynamic "udp_options" {
        for_each = rule.value.protocol == "17" ? [rule.value.ports] : []
        content {
          min = udp_options.value.min
          max = udp_options.value.max
        }
      }

      dynamic "icmp_options" {
        for_each = rule.value.protocol == "1" ? [rule.value.ports] : []
        content {
          type = icmp_options.value.min
          code = icmp_options.value.max
        }
      }
    }
  }

  dynamic "egress_security_rules" {
    for_each = var.security_list_rules.egress
    iterator = rule
    content {
      protocol         = rule.value.protocol
      destination      = rule.value.destination
      destination_type = "CIDR_BLOCK"
      stateless        = rule.value.stateless
      description      = rule.value.description

      dynamic "tcp_options" {
        for_each = rule.value.protocol == "6" ? [rule.value.ports] : []
        content {
          min = tcp_options.value.min
          max = tcp_options.value.max
        }
      }

      dynamic "udp_options" {
        for_each = rule.value.protocol == "17" ? [rule.value.ports] : []
        content {
          min = udp_options.value.min
          max = udp_options.value.max
        }
      }

      dynamic "icmp_options" {
        for_each = rule.value.protocol == "1" ? [rule.value.ports] : []
        content {
          type = icmp_options.value.min
          code = icmp_options.value.max
        }
      }
    }
  }

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
  dynamic "tcp_options" {
    for_each = each.value.protocol == "6" ? [each.value.ports] : []
    content {
      destination_port_range {
        min = tcp_options.value.min
        max = tcp_options.value.max
      }
    }
  }

  dynamic "udp_options" {
    for_each = each.value.protocol == "17" ? [each.value.ports] : []
    content {
      destination_port_range {
        min = udp_options.value.min
        max = udp_options.value.max
      }
    }
  }

  dynamic "icmp_options" {
    for_each = each.value.protocol == "1" ? [each.value.ports] : []
    content {
      type = icmp_options.value.min
      code = icmp_options.value.max
    }
  }
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
  dynamic "tcp_options" {
    for_each = each.value.protocol == "6" ? [each.value.ports] : []
    content {
      destination_port_range {
        min = tcp_options.value.min
        max = tcp_options.value.max
      }
    }
  }

  dynamic "udp_options" {
    for_each = each.value.protocol == "17" ? [each.value.ports] : []
    content {
      destination_port_range {
        min = udp_options.value.min
        max = udp_options.value.max
      }
    }
  }

  dynamic "icmp_options" {
    for_each = each.value.protocol == "1" ? [each.value.ports] : []
    content {
      type = icmp_options.value.min
      code = icmp_options.value.max
    }
  }
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
  dynamic "tcp_options" {
    for_each = each.value.protocol == "6" ? [each.value.ports] : []
    content {
      destination_port_range {
        min = tcp_options.value.min
        max = tcp_options.value.max
      }
    }
  }

  dynamic "udp_options" {
    for_each = each.value.protocol == "17" ? [each.value.ports] : []
    content {
      destination_port_range {
        min = udp_options.value.min
        max = udp_options.value.max
      }
    }
  }

  dynamic "icmp_options" {
    for_each = each.value.protocol == "1" ? [each.value.ports] : []
    content {
      type = icmp_options.value.min
      code = icmp_options.value.max
    }
  }
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
  dynamic "tcp_options" {
    for_each = each.value.protocol == "6" ? [each.value.ports] : []
    content {
      destination_port_range {
        min = tcp_options.value.min
        max = tcp_options.value.max
      }
    }
  }

  dynamic "udp_options" {
    for_each = each.value.protocol == "17" ? [each.value.ports] : []
    content {
      destination_port_range {
        min = udp_options.value.min
        max = udp_options.value.max
      }
    }
  }

  dynamic "icmp_options" {
    for_each = each.value.protocol == "1" ? [each.value.ports] : []
    content {
      type = icmp_options.value.min
      code = icmp_options.value.max
    }
  }
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
  dynamic "tcp_options" {
    for_each = each.value.protocol == "6" ? [each.value.ports] : []
    content {
      destination_port_range {
        min = tcp_options.value.min
        max = tcp_options.value.max
      }
    }
  }

  dynamic "udp_options" {
    for_each = each.value.protocol == "17" ? [each.value.ports] : []
    content {
      destination_port_range {
        min = udp_options.value.min
        max = udp_options.value.max
      }
    }
  }

  dynamic "icmp_options" {
    for_each = each.value.protocol == "1" ? [each.value.ports] : []
    content {
      type = icmp_options.value.min
      code = icmp_options.value.max
    }
  }
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
  dynamic "tcp_options" {
    for_each = each.value.protocol == "6" ? [each.value.ports] : []
    content {
      destination_port_range {
        min = tcp_options.value.min
        max = tcp_options.value.max
      }
    }
  }

  dynamic "udp_options" {
    for_each = each.value.protocol == "17" ? [each.value.ports] : []
    content {
      destination_port_range {
        min = udp_options.value.min
        max = udp_options.value.max
      }
    }
  }

  dynamic "icmp_options" {
    for_each = each.value.protocol == "1" ? [each.value.ports] : []
    content {
      type = icmp_options.value.min
      code = icmp_options.value.max
    }
  }
  description = each.value.description
}

#####################
# Subnets
#####################

# Public subnets (one per AD)
resource "oci_core_subnet" "public" {
  for_each = var.public_subnet_cidrs

  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.main.id
  cidr_block                 = each.value
  display_name               = "${var.vcn_display_name}-public-${each.key}"
  dns_label                  = "public${each.key}"
  availability_domain        = each.key
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_security_list.public.id]
  dhcp_options_id            = oci_core_dhcp_options.main.id
  prohibit_public_ip_on_vnic = false
  freeform_tags              = var.common_tags
}

# Private subnets (one per AD)
resource "oci_core_subnet" "private" {
  for_each = var.private_subnet_cidrs

  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.main.id
  cidr_block                 = each.value
  display_name               = "${var.vcn_display_name}-private-${each.key}"
  dns_label                  = "private${each.key}"
  availability_domain        = each.key
  route_table_id             = oci_core_route_table.private.id
  security_list_ids          = [oci_core_security_list.public.id]
  dhcp_options_id            = oci_core_dhcp_options.main.id
  prohibit_public_ip_on_vnic = true
  freeform_tags              = var.common_tags
}

#####################
# DHCP Options
#####################

resource "oci_core_dhcp_options" "main" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.vcn_display_name}-dhcp"

  # DNS resolver options
  options {
    type               = "DomainNameServer"
    server_type        = var.dhcp_dns_type == "Custom" ? "CustomDnsServer" : "VcnLocalPlusInternet"
    custom_dns_servers = var.dhcp_dns_type == "Custom" ? var.dhcp_custom_dns : null
  }

  # Search domain
  dynamic "options" {
    for_each = var.dhcp_search_domain != "" ? [var.dhcp_search_domain] : []
    content {
      type                = "SearchDomain"
      search_domain_names = [options.value]
    }
  }

  freeform_tags = var.common_tags
}

#####################
# Outputs
#####################
