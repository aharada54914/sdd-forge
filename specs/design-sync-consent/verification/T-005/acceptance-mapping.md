# T-005 — Register the design-sync-consent assertion suite in `run-all`:
# acceptance-first mapping

Written before the rest of this task's verification evidence, per
`Required Workflow: acceptance-first` (`tasks.md` T-005). This document is
the required Done-When ↔ evidence correspondence table. The supporting raw
evidence it cites lives alongside it in this directory:
`case-sensitivity-sweep-evidence.log`, `run-all-execution-evidence.log`, and
the fixture/harness files each references.

Base commit at task start: `6dc9cf09` (T-001) with `c33e1525` (T-002) and
`29d0ae3d` (T-003) already landed on top of it (`tasks.md` Status:
`Implementation Complete` for both at task-authoring re-check). T-004
(`Status: In Progress`) had its staged draft and `human-copy/MANIFEST.sha256`
already present on disk in this shared worktree by the time this task's
evidence was captured (untracked, `git status --short` confirms
`?? specs/design-sync-consent/human-copy/` and
`?? specs/design-sync-consent/verification/T-004/`) — a concurrent-agent
artifact of this shared worktree, not this task's own work, and not touched
by it. Working-tree HEAD during this task: `038350371e8c0e29eed0e89abfaafae2ef4b040f`.

## Files this task edits

Only the two named in scope:

- `tests/run-all.sh` — one line appended to the `tests=(...)` array.
- `tests/run-all.ps1` — one line appended to the `$tests = @(...)` array.

Both read in full before editing (per Done-When item 1's own requirement),
confirming the existing convention (bare, unquoted paths, one per line, no
trailing comma on the last `.sh` entry; single-quoted strings, comma-joined,
no trailing comma on the last `.ps1` entry) before appending.
`tests/design-system-contract.tests.{sh,ps1}` themselves, and
`.github/workflows/test.yml`, are untouched, per this task's explicit
prohibition and per `tasks.md`'s Protected Files section (`test.yml` is on
the 42-entry `PROTECTED_GATE_SUFFIXES` list; CI registration is a separately
staged, human-applied patch outside every task in this decomposition).

## Done-When ↔ evidence table

