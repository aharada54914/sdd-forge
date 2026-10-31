from pathlib import Path
import hashlib,json
OUT=Path(__file__).resolve().parents[1]
W=OUT/'work'
E=W/'specs/shared-review-launch-repair/verification/T-004'
M=json.loads((OUT.parent/'manifest.json').read_text())
REPORT=W/'reports/implementation/shared-review-launch-repair/T-004.md'
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
outputs=[W/'.github/workflows/test.yml']+sorted(p for p in E.iterdir() if p.is_file())
rows='\n'.join('| `'+str(p.relative_to(W))+'` | `'+sha(p)+'` |' for p in outputs)
preflight=(E/'preflight-report-before-edit.md').read_text().split('## High-risk Preflight',1)[1]
body="""# Implementation Report: T-004

- Task ID: T-004
- Model: gpt-6-astra (manifest-declared)
- Effort: Not exposed by the native host

Report Schema: implementation-report/v2
Run ID: RUN_ID_VALUE
Task Attempt Count: 1

**Snapshot Notice**: This record describes only this isolated native implementation attempt. It is not a quality verdict, native Windows result, hosted CI result, merge receipt, or lifecycle transition.

## Target

Approved shared-review-launch-repair T-004, REQ-003 / REQ-006 only. Parent applies outputs and owns all transitions and delivery gates.

## Summary

Added two lines in the consuming posix-regression job: the existing locked npm ci command now runs before the shared review suite that invokes task-structured-output. The separate posix-unwired-sharded install remains unchanged. This removes a clean-checkout Ajv dependency defect without changing validators, assertions, permissions, or runtime entrypoints.

Local implementation and bounded verification are recorded below. Required task-level acceptance remains NOT RUN; no Implementation Complete or Done claim.

## Files Changed

- `.github/workflows/test.yml`: added `npm ci --prefix mcp/ci-mcp --ignore-scripts` before the consuming shared-review step.
- Task-scoped verification evidence and this report only.
- Existing Bash/PowerShell runner registrations, workflow registry, historical integration record and all other 61 admitted files retain their snapshot hashes. Existing dirty candidate bytes are preserved; see source-preservation.json and candidate.diff.

## Tests Added Or Updated

`verification/T-004/wiring-check.py` checks executable registrations in the existing fixed workflow/runner grammar: consuming-job install/order, direct transport CI, POSIX traceability CI/Bash, Bash Python suite loop and execution, applicable PowerShell transport/hash-parity registration and execution, and the existing full-profile registry entry. It is evidence-scope only, not a new permanent production test. Permanent TEST-013 remains in the unchanged host-review-preflight suite.

`preflight-mismatches.py` executes one mutation at a time in a disposable projection; `rollback-check.py` executes the source restoration experiment. Existing production test sources are unchanged. `record-command.py` captures full stdout/stderr, commands, cwd, exits and input source pins.

## Outputs

Exact repository-relative deliverables, excluding this report's self-hash. delivery-index.json separately pins the report and maps these paths into output/work. npm-cache, installed node_modules, admitted support copies and output/tmp are execution dependencies/scratch, not application targets.

| Path | SHA-256 |
|---|---|
OUTPUT_ROWS

## Test Evidence

- **Test Command**: Commands/cwd/exits/full stdout/stderr are preserved in verification/T-004/*.json; see the named records below.
- **Test Result**: NOT RUN
- **Test Evidence Path**: specs/shared-review-launch-repair/verification/T-004/structured-output-suite.json

The aggregate result is NOT RUN because required full runners, hosted CI and native Windows are downstream. Local observations:

| Check | Observed result | Record under specs/shared-review-launch-repair/verification/T-004/ |
|---|---|---|
| All admitted hashes + source-mode restoration | 62 hashes matched; structure exit 0, CLAUDE advisory only | input-verification.json, structure.json |
| Original production wiring RED | exit 1; only consuming-install fails | original-wiring-red.json |
| Original real dependency RED | exit 1; exact MODULE_NOT_FOUND for local Ajv | original-missing-ajv-red.json |
| Mutation preflight | 27 registration/order mutations + 97 evidence-field mismatches rejected | preflight-mismatch-results.json, preflight-mismatches-final.json |
| Candidate wiring GREEN | all 26 structural checks pass, exit 0 | wiring-green.json |
| Real locked dependency installation | exit 0; offline supplied cache; 200 packages installed | offline-npm-ci.json |
| Identical Ajv test after install | 1 test passes, exit 0 | installed-ajv-green.json |
| Entire admitted structured-output suite | 13 tests pass, exit 0 | structured-output-suite.json |
| Permanent TEST-013 | baseline and candidate each 1 test passes; actual deletion/comment-only negative fixtures exercised | baseline-test013.json, candidate-test013.json |
| Generated projections | generator --check exit 0 | generator-check.json |
| Task source rollback | bytes/mode restored; original dependency-wiring RED returns; other registrations, TEST-013 and generator GREEN | rollback-results.json, rollback.json |

The offline npm output contains a dependency deprecation warning; its raw text is retained. No network or global npm cache was used. Offline npm audit text is not a security-audit claim.

## TEST Mapping And Platform Applicability

- TEST-006a / AC-003: registration assertions and local dependency experiment are executed supporting evidence only. Full Bash/PowerShell entrypoints: NOT RUN.
- TEST-006b / AC-003: exact-final-head hosted CI and mandatory native Windows branches: NOT RUN. No CI run URL or submitted PR head exists in this context.
- TEST-013 / AC-006: `ProtectedEntrypointTests.test_013_ci_transport_registration` ran against admitted baseline, candidate and restored source. Its deletion-negative assertion remains the permanent regression; mutation RED is prior-registration evidence, not original-production RED.
- POSIX traceability Bash fixtures remain registered in Bash and the POSIX CI job. They are not added to the native Windows runner merely for symmetry. Applicable PowerShell transport and PowerShell hash parity registrations are preserved; native execution is NOT RUN here.
- No existing SKIP condition is changed. The consuming POSIX CI job now obtains Ajv before the schema test; first real hosted execution remains pending CI. This local Darwin experiment does not establish Ubuntu/Windows CI behavior.

## Iteration And Escalation

- **Task Attempt Count**: 1
- **Escalation Prior Tier**: None
- **Escalation Next Tier**: None
- **Escalation Failure Class**: None
- **Escalation Attempt Number**: None
- **Escalation Reason**: None

One production edit. The evidence harness needed two local corrections, both retained as failures in preflight-mismatches.json and preflight-mismatches-fixed.json: the '-order' suffix matched a suite name; the final shell-loop token ends at a semicolon rather than a space. The third preflight execution passed. These are instrumentation failures, not original production RED or separate native task attempts.

## Isolation Evidence

- **Scratch Root**: SCRATCH_ROOT_VALUE
- **Run ID**: RUN_ID_VALUE
- **Session ID**: SESSION_ID_VALUE
- **Agent Instance ID**: SESSION_ID_VALUE
- **Isolation Mode**: fresh-agent
- **Fallback Reason**: None
- **Handoff Reload Evidence Hash**: None

Manifest SHA-256: 565e5fcccf4b60629d24aad73a3d246c9e69b036a634829c211be63c68688a90

spec_revision: 9ce19abe90df0cb83e385f96855e4843318a8807 (admitted base HEAD from before-byte-inventory, not a live Git observation). Actual current spec raw hashes, including approved tasks and all four layer files, are individually pinned in input-verification.json and preflight-claims.json; candidate bytes are not described by the base commit alone.

Only manifest/snapshot inputs and generated output files were read. No owner/history/memory/ledger/Git/network/delegated agent reads or status edits. All work after governing-instruction load used rtk proxy and login=false. The first two hash-verification commands used the executor default login setting before that instruction was read; no dependent owner/history reads were requested. No compaction occurred.

## High-risk Preflight
PREFLIGHT_BODY

## Regression Tests Run

The scoped checks and their exact records are in Test Evidence. Full transport/traceability suites, full run-all and native Windows checks remain NOT RUN per native-instructions; no incomplete runner was executed. No runtime or production test-source behavior was changed.

## Rollback

The immutable snapshot is the before-byte reference. `rollback-check.py` copied only enumerated admitted inputs into output/tmp/t004-source-rollback, applied the candidate workflow bytes, observed wiring GREEN, restored only this task's workflow bytes and mode from snapshot, and compared restored SHA-256/mode with the original. All 62 admitted bytes and recorded source modes then matched. Missing-install wiring returned to the known RED; unaffected applicable registrations, permanent TEST-013 and generator remained GREEN. This is real task-scoped file restoration and subprocess verification, not a native installed-host rollback. Combined T001-T005 rollback: NOT RUN; parent responsibility.

## Specification Differences

None. No frozen spec, approval, task status, historical report or existing registration was edited. No UI scope; visual verification and design-system changes are not applicable. The evidence checker intentionally targets the current executable line grammar rather than introducing a YAML dependency.

## Unresolved Items

NOT RUN: full Bash/PowerShell runners, full transport/traceability regressions, native Windows, exact-final-head CI, combined rollback, independent review, formal quality gate, merge and postmerge. No PR head, merge commit or run URL is claimed. Parent must apply the candidate with before-hash checks and collect these required observations before any completion decision.

## Quality Gate Focus

Verify the one-file/two-line source diff; preserve existing dirty candidate bytes and all frozen hashes. Recheck shared runner/CI/protection registrations at current head. Verify clean CI dependency installation, full required runners and native Windows, and combined rollback. Do not promote this scoped local GREEN to TEST-006 acceptance or Done.

## Working Notes

No delegation. The shared sources already contain all applicable registrations, so runners and registry were preserved. Candidate source preservation is independently hash-checked against the admitted snapshot; this self-check is not independent diff review. No dependency changes were made to package manifests or lockfiles.

## Session Handoff

- **Current Status**: In Progress
- **Next Action**: Parent verify delivery-index and before hashes, apply the candidate through the authorized path, then run downstream full/platform/CI/rollback/review/gate and delivery checks.
- **Unresolved Items**: Required downstream evidence remains NOT RUN; this native context makes no lifecycle transition.
"""
body=body.replace('OUTPUT_ROWS',rows).replace('PREFLIGHT_BODY',preflight).replace('RUN_ID_VALUE',M['run_id']).replace('SESSION_ID_VALUE',M['session_id']).replace('SCRATCH_ROOT_VALUE',str(OUT))
REPORT.write_text(body)
print('Report written; '+str(len(outputs))+' output rows')
