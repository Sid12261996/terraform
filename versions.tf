terraform {
  required_version = ">= 1.6.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }

  # Remote state backend — DISABLED during bootstrap.
  #
  # The state bucket is provisioned by module.state_backend in this same
  # configuration, so remote state cannot be used until after the first
  # apply (chicken-and-egg). Until then, state stays local.
  #
  # To enable remote state once the bucket exists:
  #   1. Uncomment the block below.
  #   2. Set TF_STATE_BUCKET / OCI_REGION repo variables.
  #   3. Restore the backend flags in the workflow "Initialize Terraform"
  #      steps (they are kept ready for this).
  #
  # backend "oss" {
  #   bucket = "<tf-state-bucket>"
  #   key    = "terraform.tfstate"
  #   region = "<region>"
  # }
}