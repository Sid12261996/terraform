# Compute Module
# Creates compute instances with flexible shapes, SSH keys, metadata, and user data

#####################
# Inputs
#####################

#####################
# Data Sources
#####################

# Default Oracle Linux x86_64 image for non-ARM shapes
data "oci_core_images" "oracle_linux_x86" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Oracle Linux"
  operating_system_version = "8"
  shape                    = "VM.Standard.E4.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# Default Oracle Linux aarch64 image for Ampere ARM shapes
data "oci_core_images" "oracle_linux_aarch64" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Oracle Linux"
  operating_system_version = "8"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

#####################
# Locals
#####################

locals {
  # Architecture-aware default image per pool: A1 (arm64) shapes get aarch64
  # images, all other shapes get x86_64 images. Explicit instance_images win.
  pool_image_ids = {
    for name, cfg in var.instance_shapes :
    name => (
      try(var.instance_images[name], "") != "" ?
      var.instance_images[name] :
      (
        startswith(cfg.shape, "VM.Standard.A1") ?
        data.oci_core_images.oracle_linux_aarch64.images[0].id :
        data.oci_core_images.oracle_linux_x86.images[0].id
      )
    )
  }

  # Effective user_data per pool: per-pool override wins over global value
  pool_user_data = {
    for name in keys(var.instance_shapes) :
    name => lookup(var.instance_user_data, name, var.user_data)
  }
}

#####################
# Instance Pools (using instance configurations)
#####################

resource "oci_core_instance_configuration" "instance_configs" {
  for_each = var.instance_shapes

  compartment_id = var.compartment_ocid
  display_name   = "ic-${each.key}"

  instance_details {
    instance_type = "compute"

    launch_details {
      shape = each.value.shape

      shape_config {
        ocpus         = each.value.shape_config_ocpus != null ? each.value.shape_config_ocpus : each.value.ocpus
        memory_in_gbs = each.value.shape_config_memory_in_gbs != null ? each.value.shape_config_memory_in_gbs : each.value.memory_in_gbs
      }

      source_details {
        source_type = "image"
        # Architecture-aware: custom image if provided, else latest matching image
        image_id = local.pool_image_ids[each.key]
      }

      create_vnic_details {
        subnet_id        = var.subnet_ocids[keys(var.subnet_ocids)[0]] # Default to first subnet
        nsg_ids          = var.nsg_ocids
        assign_public_ip = var.assign_public_ip
      }

      metadata = merge(
        var.instance_metadata,
        {
          "ssh_authorized_keys" = join("\n", var.ssh_public_keys)
          "user_data"           = local.pool_user_data[each.key]
        }
      )
    }
  }

  freeform_tags = var.common_tags
}

resource "oci_core_instance_pool" "instance_pools" {
  for_each = var.instance_shapes

  compartment_id            = var.compartment_ocid
  display_name              = "pool-${each.key}"
  instance_configuration_id = oci_core_instance_configuration.instance_configs[each.key].id
  size                      = var.instance_counts[each.key]

  placement_configurations {
    availability_domain = var.availability_domains[0].name
    primary_subnet_id   = var.subnet_ocids[keys(var.subnet_ocids)[0]]
  }

  freeform_tags = var.common_tags
}

# Instance members of each pool (used by outputs to report OCIDs/IPs)
data "oci_core_instance_pool_instances" "pools" {
  for_each = oci_core_instance_pool.instance_pools

  compartment_id   = var.compartment_ocid
  instance_pool_id = each.value.id
}

#####################
# Locals
#####################

locals {
  # Flatten pools with small counts into individual instance specs.
  # Each spec keeps its pool name so instances can be grouped per pool in outputs.
  individual_instances = merge([
    for pool_name, n in var.instance_counts : {
      for i in range(n) :
      "${pool_name}-${i + 1}" => {
        pool_name = pool_name
        slot      = i
      }
    } if n > 0 && n <= 3
  ]...)
}

#####################
# Individual Instances (for more control)
#####################

# Create individual instances when counts are small or specific placement needed
resource "oci_core_instance" "instances" {
  for_each = local.individual_instances

  compartment_id = var.compartment_ocid
  display_name   = each.key

  shape = var.instance_shapes[each.value.pool_name].shape

  launch_options {
    # CKV_OCI_4: encrypt boot volume traffic in transit
    is_pv_encryption_in_transit_enabled = true
  }

  instance_options {
    # CKV_OCI_5: disable legacy instance metadata service endpoints
    are_legacy_imds_endpoints_disabled = true
  }

  shape_config {
    ocpus         = coalesce(var.instance_shapes[each.value.pool_name].shape_config_ocpus, var.instance_shapes[each.value.pool_name].ocpus)
    memory_in_gbs = coalesce(var.instance_shapes[each.value.pool_name].shape_config_memory_in_gbs, var.instance_shapes[each.value.pool_name].memory_in_gbs)
  }

  source_details {
    source_type = "image"
    # Architecture-aware: custom image if provided, else latest matching image
    source_id = local.pool_image_ids[each.value.pool_name]
  }

  create_vnic_details {
    subnet_id        = var.subnet_ocids[element(keys(var.subnet_ocids), each.value.slot % length(var.subnet_ocids))]
    nsg_ids          = var.nsg_ocids
    assign_public_ip = var.assign_public_ip
  }

  metadata = merge(
    var.instance_metadata,
    {
      "ssh_authorized_keys" = join("\n", var.ssh_public_keys)
      "user_data"           = local.pool_user_data[each.value.pool_name]
    }
  )

  availability_domain = var.availability_domains[each.value.slot % length(var.availability_domains)].name

  freeform_tags = var.common_tags
}

#####################
# Dedicated Block Volumes (per pool)
#####################

# One data volume per configured pool. Volumes live outside the instance
# lifecycle, so replacing an instance preserves the attached data volume.
resource "oci_core_volume" "app_data" {
  for_each = var.data_volumes

  availability_domain = var.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  display_name        = "${each.key}-data"
  size_in_gbs         = each.value.size_in_gbs

  freeform_tags = var.common_tags
}

resource "oci_core_volume_attachment" "app_data" {
  for_each = oci_core_volume.app_data

  attachment_type = "paravirtualized"
  display_name    = "${each.key}-data-attachment"
  instance_id     = oci_core_instance.instances["${each.key}-1"].id
  volume_id       = each.value.id
}

#####################
# Outputs
#####################
