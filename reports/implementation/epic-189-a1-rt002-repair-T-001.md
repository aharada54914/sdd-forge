# RT002 T-001 bounded host-denial repair

Task ID: T-001
Feature: epic-189-a1-rt002-repair
Run ID: rt002-t001-20260927-01a0e0a3
Task Attempt Count: 1
Status: In Progress; current evidence reconciled below; independent quality-gate pending

## Parent verification update — 2026-09-27

Inspected the completed original-path PowerShell logs: baseline `third-baseline-pwsh-20260927.log` ends with 199 PASS / 211 FAIL; candidate `third-candidate-pwsh-20260927.log` ends with 410 PASS / 0 FAIL. Together with the recorded runner exits (baseline 1, candidate 0), both Bash and PowerShell supply the same genuine baseline RED / candidate GREEN evidence. This supersedes only the pending-total statements below, not their preserved historical records. The four focused assertions also pass on baseline and are not independently claimed as new TDD failures. No Windows, CI, independent quality-gate, implementation-complete or Done claim follows from these local results.

## High-risk preflight (before new implementation)

### Parent scoped review — 2026-09-27

Reviewed the complete current Python verifier, both original dispatcher wrappers, the focused `a2c56bcc^..a2c56bcc` regression diff, the shared loader's response/cleanup callers and the recorded original-path differential results. No defect found in this bounded diff: response schema dispatch cannot select cleanup behavior; duplicate members are rejected in the shared loader; the complete raw denial and its embedded nonce are matched without normalization; both legacy Write templates remain unchanged. PowerShell property counts explicitly materialize the property collection, while string assertions use case-sensitive comparison. This is scoped parent review, not independent quality-gate approval or a review of every unrelated dirty artifact.

Current feature workflow validation (`check-workflow-state.sh --feature epic-189-a1-rt002-repair`) and scoped `git diff --check` each exited 0. Native Windows, latest-head CI, independent quality gate, restoration-procedure evidence and merge/post-merge confirmation still require their own evidence. T-001 remains In Progress; no Done decision or parent Issue closure follows.

Risk is high; Required Workflow is tdd. These pairs are inherited from the reviewed security specification, not inferred from a passing suite count.

| Persisted field | Contract counterpart | Failing mismatch assertion |
|---|---|---|
| schema/runtime | Version selector and both Codex runtime values | TEST-002–009 and TEST-020–025 reject selector/runtime mismatch |
| nonce | Expected fresh nonce equals recorded and exactly echoed nonce | TEST-036–043 reject differing or malformed nonce |
| executed | Strict boolean nonexecution | TEST-013 and TEST-015–019 reject execution and wrong types |
| raw_result | Whole normative envelope and exact canary operation | TEST-031–035 and TEST-044–057 reject altered/truncated envelope |
| status/reason/exit | Actual accepted denial; invalid evidence is unavailable | Negative acceptance rows assert unavailable result and nonzero exit; TEST-089 is separate real activation |
| cleanup_status | Legacy cleanup predicate independent of response schema; cleanup never proves activation | TEST-070–080 reject invalid cleanup and explicitly check schema independence |

## Installer isolation result — 2026-09-27

The installer `--self-test` completed with exit 0: candidate apply, restore,
two hash-mismatch refusals and symbolic-link refusal passed in isolated temporary
files. See `specs/epic-189-a1-rt002-repair/verification/installer-isolation-20260927.md`.
No installed verifier or human backup was changed. This closes the isolated
restoration check only; Windows, independent quality verification, latest-head
CI and integration are not satisfied by it.

## Starting evidence

The pre-repair verifier in commit `c0aaf3a639f4cb4798b16acd115f0b05db44493f` hashes to `d9277ca516fa79b6ef459e0d0505375624a0a9279c32390758a96650985d0064`. The existing candidate checkpoint is `de3e5b64a5840afde385f2f721f7503b55e50c1d`; its current verifier hashes to `bb388dfba366a9f300f1c0060fa6282468d7a896dc7e72986f3bf3452f08c3d5`. Existing correct candidate code is not reported as newly written or as historical TDD.

Fresh installed activation is recorded in `specs/epic-189-a1-rt002-repair/verification/installed-host-activation-20260927.md` and its unchanged JSON capture: one native rejected dispatch, installed verification exit 0 and HOOK_ACTIVE, sentinel still absent. This does not prove Windows, another session, or any parent epic complete.

Reproduction, shared-loader diagnosis, caller impact, committed differential RED/GREEN and full regression logs must be appended before claiming implementation complete. No production change has been made in this task run. Historical verdicts and frozen specification bodies remain unchanged.

## Resume entry — 2026-09-27 / 01a0e0b5

Run identity for this continuation: `rt002-t001-20260927-01a0e0b5`; actual host session id `01a0e0b5-109e-7331-b348-f1e5eb72a7f3`, agent `/root/rt002_t001_resume`. Parent validated `verification/task-input-manifest-resume-20260927.json` with TASK_INPUT_OK and released immutable `/tmp/sdd-rt002-resume.FYpIb6/snapshot`. Initial actions read tasks.md and this report only. The high-risk preflight pairs above match the bound security specification; no new persisted field is introduced by the four focused assertions.

Installed original-path challenge emission returned nonce `06e777b8345cd32f6edd281163846749` (exit 0). One native apply_patch dispatch received the actual PreToolUse denial. Its unchanged envelope is recorded in `verification/child-host-activation-resume-20260927-01a0e0b5.json`. The installed verifier with `--verify-response --runtime codex-cli --nonce 06e777b8345cd32f6edd281163846749 --recorded-result <capture>` returned HOOK_ACTIVE, exit 0. The first verification used an incorrect `--response-file` argument and exited 2; correcting the verification argument did not redispatch the canary. `test ! -e sdd/.hook-canary-sentinel` exited 0; installed SHA256 remains `bb388dfba366a9f300f1c0060fa6282468d7a896dc7e72986f3bf3452f08c3d5`.

