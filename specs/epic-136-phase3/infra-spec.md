# Infrastructure Specification: epic-136-phase3

**Stream C status.** ADR-0010 reached `Status: Accepted` (commit `67015a5`,
2026-07-22), discharging Stream C's Blocker, and Stream C landed in this
feature (T-004). requirements.md and design.md carry the authoritative
record; this document is reconciled to it.

4 new-test-suite/CI-lane-restructuring streams. No cloud service, deployment
target, IaC resource, network route, or data store is added or changed. The
only infrastructure-facing edit across the four streams is
`.github/workflows/test.yml`, staged as ONE shared human-copy batch
covering all four streams' 4 new CI steps — Streams A/B/C's three product
suites plus Stream D's own `tests/deterministic-lane-selfcheck.tests.sh`
self-check harness — and Stream D's step-prefix lane marking (design.md
Protected-File Statement) — never two sequential human-copy rounds against
the same protected file within this feature.

## Deployment Topology

```mermaid
flowchart LR
  DISPATCH["sdd-hook-guard.sh (live, protected)"] -->|python3 present| GUARDPY["sdd-hook-guard.py (live, protected)"]
  DISPATCH -->|python3 absent, ps variant present| GUARDPS["sdd-hook-guard.ps1 (live, protected)"]
  DISPATCH -->|all absent| DENY["deny_unavailable (fail-closed)"]

  GDF["tests/guard-dispatch-fallback.tests.sh (Stream A, new)"] -->|PATH-restricted subshell, drives real| DISPATCH
  GDF -->|decision-parity, direct invocation| GUARDPY
  GDF -->|decision-parity, direct invocation| GUARDPS

  GNC["tests/guard-negative-corpus.tests.sh (Stream B, new)"] -->|env-var indirection, drives real| GUARDPY
  GNC -->|drives real| GUARDPS
  GNC -->|drives real| DISPATCH
  GNC -.->|node present| GUARDJS["sdd-hook-guard.js (live, protected)"]

  CI["test.yml 3-OS matrix (windows / macos / ubuntu)"] --> TESTJOB["test job ([deterministic]-prefixed steps, Stream D)"]
  TESTJOB --> GDFSTEP["Test guard dispatch fallback suite (bash, Stream A new step)"]
  TESTJOB --> GNCSTEP["Test guard negative corpus suite (bash, Stream B new step)"]
  TESTJOB --> WFSSTEP["Test workflow-scenarios suite (bash, Stream C new step)"]
  TESTJOB --> RC["required-checks (needs: [test, cli-hook-enforcement], UNCHANGED membership)"]

  HUMAN["Human maintainer"] -->|copies ONE shared staged candidate, MANIFEST.sha256 verified| TESTYMLLIVE[".github/workflows/test.yml (protected, live)"]

  ADR["ADR-0010 (Status: Accepted)"] -.->|Blocker discharged, commit 67015a5| WFSCEN["tests/workflow-scenarios/ (Stream C, created by T-004)"]
```

## CI/CD Sequence

`.github/workflows/test.yml`'s existing 3-OS matrix (`windows-latest`,
`macos-latest`, `ubuntu-latest`, `test.yml:18`) and existing step-pairing
pattern are unchanged in SHAPE by this feature — Stream D deliberately
avoids splitting the single `test` job into multiple jobs (design.md
Design Decisions, OQ-5), so no toolchain-setup step is re-run per new job
per OS. All four streams together add exactly 4 new steps to the existing
`test` job — one per new suite, Stream D's self-check harness included —
each now carrying the `[deterministic]` name prefix Stream D's
restructuring applies to every step in that job. This block is the
byte-exact tail of the staged candidate
(`specs/epic-136-phase3/verification/T-003/staged-workflow-candidate.draft.yml`),
in the same order:

```yaml
      - name: "[deterministic] Test guard dispatch fallback suite (bash)"
        shell: bash
        run: bash ./tests/guard-dispatch-fallback.tests.sh
      - name: "[deterministic] Test guard negative corpus suite (bash)"
        shell: bash
        run: bash ./tests/guard-negative-corpus.tests.sh
      - name: "[deterministic] Test deterministic-lane self-check suite (bash)"
        shell: bash
        run: bash ./tests/deterministic-lane-selfcheck.tests.sh
      - name: "[deterministic] Test workflow-scenarios suite (bash)"
        shell: bash
        run: bash ./tests/workflow-scenarios/workflow-scenarios.tests.sh
```

Because `.github/workflows/test.yml` is itself an enforcement-chain
protected file
(`plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4`,
design.md Protected-File Statement), ALL FOUR streams' edits are staged as
ONE combined candidate under
`specs/epic-136-phase3/human-copy/.github/workflows/test.yml` with ONE
`MANIFEST.sha256`, following `epic-136-phase2-gates/tasks.md:16-25`'s
established Human-Copy Procedure verbatim. The human maintainer applies
the shared candidate as one pre-merge commit on the feature PR branch:
until it lands, the PR's own CI stays red on TEST-019/020's live-file
self-check — the designed fail-closed state, with no staged-candidate
fallback.

`tests/run-all.ps1` receives NO new entry for ANY of the four new suites
(design.md Global Constraints) — none of
`tests/guard-dispatch-fallback.tests.sh`,
`tests/guard-negative-corpus.tests.sh`,
`tests/workflow-scenarios/workflow-scenarios.tests.sh`, or
`tests/deterministic-lane-selfcheck.tests.sh` ships a native `.ps1` twin;
each drives its `.ps1`/`.js`/YAML targets via subprocess/PATH indirection
or plain text inspection from a `.sh`-only driver, matching
`guard-cwd-bypass.tests.sh`'s and `guard-r10-port.tests.ps1`'s own
established shapes for this class of cross-runtime suite. All four ARE
registered in `tests/run-all.sh` (lines 37, 47, 48, 49).

