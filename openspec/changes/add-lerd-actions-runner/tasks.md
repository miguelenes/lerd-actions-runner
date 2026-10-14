## Runner image and lifecycle

- [x] Create an Ubuntu runner image with a SHA-256 verified Actions runner download.
- [x] Add a private Docker supervisor with rootless Podman feasibility evidence, namespace loopback API binding, persistent data, and constrained resources.
- [x] Add token-stdin registration, persistent runner credentials, and guarded job cleanup.
- [x] Add shell checks, CI, and opt-in image publishing.

## Lerd integration and skill

- [x] Define the service preset and per-site service template.
- [x] Write the `lerd-add-actions-runner` skill and manual smoke workflow.
- [ ] Publish a versioned runner image and pin its digest in the service store.
- [ ] Add the service-store preset and open its draft pull request.
- [ ] Run a manual smoke workflow on a separately registered Lerd test site and record actual GitHub status.
