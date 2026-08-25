## 1. Project Setup and Bootstrap

- [x] 1.1 Initialize Terraform project structure with main.tf, variables.tf, outputs.tf, versions.tf and verify `terraform init` succeeds
- [x] 1.2 Create OCI provider configuration with instance principals and API key auth fallback, verify provider initializes
- [x] 1.3 Create state backend bootstrap script (create Object Storage bucket, Autonomous DB lock table) and verify resources exist in OCI
- [x] 1.4 Configure backend.tf with OCI Object Storage backend and verify `terraform init -migrate-state` works
- [x] 1.5 Create environment variable files (dev.tfvars, staging.tfvars, prod.tfvars) with region, compartment, and sizing defaults

## 2. Identity and Governance (oci/identity)

- [x] 2.1 Implement compartment hierarchy module (root → env → functional) and verify compartments created in correct hierarchy
- [x] 2.2 Implement IAM policy module for compute, network, database, and admin groups and verify policies attach correctly
- [x] 2.3 Implement group and dynamic group module (terraform-admins, developers, network-admins, db-admins, instance-principals) and verify group membership
- [x] 2.4 Implement tag namespace module (governance namespace with environment, owner, cost-center, project) and verify tags are definable
- [x] 2.5 Implement tag defaults on compartments and verify resources inherit tags automatically
- [ ] 2.6 (Optional) Implement OIDC identity provider module and verify federation works with test IdP

## 3. Networking (oci/network)

- [x] 3.1 Implement VCN module with configurable CIDR, DNS labels, and verify VCN created with correct settings
- [x] 3.2 Implement public subnet module with Internet Gateway route table association and verify public subnet has 0.0.0.0/0 → IGW route
- [x] 3.3 Implement private subnet module with NAT Gateway and Service Gateway route table associations and verify private subnet routes
- [x] 3.4 Implement Internet Gateway module and verify IGW attached to VCN and reachable
- [x] 3.5 Implement NAT Gateway module and verify private subnet egress works via NAT
- [x] 3.6 Implement Service Gateway module (All OCI Services) and verify private access to Object Storage/Database
- [x] 3.7 Implement route table module with custom routes and verify routes propagate to associated subnets
- [x] 3.8 Implement security list module (SSH, HTTP, HTTPS, custom ports) and verify rules apply to subnets
- [x] 3.9 Implement Network Security Group module for application tiers and verify NSG attaches to VNICs
- [x] 3.10 Implement DHCP options module with custom DNS and verify instances receive custom DNS config

## 4. Compute (oci/compute)

- [x] 4.1 Implement compute instance module with flexible shape support (VM.Standard.E4.Flex) and verify instance provisions with correct OCPU/memory
- [x] 4.2 Implement Bare Metal shape support (BM.Standard.E4.128) and verify BM instance provisions
- [x] 4.3 Implement custom image support via image OCID variable and verify instance launches from custom image
- [x] 4.4 Implement SSH key injection module (single and multiple keys) and verify SSH access works with injected keys
- [x] 4.5 Implement instance metadata and cloud-init user data module and verify user data executes on boot
- [ ] 4.6 Implement instance lifecycle operations (stop, start, reboot, terminate with boot volume preservation) and verify state transitions

## 5. Load Balancer (oci/load-balancer)

- [x] 5.1 Implement public flexible load balancer module (100-8000 Mbps) and verify LB provisions with public IP
- [x] 5.2 Implement private flexible load balancer module in private subnet and verify LB provisions with private IP
- [x] 5.3 Implement backend set module with round-robin and least-connections policies and verify traffic distribution
- [x] 5.4 Implement health check module (HTTP/TCP) and verify unhealthy backends are removed from rotation
- [x] 5.5 Implement session persistence module (cookie-based) and verify session affinity works
- [x] 5.6 Implement HTTP listener module (port 80) and verify traffic forwards to backend set
- [x] 5.7 Implement HTTPS listener module with SSL certificate from OCI Certificates and verify SSL termination
- [x] 5.8 Implement TCP listener module (e.g., port 3306) and verify TCP passthrough works
- [ ] 5.9 Implement SSL certificate management module and verify certificate associates with HTTPS listener
- [ ] 5.10 Implement load balancer bandwidth scaling and verify max bandwidth updates without downtime

