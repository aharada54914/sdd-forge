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
contract="$1"
root="${2:-.}"

if [ -z "$contract" ] || [ ! -f "$contract" ]; then
  echo "check-contract: contract file not found: $contract" >&2
  exit 1
fi

if command -v python3 >/dev/null 2>&1; then
  CONTRACT="$contract" ROOT="$root" python3 - <<'PYEOF'
import json, os, sys, pathlib

contract_path = os.environ["CONTRACT"]
root = os.environ["ROOT"]
with open(contract_path, encoding="utf-8") as f:
    contract = json.load(f)

BASELINE_IDS = {"lint", "typecheck", "unit-tests", "build", "placeholder-scan", "task-state-check"}

failures = []
seen_ids = {}
checks = contract.get("checks", [])

# Pass 1: duplicate id detection
for i, check in enumerate(checks):
    cid = check.get("id", "?")
    if cid in seen_ids:
        failures.append(f"duplicate check id '{cid}'")
    else:
        seen_ids[cid] = i

# Pass 2: per-check rules
for check in checks:
    cid = check.get("id", "?")
    required = check.get("required", False)
    passes = check.get("passes", False)
    evidence = (check.get("evidence") or "").strip()
    waiver_reason = (check.get("waiver_reason") or "").strip()

    # Waiver enforcement: required:false (or missing required) + passes:false needs waiver_reason
    if not required and not passes:
        if not waiver_reason:
            failures.append(
                f"check '{cid}' is optional and has passes=false but waiver_reason is empty; "
                f"either run the check or record why it does not apply in waiver_reason"
            )

    if required and not passes:
        failures.append(f"required check '{cid}' has passes=false")
        continue

    if passes:
        if not evidence:
            failures.append(f"check '{cid}' passes without evidence")
            continue

        # Evidence path safety
        # Reject absolute POSIX paths
        if evidence.startswith("/"):
            failures.append(f"check '{cid}' evidence is an absolute path: {evidence}")
            continue
        # Reject Windows drive paths (C:\...) and UNC (\\...)
        if (len(evidence) >= 2 and evidence[1] == ":") or evidence.startswith("\\\\"):
            failures.append(f"check '{cid}' evidence is an absolute path: {evidence}")
            continue

        # Resolve and check for traversal outside root
        abs_root = str(pathlib.Path(root).resolve())
        try:
            resolved = str(pathlib.Path(root).joinpath(evidence).resolve())
        except Exception:
            failures.append(f"check '{cid}' evidence path could not be resolved: {evidence}")
            continue
        if not resolved.startswith(abs_root + os.sep) and resolved != abs_root:
            failures.append(f"check '{cid}' evidence path escapes repo root: {evidence}")
            continue

        if not os.path.exists(resolved):
            failures.append(f"check '{cid}' evidence file missing: {evidence}")

# Pass 3: required-set protection
present_ids = set(check.get("id", "?") for check in checks)
for bid in sorted(BASELINE_IDS):
    if bid not in present_ids:
        failures.append(f"check removed from contract: '{bid}' is a required baseline check id")
        continue
    # Find the check
    for check in checks:
        if check.get("id") == bid:
            if not check.get("required", False):
                waiver_reason = (check.get("waiver_reason") or "").strip()
                if not waiver_reason:
                    failures.append(
                        f"baseline check '{bid}' is downgraded to required:false without waiver_reason; "
                        f"downgrading a baseline check requires justification recorded in the quality-gate report "
                        f"(set a non-empty waiver_reason)"
                    )
            break

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
