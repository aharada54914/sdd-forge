# human-copy staging (epic-194-a6-lite-integration)

## Canonical-path staging (current)

This directory stages every protected-file candidate this feature's tasks
produce at its own real repository-relative path, exactly as design.md's
Protected-File Statement and tasks.md's Planned Files describe. There is no
`.PROPOSED`-suffix workaround here any more: an earlier session recorded two
blockers against this canonical layout (R-10 guard suffix-match with no
`human-copy/` staging carve-out; `check-workflow-state.sh` not recognizing
`Status: Blocked`) and staged the same content under a non-suffix-matching
`PROPOSED/*.PROPOSED` convention as an interim workaround pending a human
decision (tasks.md T-001 Blocker, Addendum). Both premises were
re-measured against the current tree and found **false**:

- The installed guard (`sdd-hook-guard`, `plugins/sdd-quality-loop/scripts/
  sdd-hook-guard.py` and its `.js`/`.ps1` twins) carries an explicit
  `_HUMAN_COPY_STAGING_RE` staging exemption for any repository-relative
  path containing a `specs/<feature>/human-copy/` segment, confirmed by
  directly writing (and this session, overwriting) every file below via the
  `Write` tool with no denial.
- `check-workflow-state.sh`'s task-lifecycle status regex now accepts
  `Planned|In Progress|Blocked|Implementation Complete|Done` (line ~790),
  confirmed by a clean `workflow-state: ok` run against this feature.

This session therefore migrated every `PROPOSED/*.PROPOSED` file to its real
relative path under this directory (see "What's staged" below) and deleted
the obsolete `PROPOSED/` subtree and its own README. `git log --follow` on
each destination path recovers the migration history if needed.

## What's staged

