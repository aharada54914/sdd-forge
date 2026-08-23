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
import hashlib
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
    "high":     {"lint", "typecheck", "build", "placeholder-scan", "task-state-check", "unit-tests", "acceptance-tests", "regression", "requirement-traceability", "check-component-coverage"},
    "critical": {"lint", "typecheck", "build", "placeholder-scan", "task-state-check", "unit-tests", "acceptance-tests", "regression", "requirement-traceability", "check-component-coverage"},
}

# Stack descriptor: compile-oriented checks are toolchain-dependent on non-code stacks.
COMPILE_CHECKS = {"lint", "typecheck", "build"}
KNOWN_STACKS = {"code", "shell", "docs", "spec"}
NONCODE_STACKS = {"shell", "docs", "spec"}

TDD_TEST_IDS = {"unit-tests", "acceptance-tests"}

# epic-191-a3-path-ownership T-004 (REQ-004, AC-055, INV-017/INV-018): the
# check-component-coverage evidence producer-digest is independently
# recomputed over this literal sibling file, never trusted from the
# evidence record itself.
PRODUCER_DIGEST_CHECK_ID = "check-component-coverage"
PRODUCER_DIGEST_SCRIPT_NAME = "check-component-coverage.py"

# epic-191-a3-path-ownership T-004 follow-up (REQ-004, INV-018): tier-minimum
# ids that are only required once the project has declared a capability-
# enforcement posture at all.
#
# check-component-coverage derives one of three states from
# `workflow.capability_enforcement` in sdd/project-context.yaml (ADR-0016 §4).
# In `disabled-legacy` -- which derive_state() returns when that file is
# ABSENT -- the gate evaluates zero Fail conditions, consults no Facet
# Manifest, and exits 0 unconditionally: it is structurally incapable of
# asserting anything. Requiring it in the tier minimum while it is inert
# demands a `passes:true` entry for a check that can never say anything but
# "not-applicable", which is exactly the fabricated-pass footgun
# requirements.md warns about. So the REQUIREMENT is gated on the same
# project state the GATE itself reads, and activates precisely when the gate
# becomes capable of asserting something.
#
# The predicate is file PRESENCE, not a re-derivation of the three-way state,
# and that is deliberate:
#   * contracts/project-context.schema.json makes `capability_enforcement`
#     REQUIRED with enum ["advisory","required"], so every schema-conformant
#     config yields advisory|required -- never disabled-legacy. Presence is
#     therefore EXACTLY equivalent to `derive_state() != "disabled-legacy"`
#     for any conformant config.
#   * The only divergence is a malformed/non-conformant config, where this
#     predicate still REQUIRES the check (fail-closed). derive_state() either
#     hard-errors (present-but-unparseable) or returns disabled-legacy
#     (parses but lacks the field); over-requiring in those cases is the safe
#     direction.
#   * It duplicates no YAML parsing into this file. A re-derivation would
#     need a parser in BOTH runtimes, and a parser that threw and was caught
#     would silently conclude "disabled-legacy" -- turning the tier minimum
#     OFF permanently and undetectably. This predicate has no such failure
#     mode: the only way it reads "inactive" is the file genuinely not
#     existing, which is the intended inactive condition.
PROJECT_CONTEXT_REL_PATH = os.path.join("sdd", "project-context.yaml")
CAPABILITY_STATE_GATED_IDS = {"check-component-coverage"}


def _capability_enforcement_declared(root):
    """True iff this project declares a capability-enforcement posture,
    i.e. sdd/project-context.yaml exists relative to the repo root.

    Mirrors the file-absence branch of check-component-coverage.py's
    derive_state(); see CAPABILITY_STATE_GATED_IDS for why presence (rather
    than a re-derived three-way state) is the predicate.
    """
    return os.path.isfile(os.path.join(root, PROJECT_CONTEXT_REL_PATH))


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


def _pass4_risk_tier(checks, contract, root, failures):
    """Risk-tier enforcement: required-id superset per tier.

    Ids in CAPABILITY_STATE_GATED_IDS are dropped from the tier minimum while
    the project has declared no capability-enforcement posture, so the
    requirement activates exactly when the corresponding gate stops being
    inert. See CAPABILITY_STATE_GATED_IDS for the full rationale.
    """
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

    # RT-20260821-005(c) / AC-005 contract side: under verification-contract/v2
    # a high/critical contract must carry a well-formed spec_revision (a 40-hex
    # git commit or 64-hex corpus digest - both live conventions, measured
    # 7:119 across shipped contracts). v1/absent-schema contracts are exempt:
    # ~40 shipped high/critical contracts predate the field and backfilling a
    # historical corpus hash would fabricate provenance.
    if (contract.get("schema") or "").strip() == "verification-contract/v2" and risk in {"high", "critical"}:
        spec_revision = (contract.get("spec_revision") or "").strip()
        if not (len(spec_revision) in (40, 64)
                and all(ch in "0123456789abcdef" for ch in spec_revision)):
            failures.append(
                f"risk {risk} requires a well-formed spec_revision "
                f"(40- or 64-hex lowercase) under verification-contract/v2")

    required_ids = RISK_TIERS[risk]
    if not _capability_enforcement_declared(root):
        required_ids = required_ids - CAPABILITY_STATE_GATED_IDS
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
    """Risk→Workflow consistency: high/critical requires required_workflow: tdd.

    RT-20260821-003: an absent, empty, or whitespace required_workflow used to
    disable BOTH this pass and Pass 5, so one omitted field silently dropped
    the entire Red→Green obligation at high/critical tier. The field is now
    mandatory whenever the risk tier demands a workflow.
    """
    risk = (contract.get("risk") or "").strip()
    required_workflow = (contract.get("required_workflow") or "").strip()
    if risk in {"high", "critical"}:
        if not required_workflow:
            failures.append(
                f"risk {risk} requires required_workflow: tdd (field missing or empty)")
        elif required_workflow != "tdd":
            failures.append(
                f"risk {risk} requires required_workflow: tdd (got '{required_workflow}')")


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


