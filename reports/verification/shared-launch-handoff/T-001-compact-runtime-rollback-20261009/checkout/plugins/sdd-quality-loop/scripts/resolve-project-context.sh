#!/bin/sh
# Thin POSIX dispatcher; the Python master is the sole implementation.
set -u
dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if command -v python3 >/dev/null 2>&1; then
  exec python3 "$dir/resolve-project-context.py" "$@"
fi
if command -v python >/dev/null 2>&1; then
  exec python "$dir/resolve-project-context.py" "$@"
fi
printf '%s\n' 'capability-resolver: runtime-unavailable: no python3 or python interpreter found' >&2
exit 3
