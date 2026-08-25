## Purpose

Provisions and manages OCI Load Balancers (public and private) with backend sets, listeners, health checks, and SSL termination.

## ADDED Requirements

### Requirement: Public Load Balancer provisioning
The system SHALL create public load balancers with public IP addresses for internet-facing traffic.

#### Scenario: Create public load balancer with flexible shape
- **WHEN** user specifies a flexible load balancer with minimum 100 Mbps and maximum 8000 Mbps
- **THEN** public load balancer is created with public IP and flexible bandwidth

#### Scenario: Create public load balancer with reserved public IP
- **WHEN** user provides a reserved public IP OCID
- **THEN** load balancer is created using the specified reserved public IP

### Requirement: Private Load Balancer provisioning
The system SHALL create private load balancers with private IPs for internal traffic only.

#### Scenario: Create private load balancer in private subnet
- **WHEN** user specifies a private subnet for load balancer
- **THEN** private load balancer is created with private IP in the specified subnet

### Requirement: Backend set configuration
The system SHALL configure backend sets with servers, health checks, and load balancing policies.

#### Scenario: Create backend set with round-robin policy
- **WHEN** user defines backend set with ROUND_ROBIN policy and two backend servers
- **THEN** backend set distributes traffic evenly across both servers

#### Scenario: Create backend set with least-connections policy
- **WHEN** user defines backend set with LEAST_CONNECTIONS policy
- **THEN** load balancer routes new connections to backend with fewest active connections

#### Scenario: Configure health checks for backend set
- **WHEN** user defines HTTP health check on path /health with 30s interval
- **THEN** load balancer performs health checks and removes unhealthy backends

#### Scenario: Configure session persistence
- **WHEN** user enables cookie-based session persistence
- **THEN** load balancer maintains session affinity using HTTP cookies

### Requirement: Listener configuration
The system SHALL create listeners for HTTP, HTTPS, and TCP protocols with SSL termination.

#### Scenario: Create HTTP listener on port 80
- **WHEN** user defines HTTP listener on port 80 forwarding to backend set
- **THEN** listener accepts HTTP traffic and routes to configured backend set

#### Scenario: Create HTTPS listener with SSL certificate
- **WHEN** user provides SSL certificate and private key for HTTPS listener on port 443
- **THEN** listener terminates SSL and forwards decrypted traffic to backend set

#### Scenario: Create TCP listener for non-HTTP traffic
- **WHEN** user defines TCP listener on port 3306 for database traffic
- **THEN** listener passes TCP traffic through to backend set without inspection

### Requirement: SSL certificate management
The system SHALL support SSL certificate upload and association with HTTPS listeners.

#### Scenario: Upload and associate SSL certificate
- **WHEN** user provides certificate bundle (cert, key, CA chain)
- **THEN** certificate is stored in OCI Certificates service and associated with HTTPS listener

### Requirement: Load Balancer lifecycle and scaling
The system SHALL support load balancer start, stop, and bandwidth scaling operations.

#### Scenario: Scale load balancer bandwidth
- **WHEN** user updates flexible load balancer max bandwidth from 4000 to 8000 Mbps
- **THEN** load balancer scales to new maximum bandwidth without downtime