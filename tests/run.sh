#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
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
echo "runner template checks passed"
