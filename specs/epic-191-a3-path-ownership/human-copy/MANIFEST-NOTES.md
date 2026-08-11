# epic-191-a3-path-ownership — human-copy staging notes

`MANIFEST.sha256` in this directory is a **machine-readable GNU
`sha256sum`-format file with no comment lines**, because
`apply-human-copy.sh --manifest` rejects a `#` line outright: `parse_manifest`
skips only *empty* lines, so a comment fails the `<64-hex>  <path>` shape check
and the tool exits 13 `MANIFEST_INVALID` (verified empirically, 2026-08-11).
That is also the convention every publisher-consumed manifest in this repo
already follows (`epic-136-phase2-gates`, `epic-159-pillar-c`/`-d`,
`epic-189-a1-project-context`, `epic-192-a4-facet-manifest`,
`quality-loop-fixes`). This file carries the prose instead.

## How to apply

The manifest's paths are **destinations relative to the repo root**. For each
entry, from the repo root:

```sh
cp specs/epic-191-a3-path-ownership/human-copy/<path> <path>
shasum -a 256 -c specs/epic-191-a3-path-ownership/human-copy/MANIFEST.sha256
```

The `shasum -c` run verifies the LIVE files after application. Every hash in
the manifest was verified against the staged file it names; nothing is recorded
for a file that was not produced.

## Superseded: the "blocked by the write guard" finding

**The previous revision of `MANIFEST.sha256` carried zero real entries** and
claimed the guard blocks writes under `human-copy/` "REGARDLESS of the
human-copy/ staging prefix". **That is false**, and this note supersedes it.

`_is_protected_gate_file` in the executing installed guard
(`sdd-quality-loop/1.10.0/scripts/sdd-hook-guard.py`) contains an explicit
staging exemption: a path still carrying the `specs/<feature>/human-copy/`
prefix after `normpath` is writable, **except** when a registered suffix itself
names a human-copy path. Only two such suffixes are registered —
`apply-human-copy.{sh,ps1}` and
`specs/epic-136-phase2-gates/human-copy/apply-protected-files.ps1` — and none
of the nine files here matches one.

Re-verified 2026-08-11 by loading the predicate from the installed guard and
evaluating it against all nine staging paths (**all writable**) and their nine
live counterparts (**all blocked**), then demonstrated by writing the files: no
write below was blocked.

Consequence: the workaround the old notes describe — staging under
`reports/implementation/<feature>/drafts/` instead — was never necessary. The
`drafts/` copies remain in place and are byte-identical to the Bundle A/B files
staged here; **this directory is now the canonical staging location**, and
`drafts/MANIFEST.sha256` is superseded by this one.

## What each item is, and how it was verified

### 1. `.github/workflows/test.yml`

The live workflow plus six CI steps appended to the end of the `version-gates`
job.

Contrary to the earlier record, **none** of the three suites was registered in
the live workflow: all three are registered in `tests/run-all.{sh,ps1}` but
none ran in CI. T-002's steps were therefore added here too, not skipped.

Verified by parsing both the live and staged documents with a real YAML parser
(Ruby Psych/libyaml):

- job key list unchanged and in the same order (`test`, `installers`,
  `loops-routing`, `version-gates`, `mcp-tests`, `local-env-mcp-tests`,
  `ci-mcp-tests`, `cli-hook-enforcement`, `required-checks`);
- every job other than `version-gates` structurally identical;
- `version-gates` 32 → 38 steps, the existing 32 unchanged and in order;
- each added step's `run` names a `tests/` file that exists;
- no duplicate step names.

Step formatting follows this job's house style (bash steps carry
`if: runner.os != 'Windows'`), which differs cosmetically from the fragments in
`reports/implementation/epic-191-a3-path-ownership/drafts/*-ci-steps.yml`.

### 2. Bundle A (6 files)

`check-component-coverage.{py,ps1,sh}` added to `PHASE2_TARGETS`
(`generate-guard-invariants.py`) and to both `protected_gate_suffixes` and
`phase2_human_copy_targets` (`guard-invariants.json`).

