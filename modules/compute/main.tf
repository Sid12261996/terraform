# Compute Module
# Creates compute instances with flexible shapes, SSH keys, metadata, and user data

#####################
# Inputs
#####################

#####################
# Data Sources
#####################

# Default Oracle Linux image if not specified
data "oci_core_images" "oracle_linux" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Oracle Linux"
  operating_system_version = "8"
  shape                    = "VM.Standard.E4.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
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
        # Use a custom image when provided per pool, otherwise the latest Oracle Linux image
        image_id = try(var.instance_images[each.key], "") != "" ? var.instance_images[each.key] : data.oci_core_images.oracle_linux.images[0].id
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
          "user_data"           = var.user_data
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
    source_id   = try(var.instance_images[each.value.pool_name], "") != "" ? var.instance_images[each.value.pool_name] : data.oci_core_images.oracle_linux.images[0].id
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
      "user_data"           = var.user_data
    }
  )

  availability_domain = var.availability_domains[each.value.slot % length(var.availability_domains)].name

  freeform_tags = var.common_tags
}

#####################
# Outputs
#####################
