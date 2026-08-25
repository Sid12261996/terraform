# Load Balancer Module
# Creates public and private flexible load balancers with backend sets, listeners, health checks

#####################
# Inputs
#####################

variable "compartment_ocid" {
  description = "Compartment OCID for load balancer resources"
  type        = string
}

variable "create_public_lb" {
  description = "Create public load balancer"
  type        = bool
  default     = true
}

variable "public_lb_shape" {
  description = "Public LB shape (flexible or fixed)"
  type        = string
  default     = "flexible"
}

variable "public_lb_min_bw" {
  description = "Public LB minimum bandwidth (Mbps)"
  type        = number
  default     = 100
}

variable "public_lb_max_bw" {
  description = "Public LB maximum bandwidth (Mbps)"
  type        = number
  default     = 8000
}

variable "create_private_lb" {
  description = "Create private load balancer"
  type        = bool
  default     = true
}

variable "private_lb_shape" {
  description = "Private LB shape (flexible or fixed)"
  type        = string
  default     = "flexible"
}

variable "private_lb_min_bw" {
  description = "Private LB minimum bandwidth (Mbps)"
  type        = number
  default     = 100
}

variable "private_lb_max_bw" {
  description = "Private LB maximum bandwidth (Mbps)"
  type        = number
  default     = 4000
}

variable "public_subnet_ocids" {
  description = "Public subnet OCIDs for public LB"
  type        = map(string)
}

variable "private_subnet_ocids" {
  description = "Private subnet OCIDs for private LB"
  type        = map(string)
}

variable "backend_servers" {
  description = "Backend server private IPs"
  type        = map(list(string))
  default     = {}
}

variable "backend_port" {
  description = "Backend server port"
  type        = number
  default     = 8080
}

variable "health_check_protocol" {
  description = "Health check protocol (HTTP, TCP)"
  type        = string
  default     = "HTTP"
}

variable "health_check_path" {
  description = "Health check path (for HTTP)"
  type        = string
  default     = "/health"
}

variable "health_check_port" {
  description = "Health check port"
  type        = number
  default     = 8080
}

variable "health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 30
}

variable "ssl_certificate_id" {
  description = "OCI Certificates service certificate OCID for HTTPS"
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

#####################
# Public Load Balancer
#####################

resource "oci_load_balancer_load_balancer" "public" {
  count = var.create_public_lb ? 1 : 0
  
  compartment_id = var.compartment_ocid
  display_name   = "public-lb"
  shape_name     = var.public_lb_shape
  shape_details {
    minimum_bandwidth_in_mbps = var.public_lb_min_bw
    maximum_bandwidth_in_mbps = var.public_lb_max_bw
  }
  subnet_ids = values(var.public_subnet_ocids)
  freeform_tags = var.common_tags
}

resource "oci_load_balancer_backend_set" "public" {
  count = var.create_public_lb ? 1 : 0
  
  load_balancer_id = oci_load_balancer_load_balancer.public[0].id
  name             = "public-backend-set"
  policy           = "ROUND_ROBIN"
  
  backends = flatten([
    for pool_name, ips in var.backend_servers :
    [for ip in ips : {
      ip_address = ip
      port       = var.backend_port
      weight     = 1
      backup     = false
    }]
  ])
  
  health_checker {
    protocol = var.health_check_protocol
    port     = var.health_check_port
    url_path = var.health_check_protocol == "HTTP" ? var.health_check_path : null
    interval_in_ms = var.health_check_interval * 1000
    timeout_in_ms  = 5000
    retries        = 3
  }
  
  session_persistence_config {
    cookie_name = "LB_SESSION"
    disable_fallback = false
  }
}

resource "oci_load_balancer_listener" "public_http" {
  count = var.create_public_lb ? 1 : 0
  
  load_balancer_id = oci_load_balancer_load_balancer.public[0].id
  name             = "http-listener"
  protocol         = "HTTP"
  port             = 80
  default_backend_set_name = oci_load_balancer_backend_set.public[0].name
}

resource "oci_load_balancer_listener" "public_https" {
  count = var.create_public_lb && var.ssl_certificate_id != "" ? 1 : 0
  
  load_balancer_id = oci_load_balancer_load_balancer.public[0].id
  name             = "https-listener"
  protocol         = "HTTPS"
  port             = 443
  default_backend_set_name = oci_load_balancer_backend_set.public[0].name
  ssl_configuration {
    certificate_name = "public-cert"
    verify_depth     = 1
    verify_peer_certificate = false
  }
}

#####################
# Private Load Balancer
#####################

resource "oci_load_balancer_load_balancer" "private" {
  count = var.create_private_lb ? 1 : 0
  
  compartment_id = var.compartment_ocid
  display_name   = "private-lb"
  shape_name     = var.private_lb_shape
  shape_details {
    minimum_bandwidth_in_mbps = var.private_lb_min_bw
    maximum_bandwidth_in_mbps = var.private_lb_max_bw
  }
  subnet_ids = values(var.private_subnet_ocids)
  is_private = true
  freeform_tags = var.common_tags
}

resource "oci_load_balancer_backend_set" "private" {
  count = var.create_private_lb ? 1 : 0
  
  load_balancer_id = oci_load_balancer_load_balancer.private[0].id
  name             = "private-backend-set"
  policy           = "LEAST_CONNECTIONS"
  
  backends = flatten([
    for pool_name, ips in var.backend_servers :
    [for ip in ips : {
      ip_address = ip
      port       = var.backend_port
      weight     = 1
      backup     = false
    }]
  ])
  
  health_checker {
    protocol = var.health_check_protocol
    port     = var.health_check_port
    url_path = var.health_check_protocol == "HTTP" ? var.health_check_path : null
    interval_in_ms = var.health_check_interval * 1000
    timeout_in_ms  = 5000
    retries        = 3
  }
  
  session_persistence_config {
    cookie_name = "LB_SESSION"
    disable_fallback = false
  }
}

resource "oci_load_balancer_listener" "private_http" {
  count = var.create_private_lb ? 1 : 0
  
  load_balancer_id = oci_load_balancer_load_balancer.private[0].id
  name             = "http-listener"
  protocol         = "HTTP"
  port             = 80
  default_backend_set_name = oci_load_balancer_backend_set.private[0].name
}

resource "oci_load_balancer_listener" "private_tcp" {
  count = var.create_private_lb ? 1 : 0
  
  load_balancer_id = oci_load_balancer_load_balancer.private[0].id
  name             = "tcp-listener"
  protocol         = "TCP"
  port             = 3306  # Database port
  default_backend_set_name = oci_load_balancer_backend_set.private[0].name
}

#####################
# SSL Certificate Association
#####################

resource "oci_load_balancer_certificate" "public_cert" {
  count = var.create_public_lb && var.ssl_certificate_id != "" ? 1 : 0
  
  load_balancer_id = oci_load_balancer_load_balancer.public[0].id
  certificate_name = "public-cert"
  public_certificate = data.oci_certificates_certificate_bundle.public.certificate
  private_key        = data.oci_certificates_certificate_bundle.public.private_key
  ca_certificate     = data.oci_certificates_certificate_bundle.public.ca_certificate
}

data "oci_certificates_certificate_bundle" "public" {
  count = var.ssl_certificate_id != "" ? 1 : 0
  
  certificate_id = var.ssl_certificate_id
  stage          = "CURRENT"
}

#####################
# Outputs
#####################

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