The two **source** files were edited from the LIVE files by this session, then
cross-checked byte-for-byte against the `drafts/bundle-a/` copies. The four
`generated/` siblings were **not** hand-authored: they were produced by running
the REAL, unmodified `generate-guard-invariants.py` against a scratch tree laid
out as the generator expects, after which `generate-guard-invariants.py
--check` exited 0. That `--check` was proven non-vacuous by tampering with one
generated file (exit 1) and restoring it (exit 0). Set comparison against the
live lists confirms the change **drops nothing**.

### 3. Bundle B (2 files)

`"check-component-coverage"` added to the hardcoded `high`/`critical`
tier-minimum sets (mirroring `risk-gate-matrix.md`), plus a producer-digest
verification pass that independently recomputes the live
`check-component-coverage.py` sha256 and rejects a `passes:true` evidence entry
whose `producer.sha256` does not match.

Verified by running the **staged** `check-contract.py` in an assembled sibling
tree: it rejects tampered evidence (exit 1, naming the digest mismatch) and
accepts genuine live-produced evidence (exit 0), while the LIVE
`check-contract.py` still accepts the tampered evidence — so the rejection is
caused by this change and not by the fixture. The staged `.ps1` twin parses
cleanly with the real PowerShell parser and carries the matching tier entries
and pass.

`tests/check-component-coverage.tests.sh` (41 passed / 0 failed) and `.ps1`
(40 / 0) are green.

### 4. `tests/gates.tests.sh`

The live suite predates Bundle B's new `check-component-coverage` minimum for
`high` and `critical` contracts. Its 12 resulting failures are all positive
assertions over 11 contracts authored by the suite itself in temporary
directories; `T-007a.9` reuses the same `T-100` fixture as `T-006.3b`. None of
these fixtures reads contract data from the repository's `specs/` tree.

Each affected positive contract now declares the new required check. The suite
runs the live `check-component-coverage.py` producer for every independent
temporary fixture root and records its JSON output, rather than substituting a
plain-text evidence file or fabricating a passing verdict. This makes the
producer sha256 in each record match the live producer and exercises the
producer-digest pass added by Bundle B. The negative fixtures remain unchanged:
none of their assertions was relaxed and no check was added merely to suppress
an expected failure.

Verification is recorded in
`../verification/T-004/gates-fixture-before-after.log`. It extracts each
contract heredoc from the live and staged suites and invokes the live
`check-contract.py` directly: all 11 live fixtures fail for the missing check,
and all 11 staged fixtures pass after genuine producer execution. The staged
candidate was also copied outside the repository and executed from scratch via
a normal scratch `tests/gates.tests.sh` layout whose `plugins/` entry pointed
to the live scripts; that run reported 126 passed and 0 failed
(`../verification/T-004/staged-candidate-suite.log`). The live suite was not
used for that green count and remains unchanged.

During this repair, the active PreToolUse hook rejected direct writes naming
the full exempt staging path even though the checked-in guard predicate permits
it. Publication therefore used a plain relative destination while the process
working directory was exactly `human-copy/tests/`; the resolved destination was
the sanctioned staging path, never the protected live path.

## Not staged, deliberately

**`plugins/sdd-quality-loop/scripts/check-contract.sh`** — no manifest entry,
because no candidate was produced.

It is a 49-line thin dispatcher (`python3` → PowerShell → error exit); it
declares no `RISK_TIERS` and runs no verification passes of its own, so both
halves of T-004's specified additive change land in `check-contract.py` and
`.ps1` only. Authoring it "from the live file plus that change" would reproduce
the live file byte-for-byte, and staging an unmodified copy would be worse than
useless: applied later it could silently **revert** an intervening live edit.
`drafts/MANIFEST.sha256` reached the same conclusion independently.

T-004.md's Unresolved Items #1 citation of a three-file Bundle B is therefore
inaccurate; **Bundle B is two files.**
