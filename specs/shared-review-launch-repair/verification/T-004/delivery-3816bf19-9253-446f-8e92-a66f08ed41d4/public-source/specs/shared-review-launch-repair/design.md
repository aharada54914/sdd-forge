# Design: shared-review-launch-repair

Impl-Review-Status: Passed

## Bounded approach

Integrate the existing shared non-TTY launcher, pre-reservation validator, conditional-input resolver, protection inventory, CI registration, WFI-030 traceability normalization, and shared PowerShell review-hash helper. The actual candidate scope is recorded in `reports/verification/shared-review-launch-integration.md:3-8`; the wrapper's check/admit/probe order is visible in `plugins/sdd-review-loop/scripts/launch-impl-review.py:143-230,321-365`. Do not create a second reservation path, infer a verdict from transport, or change the existing `review-context-invocation/v2` contract.

The caller assembles a complete ordered stage/role manifest, validates canonical paths and raw bytes, checks native permissions, then reserves once and launches only the reserved identity. Negative admission and permission cases stop with no ledger append. Existing stage precheck and role isolation remain required (`plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md:22-110`). Real callers reuse the shared construction; diagnostics may test effective permissions but never stand in for a reviewer verdict.

CI executes existing focused suites through run-all and the workflow (`tests/run-all.sh:70-76`, `tests/run-all.ps1:135`, `.github/workflows/test.yml:39-42`). The six entrypoint protection additions remain canonical/generated together (`plugins/sdd-quality-loop/references/guard-invariants.json:56-62`, `plugins/sdd-quality-loop/scripts/generate-guard-invariants.py:130-136`). WFI-030 and PowerShell hash behavior are bounded to the existing normalization semantics (`AGENTS.md:58-62`, `plugins/sdd-review-loop/scripts/review-hash-normalization.ps1:1-15`). Re-verify these shared-state references at gate time and final-head CI.

## Acceptance mapping

| Acceptance criterion | Design responsibility | Verification |
|---|---|---|
| AC-001 | Shared CLI argument construction and native model/permission diagnostics | TEST-001, TEST-002, TEST-003a–c |
| AC-002 | Ordered input admission, conditional resolution, raw invocation pin and single reservation | TEST-004, TEST-005a–h |
| AC-003 | Existing run-all entrypoints and permanent CI registration | TEST-006a–b |
| AC-004 | Existing WFI-030 traceability normalization; no other cell or body exemption | TEST-007, TEST-008a–d |
| AC-005 | Shared PowerShell digest recipe with caller-specific validation retained | TEST-009, TEST-010a–b |
| AC-006 | Six entrypoints protected through canonical inventory and generated projections | TEST-011a–f, TEST-012a–d, TEST-013 |

## Risk and persisted-evidence preflight

This high-risk repair is not accepted on prose alone. Before any further implementation, persist the following field/counterpart/mismatch checks in the non-frozen implementation record and confirm the named negative test fails on disagreement. Existing tests are candidate implementations; review must check they actually exercise the mismatches.

| Persisted field or claim | Counterpart | Failing mismatch test |
|---|---|---|
| Invocation raw SHA-256 and ordered input paths/hashes | Caller pin, canonical validator, conditional resolver | TEST-005a–f: changed pin, missing/alias/symlink/outside input, unchanged fixture ledger |
| Reserved run/session and receipt | Canonical ledger chain and native child identity | TEST-005g/h: pre-append rejection leaves ledger unchanged; post-append mismatch stops launch and retains consumed record |
| Model, exact permissions, native proof | Role contract and constructed CLI argv | TEST-002/003a–c: missing flag, wrong model, compound command, outside Read |
| Task-stage traceability normalized digest | WFI-030 rule and persisted-state checker | TEST-008a–d: unknown/annotated status, Evidence/body edit |
| PowerShell reviewed hash | Pre-refactor PowerShell recipe; unchanged caller state checks | TEST-009/010a/b: LF/CRLF, malformed/mis-cased/empty content and read-failure equivalence |
| Protected membership and CI-registration claim | Canonical inventory, generated projections, workflow | TEST-012a–c/013: inventory/projection/registration omission |

## Validation and deployment

Reproduce negative behavior, run focused parity and invariant suites, perform independent diff review, then exact-final-HEAD hosted CI including native Windows where required. Formal spec, implementation-policy, task and quality reviews are separate gates; only their validated outputs may update status. No report or old evidence is overwritten. Protected application remains subject to the existing sanctioned path; no retry through a different executor after refusal. Deployment, install, and baseline promotion are outside this repair.
