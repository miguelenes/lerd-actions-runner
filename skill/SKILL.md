---
name: lerd-add-actions-runner
description: Add, inspect, or remove the shared organization GitHub Actions runner managed by Lerd. One local runner container serves selected trusted private repositories in an organization.
---

# Manage the shared Lerd Actions runner

Supports Linux x64, rootless Podman, systemd user services, and trusted private GitHub organization repositories. Install one shared `gh-runner` service on the Lerd host; repositories in its private `lerd-private` runner group can target it with `runs-on: [self-hosted, lerd-<org>]`. The shared runner processes one job at a time, so other repositories' jobs wait while it is busy. Existing workflows remain unchanged unless a maintainer opts them in.

## Discover and install

1. Call Lerd `site` `action: "list"` and `worker` `action: "list"` before changing anything. Use the current site's Git remote to identify its GitHub organization, and stop if the target owner is not an organization or is ambiguous.
2. Confirm Linux x86_64, rootless Podman, systemd user, authenticated `gh`, an active organization admin membership, and the ability to administer organization runners and runner groups. If `gh` lacks the `admin:org` OAuth scope, stop and ask the operator to run `gh auth refresh --hostname github.com --scopes admin:org`, then continue. Confirm there is no conflicting local `gh-runner` service or runner name.
3. Keep the single service name `gh-runner`, container name `lerd-gh-runner`, and worker name `docker-gh-runner`. Derive a stable machine slug from the hostname. The GitHub runner name is `gh-<machine>` and its labels are `lerd,lerd-<org-slug>`.
4. Install or reconcile the service definition at `~/.config/lerd/services/gh-runner.yaml` using `scripts/render-site-service.sh <org-slug> <machine-slug> <absolute-output-path>`. The renderer preserves an identical definition and refuses to overwrite a local edit. If `gh-runner` already exists, reuse its service, runner credentials, data, and host worker; never create a second runner container for another repository.
5. Choose one Lerd site as the runner host. Add `gh-runner` to that site's `.lerd.yaml` `services` list. Copy this skill's `scripts/docker-supervisor.sh` to a stable host path under that site, then add one custom worker named `docker-gh-runner` with `restart: always`, `host: true`, and command `LERD_RUNNER_NAME=gh-runner LERD_DIND_IMAGE=docker:29-dind@sha256:4c42359ca23de31b73b7a58396a9ca1f3b9c8e0ffbb309f34c3b14c12d889d69 bash <absolute-script-path>`. Do not add a per-worktree worker or change host-command consent settings. Complete Lerd's normal command-consent step when requested. The shared service is global to the Lerd host; repositories do not get separate runner containers.
6. Start the service and worker. Confirm the runner and private Docker sidecar are healthy, the Docker API listens only on runner namespace loopback, and the worker monitors `lerd-gh-runner` replacement.

## Share with repositories

1. For each target repository, verify its origin is `<org>/<repo>` and the organization is trusted for private self-hosted jobs. Do not add public repositories to the runner group.
2. `scripts/runnerctl register --org <org> <org>/<repo>` creates or reconciles the organization runner group `lerd-private` with selected-repository visibility and public-repository access disabled, adds only that repository to the group, and registers the one shared runner if absent. GitHub registration tokens are streamed over stdin and never logged, persisted, or passed in process arguments. Never use `--replace`.
3. Copy `assets/lerd-runner-smoke.yml` to `.github/workflows/lerd-runner-smoke.yml` when requested, replacing `RUNNER_LABEL` with the organization slug. Keep it manual and opt-in. The workflow exercises private Docker, bind mounts, localhost service ports, container jobs, cleanup, cache retention, and artifact upload.
4. Existing organization repositories can use `runs-on: [self-hosted, lerd-<org-slug>]` when their maintainers opt in. Do not rewrite existing CI as part of installation.
5. Confirm the runner is online in the organization inventory and run the manual smoke workflow in a private repository before reporting end-to-end success.

## Operate and remove

- Run `scripts/runnerctl status` from the runner-host site. Set `LERD_RUNNER_SERVICE=gh-runner` and `LERD_RUNNER_WORKER=docker-gh-runner` only when overriding defaults.
- `scripts/runnerctl start|stop` controls the single shared service and worker. Worker restart detects runner-container replacement and rebuilds only its sidecar; registration, Docker data, and tool cache persist.
- `scripts/runnerctl remove --org <org>` verifies that the local registration belongs to the organization, obtains a short-lived removal token, stops the worker and service, then removes only GitHub registration credentials. Workspace, Docker data, and tool cache stay on disk.
- Job cleanup verifies loopback Docker, daemon identity, and canonical runner/workspace paths before deleting the private daemon's job containers, networks, volumes, temporary data, and workspace. It retains the tool cache and images newer than seven days.
- Never run untrusted pull requests, forks, or `pull_request_target` jobs on the persistent runner.
