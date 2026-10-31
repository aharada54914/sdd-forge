# Implementation Report: T-001

- Task ID: T-001

Report Schema: implementation-report/v2

**Snapshot Notice**: The numbers, statuses, and paths recorded below reflect
the state at this report's own authoring run only. A later same-feature
event -- another task's edit to the same surface, or a gate-phase artifact
normalization such as a path move -- may supersede them. The quality
verification gate's own report is the authority for the gate-time state;
this report is not edited after the fact to reconcile it.

## Target

Feature: epic-159-pillar-a2 -- T-001 "Create the HITL/WFI-audit
terminal-behavior suite" (Issue #145, REQ-001 / REQ-005 / REQ-006;
AC-001..AC-006, AC-017/AC-018/AC-019 shares scoped to this task).

## Summary

Authored `tests/hitl-wfi-terminal.tests.sh` / `.ps1` (full-parity twins,
16 checks each) locking the terminal behavior of the two
skill-instruction-enforced loops that wave-1 (epic-159-pillar-a) registered
in `tests/loops/loop-inventory.json` but never suite-drove: HITL-diagnosis
(cap 5) and WFI-audit (cap 3).

The HITL leg copies the REAL
`plugins/sdd-implementation/skills/diagnose/scripts/hitl-loop.template.sh`
into a `pwd -P`-normalized mktemp fixture (never editing the real template
in place) and drives it with a `CHECK` shell function exported via
`export -f CHECK`, plus 5 lines of mocked stdin satisfying the per-iteration
`read -r ans` prompt: a never-reproducing case (TEST-001, AC-001 -- 5
iterations, exit 0, terminal string) and a reproduces-on-iteration-3 case
(TEST-002, AC-002 -- immediate exit 1, the `RED:` canary that guards
against a broken `CHECK` wiring silently passing TEST-001 for the wrong
reason).

The WFI-audit leg never invokes the `wfi-audit-cycle` skill. Instead
`assert_wfi_audit_transition` (bash) / `Test-WfiAuditTransition` (pwsh)
apply the documented, one-directional STEP 4 / STEP 7 BLOCKED-verdict field
mutation (`wfi-audit-cycle/SKILL.md:119-135,186-203`) to fixture-scoped
copies of a minimal WFI-NNN.md across Audit-Attempt 0->1->2->3 (TEST-003,
AC-003), with a negative self-check that mutates the `>= 3` threshold to
`>= 4` and proves the attempt-3 case turns red. A construction proof
(TEST-004, AC-004) greps both new suite files for an invocation of the
remote issue-tracker CLI (pattern built from character codes at runtime so
the check line cannot match itself) and confirms the WFI-audit fixture's
`Category:` field is always `process`, keeping SKILL.md STEP 8 a documented
no-op. A read-only real-document smoke check (TEST-005, AC-005) parses
fixture-scoped copies of `docs/workflow-improvements/WFI-010.md` and
`WFI-011.md`, asserts both satisfy the one-directional invariant (absent
`Audit-Attempt:` treated as 0 -- exercised by WFI-011.md, which carries no
such field), and re-hashes the two real files to confirm their SHA-256 is
unchanged before vs. after the run. Self-registration + runtime budget
(TEST-006, AC-006) greps `tests/run-all.sh` / `tests/run-all.ps1` /
`.github/workflows/test.yml` for the suite's own basename and sources
`tests/lib/loop-driver.sh`'s `assert_runtime_budget` /
`LOOP_SUITE_BUDGET_SECONDS=300` with a threshold-0 negative self-check.

Acceptance-first order was followed: the suite content was authored and run
standalone before registration, producing a red run where every check
passed except the two self-registration assertions (TEST-006.1/.2) -- the
suite drives already-correct real behavior (the template's iteration cap,
the two real WFI documents), so the only property genuinely absent before
this task's registration edits was the registration itself. After
registering the suite in the three shared files, both twins ran fully
green (16 passed, 0 failed each).

## Files Changed

