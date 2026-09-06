terraform {
  required_version = ">= 1.11.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 7.0"
    }
  }

  # Remote state on OCI Object Storage via its S3-compatible API.
  #
  # This is the single most important part of this configuration. Without it
  # every CI run starts from an empty state, re-creates every resource, and
  # leaks the previous run's infrastructure. See docs/state-backend.md for the
  # one-time bootstrap (bucket + customer secret key).
  #
  # Values are supplied by `terraform init -backend-config=...` so the same
  # code works locally and in CI.
  backend "s3" {
    key = "immich/terraform.tfstate"

    # OCI Object Storage speaks S3, but not the parts of it that the AWS SDK
    # assumes are always present.
    use_path_style              = true
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true

    # Native S3 locking: writes a .tflock object next to the state. Removes the
    # need for DynamoDB (which OCI has no equivalent of).
    use_lockfile = true
  }
}
