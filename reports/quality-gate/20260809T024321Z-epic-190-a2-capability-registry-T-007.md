Task: Author the cross-script parity and installed-layout invocation harness
Task ID: T-007
Feature: epic-190-a2-capability-registry
Run ID: RUN-epic-190-a2-capability-registry-qg-T-007-seq0670
Host Session ID: SESS-qg-epic-190-a2-capability-registry-T-007-0670
Ledger Sequence: 670
Allowed-Input Manifest: reports/review-context/pending-epic-190-a2-capability-registry-sdd-evaluator-T-007-seq0670-manifest.json (sha256 dc1cbb8ff68bc46ce8e03b9d1bffabd5c866b6cc25ddc41be3aaed021cc1a832)
Attempt: 1
VERDICT: PASS

## Launch Integrity (verified, not trusted)

- Manifest binds sequence 670, stage quality, role sdd-evaluator, run_id and
  host_session_id matching the assignment exactly; input_mode file-manifest,
  fallback_mode none, read_only true.
- previous_record_sha256 6e403aa0d6cef8f4b7bf7f986e4eb0818b713ec99abe74a39d1354c352d1c3c9;
  identity_ledger_sha256 994bf50c5618f4160d633906add1630900edafcf8bc8811d5a3e4ed21698c934
  binds the pre-reservation ledger. For this seq that is the live ledger minus
  exactly one tail record. The evaluator corrected the orchestrator's standing
  "drop N records" guidance here: the count is per-reservation
  (current_len - (seq - 1)), not a constant.
- 29 allowed-input manifest entries.
- Working tree clean of evaluator writes; the evaluator modified no repository
  file.

## Default-FAIL Verification Contract (Risk: medium; Required Workflow: tdd)

| Check | Type | passes | red_evidence | green_evidence / evidence |
|---|---|---|---|---|
| parity suite (sh) | acceptance-tests (tdd) | true | verification/T-007/red-wrapper-sh.log, red-runtime-sh.log | Independently re-ran `bash tests/capability-registry-parity.tests.sh` -> pass=22 fail=0 designed-red=0, exit 0 |
| parity suite (ps1) | acceptance-tests (tdd) | true | verification/T-007/red-wrapper-ps1.log, red-runtime-ps1.log | Independently re-ran `pwsh -NoProfile -File tests/capability-registry-parity.tests.ps1` -> pass=22 fail=0 designed-red=0, exit 0 |
| RED reproduction (4 classes) | differential | true | n/a | All four declared RED classes reproduced by the evaluator, not taken on the implementer's word |
| fault-injection non-masking (SDD_PARITY_INJECT) | source | true | n/a | Adjudicated by line-level inspection of tests/capability-registry-parity.tests.sh:38, :204-227, :286-291. The entry point can add failures; it has no path that suppresses one. Not spec-named, recorded Minor below |
| golden-fixture provenance | output-binding | true | n/a | Both goldens produced by running the shipped scripts, not hand-authored |
| suite registration | ci-resilience | true | n/a | Registered in tests/run-all.sh and tests/run-all.ps1 after T-006's entry; the staged CI candidate carries both steps and has been human-applied |
| sibling-suite non-regression | regression | true | n/a | Three sibling suites hold at 21/0, 17/0 and 27/0 |
| declared-output integrity | output-binding | true | n/a | 18 declared rows, every hash matching its file at verdict time. Two path aliases added post-verdict -- see below |
| scope discipline | spec-conformance | true | n/a | Change surface bounded to the harness, its fixtures, both runners, the staged CI candidate and T-007's own evidence |

## Findings

Critical: 0
Major: 0
Minor: 6 (recorded, non-blocking)

The evaluator's six Minors stand as recorded in its verdict. Three are worth
restating because they are spec-facing rather than implementation defects, and
the implementer surfaced all three rather than papering over them:

- design.md:785 / AC-030 prose says eight suites where the design actually
  shares one file between two test-strategy items, making it seven pairs. The
  evaluator checked the implementer's reading against traceability.md:13 and
  confirmed it. This is a specification wording defect, correctly not edited by
  an implementation task; it needs a spec-loop correction.
- Windows byte-identity is unmeasured, because three of the four PowerShell
  wrappers route stdout through the pipeline.
- `SDD_PARITY_INJECT`, the fault-injection entry point used to produce the
  required RED, is not named in the spec.

## Post-verdict evidence completion (quality gate)

Before recording Done I re-ran the coverage check that T-005 failed on three
consecutive cycles: compare the report's `## Outputs` table against the files
the task's own commit actually changed, rather than only re-measuring what the
table already declared. That comparison is the check my earlier tooling could
not perform, and it is the substance of RT-20260809-001.

For T-007 it found two paths changed by commit 326eeace and absent from the
table:

- `specs/epic-190-a2-capability-registry/human-copy/.github/workflows/test.yml`
- `specs/epic-190-a2-capability-registry/human-copy/MANIFEST.sha256`

Their content was never unreviewable: the table already declared the byte-
identical `drafts/` twins at hashes 0b2ee030... and 5368a4f6..., and those are
the same hashes the live files carry. What was missing was the `human-copy/`
path alias that a later evaluator would need in order to read the applied file
at its real location. I added the two rows and annotated them in the report.
The addition is monotone -- no existing row's path or hash changed, and no
claim, source file, test, or log was touched -- so it does not disturb the
verdict it follows and does not require re-review.

## Domain Surfaces

- Security: not touched -- the harness is read-only over existing scripts.
- Performance / Accessibility: not touched -- out of scope.

## Decision

Zero Critical, zero Major; all Done-When conditions satisfied, including the
human-applied CI candidate that the suite verifies at 22/0 in both runtimes.
T-007 -> Done.

Post-Done: T-005 and T-006 remain Implementation Complete under
RT-20260809-001 and RT-20260809-002 respectively, so the feature is not
complete and the retrospective stays deferred.

## Checked (self-executed)

- Re-ran both parity suites on the current tree: 22/0/0 each, exit 0.
- Recomputed all 18 originally-declared Outputs hashes: 0 stale, 0 missing.
- Diffed the declared set against `git show --name-only 326eeace`: 3 paths
  undeclared, of which tasks.md is a spec file (correctly never declared by an
  implementation report) and the other two are the aliases handled above.
- Read the manifest header directly and confirmed the sequence, role, run_id,
  host_session_id and ledger binding.