- `tests/hitl-wfi-terminal.tests.sh` (new) -- HITL leg (TEST-001/TEST-002),
  WFI-audit leg (TEST-003), construction proof (TEST-004), real-document
  smoke (TEST-005), self-registration + runtime budget (TEST-006).
  Counter-based `ok()`/`fail()`, mktemp+trap cleanup, both fixture roots
  normalized with `pwd -P` immediately after creation (INV-030), no jq
  usage (INV-031 non-use declaration).
- `tests/hitl-wfi-terminal.tests.ps1` (new) -- PowerShell twin, ASCII-only,
  no BOM, LF endings (verified byte-level below), identical check IDs and
  counts. The HITL leg shells out to `bash` via a small NoBOM-encoded
  wrapper script (the driven template is bash-only); degrades to a named
  SKIP when `bash` is not on PATH (AC-017).
- `tests/run-all.sh` (edited) -- appended `tests/hitl-wfi-terminal.tests.sh`
  to the bash suite array (this suite's registration only).
- `tests/run-all.ps1` (edited) -- appended
  `tests/hitl-wfi-terminal.tests.ps1` to the pwsh suite array (this suite's
  registration only).
- `.github/workflows/test.yml` (edited) -- added the bash and pwsh
  hitl-wfi-terminal steps, following the loop-escalation step precedent
  (bash step invoked via `bash` explicitly for the exec-bit note; pwsh step
  direct).
- `CHANGELOG.md` (edited) -- `## Unreleased` entry citing #145, including
  the pwsh `COUNTER_FILE` export bug found and fixed during implementation
  (see Specification Differences).
- `specs/epic-159-pillar-a2/tasks.md` (edited) -- T-001 `Status:`
  transitions (Planned -> In Progress -> Implementation Complete) only.
- `specs/epic-159-pillar-a2/verification/T-001/{red-sh,green-sh,green-ps1}.log`
  (new) -- acceptance-first RED and GREEN run evidence.

## Tests Added Or Updated

- `tests/hitl-wfi-terminal.tests.sh` -- TEST-001 (never-reproducing CHECK,
  5 iterations, exit 0, terminal string), TEST-002 (CHECK true on
  iteration 3, immediate exit 1, RED canary -- mandatory per requirements.md
  Edge Cases), TEST-003.1..4 (WFI-audit sweep 0->1->2->3 plus the
  threshold-mutation negative self-check), TEST-004.1/.2 (gh-invocation
  grep self-check + Category construction proof), TEST-005 (WFI-010.md /
  WFI-011.md invariant + before/after SHA-256 equality, x2 each),
  TEST-006.1..4 (self-registration across run-all.sh/.ps1/test.yml,
  threshold-0 negative self-check, in-budget positive check).
- `tests/hitl-wfi-terminal.tests.ps1` -- twin with identical check IDs and
  counts (16 checks each twin).

## Outputs

One table row per produced file. Paths MUST be canonical repository-relative
paths: forward slashes only, with no absolute/drive prefix, backslash, empty
segment, `.` segment, or `..` segment. The independent evaluator launch
boundary authorizes changed/test/contract inputs ONLY from rows in exactly
this two-column, backtick-quoted form -- keep the shape byte-precise.

| Path | SHA-256 |
|---|---|
| `tests/hitl-wfi-terminal.tests.sh` | `512589151250c476701fe78a64f4e60398d875ddb5ac7739420c8c118ed4e3f9` |
| `tests/hitl-wfi-terminal.tests.ps1` | `0cd825c08114f1c572e64e7d65aa3c362405d372401a4a949fd17506429ac2dd` |
| `tests/run-all.sh` | `dc931236596aa9a1d1e4e9a44574254588acb6500e9bdab889621bbff79a177d` |
| `tests/run-all.ps1` | `2f2d4cc09a1fb196610737ffd95c7367a4c0c4b382f767cf645f7e1f640d173a` |
| `.github/workflows/test.yml` | `f47e113ceca875885b2437c73be6bb1aa73019262fd17835352ed823fb949ee3` |
| `CHANGELOG.md` | `193d9a19dda21a8230fefe9b9ed5c578b948af4c6ab2cad64a6503281faff53a` |
| `specs/epic-159-pillar-a2/tasks.md` | `06e4458d5915057700ff4ffaf91094fb0283be6fe4d5bbc5c1d8dfe28893469a` |
| `specs/epic-159-pillar-a2/verification/T-001/red-sh.log` | `eb5b6ea4d2b8f63bf12d6489ed6a0ee9e27c44f571a00fe12353711906bce21e` |
| `specs/epic-159-pillar-a2/verification/T-001/green-sh.log` | `1e247310444ca24b6449a829b070fffb939be7b24e718a196662a9ace53aabef` |
| `specs/epic-159-pillar-a2/verification/T-001/green-ps1.log` | `029163bad22da9ce6e5919495b2f0ca9d11084507dd4885ab5f12738fc237697` |

## Test Evidence

- **Test Command**: `bash tests/hitl-wfi-terminal.tests.sh` and `pwsh -NoProfile -ExecutionPolicy Bypass -File tests/hitl-wfi-terminal.tests.ps1`
- **Test Result**: PASS
- **Test Evidence Path**: specs/epic-159-pillar-a2/verification/T-001/green-sh.log

Acceptance-first evidence chain (logs under
`specs/epic-159-pillar-a2/verification/T-001/`):

- RED (`red-sh.log`, two parts):
  - Part 1 -- before either suite file existed: `ls`/direct-invocation both
    report "No such file or directory"; a registration grep across
    `tests/run-all.sh` / `tests/run-all.ps1` / `.github/workflows/test.yml`
    returns 0 matches.
  - Part 2 -- after authoring the suite content but before registering it
    in the three shared files: `hitl-wfi-terminal.tests.sh: 14 passed, 2
    failed, 0s elapsed`, exit 1. The only failures are TEST-006.1 and
    TEST-006.2 (self-registration); every other check (HITL leg,
    WFI-audit leg, construction proof, real-document smoke, runtime
    budget) already passes, because those checks drive already-correct
    real behavior (the template's own iteration cap; the two real WFI
    documents' already-compliant field values) rather than something this
    task builds.
- GREEN (after registering the suite in `tests/run-all.sh` /
  `tests/run-all.ps1` / `.github/workflows/test.yml`):
  - `green-sh.log` -- `hitl-wfi-terminal.tests.sh: 16 passed, 0 failed, 0s
    elapsed`, exit 0.
  - `green-ps1.log` -- `hitl-wfi-terminal.tests.ps1: 16 passed, 0 failed,
    1s elapsed`, exit 0.
- TEST-006 runtime budget: measured wall-clock printed in each summary line
  (0-1s on this host, far under the 300s budget); the threshold-0 negative
  self-check is `ok` inside both green runs.
- TEST-003.4 negative self-check (threshold mutation 3 -> 4): `ok` inside
  both green runs, proving the WFI-audit assertion is live.
- TEST-002 canary (CHECK true on iteration 3): `ok` inside both green runs,
  independently observing the RED branch so a broken `export -f CHECK`
  wiring cannot masquerade as TEST-001 passing (requirements.md Edge
  Cases).

## Iteration And Escalation

- **Task Attempt Count**: 1
- **Escalation Prior Tier**: None
- **Escalation Next Tier**: None
- **Escalation Failure Class**: None
- **Escalation Attempt Number**: None
- **Escalation Reason**: None

## Isolation Evidence

- **Run ID**: Not reserved -- this implementation was authored directly by
  a coder sub-agent in this session, without a separate identity-ledger
  reservation call for its own run.
- **Session ID**: 34212325-74b2-4d93-b1da-679455f12b8b
- **Agent Instance ID**: Not reserved (see Run ID note above).
- **Isolation Mode**: fresh-agent
- **Fallback Reason**: None
- **Handoff Reload Evidence Hash**: None

## Regression Tests Run

Full `bash tests/run-all.sh` was run once. It halted at the first failing
suite (`tests/gates.tests.sh`, `set -euo pipefail`), which pre-exists at
HEAD and is unrelated to this task: `T-007a.6`/`T-007a.8` pick up a
machine-local `~/.sdd/evidence-key` via the key-resolution fallback, so
"no key" cases find a key (identical to the pre-existing failure wave-1's
own T-001 report documented). Re-running with `HOME` pointed at an empty
directory (read-only workaround, no disk change) confirms the full gates
suite passes: 126 passed, 0 failed.

Because `run-all.sh` halts sequentially, it was not driven past
`gates.tests.sh` in a single run. Instead, targeted regression verification
was run directly against every suite this task's edits could plausibly
affect:

- `tests/check-placeholders.tests.sh` -- 8 passed, 0 failed.
- `tests/guard-ps1-ascii.tests.sh` -- 2 passed, 0 failed (this task's new
  `.ps1` is not in its `TARGETS`; that extension belongs to T-003/T-004).
- `tests/loop-inventory.tests.sh` -- 49 passed, 0 failed (its
  `CANONICAL_BASENAMES` array was deliberately not extended to include
  `hitl-wfi-terminal.tests` -- design.md Design Decisions -- and this run
  confirms that non-extension does not regress).
- `tests/loop-driver.tests.sh` -- 22 passed, 0 failed.
- `tests/loop-consistency.tests.sh` -- 24 passed, 0 failed.
- `tests/loop-escalation.tests.sh` -- 22 passed, 0 failed.
- `tests/second-approval-mask.tests.sh` -- 39 passed, 0 failed (its own
  `tests/run-all.sh` self-registration check, unaffected by this task's
  additive edit).
- `tests/workflow-state-ci-integration.tests.sh` -- passed.
- pwsh siblings `tests/loop-inventory.tests.ps1` (49 passed),
  `tests/loop-driver.tests.ps1` (15 passed),
  `tests/loop-consistency.tests.ps1` (9 passed),
  `tests/loop-escalation.tests.ps1` (21 passed) -- all 0 failed.

`bash tests/crlf-parity.tests.sh` (8 passed, 0 failed) and
`bash tests/constant-parity.tests.sh` (2 passed, 0 failed) both pass with
the new files present. `bash tests/validate-repository.sh` currently fails
with `workflow-state: epic-159-pillar-a2: stage-provenance: task reviewer
outputs or integrated summary contradict the final PASS`; this is a
pre-existing condition, verified via `git status`/`git diff` to already be
present (an uncommitted `reports/review-context/identity-ledger.json`
modification plus two untracked `pending-epic-159-pillar-a2-task-reviewer-*
-manifest.json` files) before this task's session began -- this task's own
edits (tasks.md `Status:` field, two new test files, three registration
edits) do not touch `reports/review-context/` and are unrelated to this
finding. Not fixed here (out of scope; `reports/review-context/` provenance
state is not a T-001 deliverable).

`.ps1` hygiene (this task's own twin, verified byte-level, independent of
the `guard-ps1-ascii.tests.sh` suite since it is not in that suite's
`TARGETS`): zero bytes outside `0x00-0x7F`, no UTF-8 BOM, no CR bytes.

## Specification Differences

- **pwsh `COUNTER_FILE` export bug (found and fixed in this session)** --
  the initial `tests/hitl-wfi-terminal.tests.ps1` draft set
  `COUNTER_FILE="..."` as a plain (non-exported) variable inside the
  bash wrapper script before `exec bash "<template>" 5`. Because `exec`
  replaces the process image and only exported environment variables carry
  across that replacement, the execed template process (which runs under
  `set -u`) saw `COUNTER_FILE` as unbound and errored inside `CHECK`,
  causing TEST-002 to red-out on iteration 1 instead of iteration 3 (a
  real bug caught by TEST-002's own canary requirement, not a design gap).
  Fixed by exporting the variable (`export COUNTER_FILE="..."`) before the
  `exec`; the bash twin's equivalent (`HITL_COUNTER_FILE`) already exported
  correctly from the start. No design or requirements change; this is
  purely an implementation-time bug caught by the suite's own acceptance
  criteria, recorded here as the task's own specification-difference note
  per the acceptance-first discipline.
- No other specification difference. The HITL leg, WFI-audit leg,
  construction proof, real-document smoke, and self-registration/runtime
  budget checks were implemented exactly as design.md's API/Contract Plan
  and Test Strategy describe, using the exact field-mutation formula and
  SKILL.md line citations design.md transcribes.

## Unresolved Items

- `tests/validate-repository.sh`'s pre-existing `stage-provenance`
  workflow-state failure (see Regression Tests Run) is outside T-001 scope;
  no action taken here. It predates this task's session (confirmed via
  `git status` at session start) and does not involve any file this task's
  Planned Files list names.
- The pre-existing `tests/gates.tests.sh` machine-local evidence-key
  pickup (T-007a.6/T-007a.8) is the same finding wave-1's own T-001 report
  already documented; no action taken here either.

## Quality Gate Focus

- AC-002 canary: confirm `ok` for TEST-002 in both green logs -- the
  suite is not green unless the reproduces-on-iteration-3 case is
  independently observed as RED, closing the exit-127 false-green gap
  requirements.md Edge Cases describes.
- AC-003 negative self-check: confirm `ok` for TEST-003.4 in both green
  logs (threshold mutated from 3 to 4, attempt-3 case now wrongly reports
  Not-Started, proving the check is live).
- AC-004 construction proof: confirm the gh-invocation grep pattern in
  TEST-004.1 is built from character codes at runtime (both twins), not
  embedded literally, so the check cannot trivially match its own
  definition line.
- AC-005 real-document invariant: confirm WFI-010.md (`Audit-Attempt: 1`)
  and WFI-011.md (no `Audit-Attempt:` field, parsed as 0) both satisfy the
  invariant, and that both real files' SHA-256 is asserted unchanged
  before vs. after the run inside the suite itself (not merely by this
  report's own external check).
- AC-006 self-registration: confirm the RED-to-GREEN differential recorded
  above (TEST-006.1/.2 fail before registration, pass after) as the
  concrete proof the self-registration check is not a vacuous always-pass.
- REQ-006/AC-019: `CHANGELOG.md` `## Unreleased` cites #145; README /
  USERGUIDE / workflow-guide / skill-reference / agent-capability-matrix /
  PLUGIN-CONTRACTS / troubleshooting / docs/contributor were grep-checked
  for `hitl` / `wfi-audit` mentions -- only `docs/skill-reference.md`'s
  existing `wfi-audit-cycle` skill-table row (unaffected description text)
  and an unrelated `docs/contributor/self-improvement-measurement-proposal.md`
  mention of "HITL" in a different context were found; no doc update
  required.

## Working Notes

- Real-document field values used for TEST-005 (verified by direct read,
  not assumed): `docs/workflow-improvements/WFI-010.md:46,48` --
  `Audit-Status: Human-Pending`, `Audit-Attempt: 1`;
  `docs/workflow-improvements/WFI-011.md:50` -- `Audit-Status:
  Human-Pending`, no `Audit-Attempt:` field at all (parsed as 0 by the
  absent-field rule).
- HITL template contract verified by direct read:
  `plugins/sdd-implementation/skills/diagnose/scripts/hitl-loop.template.sh:10`
  (`ITER="${1:-5}"`), line 18 (`read -r ans` prompt consumed once per
  iteration), line 25 (`if CHECK; then`), lines 26-27 (the `RED:` message
  and `exit 1`), lines 33-34 (the completion message and `exit 0`).
- WFI-audit rule transcribed from
  `plugins/sdd-quality-loop/skills/wfi-audit-cycle/SKILL.md:44-50`
  (precondition 4) and `SKILL.md:119-135,186-203` (STEP 4 / STEP 7).
- `guard-ps1-ascii.tests.sh`'s `TARGETS` array was deliberately NOT
  extended in this task (that belongs to T-003/T-004 per tasks.md Global
  Constraints); this task's own `.ps1` hygiene was instead verified
  directly (byte-level ASCII/BOM/CR scan, recorded above).
- `tests/loop-inventory.tests.sh`'s `CANONICAL_BASENAMES` array was
  deliberately NOT extended (design.md Design Decisions: this feature's
  suites self-register via their own grep, mirroring
  `tests/second-approval-mask.tests.sh`'s convention instead).

## Session Handoff

- **Current Status**: Implementation Complete
- **Next Action**: Independent quality-gate evaluation of T-001.
- **Unresolved Items**: See Unresolved Items above (both pre-existing,
  out-of-scope HEAD conditions; no T-001 action required).
