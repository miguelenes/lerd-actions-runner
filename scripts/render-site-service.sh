#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 ORGANIZATION-SLUG MACHINE-SLUG OUTPUT-PATH" >&2
  exit 2
}
[[ $# == 3 ]] || usage
organization=$1
machine_slug=$2
output=$3
[[ "$organization" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || usage
[[ "$machine_slug" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || usage
[[ "$output" == /* ]] || usage

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
if [[ -d "$script_dir/../skill/assets" ]]; then
  skill_dir="$script_dir/../skill"
else
  skill_dir="$script_dir/.."
fi
readonly service_name="gh-runner"
tmp=$(mktemp)
trap 'rm -f -- "$tmp"' EXIT
sed \
  -e "s/RUNNER_ORG/${organization}/g" \
  -e "s/RUNNER_MACHINE/${machine_slug}/g" \
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
