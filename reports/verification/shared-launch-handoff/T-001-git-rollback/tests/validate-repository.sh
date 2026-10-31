#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)

if ! command -v pwsh >/dev/null 2>&1; then
    printf '%s\n' 'Repository validation requires pwsh.' >&2
    exit 1
fi

exec pwsh -NoProfile -File "$script_dir/validate-repository.ps1"