Source/caller diagnosis (before any production edit): baseline commit `c0aaf3a639f4cb4798b16acd115f0b05db44493f` has no schema selector in `run_verify_response`; a five-field host capture reaches `_verify_codex_cli` and fails missing legacy flags. Its `_load_json_object` uses ordinary `json.loads`, accepting last-value duplicate members; both `run_verify_response` and `run_confirm_cleanup` call that loader. Candidate snapshot lines 271–285, 413–424 and 453–471 already reject duplicate members in the shared loader and restrict schema dispatch to response verification. Challenge generation routes `run_emit_challenge` through `build_challenge` (218–253), preserving complete Claude/Copilot Write templates. Missing TEST-079/080/084/085 are direct-assertion gaps for already-correct candidate behavior; they are not newly discovered production defects. Actual original-path differential reproduction remains pending; no historical RED is asserted from this source inspection.

## Session Handoff — 2026-09-27

### Fresh two-envelope child terminal handoff — 2026-09-28, 01a0e7fd

Continuation agent `/root/rt002_two_envelope_fresh_sep28`, actual host thread
`01a0e7fd-b8ae-7f80-8745-53a813802526`, run
`rt002-t001-20260928-01a0e7fd`. Host session metadata is
`/Users/jrmag/.codex/sessions/2026/09/28/rollout-2026-09-28T21-29-19-01a0e7fd-b8ae-7f80-8745-53a813802526.jsonl`.
The inherited `CODEX_SESSION_ID` is
`01a06d01-11b5-7bd3-83a3-7e29bb3c96cd`; it is not the fresh child thread
identity. No separate `agent_instance_id` metadata field was found; the fresh
packet binds the child instance to the actual thread identity above.

The first operation fully read the current task plan and implementation report.
Required implement-task policies and root AGENTS were read. Parent reported
batch, snapshot and single-task validation as `TASK_INPUT_OK` for
`specs/epic-189-a1-rt002-repair/verification/task-input-manifest-resume-20260928.json`,
with immutable snapshot `/tmp/rt002-task-inputs-sep28.T20fV1/snapshot/sdd-forge`.
The packet was read; `rtk proxy bash scripts/check-sdd-structure.sh` exited 0
with `check-sdd-structure: OK` before snapshot specification reads.

Snapshot requirements, design, acceptance tests, traceability, layer specs,
ticket, recovery contract, Python verifier, wrappers, native capture and prior
activation/handoff/capability evidence were inspected. Combined full-suite
output was truncated; targeted follow-up reads did not establish a complete
read of both test suites. The next fresh implementer must read both original
test files completely, rather than relying on this investigation.

The unchanged Python verifier requires the exact `Script error:\n` prefix in
`HOST_DENIAL_PREFIX` and fullmatches that prefix plus the nonce-bound patch.
The recorded native denial lacks that literal prefix. Its packet-bound SHA256
is `3c10d62c7714fc69d804d859b66a0b5e02591422ede80e06f18687ecaa68c864`.
Current packet-bound original suite hashes are Bash
`39463abc5464117cdc9e7ab6803652a061ec40b19af618fc30c0d78ffddc3403`
and PowerShell
`e0d2de1b1a9200d2634e5b377e32b4ddb4c22cf5648c3f4f5cd1f4457f963055`;
do not substitute the earlier integration hashes.

No contract candidate, additional high-risk mismatch preflight, test edit,
new regression RED/GREEN, production change, installed change, frozen input
change, lifecycle/approval change, Git operation or native redispatch was
performed. The sole mutation in this continuation is this handoff entry.
Existing unrelated dirty changes are preserved. The structure check is not
implementation or activation evidence.

Context compaction occurred. Installed implement-task
`references/agent-delegation-policy.md`, Context Hygiene, requires recording
state and ending the session; it forbids implementation from compacted context.
Parent must launch a fresh independent implementer with a newly validated
packet incorporating this report's new hash. Remaining authorized first stage:
prepare bounded exact-two-envelope contract candidates and high-risk mismatch
preflight under `verification/T-001/two-envelope-extra1-20260928/`, add minimal
named regressions to both existing suites, and save measured RED against the
unchanged Python in that same scratch. Preserve fullmatch and all nonce,
guard, operation, newline, field and rejection boundaries. Parent review and
limited test checkpoint commit must precede production release. Formal frozen
contract re-review, genuine installed native activation, independent quality
verification and lifecycle decisions remain unresolved and parent-owned.

### Two-native-envelope investigation handoff — 2026-09-28

Continuation identity: `rt002-two-envelope-investigation-20260928`, agent
`/root/rt002_two_envelope_repair`. This is an investigation handoff, not a new
task attempt, gate verdict, implementation-complete claim or native activation
claim. Prior attempts, grants and historical evidence below remain unchanged.
The human-authorized additional scope is the exact two-native-envelope contract,
the shared verifier, both existing regression suites and formal re-review input
preparation; it does not authorize installed-cache writes or a denied-operation
bypass.

The unchanged current native capture is
`specs/epic-189-a1-rt002-repair/verification/T-001/native-resume-preflight/b36a468b489e145ed538d74f7b993c31/recorded-result.json`,
SHA256 `3c10d62c7714fc69d804d859b66a0b5e02591422ede80e06f18687ecaa68c864`.
Its nonce is `b36a468b489e145ed538d74f7b993c31`, executed is strict `false`,
and its complete native raw result begins `Command blocked by PreToolUse hook: `,
without the frozen contract's `Script error:\n` prefix. The exact guard text,
nonce-bound canary patch and absent terminal newline were inspected in the saved
file. No raw-result normalization, fabricated plugin-origin field or native
canary redispatch was performed.

