## ADDED Requirements

### Requirement: Architecture-aware image selection
The system SHALL launch compute images whose CPU architecture matches the instance shape whenever no explicit image OCID is provided.

#### Scenario: Arm64 shape receives arm64 image
- **WHEN** an instance pool uses VM.Standard.A1.Flex without an explicit image OCID
- **THEN** the latest Oracle Linux aarch64 image compatible with that shape is selected automatically

#### Scenario: Explicit image OCID takes precedence
- **WHEN** an instance pool specifies an explicit image OCID
- **THEN** that exact image is used regardless of automatic architecture detection

### Requirement: Dedicated block volume attachment
The system SHALL support attaching dedicated block volumes to individual compute instances, with the volume created, attached paravirtualized, and left available to the OS for formatting and mounting.

#### Scenario: Instance requests a data volume
- **WHEN** an instance is configured with a data volume size greater than zero gigabytes
- **THEN** a block volume of that size is created in the same availability domain and attached to the instance as a paravirtualized device

#### Scenario: Instance without a data volume
- **WHEN** an instance is configured without a data volume size
- **THEN** no block volume is created or attached

#### Scenario: Volume survives instance replacement
- **WHEN** the Immich instance is replaced while its data volume is configured for preservation
- **THEN** the block volume and its stored photo library remain intact for reattachment
