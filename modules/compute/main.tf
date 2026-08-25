# Compute Module
# Creates compute instances with flexible shapes, SSH keys, metadata, and user data

#####################
# Inputs
#####################

variable "compartment_ocid" {
  description = "Compartment OCID for compute resources"
  type        = string
}

variable "instance_shapes" {
  description = "Map of instance pool names to shape configs"
  type = map(object({
    shape                    = string
    ocpus                    = number
    memory_in_gbs            = number
    shape_config_ocpus       = optional(number)
    shape_config_memory_in_gbs = optional(number)
  }))
}

variable "instance_images" {
  description = "Map of instance pool names to image OCIDs"
  type        = map(string)
  default     = {}
}

variable "instance_counts" {
  description = "Map of instance pool names to count"
  type        = map(number)
}

variable "subnet_ocids" {
  description = "Subnet OCIDs for instance placement"
  type        = map(string)
}

variable "nsg_ocids" {
  description = "NSG OCIDs to attach to instances"
  type        = list(string)
  default     = []
}

variable "assign_public_ip" {
  description = "Assign public IP to instances"
  type        = bool
  default     = false
}

variable "ssh_public_keys" {
  description = "List of SSH public keys to inject"
  type        = list(string)
  default     = []
}

variable "instance_metadata" {
  description = "Instance metadata key-value pairs"
  type        = map(string)
  default     = {}
}

variable "user_data" {
  description = "Cloud-init user data (base64 encoded)"
  type        = string
  default     = ""
}

variable "availability_domains" {
  description = "List of availability domains"
  type        = list(object({
    name = string
  }))
  default     = []
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

#####################
# Data Sources
#####################

# Default Oracle Linux image if not specified
data "oci_core_images" "oracle_linux" {
  compartment_id = var.compartment_ocid
  operating_system = "Oracle Linux"
  operating_system_version = "8"
  shape = "VM.Standard.E4.Flex"
  sort_by = "TIMECREATED"
  sort_order = "DESC"
  limit = 1
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
        ocpus       = each.value.shape_config_ocpus != null ? each.value.shape_config_ocpus : each.value.ocpus
        memory_in_gbs = each.value.shape_config_memory_in_gbs != null ? each.value.shape_config_memory_in_gbs : each.value.memory_in_gbs
      }
      
      source_details {
        source_type = var.instance_images[each.key] != "" ? "image" : "image"
        image_id = var.instance_images[each.key] != "" ? var.instance_images[each.key] : data.oci_core_images.oracle_linux.images[0].id
      }
      
      create_vnic_details {
        subnet_id = var.subnet_ocids[keys(var.subnet_ocids)[0]]  # Default to first subnet
        nsg_ids   = var.nsg_ocids
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
    
    freeform_tags = var.common_tags
  }
}

resource "oci_core_instance_pool" "instance_pools" {
  for_each = var.instance_shapes
  
  compartment_id = var.compartment_ocid
  display_name   = "pool-${each.key}"
  instance_configuration_id = oci_core_instance_configuration.instance_configs[each.key].id
  size = var.instance_counts[each.key]
  
  placement_configurations {
    availability_domain = var.availability_domains[0].name
    primary_subnet_id   = var.subnet_ocids[keys(var.subnet_ocids)[0]]
    secondary_subnet_ids = values(var.subnet_ocids)[1:]  # Remaining subnets for HA
  }
  
  freeform_tags = var.common_tags
}

#####################
# Individual Instances (for more control)
#####################

# Create individual instances when counts are small or specific placement needed
resource "oci_core_instance" "instances" {
  for_each = {
    for pool_name, count in var.instance_counts :
    pool_name => count
    if count <= 3  # Use individual instances for small counts
  }
  
  # Create multiple instances per pool
  count = each.value
  
  compartment_id = var.compartment_ocid
  display_name   = "${each.key}-${count.index + 1}"
  
  shape = var.instance_shapes[each.key].shape
  
  shape_config {
    ocpus       = var.instance_shapes[each.key].shape_config_ocpus != null ? var.instance_shapes[each.key].shape_config_ocpus : var.instance_shapes[each.key].ocpus
    memory_in_gbs = var.instance_shapes[each.key].shape_config_memory_in_gbs != null ? var.instance_shapes[each.key].shape_config_memory_in_gbs : var.instance_shapes[each.key].memory_in_gbs
  }
  
  source_details {
    source_type = var.instance_images[each.key] != "" ? "image" : "image"
    image_id = var.instance_images[each.key] != "" ? var.instance_images[each.key] : data.oci_core_images.oracle_linux.images[0].id
  }
  
  create_vnic_details {
    subnet_id = var.subnet_ocids[element(keys(var.subnet_ocids), count.index % length(var.subnet_ocids))]
    nsg_ids   = var.nsg_ocids
    assign_public_ip = var.assign_public_ip
  }
  
  metadata = merge(
    var.instance_metadata,
    {
      "ssh_authorized_keys" = join("\n", var.ssh_public_keys)
      "user_data"           = var.user_data
    }
  )
  
  availability_domain = var.availability_domains[count.index % length(var.availability_domains)].name
  
  freeform_tags = var.common_tags
}

#####################
# Outputs
#####################

output "instance_ocids" {
  description = "Compute instance OCIDs by pool"
  value = merge(
    { for k, v in oci_core_instance_pool.instance_pools : k => v.instance_ids },
    { for k, v in oci_core_instance.instances : k => [for i in v : i.id]... }
  )
}

output "instance_private_ips" {
  description = "Instance private IPs by pool"
  value = merge(
    { for k, v in oci_core_instance_pool.instance_pools : k => v.instance_private_ips },
    { for k, v in oci_core_instance.instances : k => [for i in v : i.private_ip]... }
  )
}

output "instance_public_ips" {
  description = "Instance public IPs by pool"
  value = merge(
    { for k, v in oci_core_instance_pool.instance_pools : k => v.instance_public_ips },
    { for k, v in oci_core_instance.instances : k => [for i in v : i.public_ip]... }
  )
}

output "instance_shapes" {
  description = "Instance shapes by pool"
  value = { for k, v in var.instance_shapes : k => v.shape }
}