#!/usr/bin/env bash
set -euo pipefail
set +x
[[ "${DOCKER_HOST:-}" == tcp://127.0.0.1:2375 ]] || { echo "refusing cleanup: Docker host is not the private loopback daemon" >&2; exit 1; }
info=$(docker info --format '{{.Name}}')
[[ "$info" == lerd-actions-runner-* ]] || { echo "refusing cleanup: unexpected Docker daemon identity" >&2; exit 1; }
docker ps -aq | xargs -r docker rm --force >/dev/null
docker network ls -q --filter type=custom | xargs -r docker network rm >/dev/null
docker volume ls -q | xargs -r docker volume rm --force >/dev/null
find /runner-data/tmp -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
if [[ -n "${GITHUB_WORKSPACE:-}" && "$GITHUB_WORKSPACE" == /runner-data/_work/* && -d "$GITHUB_WORKSPACE" ]]; then
  find "$GITHUB_WORKSPACE" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
fi
docker image prune --all --force --filter until=168h >/dev/null
