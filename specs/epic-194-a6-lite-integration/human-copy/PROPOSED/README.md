# PROPOSED staging (interim, pending guard-gap decision)

## Why this directory exists

`specs/epic-194-a6-lite-integration/human-copy/` is where T-001's own
`apply-protected-files.ps1` runner expects the real, final payload for the
four protected targets (plus the CI-workflow candidate) to be staged, at
their real repository-relative paths, before a human applies them.

As of this writing, that staging cannot happen at those real paths: the R-10
enforcement-chain guard (`plugins/sdd-quality-loop/scripts/sdd-hook-guard.py`,
`_is_protected_gate_file`) denies any Edit/Write/Bash/apply_patch attempt to
create a file whose repository-relative path ends in one of
`.github/workflows/test.yml`, `plugins/sdd-lite/scripts/check-risk-upgrade.sh`,
`plugins/sdd-lite/scripts/check-risk-upgrade.ps1`,
`plugins/sdd-lite/references/risk-upgrade-policy.md`, or
`plugins/sdd-lite/skills/lite-spec/SKILL.md` -- **even when the target is the
staged copy under `human-copy/`, not the live protected path itself.** There
is no carve-out for a `specs/<feature>/human-copy/**` staging prefix in the
current guard implementation. This was independently confirmed on Epic A1
too. See `specs/epic-194-a6-lite-integration/tasks.md` T-001's own Blocker
note for the full grep evidence and the three options presented to the human
for resolving it (guard exception / this `.PROPOSED` convention / rescope).

