#!/bin/sh
# Thin POSIX dispatcher for canonicalize-sdd-yaml (REQ-003). Locates
# python3, else python, on PATH and execs canonicalize-sdd-yaml.py
# unchanged, with stdin/stdout/stderr passed through as-is (`exec` replaces
# this shell process, so no output is buffered or altered here). Exactly
# ONE behavioral implementation exists (the Python script beside this
# file); this wrapper never reimplements YAML canonicalization natively.
# If neither python3 nor python is found, denies fail-closed with the SAME
# documented exit code every .sh/.ps1/.js wrapper uses:
# CANONICALIZER_RUNTIME_UNAVAILABLE (exit 3). No output is produced on that
# path; the diagnostic goes to stderr only.
set -u

dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

if command -v python3 >/dev/null 2>&1; then
  exec python3 "$dir/canonicalize-sdd-yaml.py" "$@"
fi

if command -v python >/dev/null 2>&1; then
  exec python "$dir/canonicalize-sdd-yaml.py" "$@"
fi

echo 'canonicalize-sdd-yaml: CANONICALIZER_RUNTIME_UNAVAILABLE: no python3 or python interpreter found on PATH' >&2
exit 3
