# T-003 — Reconcile the remaining live per-upload statements: acceptance-first mapping and RED baseline

Written before either edit below was made, per `Required Workflow:
acceptance-first` (tasks.md T-003). Every `file:line` cited was re-verified
against the live tree at the time this document was authored, not carried
forward from tasks.md's own citations (WFI-011 discipline;
`plugins/sdd-quality-loop/references/risk-classification-policy.md` sweep
instruction).

## Scope

Two sites reconciled, two sites left alone:

| # | Site | Disposition | Task Done-When item |
|---|---|---|---|
| 3 | `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md:84` | reconcile | item 1 |
| — | `SKILL.md:86-87` (`ds_profile: none` guarantee) | **byte-unchanged** | item 2 |
| 4 | `docs/workflow-guide.md:224` | reconcile | item 3 |
| — | `.../references/claude-design-workflow.md` | **read only, expected no-op** | item 4 |
| 5 | `CHANGELOG.md:1301` | **not touched** | item 5 |

Line-number re-verification at authoring time: `SKILL.md:84` and `:86-87`
confirmed exact (`grep -n` against the live file); `docs/workflow-guide.md`'s
per-upload phrase confirmed at `:224` (`grep -n '都度人間承認'`), inside the
`### 3.1b` section (`:216`) before `### 3.2` (`:230`).

## Acceptance-first mapping: TEST-ID -> assertion -> target -> planned edit

| Test ID | AC | Target | Assertion (from `tests/design-system-contract.tests.sh`) | Planned edit |
|---|---|---|---|---|
| TEST-021 | AC-014 | `claude-design-workflow.md` | `CDW` contains "does not automatically inspect, upload, or retain" **and** flattened text contains no "consent" | **none** — file read in full (`:1-72`), already satisfies both halves; edit would be an unrequired change to a file design.md calls "Existing (expected no-op)" |
| TEST-024 | AC-016 | `sdd-bootstrap-interviewer/SKILL.md` | `BSI` (whole file, `grep -F`) contains "no artifacts and no" **and** "further design-system questions" | **none** at `:86-87` — the site 3 edit at `:84` sits two lines above and must not touch this text (BL-002/BL-003, AC-016) |
| TEST-035 | AC-021 site 3 | `sdd-bootstrap-interviewer/SKILL.md` UI bullet (`section_between` `'^- When the target is a UI application'` .. `'^- Otherwise ask whether the human has a local mockup'`) | bullet section is non-empty; flattened text does **not** contain the runtime-assembled `per-up`+`load` literal; flattened text matches (case-insensitive) `per-feature` or `feature.{0,15}(and\|AND).{0,15}session` | reword `:84` clause from "manages per-upload human approval" to state per-feature/session consent, without introducing the literal substring `per-upload` anywhere in the bullet (`:76-87`) |
| TEST-036 | AC-021 site 4 | `docs/workflow-guide.md` `### 3.1b` section (`section_between` `'^### 3\.1b '` .. `'^### 3\.2 '`) | section flattened text does **not** contain the runtime-assembled `都度人間` + `承認` literal; flattened text contains `セッション` | reword the `:223-224` clause "アップロードは都度人間承認" to a per-feature/session Japanese phrasing that is not a direct translation of the English sites and includes `セッション` |
| TEST-037 | AC-022 | `CHANGELOG.md`, regression (negative) | SHA-256 over the anchor line (`design-sync-loop\``) plus the following 4 lines equals the recorded hash `4d911e7a8adc86e9ea79adfe1bec5c6e26b62c939a6f0dde517d204a2ef410c8` | **none** — `CHANGELOG.md` is not opened for writing by this task under any circumstance (REQ-007 site 5, BL-006) |

## Byte-unchanged verification anchors (captured pre-edit)

Recorded here so the post-edit report can cite a diff against a known
baseline rather than assertion alone.

- `sed -n '86,87p' plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md \| shasum -a 256` =
  `f5c0abc5acd6c20f14afff3799559ebd3cc7c20db8a677dafb73f7648a744521`
- `git hash-object plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/references/claude-design-workflow.md` =
  `f9bddcd2bdf2fa5c612b931b4db2af94b5ff2789`
- `git hash-object CHANGELOG.md` = `c5148909924f687f4880a01f0c4b5a0d310488e0`
- Pre-edit `git hash-object` of the two edited files, for reference:
  - `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md` =
    `c3adc68681c4fabf0ebad6d2f6ef4af299af5327`
  - `docs/workflow-guide.md` = `705e94a633df9ae0626bb681487c138131d15350`

## RED baseline (this task's subset), captured before either edit

