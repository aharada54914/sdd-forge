# human-copy staging (epic-194-a6-lite-integration)

**Relocated 2026-08-21** from `specs/epic-194-a6-lite-integration/human-copy/
README.md` to this path (this feature's own spec directory root). A README
is not one of AC-031's three control-file categories (`MANIFEST.sha256`,
the runner script, or a machine-readable target inventory the runner reads
-- requirements.md AC-031, investigation.md INV-020, "Payload file set,
defined"), so it was itself extraneous payload under the runner's own
recursive exact-set scan and had to be manually deleted from `human-copy/`
before every run (see "Why `.github/workflows/test.yml` is a declared
payload target" below for the related, now-resolved contradiction). This
file documents that directory's contents; it no longer lives inside it, so
staging it can never again trip the check it describes. `git log --follow`
on the old path recovers this file's history before the move.

## Canonical-path staging (current)

`specs/epic-194-a6-lite-integration/human-copy/` stages every protected-file
candidate this feature's tasks produce at its own real repository-relative
path, exactly as design.md's Protected-File Statement and tasks.md's
Planned Files describe. There is no `.PROPOSED`-suffix workaround there any
more: an earlier session recorded two blockers against this canonical
layout (R-10 guard suffix-match with no `human-copy/` staging carve-out;
`check-workflow-state.sh` not recognizing `Status: Blocked`) and staged the
same content under a non-suffix-matching `PROPOSED/*.PROPOSED` convention
as an interim workaround pending a human decision (tasks.md T-001 Blocker,
Addendum). Both premises were re-measured against the current tree and
found **false**:

- The installed guard (`sdd-hook-guard`, `plugins/sdd-quality-loop/scripts/
  sdd-hook-guard.py` and its `.js`/`.ps1` twins) carries an explicit
  `_HUMAN_COPY_STAGING_RE` staging exemption for any repository-relative
  path containing a `specs/<feature>/human-copy/` segment, confirmed by
  directly writing (and this session, overwriting) every file below via the
  `Write` tool with no denial.
- `check-workflow-state.sh`'s task-lifecycle status regex now accepts
  `Planned|In Progress|Blocked|Implementation Complete|Done` (line ~790),
  confirmed by a clean `workflow-state: ok` run against this feature.

That session therefore migrated every `PROPOSED/*.PROPOSED` file to its real
relative path under `human-copy/` and deleted the obsolete `PROPOSED/`
subtree and its own README. `git log --follow` on each destination path
recovers that migration history if needed.

## What's staged

Five protected targets, verified against `MANIFEST.sha256` and applied
together by `apply-protected-files.ps1` (T-001's own runner, both live
under `specs/epic-194-a6-lite-integration/human-copy/`): four
`plugins/sdd-lite/**` targets (T-002/T-003's own payload) plus
`.github/workflows/test.yml` (the CI-workflow candidate tasks.md's own
Protected Files item 3 commits this runner to applying "the same way it
applies the four payload files" -- as of 2026-08-21 an ordinary fifth
declared target, not a special-cased exception; see "Why
`.github/workflows/test.yml` is a declared payload target" below).

| Staged path | Real destination | SHA-256 |
|---|---|---|
| `plugins/sdd-lite/scripts/check-risk-upgrade.sh` | `plugins/sdd-lite/scripts/check-risk-upgrade.sh` | `742e6316efdefab5584af8899af7d4a97c0b92d7175ee5ddb47305e06c5df8a5` |
| `plugins/sdd-lite/scripts/check-risk-upgrade.ps1` | `plugins/sdd-lite/scripts/check-risk-upgrade.ps1` | `74a0e3bb6298bf66d9521036a92653c32a5feda0d6020f18bef436aa3553c42d` |
| `plugins/sdd-lite/references/risk-upgrade-policy.md` | `plugins/sdd-lite/references/risk-upgrade-policy.md` | `dab10b8b7ed6e6e762db2b09fc73454700c47cc825fec3161b35bb16ad3be674` |
| `plugins/sdd-lite/skills/lite-spec/SKILL.md` | `plugins/sdd-lite/skills/lite-spec/SKILL.md` | `798ed3fb2760a077ce0fef9e977e4e97934d9cf5daa430caa66273d76a4eca87` |
| `.github/workflows/test.yml` | `.github/workflows/test.yml` | `dc0cc24c18c7edda87c7591f4cc1f0938ea10c5c6788eeb986426c168141d2b0` |

These are T-002's (`check-risk-upgrade.sh`/`.ps1`, `risk-upgrade-policy.md`)
and T-003's (`lite-spec/SKILL.md`) real payload, each already TDD-tested
(`tests/check-risk-upgrade-*.tests.{sh,ps1}`, `tests/lite-spec-capability-
block.tests.{sh,ps1}`; RED/GREEN: `specs/epic-194-a6-lite-integration/
verification/T-002.{red,green}.log`, `.../T-003.{red,green}.log`). Staging
these four files at their canonical path does **not** by itself change
T-002/T-003's own `Status:` in `tasks.md` -- their own Done-When items
(HUMAN APPLY STEP, quality-gate PASS) remain to be completed separately.

The fifth entry, `.github/workflows/test.yml`, registers the CI steps
tasks.md's Protected Files item 3 requires for every task below that adds
a new `tests/*.tests.sh`/`.tests.ps1` pair. It is verified, copied, and
post-copy re-verified by the same runner and the same `MANIFEST.sha256`
entry mechanism as the other four -- no manual `cp`, no unverified
destination, no exemption from any check the other four targets get.

- `apply-protected-files.ps1` -- the runner itself (control file, excluded
  from its own payload-set comparison, investigation.md INV-020,
  requirements.md AC-031).
- `MANIFEST.sha256` -- the five-target manifest above (control file, same
  exclusion).

No other file belongs under this directory: the runner's own recursive
payload-set scan (`Get-PayloadFileSet`) treats every other staged path as
payload, and `Test-ExactSet` rejects anything outside the five targets
above before any copy is attempted.

## Why `.github/workflows/test.yml` is a declared payload target (resolved 2026-08-21)

An earlier revision of this README (then `human-copy/README.md`) documented
`.github/workflows/test.yml` as a fifth staged file deliberately excluded
from `MANIFEST.sha256` and the runner's `$Script:DeclaredTargets` -- fixed
at exactly four entries -- and instructed a human to apply it with a plain,
unverified `cp`, then delete both it and this README from `human-copy/`
*before* ever invoking the runner. `git log --follow` on this path recovers
that text.

Two independent cross-model reviews of T-001
(`specs/epic-194-a6-lite-integration/verification/T-001.panelist-
{anthropic,openai}.verdict.json`, both dated 2026-08-21) converged on the
same defect from two directions: tasks.md's own Protected Files item 3
already commits this runner to applying the CI-workflow candidate "the
same way it applies the four payload files", while the runner and
AC-010/AC-031 fixed the exact-set contract at exactly four targets --
`Test-ExactSet` therefore rejected the real staged directory (which always
also carried this file) as containing an undeclared fifth path, so the
delivered runner could never complete a single successful run against its
own real staged tree. The documented `rm -rf`/`cp` workaround left this
one file with no `MANIFEST.sha256` entry, no pre-copy hash check, no
atomic publish, and no post-copy re-verification -- precisely the bare,
unverified `cp` design.md's STRIDE row B5 exists to forbid.

This session resolved the contradiction by widening the contract to five
declared targets rather than narrowing item 3: `apply-protected-files.ps1`
now names `.github/workflows/test.yml` as an ordinary fifth entry in
`$Script:DeclaredTargets`, `MANIFEST.sha256` carries its digest, and
acceptance-tests.md's AC-010 was amended to match (the three-way exact-set
match, per-target hash verification, and post-copy re-verification are
unchanged in kind -- only the target count widened from four to five).
`Test-ExactSet` and every other check in the runner treat this file
identically to the other four; nothing about it is special-cased.

## Human-apply command sequence

```sh
cd <repository-root>

# Run the runner once for the full five-target payload. It verifies the
# declared/manifest/staged three-way exact set, each staged file's own
# sha256 against MANIFEST.sha256, copies via a handle-relative, no-follow
# native publisher, then re-verifies every installed file's own hash --
# .github/workflows/test.yml included, exactly like the other four
# targets. No separate manual step for it any more.
pwsh -NoProfile -ExecutionPolicy Bypass \
     -File specs/epic-194-a6-lite-integration/human-copy/apply-protected-files.ps1

# Re-run the full suites to confirm green against the real, now-live
# files (including this task's own suite, which by default already tests
# the canonical human-copy/apply-protected-files.ps1 runner, not a draft).
bash tests/run-all.sh
pwsh -NoProfile -File tests/run-all.ps1
```

## What this is NOT

- Not a guard circumvention: every file in `human-copy/` was staged with a
  direct `Write`/`git show ... >` to its own canonical
  `specs/epic-194-a6-lite-integration/human-copy/<repository-relative-path>`
  -- never to a live or deny-listed path.
- Not a claim that T-002/T-003 are `Done` -- their own `tasks.md` Status
  lines are unchanged by this migration; only T-001's own Blocked-premise
  re-measurement and Status flip were that earlier session's own scope,
  and only the five-target contract widening was this session's own scope.
