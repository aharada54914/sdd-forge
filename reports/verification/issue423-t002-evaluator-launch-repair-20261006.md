# Issue #423 T-002 evaluator launch repair

## 2026-10-07 bounded delivery repair preflight

Owner and HEAD remain as recorded below (HEAD re-read before this edit); existing dirty changes are preserved. High-risk scope: the two independent-review findings concerning caller-pinned manifest bytes and caller-prepared read-only dependency fixtures. No reservation, task state, approval, frozen evidence or Git history is changed. Required validation is executable normal/negative delivery checks, the existing isolation suite and independent diff review. This is not a formal evaluator verdict.

Evidence-field preflight: the externally supplied manifest SHA corresponds to the exact bytes parsed by the delivery checker (mismatched and malformed-byte tests); every admitted path/SHA corresponds to its repository file and, when used, its caller-prepared scratch copy (missing, changed, symlink and path-escape tests). Delivery success is not an identity receipt or authorization expansion. Existing reservation and identity validation remain mandatory, and no test may touch the canonical ledger.

Owner: `issue423-approved-recovery/sdd-forge`, branch `codex/issue423-boundary-checkpoint`, pre-edit HEAD `3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9`. The checkout was dirty; unrelated changes and seq1198–1200 reservations are preserved. T-002 was Approved / Implementation Complete.

Risk: high, because the launched evaluator's admitted-input and identity boundary is affected. The affected contract is the quality-gate launch instruction and shipped Codex evaluator role. Validation required: inspect the receipt-only reference and both role instructions; check a negative launcher/role regression, run focused existing isolation checks, obtain independent diff review, and use a fresh identity only after coordination with the ledger owner. No raw session log or environment dump was opened for this diagnosis.

Observed cause: the Codex TOML evaluator role allowed generic repository reads and did not state the manifest/receipt-only boundary already required by the Claude evaluator role and `review-context-boundary.md`. The quality-gate caller also lacked an explicit instruction to pass the complete reservation receipt to that shipped role. Seq1200 has a persisted invocation and `REVIEW_CONTEXT_OK` receipt; it is consumed history, not a verdict.

Local validation: `tests/review-agent-isolation.tests.sh` passed 26/0, including the new Codex-role and caller handoff assertions. `tests/review-context-boundary.tests.sh` passed 84/0. Python `tomllib` parsed the shipped TOML; `git diff --check` passed. These checks validate source contracts and validator behavior, not a fresh native evaluator child or a quality-gate verdict.

Readback SHA-256 after the edit: `.codex/agents/sdd-evaluator.toml` `c2c387a492ea8f35a4933dbb3890021675a8c9ea0bea2595bf551c025e69445c`; `plugins/sdd-quality-loop/skills/quality-gate/SKILL.md` `59e605eba50933ff8db58d3c698641da6afb31442d1f64fbc30826624de507e0`; `tests/review-agent-isolation.tests.sh` `16f4d2c1836d8a831d304766880243ab273818d109646ac0fa75c85d7fe9ff26`. The latter two files had pre-existing dirty edits, which remain in place.

Readback limitation: no separate pre-edit backup was created. The TOML's prior bytes remain available at the recorded Git HEAD; the two already-dirty files were not reset, and their unrelated pre-existing hunks were not changed by this repair.

Pending: independent diff review and, only after ledger-owner coordination, a fresh manifest-bound evaluator launch with a new identity. No new reservation or verdict was made here. Current-head CI, quality-gate completion, and T-002 Done remain unverified.

## 2026-10-07 delivery-path regression results

The shipped Codex role now requires the separately caller-pinned manifest digest before parsing. The quality-gate caller prepares and reads back admitted dependency copies before calling `check-evaluator-delivery.py --reserve`. That helper performs the canonical validator's read-only preflight first, verifies optional scratch copies, and only then delegates the existing canonical reservation. It does not replace path authorization or identity validation.

Executed `bash tests/review-agent-isolation.tests.sh`: exit 0. The new checks used the real canonical validator in a disposable repository, not a validator stub: valid delivery succeeded; incorrect caller pin, changed fixture, missing fixture and source hash drift failed. A missing fixture with `--reserve` left the fixture ledger unchanged; valid prepared delivery then added exactly one fixture reservation. The existing Bash/PowerShell scratch-history checks completed with `PASS: 26; FAIL: 0`. Python AST parsing, Codex TOML parsing and `git diff --check` also succeeded.

All reservation tests above used disposable fixture ledgers. Canonical sequence 1200 was not reused, and no formal reservation, verdict, task status or Git operation was performed. Native evaluator delivery, independent diff review, CI and quality-gate completion remain pending; local delivery tests do not prove those outcomes. The earlier readback digests above describe the prior edit, not this new candidate.

## 2026-10-07 launch-helper namespace repair preflight

Scope: rename the launch helper to `preflight-evaluator-delivery.py` and update its two live callers, without changing its behavior. Owner and HEAD remain those recorded above; 177 existing dirty status entries were observed and are retained. Risk remains high because this is a caller on the existing evaluator launch boundary. No registry rule, approval, identity, frozen evidence or task state will change.

RED: both `bash tests/validate-capability-registry.tests.sh` and `pwsh -NoProfile -File tests/validate-capability-registry.tests.ps1` returned exit 1 with 26 passed / 1 failed. The sole failure was `unregistered-script: plugins/sdd-quality-loop/scripts/check-evaluator-delivery.py`. The canonical validator (`validate-capability-registry.py`, `check_c_unregistered_script`) reserves direct `check-*.py` names for registered gates. This helper delegates the existing canonical validator and is not a new gate.

Required validation: both registry suites, the executable delivery regression in `tests/review-agent-isolation.tests.sh`, syntax and whitespace checks, followed by independent diff review. Historical references above and in the earlier launch-preparation report retain their original filename; current instructions use `preflight-evaluator-delivery.py`. This is a filename migration, not a replacement of historical proof.

Executed after the rename: `bash tests/validate-capability-registry.tests.sh` and `pwsh -NoProfile -File tests/validate-capability-registry.tests.ps1` each exited 0 with 27 passed / 0 failed. `bash tests/review-agent-isolation.tests.sh` exited 0: the real canonical-validator delivery cases accepted prepared inputs, rejected stale pins, missing/substituted fixtures and source drift without consuming a reservation, and delegated exactly one reservation in a disposable fixture only. Its mandatory Bash/PowerShell scratch-history suite reported `PASS: 26; FAIL: 0`. Python AST parsing and `git diff --check` passed. No canonical reservation, native child launch, status change or Git mutation was performed. Independent diff review and native permission-boundary proof remain separate and pending.
