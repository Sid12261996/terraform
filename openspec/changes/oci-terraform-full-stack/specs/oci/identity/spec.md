## Purpose

Manages OCI Identity and Access Management including compartments, policies, groups, users, and tagging governance for resource organization and access control.

## ADDED Requirements

### Requirement: Compartment hierarchy management
The system SHALL create and manage compartment hierarchy for resource isolation and organization.

#### Scenario: Create root compartment for environment
- **WHEN** user defines compartment "prod" under tenancy root
- **THEN** compartment is created with description and parent reference

#### Scenario: Create nested compartment structure
- **WHEN** user defines compartments: prod/network, prod/compute, prod/database
- **THEN** nested compartment hierarchy is created under prod parent

### Requirement: IAM Policy management
The system SHALL create and manage IAM policies for least-privilege access control.

#### Scenario: Create policy for compute instance management
- **WHEN** user defines policy allowing group "developers" to manage instances in compartment "prod/compute"
- **THEN** policy is created with specified statements and attached to compartment

#### Scenario: Create policy for network administration
- **WHEN** user defines policy allowing group "network-admins" to manage VCNs and subnets
- **THEN** policy grants network management permissions in specified compartments

#### Scenario: Create policy for database administration
- **WHEN** user defines policy allowing group "db-admins" to manage autonomous databases
- **THEN** policy grants database management permissions with resource constraints

### Requirement: Group and user management
The system SHALL create IAM groups and manage user membership.

#### Scenario: Create group and assign users
- **WHEN** user creates group "terraform-admins" and adds user OCIDs
- **THEN** group is created with specified users as members

#### Scenario: Create dynamic group for instance principals
- **WHEN** user defines dynamic group matching instance principals in compartment "prod"
- **THEN** dynamic group is created with matching rule for instance certificates

### Requirement: Tag namespace and tag definitions
The system SHALL create tag namespaces and defined tags for resource governance.

#### Scenario: Create tag namespace for cost center tracking
- **WHEN** user defines tag namespace "cost-center" with defined tags "dept", "project"
- **THEN** tag namespace is created with defined tag keys for mandatory tagging

#### Scenario: Create freeform tag for environment identification
- **WHEN** user applies freeform tag "environment=production" to resources
- **THEN** resources are tagged with environment identifier for filtering

### Requirement: Tag defaults and tagging enforcement
The system SHALL configure tag defaults on compartments for automatic tag propagation.

#### Scenario: Set tag defaults on compartment
- **WHEN** user configures tag default "cost-center=engineering" on compartment "prod"
- **THEN** all resources created in compartment inherit the tag default

### Requirement: Identity provider federation (OIDC)
The system SHALL support OIDC identity provider configuration for federated access.

#### Scenario: Configure OIDC identity provider
- **WHEN** user provides OIDC issuer URL, client ID, and JWKS URI
- **THEN** identity provider is created and can be mapped to groups via mapping rules