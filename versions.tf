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

  # Remote state, via OCI Object Storage's S3-compatible API.
  #
  # The bucket ("terraform-state-prod") was provisioned by
  # module.state_backend during bootstrap and already exists in the
  # tenancy. Every value here is filled in at `terraform init` time with
  # -backend-config (see the "Initialize Terraform" steps in
  # .github/workflows/terraform-*.yml) because backend blocks cannot
  # reference variables. Without this, every CI run starts from an empty
  # local state, tries to recreate every resource from scratch, and
  # collides with everything a previous run already created in OCI —
  # which is why "AlreadyExists" and resource-quota errors kept
  # reappearing across runs.
  #
  # OCI's S3-compatible endpoint requires a Customer Secret Key (Identity
  # > My Profile > Customer Secret Keys), which is a different credential
  # from the API signing key used by the oci provider elsewhere.
  backend "s3" {
    key                         = "terraform.tfstate"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
    force_path_style            = true
  }
}