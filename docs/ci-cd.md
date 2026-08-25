# CI/CD Documentation

This document describes the GitHub Actions CI/CD pipeline for the OCI Terraform configuration.

## Overview

Two workflows handle the CI/CD pipeline:

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `terraform-plan.yml` | Pull Request, Push to main | Validate changes, run plan, post summary |
| `terraform-apply.yml` | Merge to main, Manual dispatch | Apply changes to target environment |

## Workflow: Terraform Plan (terraform-plan.yml)

### Triggers
- Pull request opened/synchronized/reopened against `main`
- Push to `main` (for validation only)

### Jobs

#### 1. fmt (Format Check)
- Runs `terraform fmt -check -recursive -diff`
- Fails if formatting issues found
- Run `terraform fmt -recursive` locally to fix

#### 2. validate (Configuration Validation)
- Runs `terraform init -backend=false`
- Runs `terraform validate`
- Catches syntax errors, missing variables, etc.

#### 3. plan (Terraform Plan)
- Configures OCI authentication (API key or instance principal)
- Initializes with remote backend
- Runs `terraform plan -var-file=dev.tfvars`
- Converts plan to JSON for analysis
- Generates summary (create/update/destroy counts)
- Posts summary as PR comment
- Uploads plan artifact (30 days retention)

#### 4. policy-check (Checkov)
- Runs Checkov static analysis on Terraform
- Outputs SARIF for GitHub Security tab
- Skips specific OCI checks if needed

### Required Secrets
| Secret | Description |
|--------|-------------|
| `OCI_TENANCY_OCID` | Tenancy OCID |
| `OCI_USER_OCID` | User OCID for API key |
| `OCI_FINGERPRINT` | API key fingerprint |
| `OCI_PRIVATE_KEY` | Private key PEM content |
| `OCI_PRIVATE_KEY_PASSPHRASE` | (Optional) Key passphrase |

### Required Variables
| Variable | Description |
|----------|-------------|
| `OCI_REGION` | OCI region (e.g., us-ashburn-1) |
| `TF_STATE_BUCKET` | State bucket name |
| `TF_STATE_NAMESPACE` | Object Storage namespace |

### Branch Protection
Configure on `main` branch:
- Require status checks: `terraform-plan`
- Require PR reviews: 1+
- Dismiss stale reviews on new commits

## Workflow: Terraform Apply (terraform-apply.yml)

### Triggers
- Push to `main` (auto-deploys to staging)
- Manual workflow dispatch (for production)

### Environment Mapping

| Trigger | Environment | Approval |
|---------|-------------|----------|
| Push to main | staging | None |
| Manual dispatch → staging | staging | None |
| Manual dispatch → prod | production | Required |

### Jobs

#### 1. determine-environment
Determines target environment and approval requirement.

#### 2. plan
Runs terraform plan for target environment:
- Uses environment-specific `.tfvars` file
- Uploads plan artifact (90 days retention)

#### 3. approval (Production only)
Manual approval gate using GitHub Environments:
- Creates `production-approval` environment
- Requires reviewer to approve before apply

#### 4. apply
Runs `terraform apply -auto-approve` using saved plan:
- Posts deployment summary to workflow run
- On production success: creates deployment tag

#### 5. cleanup
Removes old workflow runs (keeps 30 days / 10 minimum).

## Authentication in CI/CD

### GitHub-Hosted Runners (API Keys)
```yaml
# Workflow configures ~/.oci/config automatically
cat > ~/.oci/config <<EOF
[DEFAULT]
user=${{ secrets.OCI_USER_OCID }}
fingerprint=${{ secrets.OCI_FINGERPRINT }}
tenancy=${{ secrets.OCI_TENANCY_OCID }}
region=${{ vars.OCI_REGION }}
key_file=~/.oci/oci_api_key.pem
EOF
echo "${{ secrets.OCI_PRIVATE_KEY }}" > ~/.oci/oci_api_key.pem
```

### Self-Hosted Runners in OCI (Instance Principals)
- No secrets needed
- Automatic authentication via instance metadata service
- More secure - no long-lived credentials