Four protected `plugins/sdd-lite/**` targets, verified against
`MANIFEST.sha256` below and applied together by `apply-protected-files.ps1`
(T-001's own runner, this directory):

| Staged path | Real destination | SHA-256 |
|---|---|---|
| `plugins/sdd-lite/scripts/check-risk-upgrade.sh` | `plugins/sdd-lite/scripts/check-risk-upgrade.sh` | `89eb175a274f6ef08c33ae793866e5698b40ca21fa3b454701b0158bf6fe1acc` |
| `plugins/sdd-lite/scripts/check-risk-upgrade.ps1` | `plugins/sdd-lite/scripts/check-risk-upgrade.ps1` | `6090a6337ef300dfa4f755e54fdbe605fe4229e46d570cb262be20de457e4902` |
| `plugins/sdd-lite/references/risk-upgrade-policy.md` | `plugins/sdd-lite/references/risk-upgrade-policy.md` | `dab10b8b7ed6e6e762db2b09fc73454700c47cc825fec3161b35bb16ad3be674` |
| `plugins/sdd-lite/skills/lite-spec/SKILL.md` | `plugins/sdd-lite/skills/lite-spec/SKILL.md` | `1dcc9ad9fcabd0c3ea78c12bb66348bb9634c0196ed6ca0800a1c814f67346ae` |

These are T-002's (`check-risk-upgrade.sh`/`.ps1`, `risk-upgrade-policy.md`)
and T-003's (`lite-spec/SKILL.md`) real payload, each already TDD-tested
(`tests/check-risk-upgrade-*.tests.{sh,ps1}`, `tests/lite-spec-capability-
block.tests.{sh,ps1}`; RED/GREEN: `specs/epic-194-a6-lite-integration/
verification/T-002.{red,green}.log`, `.../T-003.{red,green}.log`). Staging
these four files at their canonical path does **not** by itself change
T-002/T-003's own `Status:` in `tasks.md` -- their own Done-When items
(HUMAN APPLY STEP, quality-gate PASS) remain to be completed separately.

A fifth staged file, `.github/workflows/test.yml` below, is a **CI-workflow
candidate**, not part of the four-target payload `apply-protected-files.ps1`
verifies -- see "Why `.github/workflows/test.yml` is NOT in MANIFEST.sha256"
below for why, and apply it via a plain `cp` (not the runner).

- `apply-protected-files.ps1` -- the runner itself (control file, excluded
  from its own payload-set comparison, investigation.md INV-020).
- `MANIFEST.sha256` -- the four-target manifest above (control file, same
  exclusion).
- `.github/workflows/test.yml` -- the staged CI-registration candidate.
  design.md's "Payload file set, defined" text (investigation.md INV-020)
  names only the two files above as controls, so this file is **not**
  excluded from the runner's own recursive payload-set scan and is never
  one of the runner's four `$Script:DeclaredTargets` -- it must be applied
  by a plain `cp`, never through the runner, and removed from this
  directory before the runner is ever invoked (see "Why ... is NOT in
  MANIFEST.sha256" and the human-apply sequence below).
- `README.md` (this file) -- likewise not a control file by INV-020's
  definition; remove it from this directory too before invoking the
  runner (human-apply sequence, step 2).

## Why `.github/workflows/test.yml` is NOT in MANIFEST.sha256

design.md's Protected-File Statement fixes the runner's own exact-set
contract to exactly the four `plugins/sdd-lite/**` targets named above
(`risk-upgrade-policy.md`, `check-risk-upgrade.sh`, `check-risk-upgrade.
ps1`, `lite-spec/SKILL.md`) -- it does not name `.github/workflows/test.yml`
as a fifth payload target, even though one paragraph of tasks.md's own
Protected Files section (item 3) says the runner "applies this staged
candidate the same way it applies the four payload files." A prior
implementation report (`reports/implementation/epic-194-a6-lite-integration/
T-001.md`, "Four-target / fifth-target contradiction") already recorded this
self-contradiction and recommended the narrower, four-target interpretation
until a formal spec amendment -- this session keeps that recommendation
unchanged. Concretely, this means:

- `apply-protected-files.ps1`'s `$Script:DeclaredTargets` stays at exactly
  four entries; `MANIFEST.sha256` stays at exactly four entries.
- The runner's `Get-PayloadFileSet` enumerates the **entire** `human-copy/`
  tree recursively (everything except `MANIFEST.sha256` and
  `apply-protected-files.ps1` itself) when deciding what counts as
  "payload" for the exact-set check. Because of this, a human must apply
  (or otherwise remove) `.github/workflows/test.yml` from this directory
  **before** ever invoking the runner for the four-target payload above --
  otherwise `Test-ExactSet` will correctly reject it as "an undeclared path
  outside the four-target set." This is a known, disclosed operational
  ordering requirement, not a runner defect: the alternative (silently
  widening the exact-set contract to include CI-workflow content) would be
  a security-relevant contract change on a `Risk: high` / `Security-
  Sensitive: true` task that only a follow-up spec revision should make.

## Human-apply command sequence

```sh
cd <repository-root>

# 1. Apply the CI-workflow candidate FIRST, with a plain diff-verified copy
#    (never through the runner -- see above). Review the diff before copying;
#    it is additive-only (22 new steps for T-001..T-004, ordered T-001 ->
#    T-002 -> T-003 -> T-004) against whatever .github/workflows/test.yml
#    happens to be live at apply time.
diff .github/workflows/test.yml \
     specs/epic-194-a6-lite-integration/human-copy/.github/workflows/test.yml
cp specs/epic-194-a6-lite-integration/human-copy/.github/workflows/test.yml \
   .github/workflows/test.yml

# 2. Remove the now-applied CI-workflow candidate AND this README from this
#    staging tree so the runner's own exact-set scan (step 3) does not see
#    either as an undeclared payload path -- Get-PayloadFileSet enumerates
#    the ENTIRE human-copy/ tree recursively except MANIFEST.sha256 and
#    apply-protected-files.ps1 themselves (investigation.md INV-020's
#    control-file definition covers only those two).
rm -rf specs/epic-194-a6-lite-integration/human-copy/.github
rm -f specs/epic-194-a6-lite-integration/human-copy/README.md

# 3. Run the runner for the four-target sdd-lite payload. It verifies the
#    declared/manifest/staged three-way exact set, each staged file's own
#    sha256 against MANIFEST.sha256, copies via a handle-relative, no-follow
#    native publisher, then re-verifies every installed file's own hash.
pwsh -NoProfile -ExecutionPolicy Bypass \
     -File specs/epic-194-a6-lite-integration/human-copy/apply-protected-files.ps1

# 4. Re-run the full suites to confirm green against the real, now-live
#    files (including this task's own suite, which by default already tests
#    the canonical human-copy/apply-protected-files.ps1 runner, not a draft).
bash tests/run-all.sh
pwsh -NoProfile -File tests/run-all.ps1
```

## What this is NOT

- Not a guard circumvention: every file in this tree was staged with a
  direct `Write`/`git show ... >` to its own canonical
  `specs/epic-194-a6-lite-integration/human-copy/<repository-relative-path>`
  -- never to a live or deny-listed path.
- Not a claim that T-002/T-003 are `Done` -- their own `tasks.md` Status
  lines are unchanged by this migration; only T-001's own Blocked-premise
  re-measurement and Status flip are this session's own scope.
