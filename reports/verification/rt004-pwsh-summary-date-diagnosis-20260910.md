# RT004 PowerShell summary timestamp diagnosis

Status: timestamp and diagnostic candidates applied by human; workflow history now passes 137/0. Admission remains unresolved; formal review, CI and merge incomplete. Earlier failures below are historical evidence, not current results.

## Scope and baseline

Ticket: `docs/review-tickets/RT-20260908-004.yml`.
Original validator SHA-256: `4825a5b0c893dd4bf7a6b713d73133caa826a22571d613ae72e7a367ad64baa0`.
Original test SHA-256: `2bcbb2bb7a3d8a64be64fc36011e5736185a68c1f863c57401a951c6a7265ee2`.
Environment: macOS, PowerShell 7.6.2; not native Windows evidence.

The agent ran the unchanged `tests/impl-review-adr-inputs.tests.sh --current-adr-only`: 8 passed, 6 failed, exit 1. Bash passed all seven selected cases; PowerShell passed legacy and failed all six current cases. Previous failures remain failures.

## Direct observations, without source modification

The original source is readable and its existing regression suite is executable by the agent. A protected source edit through apply_patch was rejected by the live PreToolUse hook. An earlier assertion that all test execution required human intervention was incorrect.

An observational PowerShell command breakpoint captured exception type `System.Management.Automation.RuntimeException` at original source line 1456: `ADR summary identity invalid`. A subsequent observational line breakpoint at line 1451 on the original validator, using the suite's synthetic current-singleton data, captured:

```text
ADR_SUMMARY_TYPES schema=System.String;attempt=System.Int64;round=System.Int64;generated_at=System.DateTime
workflow-state: workflow-state-integrity: stage-provenance: impl review evidence is malformed
```

Neither breakpoint changed variables, validators, test expectations, output verdicts or persisted review evidence. Synthetic fixture directories were removed by the existing suite cleanup.

A separate primitive JSON conversion on PowerShell 7.6.2 showed that `{"generated_at":"2026-09-09T00:00:00Z"}` yields `System.DateTime` by default, and `System.String` with `-DateKind String`. Microsoft documents DateKind as added in 7.5: <https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/convertfrom-json?view=powershell-7.5>.

## Minimal candidate and review

Candidate DATA: `reports/verification/rt004-pwsh-summary-date-candidate-20260910.patch`.
SHA-256: `c2cae53ff768c2ca9e98e89d80e5503877e0be6a3e1311d817afdf0d4a10d0ce`.
`git apply --check` succeeded against the source hash above. This is applicability, not runtime validation.

Only the generated_at predicate changes: recognize a nonempty string or the CLR DateTime/DateTimeOffset produced from a JSON string by this deserialization path. No casts, date formatting, relaxed numeric checks, changed raw snapshots or hash rebinding are introduced. The raw JSON contract still rejects null, empty strings, numbers, booleans, objects and arrays. Do not reuse this predicate as validation of arbitrary caller-created PowerShell objects.

The independent static reviewer `/root/rt004_snapshot_static_review` recommended this narrow approach over a mandatory PowerShell 7.5 parameter or parser rewrite, then reviewed the exact patch hash above and reported no new Critical/Major findings. It confirmed that schema, attempt, round and existing rejection behavior remain unchanged. This was static review, not application or runtime verification, and is not formal gate PASS.

## Verification still required

### Post-application observations (2026-09-10)

Human application backup: `/tmp/sdd-rt004-date.WRVmfI`.
The agent independently measured the applied validator SHA-256 as
`783c207407b807d15253c67f594c45ecb3b558ddfb2928f0abe3335ebc7cfd6a`.
Original PowerShell parser reported zero syntax errors; scoped git whitespace check exited 0.

Executed original suites on macOS PowerShell 7.6.2, without copying or modifying protected executables:

- `bash tests/impl-review-adr-inputs.tests.sh --current-adr-only`: 14 passed, 0 failed, exit 0 (previous baseline 8/6 remains recorded above).
- `bash tests/review-context-boundary.tests.sh`: exit 0, including Bash/PowerShell boundary checks and 31 citation anchors.
- `bash tests/impl-review-round2-contract.tests.sh`: exit 0, four assertions passed.
- `bash tests/impl-review-adr-inputs.tests.sh --workflow-only`: 85 passed, 52 failed, exit 1. PowerShell negative cases report exit 1 as expected but the generic evidence catch lacks the ADR diagnostic required by the unchanged regression. This is not overall PASS.