Reproduction used PR528 integration HEAD
`a7cb83d3d3200ecb9a6f55cd2662fbce6bb7cae3` and its original Bash wrapper:
`bash plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.sh --verify-response --runtime codex-cli --nonce b36a468b489e145ed538d74f7b993c31 --recorded-result <unchanged-capture>`.
It returned exit 64, `CAPABILITY_RUNTIME_UNAVAILABLE`, reason
`UNRECOGNIZED_RESULT`, and stderr `host-denial envelope or operation does not match`.
The current shared verifier SHA256 is
`bb388dfba366a9f300f1c0060fa6282468d7a896dc7e72986f3bf3452f08c3d5`;
the installed verifier was not changed. The current Bash and PowerShell suite
hashes are respectively
`4d246e61042efd790831ea9eccbb16b3a7eb2df52f341d59d09ad71142e070de`
and `12580e2d000e51c25e5415579d2c397cfe3ccf095a3aaf8b90a35b8234761a33`.

Source diagnosis: `HOST_DENIAL_PREFIX` includes the mandatory prefix and
`_verify_codex_host_denial` fullmatches its escaped concatenation with the
nonce-bound patch. The exact saved capture therefore fails this shared predicate.
The planned minimal change permits only the one exact optional
`Script error:\n` literal before that complete envelope, using a noncapturing
group so the nonce capture remains unchanged. Both complete strings remain
whole-string matches: no trimming, arbitrary wrapper, whitespace, newline,
extra operation, alternative guard text or plugin-origin assertion is allowed.
Both original wrapper implementations retain their common shared verifier route.
Caller inventory identified ship, bootstrap, bootstrap-interviewer, lite-spec
and lite-gate native challenge/verification entry points; suite/CI launchers
continue invoking the two original regression suite paths.

High-risk additional preflight, pending execution: persisted `raw_result` is
paired with the two exact normative native envelopes in the requirements,
acceptance tests, design and security contract. The current unchanged native
capture already demonstrates the failing positive mismatch above; before a
production edit, the same committed focused regressions must fail against the
current verifier and cover both positives plus wrong nonce, incorrect guard or
operation, every existing strict field case, malformed wrapper, extra text and
missing output. The existing schema/runtime, nonce, executed, verdict/exit and
cleanup counterpart entries remain required and are not weakened.

No implementation/test/frozen-artifact edit, focused RED/GREEN execution,
baseline differential execution, commit, staging or formal verdict was made in
this continuation. Integration checkout pre-existing untracked verification
artifacts were preserved. The available current differential baseline directory
was located but not yet inspected or executed. Required next steps are a fresh
validated input packet; reread current task/report and required policies;
prepare precise bounded frozen-document amendment candidates; add the same
synthetic two-envelope regressions to both original suites; obtain current
baseline RED, minimal shared fix GREEN and full original-suite results; then
parent-owned independent formal re-review and genuinely fresh installed native
activation. Fixture success cannot satisfy that activation.

Context compaction occurred. The installed implement-task
`references/agent-delegation-policy.md` lines 58–60 requires writing Session
Handoff and ending the session rather than implementing from a compacted
summary. This continuation ends here; lifecycle and remaining formal/native/CI
work remain parent-owned and unresolved.

### Third child continuation — 01a0e0bd

Run ID: rt002-t001-20260927-01a0e0bd
Actual host metadata: `/Users/jrmag/.codex/sessions/2026/09/27/rollout-2026-09-27T11-41-37-01a0e0bd-4b68-75d1-9125-924785c97474.jsonl`, `session_meta.payload.id=01a0e0bd-4b68-75d1-9125-924785c97474`, agent `/root/rt002_t001_third`. Parent validated `verification/task-input-manifest-third-20260927.json` and immutable snapshot `/tmp/sdd-rt002-third.s18GRH/snapshot/sdd-forge`. Bound tasks/report and required policy/specification inputs were reloaded before implementation. The high-risk field/counterpart/mismatch preflight above applies unchanged; no production field or code was added.

Installed original path `/Users/jrmag/.codex/plugins/cache/sdd-plugins/sdd-quality-loop/1.17.0/scripts/check-hook-activation-handshake.py`: initial challenge invocation incorrectly included `--runtime` and exited 2; corrected `--emit-challenge` exited 0 with nonce `1944db808d939f00ad63fd560f76caf4`. Exactly one native apply_patch was denied. Its unchanged raw envelope is in `verification/child-host-activation-third-20260927-01a0e0bd.json`; verification with `--verify-response --runtime codex-cli --nonce 1944db808d939f00ad63fd560f76caf4 --recorded-result <capture>` returned HOOK_ACTIVE / exit 0. Sentinel absence check exited 0. Installed hash is `bb388dfba366a9f300f1c0060fa6282468d7a896dc7e72986f3bf3452f08c3d5`. No canary redispatch or alternate executor occurred.

Prior child's four additions were reviewed. PowerShell `.PSObject.Properties.Count` enumerates per-property counts (`1,1` for a two-property object), so its `-eq 2` did not measure object size. Changed only the two counts to `@(...).Count`; direct check returned true. Focused regression commit `a2c56bcc` contains only both existing suites, 39 added lines, including TEST-079/080/084/085. No existing assertion was removed. No production edit was required yet.

Differential runner `verification/run-third-differential-20260927.sh` exports genuine baseline `c0aaf3a639f4cb4798b16acd115f0b05db44493f` to task scratch `/tmp/sdd-rt002-third-differential.0QPJNo`, then overlays only both committed original test paths from `a2c56bcc`. Both environments use their real original wrapper/verifier paths. Test SHA256s are identical: Bash `39463abc5464117cdc9e7ab6803652a061ec40b19af618fc30c0d78ffddc3403`, PowerShell `e0d2de1b1a9200d2634e5b377e32b4ddb4c22cf5648c3f4f5cd1f4457f963055`. Baseline verifier SHA256 `d9277ca516fa79b6ef459e0d0505375624a0a9279c32390758a96650985d0064`; candidate verifier SHA256 `bb388dfba366a9f300f1c0060fa6282468d7a896dc7e72986f3bf3452f08c3d5`. Execution results pending below; the old 401-assertion runs are not this evidence.

