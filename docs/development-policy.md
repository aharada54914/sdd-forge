# Repository development policy and evidence handoff

Authorized development-policy decision: 2026-10-05. Applies to sdd-forge's own
repository development, not to projects consuming the product. This policy edit
is a documentation change under the user's explicit instruction; it is not a
product gate verdict, task approval, installation or release authorization.

## Scope, risk and completion

Use AGENTS.md's routine/high-risk criteria before work begins. Record the issue,
canonical task if one exists, checkout/branch/HEAD, dirty changes, scope, risk
rationale, affected readers/writers, reviewer and validation plan. Documentation
that changes a safety or evidence contract belongs to the high-risk path too.
Do not split one high-risk change into nominally routine patches to evade that path.

Routine work uses reproduction, a bounded fix, affected tests, independent diff
review and all applicable CI at the final head. Test a defect before and after the
fix when feasible; otherwise record the concrete alternative evidence. Include
negative/security and cross-runtime cases whenever the behavior reaches them.
A reviewer must be distinct from the implementer and see the final diff and actual
validation. Stop on unresolved blocking findings; changed reviewed bytes require
review of the new delta. A documentation-only change uses link/structure/consistency
checks and independent review; do not execute unrelated product tests for ceremony.
Before merge, all required checks must succeed for the exact head, and branch
protection and scoped merge authority still apply. A merged change needs relevant
post-merge verification before delivery is reported. Pending, skipped and unknown
checks are not success. Local implementation, formal acceptance, merge and delivery
are separate milestones. This instruction authorizes no push/PR/merge.

High-risk/protected work retains the full workflow in AGENTS.md: approved
specification/task, contract and risk preflight, truthful field/counterpart/mismatch
evidence where required, independent review and quality-gate. Keep authorization,
identity, scratch isolation, required verification and egress controls intact.
A broken launch is BLOCKED/unevaluated, not PASS and not a semantic FAIL. Neither
routine mode nor a diagnostic session grants permission to retry a refused write
through another tool, terminal, renamed copy or checkout. Protected application
requires the existing sanctioned, scope/hash-bound management path and genuine
human operation where that path requires it; never impersonate the human.

## Verified control baseline and shared repairs

The control baseline is distinct from the code being developed. Before adopting
one, record its version/commit, installed file hashes, host/runtime coverage,
proven positive and negative behavior, known limits and rollback plan. A release
label is not verification. No baseline has been selected by this document.
Use explicit scoped human authority for baseline installation, hook trust or
control-version promotion. Do not disable existing protection during diagnosis.

Validate candidate product code in disposable fixtures and isolated host sessions
without modifying the installed control baseline, original reviewer histories or
production state. Fixture execution does not establish native host activation.
If the control baseline itself blocks repair, prepare one reviewed, hash-pinned
management repair and use its sanctioned application route; do not let the
candidate authorize its own replacement or weaken the gate until it passes.

One owner coordinates a shared repair across callers and runtimes. Inventory
readers/writers, pin each checkout's own bytes, retain unrelated dirty work, and
review the combined bounded delta. A candidate approved for one checkout is not
an instruction to overwrite another. Combine related launch/read/hash/delivery/
recovery regressions once, then reuse evidence only for the exact bytes and
conditions it proves. Serialize conflicting edits, installations and reservations
on the same ledger. Fresh ledger hashes/tips are taken immediately before atomic
reservation. Independent non-overlapping work may continue in separate contexts.

## Existing tasks and evidence: transition procedure

The new routine route applies prospectively to eligible, unbound correction work.
It does not automatically migrate the current full-track task plans. For each
existing task, first produce a non-frozen transition record containing its original
owner/task ID, approval, status, dependencies, acceptance obligations, frozen
inputs and hashes, historical verdicts and proposed route with rationale.

1. Preserve all task IDs, human approvals, statuses, frozen artifacts, verdicts,
   reservations and raw execution history. Never bulk-convert Planned, Blocked or
   Implementation Complete to Done, rewrite a past verdict, or reset a consumed
   reviewer context. Existing Done remains historical evidence, not proof of later
   changed bytes. Only quality-gate sets Done for these existing SDD tasks.
2. Continue under the existing approved contract where it remains satisfiable.
   Unchanged evidence may be reused only after confirming its byte/environment/
   requirement scope. Tests and diagnostics can progress without claiming a gate.
   Existing approvals are not requested again merely because a checkout was wrong.
