#!/usr/bin/env bash
set -euo pipefail
set +x
readonly state=/runner-data/state
readonly work=/runner-data/_work
readonly runner_files=(.runner .credentials .credentials_rsaparams)
mkdir -p "$state" "$work" /runner-data/tmp /runner-data/_toolcache
export RUNNER_TOOL_CACHE=/runner-data/_toolcache
for name in "${runner_files[@]}"; do
  if [[ -e "$state/$name" && ! -e "/opt/actions-runner/$name" ]]; then ln -s "$state/$name" "/opt/actions-runner/$name"; fi
done
if [[ "${1:-run}" == register ]]; then
  if [[ -f "$state/.runner" ]]; then echo "runner is already registered" >&2; exit 2; fi
  [[ -n "${RUNNER_URL:-}" && -n "${RUNNER_NAME:-}" ]] || { echo "RUNNER_URL and RUNNER_NAME are required" >&2; exit 2; }
  IFS= read -r token || true
  [[ -n "${token:-}" ]] || { echo "registration token is required on stdin" >&2; exit 2; }
  chmod 700 "$state"
  ./config.sh --unattended --url "$RUNNER_URL" --token "$token" --name "$RUNNER_NAME" --labels "${RUNNER_LABELS:-lerd}" --work "$work" --disableupdate >/dev/null
  unset token
  for name in "${runner_files[@]}"; do
    [[ -f "/opt/actions-runner/$name" ]] || { echo "registration omitted $name" >&2; exit 1; }
    [[ -e "$state/$name" ]] || mv "/opt/actions-runner/$name" "$state/$name"
    ln -sfn "$state/$name" "/opt/actions-runner/$name"
  done
  chmod 600 "$state"/.runner "$state"/.credentials*
  echo "runner registration saved in its private service volume"
  exit 0
fi
if [[ "${1:-run}" == remove ]]; then
  [[ -f "$state/.runner" ]] || { echo "runner is not registered" >&2; exit 2; }
  IFS= read -r token || true
  [[ -n "${token:-}" ]] || { echo "removal token is required on stdin" >&2; exit 2; }
  ./config.sh remove --unattended --token "$token" >/dev/null
  unset token
  rm -f -- "$state/.runner" "$state/.credentials" "$state/.credentials_rsaparams"
  echo "runner registration removed; workspace and tool cache retained"
  exit 0
fi
while :; do
  registered=true
  for name in "${runner_files[@]}"; do
    if [[ ! -s "$state/$name" ]]; then registered=false; break; fi
    [[ -e "/opt/actions-runner/$name" ]] || ln -s "$state/$name" "/opt/actions-runner/$name"
  done
  if [[ "$registered" == true ]]; then
    break
  fi
  sleep 15
done
export ACTIONS_RUNNER_HOOK_JOB_STARTED=/usr/local/bin/lerd-runner-job-cleanup.sh
export ACTIONS_RUNNER_HOOK_JOB_COMPLETED=/usr/local/bin/lerd-runner-job-cleanup.sh
for _ in $(seq 1 90); do
  if docker info >/dev/null 2>&1; then exec ./run.sh; fi
  sleep 2
done
echo "private Docker sidecar did not become ready" >&2
exit 1
