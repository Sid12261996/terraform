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
    { for k, v in data.oci_core_instance_pool_instances.pools : k => [for i in v.instances : i.instance_id] },
    { for k, v in local.individual_by_pool : k => [for i in v : i.id] }
  )
}

output "instance_private_ips" {
  description = "Instance private IPs by pool. Pooled instances report IPs of individually-managed instances only; discover pool-member IPs via the instance OCIDs."
  value = merge(
    { for k, v in oci_core_instance_pool.instance_pools : k => [] },
    { for k, v in local.individual_by_pool : k => [for i in v : i.private_ip] }
  )
}

output "instance_public_ips" {
  description = "Instance public IPs by pool (if assigned)"
  value = merge(
    { for k, v in oci_core_instance_pool.instance_pools : k => [] },
    { for k, v in local.individual_by_pool : k => [for i in v : i.public_ip] }
  )
}

output "instance_shapes" {
  description = "Instance shapes by pool"
  value       = { for k, v in var.instance_shapes : k => v.shape }
}
