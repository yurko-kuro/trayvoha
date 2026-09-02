#!/usr/bin/env bash

set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(CDPATH= cd -- "$script_dir/../.." && pwd)"
output_dir="${1:-$repo_root/dist}"
top_dir="$(mktemp -d)"
trap 'rm -rf -- "$top_dir"' EXIT

command -v rpmbuild >/dev/null 2>&1 || {
    echo "Для складання пакета потрібна команда rpmbuild." >&2
    exit 1
}

mkdir -p "$output_dir"
rpmbuild -bb "$script_dir/trayvoha.spec" \
    --define "_topdir $top_dir" \
    --define "_rpmdir $output_dir" \
    --define "repo_root $repo_root"

find "$output_dir" -type f -name 'trayvoha-*.noarch.rpm' -print
