#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
if grep -Eq -- '--replace' "$root/scripts/runnerctl"; then exit 1; fi
if grep -q 'REGISTRATION_TOKEN' "$root/services/github-actions-runner.yaml"; then exit 1; fi
grep -q "tcp://127.0.0.1:2375" "$root/image/Dockerfile"
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
"$root/scripts/render-site-service.sh" test desktop-pc owner/repo "$output" >/dev/null
before=$(sha256sum "$output")
"$root/scripts/render-site-service.sh" test desktop-pc owner/repo "$output" >/dev/null
[[ "$before" == "$(sha256sum "$output")" ]]
echo '# operator edit' >>"$output"
if "$root/scripts/render-site-service.sh" test desktop-pc owner/repo "$output" >/dev/null 2>&1; then
  echo "renderer overwrote a local edit" >&2
  exit 1
fi
grep -q '# operator edit' "$output"

# The registration helper streams its fixture token on stdin, never argv.
cat >"$tmp/bin/gh" <<'GH'
#!/usr/bin/env bash
[[ "$1" == auth ]] && exit 0
[[ "$1" == api ]] && { printf '%s\n' 'fixture-registration-token'; exit 0; }
exit 1
GH
cat >"$tmp/bin/podman" <<'PODMAN'
#!/usr/bin/env bash
for arg in "$@"; do
  [[ "$arg" == 'fixture-registration-token' ]] && exit 31
done
read -r incoming
[[ "$incoming" == "$EXPECTED_TOKEN" ]]
PODMAN
chmod +x "$tmp/bin/gh" "$tmp/bin/podman"
PATH="$tmp/bin:$PATH" EXPECTED_TOKEN=fixture-registration-token \
  LERD_RUNNER_SERVICE=github-actions-runner-test \
  "$root/scripts/runnerctl" register owner/repo >"$tmp/register.out" 2>"$tmp/register.err"
[[ ! -s "$tmp/register.out" && ! -s "$tmp/register.err" ]]

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
if rg -q '^(rm|network rm|volume rm|image prune)' "$tmp/docker.log"; then echo 'cleanup ran a destructive command' >&2; exit 1; fi

echo "runner template checks passed"
