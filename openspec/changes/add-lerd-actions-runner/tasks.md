## Runner image and lifecycle

- [x] Create an Ubuntu runner image with a SHA-256 verified Actions runner download.
- [x] Add a private Docker supervisor with rootless Podman feasibility evidence, namespace loopback API binding, persistent data, and constrained resources.
- [x] Add token-stdin registration, persistent runner credentials, and guarded job cleanup.
- [x] Add shell checks, CI, and opt-in image publishing.

## Lerd integration and skill

- [x] Define the service preset and per-site service template.
- [x] Write the `lerd-add-actions-runner` skill and manual smoke workflow.
- [x] Publish runner image `0.1.2` and pin digest `sha256:d0cee9301e5b61c6d07e15e418df9796e040bedfb44e8b91fffa6c12d755be4d` in the service store.
- [x] Add the service-store preset and open draft pull request [lerd-env/services#44](https://github.com/lerd-env/services/pull/44).
- [x] Run manual smoke workflow `38615198572` on isolated Lerd site `lerd-actions-runner-validation`; verify job cleanup, tool-cache persistence, Docker commands, host-local workflow service, container job/service, bind mount, artifact upload, and runner removal.

## Shared organization runner follow-up

- [ ] Reconcile the validation service to one short-named shared `gh-runner` instance.
- [ ] Register at `illuma-law` organization scope in a selected-only group for trusted private repositories.
- [ ] Update the skill, manual workflow asset, and service-store documentation to describe the shared runner.
