# Implementation Report: T-002

- Task ID: T-002

Report Schema: implementation-report/v2

## Target

Feature `evidence-deep-verify`, task T-002 — internal invariant recomputations
of the `evidence_deep_verify` core in
`mcp/sdd-forge-mcp/src/tools/evidence.ts`: (1) `spec_revision` recompute
verbatim-identical to host `compute_spec_revision`, (2) `git_commit` shape-only
(`^[0-9a-f]{40}$`) validation with host-deferred ancestry and NO git
subprocess (ADR-0008), and (3) verification-contract / quality-report
task_id·feature cross-binding. Required Workflow: tdd (Risk: high).

## Summary

T-001 (Status: Implementation Complete) already implemented all three internal
invariants to T-002's acceptance criteria. Per tasks.md T-002 ("T-001 laid a
skeleton — verify it and complete") and the launch contract, this task's
deliverable is the TDD verification suite for AC-006/007/008/009/010/019 plus a
runtime no-exec guard, and a line-by-line verification that the recompute
formulas match the host scripts verbatim (ADR-0009).

Outcome: the new suite (15 tests) passes on first run against the unmodified
T-001 source — recorded honestly as the Red evidence. Non-vacuity is proven by
a mutation sanity check that fails 8 of 15 tests when the three invariant
checks are deliberately broken in the compiled build artifact (source
untouched, artifact restored). No change to `evidence.ts` was required; the
source was never modified.

### Host-formula parity verification (ADR-0009)

`spec_revision` — host `compute_spec_revision`
(`plugins/sdd-quality-loop/scripts/generate-evidence-bundle.sh` lines 203–222):
iterates `specs/<feature>/{requirements.md, design.md, acceptance-tests.md}` in
that order, `if spec_file.exists() and spec_file.is_file()` updates one
`hashlib.sha256()` with the file bytes and sets `found_any = True`, returning
`hasher.hexdigest() if found_any else ""` (line 222). The MCP
`recomputeSpecRevision` (evidence.ts lines 552–581) iterates the same three
relative paths in the same order, updates one `createHash("sha256")` for each
`guardedRead`-readable file, and returns `foundAny ? hasher.digest("hex") : ""`
— byte-identical ordering, same empty-set canonical value `""`. UTF-8 string
update equals the host's raw-byte update for the UTF-8 spec text.

`git_commit` shape — host `re.fullmatch(r"[0-9a-f]{40}", git_commit)`
(check-evidence-bundle.sh line 286; generate line 180). MCP `GIT_COMMIT_PATTERN
= /^[0-9a-f]{40}$/` (evidence.ts line 471) — identical. Host ancestry via
`git ... cat-file`/`merge-base` (check lines 298–322) is host-only; MCP echoes
`ancestryVerified: false` and spawns no subprocess (ADR-0008).

cross-binding — host contract check `contract_task != task_id`
(check-evidence-bundle.sh lines 212–214) and feature `(contract_feature or
bundle_feature) and contract_feature != bundle_feature` (215–220); report
`^Task ID:\s*{task_id}\s*$` (201) and `^Feature:\s*(.*)\s*$` (228). MCP
`verifyContractBinding` / `verifyReportBinding` (evidence.ts lines 606–677)
mirror these comparisons.

## WFI-001 High-Risk Preflight Checklist

For each evidence field this task's tests assert, the persisted field, its
sibling/counterpart, and the failing mismatch test that fails while they
disagree:

| Persisted evidence field | Sibling / counterpart | Failing mismatch test |
|---|---|---|
| `invariants.specRevision.status/computed` | on-disk `specs/<feature>/{requirements,design,acceptance-tests}.md` bytes vs recorded `bundle.spec_revision` | AC-006 (drifted design.md → `mismatch`, computed=recompute, verdict fail) |
| `invariants.specRevision` empty-set value | absent spec files → canonical `""` vs recorded `""`/non-empty | AC-019 match (`""=""`) and AC-019 mismatch (non-empty recorded → fail) |
| `invariants.gitCommit.shapeValid` | recorded `bundle.git_commit` vs `^[0-9a-f]{40}$` | AC-007 (missing/short/too-long/non-hex/uppercase → `shapeValid:false` + fail) |
| `invariants.gitCommit.ancestryVerified` + no-exec | ancestry is host-deferred; tool must not spawn git | AC-008 (foreign 40-hex → `ancestryVerified:false`, verdict not lowered; child_process trap asserts 0 spawns) |
| `invariants.crossBindings[verification_contract].status` | contract file `task_id`/`feature` vs `bundle.task_id`/`feature` | AC-009 (foreign contract task_id and foreign feature → `mismatch` + fail) |
| `invariants.crossBindings[quality_report].status` | report `Task ID:`/`Feature:` lines vs `bundle.task_id`/`feature` | AC-010 (foreign Task ID, foreign Feature, and unreadable report → `mismatch` + fail) |

