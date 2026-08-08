# T-002 TDD evidence — RED → GREEN, attribution, and discrepancies

Task: T-002 (Risk `high`, Required Workflow `tdd`). Single edited product file:
`plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md`.
Base commit: `6dc9cf09` (T-001's suite commit).

Both stages invoke the suites **directly**, never via `tests/run-all`
(T-005 has not landed; T-002's evidence must not depend on it):

```
bash tests/design-system-contract.tests.sh
pwsh -NoProfile -File tests/design-system-contract.tests.ps1
```

## Stage RED (before this task's edit)

| Log | Result |
|---|---|
| `red-sh.log` | PASS 78 / FAIL 43, exit 1 |
| `red-ps1.log` | PASS 9 / FAIL 42, exit 1 |

Both are **byte-identical** to T-001's landed baseline
(`../T-001/red-baseline-sh.log`, `../T-001/red-baseline-ps1.log`) — verified
by `diff`, empty output. The two runtimes differ in totals only because the
`.sh` suite runs one pass/fail counter over `DS-001..DS-017` **and**
`TEST-001..051`, while the `.ps1` suite's `$Script:TestPass` counter covers
only the 51 new assertions (its `DS-*` block prints `ok:` lines under a
separate mechanism).

## Stage GREEN — attribution hazard, and how it was resolved

**This worktree is shared with a concurrently-running T-003 agent.** Between
the RED capture and the GREEN capture, that agent modified — and then
committed as `29d0ae3d` — `sdd-bootstrap-interviewer/SKILL.md` and
`docs/workflow-guide.md`, which flipped TEST-035 and TEST-036 —
**T-003's scope, not T-002's**. A GREEN log taken from the live worktree
therefore over-credits this task. (`HEAD` was `6dc9cf09` when T-002 started
and `29d0ae3d` when it finished; the isolated tree below is built from
`6dc9cf09`, which is what makes the attribution exact.)

Two GREEN measurements are recorded, and the isolated one is authoritative:

| Log | Tree | Result |
|---|---|---|
| `green-sh-isolated.log` | `git archive HEAD` + **only** T-002's edited file | PASS 115 / FAIL 6 |
| `green-ps1-isolated.log` | same | PASS 46 / FAIL 5 |
| `green-sh.log` | live worktree (contains T-003's concurrent edits) | PASS 117 / FAIL 4 |
| `green-ps1.log` | same | PASS 48 / FAIL 3 |

## The flip is exactly this task's scope: 37 Test IDs, identical in both runtimes

`flipped-sh.txt` / `flipped-ps1.txt` (FAIL in RED → PASS in isolated GREEN).
The two Test-ID sets are identical — dual-runtime parity, BL-008:

TEST-001 · 002 · 003 · 004 · 005 · 006 · 007 · 008 · 009 · 010 · 011 · 012 ·
013 · 014 · 015 · 018 · 025 · 026 · 027 · 028 · 029 · 030 · 031 · 032 · 033 ·
034 · 041 · 042 · 043 · 044 · 045 · 046 · 047 · 048 · 049 · 050 · 051

**Nothing else flipped, in either direction.** `regressions-sh.txt` and
`regressions-ps1.txt` (PASS in RED ∩ FAIL in isolated GREEN) are both empty:
no previously-passing assertion regressed, including the seven pre-existing
`DS-006` literals (AC-025 / TEST-040, still PASS) and the six assertions this
task must preserve rather than produce — TEST-016, TEST-019, TEST-020,
TEST-022, TEST-023, TEST-040.

### The 6 remaining FAILs are all outside T-002's scope

| Test | Why it is correctly still red |
|---|---|
| `DS-010 impl count updated` | pre-existing failure at `HEAD`, present in T-001's RED baseline; unrelated to this feature |
| TEST-017 | T-004's staged lite-spec draft candidate does not exist yet |
| TEST-035 | T-003's site 3 (`sdd-bootstrap-interviewer/SKILL.md`) |
| TEST-036 | T-003's site 4 (`docs/workflow-guide.md`) |
| TEST-038 | T-004's draft + `MANIFEST.sha256` |
| TEST-039 | **designed red** — separately staged, human-applied CI patch (R-OQ-8 part 3, BL-005) |

The `.ps1` list is the same minus `DS-010`, which its counter does not cover.

## Byte-frozen sections — verified by diff, not by assertion

| Section | Before (HEAD) | After | Verdict |
|---|---|---|---|
| `## Capability Detection` (`:22-30`) | `e90dda59f812f4eaf50a4c393e2cb35bcc6804090e2d9e1f0825d5e859773060` | same | **byte-identical** (AC-013) |
| `## Ensure design-system/` (`:32-64`) | `e2f224938ca034c82a66484e65d85c13190f830928c04570d0ba2e412d38d82e` | same | **byte-identical** (BL-007) |

Extracted snapshots: `frozen-capability-detection.{before,after}.txt`,
`frozen-ensure-design-system.{before,after}.txt`; `diff` output empty for both.

`git diff -U0` reports exactly four changed hunks in the whole file, which is
the complete, intended edit surface:

```
@@ -3     +3      @@   frontmatter description: (REQ-007 site 1)
@@ -67,0  +68,6   @@   Loop: consent-after-capability-detection ordering statement
@@ -81,10 +87,119 @@   Loop: old steps 3-5 -> new steps 3-7 + Design-Source record section
@@ -97,2  +212,3  @@   Boundaries: old :97-98 (REQ-007 site 2)
```

BL-003's preserved Boundaries ranges were additionally diffed line-for-line
against `HEAD`: `:94-96` and `:99-111` are unchanged (`OK :94-96`,
`OK :99-111`). Loop steps 1 and 2 (old `:68-80`) sit outside every hunk.

## Discrepancies found — reported, not patched around

**No assertion in `tests/design-system-contract.tests.{sh,ps1}` contradicted
`design.md`.** Every T-002-scope assertion was satisfiable by text written
faithfully from `design.md:90-158`'s target shape plus tasks.md's Done-When.
The suite was not edited. Three items are recorded for the reviewer:

### D-1 — `design.md` contradicts itself on what a decline binds

- `design.md:105-106` (step 3c parenthetical): a decline "binds this scope
  for this session and is not a persisted refusal".
- `design.md:185` (Design-Source consequences): "It binds the current upload
  attempt only; the next one asks again."

These are not the same rule. `requirements.md` AC-026 rows 1–2,
`acceptance-tests.md` TEST-042, and `tasks.md` T-002 Done-When ("binding only
the attempted upload, not the scope") all agree with `:185`, and `:105-106`'s
reading is the exact failure mode AC-026 row 3 exists to reject ("silently
manufacturing the configuration-level control that #140 owns"). **Implemented
`:185`'s reading**, on the 3-to-1 majority of the normative documents. A
`design.md` amendment to `:105-106` is an orchestrator/spec decision, not
made here.

### D-2 — `design.md`'s seven-step shape silently drops the `Finalize` step

`design.md:90-158` presents the complete replacement for `## Loop` and omits
the pre-existing step 5, `Finalize` (old `SKILL.md:88-90`) — the **only**
place `design-sync-loop` specifies `Mockup-Status: Approved (<date>)`.
Re-verified at implementation start that the statement is load-bearing
elsewhere:

- `plugins/sdd-lite/skills/lite-spec/SKILL.md:64` — the lite profile records
  `Design-Source` / `Mockup-Status` (a **protected** file this task cannot
  edit);
- `docs/superpowers/plans/2026-07-02-design-iteration-lane.md:38` — the
  skill's stated contract: "records `Design-Source` and `Mockup-Status`
  sections".

Implementing `design.md` literally would delete a contract statement no
Baseline Constraint sanctions removing, and no TEST would have caught it.
**Resolution:** the numbered list is exactly the seven steps `design.md`
specifies; `Finalize` is preserved verbatim as an unnumbered trailing
paragraph after step 7, in the same position and form `design.md` itself uses
for its own unnumbered trailing "Local review is OPTIONAL" paragraph. No
assertion reads it. Flagged as a deliberate, minimal deviation from the
literal target block.

### D-3 — citation drift (WFI-011 class)

`design.md:190` and `:217` cite `docs/THREAT-MODEL.md:12` for "agent
self-reports are NOT Trusted"; the line is actually `:11` (`:12` is
"In-repo files"). Immaterial to any Done-When. The skill text cites the
document by name and no line number, so it cannot go stale the same way.
All `SKILL.md` line citations in tasks.md (`:3`, `:18-20`, `:22-30`,
`:32-64`, `:66-90`, `:92-111`, `:94-95`, `:96`, `:97-98`, `:99-111`) were
re-verified against the live file at implementation start and were **all
accurate**.

## Authoring hazard worth recording for T-003/T-004

`loop_line_of 'Resolve egress consent|Consent Resolution'` is
case-**insensitive** in both runtimes (`grep -n -iE`; PowerShell `-match`).
Any prose containing the words "consent resolution" earlier in `## Loop` than
step 3 would be picked up as the consent step's position and would break
TEST-010's ordering parse against an otherwise conforming file. The AC-013
ordering sentence added before step 1 is therefore worded "Egress consent is
resolved at step 3", not "Consent resolution runs after…". The same trap
applies to `\bPush\b` (TEST-010's third anchor): the word "push" must not
appear in `## Loop` before step 6.

## Scope discipline

Files written by this task: `design-sync-loop/SKILL.md` and this verification
directory. No test file, no frozen spec document, no T-003/T-004 target, and
no `git add` / `git commit` was performed.
