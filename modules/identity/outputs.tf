# Identity Module Outputs

output "environment_compartment_ocid" {
  description = "Environment compartment OCID"
  value       = oci_identity_compartment.environment.id
}

output "functional_compartment_ocids" {
  description = "Functional compartment OCIDs"
  value       = { for k, v in oci_identity_compartment.functional : k => v.id }
}

output "group_ocids" {
  description = "IAM group OCIDs"
  value       = { for k, v in oci_identity_group.admin_groups : k => v.id }
}

output "dynamic_group_ocids" {
  description = "Dynamic group OCIDs"
  value       = { for k, v in oci_identity_dynamic_group.dynamic_groups : k => v.id }
}

output "tag_namespace_ocid" {
  description = "Tag namespace OCID"
  value       = oci_identity_tag_namespace.governance.id
}

output "tag_ocids" {
  description = "Defined tag OCIDs"
  value       = { for k, v in oci_identity_tag.defined_tags : k => v.id }
}