---
name: lerd-add-actions-runner
description: Add, inspect, or remove a repository-scoped GitHub Actions runner managed by Lerd, including its isolated Docker daemon. Use for requests to add a self-hosted runner to an existing Lerd project; do not redirect existing CI without explicit instruction.
---

# Add a GitHub Actions runner to a Lerd project

Supports Linux x64, rootless Podman, systemd user services, and trusted private repositories. Existing workflows are not changed. Read this repository's README and helper scripts before acting.

## Discover and validate

1. Call Lerd site `list` and worker `list` before changing anything. Use the requested site; if project context picks one unambiguously, use it.
2. Read its Git origin without printing embedded credentials. Resolve the GitHub owner/repository from the remote. Stop if this is not GitHub or the remote is ambiguous.
3. Check Linux x86_64, rootless Podman, systemd user services, and authenticated `gh`. Confirm the GitHub repository is private and `gh` can administer Actions runners.
4. Use runner name `lerd-<site-slug>-<machine-slug>` and labels `lerd,lerd-<site-slug>`; normalize to lowercase alphanumeric hyphenated slugs. Check the GitHub runner list and Lerd service/worker lists for an existing matching installation.
5. Read the project and site `.lerd.yaml` and the existing smoke workflow if present. Preserve every unrelated entry. Do not use a global worker or edit existing CI workflows.

## Install

1. Add the `github-actions-runner` preset to the site service list. Install it only after the pinned image is published and available.
2. Set non-secret runner `RUNNER_URL`, `RUNNER_NAME`, and labels in the site's local custom-service definition. Never put registration credentials or PATs in YAML.
3. Copy `scripts/docker-supervisor.sh` from this skill's `scripts/` directory into a stable project-owned location. Add a custom Lerd worker with command `bash <absolute-path>`, label `Runner Docker daemon`, restart `always`; set `host: true` on that worker entry in the site `.lerd.yaml`. Keep host-command confirmation enabled; complete its normal interactive consent if asked.
4. Start service and worker. Register only when GitHub has no runner with the selected name. Run this skill's `scripts/runnerctl register <owner>/<repo>` after configuring its service/container selector for the selected site. It obtains a short-lived token from the authenticated `gh` session and pipes it into the service container stdin. Never print, persist, or put the token in argv; never use `--replace`.
5. Confirm readiness in Lerd worker health/logs and GitHub's runner API before reporting success.
6. Copy `skill/assets/lerd-runner-smoke.yml` into `.github/workflows/lerd-runner-smoke.yml` if it does not exist. Replace `RUNNER_LABEL` with the site slug and preserve SHA-pinned actions.

## Operate and remove

- `scripts/runnerctl status` inspects Lerd services/workers and runner/sidecar containers.
- `scripts/runnerctl start|stop` operates this project's service and worker.
- Revoke registration through the operator's authenticated GitHub session before service removal. Stop the worker/service and preserve data by default. Only remove the service data directory after explicit request to remove local registration credentials and job state.
- Never run untrusted pull request code, forks, or `pull_request_target` jobs on the persistent runner.
