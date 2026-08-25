## Purpose

Provisions and manages complete OCI networking stack including VCN, subnets, gateways, route tables, security lists, and network security groups.

## ADDED Requirements

### Requirement: VCN creation and configuration
The system SHALL create a Virtual Cloud Network with configurable CIDR blocks and DNS settings.

#### Scenario: Create VCN with custom CIDR
- **WHEN** user specifies a CIDR block of 10.0.0.0/16
- **THEN** system creates a VCN with the specified CIDR range

#### Scenario: Enable DNS hostnames in VCN
- **WHEN** user enables DNS hostnames and provides a DNS label
- **THEN** VCN is created with DNS resolution enabled for instances

### Requirement: Subnet provisioning (public and private)
The system SHALL create public and private subnets with appropriate route tables and security configurations.

#### Scenario: Create public subnet with Internet Gateway route
- **WHEN** user defines a public subnet with CIDR 10.0.1.0/24
- **THEN** subnet is created with route table directing 0.0.0.0/0 to Internet Gateway

#### Scenario: Create private subnet with NAT Gateway route
- **WHEN** user defines a private subnet with CIDR 10.0.2.0/24
- **THEN** subnet is created with route table directing 0.0.0.0/0 to NAT Gateway

#### Scenario: Create private subnet with Service Gateway for OCI services
- **WHEN** user defines a private subnet for database workloads
- **THEN** subnet route table includes route to Service Gateway for all OCI services

### Requirement: Internet Gateway for public internet access
The system SHALL provision an Internet Gateway for VCN public internet connectivity.

#### Scenario: Create and attach Internet Gateway
- **WHEN** VCN requires public internet access
- **THEN** Internet Gateway is created and attached to the VCN

### Requirement: NAT Gateway for private subnet egress
The system SHALL provision a NAT Gateway for outbound internet access from private subnets.

#### Scenario: Create and attach NAT Gateway
- **WHEN** private subnets require outbound internet access
- **THEN** NAT Gateway is created, attached to VCN, and associated with private subnet route tables

### Requirement: Service Gateway for private OCI service access
The system SHALL provision a Service Gateway for private access to OCI services without internet.

#### Scenario: Create Service Gateway for all OCI services
- **WHEN** private subnets need access to Object Storage, Database, etc.
- **THEN** Service Gateway is created with "All OCI Services in Region" and attached to VCN

### Requirement: Route table management
The system SHALL manage route tables for directing traffic between subnets and gateways.

#### Scenario: Create custom route table with multiple routes
- **WHEN** user defines routes for Internet Gateway, NAT Gateway, and Service Gateway
- **THEN** route table is created with all specified routes and associated with subnets

### Requirement: Security Lists and Network Security Groups
The system SHALL configure security lists and network security groups for traffic filtering.

#### Scenario: Create security list with ingress/egress rules
- **WHEN** user defines allow rules for SSH (22), HTTP (80), HTTPS (443)
- **THEN** security list is created with specified ingress rules and permissive egress

#### Scenario: Create Network Security Group for application tier
- **WHEN** user defines NSG for web servers with specific port rules
- **THEN** NSG is created and can be attached to instance VNICs

### Requirement: DHCP options configuration
The system SHALL configure DHCP options for custom DNS and search domains.

#### Scenario: Configure custom DNS servers
- **WHEN** user specifies custom DNS server IPs
- **THEN** DHCP options set is created with custom DNS and attached to VCN