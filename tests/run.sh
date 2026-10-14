#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
if grep -Eq -- '--replace' "$root/scripts/runnerctl"; then exit 1; fi
if grep -q 'REGISTRATION_TOKEN' "$root/services/github-actions-runner.yaml"; then exit 1; fi
grep -q "tcp://127.0.0.1:2375" "$root/image/Dockerfile"
grep -q 'ACTIONS_RUNNER_HOOK_JOB_COMPLETED=/usr/local/bin/lerd-runner-job-cleanup.sh' "$root/image/entrypoint.sh"
grep -q 'lerd-actions-runner-' "$root/image/job-cleanup.sh"
python3 - "$root" <<'PY'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
service = (root / "services/github-actions-runner.yaml").read_text()
index = json.loads((root / "services/index.json").read_text())
entries = [s for s in index["services"] if s["name"] == "github-actions-runner"]
assert len(entries) == 1
assert entries[0]["description"] in service
assert "ports:" not in service
assert "RUNNER_TOKEN" not in service and "REGISTRATION_TOKEN" not in service
PY

# The service renderer is idempotent and refuses to overwrite a local edit.
mkdir -p "$tmp/bin"
output="$tmp/github-actions-runner-test.yaml"
"$root/scripts/render-site-service.sh" illuma-law local-linux "$output" >/dev/null
before=$(sha256sum "$output")
"$root/scripts/render-site-service.sh" illuma-law local-linux "$output" >/dev/null
[[ "$before" == "$(sha256sum "$output")" ]]
echo '# operator edit' >>"$output"
if "$root/scripts/render-site-service.sh" test desktop-pc owner/repo "$output" >/dev/null 2>&1; then
  echo "renderer overwrote a local edit" >&2
  exit 1
fi
grep -q '# operator edit' "$output"

# Organization registration creates a selected-only private runner group,
# preserves its existing repository members, and streams the token on stdin.
cat >"$tmp/bin/gh" <<'GH'
#!/usr/bin/env bash
[[ "$1" == auth ]] && exit 0
if [[ "$1" == api && "$2" == orgs/illuma-law/actions/runner-groups ]]; then exit 0; fi
if [[ "$1" == api && "$2" == --method && "$3" == POST && "$4" == orgs/illuma-law/actions/runner-groups ]]; then
  printf '{"id":9,"visibility":"selected","allows_public_repositories":false}\n'
elif [[ "$1" == api && "$2" == repos/illuma-law/lerd-actions-runner-validation ]]; then
  if [[ " $* " == *" --jq .id "* ]]; then printf '100\n'; else printf '{"id":100,"private":true}\n'; fi
elif [[ "$1" == api && "$2" == --paginate && "$3" == orgs/illuma-law/actions/runner-groups/9/repositories ]]; then
  printf '42\n'
elif [[ "$1" == api && "$2" == --method && "$3" == PUT && "$4" == orgs/illuma-law/actions/runner-groups/9/repositories ]]; then
  printf '%s\n' "$*" >>"$GH_CALLS"
elif [[ "$1" == api && "$2" == orgs/illuma-law/actions/runners ]]; then
  exit 0
elif [[ "$1" == api && "$2" == --method && "$3" == POST && "$4" == orgs/illuma-law/actions/runners/registration-token ]]; then
  printf '%s\n' 'fixture-registration-token'
else
  exit 1
fi
exit 0
GH
cat >"$tmp/bin/podman" <<'PODMAN'
#!/usr/bin/env bash
for arg in "$@"; do
  [[ "$arg" == 'fixture-registration-token' ]] && exit 31
done
[[ "$1" == exec && "$2" == --interactive && "$3" == lerd-gh-runner ]] || exit 32
read -r incoming
[[ "$incoming" == "$EXPECTED_TOKEN" ]]
PODMAN
chmod +x "$tmp/bin/gh" "$tmp/bin/podman"
mkdir -p "$tmp/config/lerd/services"
cat >"$tmp/config/lerd/services/gh-runner.yaml" <<'YAML'
environment:
  RUNNER_NAME: lerd-gh-runner-local-linux
YAML
: >"$tmp/gh-calls.log"
PATH="$tmp/bin:$PATH" HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/config" GH_CALLS="$tmp/gh-calls.log" \
  EXPECTED_TOKEN=fixture-registration-token LERD_RUNNER_SERVICE=gh-runner \
  "$root/scripts/runnerctl" register --org illuma-law illuma-law/lerd-actions-runner-validation \
  >"$tmp/register.out" 2>"$tmp/register.err"
[[ ! -s "$tmp/register.out" && ! -s "$tmp/register.err" ]]
grep -q 'selected_repository_ids\[\]=42' "$tmp/gh-calls.log"
grep -q 'selected_repository_ids\[\]=100' "$tmp/gh-calls.log"

