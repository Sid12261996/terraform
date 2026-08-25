## Context

This is a greenfield Terraform project for Oracle Cloud Infrastructure. No existing Terraform code or OCI resources exist. The project will be a monolithic root module (single configuration) as specified in the proposal. The target is a full-stack OCI deployment including compute, networking, load balancers, databases, and identity management.

OCI provider version 5.x will be used with Terraform 1.6+. State will be stored in OCI Object Storage with locking via an Autonomous Database table.

## Goals / Non-Goals

**Goals:**
- Single root module that provisions complete OCI infrastructure
- Modular internal structure using Terraform modules for each capability
- Secure-by-default networking (private subnets, restricted security rules)
- Support for multiple environments via variable files
- Terraform best practices: consistent naming, tagging, and resource organization

**Non-Goals:**
- Multi-region deployment (single region only)
- Terraform Cloud/Enterprise integration
- Custom provider development
- Advanced networking like DRG/VCN peering (can be added later)

## Decisions

### 1. Monolithic root module with internal modules
**Decision**: Use a single root module (`main.tf`) that calls internal modules for each capability (compute, network, load-balancer, database, identity, state-backend).

**Rationale**: User requested monolithic structure. Internal modules provide code organization and reusability without the complexity of separate module repositories or registry publishing.

**Alternatives considered**:
- Flat files (no modules): Rejected - would be unmaintainable at this scale
- Separate module repos: Rejected - overkill for single-project use case
- Terraform Registry modules: Rejected - OCI-specific customizations needed

### 2. OCI Provider Authentication
**Decision**: Use instance principals for Terraform execution in OCI, with API key fallback for local development.

**Rationale**: Instance principals are more secure (no long-lived credentials) and work natively in OCI compute. API keys support local development.

**Alternatives considered**:
- Only API keys: Rejected - less secure for production automation
- Resource principals: Rejected - similar to instance principals, more complex setup
- OIDC federation: Rejected - adds complexity for initial implementation

### 3. Compartment Strategy
**Decision**: Create a compartment hierarchy: root → environment (prod/staging/dev) → functional (network, compute, database, identity).

**Rationale**: Aligns with OCI best practices for resource isolation and policy scoping. Functional compartments allow granular IAM policies.

**Alternatives considered**:
- Flat compartment structure: Rejected - doesn't scale for policy management
- Single compartment: Rejected - no isolation, violates least privilege

### 4. Networking Architecture
**Decision**: Hub-spoke not required initially. Single VCN with public/private subnet pairs per availability domain. NAT Gateway for private egress. Service Gateway for OCI service access.

**Rationale**: Simpler to implement and manage. Hub-spoke adds complexity (DRG, route tables) not needed for single VCN deployment.

**Alternatives considered**:
- Hub-spoke with DRG: Rejected - over-engineering for single VCN
- Public-only subnets: Rejected - security risk, not production-ready

### 5. Compute Instance Shapes
**Decision**: Default to VM.Standard.E4.Flex for flexibility. Support BM.Standard.E4.128 for bare metal workloads. Shape configurable via variables.

**Rationale**: Flex shapes optimize cost/performance. Bare metal option for licensing or performance requirements.

**Alternatives considered**:
- Fixed shapes: Rejected - inflexible for different workloads
- Only AMD shapes: Rejected - Intel/ARM options may be needed

### 6. Load Balancer Configuration
**Decision**: Flexible load balancers (100-8000 Mbps) for both public and private. SSL termination at load balancer with certificates in OCI Certificates service.

**Rationale**: Flexible shape handles variable traffic. SSL offload reduces backend complexity. OCI Certificates integrates with load balancer.

**Alternatives considered**:
- Fixed bandwidth: Rejected - wasteful or insufficient
- Backend SSL termination: Rejected - certificate management complexity

### 7. Database Strategy
**Decision**: Autonomous Database (ATP/ADW) as primary. DB Systems (VM/BM) for workloads requiring OS access or specific Oracle features.

**Rationale**: Autonomous reduces operational overhead. DB Systems for legacy/custom requirements.

**Alternatives considered**:
- Only Autonomous: Rejected - some workloads need OS access
- Only DB Systems: Rejected - higher operational burden

### 8. State Backend
**Decision**: OCI Object Storage bucket with versioning + Autonomous Database table for locking.

**Rationale**: Native OCI services, no external dependencies. Object Storage is highly durable. Autonomous Database provides consistent locking.

**Alternatives considered**:
- S3-compatible (MinIO): Rejected - operational overhead
- Local state only: Rejected - no team collaboration
- DynamoDB-style locking: Rejected - requires additional service

### 9. Tagging Strategy
**Decision**: Defined tags in namespace `governance` with keys: `environment`, `owner`, `cost-center`, `project`. Mandatory via tag defaults on compartments.

**Rationale**: Enables cost allocation, ownership tracking, and policy enforcement. Tag defaults ensure compliance.

**Alternatives considered**:
- Freeform tags only: Rejected - no governance, inconsistent
- No tagging: Rejected - operational blind spot

