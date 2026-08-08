#!/bin/sh
# Thin POSIX dispatcher for validate-approval-sidecar (REQ-005). Locates
# python3, else python, on PATH and execs validate-approval-sidecar.py
# unchanged, with stdin/stdout/stderr passed through as-is (`exec` replaces
# this shell process, so no output is buffered or altered here). Exactly
# ONE behavioral implementation exists (the Python script beside this
# file); this wrapper never reimplements validation natively.
# If neither python3 nor python is found, denies fail-closed with the SAME
# documented exit code the sibling canonicalize-sdd-yaml.sh/.ps1 and
# generate-approval-sidecar.sh/.ps1 wrappers use for this condition
# (exit 3). No output is produced on that path; the diagnostic goes to
# stderr only.
set -u

dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

if command -v python3 >/dev/null 2>&1; then
  exec python3 "$dir/validate-approval-sidecar.py" "$@"
fi

if command -v python >/dev/null 2>&1; then
  exec python "$dir/validate-approval-sidecar.py" "$@"
fi

echo 'validate-approval-sidecar: VALIDATE_APPROVAL_SIDECAR_RUNTIME_UNAVAILABLE: no python3 or python interpreter found on PATH' >&2
exit 3
