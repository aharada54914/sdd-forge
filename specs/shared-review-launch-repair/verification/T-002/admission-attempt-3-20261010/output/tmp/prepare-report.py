from pathlib import Path
import json, hashlib, sys
out=Path(__file__).resolve().parents[1]; w=out/'work'
eRel='specs/shared-review-launch-repair/verification/T-002/native-revalidation-attempt-3-20261010'; e=w/eRel
rp='reports/implementation/shared-review-launch-repair/T-002.md'
m=json.loads((out.parent/'manifest.json').read_text()); h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
paths={r['path'] for r in m['allowed_inputs'] if r['path']!=rp}
paths.update(str(p.relative_to(w)) for p in e.iterdir() if p.is_file())
assert rp not in paths
rows=[{'path':p,'sha256':h(w/p)} for p in sorted(paths)]
table='\n'.join('| `'+r['path']+'` | `'+r['sha256']+'` |' for r in rows)
summary=json.loads((e/'execution-summary.json').read_text())
specs='\n'.join('| `'+p+'` | `'+v+'` |' for p,v in summary['spec_revision'].items())
validation='NOT RUN: report validator has not yet been executed.'
if (e/'report-validation.json').exists():
 v=json.loads((e/'report-validation.json').read_text()); validation=f"Actual report validator exit {v['exit_code']}; stdout: `{(e/'report-validation.stdout.log').read_text().strip()}`. Full command/cwd/exit and stdout/stderr are in `{eRel}/report-validation.json` and its log siblings. This validates report structure, not independent task acceptance."