# Organization removal validates the matching registration, streams its token,
# stops the Lerd units, and leaves local data in place.
cat >"$tmp/bin/gh" <<'GH'
#!/usr/bin/env bash
[[ "$1" == auth ]] && exit 0
if [[ "$1" == api && "$2" == orgs/illuma-law/actions/runners ]]; then
  printf '42\n'
elif [[ "$1" == api && "$2" == --method ]]; then
  [[ "$3" == POST && "$4" == orgs/illuma-law/actions/runners/remove-token ]] || exit 1
  printf '%s\n' fixture-removal-token
else
  exit 1
fi
GH
cat >"$tmp/bin/podman" <<'PODMAN'
#!/usr/bin/env bash
if [[ "$1" == inspect ]]; then
  printf 'ghcr.io/example/runner@sha256:fixture\n'
elif [[ "$1" == run ]]; then
  [[ " $* " == *" --interactive "* ]] || exit 32
  for arg in "$@"; do [[ "$arg" == fixture-removal-token ]] && exit 31; done
  read -r incoming
  [[ "$incoming" == fixture-removal-token ]]
else
  exit 1
fi
PODMAN
cat >"$tmp/bin/lerd" <<'LERD'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$LERD_CALLS"
LERD
chmod +x "$tmp/bin/gh" "$tmp/bin/podman" "$tmp/bin/lerd"
: >"$tmp/lerd-calls.log"
mkdir -p "$tmp/data/lerd/data/gh-runner/state" "$tmp/config/lerd/services"
printf '{"agentName":"lerd-gh-runner-local-linux","gitHubUrl":"https://github.com/illuma-law"}\n' \
  >"$tmp/data/lerd/data/gh-runner/state/.runner"
cat >"$tmp/config/lerd/services/gh-runner.yaml" <<'YAML'
image: ghcr.io/example/runner@sha256:fixture
YAML
PATH="$tmp/bin:$PATH" HOME="$tmp/home" XDG_DATA_HOME="$tmp/data" XDG_CONFIG_HOME="$tmp/config" LERD_CALLS="$tmp/lerd-calls.log" \
  LERD_RUNNER_SERVICE=gh-runner LERD_RUNNER_WORKER=docker-gh-runner \
  "$root/scripts/runnerctl" remove --org illuma-law >"$tmp/remove.out" 2>"$tmp/remove.err"
[[ ! -s "$tmp/remove.out" && ! -s "$tmp/remove.err" ]]
[[ "$(cat "$tmp/lerd-calls.log")" == $'worker stop docker-gh-runner\nservice stop gh-runner' ]]
[[ -s "$tmp/data/lerd/data/gh-runner/state/.runner" ]]

# A mismatched daemon identity must fail before any destructive Docker command.
cat >"$tmp/bin/docker" <<'DOCKER'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$DOCKER_CALLS"
if [[ "$1" == info ]]; then printf '%s\n' unexpected-daemon; exit 0; fi
exit 0
DOCKER
chmod +x "$tmp/bin/docker"
if PATH="$tmp/bin:$PATH" DOCKER_CALLS="$tmp/docker.log" \
  DOCKER_HOST=tcp://127.0.0.1:2375 "$root/image/job-cleanup.sh" >/dev/null 2>&1; then
  echo "cleanup accepted an unexpected daemon" >&2
  exit 1
fi
if grep -Eq '^(rm|network rm|volume rm|image prune)' "$tmp/docker.log"; then echo 'cleanup ran a destructive command' >&2; exit 1; fi

# Cleanup removes only workspace/temp data under the runner data root and keeps the tool cache.
cleanup_data="$tmp/runner-data"
mkdir -p "$cleanup_data/_work/job-1" "$cleanup_data/_work/_temp" "$cleanup_data/_toolcache" "$cleanup_data/tmp" "$tmp/outside"
printf x >"$cleanup_data/_work/job-1/workspace-file"
printf x >"$cleanup_data/_work/_temp/temp-file"
printf x >"$cleanup_data/tmp/temp-file"
printf x >"$cleanup_data/_toolcache/cache-file"
printf x >"$tmp/outside/keep-file"
cat >"$tmp/bin/docker" <<'DOCKER'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$DOCKER_CALLS"
case "$1" in
  info) printf '%s\n' lerd-actions-runner-test ;;
  ps|network|volume) ;;
  *) ;;
esac
DOCKER
chmod +x "$tmp/bin/docker"
: >"$tmp/docker-safe.log"
PATH="$tmp/bin:$PATH" DOCKER_CALLS="$tmp/docker-safe.log" DOCKER_HOST=tcp://127.0.0.1:2375 \
  LERD_RUNNER_DATA_ROOT="$cleanup_data" GITHUB_WORKSPACE="$cleanup_data/_work/job-1" \
  "$root/image/job-cleanup.sh"
