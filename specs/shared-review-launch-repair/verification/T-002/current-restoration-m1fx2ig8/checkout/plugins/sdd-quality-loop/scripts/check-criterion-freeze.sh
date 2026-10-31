#!/bin/sh
# WFI-045 deterministic gate: a commit may not rewrite frozen criterion prose
# in a reviewed tasks.md while also changing files outside specs/.
# Usage: check-criterion-freeze.sh [commit] [repo-root]
# Exit 0 = ok, 1 = criterion-prose edit in a mixed commit, 2 = runtime error.
#
# Thin dispatcher (same shape as check-contract.sh): python3 -> PowerShell ->
# error exit. Fails closed when neither runtime is available.
commit="${1:-HEAD}"
root="${2:-.}"

dir="$(dirname "$0")"

if command -v python3 >/dev/null 2>&1; then
  py_script="${dir}/check-criterion-freeze.py"
  if [ ! -f "$py_script" ]; then
    echo "check-criterion-freeze: check-criterion-freeze.py not found alongside check-criterion-freeze.sh" >&2
    exit 2
  fi
  COMMIT="$commit" ROOT="$root" python3 "$py_script"
  exit $?
fi

for ps in pwsh powershell.exe powershell; do
  if command -v "$ps" >/dev/null 2>&1; then
    "$ps" -NoProfile -ExecutionPolicy Bypass -File "${dir}/check-criterion-freeze.ps1" -Commit "$commit" -RepoRoot "$root"
    exit $?
  fi
done

echo "check-criterion-freeze: needs python3 or PowerShell. Install one, or run check-criterion-freeze.ps1 directly." >&2
exit 2