text=f"""# Implementation Report: T-002

- Task ID: T-002
- Model: gpt-6-astra
- Effort: high

Report Schema: implementation-report/v2
Run ID: {m['run_id']}
Task Attempt Count: 3

**Snapshot Notice**: This report records the admitted attempt-3 snapshot and this native revalidation run only. It does not certify current owner-tree state, historical chronology beyond admitted records, or a quality-gate verdict. Parent-owned independent evaluation is authoritative for gate-time acceptance.

## Target

Approved shared-review-launch-repair T-002, REQ-004/REQ-005, AC-004/AC-005, risk high, required workflow tdd. The admitted tasks.md records T-002 Planned/Approved and dependency T-005 Done. No lifecycle field was changed. User authorized existing-candidate revalidation and final report preparation only, with no production changes.

Admission: `{out.parent/'manifest.json'}`, SHA-256 `8967a982af35b8ea99fa2c6285bcf4d4f3706a26c4b0f66080fd8e9cd5ecf564`. Caller reported prepare-task-snapshot and validate-task-input-manifest: TASK_INPUT_OK; this implementer independently verified all 218 admitted hashes before reading source content. Caller admission was not independently re-created or reserved.

## Summary

The unchanged candidate passed the existing native hash-parity, traceability-freeze, downstream-precheck parity and admitted unreadable-equivalence checks on macOS with PowerShell. Traceability initially exited 1 because the restricted runtime PATH omitted iconv; one harness-only correction added actual installed iconv/rmdir executables, and the retry exited 0. Both logs remain evidence. This environmental failure is not product RED.

No product, test source, registry, task or frozen artifact bytes were changed in the delivered work copy. Existing tests temporarily generate their own fixtures; downstream parity restored its temporary registry edit, verified by pinned hash after execution. All 45 admitted registered directories exist, and the registry content is unchanged. All 217 authorized source modes were restored and verified; source-modes.json itself has no self-referential mode entry.

## Files Changed

Only this newly authored output report, native verification records/logs and scratch execution helpers were created. The old incomplete report remains byte-identical in the read-only snapshot and is preserved at `{eRel}/old-incomplete-report.md` (SHA-256 `c82f33515dfcfdf425543b2e67f4b7085edd438be6c0dfa64baedd585cd99bbd`). The canonical report here is an output artifact, not a mutation of the old owner report.

Scope inspected: AGENTS freeze rule, shared review-hash-normalization.ps1, impl/task PowerShell precheck callers, Bash/PowerShell context validators, their existing hash/traceability/downstream tests, admitted workflow-state-integrity fixture specs and historical review files, registry topology, report template/validator. No new API, export, config, dependency, source behavior or feature was introduced. Production data and callers receive no change from this run.

## Tests Added Or Updated

None. Reused all admitted test sources unchanged, including unreadable-equivalence.ps1. The execution-only Python helpers expose installed runtimes, capture commands and logs, and place scratch under `{out/'tmp'}`. They do not replace tested source or reconstruct historical RED. Existing tests' own fixture generation remains unchanged. Workflow-state-integrity historical review files are fixture inputs only; their historic verdicts are not T-002 acceptance evidence.

## Outputs

Complete explicit inventory of the manifest-listed work copies (except this report's self-hash), preserved old report and newly produced evidence. Rows for existing source/spec/test files bind their unchanged bytes, not authored changes. Historical reviewer artifacts are fixture-only and do not authorize reuse of prior verdicts or independent-review contamination; the parent must construct the separate evaluator admission boundary. Source/test/spec maps are also in execution-summary.json, and the original 218-input inventory is in input-hashes.json. Disposable tmp files are scratch, not acceptance outputs. delivery-index.json, outside work, binds this report separately and avoids a self-hash cycle.

| Path | SHA-256 |
|---|---|
{table}

## Test Evidence

- **Test Command**: `rtk proxy python3 -B tmp/run-native.py` from absolute native output cwd; exact per-suite commands, work cwd, exit codes and full stdout/stderr paths are persisted in commands.json.
- **Test Result**: PASS
- **Test Evidence Path**: {eRel}/commands.json

PASS is limited to the four completed behavioral suites' final exit codes, not formal evaluation or all Done When clauses. commands.json retains the initial failed traceability execution as well. Native shell login=false; subprocess test cwd is `{w}`. TMPDIR, TMP, TEMP and TMPPREFIX point under `{out/'tmp'}`. Runtime environment and executable paths are recorded in environment.json and environment-retry-1.json. Git was unavailable on the test PATH; no Git/status/ledger/history/network/owner-source operations were performed. Existing checker no-Git fixture handling is used, so these runs do not validate historical plugin paths against a Git baseline.

### Acceptance mapping

| Requirement / AC | TEST-ID | Exact assertion and current evidence |
|---|---|---|
| REQ-004 / AC-004 | TEST-007 | Persisted Shell and PowerShell twins accept each of Planned, In Progress, Implementation Complete, Done, Blocked for only the REQ final-status cell; traceability-freeze retry stdout/stderr. |
| REQ-004 / AC-004 | TEST-008a | Both twins reject Delivered and case-variant done via stage-provenance. |
| REQ-004 / AC-004 | TEST-008b | Both twins reject annotated Done (verified). |
| REQ-004 / AC-004 | TEST-008c | Both twins reject mutation of the Evidence cell. |
| REQ-004 / AC-004 | TEST-008d | Both twins reject appended non-status body text. This is the body-change assertion, not the separate raw prelaunch test. |
| REQ-005 / AC-005 | TEST-009 | Frozen pre-extraction recipe and helper match for LF, CRLF and mixed endings, including explicit impl-status LF/CRLF; hash-parity log. |
| REQ-005 / AC-005 | TEST-010a | Recipe equality for malformed, empty and missing-field contents; both reject empty/missing paths. Supplemental real existing-file exclusive-lock test reports System.IO.IOException for both, verifies read recovery and unchanged bytes after release. |
| REQ-005 / AC-005 | TEST-010b | Mis-cased key/value parity and raw digest for mis-cased key; existing caller-specific stage checks remain in callers; downstream Shell/PowerShell precheck semantic parity exits 0. |

Additional boundary control: test_raw_prelaunch_binding_twins accepts unchanged raw task inputs and rejects status-only Planned-to-Done mutation after precheck in Bash and PowerShell with `traceability review input changed after precheck`. Persisted normalized acceptance does not weaken raw prelaunch binding. The current hash suite has ten content cases and caller structural checks. Stage-specific status validation and reviewed hash parameters remain in their original prechecks; the shared helper performs only the existing hash recipe. This is not a newly authored full-parity port or a claim of exhaustive OS behavior.

### High-risk evidence preflight

No implementation editing occurred in this run. This report documents the current evidence/counterpart/mismatch matrix without backdating it to the historical implementation. No new persisted product field or verdict contract was added.

| Persisted field / claim | Sibling counterpart | Existing mismatch test / check |
|---|---|---|
| Persisted normalized REQ final-status digest | WFI-030, AC-004, TEST-007/008a-d | Accepted five statuses; reject unknown, annotated, Evidence and body mutations in both runtimes. |
| Raw prelaunch traceability digest | task-review precheck raw input pins and context-set checks | Raw prelaunch twins reject status-only post-precheck mutation. |
| Reviewed PowerShell digest | Both callers and frozen old recipe, AC-005 | Ten content cases compare exact lowercase hashes; mis-cased key stays raw; empty/missing/exclusively locked file failures agree. |
| Recorded source/spec/test identities and modes | Input manifest and source-modes.json | Exact hash/mode assertions fail on mismatch; source-integrity.json records all comparisons. This is current integrity verification, not historical product RED. |
| Native evidence results and report inventory | Captured process exits/full logs, Outputs and delivery-index | Report validator plus independent deterministic row/hash readback; final report hash is bound externally only. |

### Spec revision and hashes

spec_revision means this exact admitted artifact hash map, not an unverified Git commit. Source and test hash maps are explicitly in execution-summary.json and all mapped paths are inventoried above. No current Git revision was read.

| Artifact | SHA-256 |
|---|---|
{specs}

## Iteration And Escalation

- **Task Attempt Count**: 3
- **Escalation Prior Tier**: None
- **Escalation Next Tier**: None
- **Escalation Failure Class**: None
- **Escalation Attempt Number**: None
- **Escalation Reason**: None

Attempt count is caller-assigned. One local harness repair corrected the runtime PATH omission; it was neither a product change nor a model escalation. Initial exit 1 and retry exit 0 are both retained. Historical source/test failure sequences are not recounted as new attempt-3 failures.

## Isolation Evidence

- **Scratch Root**: {out}
- **Run ID**: {m['run_id']}
- **Session ID**: {m['session_id']}
- **Agent Instance ID**: {m['agent_instance_id']}
- **Isolation Mode**: fresh-agent
- **Fallback Reason**: None
- **Handoff Reload Evidence Hash**: None

Model gpt-6-astra, effort high, tier strong, provider openai are the supplied native identity, not independently observed billing/model metadata. Fresh-agent describes the admitted launch. Context compaction occurred during this native run; it is not evidence of compaction-free isolation. The admitted delegation policy lines 58-60 require a Session Handoff and ending the session on compaction. Higher-priority host instructions require continuation across compaction, so requested artifact preparation was completed with this explicit limitation. No incapable-host fallback or new identity is invented. Parent disposition of the skill continuity condition remains unresolved even if the structural report validator accepts these fields.

Only manifest-explicit snapshot files were copied, individually, after all hash checks; no recursive snapshot acquisition or extra owner discovery. Registered topology came solely from admitted registry-topology.json. All writes are under the sole output root. No source snapshot writes, agents, reservations or owner mutations occurred.

## Regression Tests Run

| Check | Actual exit | Evidence |
|---|---|---|
| hash parity | 0 | hash-parity.stdout.log / stderr.log |
| traceability-freeze initial | 1 | traceability-freeze.stdout.log / stderr.log; iconv absent from harness PATH |
| traceability-freeze retry | 0 | traceability-freeze-retry-1.stdout.log / stderr.log; 2 tests, both runtimes |
| downstream-precheck parity | 0 | downstream-parity.stdout.log / stderr.log |
| unreadable equivalence | 0 | unreadable-equivalence.stdout.log / stderr.log; IOException twins and recovery |

All listed logs live under `{eRel}`. Exact argv, commands, cwd, timestamps and exit values are in commands.json. Runtime version output is retained; this is native macOS PowerShell, not native Windows. The earlier historical downstream fixture failure due to omitted registered directories remains a historical failure; this complete-topology run does not rewrite it.

Report validation: {validation}

## Historical RED And Rollback Provenance

Admitted historical-red-recovery-20261010.md records original Oct 6 extraction chronology: test added 16:02:24, structural failure at 16:02:27 (`impl must load the shared hash recipe, not define its own`), helper extraction 16:02:36, success 16:02:38. This authentic RED concerns duplicated-function structure only. It does not demonstrate a pre-fix digest defect or product RED for every output. Current helper bytes match admitted historical helper hash `06c8e58f2256f6b8c2ff698a73e6d1308caf5ab73ec2e20e7c8074ea8d991e42`; the current test's two additional impl-status cases are identified in that record. No archived session or Git history was read and no RED was regenerated. The historical addendum supersedes only the earlier historical inspection statement that authentic extraction RED had not been located.

Historical traceability failures were fixture errors (missing Evidence cell / feature setup), not product RED. RT-20261009-001's exception applies only to T-001 and is not extended here. Current checks establish unchanged behavior; they do not establish historical TDD chronology.

Admitted current-restoration-z04ertpw records bind eight dirty-candidate file hashes before mutation and after restoration; before-hashes.json and restored-hashes.json both hash to `a9e1ba2fcc6a3fe6a6500a045ed17a918d2357d150eb574eef44229a1151102b`, with all eight mutated values different. They record primary suites before/after and a historical downstream fixture failure. This is restoration of then-current dirty bytes, not installed baseline rollback, trusted installed provenance, or exact pre-fix rollback. No new restoration experiment was performed because the user admitted this history and requested unchanged-source revalidation. Historical inspection, independent-verification and independent-diff-review are prior records only, not new independent evaluation.

## Specification Differences

None authored. Requirements, design, acceptance tests, all layers, tasks, traceability, AGENTS.md and registry retain their admitted hashes. No normalized-field carve-out was used to justify a mutation. The new report is a non-frozen addendum. Generic implement-task mutations, Git/status checks, delegation, structure discovery and reservations were not executed because the explicit manifest-only/report-only scope excludes them. No missing test input was encountered after complete admitted fixture/topology preparation.

## Unresolved Items

There is no remaining executable-test or missing-input blocker in this admitted run. Formal acceptance remains unresolved: the parent must evaluate narrow structural RED versus the task's TDD/evidence requirement and the context-compaction continuity limitation. Do not infer all-output product RED or a T-002 exception from T-001 authorization. Current independent diff review, quality contract, reservations and formal verdict are parent responsibilities and NOT RUN here. Native installed rollback/trust, Windows and final-head CI are NOT RUN; T-004 owns integrated delivery. No formal PASS, Implementation Complete task transition or Done is claimed.

## Quality Gate Focus

Check exact AC/TEST mapping (especially TEST-008d body change versus separate raw boundary), final source/test/spec pins, complete explicit inventory, honest first-run environment failure, real unreadable-file equivalence, narrow historical chronology and rollback scope. Resolve continuity policy separately from report-schema validation. Treat workflow-state-integrity historical review documents only as fixture data. Parent must admit evaluator inputs independently and must not promote historical review results to current acceptance.

## Working Notes

Admitted implement-task, its three references, template, task/spec Must Read, old incomplete report and T-002 evidence were read. No delegation or evaluation was conducted. Native commands use rtk proxy with login=false; scratch and TMPPREFIX are output-scoped. No owner reads, memories, history, network, Git/status operations, commit, push, PR, installation or production edits. Modes were restored only for disposable work copies as authorized. source-integrity.json records post-test, pre-report preservation; delivery-index.json records final report and evidence hashes and final source readback.

## Session Handoff

- **Current Status**: In Progress
- **Next Action**: Parent performs independent admission/evaluation, resolves historical RED and context-continuity limitations, and owns formal quality contract/verdict/reservations and any task transition.
- **Unresolved Items**: Parent formal evidence acceptance, continuity disposition, independent review/evaluation and T-004 integrated delivery; no missing admitted input or remaining failing behavioral suite.

This handoff status describes remaining formal workflow, not a write to tasks.md. Only quality-gate may set Done.
"""
(w/rp).write_text(text)
(out/'tmp/report-output-rows.json').write_text(json.dumps(rows,indent=2)+'\n')
print('Prepared report with '+str(len(rows))+' explicit output rows; validator evidence '+('included' if (e/'report-validation.json').exists() else 'pending'))
