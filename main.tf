# OCI Full-Stack Terraform Configuration
# Monolithic root module with internal modules
#
# Provider configuration and provider data sources live in providers.tf

#####################
# Data Sources
#####################

# List availability domains for placement across the stack
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.root_compartment_ocid
}

# Tenancy object storage namespace (required by object storage resources).
# Resolved automatically so the state backend works during bootstrap.
data "oci_objectstorage_namespace" "this" {
  compartment_id = var.root_compartment_ocid
}

#####################
# Locals
#####################

locals {
  # Environment-specific settings
  env = var.environment

  # Compartment hierarchy: root -> environment -> functional
  compartment_hierarchy = {
    root        = var.root_compartment_ocid
    environment = var.environment_compartment_ocid
    functional = {
      network  = var.network_compartment_ocid
      compute  = var.compute_compartment_ocid
      database = var.database_compartment_ocid
      identity = var.identity_compartment_ocid
      lb       = var.lb_compartment_ocid
    }
  }

  # Common tags applied to all resources.
  # NOTE: OCI forbids periods and spaces in freeform tag keys, so use
  # underscore separators here (dots are only valid in defined tags).
  common_tags = merge(
    var.common_tags,
    {
      "governance_environment" = var.environment
      "governance_owner"       = var.owner_tag
      "governance_cost_center" = var.cost_center_tag
      "governance_project"     = var.project_tag
    }
  )

  # Availability domains
  availability_domains = data.oci_identity_availability_domains.ads.availability_domains

  #####################
  # Apps: Immich photo library (gated by enabled; see apps/immich/README.md)
  #####################
  apps_immich_enabled = var.apps_immich.enabled

  instance_shapes_effective = local.apps_immich_enabled ? merge(var.instance_shapes, {
    "immich" = {
      shape                      = var.apps_immich.shape
      ocpus                      = var.apps_immich.ocpus
      memory_in_gbs              = var.apps_immich.memory_in_gbs
      shape_config_ocpus         = null
      shape_config_memory_in_gbs = null
    }
  }) : var.instance_shapes

  instance_counts_effective = local.apps_immich_enabled ? merge(var.instance_counts, {
    "immich" = 1
  }) : var.instance_counts

  data_volumes_effective = local.apps_immich_enabled ? {
    "immich" = { size_in_gbs = var.apps_immich.data_volume_size_gb }
  } : {}

  immich_user_data = base64encode(templatefile("${path.module}/apps/immich/cloud-init.yml.tftpl", {
    library_mount  = var.apps_immich.library_mount
    install_dir    = var.apps_immich.install_dir
    immich_version = var.apps_immich.immich_version
  }))
  instance_user_data_effective = local.apps_immich_enabled ? {
    "immich" = local.immich_user_data
  } : {}

  # Allow only the public LB subnets to reach the Immich backend on port 2283
  nsg_rules_effective = local.apps_immich_enabled ? merge(var.nsg_rules, {
    "app" = merge(var.nsg_rules["app"], {
      ingress = concat(
        var.nsg_rules["app"].ingress,
        [
          for cidr in var.apps_immich.allowed_lb_cidrs :
          {
            protocol    = "6"
            source      = cidr
            stateless   = false
            ports       = { min = 2283, max = 2283 }
            description = "Immich via public LB"
          }
        ]
      )
    })
  }) : var.nsg_rules

  additional_routes_effective = local.apps_immich_enabled ? {
    "immich" = {
      listener_port            = 2283
      protocol                 = "HTTP"
      backend_port             = 2283
      health_check_protocol    = "HTTP"
      health_check_path        = "/api/server/ping"
      health_check_port        = null
      health_check_interval_ms = 30000
      health_check_timeout_ms  = 5000
      health_check_retries     = 3
    }
  } : {}
}

#####################
# Module: Identity (must run first for compartment hierarchy)
#####################

module "identity" {
  source = "./modules/identity"

  root_compartment_ocid        = var.root_compartment_ocid
  environment_compartment_name = var.environment
  functional_compartment_names = ["network", "compute", "database", "identity", "lb"]

  # Groups
  admin_groups   = var.admin_groups
  dynamic_groups = var.dynamic_groups

  # Tagging
  tag_namespace_name = var.tag_namespace_name
  tag_keys           = var.defined_tag_keys

  # Tag defaults
  tag_defaults = var.tag_defaults

  common_tags = local.common_tags
}

#####################
# Module: Network
#####################

module "network" {
  source = "./modules/network"