| # | Done-When (tasks.md T-005) | Evidence |
|---|---|---|
| 1 | Both suites registered in `tests/run-all.sh` and `tests/run-all.ps1`, each file read in full at implementation time, new entry appended following the file's existing convention. | Diffs below. Both files re-read in full before editing (this task's first two tool calls). `bash -n tests/run-all.sh` exits 0 (syntax-clean); `[System.Management.Automation.Language.Parser]::ParseFile` over `tests/run-all.ps1` reports `ParseErrors=0` — see `run-all-execution-evidence.log` §0. |
| 2 | Newly-reachable branch declaration (AGENTS.md sweep item 5): the entire pre-existing `DS-001`..`DS-017` block becomes reachable under a local `run-all` invocation for the first time; the report names the block/environment and either exercises `bash tests/run-all.sh` / the PowerShell equivalent for real, or flags any resulting failure as "pending first real execution". | See "Newly-reachable branch declaration" section below and `run-all-execution-evidence.log` §1–§3. Exercised for real (direct invocation + a tail-scoped harness replicating `run-all`'s own loop mechanism verbatim); one pre-existing, unrelated `DS-010` sub-assertion failure is named, not hidden. |
| 3 | Case-sensitivity sweep (AGENTS.md sweep item 1), narrow scope: every `-match`/`-notmatch`/`Select-String` site T-001 added to `tests/design-system-contract.tests.ps1` whose `.sh` counterpart compares case-sensitively is swept at both the operator level and the cmdlet level, with a mis-cased negative fixture recorded per layer. | `case-sensitivity-sweep-evidence.log` — full site enumeration (47 `-match`/`-notmatch` occurrences + 0 `Select-String` occurrences, both confirmed by exhaustive `grep`), 2 genuine operator-level divergences found and demonstrated with mis-cased fixtures, cmdlet layer confirmed empty (nothing to sweep). |
| 4 | RED baseline evidence: `bash tests/design-system-contract.tests.sh` and the PowerShell equivalent, captured after T-001's commit and before T-002/T-003/T-004 land, showing the expected failures while every pre-existing `DS-001`..`DS-017` assertion (incl. the seven `DS-006` literals) continues to pass. | **Cited, not re-captured** — see "RED baseline: why cited, not re-captured" below. Source: `specs/design-sync-consent/verification/T-001/red-baseline-sh.log` (78 PASS / 43 FAIL) and `.../red-baseline-ps1.log` (9 PASS / 42 FAIL), both committed at `6dc9cf09`. |
| 5 | TEST-039 traces this suite from a CI entry point in both runtimes; expected **red against the live tree** until a human applies the separately staged CI workflow patch (R-OQ-8 part 3, BL-005) — designed fail-closed, not a defect here. | Confirmed still red in every run this task performed (direct invocation, tail-harness invocation): `FAIL: TEST-039 ... -- DESIGNED RED: staged workflow patch not yet applied (R-OQ-8 part 3)` in both runtimes. `.github/workflows/test.yml` untouched by this task (see Files this task edits). |
| 6 | Acceptance-test and regression evidence for this task's own additions (the `run-all` invocation itself), per the medium tier's required-check set (`risk-gate-matrix.md`); `requirement-traceability` and independent review not mandated at this tier. | `run-all-execution-evidence.log` is this task's acceptance-test/regression evidence: the `run-all` invocation (direct + tail-harness-replicated) is the "test" this task's own change is verified against. Medium tier's required set is `{lint, typecheck, build (waivable, stack: shell), placeholder-scan, task-state-check, unit-tests, acceptance-tests, regression}` (`risk-gate-matrix.md:88-89`); `lint`/`typecheck`/`build` waived under the `shell` stack descriptor (`risk-gate-matrix.md:63-66`, `tasks.md` Global Constraints "Stack is `shell`") — reason: this task edits only a POSIX-shell array and a PowerShell array, no compiled/typed source, matching `design.md`'s "the loop has no executable code path" descriptor already applied to every other task in this feature. |

## Newly-reachable branch declaration (AGENTS.md "Author-time sweeps" item 5)

Before this task's edit, `tests/design-system-contract.tests.sh` and
`tests/design-system-contract.tests.ps1` were absent from both `run-all`
arrays (confirmed by reading both files in full — `grep -n
design-system-contract tests/run-all.sh tests/run-all.ps1` returned nothing
before this task's edit). Every `DS-001`..`DS-017` assertion at the head of
both files (contract schema, tokens template, design-system/ui-patterns
templates, `PLUGIN-CONTRACTS.md`, `design-sync-loop/SKILL.md`'s
`## Ensure design-system/`, `investigate-codebase` design inventory,
`design.template.md`/`design-lite.md`, `impl-reviewer-a`/`-b`,
`implementation-policy.md`, `visual-verify-loop`, the design-system
checklist/rubric/quality-gate wiring, `accessibility-checklist.md`, the
verification-contract/risk-gate-matrix wiring, and the four `DS-017`
documentation sites) — 70 `pass`/`fail` lines in `.sh`, 16 `throw`-guarded
checks in `.ps1` — was therefore never exercised by `bash tests/run-all.sh`
or its PowerShell twin, in this environment or in CI (CI registration for
this suite is the same separately-staged, human-applied
`.github/workflows/test.yml` patch T-001's own commit message and
`tasks.md`'s Protected Files section both name as out of every task's scope
here). Registering the suite makes this block reachable under a local
`run-all` invocation for the first time.

**Environment**: this repository, this working tree
(`/Users/jrmag/Projects/active/sdd-forge-wt-phase4`), macOS (Darwin), bash
and PowerShell 7.6.2 (`pwsh`) both present locally — not CI (CI reachability
is TEST-039's own, separately staged, concern).

**Exercised for real** (not flagged as merely pending): both suites were run
directly (`bash tests/design-system-contract.tests.sh`,
`pwsh -File tests/design-system-contract.tests.ps1`) and, additionally, via
a tail-scoped harness that replicates `run-all`'s own per-file loop body
verbatim (see `run-all-execution-evidence.log`). Result: every `DS-001`
through `DS-017` check passes in both runtimes **except one pre-existing,
unrelated sub-assertion** — `.sh`'s `DS-010 impl count updated` (checking a
stale "20 checks" literal in `phase-review-checklist.md` against the current
tree) — which T-001's own commit message already surfaced as "out of scope,
reported not fixed" before this task started; this task did not introduce
it, and it is not a `design-sync-consent` (TEST-NNN) assertion. The `.ps1`
twin does not carry this particular literal check (a pre-existing,
documented `.sh`/`.ps1` asymmetry, not something T-005 changed), so it does
not surface there.

## RED baseline: why cited, not re-captured

`tasks.md` T-005's Done-When calls for RED-baseline evidence "captured after
T-001's commit lands and before T-002/T-003/T-004 land". At this task's
start, `git log` already shows T-002 (`c33e1525`) and T-003 (`29d0ae3d`)
landed on top of T-001 (`6dc9cf09`), and T-004's staged artifacts already
exist on disk in this shared worktree (see "Base commit" above) — so the
window this Done-When item names has already closed by the time this task
runs, and a *new* capture is structurally impossible: any suite run
performed now runs against a tree with T-002/T-003 already applied (and
T-004's content already present), not the T-001-only tree the RED baseline
is defined against. This is exactly the situation the task prompt's own
framing anticipates: cite T-001's own captured logs from the correct window
rather than fabricate a new one against the wrong tree.

The cited evidence — `specs/design-sync-consent/verification/T-001/red-baseline-sh.log`
(78 PASS / 43 FAIL) and `.../red-baseline-ps1.log` (9 PASS / 42 FAIL), both
committed inside T-001's own commit `6dc9cf09` — was captured directly via
`bash tests/design-system-contract.tests.sh` / the PowerShell twin (not via
`run-all`, since `run-all` registration did not exist yet at that point),
exactly matching the "captured directly via the suite invocation above,
independent of this task's own `run-all` registration landing first" clause
`tasks.md` T-005's own Done-When states, and the identical point made from
T-002's side at `tasks.md:499-502` ("Both runs invoke the suite directly...
not via `tests/run-all`"). Both logs show every pre-existing `DS-001`..`DS-017`
assertion (including the seven `DS-006` literals) passing, and the expected
FAILs distributed exactly across the TEST-NNN rows whose target content
T-002/T-003/T-004 had not yet produced — re-verified by direct comparison
against the current, already-landed state in `run-all-execution-evidence.log`
§4 (nearly every one of those 2026-08-05-dated FAILs is now PASS, which is
the expected GREEN transition T-002's and T-003's own Done-When name, not a
re-capture of RED).

## Case-sensitivity sweep — narrow-scope justification

`tasks.md` T-005 explicitly narrows AGENTS.md sweep item 1's scope (which
also names `-eq`/`-ne`/`-contains`/`-notcontains`/`-replace`/`-like`/`-notlike`
at the operator layer) down to "every `-match`/`-notmatch`/`Select-String`
site". This task follows that narrower, explicitly-assigned scope rather
than the full AGENTS.md rule: `.Contains()` string-instance-method calls
(used extensively in the TEST-NNN block, e.g. TEST-006, TEST-009, TEST-015,
TEST-016, TEST-024, TEST-034/035/036, TEST-039, TEST-044) are *not* swept
here, because — unlike `-match`/`-notmatch`, which silently default to
case-**insensitive** — .NET's `[string]::Contains(string)` is ordinal
case-**sensitive** by default, so it carries none of the "reads like a
case-sensitive check, silently isn't" hazard AGENTS.md item 1 exists to
catch. Full findings in `case-sensitivity-sweep-evidence.log`.
