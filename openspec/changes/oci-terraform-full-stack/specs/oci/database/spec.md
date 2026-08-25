## Purpose

Provisions and manages Oracle Databases including Autonomous Database (ATP/ADW) and DB Systems (VM/BM) with backup, patching, and scaling configuration.

## ADDED Requirements

### Requirement: Autonomous Database provisioning
The system SHALL provision Autonomous Transaction Processing (ATP) and Autonomous Data Warehouse (ADW) databases.

#### Scenario: Create Autonomous Transaction Processing database
- **WHEN** user specifies ATP with 4 OCPUs and 1TB storage
- **THEN** ATP database is provisioned with specified compute and storage

#### Scenario: Create Autonomous Data Warehouse database
- **WHEN** user specifies ADW with 8 OCPUs and 2TB storage
- **THEN** ADW database is provisioned with specified compute and storage

#### Scenario: Configure Autonomous Database with private endpoint
- **WHEN** user specifies private subnet and NSG for database access
- **THEN** database is accessible only via private endpoint in the specified subnet

#### Scenario: Enable Auto Scaling on Autonomous Database
- **WHEN** user enables auto-scaling for ATP database
- **THEN** database automatically scales CPU up/down based on workload

### Requirement: DB System provisioning (VM and Bare Metal)
The system SHALL provision DB Systems for Oracle Database Enterprise Edition on VM or Bare Metal shapes.

#### Scenario: Create VM DB System
- **WHEN** user specifies VM.Standard.E4.Flex shape with 2 nodes
- **THEN** 2-node VM DB System is provisioned with specified shape

#### Scenario: Create Bare Metal DB System
- **WHEN** user specifies BM.Standard.E4.128 shape for single-node DB System
- **THEN** Bare Metal DB System is provisioned with 128 OCPUs

#### Scenario: Configure DB System with Data Guard
- **WHEN** user enables Data Guard with standby in different availability domain
- **THEN** primary and standby DB Systems are created with Data Guard configured

### Requirement: Database backup and recovery configuration
The system SHALL configure automated backups and recovery windows for databases.

#### Scenario: Configure automatic backups with retention
- **WHEN** user sets backup retention to 30 days for Autonomous Database
- **THEN** daily automatic backups are retained for 30 days

#### Scenario: Configure manual backup
- **WHEN** user triggers on-demand backup for DB System
- **THEN** manual backup is created and available for restore

### Requirement: Database patching and maintenance
The system SHALL manage patching schedules and maintenance windows.

#### Scenario: Configure maintenance window for Autonomous Database
- **WHEN** user sets maintenance window to Saturday 02:00-06:00 UTC
- **THEN** patches are applied only during the specified maintenance window

#### Scenario: Configure patching mode for DB System
- **WHEN** user sets patching mode to ROLLING for 2-node VM DB System
- **THEN** patches are applied in rolling fashion to minimize downtime

### Requirement: Database connection and networking
The system SHALL configure database network access, wallets, and connection strings.

#### Scenario: Generate wallet for Autonomous Database
- **WHEN** user requests wallet for ATP database
- **THEN** wallet zip is generated with TLS certificates and connection strings

#### Scenario: Configure database private endpoint access
- **WHEN** user attaches NSG allowing port 1521/2484 from application subnet
- **THEN** database accepts connections only from allowed sources