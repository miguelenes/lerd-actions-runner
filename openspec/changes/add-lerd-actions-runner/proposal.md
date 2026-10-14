# Add a Lerd managed GitHub Actions runner template

Provide an installable self-hosted runner image, a Lerd service preset, and a skill that configures one persistent organization-scoped runner per host with an isolated Docker daemon. Support Linux x64 on rootless Podman, restrict the runner group to selected trusted private repositories, and keep registration credentials in the runner data volume. Include a manual smoke workflow, secure job cleanup, and explicit image publishing. Existing project workflows remain unchanged.
