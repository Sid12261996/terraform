#####################
# Identity Outputs
#####################

output "compartment_ocids" {
  description = "All compartment OCIDs created"
  value = {
    root        = var.root_compartment_ocid
    environment = module.identity.environment_compartment_ocid
    network     = module.identity.functional_compartment_ocids["network"]
    compute     = module.identity.functional_compartment_ocids["compute"]
    database    = module.identity.functional_compartment_ocids["database"]
    identity    = module.identity.functional_compartment_ocids["identity"]
    lb          = module.identity.functional_compartment_ocids["lb"]
  }
}

output "iam_groups" {
  description = "IAM group OCIDs"
  value       = module.identity.group_ocids
}

output "dynamic_groups" {
  description = "Dynamic group OCIDs"
  value       = module.identity.dynamic_group_ocids
}

output "tag_namespace_ocid" {
  description = "Tag namespace OCID"
  value       = module.identity.tag_namespace_ocid
}

#####################
# Network Outputs
#####################

output "vcn_id" {
  description = "VCN OCID"
  value       = module.network.vcn_id
}

output "vcn_cidr_block" {
  description = "VCN CIDR block"
  value       = module.network.vcn_cidr_block
}

output "public_subnet_ocids" {
  description = "Public subnet OCIDs by AD"
  value       = module.network.public_subnet_ocids
}

output "private_subnet_ocids" {
  description = "Private subnet OCIDs by AD"
  value       = module.network.private_subnet_ocids
}

output "internet_gateway_id" {
  description = "Internet Gateway OCID"
  value       = module.network.internet_gateway_id
}

output "nat_gateway_id" {
  description = "NAT Gateway OCID"
  value       = module.network.nat_gateway_id
}

output "service_gateway_id" {
  description = "Service Gateway OCID"
  value       = module.network.service_gateway_id
}

output "route_table_ocids" {
  description = "Route table OCIDs"
  value       = module.network.route_table_ocids
}

output "security_list_ocids" {
  description = "Security list OCIDs"
  value       = module.network.security_list_ocids
}

output "nsg_ocids" {
  description = "Network Security Group OCIDs by tier"
  value = {
    app = module.network.app_nsg_ocid
    db  = module.network.db_nsg_ocid
    lb  = module.network.lb_nsg_ocid
  }
}

output "dhcp_options_id" {
  description = "DHCP options OCID"
  value       = module.network.dhcp_options_id
}

#####################
# Compute Outputs
#####################

output "instance_ocids" {
  description = "Compute instance OCIDs by pool"
  value       = module.compute.instance_ocids
}

output "instance_private_ips" {
  description = "Instance private IPs by pool (for LB backends)"
  value       = module.compute.instance_private_ips
}

output "instance_public_ips" {
  description = "Instance public IPs by pool (if assigned)"
  value       = module.compute.instance_public_ips
}

output "instance_shapes" {
  description = "Instance shapes by pool"
  value       = module.compute.instance_shapes
}

#####################
# Load Balancer Outputs
#####################

output "public_lb_id" {
  description = "Public Load Balancer OCID"
  value       = module.load_balancer.public_lb_id
}

output "public_lb_ips" {
  description = "Public Load Balancer IP addresses"
  value       = module.load_balancer.public_lb_ips
}

output "private_lb_id" {
  description = "Private Load Balancer OCID"
  value       = module.load_balancer.private_lb_id
}

output "private_lb_ips" {
  description = "Private Load Balancer IP addresses"
  value       = module.load_balancer.private_lb_ips
}

output "lb_backend_sets" {
  description = "Load Balancer backend set names"
  value       = module.load_balancer.backend_set_names
}

output "lb_listeners" {
  description = "Load Balancer listener details"
  value       = module.load_balancer.listeners
}

#####################
# Database Outputs
#####################

output "atp_database" {
  description = "ATP database details"
  value       = module.database.atp_database
  sensitive   = true
}

output "adw_database" {
  description = "ADW database details"
  value       = module.database.adw_database
  sensitive   = true
}

output "db_system" {
  description = "DB System details"
  value       = module.database.db_system
  sensitive   = true
}

output "database_wallets" {
  description = "Database wallet files (base64 encoded)"
  value       = module.database.wallets
  sensitive   = true
}

output "database_connection_strings" {
  description = "Database connection strings"
  value       = module.database.connection_strings
  sensitive   = true
}

#####################
# State Backend Outputs
#####################

output "state_bucket_name" {
  description = "Terraform state bucket name"
  value       = module.state_backend.bucket_name
}

output "state_bucket_namespace" {
  description = "Terraform state bucket namespace"
  value       = module.state_backend.bucket_namespace
}

output "state_lock_table_name" {
  description = "State lock table name"
  value       = module.state_backend.lock_table_name
}

output "state_lock_table_ocid" {
  description = "State lock table OCID"
  value       = module.state_backend.lock_table_ocid
}

#####################
# Summary Output
#####################

output "deployment_summary" {
  description = "Summary of all deployed resources"
  sensitive   = true
  value = {
    environment = var.environment
    region      = var.oci_region
    vcn         = module.network.vcn_id
    subnets = {
      public  = module.network.public_subnet_ocids
      private = module.network.private_subnet_ocids
    }
    gateways = {
      internet = module.network.internet_gateway_id
      nat      = module.network.nat_gateway_id
      service  = module.network.service_gateway_id
    }
    compute = {
      instances   = module.compute.instance_ocids
      private_ips = module.compute.instance_private_ips
    }
    load_balancer = {
      public  = module.load_balancer.public_lb_id
      private = module.load_balancer.private_lb_id
    }
    database = {
      atp       = module.database.atp_database
      adw       = module.database.adw_database
      db_system = module.database.db_system
    }
    state_backend = {
      bucket     = module.state_backend.bucket_name
      lock_table = module.state_backend.lock_table_name
    }
  }
}