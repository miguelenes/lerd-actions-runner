# Lerd runner setup skill

## Requirements

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
