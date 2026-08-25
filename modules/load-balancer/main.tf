# Load Balancer Module
# Creates public and private flexible load balancers with backend sets, listeners, health checks

#####################
# Inputs
#####################

#####################
# Public Load Balancer
#####################

resource "oci_load_balancer_load_balancer" "public" {
  count = var.create_public_lb ? 1 : 0

  compartment_id = var.compartment_ocid
  display_name   = "public-lb"
  shape          = var.public_lb_shape
  shape_details {
    minimum_bandwidth_in_mbps = var.public_lb_min_bw
    maximum_bandwidth_in_mbps = var.public_lb_max_bw
  }
  subnet_ids    = values(var.public_subnet_ocids)
  freeform_tags = var.common_tags
}

resource "oci_load_balancer_backend_set" "public" {
  count = var.create_public_lb ? 1 : 0

  load_balancer_id = oci_load_balancer_load_balancer.public[0].id
  name             = "public-backend-set"
  policy           = "ROUND_ROBIN"

  health_checker {
    protocol          = var.health_check_protocol
    port              = var.health_check_port
    url_path          = var.health_check_protocol == "HTTP" ? var.health_check_path : null
    interval_ms       = var.health_check_interval * 1000
    timeout_in_millis = 5000
    retries           = 3
  }

  session_persistence_configuration {
    cookie_name      = "LB_SESSION"
    disable_fallback = false
  }
}

# Backends are managed as individual resources (inline "backend" blocks are read-only).
# Keys combine the (plan-time-known) pool name with the position inside the pool so
# for_each never depends on values that are only known after apply.
locals {
  lb_backends_map = merge([
    for pool_name, ips in var.backend_servers : {
      for idx, ip in ips :
      "${pool_name}-${idx}" => {
        ip_address = ip
        port       = var.backend_port
        weight     = 1
        backup     = false
      }
    }
  ]...)
}

resource "oci_load_balancer_backend" "public_backends" {
  for_each = var.create_public_lb ? local.lb_backends_map : {}

  load_balancer_id = oci_load_balancer_load_balancer.public[0].id
  backendset_name  = oci_load_balancer_backend_set.public[0].name
  ip_address       = each.value.ip_address
  port             = each.value.port
  weight           = each.value.weight
  backup           = each.value.backup
}

resource "oci_load_balancer_listener" "public_http" {
  count = var.create_public_lb ? 1 : 0

  load_balancer_id         = oci_load_balancer_load_balancer.public[0].id
  name                     = "http-listener"
  protocol                 = "HTTP"
  port                     = 80
  default_backend_set_name = oci_load_balancer_backend_set.public[0].name
}

resource "oci_load_balancer_listener" "public_https" {
  count = var.create_public_lb && var.ssl_certificate_id != "" ? 1 : 0

  load_balancer_id         = oci_load_balancer_load_balancer.public[0].id
  name                     = "https-listener"
  protocol                 = "HTTPS"
  port                     = 443
  default_backend_set_name = oci_load_balancer_backend_set.public[0].name
  ssl_configuration {
    certificate_ids         = [var.ssl_certificate_id]
    verify_depth            = 1
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
  shape          = var.private_lb_shape
  shape_details {
    minimum_bandwidth_in_mbps = var.private_lb_min_bw
    maximum_bandwidth_in_mbps = var.private_lb_max_bw
  }
  subnet_ids    = values(var.private_subnet_ocids)
  is_private    = true
  freeform_tags = var.common_tags
}

resource "oci_load_balancer_backend_set" "private" {
  count = var.create_private_lb ? 1 : 0

  load_balancer_id = oci_load_balancer_load_balancer.private[0].id
  name             = "private-backend-set"
  policy           = "LEAST_CONNECTIONS"

  health_checker {
    protocol          = var.health_check_protocol
    port              = var.health_check_port
    url_path          = var.health_check_protocol == "HTTP" ? var.health_check_path : null
    interval_ms       = var.health_check_interval * 1000
    timeout_in_millis = 5000
    retries           = 3
  }

  session_persistence_configuration {
    cookie_name      = "LB_SESSION"
    disable_fallback = false
  }
}

resource "oci_load_balancer_backend" "private_backends" {
  for_each = var.create_private_lb ? local.lb_backends_map : {}

  load_balancer_id = oci_load_balancer_load_balancer.private[0].id
  backendset_name  = oci_load_balancer_backend_set.private[0].name
  ip_address       = each.value.ip_address
  port             = each.value.port
  weight           = each.value.weight
  backup           = each.value.backup
}

resource "oci_load_balancer_listener" "private_http" {
  count = var.create_private_lb ? 1 : 0

  load_balancer_id         = oci_load_balancer_load_balancer.private[0].id
  name                     = "http-listener"
  protocol                 = "HTTP"
  port                     = 80
  default_backend_set_name = oci_load_balancer_backend_set.private[0].name
}

resource "oci_load_balancer_listener" "private_tcp" {
  count = var.create_private_lb ? 1 : 0

  load_balancer_id         = oci_load_balancer_load_balancer.private[0].id
  name                     = "tcp-listener"
  protocol                 = "TCP"
  port                     = 3306 # Database port
  default_backend_set_name = oci_load_balancer_backend_set.private[0].name
}

#####################
# SSL Certificate Association
# Uses the certificate managed by the OCI Certificates service directly
# (referenced by OCID) instead of uploading cert material to the LB.

#####################
# Outputs
#####################