  compartment_ocid = module.identity.functional_compartment_ocids["network"]

  vcn_cidr_block   = var.vcn_cidr_block
  vcn_dns_label    = var.vcn_dns_label
  vcn_display_name = "${var.environment}-vcn"

  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs

  # Gateway configuration
  create_internet_gateway = true
  create_nat_gateway      = true
  create_service_gateway  = true

  # Security
  security_list_rules = var.security_list_rules
  nsg_rules           = local.nsg_rules_effective

  # DNS
  dhcp_dns_type      = var.dhcp_dns_type
  dhcp_custom_dns    = var.dhcp_custom_dns
  dhcp_search_domain = var.dhcp_search_domain

  availability_domains = local.availability_domains

  common_tags = local.common_tags
}

#####################
# Module: Compute
#####################

module "compute" {
  source = "./modules/compute"

  compartment_ocid = module.identity.functional_compartment_ocids["compute"]

  # Instance configuration
  instance_shapes = local.instance_shapes_effective
  instance_images = var.instance_images
  instance_counts = local.instance_counts_effective
  data_volumes    = local.data_volumes_effective

  # Network
  subnet_ocids     = module.network.private_subnet_ocids
  nsg_ocids        = [module.network.app_nsg_ocid]
  assign_public_ip = false

  # SSH keys
  ssh_public_keys = var.ssh_public_keys

  # Metadata
  instance_metadata  = var.instance_metadata
  user_data          = var.user_data
  instance_user_data = local.instance_user_data_effective

  availability_domains = local.availability_domains

  common_tags = local.common_tags
}

#####################
# Module: Load Balancer
#####################

module "load_balancer" {
  source = "./modules/load-balancer"

  compartment_ocid = module.identity.functional_compartment_ocids["lb"]

  # Public LB
  create_public_lb    = var.create_public_lb
  public_lb_shape     = var.public_lb_shape
  public_lb_min_bw    = var.public_lb_min_bw
  public_lb_max_bw    = var.public_lb_max_bw
  public_subnet_ocids = module.network.public_subnet_ocids

  # Private LB
  create_private_lb    = var.create_private_lb
  private_lb_shape     = var.private_lb_shape
  private_lb_min_bw    = var.private_lb_min_bw
  private_lb_max_bw    = var.private_lb_max_bw
  private_subnet_ocids = module.network.private_subnet_ocids

  # Backend configuration - default set serves the generic app pool(s);
  # dedicated apps like immich get their own named route below.
  backend_servers = {
    for pool_name, ips in module.compute.instance_private_ips :
    pool_name => ips
    if !local.apps_immich_enabled || pool_name != "immich"
  }
  backend_port = var.backend_port

  # Additional named service routes (e.g., Immich on 2283)
  additional_routes = local.additional_routes_effective
  route_backends = local.apps_immich_enabled ? {
    "immich" = lookup(module.compute.instance_private_ips, "immich", [])
  } : {}

  # Health checks
  health_check_protocol = var.health_check_protocol
  health_check_path     = var.health_check_path
  health_check_port     = var.health_check_port
  health_check_interval = var.health_check_interval

  # SSL
  ssl_certificate_id = var.ssl_certificate_id

  common_tags = local.common_tags
}

#####################
# Module: Database
#####################

module "database" {
  source = "./modules/database"

  compartment_ocid = module.identity.functional_compartment_ocids["database"]

  # Autonomous Database
  create_atp = var.create_atp
  atp_config = var.atp_config

  create_adw = var.create_adw
  adw_config = var.adw_config

  # DB Systems
  create_db_system = var.create_db_system
  db_system_config = var.db_system_config

  # Network
  subnet_ocids = module.network.private_subnet_ocids
  nsg_ocids    = [module.network.db_nsg_ocid]

  # Access
  ssh_public_keys = var.ssh_public_keys

  # Backup
  backup_retention_days = var.backup_retention_days

  common_tags = local.common_tags
}

#####################
# Module: State Backend (Bootstrap)
#####################

module "state_backend" {
  source = "./modules/state-backend"

  compartment_ocid = var.root_compartment_ocid

  bucket_name      = var.state_bucket_name
  bucket_namespace = var.state_bucket_namespace != "" ? var.state_bucket_namespace : data.oci_objectstorage_namespace.this.namespace
  bucket_region    = var.oci_region

  create_lock_table = var.create_state_lock_table
  lock_table_name   = var.state_lock_table_name

  common_tags = local.common_tags
}