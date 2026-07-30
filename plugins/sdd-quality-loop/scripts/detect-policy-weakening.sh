#!/bin/sh
# Thin POSIX dispatcher for detect-policy-weakening (REQ-006). Locates
# python3, else python, on PATH and execs detect-policy-weakening.py
# unchanged, with stdin/stdout/stderr passed through as-is (`exec` replaces
# this shell process, so no output is buffered or altered here). Exactly
# ONE behavioral implementation exists (the Python script beside this
# file); this wrapper never reimplements classification/verdict logic
# natively. If neither python3 nor python is found, denies fail-closed with
# the SAME documented exit code the sibling canonicalize-sdd-yaml.sh/.ps1 /
# generate-approval-sidecar.sh/.ps1 wrappers use for this condition
# (exit 3). No output is produced on that path; the diagnostic goes to
# stderr only.
set -u

dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

if command -v python3 >/dev/null 2>&1; then
  exec python3 "$dir/detect-policy-weakening.py" "$@"
fi

if command -v python >/dev/null 2>&1; then
  exec python "$dir/detect-policy-weakening.py" "$@"
fi

echo 'detect-policy-weakening: DETECT_POLICY_WEAKENING_RUNTIME_UNAVAILABLE: no python3 or python interpreter found on PATH' >&2
exit 3
