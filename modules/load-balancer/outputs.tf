# Load Balancer Module Outputs

output "public_lb_id" {
  description = "Public Load Balancer OCID"
  value       = var.create_public_lb ? oci_load_balancer_load_balancer.public[0].id : null
}

output "public_lb_ips" {
  description = "Public Load Balancer IP addresses"
  value       = var.create_public_lb ? oci_load_balancer_load_balancer.public[0].ip_addresses : []
}

output "private_lb_id" {
  description = "Private Load Balancer OCID"
  value       = var.create_private_lb ? oci_load_balancer_load_balancer.private[0].id : null
}

output "private_lb_ips" {
  description = "Private Load Balancer IP addresses"
  value       = var.create_private_lb ? oci_load_balancer_load_balancer.private[0].ip_addresses : []
}

output "backend_set_names" {
  description = "Load Balancer backend set names"
  value = {
    public  = var.create_public_lb ? oci_load_balancer_backend_set.public[0].name : null
    private = var.create_private_lb ? oci_load_balancer_backend_set.private[0].name : null
  }
}

output "listeners" {
  description = "Load Balancer listener details"
  value = {
    public_http  = var.create_public_lb ? oci_load_balancer_listener.public_http[0].name : null
    public_https = var.create_public_lb && var.ssl_certificate_id != "" ? oci_load_balancer_listener.public_https[0].name : null
    private_http = var.create_private_lb ? oci_load_balancer_listener.private_http[0].name : null
    private_tcp  = var.create_private_lb ? oci_load_balancer_listener.private_tcp[0].name : null
  }
}