Environment: macOS Darwin 27.0.0 arm64, PowerShell 7.6.2. Candidate base HEAD was `2f996d16664e6b42d0c760c1dd36a53a7ba10768`; local origin/main was `96c040a6cf7644981f94956e0878092d0ac85c04` (no claim of remote refresh). Unrelated dirty changes were preserved. Native Windows, latest-head CI, scoped self-review, independent quality gate and lifecycle remain parent-owned and pending.

Actual differential reproduction: `rtk proxy bash /tmp/sdd-rt002-third-differential.0QPJNo/plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.sh --verify-response --runtime codex-cli --nonce 1944db808d939f00ad63fd560f76caf4 --recorded-result /Users/jrmag/sdd-forge/specs/epic-189-a1-rt002-repair/verification/child-host-activation-third-20260927-01a0e0bd.json` exits 65 / CAPABILITY_RUNTIME_UNAVAILABLE / PLUGIN_HOOKS_DISABLED. The candidate original wrapper, using the same capture and nonce, exits 0 / HOOK_ACTIVE. The baseline `run_verify_response` at lines 365–371 has no schema dispatch and reaches `_verify_codex_cli`, which demands absent legacy plugin flags. Its shared loader at lines 247–264 calls plain `json.loads`, so duplicate members use their last value; both response and cleanup callers are affected. Candidate loader lines 262–285 rejects duplicates at every depth; response lines 413–424 owns schema selection; cleanup lines 453–471 retains its independent predicate. Challenge `run_emit_challenge` → `build_challenge` preserves the two legacy templates while candidate `_codex_canary_patch` binds the nonce. This confirms the prior root-cause diagnosis without changing production.

Bash original full-suite differential: baseline exit 1, 199 PASS / 211 FAIL (`verification/third-baseline-bash-20260927.log`); candidate 410 PASS / 0 FAIL (`verification/third-candidate-bash-20260927.log`, process exit pending runner wait). Baseline explicitly fails nonce-bound emitted patch, schema rejection, duplicate responses and duplicate cleanup; valid legacy runtime positives remain PASS. TEST-079/080/084/085 pass in both baseline and candidate: those additions verify existing correct behavior and do not independently claim historical TDD. The same committed complete suite supplies genuine differential RED for the bounded repair and candidate GREEN; no controlled source mutation was used. PowerShell results remain pending.

### Third child terminal handoff — context compaction

Context compaction occurred in `/root/rt002_t001_third`, actual host session `01a0e0bd-4b68-75d1-9125-924785c97474`. The installed implement-task Context Hygiene rule requires saving state and ending this session; no implementation is continued from the compacted summary. The runner has now completed: baseline Bash exit 1, baseline PowerShell exit 1, candidate Bash exit 0, candidate PowerShell exit 0. This supersedes the pending process-exit statements above. Bash totals were inspected as 199 PASS / 211 FAIL at baseline and 410 PASS / 0 FAIL at candidate. Final PowerShell assertion totals have not yet been inspected; only its completed process exits are claimed here. All four full logs remain in this feature's verification directory under `third-{baseline,candidate}-{bash,pwsh}-20260927.log`. Scratch `/tmp/sdd-rt002-third-differential.0QPJNo` is preserved.

Authorized scoped regression commit `a2c56bcc` contains only the two original test suites, including the corrected PowerShell property counting. No new production edit, push, PR, merge, task status mutation or Done decision was made. No protected-operation denial was bypassed. Parent must inspect final PowerShell totals, perform remaining scoped self-review/provenance/report finalization and independent quality verification; native Windows and latest-head CI remain pending. If further implementation is needed, use a fresh session and newly validated hash-bound input packet, rereading the current task and report rather than this compacted context.

### Second child handoff — 01a0e0b5

Context compaction occurred in continuation `/root/rt002_t001_resume`, host session `01a0e0b5-109e-7331-b348-f1e5eb72a7f3`; the implement-task Context Hygiene rule requires ending rather than implementing from a compacted summary. Reconstruct the next continuation from tasks, this report and a newly validated hash-bound packet. The current packet was `specs/epic-189-a1-rt002-repair/verification/task-input-manifest-resume-20260927.json`, immutable snapshot `/tmp/sdd-rt002-resume.FYpIb6/snapshot`.

This continuation added the missing four direct assertions to both original suites: TEST-079/080 assert cleanup schema independence and cleanup/capability outcomes; TEST-084/085 assert complete unchanged Claude/Copilot challenge templates. Changes are uncommitted and UNTESTED. The scoped diff summary was 16 added Bash lines and 23 added PowerShell lines. No production edit, differential reproduction, regression execution or commit occurred in this continuation. Re-read and verify the new PowerShell property-count assertions before relying on them. Parent separately reported the unmodified suites each passing 401 assertions; those runs are not the committed differential RED/GREEN proof for these additions.

Fresh child native activation and source diagnosis are recorded in the Resume entry above. The sentinel-absence check and installed-verifier hash check both succeeded in this continuation. Preserve the prior child's historical handoff below. Next fresh continuation must inspect the current focused diff, validate both additions, commit only authorized focused regressions, then run the same committed regressions at original paths against genuine baseline `c0aaf3a639f4cb4798b16acd115f0b05db44493f` (RED) and existing candidate (GREEN), and run both full suites. No extra production fix is required if those prove the existing candidate correct. Parent owns lifecycle edits, self-review, independent quality gate and latest-head CI; no push, PR, merge or Done authority is granted here.

This fresh child session (`01a0e0a3-f62d-7843-971d-8d0bc025bd23`, agent path `/root/rt002_t001_impl`) ends before implementation because context compaction occurred. The installed implement-task `references/agent-delegation-policy.md`, Context Hygiene, requires persisting state and ending the session after compaction; it forbids summary-based continuation. Task status remains parent-owned; this is not Implementation Complete or a Done decision.

