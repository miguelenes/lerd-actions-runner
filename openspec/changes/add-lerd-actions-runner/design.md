# Design

The runner is a versioned Ubuntu image whose Actions runner download is verified with the official release SHA-256. A Lerd custom service owns its persistent registration and work data. A site-scoped host worker observes the runner container ID and starts a privileged Docker sidecar in that container's network namespace, binding Docker only to loopback. The sidecar uses a separate persistent data directory and fixed image digest. A recreated runner causes only the sidecar to be replaced.

A short-lived registration token is obtained from the operator's authenticated GitHub CLI and piped through stdin. Neither repository config nor runner image contains registration secrets. Per-site service config is generated from the service-store preset. A manual smoke workflow exercises Docker and workflow services without changing existing CI routing.

The initial release supports trusted private GitHub repositories on Linux x64 with rootless Podman and systemd user services. The service-store preset is data-only; the skill owns site-scoped worker and service configuration. Image publication is a separate manual workflow. The preset's immutable image digest is updated only after publication.
