# Unified launch: bounded implementation

Owner: this session, A7 checkout `/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge`.
Base HEAD: `25813ee4baf8ae8fff344a6c979da61fbd23d2c7`.
Scope: user-approved option 2; local candidate and validation only. No installation,
trust changes, publication, reservation or formal review is authorized by a local
test result. Existing dirty A7 recovery, role, specification, ledger and test
changes are retained. This is high-risk launch-boundary work, not a routine fix.

Reuse the non-TTY transport, session guard, native boundary probe and canonical
review-context validator. First supported connection is Claude implementation-
policy review; other stages/hosts must not silently fall back to this path.

Evidence consistency checks before implementation:

| Persisted field | Counterpart | Required failing check |
|---|---|---|
| Invocation/input hashes | Current admitted bytes | missing/modified input rejected |
| CLI argv and permission settings | Same builder used by diagnostic and launch | unsupported flag/settings mismatch rejected |
| Native boundary result | Observed transcript and pinned policy | denied read/compound operation must not execute |
| Reservation receipt | Existing ledger/validator | preflight failure never reaches reserve |

Required validation: old non-TTY contracts, new common preflight regressions,
native unreserved boundary probe where available, independent diff review.
Local fixtures do not prove native admission or a verified control baseline.
No frozen approval, historical verdict, or task lifecycle is changed.

## Historical intermediate checkpoint (2026-10-07; superseded below)

This is an incomplete candidate, not an adopted review entrypoint. No skill caller
has been switched, no identity reserved, and no formal verdict produced by this work.

Changed files in this bounded work:

- This implementation record.
- `plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py`: shared Claude argv builder.
- `plugins/sdd-review-loop/scripts/launch-impl-review.py`: candidate ordered preflight/launch orchestration.
- `reports/verification/a7-nontty-impl-read-guard-probe-20261006.py`: shared builder and input-bound diagnostic support.
- `reports/verification/a7-nontty-impl-contract.tests.py`: transport contract regressions.
- `reports/verification/unified-launch-order.tests.py`: ordering and failure-path checks.

Observed local results:

| Command | Result | Limit |
|---|---|---|
| `python3 -B reports/verification/a7-nontty-impl-contract.tests.py` | 7 test methods passed | Local contract tests |
| `python3 -B reports/verification/unified-launch-order.tests.py` | 4 test methods passed, including ten pre-reservation failure cases | Mocked launch, not native admission |
| `bash tests/impl-review-round2-contract.tests.sh` | 4 checks passed | Existing round-2 contract fixtures |
| `git diff --check` | Exit 0 | Whitespace only |
| `python3 -B reports/verification/a7-nontty-impl-read-guard-probe-20261006.py` | Exit 0; admitted/control Reads and four ordered hashes succeeded; outside Read and compound Bash denied | Default synthetic input, no formal invocation/reservation |

The earlier command using `reports/verification/impl-review-round2-contract.tests.sh`
failed because that path does not exist. The corrected `tests/` command above passed.

Native diagnostic session: `d8c684c0-bebe-4e67-b14b-5a6af467141b`.
Policy SHA-256: `24e9cdbb146a0f5942c81f2230ad2864efc70355da308eba0a9bcb1a6d685dbf`.
Guard SHA-256: `f14cacb497e0c58c0618015a5e1229819f8d85d9825a4afa36a4d1cfd4954dc6`.
Transcript SHA-256: `f1bfbf018eeeacc5bbc2985ee4136077951c5ae591c908ae92bf4f703acb9e01`.
The first Bash required the existing identical FactForcing retry; no changed command
or executor was used to evade a refusal. This diagnostic is not a formal PASS.

## Independent review and remaining connection blockers

Independent diff inspection identified unresolved integration requirements; it did
not certify the candidate as PASS or re-run its tests:

1. The native probe reads its diagnostic invocation, not the caller's formal
   invocation path. Caller-side SHA comparison does not prove native Read access
   to that formal path. Verify that exact control input before any reservation.
2. The non-TTY caller-proposal record required by the current impl-review skill
   is not produced/validated by the launcher. Bind it to the existing allocation
   location and test identity collision/replay before connecting the skill.
3. `domain/` and `design-system/` dependencies are not admitted by the current
   canonical impl input contract. The candidate explicitly rejects their presence;
   this is an unsupported ceiling, not successful dependency coverage or SKIP.
