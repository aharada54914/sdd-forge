# Issue 423: A1 guard-invariants CI repair validation

## Failure and cause

On `87f59ca3c921d553ccefaa5082c21c238e838510`,
[CI run 38999349235, job 117300625311](https://github.com/aharada54914/sdd-forge/actions/runs/38999349235/job/117300625311)
failed the Bash A1 guard-invariants registration suite: 74 PASS / 8 FAIL, exit 1.
The cloud reproduced those exact counts.

T-005 commit `7e110ebb763d24b7ee7d73f383d774e8f935823b` added
`plugins/sdd-bootstrap/scripts/resolve-design-sync.py` to live protected paths
and BASELINE_SUFFIXES, then regenerated four native outputs. The A1 staged
archive retained its previous six files. This produced two inventory/constant
mismatches and six byte-comparison failures.

## Concurrent repair and preservation

The regular `python3 -B scripts/sync-human-copy-mirrors.py --check` was tried
first: exit 0, no stale mirrors. It classified these branch-applied mirrors
PENDING because origin/main predates earlier branch inventory updates.
A bounded six-file synchronization was prepared after proving all old A1
bytes equal the verified `7848ad97` live tree, but was not published.

Before publication, fetch found concurrent remote commit
`1d1dd859d5699a575ce9e5de52fff7debb6c611c`, which repairs this failure while
explicitly preserving the A1 archive. The cloud withdrew its unpublished mirror
changes rather than overwrite that archive or duplicate the repair. The final
cloud delivery adds only this separate CI verification report on top of that
commit. The concurrent commit's tests and helper remain unchanged.

That repair changes only `tests/guard-invariants-epic-a1.tests.sh`, its PowerShell
twin, and `tests/lib/guard-invariants-evolution.py`. The helper authenticates
archived source digests before using its validator/renderer, permits literal
baseline additions, preserves ordered unique historical protected paths and
identical policy, and compares all four live projections against the archived
renderer. Historical pre-apply and applied states remain accepted. Coherent
negative controls reject archive tampering, removed/reordered/duplicate paths,
policy weakening, generator changes or duplicate assignments, and stale native
projections; an additional protected path is explicitly exercised.

No T-004 plan/report, ledger, live production bytes, pending candidate, frozen
archive, or historical verdict is modified by this cloud delivery. No new
permissions, trust changes, installation, review reservation, task-state update
or PR merge occurred.

## Actual cloud verification on the preserved remote repair

| Command | Exit / result |
|---|---|
| `bash tests/guard-invariants-epic-a1.tests.sh` | 0; 83 PASS / 0 FAIL |
| `python3 -B tests/lib/guard-invariants-evolution.py specs/epic-189-a1-project-context/human-copy/plugins/sdd-quality-loop plugins/sdd-quality-loop --self-test` | 0; all embedded positive/negative controls completed |
| `bash tests/human-copy-mirror-freshness.tests.sh` | 0; 6 passed / 0 failed; 43 informational PENDING, not accepted as applied |
| `python3 -B tests/human-copy-mirrors-classification.tests.py` | 0; 2 passed |
| `bash tests/phase2-guard-invariants.tests.sh` | 0; 42 passed / 0 failed |
| Live and A1-staged `generate-guard-invariants.py --check` | 0 each |
| `git diff --check` | 0 |

The phase2, classification and generator checks cover unchanged live/phase2
inputs; no result from the withdrawn mirror synchronization is substituted for
the 83-check final A1 execution. PowerShell is unavailable in this runtime;
its suite was not executed here or counted as passing.

## Independent development review

A fresh, conversation-isolated Codex reviewer, `ci_a1_overlap_review`, inspected
`87f59ca3..1d1dd859` and the restored archive. Verdict: PASS, no Critical/Major
findings. It independently ran A1 (83/0) and the direct helper self-test (exit 0),
and inspected PowerShell parity. It noted the ordinary Python interpreter/cache
trust assumption for direct helper execution; the suites suppress bytecode
writes. This is development diff review, not T-004 formal evaluation.

The earlier independent review of the withdrawn mirror alternative is not
transferred to the final repair. No model/session or formal ledger reservation
is reconstructed. Full publication-head CI remains separate: run 39001505542
was pending for the concurrent implementation commit when checked, not PASS.
