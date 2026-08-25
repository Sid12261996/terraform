## Purpose

Configures Terraform remote state backend using OCI Object Storage with state locking via OCI Database (or DynamoDB-compatible) for team collaboration and state consistency.

## ADDED Requirements

### Requirement: Object Storage bucket for Terraform state
The system SHALL create an OCI Object Storage bucket for storing Terraform state files.

#### Scenario: Create state bucket with versioning enabled
- **WHEN** user specifies bucket name "terraform-state-prod" in compartment "prod"
- **THEN** bucket is created with object versioning enabled for state history

#### Scenario: Create state bucket with encryption
- **WHEN** user enables bucket encryption with OCI-managed keys
- **THEN** all state objects are encrypted at rest using AES-256

#### Scenario: Configure bucket lifecycle policy
- **WHEN** user sets lifecycle rule to delete previous versions after 90 days
- **THEN** bucket automatically removes old state versions per policy

### Requirement: State locking mechanism
The system SHALL provide state locking to prevent concurrent Terraform operations.

#### Scenario: Enable state locking with OCI Database
- **WHEN** user configures state locking using Autonomous Database table
- **THEN** Terraform acquires lock before operations and releases on completion

#### Scenario: Lock acquisition and release
- **WHEN** Terraform plan/apply runs
- **THEN** lock is acquired, operation executes, lock is released on success or failure

#### Scenario: Force unlock capability
- **WHEN** user runs `terraform force-unlock` with lock ID
- **THEN** stale lock is removed allowing subsequent operations

### Requirement: Backend configuration for Terraform
The system SHALL generate Terraform backend configuration for team use.

#### Scenario: Generate backend.tf with OCI Object Storage config
- **WHEN** user initializes Terraform with backend configuration
- **THEN** backend block specifies bucket, namespace, region, and lock table

#### Scenario: Support multiple environments with separate state
- **WHEN** user configures dev, staging, prod environments
- **THEN** each environment uses separate bucket or key prefix for state isolation

### Requirement: State access permissions
The system SHALL configure IAM policies for Terraform service principal state access.

#### Scenario: Grant state read/write to Terraform service principal
- **WHEN** user creates dynamic group for Terraform instances
- **THEN** policy allows dynamic group to manage objects in state bucket

#### Scenario: Restrict state access to specific compartments
- **WHEN** user limits state bucket access to "prod" compartment
- **THEN** only principals in prod compartment can access Terraform state