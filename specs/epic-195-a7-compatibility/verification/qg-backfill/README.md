# T-001 / T-002 / T-003 verification-artifact backfill

Recorded 2026-08-13. This directory holds the evidence produced while
backfilling six verification artifacts that this feature's first three quality
gates never created, plus the machine-readable `traceability.json` the feature
never carried.

## What was wrong

`plugins/sdd-quality-loop/scripts/check-task-state.sh specs/epic-195-a7-compatibility/tasks.md`
exited 1 with six errors: T-001, T-002 and T-003 are each `Status: Done` while
`verification/T-00N.evidence.json` and `verification/T-00N.contract.json` do not
exist. `git log --all --oneline --full-history` against each of the six paths
returns zero commits — they never existed on any branch. All three prior gate
reports (`reports/quality-gate/epic-195-a7-compatibility/T-00{1,2,3}.md`) passed
their task to `Done` without producing them, and none of the three mentions
`check-task-state`, `check-contract` or `check-evidence-bundle` at all.

Separately, `specs/epic-195-a7-compatibility/traceability.json` did not exist:
the feature carried only the Markdown `traceability.md`, so `check-traceability`
had no target.

The T-004 quality gate recorded both as inherited conditions and deliberately
left them alone, since fixing them means touching three Done tasks and is
outside T-004's scope.

## The decision: backfill, not waiver

The two options were (1) build the six artifacts properly, or (2) record a
documented waiver so the gate's expectations and this feature's reality agree.

**Option 2 is not implementable.** It was checked against the code, not
assumed:

- `check-task-state.sh` has no waiver, allowlist, exemption, or skip mechanism.
  Reading the whole script: the `Done` branch (`:97-142`) fails closed on a
  missing bundle or contract with no escape.