The parent supplied verified input manifest `/tmp/sdd-rt002-task-input.WvEZ7d/task-input-manifest.json` and read-only snapshot `/tmp/sdd-rt002-task-input.WvEZ7d/snapshot`. Subsequent implementation must reconstruct scope from that packet, tasks and this report, not this session's compacted conversation. Only the declared output paths are writable. All shell calls used `rtk proxy` with login disabled. No Gemini invocation, commit, push, PR, production edit or test edit occurred.

Fresh native activation for this child used installed original verifier `/Users/jrmag/.codex/plugins/cache/sdd-plugins/sdd-quality-loop/1.17.0/scripts/check-hook-activation-handshake.py`. Emit-challenge exited 0 with nonce `6b69cc9db044d6413ab621997f1277a8`; its exact canary apply_patch was dispatched once and rejected by PreToolUse. No alternate execution path retried that rejected operation. Exact five-field denial JSON is persisted in `specs/epic-189-a1-rt002-repair/verification/child-host-activation-20260927-01a0e0a3.json`. Installed verification with codex-cli and that nonce returned HOOK_ACTIVE, exit 0. The child's sentinel-absence and installed-hash checks remain unperformed; do not infer them from the parent's independent activation.

Investigation is incomplete and unverified: candidate source inspected so far shows `_load_json_object` using duplicate-member rejection and callers `run_verify_response` and `run_confirm_cleanup`; cleanup appears independent of the response schema selector. Original Bash and PowerShell suite bodies were inspected; missing focused regressions to add are TEST-079/080 (cleanup schema independence) and TEST-084/085 (complete unchanged Claude/Copilot challenge templates). No reproduction, differential RED/GREEN, full suite run or self-review has yet occurred. Re-read relevant source before relying on this partial observation.

Next fresh session must preserve unrelated dirty working-tree changes; complete source/caller diagnosis and reproduction; add only the four missing regressions to both original suites; obey any actual protected-file edit rejection without bypass; commit authorized focused regressions before a new shared fix; demonstrate committed regressions RED against genuine baseline `c0aaf3a639f4cb4798b16acd115f0b05db44493f` and GREEN against candidate at original paths; run full Bash and PowerShell suites and report bounded results. Windows/latest-head CI and independent quality verification remain parent-level obligations. Scoped commit authority is documented in the handoff; push/PR/merge/Done are not authorized.

### Two-envelope child Session Handoff — 2026-09-29

Agent: `/root/rt002_two_envelope_finish`. The parent authorized this bounded extra two-envelope trial and scoped commit/push/PR integration. No implementation or test edit, regression execution, staging, commit or push occurred in this child. T-001 remains Approved / In Progress; T-002 remains Draft / Planned. Root unrelated changes and the integration checkout's six pre-existing untracked verification artifacts were preserved.

Confirmed current shared verifier SHA256 is `bb388dfba366a9f300f1c0060fa6282468d7a896dc7e72986f3bf3452f08c3d5`. Its anchored predicate requires the exact `Script error:\n` prefix. The saved `native-resume-preflight/b36a468b489e145ed538d74f7b993c31/recorded-result.json` instead begins with the complete bare `Command blocked by PreToolUse hook: ` envelope. The separate preserved original baseline verifier SHA256 is `d9277ca516fa79b6ef459e0d0505375624a0a9279c32390758a96650985d0064`. PR528 integration branch `codex/rt002-host-denial-repair` was at `a7cb83d3d3200ecb9a6f55cd2662fbce6bb7cae3`; its tracked files were clean.

Required next work is unchanged: complete the additional high-risk raw-result counterpart/mismatch preflight; add meaningful TEST-090/091 positives and TEST-092..097 malformed-envelope negatives to both original suites, applying the versioned field/body negative matrix independently to both exact envelopes; commit focused regressions and execute genuine original-path baseline RED; minimally make only the exact literal prefix optional via a noncapturing group while preserving whole-string fullmatch and the sole nonce capture; execute both full original suites GREEN. Fixture results must remain separate from fresh installed native activation, independent formal verification, native Windows and latest-head CI obligations. No protected installer/hook may be bypassed or rejected operation retried through an alternate executor.

Context compaction occurred during required source/specification/policy inspection. The installed `implement-task/references/agent-delegation-policy.md` Context Hygiene instruction was reread: after compaction persist this handoff and end the session without relying on the summary. This child stops accordingly; no new successful test, live activation, review verdict or lifecycle completion is claimed.

## Two-envelope evidence reconciliation — 2026-10-02

This addendum updates only evidence. Earlier handoffs remain historical. T-001 remains Approved / In Progress; this is neither Implementation Complete nor an independent quality-gate verdict.

The committed two-envelope regression at `6aa67116af3b7c8609767df4ee367f8741254811` precedes the shared-verifier fix at `ed936b69c15cb9fdeb9d6d4caa9d1975f54d0587` in Git ancestry. Against pre-fix verifier SHA-256 `bb388dfba366a9f300f1c0060fa6282468d7a896dc7e72986f3bf3452f08c3d5`, both original-path full-suite RED logs show the same four failed assertions: TEST-090 bare-denial exit and status, and bare echoed-nonce mismatch exit and reason. The RED suite SHA-256 values in `red-pinned-handoff.md` are Bash `0b5417b86553ebe9001f8ac1871930378330e74289adb65eab8c92148855000c` and PowerShell `e61f786b18d59a0a764cae70fe223153d360f25b80be246b7d44802962ac8103`. The retained raw-log SHA-256 values are respectively `e8361f4975b2bcdf1cc9fa0d262690e2481dea583bdd6d15fcb2c762a8d706e5` (980 PASS / 4 FAIL) and `7037c9c4d9bbb749db636045553aea433514083bc287c7760060ec2a46ccbb0e` (981 PASS / 4 FAIL). The handoff, not the raw logs, records exit 1 for both. The separately refused focused command was not executed and is not attributed as this RED evidence.