4. A separately verified control baseline has not been established by these
   candidate tests. `docs/development-policy.md` requires version/hash, runtime
   coverage, positive/negative evidence, limits and rollback before adoption;
   installation/trust/promotion are outside this request.
5. Spec/task/quality and other host callers are not connected. Complete native
   formal-input checks, canonical output validation/adoption and an independently
   reviewed caller migration remain unperformed. Do not advertise a unified entry
   for all callers or launch this candidate as the governing review route.

No reinstall, global trust/permission change, commit, push, publication, merge,
production application, approval change or frozen-evidence rewrite was performed.

## Intermediate local checkpoint for the six-item request (2026-10-07)

This section supersedes connection claims above, not historical evidence. The
earlier synthetic native result does not verify the current launcher. The owning
checkout and pre-existing dirty work remain unchanged; no Git publication occurred.

| Item | Local result | Remaining boundary |
|---|---|---|
| 1: comma-separated CLI aliases | Shared help parser corrected; contract suite passes | Current Claude reports 2.1.291; final native route not executed |
| 2: diagnostic/formal assembly | Shared argv/policy builder and spec/impl skill callers connected; session guard and native proof are mandatory | Other hosts, task and quality routes are not migrated; actual final native execution pending |
| 3: pre-reservation validation | Required input verification, canonical path/hash preview, dependency rejection, caller proposal, native permission proof and rechecks precede reserve | domain/design-system dependencies remain explicitly unsupported by the canonical input contract |
| 4: permanent regressions | Permanent tests and applicable CI drivers wired | CI execution not performed; mocked order tests are not native integration proof |
| 5: freeze contract | AGENTS aligned with approved WFI-030 state-cell normalization; raw historical proofs retained | Approval of transitions remains a separate existing requirement, not granted by hashing |
| 6: PowerShell normalization | Shared helper reused by impl/task consumers; stage rules and outputs retained | Local equivalence checked; Windows CI not run |

Current bounded files (including integration edits to already-dirty files):

- `plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py`
- `plugins/sdd-review-loop/scripts/launch-impl-review.py`
- `plugins/sdd-review-loop/scripts/probe-nontty-review.py`
- `plugins/sdd-review-loop/scripts/nontty-impl-pretool-guard.mjs`
- `plugins/sdd-review-loop/scripts/review-hash-normalization.ps1`
- `plugins/sdd-review-loop/scripts/impl-review-precheck.ps1`
- `plugins/sdd-review-loop/scripts/task-review-precheck.ps1`
- `plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md`
- `plugins/sdd-review-loop/skills/impl-review-loop/SKILL.md`
- `tests/a7-nontty-impl-contract.tests.py`, `tests/unified-launch-order.tests.py`
- `tests/traceability-freeze-contract.tests.py`, `tests/review-hash-normalization.tests.ps1`
- `tests/run-all.sh`, `tests/run-all.ps1`, `.github/workflows/test.yml`
- `AGENTS.md`, `reports/verification/traceability-freeze-contract-20261007.md`, this record.

Final observed local executions:

- Unified launch order: 4 test methods PASS, 0.060 seconds.
- Non-TTY contracts: 11 test methods PASS, 0.806 seconds.
- Traceability freeze: 2 test methods / 24 Bash and PowerShell outcomes PASS,
  41.303 seconds. Body edits, unknown/mis-cased states and comment changes rejected.
- PowerShell normalization: exit 0, exact baseline parity including CRLF,
  case and invalid-input cases. Existing stage-specific normalization retained.
- CI wiring checks previously executed in this bounded work: required-checks-posix
  4, ci-suite-wiring 21, deterministic lane 29; syntax/YAML and whitespace checks passed.

Independent reviewer `/root/unified_launch_review` reran the order (4), contract
(11), and traceability (2 methods) suites successfully and inspected the actual
caller-to-reserve order. No new major defect was found. This is a limited independent
diff review, not a formal SDD verdict or a native activation certificate.

Remaining limits: a separately verified control baseline has not been established;
the final native probe and formal reservation/launch have not run; domain and
design-system admission requires an explicit canonical input contract; other
stage/host caller migration remains incomplete. Probe policy/settings are temporary,
so their later content audit is limited despite retained hashes/transcripts.
No existing approval, frozen evidence, task state or review verdict was changed.

## Real caller mismatch found during follow-up (2026-10-07 JST)

