# Identity Module
# Creates compartment hierarchy, IAM groups, policies, and tagging governance

#####################
# Inputs
#####################

#####################
# Compartment Hierarchy
#####################

# Environment compartment
resource "oci_identity_compartment" "environment" {
  compartment_id = var.root_compartment_ocid
  name           = var.environment_compartment_name
  description    = "Environment compartment for ${var.environment_compartment_name}"
  freeform_tags  = var.common_tags
}

# Functional compartments under environment
resource "oci_identity_compartment" "functional" {
  for_each = toset(var.functional_compartment_names)

  compartment_id = oci_identity_compartment.environment.id
  name           = each.key
  description    = "Functional compartment for ${each.key}"
  freeform_tags  = var.common_tags
}

#####################
# IAM Groups
#####################

resource "oci_identity_group" "admin_groups" {
  for_each = var.admin_groups

  compartment_id = var.root_compartment_ocid
  name           = each.key
  description    = "Admin group: ${each.key}"
  freeform_tags  = var.common_tags
}

#####################
# Dynamic Groups
#####################

resource "oci_identity_dynamic_group" "dynamic_groups" {
  for_each = var.dynamic_groups

  compartment_id = var.root_compartment_ocid
  name           = each.key
  description    = "Dynamic group: ${each.key}"
  matching_rule  = each.value
  freeform_tags  = var.common_tags
}

#####################
# Policies
#####################

# Policy for each admin group to manage their compartments
resource "oci_identity_policy" "admin_policies" {
  for_each = var.admin_groups

  compartment_id = var.root_compartment_ocid
  name           = "policy-${each.key}"
  description    = "Policy for ${each.key} group"

  statements = [
    "Allow group ${each.key} to manage all-resources in compartment ${oci_identity_compartment.environment.name}",
    "Allow group ${each.key} to manage all-resources in compartment ${oci_identity_compartment.environment.name}:${each.key}",
    # Allow access to functional compartments
    "Allow group ${each.key} to manage all-resources in compartment ${oci_identity_compartment.environment.name}:network",
    "Allow group ${each.key} to manage all-resources in compartment ${oci_identity_compartment.environment.name}:compute",
    "Allow group ${each.key} to manage all-resources in compartment ${oci_identity_compartment.environment.name}:database",
    "Allow group ${each.key} to manage all-resources in compartment ${oci_identity_compartment.environment.name}:identity",
    "Allow group ${each.key} to manage all-resources in compartment ${oci_identity_compartment.environment.name}:lb"
  ]

  freeform_tags = var.common_tags
}

# Policy for instance principals (compute instances)
resource "oci_identity_policy" "instance_principals" {
  count = length([for k, v in var.dynamic_groups : k if k == "instance-principals"]) > 0 ? 1 : 0

  compartment_id = var.root_compartment_ocid
  name           = "policy-instance-principals"
  description    = "Policy for instance principals to access resources"

  statements = [
    "Allow dynamic-group instance-principals to read compartments in tenancy",
    "Allow dynamic-group instance-principals to read instance in compartment ${oci_identity_compartment.environment.name}:compute",
    "Allow dynamic-group instance-principals to read vcn in compartment ${oci_identity_compartment.environment.name}:network",
    "Allow dynamic-group instance-principals to read subnet in compartment ${oci_identity_compartment.environment.name}:network",
    "Allow dynamic-group instance-principals to read load-balancer in compartment ${oci_identity_compartment.environment.name}:lb",
    "Allow dynamic-group instance-principals to read autonomous-database in compartment ${oci_identity_compartment.environment.name}:database",
    "Allow dynamic-group instance-principals to read db-system in compartment ${oci_identity_compartment.environment.name}:database"
  ]

  freeform_tags = var.common_tags
}

#####################
# Tag Namespace
#####################

resource "oci_identity_tag_namespace" "governance" {
  compartment_id = var.root_compartment_ocid
  name           = var.tag_namespace_name
  description    = "Governance tag namespace for cost allocation and ownership"
  freeform_tags  = var.common_tags
}

resource "oci_identity_tag" "defined_tags" {
  for_each = toset(var.tag_keys)

  tag_namespace_id = oci_identity_tag_namespace.governance.id
  name             = each.key
  description      = "Governance tag: ${each.key}"
  freeform_tags    = var.common_tags
}

#####################
# Tag Defaults on Compartments
#####################

resource "oci_identity_tag_default" "compartment_defaults" {
  for_each = var.tag_defaults

  compartment_id    = each.key
  tag_definition_id = oci_identity_tag.defined_tags[each.value.key].id
  value             = each.value.value
  is_required       = each.value.required != false
}

#####################
# Outputs
#####################
