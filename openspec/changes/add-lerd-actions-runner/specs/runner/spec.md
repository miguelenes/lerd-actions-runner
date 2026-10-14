# Runner service and runtime

## ADDED Requirements

### Requirement: Persistent repository runner
The template SHALL provide a versioned Linux x64 GitHub Actions runner image with its upstream release archive verified by SHA-256. A Lerd service SHALL persist runner registration and job state without publishing service ports or storing a registration token.

#### Scenario: Runner waits for operator registration
- **WHEN** the service starts without runner credentials
- **THEN** the container remains available for one-time registration and does not repeatedly fail or register itself

### Requirement: Private Docker daemon
The host worker SHALL supervise a private Docker sidecar inside the runner container's network namespace, bind its API to loopback only, constrain CPU and memory, and preserve Docker data separately from runner state.

#### Scenario: Runner is recreated
- **WHEN** the Lerd runner container changes identity
- **THEN** the supervisor replaces the sidecar against the new namespace and retains the configured data volumes

### Requirement: Safe job cleanup
The runner SHALL clean job containers, custom networks, job-created volumes, temporary files, and the checked job workspace only after confirming the expected loopback daemon identity. It SHALL preserve runner credentials and the tool cache.

#### Scenario: Unexpected Docker daemon
- **WHEN** the configured Docker endpoint or daemon identity does not match this runner
- **THEN** cleanup refuses to remove resources