The earlier mocked ordering checks are insufficient to certify the spec caller.
`launch-impl-review.py` passes `--verify-inputs` to both stage prechecks, but the
specification prechecks do not accept that option. Their normal mode also creates
a round, so repeating normal generation is not a read-only substitute. This is
an implementation defect, not a missing user approval. Items 2–4 remain incomplete.
The bounded repair adds read-only verification to the existing spec prechecks and
tests their actual Bash/PowerShell interfaces without reserving identities.

The latest mocked launch-order run contained five methods, not four; its scope
remains orchestration only. Conditional domain/design-system requirements exist
in reviewer instructions, but admission is not yet wired through the canonical
prechecks and validators. Blanket rejection is a safe stop, not completed support.
No formal PASS or completion claim follows from these intermediate results.

## Native diagnostic and dependency checkpoint (2026-10-07 JST)

The final-candidate native permission diagnostic now succeeded (exit 0), using
`reports/verification/unified-launch-native-diagnostic-20261007.json` and
`probe-nontty-review.py`. This supersedes only the pending *diagnostic* statement
above: no formal reservation or review was performed. The two selected A7 inputs
do not constitute the complete formal input manifest.

- Native session: `b7ea1324-42bc-47ff-88c6-b7329111f3a4`.
- Source invocation SHA-256: `2130af4f71e0f95ded8f22e5446ba188337f7fcec348c121368637721e9da922`.
- Transcript SHA-256: `a4afa95bc1231ed81711cf123981286bd2d4147d5a794416b47a79e981df69dd`.
- Six ordered hashes verified; admitted/control/source reads executed.
- Outside Read, chained Bash and duplicate session were rejected.
- The probe checked that source invocation and canonical ledger were unchanged.
- First-Bash retry was observed; this is not permission to retry a session-guard refusal.

Existing-issue dependency inventory, read from the owning task plans:

- A7: T-005 is Implementation Complete, not Done; T-004/T-010 remain In Progress.
- A8: T-004 is Implementation Complete; T-001/T-002/T-003 remain Planned.
- #423: T-001 is Done; T-002 quality acceptance must precede blocked T-003,
  followed by T-004 through T-006. Successful payload assembly alone is insufficient.
- A9: the integration copy contains Draft tasks; development-policy.md explicitly
  requires locating the separately approved owner plan, not treating this copy
  as proof that human approval is absent.

The six-item delivery remains incomplete: unsupported conditional input contracts,
verified control-baseline selection, formal launch and remaining caller coverage
are not proved by this diagnostic. No public CI, Git publication, installation,
global permission change, frozen-evidence rewrite or task-state change occurred.

## Downstream compatibility repair checkpoint (2026-10-07 JST)

Independent diff inspection found that admitting conditional domain/design-system
inputs at launch was insufficient: saved-round readers still required the old
fixed input set. Items 2–4 remain incomplete until both entry and downstream
readers agree. Historical records are not rewritten or supplemented from current
files. New invocations require the currently resolved inputs; historical readers
validate the recorded stage-specific paths and matching role hashes.

Bounded repair preflight (owner checkout above, HEAD
`25813ee4baf8ae8fff344a6c979da61fbd23d2c7`, high-risk evidence-reader change):

| Existing evidence field | Counterpart | Required rejection regression |
| --- | --- | --- |
| manifest path | stage-specific canonical input set | unknown/wrong-stage extra |
| conditional path and SHA-256 | other role's recorded manifest | missing role entry, mismatch, duplicate |
| current input SHA-256 | ordinary live freshness check | changed current input |

No new evidence field, approval or verdict is introduced. Shared-file owners are
separate: spec prechecks, downstream prechecks, workflow-state readers, and
canonical admission validators. Overlapping writes and canonical reservations are
not authorized by this repair checkpoint.

Executed local checks before the downstream repairs finish:

- `a7-nontty-impl-contract.tests.py`: 11 methods passed.
- `unified-launch-order.tests.py`: 5 methods passed (mock orchestration only).
- `review-hash-normalization.tests.ps1`: baseline/CRLF/case/invalid checks passed.
- `traceability-freeze-contract.tests.py`: 2 methods, 24 Bash/PowerShell outcomes passed.
- Spec-precheck owner reports both actual runtimes passed historical 0/1/2
  conditional-input, changed/deleted live file, alternate recorded checkout,
  mismatch, duplicate and unknown-extra cases; full spec loop passed. Independent
  review of this latest repair is still pending.