def _pass7_producer_digest(checks, root, failures):
    """Producer-digest verification (epic-191-a3-path-ownership T-004; REQ-004,
    AC-055, INV-017/INV-018): a passing check-component-coverage evidence
    entry must carry a producer.sha256 field equal to the sha256 this pass
    independently (re-)computes over the live, on-disk
    check-component-coverage.py at verification time — never trusted from
    the evidence record itself. A mismatch, or a missing/unreadable
    evidence file, or a missing producer/producer.sha256 field, fails the
    contract. Scoped to check-component-coverage only; every other check id
    is untouched by this pass."""
    for check in checks:
        if check.get("id") != PRODUCER_DIGEST_CHECK_ID:
            continue
        if not check.get("passes", False):
            continue  # a non-passing check is already handled by Pass 2/3/4

        evidence = _str_field(check, "evidence")
        if not evidence:
            continue  # already flagged by Pass 2 ("passes without evidence")

        evidence_path = os.path.normpath(os.path.join(root, evidence))
        try:
            with open(evidence_path, "r", encoding="utf-8") as fh:
                record = json.load(fh)
        except (OSError, json.JSONDecodeError) as exc:
            failures.append(
                f"check '{PRODUCER_DIGEST_CHECK_ID}' evidence could not be read/parsed "
                f"for producer-digest verification: {exc}"
            )
            continue

        producer = record.get("producer") if isinstance(record, dict) else None
        recorded_sha256 = producer.get("sha256") if isinstance(producer, dict) else None
        if not recorded_sha256:
            failures.append(f"check '{PRODUCER_DIGEST_CHECK_ID}' evidence is missing producer.sha256")
            continue

        script_dir = os.path.dirname(os.path.abspath(__file__))
        producer_script = os.path.join(script_dir, PRODUCER_DIGEST_SCRIPT_NAME)
        try:
            with open(producer_script, "rb") as fh:
                live_sha256 = hashlib.sha256(fh.read()).hexdigest()
        except OSError as exc:
            failures.append(
                f"check '{PRODUCER_DIGEST_CHECK_ID}' producer-digest verification could not "
                f"read the live script {PRODUCER_DIGEST_SCRIPT_NAME}: {exc}"
            )
            continue

        if recorded_sha256 != live_sha256:
            failures.append(
                f"check '{PRODUCER_DIGEST_CHECK_ID}' evidence producer.sha256 ({recorded_sha256}) "
                f"does not match the live on-disk {PRODUCER_DIGEST_SCRIPT_NAME} ({live_sha256})"
            )


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

    # RT-20260821-007: non-string scalar fields previously crashed the pass
    # chain with an uncaught traceback (exit code was correct, the diagnostic
    # was not). Fail closed with a proper message and skip the passes.
    non_string = [
        name for name in ("risk", "stack", "required_workflow", "spec_revision", "cross_model")
        if contract.get(name) is not None and not isinstance(contract.get(name), str)
    ]
    if non_string:
        for name in non_string:
            failures.append(f"contract {name} must be a string")
        return contract.get("task_id", "?"), failures

    # RT-20260821-005(c): contract schema versioning. Absent schema = v1
    # (legacy, 194 shipped contracts) - current behavior unchanged. A declared
    # schema must be a recognized version; anything else fails closed.
    contract_schema = (contract.get("schema") or "").strip()
    if contract_schema and contract_schema != "verification-contract/v2":
        failures.append(f"contract schema is unrecognized: {contract_schema}")
        return contract.get("task_id", "?"), failures

    non_dict_indices = [i for i, c in enumerate(checks_raw) if not isinstance(c, dict)]
    if non_dict_indices:
        failures.append(f"contract 'checks' has non-dict elements at indices: {non_dict_indices}")
    checks = [c for c in checks_raw if isinstance(c, dict)]

    _pass1_duplicate_ids(checks, failures)
    _pass2_per_check_rules(checks, root, failures)
    _pass3_required_set(checks, failures)
    _pass4_risk_tier(checks, contract, root, failures)
    _pass5_tdd_evidence(checks, contract, root, failures)
    _pass5b_risk_workflow(contract, failures)
    _pass6_cross_model(checks, contract, failures)
    _pass7_producer_digest(checks, root, failures)

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
