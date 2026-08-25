# Network Module Outputs

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