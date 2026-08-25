## ADDED Requirements

### Requirement: Additional named service routes
The system SHALL support additional named backend sets and listeners on the public load balancer so multiple services with distinct ports can share one load balancer without altering the default backend set.

#### Scenario: Register an additional service route
- **WHEN** a named route (for example, `immich`) is configured with a listener port of 2283, a backend port, and a health check path
- **THEN** the public load balancer gains a backend set targeting the configured backends on that backend port plus an HTTP listener on the listener port wired to that backend set

#### Scenario: Default route remains intact
- **WHEN** additional named service routes exist on the public load balancer
- **THEN** the original default backend set and its listeners keep their configuration and traffic

#### Scenario: Per-route health checking
- **WHEN** a named service route defines its own health check protocol, port, and URL path
- **THEN** only that route's backend set uses the specified health check configuration