## 6. Database (oci/database)

- [x] 6.1 Implement Autonomous Transaction Processing (ATP) module with OCPU/storage config and verify database provisions
- [x] 6.2 Implement Autonomous Data Warehouse (ADW) module and verify database provisions
- [x] 6.3 Implement private endpoint configuration for Autonomous Database and verify access only via private IP
- [x] 6.4 Implement auto-scaling enablement for Autonomous Database and verify CPU scales with load
- [x] 6.5 Implement VM DB System module (2-node RAC) and verify DB System provisions
- [x] 6.6 Implement Bare Metal DB System module and verify DB System provisions
- [x] 6.7 Implement Data Guard configuration for DB System (primary + standby in different AD) and verify replication
- [x] 6.8 Implement backup configuration module (retention, manual backup trigger) and verify backups created
- [x] 6.9 Implement maintenance window and patching configuration and verify patches apply in window
- [x] 6.10 Implement wallet generation for Autonomous Database and verify wallet contains valid certs and connection strings

## 7. State Backend (oci/state-backend)

- [x] 7.1 Implement Object Storage bucket module with versioning and encryption and verify bucket created with settings
- [x] 7.2 Implement bucket lifecycle policy module (delete old versions after 90 days) and verify policy applies
- [x] 7.3 Implement state locking table in Autonomous Database and verify lock acquire/release works
- [x] 7.4 Implement IAM policy for Terraform service principal state access and verify dynamic group can read/write state
- [x] 7.5 Generate backend configuration template and verify `terraform init` works for team members

## 8. Integration and Validation

- [x] 8.1 Wire all modules in root main.tf with proper dependencies and verify `terraform plan` succeeds for dev environment
- [ ] 8.2 Apply dev environment and verify all resources create successfully in OCI
- [ ] 8.3 Test compute instance SSH access via public load balancer and verify connectivity
- [ ] 8.4 Test private subnet egress via NAT Gateway and verify internet access from private instances
- [ ] 8.5 Test database connectivity from compute instances in private subnet and verify connection works
- [ ] 8.6 Test load balancer health checks and failover by stopping a backend instance and verify traffic redirects
- [ ] 8.7 Run `terraform destroy` on dev environment and verify clean teardown (state bucket retained)
- [ ] 8.8 Validate staging and prod tfvars produce correct plans and verify no unintended changes
- [x] 8.9 Document usage in README.md with examples for each environment and verify documentation accuracy

## 9. CI/CD Pipeline (oci/ci-cd)

- [x] 9.1 Create GitHub Actions workflow `.github/workflows/terraform-plan.yml` with fmt, init, plan jobs and verify it triggers on PR
- [x] 9.2 Configure workflow to post terraform plan output as PR comment and verify comment appears on test PR
- [x] 9.3 Create GitHub Actions workflow `.github/workflows/terraform-apply.yml` with init, apply jobs and verify it triggers on merge to main
- [x] 9.4 Implement manual approval gate for production environment in apply workflow and verify approval pauses workflow
- [ ] 9.5 Add GitHub repository secrets for OCI authentication (user OCID, tenancy OCID, fingerprint, private key, region) and verify workflow authenticates
- [ ] 9.6 Add GitHub repository variables for OCI region, compartment OCID, environment mapping and verify workflow reads them
- [ ] 9.7 Configure branch protection rules on main branch requiring "terraform-plan" status check and verify merge blocked without passing plan
- [ ] 9.8 Configure GitHub Actions concurrency group to prevent concurrent applies and verify queuing works
- [ ] 9.9 Test full PR flow: create PR → plan runs → review → merge → apply runs → verify resources deployed
- [ ] 9.10 Test production deployment: trigger manual workflow dispatch → approval → apply → verify prod resources deployed
- [x] 9.11 Document CI/CD setup in docs/ci-cd.md with secrets, variables, workflow diagrams and verify documentation accuracy