An observational breakpoint on the original validator for the suite's `null-set` fixture reported `System.Management.Automation.RuntimeException` at line 1094. The source there explicitly rejects non-array entries with `ADR entries must be an array`. The outer catch at line 1819 replaces that diagnostic with `impl review evidence is malformed`. No exception message, evidence content, variable, outcome or stored review record was altered by the breakpoint. The original suite cleaned up its temporary fixtures.

Diagnostic hypotheses: (1) expected invalid-input rejection loses its validation-boundary classification in the outer catch (confirmed for null-set); (2) remaining failures include an unexpected runtime exception (not ruled out individually merely by exit 1); (3) regression expects a stale category (the ADR boundary is still the actual impl reader, so retain the test expectation). Successful controls are required alongside negative cases to avoid masking a broken reader.

An unapplied, fixed-string-only diagnostic candidate is `rt004-pwsh-history-diagnostic-candidate-20260910.patch`, SHA-256 `ff1521b564442bead8e0d9b0a74553faa17e5019bdd79bb71ab5dc5f5078b520`. It labels only the impl reader catch as an ADR validation failure, preserves rejection and other-stage diagnostics, and does not expose exception text or evidence. `git apply --check` succeeded. Independent reviewer `/root/rt004_snapshot_static_review` verified both hashes and reported no new Critical/Major findings for this narrow diff; Stop-WorkflowState still throws or exits and other stages are unchanged. The reviewer explicitly cautioned that a boundary catch also classifies unexpected runtime exceptions: green diagnostics alone do not prove all 52 individual rejection causes. No test expectations are changed. Static review and patch applicability are not execution evidence or formal gate PASS.

After authorized human application, the agent can run the original current-ADR and workflow-history suites and check syntax, whitespace and hash stability. Extend regression coverage for timestamp with offset, arbitrary nonempty text and whitespace; reject empty/null/numeric/boolean/object/array/missing/mis-cased/duplicate generated_at in both current and previous summary routes, rebinding fixture summary manifests so rejection is not attributable to stale hashes. Preserve all existing tests. Distinguish actual runtime coverage for PS5.1, PS7.0–7.4 and PS7.5+; unexecuted runtimes are not passes.

The previous exception-location candidate and its human instructions are superseded for diagnosis: the required observations were obtained without applying them. Do not apply that obsolete diagnostic patch merely to reproduce these observations.

No commit, push, merge, issue closure, ticket resolution or review verdict change occurred.

## Diagnostic application and agent verification (2026-09-10)

Human backup: `/tmp/sdd-rt004-diagnostic.1r71bx`. Independently measured source
SHA-256: `291ee7531594757d6ebc04c144bb8b35938f7715ae76665c9bdf723df09b1ff5`.
The unchanged ADR test digest remains `2bcbb2bb7a3d8a64be64fc36011e5736185a68c1f863c57401a951c6a7265ee2`.

- `rtk proxy bash tests/impl-review-adr-inputs.tests.sh --workflow-only`: **137 passed, 0 failed, exit 0**, including Bash/PowerShell positive and negative controls. Session 36040 completed normally.
- `rtk proxy bash tests/review-context-boundary.tests.sh`: exit 0, including 31 citation anchors and both runtimes' boundary checks.
- `rtk proxy bash tests/impl-review-round2-contract.tests.sh`: four assertions passed, exit 0.
- `rtk proxy git diff --check`: exit 0 before this evidence update.

The full ADR driver `rtk proxy bash tests/impl-review-adr-inputs.tests.sh`
(session 87962) completed with **249 passed, 64 failed, exit 1**. Its aggregate
includes the 137 successful workflow cases; the admission subset is 112/64,
matching the recorded prior admission baseline counts. The Bash original's `path_is_authorized` impl branch
(`validate-review-context-set.sh:146`) still has no ADR allowlist branch;
the valid `bound` fixture is rejected as role-unlisted. Conversely, missing and
malformed extension fixtures are admitted and reserve synthetic fixture ledger
entries. The prior admission baseline and unapplied candidate are documented in
`rt004-admission-legacy-boundaries-20260909.md`; this is not a new regression
introduced by the fixed diagnostic catch. Neither these synthetic admissions
nor workflow-only success authorizes a real formal review or merge.

Remaining diagnostic hypotheses are candidate not yet integrated (supported by
the original allowlist), fixture-contract drift (must compare candidate and
fixture before application), and runtime-specific parsing (cannot explain the
shared Bash/PowerShell role-unlisted positive failure on its own). No new
implementation attempt or test weakening was made during this verification.
