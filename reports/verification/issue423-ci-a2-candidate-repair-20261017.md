# Issue 423: A2 regenerated-candidate protection repair

## Scope and root cause

Baseline: `10072e8a952e26c6678c6a975d73013fffecad41`.
[CI run 39001712985, version-gates Ubuntu job 117306945890](https://github.com/aharada54914/sdd-forge/actions/runs/39001712985/job/117306945890)
reported 26 successful checks, two genuine failures and two designed-red results
in `generate-gate-capabilities.tests.sh`, exit 1. The cloud reproduced these
counts before editing. The initial working tree was clean; no overlapping
uncommitted changes were found.

The current canonical `guard-invariants.json` and `generate-guard-invariants.py`
already include T-005's protected
`plugins/sdd-bootstrap/scripts/resolve-design-sync.py`, introduced by
`7e110ebb763d24b7ee7d73f383d774e8f935823b`. The A2 regenerated draft candidates
predated that addition. Their protected_gate_suffixes and BASELINE_SUFFIXES
therefore each omitted one live protection. The gate-capabilities projection
generator itself was not the source of the dropped path.

## Repair

Only the six invariant files under
`specs/epic-190-a2-capability-registry/drafts/human-copy-candidate/` were refreshed:
the JSON and generator candidates now exactly match the current canonical live
sources, and the four projections were produced by executing that candidate
generator in a disposable tree, then running its `--check`. No generated
projection or source digest was hand-authored. Exactly six existing manifest
digest rows changed; all seven ordered paths and the workflow candidate/digest
remain unchanged. A dated README addition distinguishes this refresh from
historical recovery results and does not claim workflow freshness.

The Bash and PowerShell suites add two independent negative controls: remove
the helper from candidate JSON only, then remove it from the candidate generator
only. Each must be rejected by its existing superset checker with the exact
field/path diagnostic. Existing positive checks, shell/export and manifest
mutation controls, designed-red accounting, and nonzero exit policy remain.
PowerShell's source mutation accepts LF/CRLF and uses case-sensitive matching.

No frozen `human-copy/` files, live production bytes, task plans, T-004 reports,
identity ledger, permissions, trust settings, or previous verdicts were changed.
No candidate was applied and no PR was merged.

## Actual cloud results

| Command / observation | Exit and result |
|---|---|
| `bash tests/generate-gate-capabilities.tests.sh` before repair | 1; pass=26 fail=2 designed-red=2 |
| Same suite after repair and new negative controls | **1; pass=30 fail=0 designed-red=2** |
| JSON-only helper deletion fixture | Rejected with protected_gate_suffixes and exact helper path |
| Generator-only helper deletion fixture | Rejected with BASELINE_SUFFIXES and exact helper path |
| Candidate generator render and `--check` in isolated tree | 0 each; four outputs exactly match committed candidates |
| Read-only seven-file manifest/equality checks | 0; all hashes valid, six live-byte matches, workflow row preserved |
| `python3 -B plugins/sdd-quality-loop/scripts/generate-guard-invariants.py --check` | 0 |
| `python3 -B plugins/sdd-quality-loop/scripts/generate-gate-capabilities.py --check` | 0 |
| `bash tests/human-copy-mirror-freshness.tests.sh` | 0; 6 passed, 0 failed, 37 informational pending |
| `bash tests/guard-invariants-epic-a1.tests.sh` | 0; 83 PASS / 0 FAIL |
| `bash tests/phase2-guard-invariants.tests.sh` | 0; 42 passed / 0 failed |
| `bash -n tests/generate-gate-capabilities.tests.sh` | 0 |
| `git diff --check` | 0 |

PowerShell is unavailable in this cloud runtime. Its updated suite was inspected
but not executed; it is not counted as passing. No tools were installed.

## Independent development review

A fresh, conversation-isolated Codex reviewer, `ci_a2_candidate_review`, returned
PASS with zero Critical/Major/Minor findings. It independently ran the Bash suite
(30/0/2, exit 1), rendered and checked the isolated candidate, verified all four
projections and seven manifest hashes, checked exact live source equality and
preservation of row order/workflow bytes, and inspected PowerShell parity and
LF/CRLF handling. Frozen copies, live production and T-004/ledger were confirmed
unchanged. This is development diff review, not formal task acceptance.

## Remaining blocker

The two genuine candidate defects are repaired, but **the suite and full CI are
not green**. Its two separate designed-red checks still detect that the frozen
A2 human-copy JSON and generator would omit the current live protection. The
suite deliberately exits 1 for that state. Neither counter nor exit handling
was relaxed. Applying or replacing frozen evidence is outside this repair's
authorization. Resolve that remaining condition through its authorized process;
do not treat candidate freshness, isolated checks or this review as human apply.
Publication-head CI must be reported separately from these local cloud runs.
