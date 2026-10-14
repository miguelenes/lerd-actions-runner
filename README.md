# Lerd GitHub Actions runner

A persistent, repository scoped Actions runner managed as a Lerd custom service,
with a private Docker daemon supervised by a Lerd host worker. Version one targets
Linux x64, rootless Podman, systemd user services, and trusted private repositories.

Install and deploy the `lerd-add-actions-runner` skill from this repository, then
invoke it in the target project. It discovers the Lerd site and GitHub origin,
installs the `github-actions-runner` preset, adds a site scoped worker, and merges
an opt in smoke workflow. Existing workflows stay as they are.

The service has no ports and stores runner credentials and job state in
`~/.local/share/lerd/data/github-actions-runner/`. The short lived registration
token is read from stdin and is not written to disk or printed. GitHub runner
credentials stay in the private data directory after registration.

The host worker starts Docker inside the runner's private network namespace. The
Docker API listens on `127.0.0.1:2375` in that namespace only. Docker data lives
in a separate Podman volume. Job cleanup checks daemon identity before clearing
its containers, networks, volumes, temporary files, and job workspace; the tool
cache remains.

The isolated daemon uses a privileged container inside rootless Podman. It never
mounts the host Docker or Podman socket. Do not run untrusted code on this runner.
Stop the Lerd worker to pause jobs. Do not remove service data unless you intend
to remove runner credentials and workspace.

Use `scripts/runnerctl remove <owner>/<repo>` from the project root to revoke
the matching GitHub registration and remove its local runner credentials. The
workspace and private Docker data remain in place; purge them separately only
when explicitly requested.

The runner image is built from the official Actions runner release with its
release SHA-256 verified before extraction. Pull requests build without
publishing. Publish is manually dispatched. Update the service-store preset
after resolving the published image to its immutable digest.

## Local checks

```sh
./tests/run.sh
shellcheck image/entrypoint.sh image/job-cleanup.sh scripts/runnerctl scripts/docker-supervisor.sh tests/run.sh
podman build -t lerd-actions-runner:local image
```

Live validation requires a registered test runner and rootless Podman.
