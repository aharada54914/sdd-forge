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

# Risk tier required-id sets (source: plugins/sdd-quality-loop/references/risk-gate-matrix.md)
RISK_TIERS = {
    "low":      {"lint", "typecheck", "build", "placeholder-scan", "task-state-check"},
    "medium":   {"lint", "typecheck", "build", "placeholder-scan", "task-state-check", "unit-tests", "acceptance-tests", "regression"},
    "high":     {"lint", "typecheck", "build", "placeholder-scan", "task-state-check", "unit-tests", "acceptance-tests", "regression", "requirement-traceability"},
    "critical": {"lint", "typecheck", "build", "placeholder-scan", "task-state-check", "unit-tests", "acceptance-tests", "regression", "requirement-traceability"},
}

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

    # Type strictness: required and passes must be JSON boolean (not string, number, null)
    required = check.get("required", False)
    if not isinstance(required, bool):
        failures.append(f"check '{cid}' has invalid type for required: {type(required).__name__} (expected bool)")
        continue

    passes = check.get("passes", False)
    if not isinstance(passes, bool):
        failures.append(f"check '{cid}' has invalid type for passes: {type(passes).__name__} (expected bool)")
        continue

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

        # Evidence must exist, be a regular file, and have size > 0
        if not os.path.exists(resolved):
            failures.append(f"check '{cid}' evidence file missing: {evidence}")
        elif not os.path.isfile(resolved):
            failures.append(f"check '{cid}' evidence is not a regular file: {evidence}")
        elif os.path.getsize(resolved) == 0:
            failures.append(f"check '{cid}' evidence file is empty: {evidence}")

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

# Pass 4: risk-tier enforcement (source: plugins/sdd-quality-loop/references/risk-gate-matrix.md)
risk = (contract.get("risk") or "").strip()
if risk:  # LEGACY mode: if risk is absent or empty string, skip this pass
    # Validate risk tier value
    if risk not in RISK_TIERS:
        failures.append(f"contract risk is invalid: {risk}")
    else:
        # Enforce tier's required-id set
        required_ids = RISK_TIERS[risk]
        present_ids_set = set(check.get("id", "?") for check in checks)

        for req_id in sorted(required_ids):
            if req_id not in present_ids_set:
                failures.append(f"risk {risk} requires check '{req_id}' present and required:true (missing)")
            else:
                # Find the check and verify required:true
                for check in checks:
                    if check.get("id") == req_id:
                        if not check.get("required", False):
                            failures.append(f"risk {risk} requires check '{req_id}' to be required:true")
                        break

task = contract.get("task_id", "?")

# Pass 5: Red→Green evidence enforcement (only when required_workflow == "tdd")
required_workflow = (contract.get("required_workflow") or "").strip()
if required_workflow == "tdd":
    # TDD test-check ids that require red_evidence and green_evidence when required=true
    tdd_test_ids = {"unit-tests", "acceptance-tests"}

    for check in checks:
        cid = check.get("id", "?")
        required = check.get("required", False)

        # Only enforce red/green for test-type checks that are required:true
        if cid in tdd_test_ids and required:
            red_evidence = (check.get("red_evidence") or "").strip()
            green_evidence = (check.get("green_evidence") or "").strip()

            # Rule 2a: must not be empty/missing
            if not red_evidence:
                failures.append(f"check '{cid}' required_workflow tdd needs non-empty red_evidence")
                continue
            if not green_evidence:
                failures.append(f"check '{cid}' required_workflow tdd needs non-empty green_evidence")
                continue

            # Rule 2b: validate red_evidence path (same as evidence in Pass 2)
            # Reject absolute POSIX paths
            if red_evidence.startswith("/"):
                failures.append(f"check '{cid}' red_evidence is an absolute path: {red_evidence}")
                continue
            # Reject Windows drive paths and UNC
            if (len(red_evidence) >= 2 and red_evidence[1] == ":") or red_evidence.startswith("\\\\"):
                failures.append(f"check '{cid}' red_evidence is an absolute path: {red_evidence}")
                continue

            # Check for traversal outside root
            abs_root = str(pathlib.Path(root).resolve())
            try:
                resolved_red = str(pathlib.Path(root).joinpath(red_evidence).resolve())
            except Exception:
                failures.append(f"check '{cid}' red_evidence path could not be resolved: {red_evidence}")
                continue
            if not resolved_red.startswith(abs_root + os.sep) and resolved_red != abs_root:
                failures.append(f"check '{cid}' red_evidence path escapes repo root: {red_evidence}")
                continue

            # File must exist, be regular file, be non-empty
            if not os.path.exists(resolved_red):
                failures.append(f"check '{cid}' red_evidence file missing: {red_evidence}")
            elif not os.path.isfile(resolved_red):
                failures.append(f"check '{cid}' red_evidence is not a regular file: {red_evidence}")
            elif os.path.getsize(resolved_red) == 0:
                failures.append(f"check '{cid}' red_evidence file is empty: {red_evidence}")

            # Rule 2b: validate green_evidence path (same as evidence in Pass 2)
            # Reject absolute POSIX paths
            if green_evidence.startswith("/"):
                failures.append(f"check '{cid}' green_evidence is an absolute path: {green_evidence}")
                continue
            # Reject Windows drive paths and UNC
            if (len(green_evidence) >= 2 and green_evidence[1] == ":") or green_evidence.startswith("\\\\"):
                failures.append(f"check '{cid}' green_evidence is an absolute path: {green_evidence}")
                continue

            # Check for traversal outside root
            try:
                resolved_green = str(pathlib.Path(root).joinpath(green_evidence).resolve())
            except Exception:
                failures.append(f"check '{cid}' green_evidence path could not be resolved: {green_evidence}")
                continue
            if not resolved_green.startswith(abs_root + os.sep) and resolved_green != abs_root:
                failures.append(f"check '{cid}' green_evidence path escapes repo root: {green_evidence}")
                continue

            # File must exist, be regular file, be non-empty
            if not os.path.exists(resolved_green):
                failures.append(f"check '{cid}' green_evidence file missing: {green_evidence}")
            elif not os.path.isfile(resolved_green):
                failures.append(f"check '{cid}' green_evidence is not a regular file: {green_evidence}")
            elif os.path.getsize(resolved_green) == 0:
                failures.append(f"check '{cid}' green_evidence file is empty: {green_evidence}")

# Pass 5b: Risk→Workflow consistency (only when BOTH risk AND required_workflow are present)
if risk and required_workflow:  # Enforce only if both fields are present and non-empty
    if risk in {"high", "critical"}:
        if required_workflow != "tdd":
            failures.append(f"risk {risk} requires required_workflow: tdd (got '{required_workflow}')")

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