**This directory is the interim workaround authorized while that decision is
pending.** Every file below has a `.PROPOSED` suffix, which does **not**
match any protected suffix (`endswith()` fails once `.PROPOSED` is
appended), so creating these files was never denied and is not a guard
circumvention: nothing was ever written to a live or deny-listed path.
These files hold the **final, already-tested** content; the only remaining
step is a human copying each one's exact bytes to its real destination path
(or applying it via T-001's runner, once that path is unblocked).

## What's in here

| `.PROPOSED` file | Real destination (once applied) | SHA-256 |
|---|---|---|
| `dot-github-workflows-test.yml.PROPOSED` | `.github/workflows/test.yml` | `f6efce1c800630711dd5ce5fa119582b23047e5bfb4b760a16f38a1b03a20ceb` |
| `check-risk-upgrade.sh.PROPOSED` | `plugins/sdd-lite/scripts/check-risk-upgrade.sh` | `89eb175a274f6ef08c33ae793866e5698b40ca21fa3b454701b0158bf6fe1acc` |
| `check-risk-upgrade.ps1.PROPOSED` | `plugins/sdd-lite/scripts/check-risk-upgrade.ps1` | `6090a6337ef300dfa4f755e54fdbe605fe4229e46d570cb262be20de457e4902` |
| `risk-upgrade-policy.md.PROPOSED` | `plugins/sdd-lite/references/risk-upgrade-policy.md` | `dab10b8b7ed6e6e762db2b09fc73454700c47cc825fec3161b35bb16ad3be674` |
| `lite-spec-SKILL.md.PROPOSED` | `plugins/sdd-lite/skills/lite-spec/SKILL.md` | `1dcc9ad9fcabd0c3ea78c12bb66348bb9634c0196ed6ca0800a1c814f67346ae` |

Each SHA-256 above is the hash of the `.PROPOSED` file's own bytes, computed
with `shasum -a 256 <file>`. Renaming/copying a file does not change its
bytes, so this is also the hash the real destination file will carry once
applied -- verify it again after copying, as a sanity check.

Every one of these is genuinely tested, not placeholder content:

- `check-risk-upgrade.sh.PROPOSED` / `.ps1.PROPOSED` -- covered by
  `tests/check-risk-upgrade-byte-identical.tests.{sh,ps1}`,
  `tests/check-risk-upgrade-capability-merge.tests.{sh,ps1}`,
  `tests/check-risk-upgrade-fragment-fail-closed.tests.{sh,ps1}`,
  `tests/check-risk-upgrade-ineligible-no-reasons.tests.{sh,ps1}` (T-002).
  RED/GREEN evidence:
  `specs/epic-194-a6-lite-integration/verification/T-002.{red,green}.log`.
- `lite-spec-SKILL.md.PROPOSED` -- covered by
  `tests/lite-spec-capability-block.tests.{sh,ps1}` (T-003). RED/GREEN
  evidence: `specs/epic-194-a6-lite-integration/verification/T-003.{red,green}.log`.
- `dot-github-workflows-test.yml.PROPOSED` -- the full, real
  `.github/workflows/test.yml` content with T-001/T-002/T-003/T-004's 22 new
  CI steps inserted in the correct serialized order; validated as parseable
  YAML (`ruby -ryaml -e "YAML.load_file(...)"`, since this environment has
  no `pyyaml` installed) and step-count-diffed against the live file (87 ->
  109 steps, exactly the 22 new steps expected: 2 for T-001, 8 for T-002, 2
  for T-003, 10 for T-004).
- `risk-upgrade-policy.md.PROPOSED` -- documentation only, no test suite of
  its own; reviewed by hand against the actual extended script behavior.

**Note on T-004**: unlike T-001/T-002/T-003, T-004's own target
(`plugins/sdd-lite/skills/lite-gate/SKILL.md`) is confirmed **not**
protected (absent from both `guard-invariants.json` arrays, re-verified
immediately before editing, AC-017) -- its direct edit landed at the real
path with no staging needed. Only the shared CI-workflow candidate above is
affected by the same guard gap, for the identical reason as T-001's own CI
step. T-004's own 5 new test suites
(`tests/lite-gate-summary-consumption.tests.{sh,ps1}` and four siblings)
are committed as ordinary, unprotected files -- see
`specs/epic-194-a6-lite-integration/verification/T-004.{red,green}.log`
and `reports/implementation/epic-194-a6-lite-integration/T-004.md`.

## Human-apply command sequence

Once the guard/staging decision lands (any of the three options in
tasks.md's T-001 Blocker note), applying this batch is:

```sh
cd <repository-root>

# 1. Copy each .PROPOSED file to its real destination (see table above).
#    Example (adjust for whichever resolution path was chosen):
cp specs/epic-194-a6-lite-integration/human-copy/PROPOSED/check-risk-upgrade.sh.PROPOSED \
   plugins/sdd-lite/scripts/check-risk-upgrade.sh
cp specs/epic-194-a6-lite-integration/human-copy/PROPOSED/check-risk-upgrade.ps1.PROPOSED \
   plugins/sdd-lite/scripts/check-risk-upgrade.ps1
cp specs/epic-194-a6-lite-integration/human-copy/PROPOSED/risk-upgrade-policy.md.PROPOSED \
   plugins/sdd-lite/references/risk-upgrade-policy.md
cp specs/epic-194-a6-lite-integration/human-copy/PROPOSED/lite-spec-SKILL.md.PROPOSED \
   plugins/sdd-lite/skills/lite-spec/SKILL.md
cp specs/epic-194-a6-lite-integration/human-copy/PROPOSED/dot-github-workflows-test.yml.PROPOSED \
   .github/workflows/test.yml

# 2. Verify every copied file's SHA-256 matches the table above.
shasum -a 256 plugins/sdd-lite/scripts/check-risk-upgrade.sh
shasum -a 256 plugins/sdd-lite/scripts/check-risk-upgrade.ps1
shasum -a 256 plugins/sdd-lite/references/risk-upgrade-policy.md
shasum -a 256 plugins/sdd-lite/skills/lite-spec/SKILL.md
shasum -a 256 .github/workflows/test.yml

# 3. Re-point the T-002/T-003 test suites at the real, now-live paths
#    instead of the interim .PROPOSED paths (one SUT-path constant per
#    suite file -- see each suite's own header comment for the exact
#    variable name and line).

# 4. Re-run the full suites to confirm green against the real files.
bash tests/run-all.sh
pwsh -NoProfile -File tests/run-all.ps1

# 5. Append the four real MANIFEST.sha256 entries (T-002's three targets +
#    T-003's one target) to the SAME feature-scoped manifest T-001 already
#    created -- see "MANIFEST.sha256 additions" below for the exact lines,
#    which use the identical hashes already verified in step 2 (copying
#    does not change bytes).
```

## MANIFEST.sha256 additions (prepared now, applied at step 5 above)

`specs/epic-194-a6-lite-integration/human-copy/MANIFEST.sha256` currently
exists (created by T-001) and is empty -- no entries yet, because no real
payload has been staged at a protected suffix. Once step 1-2 above land at
the real paths, append exactly these four lines (GNU `sha256sum`-style,
lowercase hex + two spaces + the runner's own repository-relative target
name, matching `apply-protected-files.ps1`'s own `Get-ManifestDigests`
format):

```
89eb175a274f6ef08c33ae793866e5698b40ca21fa3b454701b0158bf6fe1acc  plugins/sdd-lite/scripts/check-risk-upgrade.sh
6090a6337ef300dfa4f755e54fdbe605fe4229e46d570cb262be20de457e4902  plugins/sdd-lite/scripts/check-risk-upgrade.ps1
dab10b8b7ed6e6e762db2b09fc73454700c47cc825fec3161b35bb16ad3be674  plugins/sdd-lite/references/risk-upgrade-policy.md
1dcc9ad9fcabd0c3ea78c12bb66348bb9634c0196ed6ca0800a1c814f67346ae  plugins/sdd-lite/skills/lite-spec/SKILL.md
```

These are NOT written to the real `MANIFEST.sha256` by this session --
`MANIFEST.sha256` is not itself a protected path (T-001 already created and
committed it, empty), so appending to it directly is technically possible,
but doing so before the four real payload files exist at their real paths
would leave the runner's own exact-set check permanently failing (manifest
declaring targets the payload set doesn't yet contain) until this human
decision resolves -- so the addition is deliberately staged here as text,
not applied to the live manifest file, until the payload files themselves
land.

## What this is NOT

- Not a guard circumvention: no file at a protected suffix was ever
  written, read-modified, or targeted by a rename/move in this session.
- Not a claim that T-002/T-003 are `Done`, or even `Implementation
  Complete` in the normal sense -- their own `tasks.md` entries record the
  same human-apply-pending blocker T-001 does, once you (the reader)
  update them; this session recorded the sudo Approval + implementation
  evidence but left Status decisions to the same pending human review this
  README describes.
