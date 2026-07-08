# Implementation Report: T-005

- Task ID: T-005

Report Schema: implementation-report/v2

## Identity

- Task: T-005 / Feature: evidence-deep-verify
- Run ID: evidence-deep-verify-T-005-run-01
- Session ID: evidence-deep-verify-T-005-session-01
- Agent Instance ID: evidence-deep-verify-T-005-agent-01
- Model: anthropic/sonnet (tier standard)
- Isolation Mode: fresh-agent

## Preflight Note (medium risk)

`Risk: medium` — the WFI-001 high-risk preflight table is not required (only
`high`/`critical` tasks require it). Brief note per AGENTS.md's "good
practice" guidance: the one thing worth checking before writing fixtures was
whether `check-evidence-bundle.sh` actually recomputes/compares
`spec_revision` against the spec files' current content (the way
`evidenceDeepVerify`'s `specRevision` invariant does) — confirmed it does
**not**: it only enforces that the *recorded* `spec_revision` is present and
64-hex-shaped, and only for `risk: high`/`critical` bundles. This shaped how
the "spec drift" fixture had to be constructed (see Summary) to produce a
genuine host-side failure rather than a host/tool disagreement.

## Target

AC-012 (REQ-009, ADR-0009) host-parity goldens in `tests/golden/`: for four
fixture classes — consistent bundle (pass), tampered on-disk artifact (fail),
spec drift (fail), tampered recorded hash (fail) — verify that the host
scripts' verdict (`check-evidence-bundle.sh`, itself invoked by
`generate-evidence-bundle.sh`'s counterpart logic) and `evidenceDeepVerify()`'s
verdict agree in both directions. `src/`, `contracts/`, `tests/tools/`,
`plugins/`, and `scripts/` are out of scope / not writable for this task —
T-001–T-004, T-007, T-008 are Implementation Complete and untouched.

## Summary

Wrote the acceptance test + fixtures first (acceptance-first workflow) and
ran them against the pre-existing (already Implementation Complete)
`evidenceDeepVerify()`, recording the result honestly:

- **First run: 4/4 green, unmodified** — no defect found in T-001–T-004/T-007
  (`specs/evidence-deep-verify/verification/T-005-acceptance-first.txt`).
  This is a genuine "no news" acceptance-first outcome, not a weak test: a
  follow-up manual inspection (see Working Notes) confirmed each of the three
  intended-fail fixtures fails on the host side for exactly the tampered
  dimension and no other (`artifact sha256 mismatch for
  specs/golden-parity/artifact.md` for both tamper cases, `high/critical
  bundle requires spec_revision (64-hex), got: (empty)` for the drift case),
  ruling out "both sides happen to fail for unrelated reasons."

Each fixture is a throwaway, git-backed synthetic SDD root
(`tests/golden/deep-verify-parity-helpers.ts`'s `buildParityFixtureBase`):
`git init` + a single commit gives `check-evidence-bundle.sh`'s `git_commit`
ancestor check (`git cat-file -e` / `merge-base --is-ancestor`) a real commit
to validate, since that check requires an actual git repository at the given
root — `evidence_deep_verify` itself never spawns git or a shell (ADR-0008;
`tests/readonly`'s static no-exec check already covers this); only this test
file's helper does, mirroring `tests/golden/shell-runner.ts`'s existing
precedent of being the one place allowed to shell out to a host script.

**Spec drift fixture design note**: because `check-evidence-bundle.sh` never
recomputes `spec_revision` from the spec files' content (it only checks
shape+presence, and only for `risk: high`/`critical`), a low-risk "drifted
recorded value" fixture would make the tool fail while the host stayed pass —
a genuine disagreement, not a valid AC-012 fixture. The fixture that produces
real two-sided agreement is `risk: "high"` with recorded `spec_revision: ""`
even though `specs/<feature>/{requirements,design,acceptance-tests}.md` exist
on disk (simulating a bundle generated before/without the spec files, never
regenerated): the host fails its 64-hex shape gate on the empty string, and
the tool independently fails via its own REQ-005 recompute-and-compare
(`recorded "" != computed <64-hex>`). Both reach `fail` through genuinely
different logic, which is exactly what ADR-0009's agreement guarantee is
meant to prove.

Full regression (`cd mcp/sdd-forge-mcp && npm test`): 205/205 green (201
prior + 4 new).

## Files Changed

- `mcp/sdd-forge-mcp/tests/golden/deep-verify-parity-helpers.ts` (new) —
  shared (non-test, glob-excluded per node:test convention) fixture builder:
  `buildParityFixtureBase` writes a self-consistent synthetic SDD root
  (spec files with a correctly-recomputed `spec_revision`, an artifact file,
  a quality-gate report with `Task ID:`/`Feature:`/`VERDICT: PASS`, a
  verification contract whose six baseline check ids are `required:false` +
  waived so `check-contract.sh`'s required-set-protection pass is satisfied
  without needing real lint/build tooling output, and an evidence bundle
  referencing all of it), `git init`s + commits it once static files are in
  place, and returns handles for a test to layer one tamper on top. Also
  exports `runCheckEvidenceBundle` (shells out to the real
  `check-evidence-bundle.sh`, same pattern as `shell-runner.ts`'s
  `runCheckTaskState`) and `readBundleJson`.
- `mcp/sdd-forge-mcp/tests/golden/deep-verify-parity.test.ts` (new) — AC-012:
  four tests, one per fixture class, each asserting `check-evidence-bundle.sh`'s
  exit code and `evidenceDeepVerify()`'s `verdict` agree with each other *and*
  with the fixture's intended verdict (belt-and-suspenders against a fixture
  bug that happens to make both sides wrong in the same direction).
