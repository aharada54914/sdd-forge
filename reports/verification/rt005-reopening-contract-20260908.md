# RT005: T-002-only reopening contract

State: approved scope; implementation and formal review pending.

## Plan and boundary

This is a multi-role contract change: coder, reviewer, tester, then formal
quality verification. The primary agent performs implementation and tests;
independence is reserved for the required review. The user explicitly approved
the T-002-only reopening contract, refusal regressions, and formal review.

Current sources: `specs/workflow-state-registry.json:183` and its schema const
at `contracts/workflow-state-registry.schema.json:418` allow only Done;
`check-workflow-state.sh:1318` and `check-workflow-state.ps1:1506` compare task
statuses without task identity. Recheck these locations at implementation time.
REQ-005 in `specs/workflow-state-integrity/requirements.md:45` forbids broadening
the migration exception implicitly. The historical reviewed files remain frozen.

The exact sdd-forge-mcp legacy const will gain `task_status_overrides` equal to
`{"T-002":["Implementation Complete","Done"]}`. The feature-wide allowed list
remains `["Done"]`; no other registry entry gains this property. Both consumers
must associate status with an exact canonical `## T-NNN` heading, reject duplicate
IDs and orphan lifecycle fields, require exactly one status and approval per
task, and require Approved (case-sensitive) for the reopened task. Malformed
task headings must not inherit the preceding task's override. Existing stage,
registry, approval, evidence, and final Done checks are not relaxed. This
contract admits pre-gate lifecycle only; it does not itself prove gate PASS.

## High-risk preflight

| Persisted field | Counterpart | Failing mismatch test |
|---|---|---|
| legacy.task_status_overrides | exact schema const | altered-task / altered-state / wildcard registry rejected |
| tasks.md task ID | override key T-002 | another-task / duplicate-ID / malformed-heading rejected |
| tasks.md Status | task-specific exact allowed states | Planned / In Progress / Blocked / mis-case rejected |
| tasks.md Approval | Approved requirement | Draft / missing / mis-case rejected |

Tests call the actual installed-in-repository scripts with their existing
`--registry` fixture interface. No validator copies, alternate wrappers, or
hook configuration changes are part of the plan. Fixture data are disposable.
Retain RED logs, then require all cases GREEN on Bash and PowerShell, plus
existing registry/workflow-state regressions, independent review and formal
gate. Windows execution is not implied by macOS PowerShell success.

## Execution and protection boundary

The new matrix initially executed 76 subcases: 12 passed, 64 failed, exit 1.
All failures reached the existing bounded schema, which rejects the new field.
The registry and schema were temporarily updated, but the first actual Bash
validator edit was denied by the protection hook. No alternative execution or
copy was used. The two partial contract edits were reverted using only this
turn's exact changes; `git diff --stat` for the four runtime/contract targets
then returned no changes.

An inert five-file human patch includes both consumers, the exact schema and
registry change, and the existing registry test's allowed-key check. That test
still requires exact equality of the full legacy set against schema consts;
it additionally checks the exact override value. No assertion was removed.

Independent static reviewer `/root/rt005_reopen_candidate_review` found one
Major/Warning in round 1: indented H2 task headings could inherit T-002's
context. The candidate now clears context on noncanonical H2 boundaries and
the suite includes the exact counterexample, tab indentation, and missing
heading space. Round 2 reported that finding resolved and no further concrete
findings. Neither review is a formal gate verdict; candidate execution and
native Windows verification were not performed by the reviewer.

The final RED matrix executed 96 subcases (24 cases × LF/CRLF × Bash/PowerShell)
on macOS: 12 passed, 84 failed, exit 1. These are expected pre-implementation
schema rejections, not proof of the new runtime rejection rules. The harness
reports one unittest containing the subcases. Full output:
`/tmp/rt005-reopening-red-round2-20260908.log`, SHA-256
`0117326ab1362f49fac96c9548bf179ef90656d41bf626b70d0d9c922708646e`.

Final `git apply --check --recount` succeeded for
`reports/verification/rt005-reopening-human-20260908.patch`; no application
occurred. The initial fifth-file hunk needed trailing context; the corrected
patch passed the read-only applicability check. Human-only application script:
`reports/verification/rt005-reopening-human-apply-20260908.sh`.
It pins all five before-hashes plus patch/test hashes, backs up every target,
applies once, and records every validation exit without converting failures
to success. It does not commit, push, merge, alter old evidence, or issue Done.

Pending: human application; GREEN matrix and existing suites; fresh formal
gate manifest/evaluator. The separate PR400 global provenance failure remains
independent and is not excused by this contract. RT005 remains open.