`bash tests/design-system-contract.tests.sh` and
`pwsh -NoProfile -File tests/design-system-contract.tests.ps1`, both run
directly against the unedited tree:

| Test ID | `.sh` | `.ps1` |
|---|---|---|
| TEST-021 | PASS (pre-existing, unaffected) | PASS (pre-existing, unaffected) |
| TEST-024 | PASS (pre-existing, unaffected) | PASS (pre-existing, unaffected) |
| TEST-035 | FAIL | FAIL |
| TEST-036 | FAIL | FAIL |
| TEST-037 | PASS (pre-existing, unaffected) | PASS (pre-existing, unaffected) |

Full logs: `red-baseline-sh.log`, `red-baseline-ps1.log` (this directory).
Both runs exit non-zero overall (43-44 unrelated FAILs each, all belonging to
T-002's and T-004's still-unlanded scope — `TEST-001..020`, `TEST-025..034`
except this task's own `TEST-035`/`TEST-036`, `TEST-038`, `TEST-039`
designed-red, `TEST-041..051`, plus the pre-existing, unrelated `DS-010`
failure). None of those is this task's concern; this task's Done-When only
requires TEST-021/024/035/036/037 to behave as this table states, with no
regression to any assertion that was already passing.

## Expected GREEN state after this task's edits

TEST-035 and TEST-036 flip FAIL -> PASS in both runtimes. TEST-021,
TEST-024 and TEST-037 remain PASS, unchanged, in both runtimes — evidence
that the `:86-87` adjacency (AC-016) and the untouched `CHANGELOG.md`
(AC-022) and `claude-design-workflow.md` (AC-014) survived the edit intact.

## Actual result (post-edit, both runtimes)

`bash tests/design-system-contract.tests.sh` and
`pwsh -NoProfile -File tests/design-system-contract.tests.ps1`, re-run after
both edits:

| Test ID | `.sh` before -> after | `.ps1` before -> after |
|---|---|---|
| TEST-021 | PASS -> PASS | PASS -> PASS |
| TEST-024 | PASS -> PASS | PASS -> PASS |
| TEST-035 | FAIL -> **PASS** | FAIL -> **PASS** |
| TEST-036 | FAIL -> **PASS** | FAIL -> **PASS** |
| TEST-037 | PASS -> PASS | PASS -> PASS |

Whole-suite totals (this feature's TEST-001..051 plus the pre-existing
`DS-001..017`/`design-system contract tests passed` legacy block):

- `.sh`: `PASS: 78 / FAIL: 43` -> `PASS: 80 / FAIL: 41` (net +2/-2, exactly
  TEST-035 and TEST-036; every other Test ID's verdict is unchanged, verified
  by diffing the full sorted PASS-line set before and after — no line other
  than TEST-035/TEST-036 was added, none removed).
- `.ps1`: `PASS: 9 / FAIL: 42` -> `PASS: 11 / FAIL: 40` (net +2/-2, same two
  Test IDs, same diff method).
- Neither runtime's overall exit code is 0 (both still exit 1): expected,
  because T-002 and T-004 have not landed in this working tree — every
  remaining FAIL belongs to their scope (`TEST-001..020` except this task's
  four, `TEST-025..034`, `TEST-038`, `TEST-039` designed-red, `TEST-041..051`)
  or to a pre-existing, unrelated `DS-010` failure noted in the RED baseline.
  None of those is in this task's Done-When.

Full logs: `green-evidence-sh.log`, `green-evidence-ps1.log` (this
directory).

## Byte-unchanged / no-op verification (post-edit)

- `sed -n '87,88p' plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md \| shasum -a 256` =
  `f5c0abc5acd6c20f14afff3799559ebd3cc7c20db8a677dafb73f7648a744521` — **identical**
  to the pre-edit hash of the same two-line guarantee (now at `:87-88`
  because the `:84` edit added one line above it; content, not line number,
  is what BL-002/BL-003/AC-016 requires — confirmed unchanged by `git diff`
  showing no `+`/`-` on those lines).
- `git diff -- plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/references/claude-design-workflow.md` = empty (no-op, as planned).
- `git diff -- CHANGELOG.md` = empty (untouched, as required — REQ-007 site 5, BL-006, AC-022).
- `git diff -- plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md` = empty (T-002's file, not touched by this task).
- `git diff -- tests/` = empty (read-only per task instructions).

## Files edited by this task

- `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md` — one
  clause at (pre-edit) `:84` reworded; `git diff --numstat`: `3 insertions(+),
  2 deletions(-)`.
- `docs/workflow-guide.md` — one clause at (pre-edit) `:224` reworded;
  `git diff --numstat`: `3 insertions(+), 2 deletions(-)`.