3. If adopting a different route would alter an existing task's gate, acceptance,
   freeze or approval obligation, obtain a specific human decision on that delta
   through the formal contract-change path before using it. Record a superseding
   plan/version and re-review the affected contract; retain the old version.
   This policy authorization is not approval of unspecified task migrations.
4. Revalidate changed behavior, its consumers and binding/negative cases. New input
   bytes require a new admitted path/hash set and fresh independent review where
   the contract requires it. Use the existing permitted declaration/addendum channel;
   do not widen reviewer inputs informally or silently edit frozen reports.
5. Leave an active formal review running against its pinned inputs. If an actual
   mismatch requires stopping or superseding it, use that review's authorized
   transition and retain the result. Do not cancel or rewrite reviews simply to
   adopt this policy. No current review is canceled by this edit.

Freeze is limited to artifacts actually bound by the applicable passed review
contract; AGENTS.md's existing stage-specific freeze remains in force. Diagnostics,
execution logs, handoffs and progress notes do not become normative frozen inputs
merely because they exist. If one is admitted and hash-pinned into a round, preserve
that version during the round; a later revision is a new artifact/input. Runtime
observations go in non-frozen addenda. A normative requirement change still needs
the applicable human authority and re-review; an addendum cannot silently waive it.

## A7, A8, A9 and issue #423 handoff

This table determines treatment, not new task statuses. Re-read each canonical
owner plan before execution; counts from a progress report are observations.
Keep local owner paths in private handoffs rather than public issue/PR text.

| Work | Treatment of existing scope and evidence | Next validation boundary |
| --- | --- | --- |
| A7 compatibility (`epic-195-a7-compatibility`) | Preserve the 13-task plan and old fixture/golden evidence. Recovering interrupted reviews, identities, hashes and SKIP/required semantics is high-risk shared infrastructure, not a routine bug exemption. | Check changed fixtures, trace/event/output consumers and Bash/PowerShell parity; review changed normative test conditions under the formal path. Preserve interrupted attempts and use a fresh admitted reviewer. |
| A8 integration (`epic-196-a8-integration`) | Preserve the eight-task plan and T-004's implementation evidence. Keep synthetic/fixture, installed-byte and real-host evidence distinct. Old PASS is not proof of changed input. | Rebind actual changed inputs; verify the exact read/launch behavior and relevant host/runtime controls; complete independent evaluation and applicable CI before Done. |
| A9 interrupted-review recovery (`a9-interrupted-review-recovery`) | Preserve the separately approved three-task plan and original human provenance. Do not confuse a Draft integration copy with missing owner approval. | Complete protected baseline/admission preparation through the legitimate route, then task-specific implementation and formal gates; preserve all old reservations. |
| A9 Dogfood (`epic-197-a9-dogfood`) | Separate from the recovery tasks. No formal tasks.md was found during the policy preparation; do not invent a denominator or infer a new approval from the recovery plan. | Complete the applicable specification/design approval and task decomposition; recheck the stated A1-A8 dependencies. This document creates no live Context or Pack. |
| Issue #423 (`sdd-domain-multitarget`) | Mandatory scope for future extension remains intact: consumer inventory, ownership boundaries, target obligations, compatibility, consent/fallback and host/release evidence. Preserve the six-task plan and T-001 Done evidence. | T-002 quality acceptance precedes T-003; T-003 then precedes T-004, T-005 and T-006. Resolve manifest binding and exact read admission formally; rebind new evaluator inputs. Reuse unchanged payload evidence within its proven scope; do not claim an old installer receipt verifies a new complete installation. |

No A7/A8/A9/#423 function, prerequisite, required check, human provenance or
independence control is removed by this policy. A shared validator/guard repair
can affect all their launch paths even without a direct task dependency. Inventory
and regression-test those consumers before integration. Native host/OS claims need
actual matching execution; CI for an old public head cannot verify local edits.

## Adoption boundary

This edit changes only the policy documents in the checkout where it is applied.
It does not synchronize other worktrees, running session instructions, installed
skills or hooks. Before another owner uses it, compare that owner's existing
instructions and dirty changes, adopt the policy through the normal authorized
process, and record the exact policy version. Do not overwrite a live owner or
pretend an already-started session has reloaded it.

Remaining scoped human decisions: select/promote a proven control baseline;
approve any concrete transition of an existing full-track contract; authorize
installation/trust changes or publication when required. Ordinary diagnosis,
classification and preparation within existing authority do not need repeated
approval. This document is not a blanket approval of those future operations.
