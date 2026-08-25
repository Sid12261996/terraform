## Purpose

Implements GitHub Actions CI/CD pipeline for Terraform: runs `terraform plan` on pull requests and `terraform apply` on merge to main branch, with OCI authentication via instance principals or API keys.

## ADDED Requirements

### Requirement: Pull Request validation workflow
The system SHALL run `terraform fmt`, `terraform init`, and `terraform plan` on every pull request to validate changes.

#### Scenario: PR opened or updated triggers plan
- **WHEN** a pull request is opened or updated against main branch
- **THEN** GitHub Action runs terraform fmt check, init, and plan for dev environment

#### Scenario: Plan output posted as PR comment
- **WHEN** terraform plan completes successfully
- **THEN** plan summary is posted as a comment on the PR with resource changes

#### Scenario: Plan failure blocks merge
- **WHEN** terraform plan fails (syntax error, provider error, etc.)
- **THEN** workflow fails and prevents merge via required status check

#### Scenario: Format check enforces code style
- **WHEN** terraform fmt detects formatting issues
- **THEN** workflow fails with details on which files need formatting

### Requirement: Merge-to-main apply workflow
The system SHALL run `terraform apply` automatically when a pull request is merged to main branch.

#### Scenario: Apply runs on merge to main
- **WHEN** a pull request is merged to main branch
- **THEN** GitHub Action runs terraform init and apply for the target environment

#### Scenario: Environment selection via branch or label
- **WHEN** merge targets main branch
- **THEN** workflow applies to the environment configured for main (e.g., staging or prod)

#### Scenario: Apply requires manual approval for production
- **WHEN** target environment is production
- **THEN** workflow pauses for manual approval before running apply

#### Scenario: Apply output posted as workflow summary
- **THEN** apply output with resource changes is available in workflow run summary

### Requirement: OCI authentication in GitHub Actions
The system SHALL authenticate to OCI using GitHub repository secrets.

#### Scenario: API key authentication for GitHub Actions runner
- **WHEN** workflow runs on GitHub-hosted runner
- **THEN** OCI API key (user OCID, tenancy OCID, fingerprint, private key, region) from secrets authenticates provider

#### Scenario: Instance principal authentication for self-hosted runner in OCI
- **WHEN** workflow runs on self-hosted runner in OCI compute
- **THEN** instance principal authentication is used automatically

#### Scenario: Region and compartment configured via secrets/variables
- **WHEN** workflow starts
- **THEN** OCI region and target compartment are read from GitHub repository variables/secrets

### Requirement: Terraform state backend configuration
The system SHALL configure the remote state backend automatically in the workflow.

#### Scenario: Backend configured via environment variables
- **WHEN** workflow runs terraform init
- **THEN** backend configuration (bucket, namespace, region, lock table) is passed via environment variables

#### Scenario: State locking works in CI/CD
- **WHEN** multiple workflow runs attempt concurrent apply
- **THEN** state locking prevents concurrent modifications

### Requirement: Branch protection and required status checks
The system SHALL enforce branch protection rules requiring successful plan before merge.

#### Scenario: Required status check for terraform plan
- **WHEN** branch protection is configured
- **THEN** "terraform-plan" status check must pass before PR can be merged

#### Scenario: Dismiss stale reviews on new commits
- **WHEN** new commits are pushed to PR
- **THEN** previous approvals are dismissed requiring re-review

### Requirement: Workflow outputs and artifacts
The system SHALL provide actionable outputs from workflow runs.

#### Scenario: Plan artifact uploaded for review
- **WHEN** terraform plan runs
- **THEN** plan output file is uploaded as artifact for 30 days

#### Scenario: Apply creates deployment summary
- **WHEN** terraform apply completes
- **THEN** deployment summary with resources created/updated/destroyed is generated