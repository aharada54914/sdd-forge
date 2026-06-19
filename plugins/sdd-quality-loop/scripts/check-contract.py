#!/usr/bin/env python3
"""R-04: Standalone check-contract logic (extracted from check-contract.sh heredoc).

Usage (via check-contract.sh dispatcher):
    CONTRACT=<path> ROOT=<repo-root> python3 check-contract.py

Or directly:
    python3 check-contract.py <contract-path> [repo-root]

Exit 0: contract passed. Exit 1: contract failed or not found.

This module must NOT import from outside the standard library so it runs in
any Python 3.6+ environment without additional packages.

R-01: Path validation is delegated to validate_path.validate_evidence_path()
imported via __file__-relative sys.path. If validate-path.py is missing,
this script exits 1 (fail-closed) rather than skipping validation.
"""
import json
import os
import sys

# R-01: __file__-relative import so the module is found regardless of cwd.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
try:
    from validate_path import validate_evidence_path
except ImportError as exc:
    print(f"check-contract: cannot import validate-path.py: {exc}", file=sys.stderr)
    print("check-contract: validate-path.py must be present alongside check-contract.py", file=sys.stderr)
    sys.exit(1)


# Hardcoded constants — never externalized to a runtime file (no tamper surface).
# Source: plugins/sdd-quality-loop/references/risk-gate-matrix.md
BASELINE_IDS = {"lint", "typecheck", "unit-tests", "build", "placeholder-scan", "task-state-check"}

RISK_TIERS = {
    "low":      {"lint", "typecheck", "build", "placeholder-scan", "task-state-check"},
    "medium":   {"lint", "typecheck", "build", "placeholder-scan", "task-state-check", "unit-tests", "acceptance-tests", "regression"},
    "high":     {"lint", "typecheck", "build", "placeholder-scan", "task-state-check", "unit-tests", "acceptance-tests", "regression", "requirement-traceability"},
    "critical": {"lint", "typecheck", "build", "placeholder-scan", "task-state-check", "unit-tests", "acceptance-tests", "regression", "requirement-traceability"},
}

# Stack descriptor: compile-oriented checks are toolchain-dependent on non-code stacks.
COMPILE_CHECKS = {"lint", "typecheck", "build"}
KNOWN_STACKS = {"code", "shell", "docs", "spec"}
NONCODE_STACKS = {"shell", "docs", "spec"}

TDD_TEST_IDS = {"unit-tests", "acceptance-tests"}


def _str_field(check, key):
    """Safely extract a string field from a check dict; returns '' for non-string values."""
    val = check.get(key)
    if not isinstance(val, str):
        return ""
    return val.strip()


def _pass1_duplicate_ids(checks, failures):
    """Detect duplicate check ids."""
    seen_ids = {}
    for i, check in enumerate(checks):
        cid = check.get("id", "?")
        if cid in seen_ids:
            failures.append(f"duplicate check id '{cid}'")
        else:
            seen_ids[cid] = i


def _pass2_per_check_rules(checks, root, failures):
    """Per-check type strictness, waiver enforcement, evidence path safety."""
    for check in checks:
        cid = check.get("id", "?")

        required = check.get("required", False)
        if not isinstance(required, bool):
            failures.append(f"check '{cid}' has invalid type for required: {type(required).__name__} (expected bool)")
            continue

        passes = check.get("passes", False)
        if not isinstance(passes, bool):
            failures.append(f"check '{cid}' has invalid type for passes: {type(passes).__name__} (expected bool)")
            continue

        evidence = _str_field(check, "evidence")
        waiver_reason = _str_field(check, "waiver_reason")

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
            validate_evidence_path(f"check '{cid}' evidence", evidence, root, failures)


def _pass3_required_set(checks, failures):
    """Required-set protection: baseline ids must be present and non-downgraded."""
    present_ids = {check.get("id", "?") for check in checks}
    for bid in sorted(BASELINE_IDS):
        if bid not in present_ids:
            failures.append(f"check removed from contract: '{bid}' is a required baseline check id")
            continue
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


def _pass4_risk_tier(checks, contract, failures):
    """Risk-tier enforcement: required-id superset per tier."""
    risk = (contract.get("risk") or "").strip()
    stack = (contract.get("stack") or "code").strip()
    if not risk:
        return  # Legacy mode: no risk field → skip

    if stack not in KNOWN_STACKS:
        failures.append(f"contract stack is invalid: {stack}")
        stack = "code"

    if risk not in RISK_TIERS:
        failures.append(f"contract risk is invalid: {risk}")
        return

    required_ids = RISK_TIERS[risk]
    present_ids_set = {check.get("id", "?") for check in checks}
    compile_waivable = stack in NONCODE_STACKS

    for req_id in sorted(required_ids):
        if req_id not in present_ids_set:
            failures.append(f"risk {risk} requires check '{req_id}' present and required:true (missing)")
        else:
            for check in checks:
                if check.get("id") == req_id:
                    if not check.get("required", False):
                        if compile_waivable and req_id in COMPILE_CHECKS:
                            pass  # non-code stack: compile checks waivable
                        else:
                            failures.append(f"risk {risk} requires check '{req_id}' to be required:true")
                    break