These checks do not prove native Windows/Ubuntu, public CI, formal review or
completion. Existing Issue execution follows only after the applicable six-item
quality conditions hold, without waiting for the 08:00 JST reporting target.

## Independent follow-up checkpoint (2026-10-07 JST)

- The independent reviewer found an ADR path could be hashed before the canonical
  precheck admitted it. The launcher now runs the existing input verification
  first and detects changes to its precheck input. Independent re-review found
  no remaining Critical/Major finding in this bounded change: orchestration
  tests 6/6 and contract tests 11/11 passed. These are not formal-launch proof.
- Original-path `review-context-boundary.tests.sh` completed with exit 0;
  its concluding investigation matrix reported 84 passed, 0 failed. Citation
  anchors were updated to the current code without changing their assertions.
- The primary agent independently executed the shared PowerShell hash recipe
  regression: exit 0, baseline/CRLF/case/invalid-input equivalence passed.
- A separate independent inspection found that ADR-extended workflow-history
  readers still omit the conditional domain/design-system input paths. This
  remaining Major is under a three-file bounded repair; the six-item delivery
  is not complete. Old records and canonical reservations remain unchanged.

No remote CI, publication, merge, installation or global permission change was
performed at this checkpoint. Native Windows/Ubuntu and complete formal-route
execution remain unverified.

## Latest verified checkpoint and issue handoff (2026-10-07 JST)

This checkpoint supersedes the pending ADR-history finding above, not historical
test evidence or formal verdicts. The three-file repair passed independent diff
review with no Critical/Major findings. The independent execution of
`tests/workflow-conditional-history.tests.py` passed 2 methods / 44 outcomes
(16 ADR-extended and 28 ordinary, Bash and PowerShell). The implementer also
reported ADR history-pin 6/6 and workflow-only 140/140 passed. These are 190
outcomes across those three executions, not the earlier reported 184.

Primary-agent original-path executions passed:

- `tests/spec-review-verify-inputs.tests.py`: 2 tests, exit 0.
- `tests/review-conditional-inputs.tests.py`: 14 tests, exit 0.
- `git diff --check`: exit 0 after the shared repairs.

Independent inspection of items 5 and 6 found no Critical/Major findings. It
confirmed WFI-030 approval at commit `74d6ae36`, distinguished saved task-state
normalization from new raw-hash admission, and reran the freeze contract (24
outcomes) and PowerShell normalization equivalence checks successfully. Native
Windows and public CI have not run; these results are not a formal gate verdict.

At this checkpoint the GitHub open-issue inventory contains #187, #195, #196,
#197, #290 and #423. The 08:00 JST target is a report deadline, not a prerequisite
for resuming dependency-cleared work. Existing approvals and evidence are reused
only against their owning checkout and matching bytes. A9's integration copy at
`/private/tmp/pr401-main-sync.YiIrFM/checkout` still contains Draft fields; this
does not invalidate the separately approved recovery plan. Locate that owner and
its provenance before implementation; do not mutate this copy to invent approval.

The six-item delivery remains incomplete: native formal-route proof, verified
control-baseline adoption, and aggregate-card selection semantics remain
unresolved. Spec/impl Claude routes are connected; task/quality and other-host
routes must not be described as migrated. No publication, installation, global
permission change, reservation or task-state transition was performed here.

## Native formal-route transport checkpoint (2026-10-07 JST)

Owner and scope remain the A7 checkout above; only the shared strict prompt and
its contract regression changed. An isolated native run first failed because
the reviewer copied JSON-escaped TAB/LF characters into the ordered hash command.
The exact-command guard correctly denied that command; the failed fixture and
its reservation were retained. No production ledger was changed.

The strict/impl prompt now also renders the existing hash commands as literal
shell blocks. Hash construction, exact permissions, guards and legacy spec
prompt behavior are unchanged. The added regression failed before this fix;
the corrected contract suite passed 12 tests. Independent diff review and an
independent rerun passed with no Critical or Major findings. Whitespace passed.

`rtk proxy python3 -B tests/unified-launch-native.py --run-native` then exited 0
with `DELIVERY_OK` and `NATIVE_DELIVERY_VERIFIED`. The retained fixture is
`/private/var/folders/7z/hjmz6jdj4wb40srf64sl368w0000gn/T/sdd-unified-native-9bfu1yc0`;
review session `d81d210d-7988-43e0-9464-700aae8f85b0`. Its fixture ledger contains
the original record plus one reservation. This exercises actual precheck,
permission diagnosis, reservation, Claude review delivery and strict postflight.
It does not adopt a verdict or prove production review, native Windows, other
roles/stages, installation or CI. Task/quality caller coverage remains pending.