- `specs/evidence-deep-verify/verification/T-005-acceptance-first.txt` (new) —
  first-run acceptance evidence (4/4 pass, unmodified).
- `specs/evidence-deep-verify/verification/T-005-green.txt` (new) — re-run
  acceptance evidence (4/4 pass), confirming determinism/repeatability.
- `reports/implementation/evidence-deep-verify-T-005.md` (new) — this report.

No `src/`, `contracts/`, `tasks.md`, `traceability.md`, `tests/tools/`,
`plugins/`, or `scripts/` changes — out of scope per this task's
writable-outputs list and untouched.

## Tests Added Or Updated

Added `deep-verify-parity.test.ts` (4 tests, AC-012):
1. Consistent bundle → `check-evidence-bundle.sh` exit 0, `evidenceDeepVerify`
   verdict `"pass"`.
2. Tampered on-disk artifact (bundle's recorded sha256 unchanged, file
   content mutated) → both `"fail"`.
3. Spec drift on a `risk: "high"` bundle (recorded `spec_revision: ""`, spec
   files present on disk) → both `"fail"`.
4. Tampered recorded artifact hash (file content unchanged, bundle's recorded
   sha256 rewritten to a different well-formed 64-hex) → both `"fail"` — the
   dual of case 2.

## Outputs

| `path` | `hash` |
|---|---|
| `mcp/sdd-forge-mcp/tests/golden/deep-verify-parity-helpers.ts` | `d7a239faf7a9cdc1c8412977d6f068503541ab56a784a1fabe664ce602b81c6c` |
| `mcp/sdd-forge-mcp/tests/golden/deep-verify-parity.test.ts` | `439b727c9612411cf4ddfc7424216b1cde8983346f0d17d47e7ce75f2a23dbcb` |
| `specs/evidence-deep-verify/verification/T-005-acceptance-first.txt` | `f4e04c7b39adeebff2b4caf77e390250e46b2394b0e950750abb153ce3690a2c` |
| `specs/evidence-deep-verify/verification/T-005-green.txt` | `2532acea44550a332a33ccf065f011dd3f150de03ad8c1fade079cb93e070356` |

## Test Evidence

- **Test Command**: `cd mcp/sdd-forge-mcp && npm test`
- **Test Result**: PASS
- **Test Evidence Path**: `specs/evidence-deep-verify/verification/T-005-green.txt`

Acceptance-first detail (target suite in isolation,
`node --test dist-test/tests/golden/deep-verify-parity.test.js`):
- First run: tests 4, pass 4, fail 0 — unmodified, no defect found
  (`specs/evidence-deep-verify/verification/T-005-acceptance-first.txt`).
- Re-run (green confirmation): tests 4, pass 4, fail 0
  (`specs/evidence-deep-verify/verification/T-005-green.txt`).

Full regression (`cd mcp/sdd-forge-mcp && npm test`): tests 205, pass 205,
fail 0 (201 prior + 4 new). Full suite green.

## Iteration And Escalation

- **Task Attempt Count**: 1
- **Escalation Prior Tier**: None
- **Escalation Next Tier**: None
- **Escalation Failure Class**: None
- **Escalation Attempt Number**: 1
- **Escalation Reason**: None

## Isolation Evidence

- **Run ID**: evidence-deep-verify-T-005-run-01
- **Session ID**: evidence-deep-verify-T-005-session-01
- **Agent Instance ID**: evidence-deep-verify-T-005-agent-01
- **Isolation Mode**: fresh-agent
- **Fallback Reason**: None
- **Handoff Reload Evidence Hash**: None

## Regression Tests Run

