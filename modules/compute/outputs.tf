# Compute Module Outputs

locals {
  # Group individual instances back into pool -> list shape
  individual_by_pool = {
    for p in distinct([for k, s in local.individual_instances : s.pool_name]) :
    p => [for k, s in local.individual_instances : oci_core_instance.instances[k] if s.pool_name == p]
  }
}

output "instance_ocids" {
  description = "Compute instance OCIDs by pool"
  value = merge(
    { for k, v in oci_core_instance_pool.instance_pools : k => v.instance_ids },
    { for k, v in local.individual_by_pool : k => [for i in v : i.id] }
  )
}

output "instance_private_ips" {
  description = "Instance private IPs by pool"
  value = merge(
    { for k, v in oci_core_instance_pool.instance_pools : k => v.instance_private_ips },
    { for k, v in local.individual_by_pool : k => [for i in v : i.private_ip] }
  )
}

output "instance_public_ips" {
  description = "Instance public IPs by pool"
  value = merge(
    { for k, v in oci_core_instance_pool.instance_pools : k => v.instance_public_ips },
    { for k, v in local.individual_by_pool : k => [for i in v : i.public_ip] }
  )
}

output "instance_shapes" {
  description = "Instance shapes by pool"
  value       = { for k, v in var.instance_shapes : k => v.shape }
}