# Add a Lerd managed GitHub Actions runner template

Provide an installable self-hosted runner image, a Lerd service preset, and a skill that configures one persistent repository-scoped runner per project with an isolated Docker daemon. Support Linux x64 on rootless Podman and keep registration credentials in the runner data volume. Include a manual smoke workflow, secure job cleanup, and explicit image publishing. Existing project workflows remain unchanged.
