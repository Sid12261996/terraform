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
  # OCI load balancers accept at most 2 subnet_ids (in different ADs);
  # passing one per AD-keyed subnet map entry over-subscribes that limit
  # in multi-AD regions and is rejected outright in single-AD regions,
  # so just use one subnet.
  subnet_ids    = [values(var.public_subnet_ocids)[0]]
  freeform_tags = var.common_tags

  # A healthy LB provisions in a couple of minutes; a quota-blocked one
  # otherwise leaves Terraform polling a stuck work request for the
  # provider's default (much longer) timeout before reporting failure.
  timeouts {
    create = "15m"
  }
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
# Additional Named Service Routes (public LB)
#####################

# One backend set + listener per named route so multiple services with distinct
# ports can share the public load balancer. The default backend set and its
# listeners above are untouched.
resource "oci_load_balancer_backend_set" "routes" {
  for_each = var.create_public_lb ? var.additional_routes : {}

  load_balancer_id = oci_load_balancer_load_balancer.public[0].id
  name             = "${each.key}-backend-set"
  policy           = "ROUND_ROBIN"

  health_checker {
    protocol          = each.value.health_check_protocol
    port              = coalesce(each.value.health_check_port, each.value.backend_port)
    url_path          = each.value.health_check_protocol == "HTTP" ? each.value.health_check_path : null
    interval_ms       = each.value.health_check_interval_ms
    timeout_in_millis = each.value.health_check_timeout_ms
    retries           = each.value.health_check_retries
  }

  session_persistence_configuration {
    cookie_name      = "${each.key}_LB_SESSION"
    disable_fallback = false
  }
}

locals {
  lb_route_backends_map = merge([
    for route_name in keys(var.additional_routes) : {
      for idx, ip in lookup(var.route_backends, route_name, []) :
      "${route_name}-${idx}" => {
        route_name = route_name
        ip_address = ip
      }
    }
  ]...)
}

resource "oci_load_balancer_backend" "route_backends" {
  for_each = var.create_public_lb ? local.lb_route_backends_map : {}

  load_balancer_id = oci_load_balancer_load_balancer.public[0].id
  backendset_name  = oci_load_balancer_backend_set.routes[each.value.route_name].name
  ip_address       = each.value.ip_address
  port             = var.additional_routes[each.value.route_name].backend_port
  weight           = 1
}

resource "oci_load_balancer_listener" "routes" {
  for_each = var.create_public_lb ? var.additional_routes : {}

  load_balancer_id         = oci_load_balancer_load_balancer.public[0].id
  name                     = "${each.key}-listener"
  protocol                 = each.value.protocol
  port                     = each.value.listener_port
  default_backend_set_name = oci_load_balancer_backend_set.routes[each.key].name
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
  # Private load balancers require exactly one subnet.
  subnet_ids    = [values(var.private_subnet_ocids)[0]]
  is_private    = true
  freeform_tags = var.common_tags

  timeouts {
    create = "15m"
  }
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

resource "oci_load_balancer_backend_set" "private_tcp" {
  count = var.create_private_lb ? 1 : 0

  load_balancer_id = oci_load_balancer_load_balancer.private[0].id
  name             = "private-tcp-backend-set"
  policy           = "LEAST_CONNECTIONS"

  health_checker {
    protocol          = "TCP"
    port              = 3306
    interval_ms       = var.health_check_interval * 1000
    timeout_in_millis = 5000
    retries           = 3
  }
}

resource "oci_load_balancer_listener" "private_tcp" {
  count = var.create_private_lb ? 1 : 0

  load_balancer_id = oci_load_balancer_load_balancer.private[0].id
  name             = "tcp-listener"
  protocol         = "TCP"
  port             = 3306 # Database port
  # A backend set's listeners must share one protocol, so the TCP
  # listener needs its own backend set separate from the HTTP one.
  default_backend_set_name = oci_load_balancer_backend_set.private_tcp[0].name
}

#####################
# SSL Certificate Association
# Uses the certificate managed by the OCI Certificates service directly
# (referenced by OCID) instead of uploading cert material to the LB.

#####################
# Outputs
#####################