All persisted fields have all three entries; the verification suite was written
before confirming T-001's implementation satisfies them.

## Files Changed

- `mcp/sdd-forge-mcp/src/tools/evidence.ts` — NOT changed (T-001's invariant
  implementation already meets T-002's acceptance criteria; verified against
  the host formulas above). Zero source edits.

## Tests Added Or Updated

- `mcp/sdd-forge-mcp/tests/tools/deep-verify-invariants.test.ts` — NEW. 15
  tests: AC-006 (spec drift), AC-007 (5 malformed git_commit shapes), AC-008
  (foreign 40-hex + a `child_process` spawn/exec trap asserting 0 invocations),
  AC-009 (contract task_id + feature mismatch), AC-010 (report Task ID +
  Feature mismatch + unreadable report), AC-019 (absent specs match `""` and
  non-empty recorded mismatch). Reuses `deep-verify-helpers.ts` from T-001.

## Outputs

| Path | SHA-256 |
|---|---|
| `mcp/sdd-forge-mcp/tests/tools/deep-verify-invariants.test.ts` | `0fcff6c24403358a4a960e31d23de7ddac379f71111a55abef284f0cf8a5f6b9` |
| `specs/evidence-deep-verify/verification/T-002-red.txt` | `0452e06ecbee7c590cc9cc72e5b6e1e7e076a8e2710fdba24d485f566d1d609f` |
| `specs/evidence-deep-verify/verification/T-002-green.txt` | `a7f884e242a02d736959c782094c2554cfab0e221b8fa1ef98dade31d0ca4078` |

(This report is self-referential and so is not listed with its own hash. No
source file was modified, so `evidence.ts` is not an output.)

## Test Evidence

- **Test Command**: `cd mcp/sdd-forge-mcp && node scripts/run-tests.mjs` (full);
  `node --test dist-test/tests/tools/deep-verify-invariants.test.js` (T-002 suite)
- **Test Result**: PASS
- **Test Evidence Path**: specs/evidence-deep-verify/verification/T-002-green.txt

Red (before any implementation change): 15/15 pass — T-001 already satisfied
the criteria (recorded honestly in T-002-red.txt). Mutation sanity check
(non-vacuity): breaking git shapeValid, specRevision.status, and the contract
task_id comparison in the compiled build artifact (source untouched, restored
afterward) fails 8/15 tests (AC-006, AC-007×5, AC-009 task_id, AC-019
mismatch), confirming the tests detect regressions in each invariant.

## Iteration And Escalation

- **Task Attempt Count**: 1
- **Escalation Prior Tier**: None
- **Escalation Next Tier**: None
- **Escalation Failure Class**: None
- **Escalation Attempt Number**: None
- **Escalation Reason**: None

## Isolation Evidence

- **Run ID**: evidence-deep-verify-T-002-run-01
- **Session ID**: evidence-deep-verify-T-002-session-01
- **Agent Instance ID**: evidence-deep-verify-T-002-agent-01
- **Isolation Mode**: fresh-agent
- **Fallback Reason**: None
- **Handoff Reload Evidence Hash**: None

## Regression Tests Run

`node scripts/run-tests.mjs`: 181 tests, 181 pass, 0 fail (includes T-001's
`deep-verify.test.ts` / `deep-verify-error-paths.test.ts` and the new T-002
`deep-verify-invariants.test.ts`). Test compile `tsc -p tsconfig.test.json`:
clean.

## Specification Differences

None. The host `compute_spec_revision` reads raw file bytes with no size limit,
while the MCP path reads via path-guard (UTF-8 decode, 2 MiB cap). For
UTF-8 spec text under 2 MiB the digests are byte-identical; this is the
documented, ADR-0009-sanctioned reuse of the existing path-guard read path and
not a behavioral divergence within the tested domain.

## Unresolved Items

None.

## Quality Gate Focus

Confirm the `spec_revision` formula parity (report cites
generate-evidence-bundle.sh lines 203–222) and that AC-008's `child_process`
trap genuinely covers the no-exec boundary. Note the honest Red outcome (T-001
already satisfied the ACs) is validated by the mutation sanity check rather than
a naturally-failing first run.

## Working Notes

- Verified host `compute_spec_revision` (generate-evidence-bundle.sh 203–222)
  and `check-evidence-bundle.sh` cross-binding lines (201, 212–220, 228–234)
  against evidence.ts. Purpose: confirm verbatim parity (ADR-0009). Result:
  parity confirmed; no code change needed.
- Probed ESM patchability of `node:child_process` default export before relying
  on it for the AC-008 no-exec trap. Result: default-export methods are
  writable, so the runtime spawn/exec trap is sound.

## Session Handoff

- **Current Status**: Implementation Complete
- **Next Action**: Independent quality gate review (T-002); then T-003 (signature boundary / static read-only checks) which is unblocked once T-002 lands.
- **Unresolved Items**: None