`cd mcp/sdd-forge-mcp && npm test` → tests 205, pass 205, fail 0 (201 prior +
4 new). Full suite green.

## Specification Differences

None against AC-012 / the T-005 Goal. One scope decision worth flagging for
review: the "spec drift" fixture uses `risk: "high"` rather than the default
`"low"` used by the other three fixtures, because `check-evidence-bundle.sh`
only gates `spec_revision` at all for `high`/`critical` risk (see Summary) —
a low-risk drift fixture cannot produce host-side agreement. This is
documented in the test file's module doc and in this report, not silently
chosen.

Also: `deep-verify-parity.test.ts` does not add a Windows (`win32`) skip
guard the way `tests/golden/shell-runner.ts`'s AC-001 goldens do (with a
parallel "recorded fixture" fallback mode). AC-012 and design.md's Test
Strategy do not require Windows coverage for this golden set, and building a
second recorded-fixture code path was judged out of scope for a medium-risk,
acceptance-first, test-only task; this suite currently assumes a POSIX shell
+ git + python3 are available (true of this repo's dev/CI environment, same
assumption `shell-runner.ts` already makes for its live-shell mode).

## Unresolved Items

None.

## Quality Gate Focus

- Confirm the first-run 4/4-green result genuinely reflects pre-existing
  correctness in `evidenceDeepVerify()` (T-001–T-004) rather than a
  fixture-construction bug that accidentally makes both sides agree for the
  wrong reason — the manual host-script-output inspection in Working Notes
  (each fail case's failure message names exactly the tampered dimension and
  nothing else) is the intended defense against that.
- Confirm the "spec drift" fixture's `risk: "high"` choice (and its rationale
  in Specification Differences) is an acceptable interpretation of AC-012's
  "spec ドリフト(fail)" fixture class, given `check-evidence-bundle.sh`'s
  actual (risk-gated, shape-only) `spec_revision` handling.
- Confirm no test in this suite depends on real repository content (all four
  fixtures are synthetic, git-backed temp directories under the OS temp
  dir — REQ-009 / ADR-0009 point 3's "repo-internal synthetic data").

## Working Notes

- No delegated investigations. Inputs read from the hash-bound snapshot at
  `/private/tmp/claude-501/-Users-jrmag-Projects-active-sdd-forge/f51aa51c-ab40-4018-8257-d0fe8b15dfaf/scratchpad/snapshots/evidence-deep-verify-T-005`;
  the writable `mcp/sdd-forge-mcp/tests/golden/` and
  `specs/evidence-deep-verify/verification/` paths were read and written
  directly in the live repo (`/Users/jrmag/Projects/active/sdd-forge-p5`).
- Read `plugins/sdd-quality-loop/scripts/check-contract.sh` and
  `check-contract.py` (live repo) to understand what `check-evidence-bundle.sh`'s
  own subprocess call into contract validation would require of the
  synthetic contract (baseline check-id required-set protection) — not in
  the task's snapshot manifest, but necessary to construct a contract that
  passes `check-evidence-bundle.sh` end-to-end without needing real
  lint/build tooling output in a throwaway fixture.
- Read `mcp/sdd-forge-mcp/tests/tools/deep-verify-helpers.ts`,
  `tests/evidence/test-helpers.ts`, and `tests/golden/shell-runner.ts` /
  `task-state-golden.test.ts` (live repo, read-only reference per task
  instructions) for existing fixture/shell-comparison conventions, then wrote
  a self-contained equivalent inside `tests/golden/` rather than importing
  from `tests/tools/` directly (per the explicit "copy the minimal needed
  pieces into tests/golden/" instruction) — `deep-verify-parity-helpers.ts`
  only imports the general-purpose `tests/test-helpers.ts` (`makeTempSddRoot`
  / `writeFile`), which is shared infrastructure used across every test
  subdirectory, not task-specific fixture code.
- After the first (green) run, wrote a standalone one-off inspection script
  (not committed) that ran `check-evidence-bundle.sh` against the three
  intended-fail fixtures directly and printed its failure detail lines, to
  positively confirm each failure was attributable to the intended tamper
  dimension alone: `artifact sha256 mismatch for
  specs/golden-parity/artifact.md` (both tamper cases) and `high/critical
  bundle requires spec_revision (64-hex), got: (empty)` (drift case). This
  was a self-review step, not part of the committed test suite.
- Read `reports/implementation/evidence-deep-verify-T-008.md` (live repo) for
  house style/report conventions before writing this report, consistent with
  the precedent it itself documents for reading prior sibling-task reports
  not present in the snapshot manifest.

## Session Handoff

- **Current Status**: Implementation Complete
- **Next Action**: Independent quality gate / review of AC-012 evidence.
- **Unresolved Items**: None
