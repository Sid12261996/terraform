## Why

This project needs a Terraform repository to provision and manage a full-stack Oracle Cloud Infrastructure (OCI) environment including compute instances, networking (VCN, subnets, gateways, load balancers), and databases. Currently there is no infrastructure-as-code for OCI, making environment provisioning manual, error-prone, and not reproducible.

## What Changes

- Create a new Terraform repository for OCI full-stack infrastructure
- Provision compute instances (VM and Bare Metal) with custom images and shapes
- Provision complete networking stack: VCN, subnets (public/private), internet gateway, NAT gateway, service gateway, route tables, security lists, and network security groups
- Provision load balancers (public and private) with backend sets and listeners
- Provision Oracle databases (Autonomous Database and/or DB Systems)
- Configure IAM policies, compartments, and tagging standards
- Set up Terraform state backend (OCI Object Storage) with locking
- Define variables, outputs, and locals for reusable configuration
- Implement GitHub Actions CI/CD pipeline that runs `terraform plan` on PR and `terraform apply` on merge to main

## Capabilities

### New Capabilities

- `oci/compute`: Compute instance provisioning with shapes, images, SSH keys, and metadata
- `oci/network`: Complete VCN networking including subnets, gateways, routing, and security
- `oci/load-balancer`: Public and private load balancers with backend configuration
- `oci/database`: Autonomous Database and DB System provisioning
- `oci/identity`: Compartments, policies, groups, and tagging governance
- `oci/state-backend`: Terraform remote state configuration with OCI Object Storage
- `oci/ci-cd`: GitHub Actions workflow for Terraform plan on PR and apply on merge

### Modified Capabilities

None (greenfield project)

## Impact

- New Terraform codebase in `/Users/lord-sid/projects/oracle-terraform`
- OCI provider configuration and authentication setup
- State management in OCI Object Storage bucket
- IAM policies required for Terraform service principal
- Compartment hierarchy for resource organization
- GitHub Actions workflows in `.github/workflows/`
- GitHub repository secrets for OCI credentials
- Branch protection rules requiring PR reviews before merge