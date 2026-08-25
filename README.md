# OCI Full-Stack Terraform Configuration

Infrastructure as Code for Oracle Cloud Infrastructure (OCI) - compute, networking, load balancers, databases, and identity management.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      OCI Tenancy                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              Root Compartment                        │    │
│  │  ┌─────────────────────────────────────────────┐   │    │
│  │  │           Environment Compartment            │   │    │
│  │  │  (dev / staging / prod)                      │   │    │
│  │  │  ┌────────┬────────┬────────┬────────┐       │   │    │
│  │  │  │Network │Compute │Database│Identity│  LB   │       │   │    │
│  │  │  └────────┴────────┴────────┴────────┴───────┘       │   │    │
│  │  └─────────────────────────────────────────────┘   │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## Features

- **Compute**: VM.Standard.E4.Flex and BM.Standard.E4.128 instances with SSH keys, metadata, user data
- **Networking**: VCN, public/private subnets, Internet Gateway, NAT Gateway, Service Gateway, NSGs, Security Lists
- **Load Balancing**: Public/Private flexible LBs (100-8000 Mbps), HTTP/HTTPS/TCP listeners, health checks, SSL termination
- **Databases**: Autonomous Transaction Processing (ATP), Autonomous Data Warehouse (ADW), DB Systems with Data Guard
- **Identity**: Compartment hierarchy, IAM policies, groups, dynamic groups, tagging governance
- **State Management**: OCI Object Storage with versioning + Autonomous Database locking
- **CI/CD**: GitHub Actions for plan on PR, apply on merge with production approval gate

## Prerequisites

- Terraform >= 1.6.0
- OCI CLI configured (for bootstrap)
- OCI account with appropriate permissions
- GitHub repository with secrets/variables configured

## Quick Start

### 1. Bootstrap State Backend

```bash
# Run once to create state bucket and lock table
./scripts/bootstrap-state-backend.sh \
  <compartment_ocid> \
  terraform-state \
  <namespace> \
  us-ashburn-1 \
  terraform_locks
```

### 2. Configure GitHub Secrets

Go to Repository Settings → Secrets and Variables → Actions and add:

**Secrets:**
- `OCI_TENANCY_OCID` - Your tenancy OCID
- `OCI_USER_OCID` - User OCID for API key auth
- `OCI_FINGERPRINT` - API key fingerprint
- `OCI_PRIVATE_KEY` - Private key PEM content
- `OCI_PRIVATE_KEY_PASSPHRASE` - (Optional) Key passphrase
- `TF_API_TOKEN` - (Optional) Terraform Cloud token

**Variables:**
- `OCI_REGION` - e.g., `us-ashburn-1`
- `TF_STATE_BUCKET` - e.g., `terraform-state`
- `TF_STATE_NAMESPACE` - Your Object Storage namespace

### 3. Configure Branch Protection

1. Go to Settings → Branches → Add rule
2. Branch pattern: `main`
3. Require status checks to pass: `terraform-plan`
4. Require pull request reviews: 1
5. Dismiss stale reviews on new commits

### 4. Deploy

```bash
# Development
terraform apply -var-file=dev.tfvars

# Staging (auto-deploys on merge to main)
# Push to main branch triggers GitHub Actions

# Production (manual)
# Go to Actions → Terraform Apply → Run workflow → Select "prod" → Approve
```

## Project Structure

```
.
├── main.tf                 # Root module wiring all modules
├── providers.tf            # Provider configuration (multi-auth)
├── variables.tf            # All input variables
├── outputs.tf              # All outputs
├── versions.tf             # Provider versions & backend config
├── backend.hcl.example     # Backend configuration template
├── dev.tfvars              # Dev environment variables
├── staging.tfvars          # Staging environment variables
├── prod.tfvars             # Production environment variables
├── modules/
│   ├── compute/            # Compute instances
│   ├── network/            # VCN, subnets, gateways, NSGs
│   ├── load-balancer/      # Public/Private LBs
│   ├── database/           # ATP, ADW, DB Systems
│   ├── identity/           # Compartments, policies, tags
│   └── state-backend/      # Object Storage + ADB locking
├── scripts/
│   └── bootstrap-state-backend.sh
├── .github/
│   └── workflows/
│       ├── terraform-plan.yml    # PR validation
│       └── terraform-apply.yml   # Deploy on merge
└── docs/
    └── ci-cd.md            # CI/CD documentation
```

## Environments

