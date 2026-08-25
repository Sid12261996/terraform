## Purpose

Provisions and manages OCI compute instances including VM and Bare Metal shapes with custom images, SSH keys, and instance metadata.

## ADDED Requirements

### Requirement: Compute instance provisioning
The system SHALL provision OCI compute instances with specified shape, image, and network configuration.

#### Scenario: Create VM instance with custom shape
- **WHEN** user specifies a VM.Standard.E4.Flex shape with 4 OCPUs and 32GB memory
- **THEN** system creates a compute instance with the requested shape configuration

#### Scenario: Create Bare Metal instance
- **WHEN** user specifies a BM.Standard.E4.128 shape
- **THEN** system provisions a Bare Metal instance with 128 OCPUs

#### Scenario: Use custom image for instance
- **WHEN** user provides a custom image OCID
- **THEN** system launches the instance using the specified custom image

### Requirement: SSH key management
The system SHALL configure SSH public keys on compute instances for remote access.

#### Scenario: Attach SSH key at instance creation
- **WHEN** user provides an SSH public key in the configuration
- **THEN** instance is created with the SSH key injected for the default user

#### Scenario: Multiple SSH keys for instance
- **WHEN** user provides multiple SSH public keys
- **THEN** all keys are configured for the default user on the instance

### Requirement: Instance metadata and user data
The system SHALL support instance metadata and cloud-init user data for boot-time configuration.

#### Scenario: Configure instance metadata
- **WHEN** user specifies metadata key-value pairs
- **THEN** instance metadata service exposes the provided key-value pairs

#### Scenario: Execute cloud-init user data
- **WHEN** user provides cloud-init user data script
- **THEN** instance executes the user data on first boot

### Requirement: Instance lifecycle management
The system SHALL support instance start, stop, reboot, and terminate operations.

#### Scenario: Stop and start instance
- **WHEN** user triggers instance stop then start
- **THEN** instance transitions to STOPPED then RUNNING state preserving boot volume

#### Scenario: Reboot instance
- **WHEN** user triggers instance reboot
- **THEN** instance performs graceful reboot and returns to RUNNING state

#### Scenario: Terminate instance with boot volume preservation
- **WHEN** user terminates instance with preserve-boot-volume set to true
- **THEN** instance is terminated but boot volume is retained for future use