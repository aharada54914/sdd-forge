# T-001 minItems standard CLI contrast (non-formal verification)

Date: 2026-10-05

## Scope and result

Two newly executed standard CLI controls passed. This closes the narrow absence of CLI cardinality evidence identified in the local inspection; it is not a formal independent review, quality verdict, task completion, native Windows result, or registered regression-suite addition.

The existing fixture/signing pattern was read from `specs/sdd-domain-concept-test/verification/T-001/diagnose-feature-copy.py`. A disposable fixture uses a synthetic key and registered synthetic approver, a valid NEW_CONCEPT_CANDIDATE/proceed decision, matching fixed-format Markdown and JSON, canonical content hash, and separately recomputed HMAC for each case. Both invocations use the production standard validator CLI, not provenance-only validation or a mocked validator.

The earlier denied internal import/assertion command was not retried or routed through another tool. This newly authorized check runs the standard public CLI and does not import the production validator. No production, frozen, review-state, reservation, or Git state was edited.

## Executed command

Working directory: `/Users/jrmag/.codex/worktrees/issue290-concept-phase1/sdd-forge`

```sh
rtk proxy python3 -B /private/tmp/issue290-minitems-cli.sITEmn/check.py
```

Harness SHA-256: `492cdb261968d0693b6d61138ce82a33ea1154e7b6a42db1d196e797b97a0c64`.
The harness remains at the path above; synthetic fixture files were removed by its TemporaryDirectory cleanup. It invoked `validate-approval-sidecar.py --content <fixture>/concept-test.json --sidecar <fixture>/concept-test.approval.json --approver-registry <fixture>/approver-registry.yaml` for each case, with a synthetic `SDD_CONTEXT_KEY` and bytecode writing disabled.

## Actual results

Outer process exit: 0.

```text
{"inputs_count": 1, "exit": 0, "stdout": "VALID\n", "stderr": ""}
{"inputs_count": 0, "exit": 32, "stdout": "", "stderr": "validate-approval-sidecar: CONTENT_SCHEMA_VIOLATION: /inputs: fewer than minItems 1\n"}
PASS: 2 standard CLI cardinality controls; source hashes unchanged
```

The empty-input error is the intended schema cardinality rejection, not a missing signature/key/registry/Markdown error. Schema validation occurs before HMAC verification in this rejected case; the passing one-input control establishes that the same signing method and standard route are accepted. No claim is made that the rejected invocation progressed through every later gate.

## Source pins (read before execution and rechecked afterward)

| File | SHA-256 |
|---|---|
| `plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py` | `5f1fe69df13bc90baac757aefa56e2e36c82a175b6db1000cee71592e22cbc74` |
| `plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.py` | `b357a8252a7ece91161f1eca6ec6ba434a0fa9f45a29abf77efb6f90477ee0ff` |
| `contracts/concept-test.v1.schema.json` | `e9345fb3e07a57ec695a11531cac4b61989ad5b619993b3745b5f206cf090674` |
| `contracts/approval-sidecar.schema.json` | `f205da8f1103fc2ac876e7fbff4dc6f89db4146325e65aadc15d139ffa4265e3` |

## Remaining boundary

The registered Bash/PowerShell suites still lack this explicit empty-input CLI fixture; this report supplies execution evidence, not durable test registration. Existing unchanged suites were not rerun. Bootstrap downstream zero-call assertions remain T-003 work. Current task-stage provenance repair and independent implementation verification remain separate requirements; this narrow result does not authorize their status changes.
