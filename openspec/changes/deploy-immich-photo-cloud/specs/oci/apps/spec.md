## Purpose

Hosts self-managed open-source applications (starting with Immich, the photo library server) on OCI compute provisioned by this stack, giving each app a dedicated server profile, persistent data storage, automated first-boot installation, exposure through the public load balancer, and a post-apply access URL.

## ADDED Requirements

### Requirement: Application repository layout
The system SHALL organize every self-hosted application under an `apps/<app-name>/` directory containing that application's deployment assets.

#### Scenario: Add a new application to the stack
- **WHEN** a new application is added to the stack
- **THEN** a dedicated `apps/<app-name>/` directory holds its deployment assets and documentation without touching other apps' directories

#### Scenario: Immich app assets are present
- **WHEN** the repository is inspected
- **THEN** `apps/immich/` contains the cloud-init template, environment-variable template, and a README describing operation and data locations

### Requirement: Immich server provisioning
The system SHALL provision a dedicated Immich server in production using an Ampere A1.Flex shape with the configured OCPU and memory allocation (default 4 OCPU / 24 GB), placed in a private subnet.

#### Scenario: Production apply creates the Immich server
- **WHEN** Terraform is applied with the production configuration
- **THEN** a compute instance with VM.Standard.A1.Flex shape, 4 OCPUs, and 24 GB memory is created in a private subnet with no public IP

#### Scenario: Other environments are unaffected
- **WHEN** development or staging configurations are applied
- **THEN** no Immich-specific resources are created

### Requirement: Photo library data volume
The system SHALL attach a dedicated block volume sized by configuration (default 200 GB) to the Immich server and make it available to the OS at `/srv/apps/immich`.

#### Scenario: Volume attached and mounted on first boot
- **WHEN** the Immich server is provisioned with a 200 GB data volume
- **THEN** the volume is created, attached, formatted once, mounted at `/srv/apps/immich`, and persists across reboots

#### Scenario: Volume size follows configuration
- **WHEN** the operator changes the configured data volume size before first apply
- **THEN** the attached block volume reflects the requested size in GB

### Requirement: Automated first-boot installation
The system SHALL install Docker and run the official Immich install script during first boot, storing the photo library under the mounted data volume.

#### Scenario: Fresh instance becomes a working Immich host
- **WHEN** the Immich server completes its first boot
- **THEN** Docker is running and the Immich containers serve the web UI on local port 2283 with library data written under `/srv/apps/immich`

#### Scenario: Reboot preserves the installation
- **WHEN** the Immich server is rebooted
- **THEN** Docker restarts and the Immich containers come back up without manual intervention

### Requirement: Exposure through the public load balancer
The system SHALL expose Immich through the existing public load balancer via a dedicated backend set and HTTP listener on port 2283, health-checked against Immich's ping endpoint.

#### Scenario: Traffic routed to healthy Immich server
- **WHEN** the Immich server reports a successful health check
- **THEN** requests to `http://<lb-public-ip>:2283` reach the Immich web UI

#### Scenario: Unhealthy backend drained
- **WHEN** the Immich server fails consecutive health checks
- **THEN** the load balancer stops routing traffic to it until checks pass again

#### Scenario: Existing services keep their routing
- **WHEN** the Immich route is added to the load balancer
- **THEN** pre-existing backend sets and listeners continue to operate unchanged

### Requirement: Post-deploy machine URL output
The system SHALL output the ready-to-use Immich machine URL after a successful apply.

#### Scenario: Operator reads the access URL
- **WHEN** the production apply completes successfully
- **THEN** Terraform outputs `http://<lb-public-ip>:2283` as the Immich URL alongside the instance's private IP for SSH access

### Requirement: Network access control for app traffic
The system SHALL restrict ingress to the Immich server to load-balancer-originated traffic on port 2283 and administrative SSH, keeping the instance without a public IP.

#### Scenario: Direct internet access blocked
- **WHEN** an external client attempts to connect directly to the Immich server's private address from the internet
- **THEN** the connection is blocked because the instance has no public IP and network security rules admit only load-balancer subnets on port 2283

#### Scenario: Load balancer reaches the backend
- **WHEN** the public load balancer forwards a request to the Immich server on port 2283
- **THEN** network security rules permit traffic from the load balancer subnets to the instance
