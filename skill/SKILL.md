---
name: lerd-add-actions-runner
description: Add, inspect, or remove a repository-scoped GitHub Actions runner managed by Lerd, including its isolated Docker daemon. Use for requests to add a self-hosted runner to an existing Lerd project; do not redirect existing CI without explicit instruction.
---

# Add a GitHub Actions runner to a Lerd project

Supports Linux x64, rootless Podman, systemd user services, and trusted private GitHub repositories. Existing workflows stay as they are. Read the assets and helper scripts distributed with this skill before acting.

## Discover and validate

1. Call Lerd `site` with `action: "list"` and `worker` with `action: "list"` before changing anything. Select the requested site, or use the only site clearly associated with the project. Stop for user choice if several remain plausible.
2. Read Git origin URLs without printing embedded credentials. Resolve the GitHub owner/repository. Stop if no unambiguous GitHub origin exists.
3. Confirm Linux x86_64, rootless Podman, user systemd, authenticated `gh`, a private repository, and GitHub Actions runner administration access. Confirm there is no same-name runner in GitHub and no conflicting Lerd service/worker.
4. Derive `site_slug`, `machine_slug`, and `service_name=github-actions-runner-<site_slug>`. Normalize slugs to lowercase alphanumeric hyphenated strings. Keep the service name within Lerd's `[a-z0-9][a-z0-9-]*` format. Labels are `lerd,lerd-<site_slug>`; runner name is `lerd-<site_slug>-<machine_slug>`.
5. Read root and site `.lerd.yaml` files and the target workflow directory. Preserve existing entries and only add the named runner service and worker. Do not edit existing CI.

## Install

1. Check that `github-actions-runner` is available with `lerd service search github-actions-runner`. Use this skill's renderer to create a site-specific copy of `assets/site-service.yaml` with the selected repo and slugs: `scripts/render-site-service.sh <site_slug> <machine_slug> <owner>/<repo> ~/.config/lerd/services/<service_name>.yaml`. It uses the runner image digest bundled with this skill. If the file already exists, the renderer accepts identical content and refuses to overwrite a local edit. The generated service has only non-secret URL, name, and label values.
2. Add that file with `lerd service add <absolute-service-file>`. Reference `<service_name>` under the target site's `services` list, preserving all existing items. Start it with Lerd. The initial runner container waits for registration; it does not restart in a failure loop.
3. Copy `scripts/docker-supervisor.sh` from this skill to a stable project-owned path outside generated/build directories. Add a site custom worker named `docker-<site_slug>` with label `Runner Docker daemon`, `restart: always`, and command `LERD_RUNNER_NAME=<service_name> LERD_DIND_IMAGE=docker:29-dind@sha256:4c42359ca23de31b73b7a58396a9ca1f3b9c8e0ffbb309f34c3b14c12d889d69 bash <absolute-script-path>`. Set `host: true` on this exact entry in the site's `.lerd.yaml`; do not use a global worker or change host-command consent settings. Complete Lerd's normal command-consent step when requested.
4. Start the worker and wait for the private daemon to become ready. Use Lerd service/worker status and logs to confirm both containers are healthy and the Docker API binds only to runner namespace loopback.
5. Query GitHub's runner inventory. If the selected name is absent, run this skill's `scripts/runnerctl register <owner>/<repo>` from the site's root, setting `LERD_RUNNER_SERVICE=<service_name>` and `LERD_RUNNER_WORKER=docker-<site_slug>`. The helper gets a one-hour registration token from the authenticated `gh` session and streams it through stdin to the running container. The token is never written or printed, and must not appear in arguments or environment. Never use automatic replacement. If registration fails, report the generic error and inspect service logs without displaying token material.
6. Copy `assets/lerd-runner-smoke.yml` to `.github/workflows/lerd-runner-smoke.yml` if it does not already exist. Replace `RUNNER_LABEL` with `<site_slug>`. Keep this manual workflow opt-in; it does not redirect other workflows. It checks Docker, localhost published services, a container job with a workflow service, and artifact upload.
7. Confirm the runner reports online in GitHub and the runner, sidecar, Lerd service, and host worker report healthy. Then run the manual smoke workflow and inspect its actual run and artifacts before claiming end-to-end success.

## Operate and remove

- Run `scripts/runnerctl status` from the Lerd site root. Set `LERD_RUNNER_SERVICE` and `LERD_RUNNER_WORKER` for site-specific names.
- `scripts/runnerctl start|stop` controls that site's service and worker. A worker restart detects a recreated runner container and rebuilds only its Docker sidecar; persistent registration, Docker data, and tool cache remain.
- Job cleanup acts only after confirming loopback Docker and the expected `lerd-actions-runner-*` daemon hostname. It removes that private daemon's job containers, networks, volumes, temporary data, and checked workspace, retaining the tool cache and images newer than seven days.
- Revoke the GitHub runner registration first when removing it. Stop its worker and service; preserve local data by default. Delete the service data directory only after explicit request to remove runner credentials and workspace.
- Never run untrusted pull requests, forks, or `pull_request_target` jobs on the persistent runner.
