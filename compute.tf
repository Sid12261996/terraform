locals {
  compartment_ocid = var.compartment_ocid != "" ? var.compartment_ocid : var.tenancy_ocid

  # Ampere A1 capacity is scarce in Always Free tenancies and is not evenly
  # spread across availability domains. Ordering the ADs lets the instance be
  # retried against a different one by bumping var.availability_domain_index
  # rather than editing code.
  availability_domains = data.oci_identity_availability_domains.this.availability_domains[*].name

  cloud_init = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    library_mount  = var.library_mount
    immich_version = var.immich_version
    domain_name    = var.domain_name
    acme_email     = var.acme_email
  })
}

data "oci_identity_availability_domains" "this" {
  compartment_id = var.tenancy_ocid
}

# Canonical's Ubuntu 22.04 aarch64 image, resolved at plan time so the
# configuration does not pin an OCID that Oracle eventually retires.
data "oci_core_images" "ubuntu_arm" {
  compartment_id           = local.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

resource "oci_core_instance" "immich" {
  compartment_id      = local.compartment_ocid
  availability_domain = local.availability_domains[var.availability_domain_index]
  display_name        = "${var.name_prefix}-server"
  shape               = "VM.Standard.A1.Flex"
  freeform_tags       = var.tags

  shape_config {
    ocpus         = var.instance_ocpus
    memory_in_gbs = var.instance_memory_gb
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu_arm.images[0].id
    boot_volume_size_in_gbs = var.boot_volume_gb
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    assign_public_ip = true
    hostname_label   = var.name_prefix
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = base64encode(local.cloud_init)
  }

  # The image is resolved from a "latest" query, so a new Ubuntu build would
  # otherwise destroy and recreate the server - taking the photo library's
  # attachment with it. Upgrades are done in place on the instance instead.
  lifecycle {
    ignore_changes = [source_details[0].source_id]
  }
}

resource "oci_core_volume" "data" {
  compartment_id      = local.compartment_ocid
  availability_domain = local.availability_domains[var.availability_domain_index]
  display_name        = "${var.name_prefix}-data"
  size_in_gbs         = var.data_volume_gb
  freeform_tags       = var.tags

  # This volume holds every photo and the Immich database. Losing it to a
  # config change would be unrecoverable.
  lifecycle {
    prevent_destroy = true
  }
}

resource "oci_core_volume_attachment" "data" {
  attachment_type = "paravirtualized"
  instance_id     = oci_core_instance.immich.id
  volume_id       = oci_core_volume.data.id

  # Lets cloud-init's bootstrap script find and mount the disk without
  # iSCSI setup.
  is_read_only = false
}