## Environment Configuration

### Staging (Auto-deploy on merge)
```bash
# terraform-apply.yml uses staging.tfvars
# Runs automatically when PR merged to main
```

### Production (Manual)
```bash
# Go to Actions → Terraform Apply → Run workflow
# Select: environment = "prod"
# Check: approve = true
# Click: Run workflow
# Wait for approval step → Click "Approve and deploy"
```

### Adding New Environment
1. Create `newenv.tfvars` with environment config
2. Add environment to workflow `environment` input choices
3. Create GitHub Environment with protection rules if needed
4. Update `determine-environment` job logic

## Concurrency Control

Both workflows use concurrency groups to prevent conflicts:

```yaml
concurrency:
  group: terraform-plan-${{ github.ref }}
  cancel-in-progress: true  # Plan: cancel old runs

concurrency:
  group: terraform-apply-${{ environment }}
  cancel-in-progress: false  # Apply: queue runs
```

## State Locking

- Object Storage bucket with versioning
- Autonomous Database lock table
- Terraform automatically acquires/releases lock
- Lock timeout: configurable (default 20 min)

### Forcing Unlock
```bash
# If workflow stuck, force unlock
terraform force-unlock <LOCK_ID>

# Or delete from ADB lock table manually
```

## Artifact Retention

| Artifact | Retention |
|----------|-----------|
| Plan (PR) | 30 days |
| Plan (Apply) | 90 days |
| Checkov SARIF | GitHub retention |

## Troubleshooting

### Plan Fails
1. Check workflow logs for error
2. Common issues:
   - Missing secrets/variables
   - OCI quota exceeded
   - Provider version mismatch
   - State lock timeout

### Apply Fails
1. Check plan output for preview
2. Common issues:
   - Concurrent apply (wait for lock)
   - OCI resource limits
   - Dependency ordering
   - Manual intervention needed

### PR Comment Not Posting
1. Verify `pull-requests: write` permission
2. Check GitHub token has repo scope
3. Ensure bot user can comment

### Approval Not Working
1. Verify `production-approval` environment exists
2. Check environment protection rules
3. Ensure reviewers have access

## Best Practices

1. **Always review plan** before merging
2. **Use `-target`** for emergency fixes
3. **Test in dev** before staging
4. **Monitor apply** for production
5. **Tag production** deployments
6. **Rotate secrets** quarterly
7. **Audit IAM policies** regularly

## Extending the Pipeline

### Add Policy-as-Code (OPA)
```yaml
- name: Run OPA Policies
  uses: open-policy-agent/opa-action@v1
  with:
    policies: policies/
    resources: tfplan.json
```

### Add Drift Detection
```yaml
# Scheduled workflow
on:
  schedule:
    - cron: '0 6 * * *'  # Daily at 6 AM
```

### Add Notification
```yaml
- name: Notify Slack
  uses: slackapi/slack-github-action@v1.23.0
  with:
    channel-id: ${{ secrets.SLACK_CHANNEL }}
    slack-message: "Terraform ${{ job.status }} in ${{ needs.determine-environment.outputs.environment }}"
  env:
    SLACK_BOT_TOKEN: ${{ secrets.SLACK_BOT_TOKEN }}
```

### Multi-Region Support
```hcl
# Add provider aliases
provider "oci" {
  alias  = "phoenix"
  region = "us-phoenix-1"
}

# Use in modules
module "network_phx" {
  source = "./modules/network"
  providers = { oci = oci.phoenix }
  ...
}
```

## Security Considerations

1. **Secrets in GitHub** - Encrypted at rest, only exposed to workflow
2. **Least privilege** - Workflows use minimal permissions
3. **OIDC future** - Plan to migrate to OIDC federation
4. **Audit trail** - All runs logged in GitHub Actions
5. **Environment protection** - Production requires approval

## Migration from Manual Terraform

1. Run `terraform init -migrate-state` to move local state to remote
2. Verify state: `terraform state list`
3. Configure GitHub secrets/variables
4. Enable branch protection
5. Test with dev environment PR
6. Promote to staging/production