The applied shared verifier SHA-256 is `1057d1fcd1a8307c1fe55b961f3b37af2576683887f1c4ec2ce5138065e8fe0d`. Retained original-dispatcher GREEN log SHA-256 values are Bash `b4d5f30b7c0ea192ec922ba99c95f2cfbd0fa13afd070674b7a740e5ecc14c2d` (984 PASS / 0 FAIL) and PowerShell `ac17a42fe793e87d87f43f1f59d7637ccbbc52d0ccca638a33850706cd19c040` (985 PASS / 0 FAIL). `reports/verification/rt002-two-envelope-validation-20260929.md` records exit 0 for both; the raw logs independently confirm counts, not process exits. These were macOS Bash/PowerShell runs, not native Windows runs. The current Bash suite matches the RED Bash suite hash, while the current PowerShell suite hash is `49b537a37f1dbdab192b53b00147bf20377df9ecfe94283ac21f58c8073706cd` after later process-disposal changes; these logs are not fresh current-HEAD/full-current-suite executions.

The current installed-verifier observation is recorded in the integration checkout's `specs/epic-189-a1-rt002-repair/verification/T-001/native-20261002-f11bbd/observation.md`: one native denial, unchanged response, verification exit 0 / HOOK_ACTIVE. The installed hash was checked later as matching `1057d1...e0d`, but was not captured at dispatch time. A later sentinel-absence probe was refused before execution and was not rerouted. The older `prior.py` receipt belongs to the earlier candidate; no current-application backup/restore receipt was found in the inspected evidence. Current `spec_revision`, component coverage, task-scoped provenance, fresh independent evaluator activation and quality-gate decision remain open. The branch index and limits are in `specs/epic-189-a1-rt002-repair/verification/T-001-results.md` and the integration checkout's `reports/verification/rt002-t001-current-evidence-20261002.md`.

## Current-candidate reconciliation — 2026-10-02

This non-frozen addendum supersedes only stale *current-state* interpretations above, not the dated handoffs or their execution order. T-001 is Approved / In Progress; T-002 is Draft / Planned. The current owner candidate is PR #528 head `1e86fb272643e798db4e1ca0c89f0402317a2fc8`. Its source verifier and the installed verifier both hash to `1057d1fcd1a8307c1fe55b961f3b37af2576683887f1c4ec2ce5138065e8fe0d`. The current Bash and PowerShell suite hashes are `0b5417b86553ebe9001f8ac1871930378330e74289adb65eab8c92148855000c` and `49b537a37f1dbdab192b53b00147bf20377df9ecfe94283ac21f58c8073706cd` respectively. These identities and the current task/traceability inventory are recorded in `reports/verification/rt002-t001-current-evidence-20261002.md`.

The approved feature-spec source checkout's `requirements.md`, `design.md`, and `acceptance-tests.md`, concatenated in that order as specified by `generate-evidence-bundle.sh`, yield `spec_revision` SHA-256 `dd6c53d41ea62dd121f89aa49b218727e78a5614350dc571fb4302247fe709d3`. Their individual SHA-256 values are `b319feab9659915dfba970f371648325b9801ffa6aaa28b6acce47949f61997a`, `a0532e6d053ff9113c66d718e32ce7a2fea81d72e6608de8418a9e77adb54890`, and `a27a30070d6c024d9815ac20dfc06c70b1940f86b863047c70b48cce7fc550e9`. This is **source-checkout-derived provenance**, not yet a generated owner-worktree gate bundle or proof that the owner checkout contains the same feature-spec bytes. The relevant build/test environment for current regression evidence is macOS with Bash and PowerShell; native Windows handshake execution is not claimed.

The genuine two-envelope RED/GREEN ancestry, four RED assertion failures in each original suite, retained log hashes, and source-byte identities are detailed in the preceding addendum and `reports/verification/rt002-t001-current-evidence-20261002.md`. Unlike the older GREEN run, both current original drivers were rerun after the PowerShell disposal edit at this exact head: `bash tests/check-hook-activation-handshake.tests.sh` exited 0 with 984 PASS / 0 FAIL; `pwsh -NoLogo -NoProfile -File tests/check-hook-activation-handshake.tests.ps1` exited 0 with 985 PASS / 0 FAIL. Their retained output hashes are Bash `b4d5f30b7c0ea192ec922ba99c95f2cfbd0fa13afd070674b7a740e5ecc14c2d` and PowerShell `ac17a42fe793e87d87f43f1f59d7637ccbbc52d0ccca638a33850706cd19c040`. All 38 PR checks succeeded at this exact head (Actions run `36809330421`); the workflow skips these handshake steps on Windows, so CI is not native-Windows proof.

The fresh `verification/T-001/native-20261002-f11bbd/observation.md` records a nonce-bound, unchanged host response to **one actual native denied dispatch** and installed-verifier exit 0 / HOOK_ACTIVE. The current task's TEST-089 condition is met by that observation. The task does not require a dispatch-instant hash or a second physical sentinel probe; the latter was actually refused and was not rerouted. Fixture success alone was not used as native activation proof.

For restoration, a retained 29,144-byte mode-0600 backup and a second retained copy hash to the pre-current `bb388dfba366a9f300f1c0060fa6282468d7a896dc7e72986f3bf3452f08c3d5`, but available records do not link either copy to a receipt for the current installed-target application. The human-only helper at `reports/verification/rt002-bare-envelope-candidate-20260929/apply-human.py` was **subsequently** extended with `--restore BACKUP --installed`, pinning expected current and prior hashes, refusing hash mismatches and symlinks, and replacing regular files atomically. Its SHA-256 is `3ce86f7d4fb2da837ab4160cfeba33e98071cf6da8516f3718f675af1973e4f1`. The isolated `--self-test` exited 0 for restoration, two hash-mismatch refusals and two symlink refusals; retained log SHA-256 is `1f68c488567e0e608414302215fffcfcd8f4a142a2866b9384f68d4b99c72f26`. No real installed restoration occurred, and the helper's new command did not exist before the current application. Consequently, this does **not** retroactively prove the task's pre-application backup/restore-record condition. Because activation succeeded, the infra contract does not demand rolling back the working installed verifier just for evidence.

