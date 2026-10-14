# Design

The runner is a versioned Ubuntu image whose Actions runner download is verified with the official release SHA-256. One short-named Lerd custom service per host owns its persistent organization registration and work data. One host worker observes the runner container ID and starts a privileged Docker sidecar in that container's network namespace, binding Docker only to loopback. The sidecar uses a separate persistent data directory and fixed image digest. A recreated runner causes only the sidecar to be replaced.

A short-lived organization registration token is obtained from the operator's authenticated GitHub CLI and piped through stdin. Neither service config nor runner image contains registration secrets. The runner is assigned to a selected-repository group that excludes public repositories. A manual smoke workflow exercises Docker and workflow services without changing existing CI routing.

The initial release supports trusted private GitHub organization repositories on Linux x64 with rootless Podman and systemd user services. The service-store preset is data-only; the skill owns one shared local worker and service configuration. Image publication is a separate manual workflow. The preset's immutable image digest is updated only after publication.
