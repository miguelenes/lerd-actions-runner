# Lerd runner setup skill

## ADDED Requirements

### Requirement: Site-scoped runner setup
The skill SHALL discover Lerd sites and workers, resolve the GitHub origin, and configure a uniquely named service and host worker without replacing unrelated project settings.

#### Scenario: Ambiguous project target
- **WHEN** multiple sites or Git remotes could be the requested project
- **THEN** the skill asks the user to select the target before mutating configuration

### Requirement: Short-lived registration
The skill SHALL obtain repository-scoped registration through the operator's authenticated GitHub CLI and stream it to the container over stdin. It SHALL not log or persist the token or automatically replace an existing registration.

#### Scenario: Runner name already exists
- **WHEN** GitHub already lists the selected runner name
- **THEN** setup reuses or inspects that installation without replacing it

### Requirement: Opt-in validation workflow
The skill SHALL add a manual smoke workflow when absent, using a site-specific runner label and SHA-pinned actions, without changing existing CI workflows.

#### Scenario: Smoke workflow stays opt-in
- **WHEN** the skill installs its validation workflow
- **THEN** the workflow runs only on `workflow_dispatch` and existing CI routing remains unchanged

### Requirement: Safe runner removal
The skill SHALL revoke the matching GitHub runner registration before removing local runner credentials, and preserve work, tool-cache, and Docker data unless the operator explicitly requests a purge.

#### Scenario: Runner registration is removed
- **WHEN** the operator removes a configured runner
- **THEN** GitHub no longer lists it and local work, tool-cache, and Docker data remain available