def _pass5_tdd_evidence(checks, contract, root, failures):
    """Red→Green evidence enforcement for required_workflow == 'tdd'."""
    required_workflow = (contract.get("required_workflow") or "").strip()
    if required_workflow != "tdd":
        return

    for check in checks:
        cid = check.get("id", "?")
        required = check.get("required", False)
        if cid not in TDD_TEST_IDS or not required:
            continue

        red_evidence = (check.get("red_evidence") or "").strip()
        green_evidence = (check.get("green_evidence") or "").strip()

        if not red_evidence:
            failures.append(f"check '{cid}' required_workflow tdd needs non-empty red_evidence")
            continue
        if not green_evidence:
            failures.append(f"check '{cid}' required_workflow tdd needs non-empty green_evidence")
            continue

        validate_evidence_path(f"check '{cid}' red_evidence", red_evidence, root, failures)
        validate_evidence_path(f"check '{cid}' green_evidence", green_evidence, root, failures)


def _pass5b_risk_workflow(contract, failures):
    """Risk→Workflow consistency: high/critical requires required_workflow: tdd."""
    risk = (contract.get("risk") or "").strip()
    required_workflow = (contract.get("required_workflow") or "").strip()
    if risk and required_workflow:
        if risk in {"high", "critical"} and required_workflow != "tdd":
            failures.append(f"risk {risk} requires required_workflow: tdd (got '{required_workflow}')")


def _pass6_cross_model(checks, contract, failures):
    """Cross-model verification descriptor enforcement."""
    cross_model = (contract.get("cross_model") or "").strip()
    if not cross_model or cross_model == "legacy":
        return

    if cross_model not in {"required", "waived"}:
        failures.append(f"contract cross_model is invalid: {cross_model}")
        return

    cm_check = next((c for c in checks if c.get("id") == "cross-model-verification"), None)
    if cross_model == "required":
        if cm_check is None:
            failures.append("cross_model:required needs a 'cross-model-verification' check present and required:true with evidence")
        elif not cm_check.get("required", False):
            failures.append("cross_model:required needs 'cross-model-verification' to be required:true")
    elif cross_model == "waived":
        if cm_check is None:
            failures.append("cross_model:waived needs a 'cross-model-verification' check present with a non-empty waiver_reason")
        elif not (cm_check.get("waiver_reason") or "").strip():
            failures.append("cross_model:waived needs a non-empty waiver_reason on 'cross-model-verification'")


def run(contract_path, root):
    """Run all passes against the contract file. Returns (task_id, failures)."""
    try:
        with open(contract_path, encoding="utf-8") as f:
            contract = json.load(f)
    except FileNotFoundError:
        return "?", [f"contract file not found: {contract_path}"]
    except json.JSONDecodeError as exc:
        return "?", [f"contract JSON parse error: {exc}"]

    checks_raw = contract.get("checks", [])
    failures = []

    if not isinstance(checks_raw, list):
        failures.append(f"contract 'checks' is not a list (got {type(checks_raw).__name__})")
        return contract.get("task_id", "?"), failures

    non_dict_indices = [i for i, c in enumerate(checks_raw) if not isinstance(c, dict)]
    if non_dict_indices:
        failures.append(f"contract 'checks' has non-dict elements at indices: {non_dict_indices}")
    checks = [c for c in checks_raw if isinstance(c, dict)]

    _pass1_duplicate_ids(checks, failures)
    _pass2_per_check_rules(checks, root, failures)
    _pass3_required_set(checks, failures)
    _pass4_risk_tier(checks, contract, failures)
    _pass5_tdd_evidence(checks, contract, root, failures)
    _pass5b_risk_workflow(contract, failures)
    _pass6_cross_model(checks, contract, failures)

    return contract.get("task_id", "?"), failures


def main():
    """CLI entry point: run contract validation, print summary, exit 0/1."""
    # Accept args either from env (when called from .sh dispatcher) or CLI.
    contract_path = os.environ.get("CONTRACT") or (sys.argv[1] if len(sys.argv) > 1 else None)
    root = os.environ.get("ROOT") or (sys.argv[2] if len(sys.argv) > 2 else ".")

    if not contract_path:
        print("check-contract: usage: check-contract.py <contract-path> [repo-root]", file=sys.stderr)
        sys.exit(1)

    task, failures = run(contract_path, root)
    if failures:
        print(f"Verification contract FAILED for task {task}:")
        for f in failures:
            print(f" - {f}")
        sys.exit(1)
    print(f"Verification contract passed for task {task}.")


if __name__ == "__main__":
    main()