Determinism lane (Stream D, #126): the `[deterministic]` step-name prefix
applied across the `test` job's existing steps is the visible artifact of
this restructuring — no step moves to a new job, so `required-checks`'
`needs: [test, cli-hook-enforcement]` membership is UNCHANGED (BL-001
preserved by construction, design.md Constraint Compliance). When a real
LLM-invoking eval step is eventually proposed, it lands in a genuinely
separate job outside this `needs:` list, following the isolation pattern
`self-improvement.yml` already establishes (investigation.md INV-021) —
this feature does not itself add that job, only the naming boundary that
makes the future split's target obvious.

## Runtime Dependencies

| Dependency | Used by | Absence behavior |
|---|---|---|
| bash | all four new suites; `tests/run-all.sh` | already an established repository-wide precondition; GitHub-hosted runners ship bash by default |
| python3 | `tests/guard-dispatch-fallback.tests.sh`'s control case (AC-001) and decision-parity checks | already a hard dependency of `sdd-hook-guard.sh`'s own `.py` branch (unchanged); the suite's OTHER cases deliberately construct a `python3`-absent `PATH`, so absence is exercised on purpose, not merely tolerated |
| pwsh / powershell.exe / powershell (at least one, or stubbed) | `tests/guard-dispatch-fallback.tests.sh`'s fallback-branch cases (AC-002..006) | the suite provides thin forwarding stubs (design.md API/Contract Plan) so a host lacking a real PowerShell variant can still exercise `command -v`-level branch selection; the underlying DECISION parity check (AC-002..004) requires a real interpreter reachable from the pre-override `PATH` and SKIPs with a named reason if none is available, mirroring `guard-parity.tests.sh`'s SKIP convention |
| node | `tests/guard-negative-corpus.tests.sh`'s `.js`-runtime sub-cases | already a hard dependency of `sdd-hook-guard.js` (unchanged); absence SKIPs only the `.js` sub-cases of AC-008/009/010, not the whole suite |
| git | human-copy staging verification (the shared carve-out covering all four streams) | already a repository dependency |

No new services, containers, or package installations of any kind.

## Environments

| Environment | URL | Auth | Trigger | Classification | Promotion Rule |
|---|---|---|---|---|---|
| local | repository checkout | none / synthetic fixtures | `bash tests/run-all.sh` | internal fixtures only | all four new suites green |
| CI matrix (`test.yml`) | no network use by any of the four new suites beyond checkout | scoped `GITHUB_TOKEN` (unchanged) | push / PR / merge_group | synthetic fixtures | all required checks green on 3 OSes, once the shared human-copied `test.yml` candidate (Streams A + B + C + D) is live |

## Runtime Budget

No stream's suite requires a runtime-budget assertion (design.md Test
Strategy item 4): all four new suites are pure fixture-driven
function/script/text-inspection testing — no live network call, no
subprocess-loop-driving beyond what
`guard-cwd-bypass.tests.sh` and `guard-parity.tests.sh` already do for a
comparable class of guard-invocation suite.

## Infrastructure as Code, Scaling, SLOs, and Residency

N/A — no change: no deployed service. The only IaC-like artifact touched is
`.github/workflows/test.yml` (existing, protected — 4 new steps plus a
step-name-prefix restructuring, one shared human-copy batch covering all
four streams).

## Observability

| Logs | Traces | Metrics | Alert | Owner | Runbook |
|---|---|---|---|---|---|
| each new suite's own stdout/stderr (per-combination PASS/FAIL lines, acceptance-tests.md Notes); GitHub Actions job status for the `test` job (unchanged mechanism, 4 new `[deterministic]`-prefixed steps) | N/A | pass/fail per suite per OS per lane (`test.yml`, unchanged mechanism) | none new — this feature adds no new alerting surface; a cross-runtime decision-parity FAIL (AC-011) names the disagreeing runtimes directly in its own output, no separate alert channel needed | maintainers | re-run the affected suite locally (`bash tests/guard-dispatch-fallback.tests.sh` / `bash tests/guard-negative-corpus.tests.sh`) against a fresh fixture if a CI failure needs reproduction |

## Rollback

Streams A, B, and C: reviewed revert of their own commits removes their 3
product test suites; because their CI-step registration is part of the
SHARED `test.yml` human-copy batch with Stream D, a revert of the LIVE
`test.yml`'s registration lines requires a second human-copy application
(staging a candidate with those 3 step blocks removed, leaving Stream D's
own self-check step — the 4th — in place) — the same human-in-the-loop
mechanism that added them, never a direct agent revert of the live
protected file. Stream D: reverting its step-prefix lane marking similarly
requires a second human-copy application removing the `[deterministic]`
prefixes, its own self-check suite's step block (the 4th of the 4 new
steps), and the comment lane-boundary placeholder; if
Streams A/B/C's step lines are meant to survive a Stream D revert, the
implementation report for whichever stream lands LAST in the shared batch
must record the exact revert boundary (design.md Deployment / CI Plan).
Stream C's rollback is a reviewed revert of T-004's own commits
(`tests/workflow-scenarios/` and its driver suite are new, unprotected files,
so no protected-file round-trip is needed) plus removal of its line from
`tests/run-all.sh` and its step from the shared staged candidate.

## Open Questions

None. Owner: maintainers; non-blocking.