| Environment | VCN CIDR     | Compute Shape      | LB Bandwidth | Database |
|-------------|--------------|--------------------|--------------|----------|
| dev         | 10.0.0.0/16  | 1 OCPU / 8GB       | 10-100 Mbps  | ATP Free |
| staging     | 10.10.0.0/16 | 2 OCPU / 16GB      | 100-1000 Mbps| ATP 2C   |
| prod        | 10.20.0.0/16 | 4 OCPU / 32GB      | 100-8000 Mbps| ATP 4C   |

## Authentication

### Local Development (API Keys)

```bash
export OCI_REGION=us-ashburn-1
export OCI_TENANCY_OCID=ocid1.tenancy.oc1..
export OCI_USER_OCID=ocid1.user.oc1..
export OCI_FINGERPRINT=aa:bb:cc...
export OCI_PRIVATE_KEY_PATH=~/.oci/oci_api_key.pem
export OCI_PRIVATE_KEY_PASSPHRASE=  # if encrypted

terraform init -backend-config=backend.hcl
terraform plan -var-file=dev.tfvars
```

### CI/CD (GitHub Actions)

- **Hosted runners**: Uses API keys from GitHub secrets
- **Self-hosted in OCI**: Uses instance principals automatically

### OCI Compute (Instance Principals)

No configuration needed - automatically detected when running on OCI instance with instance principal enabled.

## State Management

State is stored in OCI Object Storage with locking via Autonomous Database:

```hcl
backend "oss" {
  bucket_name = "terraform-state"
  namespace   = "mynamespace"
  region      = "us-ashburn-1"
  object_name = "terraform.tfstate"
}
```

Initialize with:
```bash
terraform init -backend-config=backend.hcl
```

## Tagging Strategy

All resources receive governance tags:

| Tag Key | Description | Example |
|---------|-------------|---------|
| `governance.environment` | Environment | `dev`, `staging`, `prod` |
| `governance.owner` | Team owner | `platform-team` |
| `governance.cost-center` | Cost center | `engineering` |
| `governance.project` | Project name | `oci-full-stack` |

Tag defaults are enforced on compartments for automatic propagation.

## CI/CD Pipeline

### Pull Request Flow
1. Developer creates PR
2. `terraform-plan.yml` runs:
   - `terraform fmt` check
   - `terraform init` (no backend)
   - `terraform validate`
   - `terraform plan` (dev environment)
   - Posts plan summary as PR comment
   - Runs Checkov policy scan
3. Reviewers approve
4. Merge to main

### Merge to Main Flow
1. `terraform-apply.yml` triggers
2. Determines environment (main → staging)
3. Runs `terraform plan` (staging)
4. If changes: runs `terraform apply`
5. Posts deployment summary

### Production Deployment
1. Manual workflow dispatch
2. Select `prod` environment
3. Requires manual approval
4. Runs `terraform plan` (prod)
5. On approval: runs `terraform apply`
6. Creates deployment tag

## Common Commands

```bash
# Initialize
terraform init -backend-config=backend.hcl

# Plan
terraform plan -var-file=dev.tfvars

# Apply
terraform apply -var-file=dev.tfvars

# Destroy (dev only!)
terraform destroy -var-file=dev.tfvars

# Format
terraform fmt -recursive

# Validate
terraform validate

# Show state
terraform state list

# Import existing resource
terraform import oci_core_instance.example ocid1.instance.oc1..

# Force unlock (if stuck)
terraform force-unlock <lock_id>
```

## Troubleshooting

### State Lock Issues
```bash
# Check lock table
terraform force-unlock -force <LOCK_ID>

# Or manually delete from ADB lock table
```

### Provider Auth Issues
- Verify API key permissions in OCI Console
- Check private key format (PEM, no password or provide passphrase)
- Ensure instance principal is enabled on compute instance

### Plan Takes Too Long
- Use `-target` for focused plans
- Split into smaller modules if state > 500 resources

## Security Best Practices

1. **Never commit secrets** - Use GitHub secrets and `.gitignore`
2. **Rotate API keys** regularly (90 days)
3. **Use instance principals** in OCI when possible
4. **Enable MFA** on OCI users
5. **Restrict security lists/NSGs** to minimum required ports
6. **Use private subnets** for compute and databases
7. **Enable encryption** on all storage

## Contributing

1. Create feature branch
2. Make changes
3. Run `terraform fmt -recursive && terraform validate`
4. Create PR
5. Wait for plan check and reviews
6. Merge after approval

## License

MIT License - See LICENSE file for details.