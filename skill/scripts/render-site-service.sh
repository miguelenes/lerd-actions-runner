#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 SITE-SLUG MACHINE-SLUG OWNER/REPOSITORY OUTPUT-PATH" >&2
  exit 2
}
[[ $# == 4 ]] || usage
site_slug=$1
machine_slug=$2
repository=$3
output=$4
[[ "$site_slug" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || usage
[[ "$machine_slug" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || usage
[[ "$repository" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || usage
[[ "$output" == /* ]] || usage

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
if [[ -d "$script_dir/../skill/assets" ]]; then
  skill_dir="$script_dir/../skill"
else
  skill_dir="$script_dir/.."
fi
readonly service_name="github-actions-runner-${site_slug}"
readonly runner_name="lerd-${site_slug}-${machine_slug}"
tmp=$(mktemp)
trap 'rm -f -- "$tmp"' EXIT
sed \
  -e "s/RUNNER_SITE/${site_slug}/g" \
  -e "s/RUNNER_MACHINE/${machine_slug}/g" \
  -e "s|RUNNER_REPOSITORY|${repository}|g" \
  -e "s|github-actions-runner-${site_slug}|${service_name}|g" \
  -e "s/lerd-${site_slug}-${machine_slug}/${runner_name}/g" \
  "$skill_dir/assets/site-service.yaml" >"$tmp"

if [[ -e "$output" ]]; then
  if cmp -s "$tmp" "$output"; then
    echo "service definition already matches"
    exit 0
  fi
  echo "refusing to replace existing service definition: $output" >&2
  exit 1
fi
install -D -m 0600 "$tmp" "$output"
echo "created $service_name at $output"