- It honours no sudo bypass. `SDD_SUDO` does not appear in `check-task-state.sh`,
  `check-contract.py`, or `check-evidence-bundle.sh`. `risk-gate-matrix.md`'s
  cross-gate table says so explicitly for the two-person control ("never
  sudo-bypassed").
- Giving the gate a waiver path means editing the gate scripts themselves, which
  are R-10 protected and watched by `detect-policy-weakening`. That is a
  deliberate weakening of an enforcement chain to make one feature's history
  look compliant — the opposite of what a waiver is for.
- A waiver recorded only in prose would leave `check-task-state` red forever.
  `task-state-check` is a `required: true` check at **every** risk tier
  (`risk-gate-matrix.md`), so every remaining task in this feature (T-004 through
  T-012) would be unable to produce passing evidence for it. The feature would
  be permanently blocked by a document nothing reads.

**Option 1 is honest here, because the verification is real.** The contracts are
not a retroactive story about what the seq0662/0667/0671 gates did. Every
passing check points at output that was *re-run at the current HEAD* by
`run-checks.sh`, in both runtimes, during this backfill. A contract check asserts
"this command ran and here is its output"; that assertion is literally true of
every check flipped to `passes: true` here. Each contract's `comment` field says
in its first word that it is a BACKFILL and states that it is not a record of
the original gate.

Two fields are the deliberate exception and stay historical:
`red_evidence`/`green_evidence`. A Red run against a finished implementation is
green, so re-running it after the fact would manufacture a false artifact. Those
paths point at the logs the TDD/acceptance-first cycles captured at
implementation time, unchanged since, and each contract's comment says so.

## What was built

| Stage | Commit subject | Contents |
|---|---|---|
| 1 | `docs(epic-195-a7): derive traceability.json …` | `traceability.json` + `derive-traceability-json.py` |
| 2 | `docs(qg): add the machine-readable header …` | header lines on the three gate reports |
| 3 | `test(epic-195-a7): re-run every gate check …` | `run-checks.sh` + eight fresh logs |
| 4 | `feat(epic-195-a7): author the missing … contracts` | three `T-00N.contract.json` |
| 5 | `feat(epic-195-a7): generate the missing … bundles` | three `T-00N.evidence.json` |

### traceability.json

`requirement-traceability` is a required check at T-002's **high** tier, so the
missing JSON companion was a hard prerequisite of the backfill, not an optional
extra. `traceability.md` is reviewed and frozen, so the JSON is *derived* from
it by `derive-traceability-json.py` rather than transcribed: `tests(REQ)` unions
the REQ row's own Test ID cell with the Acceptance Tests cells of every Task
Mapping row naming that REQ, and `acs(REQ)` is read back out of the Acceptance
Mapping table. The result covers all 43 acceptance criteria with zero extras.
Re-run with `--check` to prove the two are still in sync; that check is part of
`traceability.log`, so a future drift turns the gate red instead of rotting
silently. `traceability.md` itself is unchanged.

REQ-009 is excluded by design: its Test ID, Code Target and Evidence cells are
all `N/A` because it is Epic A1's own upstream requirement, and
`check-traceability` rejects a zero-test link. Inventing a test id for an
out-of-scope external requirement is exactly the fabrication that gate exists to
prevent.

### The gate-report header

`check-evidence-bundle` requires the quality report a bundle names to carry a
bare `^Task ID: T-NNN` line, exactly one `^Feature:` line, and a
`^VERDICT: PASS` line. `T-003.md` carried none of the three — its Task ID and
Verdict were bullet items — so no bundle could legally name it.
`generate-evidence-bundle` additionally parses `^Critical:`, `^Major:` and
`^Minor:`, which no report carried, and it records the **first** `^VERDICT:`
match, which for T-003 was its superseded cycle-1 `NEEDS_WORK`.

The added lines restate each report's own Result/Disposition section verbatim.
No finding, count, or verdict was changed and no body text was removed.

### The task-state fixed point

`task-state.log` is self-referential: `check-task-state` transitively hashes
every artifact an evidence bundle names, and `task-state.log` is one of them.
The convergence used here is:

1. bootstrap the log with the real failing output (three missing bundles);
2. generate the bundles — they hash the bootstrap bytes;
3. re-run the gate: it passes, because the bundles exist and the log on disk
   still matches what they recorded;
4. regenerate the bundles over the now-passing log;
5. re-run once more.

Step 5's output is **byte-identical** to the stored log, which is the proof the
fixed point is reached rather than asserted: `check-task-state`'s success text
does not depend on any hash, so it cannot oscillate. `run-checks.sh` assembles
each log in a `.partial` sibling and moves it into place only after the command
exits, so the gate never reads a half-truncated copy of its own output file.

All three bundles record `git_generated_dirty: true`. That is the honest value —
the logs they hash are uncommitted at generation time by construction — and the
flag is a hard failure only at the `critical` tier, which none of these tasks is.

## How to re-verify

```sh
sh specs/epic-195-a7-compatibility/verification/qg-backfill/run-checks.sh
sh specs/epic-195-a7-compatibility/verification/qg-backfill/run-checks.sh task-state
plugins/sdd-quality-loop/scripts/check-task-state.sh specs/epic-195-a7-compatibility/tasks.md
```

The third command is the one that opened this work. It now exits 0 with
`Task state check passed for 12 task(s).` The PowerShell twin
(`check-task-state.ps1`) agrees, as do `check-contract.{sh,ps1}` and
`check-evidence-bundle.sh` run standalone against each artifact.

Regenerating the logs makes the bundle hashes stale, because a fresh test run
produces fresh temporary paths. After any re-run, regenerate the bundles too:

```sh
sh plugins/sdd-quality-loop/scripts/generate-evidence-bundle.sh specs/epic-195-a7-compatibility/verification/T-001.contract.json reports/quality-gate/epic-195-a7-compatibility/T-001.md .
```

## Not fixed here, deliberately

- **The process defect that caused this.** Three consecutive quality gates
  reached a `Done` decision without running `check-contract`,
  `check-evidence-bundle`, or `check-task-state`, which
  `deterministic-check-policy.md` lists as required before any `Done` decision.
  Backfilling the artifacts does not stop the fourth gate from doing the same.
  That belongs in a `docs/workflow-improvements/WFI-NNN.md` with its own audit
  cycle, which is a reviewed artifact and outside this change's scope.
- **`T-004.md` has the same missing header** that `T-003.md` had. It is not
  touched here because T-004 is `Implementation Complete` with a `NEEDS_WORK`
  verdict, so it names no bundle yet — but its next gate cycle will hit this
  wall unless the header is added when the report is rewritten.
- **`tests/capture-golden-baseline.sh` needs Python >= 3.10.** Under a
  restricted `PATH=/usr/bin:/bin` on macOS, `python3` resolves to the system
  3.9.6, where `pathlib.Path.write_text()` has no `newline` keyword; the script
  dies with a `TypeError` and `tests/golden-baseline-contract.tests.sh` reports
  3 failures, `tests/compatibility-byte-identical.tests.sh` 2. Both suites are
  fully green (10/0 and 25/0) under the normal `PATH`. The suites do fail closed
  on it, so this is a portability finding, not a correctness one, and fixing it
  would mean editing a T-002 deliverable — outside this change's scope.
- **`check-workflow-state` still reports `task plan hash is stale`** for this
  feature. That predates this work (the T-004 gate recorded it as the expected
  consequence of the `Implementation Complete` flip, resolved by the post-Done
  provenance re-bind) and this backfill neither fixed nor worsened it: the
  diagnostic set is identical before and after.
- **No task Status, `Approval`, or `Second Approval` line was touched.**
  `tasks.md` is unmodified by this entire change.
