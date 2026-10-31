from pathlib import Path
import hashlib,json
out=Path.cwd(); work=out/'work'; rel='specs/shared-review-launch-repair/verification/T-003'; ev=work/rel
m=json.loads((out.parent/'manifest.json').read_bytes()); p=json.loads((ev/'provenance.json').read_bytes())
sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
source='tests/host-review-preflight.tests.py'; before=next(e['sha256'] for e in m['allowed_inputs'] if e['path']==source)
files=[source]+[rel+'/'+f.name for f in sorted(ev.iterdir()) if f.is_file()]
outputs='\n'.join('| `'+name+'` | `'+sha(work/name)+'` |' for name in files)
preflight=(ev/'preflight-report.md').read_text().split('## High-risk Preflight\n',1)[1].split('## Session Handoff',1)[0].strip()
report=f"""# Implementation Report: T-003

Run ID: {m['run_id']}
Task Attempt Count: 2

- Task ID: T-003
- Feature: shared-review-launch-repair
- Model: gpt-6-astra
- Effort: high

Report Schema: implementation-report/v2

**Snapshot Notice**: Evidence records this implementation run only. Independent quality verification and all task-state decisions belong to the parent. This report does not set Done or change any task/specification state.

## Target

Approved T-003, REQ-006 / AC-006. Native implementation identity: session and agent `{m['session_id']}`. Continue the same identity and attempt 2 after the user clarified the validator location. Source work is confined to `{work}`; temporary files are confined to `{out/'tmp'}`.

## Summary

Added regression coverage to the existing host suite for all six protected entrypoints, invariant drift, unrelated membership preservation and actual workflow transport-registration removal. Existing registration already satisfied the runtime contract. No canonical, generator, projection, guard, entrypoint, CI, run-all, contract, specification or status change was needed.

This is an intact-baseline → isolated mutation RED → restored-byte GREEN exercise. It is not original production RED. RT-20261009-001's T001-only exception is not used or extended. New assertions passed against the already-registered candidate and failed against deliberately changed disposable copies. Original seven host regressions remain byte-for-byte unchanged.

## Files Changed

- `{source}` only: six additional standard-library imports, six named entrypoint tests, canonical/generator drift tests, each of four stale projections, unchanged unrelated-invariant pin, real workflow registration check, and a broken-projection diagnostic control. No new dependency.
- Before SHA256: `{before}`.
- After/test SHA256: `{sha(work/source)}`.
- All other 56 admitted input copies retain their exact hashes. All 56 explicitly enumerated source modes match the admitted source-modes inventory. Its own metadata file has no declared source-mode entry; the work copy is 0644 while the immutable snapshot is 0444. No mode change was made during finalization.
- `source-integrity.json` contains every before/after input hash and declared/observed mode. `candidate.diff` is an author-produced byte diff, not independent review evidence.

## High-risk Preflight

{preflight}

The original persisted preflight text is retained in `{rel}/preflight-report.md`. `identity-hash-preflight.json` records synthetic identity/hash disagreements, not a live identity-ledger reservation or verification. The structure precheck passed after reconstruction from the enumerated sources and registry-topology directories. Procedural order note: task/specification inputs were read before that structure command; no candidate implementation edits preceded preflight persistence.

## Tests Added Or Updated

| TEST-ID | Concrete assertion and evidence |
|---|---|
| TEST-011a | launch-impl-review.py: Write exit 2 with enforcement-chain reason; Read and ordinary Write exit 0 in Python, Node, PowerShell and Bash dispatcher. |
| TEST-011b | preflight-host-review.py: same four-runtime write/read assertions. |
| TEST-011c | validate-nontty-spec-launch.py: same four-runtime write/read assertions. |
| TEST-011d | probe-nontty-review.py: same four-runtime write/read assertions. |
| TEST-011e | nontty-impl-pretool-guard.mjs: same four-runtime write/read assertions. |
| TEST-011f | preflight-evaluator-delivery.py: same four-runtime write/read assertions. |
| TEST-012a | Canonical-only addition: generator check exits 1 with exact baseline/inventory-union diagnostic; restore bytes and check exits 0. |
| TEST-012b | Generator-only addition: same mismatch diagnostic and restored-byte success. |
| TEST-012c | Each Python, JavaScript, PowerShell and shell projection separately gets a stale-byte mutation; check exits 1 naming that file; byte restoration exits 0. |
| TEST-012d | Pin all invariant keys and unrelated memberships after excluding only the six T-003 paths; explicitly retain all eight original additions exactly once. Unrelated membership/key mutations fail. External unittest mutation exits 1, restored bytes exit 0. |
| TEST-013 | Copy the actual admitted .github/workflows/test.yml; remove its executable POSIX transport run line; registration assertion fails, including when a comment mentions the command. Generator --check still exits 0 on the workflow omission. External unittest exits 1; restored workflow exits 0. |

Each fixture input must exist before copying; missing inputs fail with a named `missing admitted fixture input` diagnostic. Runtime evidence requires the specific enforcement-chain denial plus successful read and unrelated-write controls. A broken Python projection is deliberately tested to ensure generic fail-closed exit 2 is not accepted as protection evidence. All mutations are disposable; production guard implementation and entrypoint bytes remain unchanged.

## Outputs

Only the following changed source and verification artifacts are intended delivery inputs. Unchanged work copies and temporary fixtures are not delivered changes. The report itself is excluded from its Outputs hash table; its final hash is bound in output/delivery-index.json. The delivery index is packaging metadata outside the repository and is not a self-hashed report output.

| Path | SHA-256 |
|---|---|
{outputs}

## Test Evidence

- **Test Command**: rtk proxy python3 -B work/tests/host-review-preflight.tests.py -v
- **Test Result**: PASS
- **Test Evidence Path**: {rel}/focused-host.json

PASS here applies to the recorded local focused suite only. Exact argv, cwd, exit, full stdout and full stderr are retained in the command JSON records. The runner sets TMPDIR/TMP/TEMP and runtime cache homes under the absolute output/tmp path; no shell login is used. Nested guard commands and payloads are preserved in guard-preflight-mismatches.json. Execution driver bytes and hashes are retained in execution-sources.json. The final suite source hash is the after/test hash above; it did not change after the successful 19-test run.

## Iteration And Escalation

- **Task Attempt Count**: 2
- **Escalation Prior Tier**: None
- **Escalation Next Tier**: None
- **Escalation Failure Class**: None
- **Escalation Attempt Number**: None
- **Escalation Reason**: None

No new identity, model escalation or additional task attempt was created. One candidate edit; zero failing candidate-suite repair loops. The earlier wrong validator location is preserved in diagnostics.json; the original combined output did not retain a numeric exit code, which is explicitly unknown rather than invented. The user corrected the path to the admitted sdd-implementation validator. An auxiliary mode-audit assertion was corrected to compare only the 56 actually declared modes; this did not change candidate bytes or modes.

## Isolation Evidence

- **Scratch Root**: {out}
- **Run ID**: {m['run_id']}
- **Session ID**: {m['session_id']}
- **Agent Instance ID**: {m['agent_instance_id']}
- **Isolation Mode**: fresh-agent
- **Fallback Reason**: None
- **Handoff Reload Evidence Hash**: None

Manifest: `{out.parent/'manifest.json'}`. SHA256: `{p['manifest_sha256']}`. All 57 snapshot input hashes verified before substantive reads and reverified on same-identity continuation. No owner, memory, history, network, agent, ledger, Git or status operation was used. Explicit source enumeration and authorized mode restoration created the work copy; no recursive snapshot/source discovery or copy was used. The admitted guard-parity script performs its own fixture operations inside the bounded work/tmp environment.

`spec_revision`: `{p['spec_revision']}` (raw admitted requirements.md SHA256). Complete specification hashes, all input/source hashes and test-source before/after hashes are in provenance.json and source-integrity.json; every delivered evidence hash is in Outputs. The admitted baseline head is provenance supplied by before-byte-inventory.json, not a Git observation in this run.

## Regression Tests Run

| Scope | Result | Exact evidence |
|---|---|---|
| Reconstructed feature structure | exit 0; check-sdd-structure OK | structure.json |
| Intact baseline host suite | 7 tests, exit 0 | baseline-host.json |
| Intact baseline generator | exit 0 | baseline-generator.json |
| Intact baseline guard parity | 110 passed, 0 failed; exit 0 | baseline-parity.json |
| Added focused host suite | 19 tests, all pass; exit 0; four available runtimes | focused-host.json |
| Final generator --check | exit 0 | final-generator.json |
| Implementation report schema | exit 0; IMPLEMENTATION_REPORT_OK | report-validation.json |
| Final admitted guard parity | 110 passed, 0 failed; exit 0 | final-parity.json |
| Preflight inventory/projection mismatches | 6 expected check failures and restored successes | preflight-mismatches.json, preflight-execution.json |
| Preflight six-path runtime membership removal | 24 path/runtime combinations: intact denial/read, lost protection after mutation, restored denial | guard-preflight-mismatches.json, preflight-guards.json |
| Isolated unittest RED / restored-byte GREEN | 8 expected exit-1 failures: six paths, actual workflow omission, unrelated membership; 20 rollback hash triples | regression-mutations.json, isolated-regression-execution.json |

Previously completed expensive focused/generator/parity checks were retained, not rerun during finalization. The first isolated unittest driver did not leave a completed evidence file; no result is inferred from it. Only the changed disposable-fixture mutation checks were completed again with an incrementally persisted log. Every rollback triple has before == restored and before != mutated. This includes the actual workflow line, not a fabricated stand-in workflow. Available runtime versions and native platform are captured in runtime-environment.json.

## Specification Differences

None. Existing six-path registration plus the two other original additions were preserved exactly. The change completes task-scoped regression evidence only. T-004 owns permanent CI wiring and CI results. TEST-013 checks the existing single-line executable run step inside the actual POSIX regression job; a future workflow syntax refactor must update that scoped assertion. This is intentionally not a general YAML parser.

## Unresolved Items

Native Windows: NOT RUN. PowerShell was exercised on the recorded native non-Windows host. Installed-host activation: NOT RUN; executing copied fixture guards is not activation evidence. Independent diff review: NOT RUN. Formal quality gate: NOT RUN. CI: NOT RUN. Merge: NOT RUN. No full-repository suite or run-all was executed because only the admitted focused and parity checks are in scope. No task-state transition, reservation, live reviewer launch, commit or push occurred. These parent-owned delivery conditions remain open.

## Quality Gate Focus

The parent should use final delivered hashes, verify the distinction between isolated mutation RED and production RED, and inspect the CI omission failure independently of generator success. Verify the untouched eight registrations and unrelated invariant keys. This author report does not evaluate its own independent review or formal quality outcome.

## Working Notes

No delegated investigations or live reviewer activity. Report validation uses the admitted plugins/sdd-implementation/scripts/validate-implementation-report.sh and is a schema check, not quality-gate approval. Schema validation exited 0 with IMPLEMENTATION_REPORT_OK. Exact validator results are packaged as report-validation.json and bound to final report bytes by delivery-index.json. Original high-risk preflight and error diagnostics remain separate immutable evidence files.

## Session Handoff

- **Current Status**: In Progress
- **Next Action**: Parent receives the completed implementation artifacts, applies its own source delivery checks, and owns independent review, formal quality gate and lifecycle transitions.
- **Unresolved Items**: Windows, installed-host activation, independent review, quality gate, CI and merge NOT RUN; no task status changed by this implementation context.
"""
(work/'reports/implementation/shared-review-launch-repair/T-003.md').write_text(report)
print('Implementation report v2 assembled:',len(files),'declared outputs.')
