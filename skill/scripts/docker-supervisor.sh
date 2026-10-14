#!/usr/bin/env bash
set -euo pipefail
set +x
command -v podman >/dev/null || { echo "Podman is required on the Lerd host" >&2; exit 2; }
podman info --format '{{.Host.Security.Rootless}}' | grep -qx true || { echo "This runner requires rootless Podman" >&2; exit 2; }
readonly name="${LERD_RUNNER_NAME:-github-actions-runner}"
readonly container="lerd-${name}"
readonly sidecar="lerd-actions-runner-${name}-dind"
readonly data="${XDG_DATA_HOME:-$HOME/.local/share}/lerd/data/${name}"
readonly daemon_data="${XDG_DATA_HOME:-$HOME/.local/share}/lerd/data/${name}-dind"
readonly image="${LERD_DIND_IMAGE:-docker:29-dind@sha256:4c42359ca23de31b73b7a58396a9ca1f3b9c8e0ffbb309f34c3b14c12d889d69}"
mkdir -p "$daemon_data"
cleanup() { podman rm --force "$sidecar" >/dev/null 2>&1 || true; }
trap cleanup EXIT INT TERM
while :; do
  runner_id=$(podman inspect --format '{{.Id}}' "$container" 2>/dev/null || true)
  runner_state=$(podman inspect --format '{{.State.Running}}' "$container" 2>/dev/null || true)
  if [[ -n "$runner_id" && "$runner_state" == true ]]; then
    if [[ "$(podman inspect --format '{{.State.Running}}' "$sidecar" 2>/dev/null || true)" != true || "$(podman inspect --format '{{.Config.Labels.lerd-runner-id}}' "$sidecar" 2>/dev/null || true)" != "$runner_id" ]]; then
      cleanup
      podman run --detach --privileged --name "$sidecar" --network "container:$container" \
        --hostname "$sidecar" --env DOCKER_TLS_CERTDIR= --label "lerd-runner-id=$runner_id" --volume "$daemon_data:/var/lib/docker:Z" \
        --volume "$data:/runner-data:Z" --volume "$data/tmp:/tmp:Z" \
        --cpus "${LERD_DIND_CPUS:-2}" --memory "${LERD_DIND_MEMORY:-4g}" --entrypoint dockerd "$image" \
        --host=unix:///var/run/docker.sock --host=tcp://127.0.0.1:2375 --tls=false --storage-driver=vfs
    fi
  else
    cleanup
  fi
  sleep 5
done
