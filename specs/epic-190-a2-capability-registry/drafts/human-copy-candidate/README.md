# T-006 protected-file registration bundle -- regenerated candidate (quality-gate remediation)

This directory is **not** `specs/epic-190-a2-capability-registry/human-copy/`.
It exists because the bundle previously staged under `human-copy/` was built
from a pre-`epic-189-a1-merge` baseline (before commit `6f1351d4` merged
`origin/main`'s `epic_a1_targets` protected-path registration into this
branch) and, separately, the staged CI candidate predated commit `3baadda5`
(the `test`-job parallel split). Applying either stale candidate to the
current live tree would **silently drop** protections rather than only add
this feature's own seven new paths. See the T-006 quality-gate evaluation's
Critical finding and this repository's `reports/implementation/epic-190-a2-
capability-registry/T-006.md` ("Quality-gate remediation correction"
section) for the full incident record.

Every file below is named `<real-target-filename>.candidate` instead of the
real target filename. This is **not** an attempt to hide anything from the
repository's deterministic write-guard (`sdd-hook-guard`) -- it is the
opposite: `sdd-hook-guard` protects any path whose *tail* matches a
registered protected-gate suffix, `specs/<feature>/human-copy/` is the only
sanctioned exemption prefix, and this directory is deliberately **not**
that prefix (agents may not write under `human-copy/` directly -- see
`tasks.md` Protected Files / this session's own instructions). The `.candidate`
suffix is simply the plainest way to stage a draft outside that prefix
without the write itself being denied. Nothing here is a substitute for
human review; a human must still copy each file to its real target,
verify its hash, and run the generator's own `--check`.

## Mapping (candidate path -> real target path)

| Candidate file (this directory) | Real target path (after human `cp`, stripping `.candidate`) |
|---|---|
| `plugins/sdd-quality-loop/references/guard-invariants.json.candidate` | `plugins/sdd-quality-loop/references/guard-invariants.json` |
| `plugins/sdd-quality-loop/scripts/generate-guard-invariants.py.candidate` | `plugins/sdd-quality-loop/scripts/generate-guard-invariants.py` |
| `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py.candidate` | `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py` |
| `plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.js.candidate` | `plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.js` |
| `plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.ps1.candidate` | `plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.ps1` |
| `plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.sh.candidate` | `plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.sh` |
| `.github/workflows/test.yml.candidate` | `.github/workflows/test.yml` |
| `MANIFEST.sha256.candidate` | (becomes the new `MANIFEST.sha256` content -- see below) |

## What changed vs. the stale `human-copy/` candidate

- `plugins/sdd-quality-loop/references/guard-invariants.json` /
  `generate-guard-invariants.py`: rebuilt starting from the CURRENT LIVE
  files (which already carry the `epic_a1_targets` top-level key and its 28
  paths, plus `tests/guard-parity.tests.sh` in `phase2_human_copy_targets`),
  then this task's own seven new capability-registry paths were appended to
  `PHASE2_TARGETS`/`phase2_human_copy_targets` exactly as the original T-006
  implementation chose (end of the list). `protected_gate_suffixes` was
  **not** hand-edited -- it was recomputed by actually running the patched
  generator's own union algorithm
  (`BASELINE_SUFFIXES + PHASE2_TARGETS-extra + EPIC_A1_TARGETS-extra`) so
  the seven new entries land in their algorithmically-correct position
  (before the `epic_a1_targets`-derived tail, not after it). The four
  `generated/` siblings were rendered by actually running the generator
  against this candidate JSON in an isolated tree (never hand-transcribed),
  and `generate-guard-invariants.py --check` was confirmed to exit 0 against
  that same isolated tree before anything was copied here.
- `.github/workflows/test.yml`: rebuilt starting from the CURRENT LIVE file
  (9 jobs / 854 lines, post-`3baadda5` parallel split), not the stale staged
  file (6 jobs / 641 lines, pre-split). Insertions:
  - `test` job: two new steps ("Verify generated gate-capabilities
    projection", Windows/POSIX) immediately after the existing "Verify
    generated guard invariants" steps, mirroring that exact pattern
    (design.md Deployment / CI Plan: "mirroring `generate-guard-invariants.py
    --check` at `test.yml:30,35`").
  - `version-gates` job (the job the `test`-job split moved
    `model-freshness-check`/`project-context-schema`/other schema-and-generator
    suites into): appended, at the end of the job, the six
    `tests/*.tests.sh`/`.ps1` pairs for `capability-registry-schema`,
    `evaluate-predicate`, `registry-discovery`, `validate-capability-registry`,
    `generate-registry-digest` (T-005's suite -- previously unregistered in
    any staged CI candidate; text taken verbatim from
    `specs/epic-190-a2-capability-registry/verification/T-005/ci-registration-draft.md`),
    and `generate-gate-capabilities`, in that order (`generate-registry-digest`
    placed immediately after `validate-capability-registry` and before
    `generate-gate-capabilities`, per the draft's own placement instruction).
    This job (not the original monolithic `test` job the stale candidate
    assumed) is where the post-split live file groups this category of
    suite; there was no explicit spec directive for where these suites should
    live after the split, since the split (`3baadda5`) postdates every
    epic-190 task's own written Scope text -- this placement is this
    remediation's own engineering judgment, documented here for reviewer
    visibility.
- `MANIFEST.sha256`: recomputed from scratch against the seven files above
  (sha256 of each `*.candidate` file, recorded against its real target path).

A regression test
(`tests/generate-gate-capabilities.tests.sh`/`.ps1`, "candidate bundle drops
no live-protected path/key") verifies this candidate is a pure superset of
the live `guard-invariants.json` (0 removals across the top-level key set,
`protected_gate_suffixes`, and `phase2_human_copy_targets`); the same check
run against the stale `human-copy/` candidate fails (measured: 1 top-level
key, 28 `protected_gate_suffixes` entries, and 1 `phase2_human_copy_targets`
entry removed), proving the assertion is not vacuous. See
`reports/implementation/epic-190-a2-capability-registry/T-006.md`'s
"Quality-gate remediation correction" section for the full record.

## T-007 append (2026-08-09) -- one more pending apply, workflow only

The human apply recorded in commit `86b9aa7b` ("apply the regenerated
human-copy bundle") brought `specs/epic-190-a2-capability-registry/human-copy/`
in line with this directory as it stood at that moment, and T-006's own suite
went to `pass=21 fail=0 designed-red=0`.

T-007 ("Author the cross-script parity and installed-layout invocation
harness") then appended **its own two CI steps** -- `tests/
capability-registry-parity.tests.sh` and `.ps1`, at the end of the
`version-gates` job, immediately after `generate-gate-capabilities`'s pair --
to `.github/workflows/test.yml.candidate`, and recomputed that file's entry in
`MANIFEST.sha256.candidate`. That append is the LAST one this feature makes:
the candidate now carries every one of this feature's suite pairs in task
order (T-001 `capability-registry-schema`, T-002 `evaluate-predicate`, T-003
`registry-discovery`, T-004 `validate-capability-registry`, T-005
`generate-registry-digest`, T-006 `generate-gate-capabilities`, T-007
`capability-registry-parity`).

Nothing else in this directory changed, so **only two files need re-applying**:

| Candidate file | Target |
|---|---|
| `.github/workflows/test.yml.candidate` | `specs/epic-190-a2-capability-registry/human-copy/.github/workflows/test.yml` |
| `MANIFEST.sha256.candidate` | `specs/epic-190-a2-capability-registry/human-copy/MANIFEST.sha256` |

Until that lands, `tests/capability-registry-parity.tests.sh`/`.ps1` reports
exactly one `DESIGNED-RED` result naming this action, and exits non-zero with
`fail=0`. It turns green with no suite-code change once the two files above
are copied. (`tests/generate-gate-capabilities.tests.sh`/`.ps1` stays green
throughout: its own candidate-vs-`MANIFEST.sha256.candidate` check was
updated in the same edit.)

## Human apply step (unchanged procedure, new source directory)

1. For each row above, `cp` the candidate file to its real target path
   (this strips the `.candidate` suffix).
2. Rename `MANIFEST.sha256.candidate` to `MANIFEST.sha256` and place it at
   `specs/epic-190-a2-capability-registry/human-copy/MANIFEST.sha256`
   (replacing the stale one), OR verify each copied file's SHA-256 by hand
   against the table above.
3. Run `python3 plugins/sdd-quality-loop/scripts/generate-guard-invariants.py --check`
   against the applied tree; expect exit 0.
4. This bundle still carries the same cross-epic `PHASE2_TARGETS`/
   `guard-invariants.json` sequencing caveat T-006's own implementation
   report recorded (a concurrent `epic-189-a1` registration to the same
   shared constants) -- resolve that coordination question before applying,
   independent of this regeneration.