## Quality shared-route implementation handoff (2026-10-07 JST)

The A7 current-execution agent connected the quality evaluator caller to the
existing shared non-TTY launcher. Its bounded repair, source pins, reviewer
result and limitations are recorded in
`reports/verification/a7-quality-shared-launch-20261007.md`. Independent
re-review by `/root/unified_launch_review` confirmed the final three shared
source hashes, found Critical 0 / Major 0, and passed quality transport 7/7,
shared transport contract 12/12, task launch 9/9 and launch order 6/6.

This supersedes the earlier statement that quality caller coverage is pending
only for the reviewed code connection, not for native or formal proof. A
disposable native quality-boundary run remains in progress under another
owner. Canonical evaluator `model: opus` conflicts with the current Sonnet-only
authorization and therefore blocks formal reservation; aggregate-card
selection semantics and control-baseline adoption remain unresolved. No
production reservation, quality verdict, installation, publication or CI
result is asserted by this handoff.

## Current caller verification checkpoint (2026-10-07 JST)

This checkpoint supersedes the preceding in-progress quality-native statement:
that run was not performed and no such process remains active. Formal quality
launch is still blocked by the recorded Opus/Sonnet contract conflict; no model
requirement has been silently replaced.

The actual spec, impl, task and quality caller documents now route their
supported Claude non-TTY path through the shared launcher. This is code wiring,
not proof for every stage or host. Other-host/manual paths remain unchanged.
Native stage results and retained fixture locations are recorded in
`reports/verification/native-stage-delivery-20261007.md`: task B delivered on
its recorded older source pins; task A twice returned fenced JSON and was
correctly rejected. Neither failure is converted to a verdict. Impl A/B were
denied for out-of-contract directory probes; those results are retained.

The bounded correction passes already validated conditional-input observations
to the strict spec/impl prompt and postflight, rechecking them before reservation.
It does not grant directory probes or expand Read/Bash permissions. See
`reports/verification/a7-impl-conditional-prompt-20261007.md`. Independent diff
review found no Critical/Major findings and reran launch-order 7, transport
contract 12, task launch 9 and quality transport 7 successfully. Native impl A/B
verification of these corrected bytes is pending at this checkpoint.

Additional local checks completed: criterion-freeze 15 passed, CI suite wiring
21 passed, PowerShell normalization equivalence exited 0, and workflow
conditional-history completed its two test methods with exit 0 (including
Bash/PowerShell rejection cases). These are local results, not hosted CI.
The six-item maintenance delivery remains incomplete while native delivery,
aggregate selection and the formal model/control-baseline boundaries remain
unresolved. No frozen artifact, approval, task status or Git history was changed
by this checkpoint; no installation or public operation was performed.

## Impl native delivery checkpoint (2026-10-07 JST)

The corrected common caller delivered both impl roles through the actual Claude
CLI, each with exit 0 and `DELIVERY_OK`. Source pins, retained fixture transcripts
and distinct session IDs are recorded in
`reports/verification/native-stage-delivery-20261007.md`. Both processes ended;
the source edit freeze was released only after their completion. These runs use
synthetic predecessor evidence in disposable fixtures, not production review
verdicts or approval evidence. They supersede the impl-native-pending statement
above, not the other outstanding boundaries.

Task A's fenced output remains a real failure. Its bounded repair is owned by
the A7 current-execution agent; the common diagnostic/formal tool profile and
strict output validation must remain aligned. Quality native execution has not
been performed. No hosted CI, installation, publication, merge or task-state
transition was performed by this checkpoint.

## Follow-up local regression checkpoint (2026-10-07 JST)

The coordinator reran `tests/traceability-freeze-contract.tests.py` (2 methods),
`tests/review-conditional-inputs.tests.py` (14 tests),
`tests/downstream-conditional-manifest.tests.py` (2 tests), and
`tests/unified-launch-order.tests.py` (7 tests); each exited 0. The freeze suite
accepted the documented lifecycle states and rejected unknown/case-modified
states, task-body changes and evidence changes in both persisted-state paths.
These checks do not establish native task/quality delivery or hosted CI.