The remaining T-001 evidence work is to reconcile this source-derived provenance, current task-scoped traceability and component-coverage result into the non-frozen `verification/T-001-results.md`, and resolve or accurately record the historical pre-application receipt gap against the task's fourth Done When. The owner checkout currently contains only the native observation under this feature's `specs/` tree, not the source feature specifications or `T-001-results.md`; a formal gate there cannot consume this report alone. This report does not itself set Implementation Complete. `quality-gate` rejects a task before that status, and no independent evaluator, quality-gate PASS, Done, native-Windows run, or installed rollback is claimed here. No approval field, frozen specification, task status, or review verdict was changed.

## Limited restoration-criterion reconciliation — 2026-10-03

The human-authorized T-001 Done When 4 amendment in source `tasks.md` (SHA-256 `75d0e1d8a837ef22ea6d6df4e90d57c6328a87828205c668de4bd26b6a0fe696` at this read) asks for a current-hash-pinned permitted restoration procedure, retained prior-hash backup, and successful isolated restoration/refusal tests. It expressly leaves the historical pre-application command chronology unverified and requires independent re-review. This supersedes only the older assertion above that the absent historical receipt itself blocks the amended condition; it does not turn that absence into historical PASS.

Current evidence for that limited criterion is the retained 29,144-byte mode-0600 backup with SHA-256 `bb388dfba366a9f300f1c0060fa6282468d7a896dc7e72986f3bf3452f08c3d5` (maintainer audit in `reports/verification/rt002-t001-current-evidence-20261002.md`), and the human-only `reports/verification/rt002-bare-envelope-candidate-20260929/apply-human.py` SHA-256 `3ce86f7d4fb2da837ab4160cfeba33e98071cf6da8516f3718f675af1973e4f1`. Its `--restore BACKUP --installed` mode accepts only installed SHA-256 `1057d1fcd1a8307c1fe55b961f3b37af2576683887f1c4ec2ce5138065e8fe0d` and backup SHA-256 `bb388d...c3d5`. The retained `--self-test` log SHA-256 `1f68c488567e0e608414302215fffcfcd8f4a142a2866b9384f68d4b99c72f26` records exit 0, isolated restoration, two hash refusals and two symlink refusals. No installed restoration was performed or needed after successful activation. These cited observations are evidence for independent review, not a quality-gate verdict.

The source `verification/T-001-results.md` records current local suites, `spec_revision`, task-scoped traceability and the component-coverage execution; coverage returned `not-applicable (disabled-legacy)`, not an ownership PASS. The prior task review's attempt-2/round-2 precheck bound normalized `tasks.md` SHA-256 `c8b80bddaa5eef43550d3b78c8b2aa4397c9bfab61551b31a8d43c7f38e00d07`; applying its documented status/approval normalization to the current source yields `94ccc8f60f89f09f2f91fd81b6b14a8a45480444f7b76d3dbe274cfa0f460dd2`. That prior PASS does not review this amendment. The owner checkout still lacks the source feature specification and results bytes, so its formal input bundle is not ready. T-001 remains In Progress; T-002 remains Draft. No status, approval, reservation or historical verdict changed.

The source already has task-review attempt-3/round-1 precheck for the amended body: it records the same normalized SHA-256, and the normal `--verify-inputs` command exited 0 on 2026-10-03. Its `launch-blocker.md` records A identities reserved but no adoptable canonical A output, no B reservation, and no integrated verdict. The latest standalone A JSON used the raw task hash instead of the precheck's normalized hash; other attempts had output-format or launch-capacity blockers. No reviewer is reported as still running. This precheck is input integrity only, not independent re-review PASS; do not overwrite/replay this round or reuse identities.

## Current implementation-candidate audit — 2026-10-03

The canonical source checkout's verifier and both suite files hash to `bb388d...c3d5`, `39463a...3403`, and `e0d2de...3055` respectively; they are not the implemented PR #528 candidate. The bounded-integration owner checkout is at `1e86fb272643e798db4e1ca0c89f0402317a2fc8` and carries the candidate hashes in the table below. Thus source specification/task review and owner implementation evidence must remain separate until a formal input assembly verifies identical specification bytes in the owner context. The source task remains In Progress; this report does not promote it or start the quality gate.

## Outputs

The rows below are the directly rehashed candidate and existing supporting files in this owner checkout. This is a scoped inventory, not a claim that the missing source specification/results have been assembled here or that an evaluator manifest is ready.

| Path | SHA-256 |
|---|---|
| `plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py` | `1057d1fcd1a8307c1fe55b961f3b37af2576683887f1c4ec2ce5138065e8fe0d` |
| `tests/check-hook-activation-handshake.tests.sh` | `0b5417b86553ebe9001f8ac1871930378330e74289adb65eab8c92148855000c` |
| `tests/check-hook-activation-handshake.tests.ps1` | `49b537a37f1dbdab192b53b00147bf20377df9ecfe94283ac21f58c8073706cd` |
| `specs/epic-189-a1-rt002-repair/verification/T-001/native-20261002-f11bbd/observation.md` | `72ea8d431a4057307cb3abb845e62babf50624e969979abf68a43cb5f3df8714` |
| `specs/epic-189-a1-rt002-repair/verification/T-001/native-20261002-f11bbd/host-response.json` | `1994bd463ea23c9e5a65be47af9a4f07598628a2670f8672509872304edcf3bf` |
| `reports/verification/rt002-bare-envelope-candidate-20260929/apply-human.py` | `3ce86f7d4fb2da837ab4160cfeba33e98071cf6da8516f3718f675af1973e4f1` |
| `reports/verification/rt002-two-envelope-validation-20260929.md` | `efa247cfbb8e4aa566b0425e1fc22201f5654d858db3df39022f896f8a4a3ab6` |
| `reports/verification/rt002-installed-followup-20261003.md` | `177df36e959e911b6851baaa312cfa66b15927a58d86c8a0c6ea3248a291b5d8` |
| `reports/verification/rt002-installed-118-human-20261003.py` | `1a1df7982c37444bf1b8d5e8e5f8b77b3d58a03fd50402708bb16ac2eb99047e` |
| `specs/epic-189-a1-rt002-repair/verification/T-001/native-20261003-5e13f6/observation.md` | `55058376c96a08ee547ed4df8bf79d9eeca8b6f23fb4f3d5437a8dd25a01d51b` |

