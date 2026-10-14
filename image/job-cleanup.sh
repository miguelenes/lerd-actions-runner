#!/usr/bin/env bash
set -euo pipefail
set +x
[[ "${DOCKER_HOST:-}" == tcp://127.0.0.1:2375 ]] || { echo "refusing cleanup: Docker host is not the private loopback daemon" >&2; exit 1; }
info=$(docker info --format '{{.Name}}')
[[ "$info" == lerd-actions-runner-* ]] || { echo "refusing cleanup: unexpected Docker daemon identity" >&2; exit 1; }

data_root="${LERD_RUNNER_DATA_ROOT:-/runner-data}"
[[ -d "$data_root" && ! -L "$data_root" ]] || { echo "refusing cleanup: runner data root is not a real directory" >&2; exit 1; }
data_root=$(realpath -e -- "$data_root")
work_root="$data_root/_work"
tmp_dir="$data_root/tmp"
[[ -d "$work_root" && ! -L "$work_root" ]] || { echo "refusing cleanup: runner work root is not a real directory" >&2; exit 1; }
[[ -d "$tmp_dir" && ! -L "$tmp_dir" ]] || { echo "refusing cleanup: runner temp root is not a real directory" >&2; exit 1; }
work_root=$(realpath -e -- "$work_root")
tmp_dir=$(realpath -e -- "$tmp_dir")
[[ "$work_root" == "$data_root/_work" && "$tmp_dir" == "$data_root/tmp" ]] || { echo "refusing cleanup: runner data paths escaped their root" >&2; exit 1; }

workspace=
if [[ -n "${GITHUB_WORKSPACE:-}" && -e "$GITHUB_WORKSPACE" ]]; then
  [[ -d "$GITHUB_WORKSPACE" && ! -L "$GITHUB_WORKSPACE" ]] || { echo "refusing cleanup: job workspace is not a real directory" >&2; exit 1; }
  workspace=$(realpath -e -- "$GITHUB_WORKSPACE")
  [[ "$workspace" == "$work_root"/* ]] || { echo "refusing cleanup: job workspace escaped the runner work root" >&2; exit 1; }
fi

temp_dir="$work_root/_temp"
if [[ -e "$temp_dir" ]]; then
  [[ -d "$temp_dir" && ! -L "$temp_dir" ]] || { echo "refusing cleanup: job temp path is not a real directory" >&2; exit 1; }
  temp_dir=$(realpath -e -- "$temp_dir")
  [[ "$temp_dir" == "$work_root/_temp" ]] || { echo "refusing cleanup: job temp path escaped the runner work root" >&2; exit 1; }
fi

docker ps -aq | xargs -r docker rm --force >/dev/null
docker network ls -q --filter type=custom | xargs -r docker network rm >/dev/null
docker volume ls -q | xargs -r docker volume rm --force >/dev/null
find "$tmp_dir" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
if [[ -n "$workspace" ]]; then
  find "$workspace" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
fi
if [[ -n "$temp_dir" && -d "$temp_dir" ]]; then
  find "$temp_dir" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
fi
docker image prune --all --force --filter until=168h >/dev/null