[[ ! -e "$cleanup_data/_work/job-1/workspace-file" && ! -e "$cleanup_data/_work/_temp/temp-file" && ! -e "$cleanup_data/tmp/temp-file" ]]
[[ -e "$cleanup_data/_toolcache/cache-file" && -e "$tmp/outside/keep-file" ]]

# A traversal workspace fails before the private Docker daemon is asked to remove anything.
: >"$tmp/docker-boundary.log"
if PATH="$tmp/bin:$PATH" DOCKER_CALLS="$tmp/docker-boundary.log" DOCKER_HOST=tcp://127.0.0.1:2375 \
  LERD_RUNNER_DATA_ROOT="$cleanup_data" GITHUB_WORKSPACE="$cleanup_data/_work/../_toolcache" \
  "$root/image/job-cleanup.sh" >/dev/null 2>&1; then
  echo "cleanup accepted a workspace outside the work root" >&2
  exit 1
fi
if grep -Eq '^(rm|network rm|volume rm|image prune)' "$tmp/docker-boundary.log"; then
  echo 'cleanup made Docker changes before validating workspace boundaries' >&2
  exit 1
fi

# A job-controlled symlink at the runner temp path is rejected before cleanup.
rmdir "$cleanup_data/_work/_temp"
ln -s "$tmp/outside" "$cleanup_data/_work/_temp"
: >"$tmp/docker-symlink.log"
if PATH="$tmp/bin:$PATH" DOCKER_CALLS="$tmp/docker-symlink.log" DOCKER_HOST=tcp://127.0.0.1:2375 \
  LERD_RUNNER_DATA_ROOT="$cleanup_data" "$root/image/job-cleanup.sh" >/dev/null 2>&1; then
  echo "cleanup accepted a symlinked temp path" >&2
  exit 1
fi
if grep -Eq '^(rm|network rm|volume rm|image prune)' "$tmp/docker-symlink.log"; then
  echo 'cleanup made Docker changes before validating temp path boundaries' >&2
  exit 1
fi

# A changed runner container id forces the Docker sidecar back into the new namespace.
cat >"$tmp/bin/podman" <<'PODMAN'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$PODMAN_CALLS"
case "$1:$2" in
  info:*) printf true ;;
  inspect:*)
    case "$3" in
      *'{{.Id}}'*) [[ -f "$PODMAN_STATE/new-runner" ]] && printf runner-new || printf runner-old ;;
      *'{{.State.Running}}'*) printf true ;;
      *'{{index .Config.Labels "lerd-runner-id"}}'*) cat "$PODMAN_STATE/sidecar-id" 2>/dev/null || true ;;
    esac
    ;;
  update:*) ;;
  rm:*) rm -f "$PODMAN_STATE/sidecar-id" ;;
  run:*)
    for arg in "$@"; do
      case "$arg" in lerd-runner-id=*) printf '%s' "${arg#*=}" >"$PODMAN_STATE/sidecar-id";; esac
    done
    ;;
esac
PODMAN
cat >"$tmp/bin/sleep" <<'SLEEP'
#!/usr/bin/env bash
if [[ ! -e "$PODMAN_STATE/new-runner" ]]; then
  touch "$PODMAN_STATE/new-runner"
elif [[ ! -e "$PODMAN_STATE/replacement-seen" ]]; then
  touch "$PODMAN_STATE/replacement-seen"
else
  exit 1
fi
SLEEP
chmod +x "$tmp/bin/podman" "$tmp/bin/sleep"
mkdir -p "$tmp/podman-state"
if PATH="$tmp/bin:$PATH" PODMAN_CALLS="$tmp/podman-replace.log" PODMAN_STATE="$tmp/podman-state" \
  HOME="$tmp/home" XDG_DATA_HOME="$tmp/data" LERD_RUNNER_NAME=test \
  "$root/scripts/docker-supervisor.sh" >/dev/null 2>&1; then
  echo "supervisor unexpectedly continued after the replacement fixture ended" >&2
  exit 1
fi
grep -q -- '--network container:lerd-test' "$tmp/podman-replace.log"
grep -q -- "--volume $tmp/data/lerd/data/test/_work:/runner-data/_work:z" "$tmp/podman-replace.log"
grep -q -- "--volume $tmp/data/lerd/data/test/tmp:/runner-data/tmp:z" "$tmp/podman-replace.log"
if grep -q -- "--volume $tmp/data/lerd/data/test:/runner-data" "$tmp/podman-replace.log"; then
  echo 'sidecar exposed the runner registration directory' >&2
  exit 1
fi
grep -q -- '--label lerd-runner-id=runner-old' "$tmp/podman-replace.log"
grep -q -- '--label lerd-runner-id=runner-new' "$tmp/podman-replace.log"
[[ $(grep -c '^run ' "$tmp/podman-replace.log") == 2 ]]

echo "runner template checks passed"