### Latest installation and source synchronization

The follow-up above records macOS Bash 984/0 and PowerShell 985/0, both exit 0, and the adapter isolation self-test (apply, restore, two hash refusals, symlink refusal), exit 0. The new installed backup hashes to `d9277ca516fa79b6ef459e0d0505375624a0a9279c32390758a96650985d0064`; this additional rollback path does not replace the task's older `bb388...` criterion. No actual installed restoration was performed.

The current-session native observation records HOOK_ACTIVE for installed 1.18.0, with the primary checkout receiving the native call and the bounded checkout used for verification subprocesses. It is not an independent evaluator or separate owner-host activation.

Following the maintainer's three-file application, direct SHA-256 checks in the primary checkout now match the three candidate rows above; scoped `git diff --check` exited 0. This supersedes the older paragraph claiming the primary checkout still contains original bytes. Formal implementation identity reconciliation and independent quality verification remain pending; no lifecycle status or verdict is changed here.

## Owner input assembly verification — 2026-10-03

This non-frozen addendum supersedes only the older *current owner inventory* statements above. The human-provided owner `tasks.md` is SHA-256 `75d0e1d8a837ef22ea6d6df4e90d57c6328a87828205c668de4bd26b6a0fe696`; T-001 remains Approved / In Progress and T-002 Draft / Planned. No historical pre-application restoration chronology is asserted. The three tracked candidate implementation files in the Outputs table were not changed by this input assembly.

The owner now has the source checkout's ten feature documents (including `investigation.md` and `tasks.md`), the non-frozen `verification/T-001-results.md` and `T-001-traceability.json`, and only the latest source spec-review attempt 2 round 2, impl-review attempt 3 round 1, and amended task-review attempt 4 round 1 JSON inputs. A read-only `diff -q` comparison of these 31 files against `/Users/jrmag/sdd-forge` found zero byte differences. The task result and traceability SHA-256 values are `5a0365bc96c8ed38e54075f313528e98206d812ca950f006b918a3724bcf5aa6` and `7cd901486a25f88190a7734f34172e136e1e54e85f67949e637ad0ea0045c334`. The source-origin task-review integrated verdict SHA-256 is `3e8302cc20c7116383314923a42c3b36b54975cbde217e6924340289bf01c662`, with attempt 4 round 1 PASS. These mirrored reviews are preserved source history, not reviewer executions in this owner checkout; the source identity ledger was not copied.

With one Active Spec entry in `AGENTS.md` and one `full` registry entry, owner `check-sdd-structure.sh` returned `OK`; `check-workflow-state.sh --feature epic-189-a1-rt002-repair` returned `workflow-state: ok`; `check-task-state.sh`, `check-risk.sh` for T-001, and `check-traceability.sh ... require-evidence` all exited 0. The owner recomputed SHA-256 of `requirements.md` + `design.md` + `acceptance-tests.md` in that order as `dd6c53d41ea62dd121f89aa49b218727e78a5614350dc571fb4302247fe709d3`, matching the recorded `spec_revision`. This establishes current owner input consistency, not a quality-gate bundle, fresh independent evaluator activation, or a Done decision. No RT002 quality-gate report exists in the owner checkout at this read. The task status is intentionally unchanged pending an implementation-complete decision and the independent quality gate.

## Session Handoff — 2026-10-03 owner regression readback

This continuation read the owner task, report, required implementation policy,
and current native owner observation. The latest native observation is
`specs/epic-189-a1-rt002-repair/verification/T-001/native-owner-cli-20261003-f31929/observation.md`;
its retained `host-response.json` rehashed to
`4b6a5bd7ac5c2ec04f3a2d89e0ca9ca3bcb7775a1a8608c3e92a6f99a37f6e42`.
This is the prior actual native owner denial, not a new canary dispatch.

Fresh direct executions in this owner checkout completed Bash 984 PASS / 0 FAIL
and PowerShell 985 PASS / 0 FAIL, each exit 0. The exact commands, tool session
IDs and limitations of retained output are indexed in
`specs/epic-189-a1-rt002-repair/verification/T-001/owner-regression-readback-20261003.md`.
The four original differential raw logs were found in the source checkout by
including Git-ignored files, rehashed, and their 199/211 baseline and 410/0
candidate tails independently inspected. The newer 984/985 raw log files
previously cited in another report have not been rediscovered; do not claim
their old SHA-256 values were freshly verified.

This long-lived agent's context was compacted. The implement-task delegation
policy requires ending this continuation after a persisted handoff, so no
canonical v2 report, Implementation Complete transition, reviewer identity
reservation, or quality-gate launch was made here. Resume from the current
`tasks.md`, this report, the non-frozen readback note and the actual native
observation. Do not label this continuation a new fresh implementation agent.
The next session must reconcile the true historical implementation identity,
author and validate the canonical v2 report, then decide Implementation
Complete only if all T-001 conditions are met. T-002 remains Draft; its native
Windows/latest CI/merge work is not a new T-001 prerequisite.
