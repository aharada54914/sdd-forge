#!/bin/sh
# Deterministic gate: verify a Default-FAIL verification contract.
# Usage: check-contract.sh <path-to-contract.json> [repo-root]
# Exit 1 while any required check has passes=false, or any passing check has
# empty or missing evidence. This gate fails closed: it errors when neither
# python3 nor PowerShell is available.
contract="$1"
root="${2:-.}"

if [ -z "$contract" ] || [ ! -f "$contract" ]; then
  echo "check-contract: contract file not found: $contract" >&2
  exit 1
fi

if command -v python3 >/dev/null 2>&1; then
  CONTRACT="$contract" ROOT="$root" python3 - <<'PYEOF'
import json, os, sys

contract_path = os.environ["CONTRACT"]
root = os.environ["ROOT"]
with open(contract_path, encoding="utf-8") as f:
    contract = json.load(f)

failures = []
for check in contract.get("checks", []):
    cid = check.get("id", "?")
    if check.get("required") and not check.get("passes"):
        failures.append(f"required check '{cid}' has passes=false")
        continue
    if check.get("passes"):
        evidence = (check.get("evidence") or "").strip()
        if not evidence:
            failures.append(f"check '{cid}' passes without evidence")
        elif not os.path.exists(os.path.join(root, evidence)):
            failures.append(f"check '{cid}' evidence file missing: {evidence}")

task = contract.get("task_id", "?")
if failures:
    print(f"Verification contract FAILED for task {task}:")
    for failure in failures:
        print(f" - {failure}")
    sys.exit(1)
print(f"Verification contract passed for task {task}.")
PYEOF
  exit $?
fi

dir="$(dirname "$0")"
for ps in pwsh powershell.exe powershell; do
  if command -v "$ps" >/dev/null 2>&1; then
    "$ps" -NoProfile -ExecutionPolicy Bypass -File "$dir/check-contract.ps1" -ContractPath "$contract" -RepoRoot "$root"
    exit $?
  fi
done

echo "check-contract: needs python3 or PowerShell. Install one, or run check-contract.ps1 directly." >&2
exit 1