### 10. Variable Management
**Decision**: Environment-specific `.tfvars` files (dev.tfvars, staging.tfvars, prod.tfvars) with shared `variables.tf` for defaults.

**Rationale**: Clear separation of environment configuration. Single source of truth for variable definitions.

**Alternatives considered**:
- TF_VAR_ environment variables: Rejected - harder to audit and version control
- Separate workspaces: Rejected - state isolation but variable duplication

### 11. CI/CD Pipeline with GitHub Actions
**Decision**: Two workflows - `terraform-plan.yml` runs on PR (fmt, init, plan) and `terraform-apply.yml` runs on merge to main (init, apply with optional manual approval for prod).

**Rationale**: Separation of concerns - validation on every PR, deployment only on merge. Manual approval gate for production adds safety.

**Alternatives considered**:
- Single workflow with conditional jobs: Rejected - harder to reason about, less visible in GitHub UI
- Terraform Cloud/Enterprise: Rejected - additional cost, vendor lock-in
- GitLab CI / Azure Pipelines: Rejected - GitHub is the chosen platform

### 12. OCI Authentication in CI/CD
**Decision**: GitHub repository secrets for API key authentication (user OCID, tenancy OCID, fingerprint, private key, region). Support instance principals for self-hosted runners in OCI.

**Rationale**: API keys work on GitHub-hosted runners without infrastructure. Instance principals are more secure for self-hosted runners in OCI.

**Alternatives considered**:
- OIDC federation with OCI: Rejected - complex setup, not yet stable for GitHub Actions
- Environment-specific credentials: Rejected - same credentials work across environments via compartment scoping

### 13. Environment Promotion Strategy
**Decision**: Main branch maps to staging environment. Production deployments use manual workflow dispatch or tag-based trigger with approval.

**Rationale**: Main branch auto-deploys to staging for continuous validation. Production requires explicit action preventing accidental deploys.

**Alternatives considered**:
- Separate branches per environment (main=prod, staging=staging): Rejected - branch management overhead
- All environments auto-deploy: Rejected - too risky for production

### 14. Workflow Permissions and Security
**Decision**: Workflows use minimal permissions (contents: read, id-token: write for OIDC if needed). Secrets stored in GitHub repository settings, not in code.

**Rationale**: Principle of least privilege. GitHub secrets are encrypted and only exposed to workflow runs.

**Alternatives considered**:
- Repository-level secrets only: Rejected - environment-specific secrets need environment protection rules
- External secret store (Vault, AWS Secrets Manager): Rejected - additional complexity

## Risks / Trade-offs

[Monolithic root module] → Larger state file, slower plans. Mitigation: Use `-target` for focused changes; consider splitting if state grows >500 resources.

[Single VCN] → No network isolation between environments. Mitigation: Use separate compartments and security rules; plan for multi-VCN if needed.

[Instance principals only in OCI] → Local development requires API keys. Mitigation: Document both auth methods; provide setup scripts.

[Autonomous DB for locking] → Additional cost (~$50/month for Always Free). Mitigation: Use Always Free tier; document cost implication.

[Flex shapes] → May not be available in all regions. Mitigation: Validate region support in variables; fallback to fixed shapes.

[GitHub Actions on hosted runners] → API keys in secrets, network egress from GitHub IPs. Mitigation: Use OCI network security groups to restrict access; rotate keys regularly.

[Auto-apply on merge] → Accidental production changes if main maps to prod. Mitigation: Main maps to staging; production requires manual dispatch with approval.

[State locking in CI/CD] → Concurrent workflow runs could deadlock. Mitigation: Lock timeout configured; workflows queue via GitHub concurrency groups.

[Self-hosted runner maintenance] → Runner updates, scaling, availability. Mitigation: Use GitHub-hosted for simplicity; self-hosted only if required for instance principals.

## Migration Plan

1. **Bootstrap**: Create OCI Object Storage bucket and Autonomous Database for state backend
2. **Identity**: Provision compartments, policies, groups, tag namespaces
3. **Network**: Create VCN, subnets, gateways, route tables, security lists
4. **Compute**: Provision instances in private subnets with NSGs
5. **Load Balancer**: Create public/private LBs with backend sets pointing to compute
6. **Database**: Provision Autonomous Database and/or DB Systems in private subnets
7. **Validation**: Run integration tests against deployed infrastructure
8. **CI/CD Setup**: Configure GitHub repository secrets, branch protection, workflows
9. **Rollback**: `terraform destroy` in reverse order; state bucket retained for recovery

## Open Questions

- Should we use OCI Resource Manager stacks instead of direct Terraform CLI?
- Do we need support for OKE (Kubernetes) in future phases?
- Should we implement drift detection and remediation automation?
- What is the exact compartment naming convention (prefix format)?
- Should production deployments use tag-based triggers (e.g., `deploy/prod/v1.0.0`) instead of manual dispatch?
- Do we need workflow for `terraform destroy` (decommission)?
- Should we implement policy-as-code checks (OPA, Checkov) in the PR workflow?