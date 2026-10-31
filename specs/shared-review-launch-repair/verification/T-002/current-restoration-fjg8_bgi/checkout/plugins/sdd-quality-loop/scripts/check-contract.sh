#!/bin/sh
# Deterministic gate: verify a Default-FAIL verification contract.
# Usage: check-contract.sh <path-to-contract.json> [repo-root]
# Exit 1 while any required check has passes=false, or any passing check has
# empty or missing evidence. This gate fails closed: it errors when neither
# python3 nor PowerShell is available.
# Additional rules enforced:
#  - Duplicate check ids → fail.
#  - Evidence path safety → fail if absolute (POSIX or Windows) or contains ..
#    traversal that escapes the repo root.
#  - Waiver enforcement → required:false + passes:false must have non-empty
#    waiver_reason; otherwise operator must run the check or record why it
#    does not apply.
#  - Required-set protection → baseline ids (lint, typecheck, unit-tests, build,
#    placeholder-scan, task-state-check) must be present; if present but
#    required:false, waiver_reason must be non-empty.
#
# R-04: The 315-line inline Python heredoc has been extracted to check-contract.py.
#        This script is now a thin dispatcher: python3 → PowerShell → error exit.
contract="$1"
root="${2:-.}"

if [ -z "$contract" ] || [ ! -f "$contract" ]; then
  echo "check-contract: contract file not found: $contract" >&2
  exit 1
fi

dir="$(dirname "$0")"

if command -v python3 >/dev/null 2>&1; then
  # R-04: invoke standalone check-contract.py (fail-closed if missing).
  py_script="${dir}/check-contract.py"
  if [ ! -f "$py_script" ]; then
    echo "check-contract: check-contract.py not found alongside check-contract.sh" >&2
    exit 1
  fi
  CONTRACT="$contract" ROOT="$root" python3 "$py_script"
  exit $?
fi

for ps in pwsh powershell.exe powershell; do
  if command -v "$ps" >/dev/null 2>&1; then
    "$ps" -NoProfile -ExecutionPolicy Bypass -File "${dir}/check-contract.ps1" -ContractPath "$contract" -RepoRoot "$root"
    exit $?
  fi
done

echo "check-contract: needs python3 or PowerShell. Install one, or run check-contract.ps1 directly." >&2
exit 1
