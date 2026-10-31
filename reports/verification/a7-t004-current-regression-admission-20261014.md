# A7 T-004 current regression and admission investigation — 2026-10-14

Scope: parent-authorized execution of the existing activation regressions,
activation mutation diagnostics, workflow-state and traceability checks only.
This is a non-frozen verification addendum, not an implementation or quality-gate
report. No task state, frozen Outputs, declaration, reservation or shared
enforcement file was changed. No evaluator or cross-model review was launched.

Owner checkout: `/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge`

Observed HEAD: `25813ee4baf8ae8fff344a6c979da61fbd23d2c7` (detached).
The owner already had 369 dirty status entries before these checks; 369 remained
after the mutation scratch cleanup, before this new addendum. Results apply to
the dirty owner bytes, not to a clean commit or the remote PR head.

## Current executions

All commands ran in the owner checkout with a non-login shell. Each completed
with exit code 0. These are fresh execution summaries from tool output; complete
raw transcripts were not persisted by this run. Historical logs were not replaced.

| Command | Observed result |
| --- | --- |
| `rtk proxy bash specs/epic-195-a7-compatibility/verification/T-004/activation-regression-20261004.sh sh` | 77 passed, 0 failed; F3 active structural regression PASS |
| `rtk proxy bash specs/epic-195-a7-compatibility/verification/T-004/activation-regression-20261004.sh ps1` | 84 passed, 0 failed; F3 active structural regression PASS |
| `rtk proxy bash specs/epic-195-a7-compatibility/verification/T-004/activation-mutation-20261004.sh sh` | 5 killed, 0 survived |
| `rtk proxy bash specs/epic-195-a7-compatibility/verification/T-004/activation-mutation-20261004.sh ps1` | 5 killed, 0 survived |
| `rtk proxy bash plugins/sdd-quality-loop/scripts/check-workflow-state.sh --feature epic-195-a7-compatibility` | workflow-state: ok |
| `rtk proxy bash plugins/sdd-quality-loop/scripts/check-traceability.sh specs/epic-195-a7-compatibility/traceability.json . require-evidence` | Traceability check passed: 7 links |

The five mutations in each runtime were f3-paths, f3-heading, f3-status,
f3-malformed, and corpus-and-template-bad-heading. They failed as expected inside
isolated scratch fixtures; those diagnostic REDs are not production failures or
quality-gate verdicts. The script's trap removed its scratch directory.

## WFI-036 route found, not yet formally admitted

An existing untracked declaration already exists:
`reports/quality-gate/epic-195-a7-compatibility/T-004.pre-gate-declaration-cycle4-20261007.md`.
Its observed SHA-256 is
`0105876cbfe3db069668dbfd15d5cc2ee55ef3897314a57a07186fd28cd653cb`.
All 20 path/hash pairs in its Post-Fix Artifacts table matched current files.
This corrects the earlier readiness inference that there was no declaration.

The implementation Outputs need not be amended to use the second admission
channel. `plugins/sdd-quality-loop/scripts/validate-review-context-set.sh:369`
defines the optional quality-only `gate_report_declaration` object with `path`
and `sha256`; lines 684–700 validate the report namespace, regular/no-symlink
path and hash before its rows can authorize inputs. This branch does not check
the declaration's verdict or Run ID. Therefore the existing declaration is a
mechanically plausible source, not evidence that a complete invocation passed.

Normative provenance is still unresolved: the declaration explicitly says
`VERDICT: N/A`, no evaluator launched, not yet pinned (declaration lines 3–11).
`plugins/sdd-quality-loop/skills/quality-gate/SKILL.md:160`–175 describes a
post-fix cycle recording rows in its own gate report and the next cycle naming
that report; it prohibits appending rows to an earlier verdict report. Merely
placing a preparation document in the report namespace does not demonstrate
that cycle provenance. The coordinator must establish an applicable sanctioned
declaration provenance before treating this preparation document as admitted.
No prior report was amended and no full canonical manifest was created or
validated in this investigation.

Conditional manifest field (rehash immediately before any future launch):

```json
{
  "gate_report_declaration": {
    "path": "reports/quality-gate/epic-195-a7-compatibility/T-004.pre-gate-declaration-cycle4-20261007.md",
    "sha256": "0105876cbfe3db069668dbfd15d5cc2ee55ef3897314a57a07186fd28cd653cb"
  }
}
```

This addendum and the activation wrapper scripts are not among those 20 rows;
do not silently include them as evaluator inputs. If needed as evaluator inputs,
they need their own exact path/hash admission through the sanctioned channel.

## Exact next entry and unmet prerequisites

The scoped orchestrator entry is
`/sdd-ship:ship specs/epic-195-a7-compatibility/tasks.md#T-004`
(Codex: use the ship skill for that task). Quality-gate must not be invoked
directly (`plugins/sdd-quality-loop/skills/quality-gate/SKILL.md:8`). Before the
gate, the coordinator must complete the approved repair lifecycle and establish
Implementation Complete; T-004 remains Approved / In Progress
(`specs/epic-195-a7-compatibility/tasks.md:555`–561).

`plugins/sdd-ship/skills/ship/SKILL.md:297`–322 requires same-invocation
cross-model verification for Security-Sensitive tasks, or the specified valid
human waiver, even without --verify. T-004 has Security-Sensitive: true
(`tasks.md:581`); a disabled/absent Cross-Model flag is not a waiver. No fresh
cross-model result or valid waiver was established here. Gemini is prohibited
for this work; no substitute panel composition or waiver was invented.

After provenance, state and required verification are satisfied, construct the
canonical allowed-input and one-role invocation manifests with exact current
hashes, the single T-004 implementation report, required specifications and
calibration inputs. The native launcher documented at
`plugins/sdd-quality-loop/skills/quality-gate/SKILL.md:225` performs preflight
before its single reservation; do not pre-reserve separately.

Not run: formal manifest admission, identity reservation, native evaluator,
quality-gate, same-invocation cross-model verification, current-head CI, merge
or post-merge verification. This record makes no Done, delivery, or historical
unexecuted-check PASS claim.