Task-only structured output and the quality native fixture remain under separate
owners. Native fixtures will not copy moving shared launcher sources. Formal
quality model selection and aggregate-card selection remain unresolved as
previously recorded; no frozen evidence or canonical ledger was changed here.

## Subsequent native and independent verification (2026-10-07 JST)

Task A/B and synthetic quality now completed actual isolated Claude Sonnet
delivery with exit 0; exact sessions, source pins and transcript hashes are in
`native-stage-delivery-20261007.md`. This is transport evidence, not adoption of
synthetic predecessor verdicts or canonical Opus quality evaluation.

The quality probe's incidental reports/verification dependency was removed by
using the already-verified ledger parent for temporary files. The focused
structured-output suite passed 10 tests, independently reproduced; quality
transport regression passed 7 tests. Independent review of Bash/PowerShell
conditional-history pins found zero Critical/Major issues and reproduced
44 runtime outcomes across 2 test methods. Old history is not recomputed from
current conditional inputs. `git diff --check` passed after these repairs.

Formal quality model selection, aggregate-card selection and verified control
baseline adoption are still unresolved. No publication, installation, global
permission change, CI execution, merge or task completion is claimed.

### Final caller-coverage audit and repeated local checks

Independent read-only audit found no additional Claude non-TTY bypass:
spec-review-loop/SKILL.md:167,273; impl-review-loop/SKILL.md:215,243;
task-review-loop/SKILL.md:168,354; quality-gate/SKILL.md:210–217 all route
through launch-impl-review.py. Other-host reservation branches remain separate.
The shared caller validates required inputs (lines 72,136), conditional
dependencies (27,304), executable dependencies (270), native permission probing
and final pin rechecks before the first reservation (315). These line references
describe this working snapshot and must be rechecked after edits.

Coordinator repeated task-launch (9), launch-order (7), CI wiring (21 cases),
and PowerShell shared hash normalization (baseline, CRLF, case, invalid input);
all exited 0. This does not claim hosted CI or formal quality admission.
The remaining canonical quality conflict is evaluator.md:6 `model: opus`
versus launch-impl-review.py:226 Sonnet-only authorization. It is intentionally
rejected before reservation; diagnostic success does not resolve that contract.

### Completed follow-up checks

The final pending local processes both exited 0: conditional required inputs
passed 14 tests, and traceability freeze passed 2 test methods covering both
runtime paths. The latter accepted documented lifecycle states and rejected
unknown/case-modified states, body changes and evidence changes. The task
structured-output suite also passed 10 tests. These results do not adopt a
control baseline, alter a role's model contract or establish hosted CI.

The four Claude caller connections are implemented and independently audited;
the full maintenance work is not declared complete. Formal quality admission
still requires resolving the canonical evaluator model conflict. Control
promotion remains separately authorized by docs/development-policy.md:42–47,
and aggregate-card selection still needs a defined contract. No reservation,
approval, historical verdict or task state was changed in this checkpoint.

### Current transport final checkpoint (2026-10-07 JST)

With transport SHA-256
`149bd3b91fc0da8e06a23a6ddc9c8d7bfded6f78466db6a87f0b9129e8c63022`,
the coordinator completed 69 Python regression methods, PowerShell normalization
parity, and native isolated impl A/B, task A/B and diagnostic quality delivery.
The spec route's unchanged transport mode has earlier native evidence. Exact
sessions and the correctly rejected first task-A run are retained in
`native-stage-delivery-20261007.md`. Independent end-to-end diff review found
no new Critical/Major findings. Local caller wiring is implemented; this is not
formal task completion. Canonical evaluator model selection, aggregate-card
selection semantics and control-baseline adoption remain unresolved. Hosted CI,
publication, installation and merge were not performed.

### Latest spec delivery and independent issue work

The latest-pin spec native run also exited 0 (`sdd-unified-native-du70l39r`);
its exact session and hashes are recorded in `native-stage-delivery-20261007.md`.
Thus all four nonTTY caller families have isolated real transport evidence,
subject to the synthetic quality model limitation above.

Independent #290 T-002 behavioral verification reached an actual permission
denial in session `edb1b525-0066-43fd-a733-7753a98bf0c0`. The noninteractive
session had no approval surface. TEST-008/023/024 were not evaluated; zero output
after denial is not confirmation-boundary evidence. The retained record is
`/private/tmp/issue290-t002-observed.b1J6uP/observations/verification.md`.
No alternate executor, permission change or refusal bypass was attempted.
