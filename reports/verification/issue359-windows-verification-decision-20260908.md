# Issue #359 — Windows verification decision

Status: human approved the limited exception and specification re-review;
implementation, formal re-review and native Windows verification remain pending.
This decision record does not itself amend frozen specifications or authorize
unisolated CI execution.

## Verified constraints

The candidate production repair and 12 Gemini cases are in
`/Users/jrmag/.local/share/sdd-forge-issue359-recovery-20260908`.
Its local report records PowerShell collection 59/0, Bash collection 52/0,
runner-effort 28/0 in both runtimes, and separate broader-suite failures.
Those results are macOS results, not native Windows results.

The candidate's `specs/cross-model-verification/requirements.md:92-93` AC-007
forbids CI invoking collection runners. `design.md:129-130` says no CI job may
invoke the collection layer. `acceptance-tests.md:14` explicitly names
`run-panelist-*` and `prepare-panelist-input`. Therefore even synthetic-CLI
coverage needs a formal exception before being registered in CI.

Read-only GitHub runner inventory returned no self-hosted runners on 2026-09-08.
The local Applications inventory did not show a Windows VM application. Neither
observation proves the user has no other Windows host; no native Windows
execution route has been established for this task.

## Proposed limited exception

Permit collection-runner tests in CI only under all these conditions:

1. Synthetic, repository-owned CLI fixtures only; no real provider CLI execution.
2. Synthetic public test input only; no repository-content collection, user
   credentials, provider credentials, secrets, or actual model requests.
3. An isolated execution boundary that denies outbound networking for the tested
   process tree, with a failing-network negative control. PATH substitution alone
   does not establish that boundary.
4. Verify fixture executable selection before runner execution, and fail closed
   when isolation or fixture selection cannot be proved.
5. Pin checkout and test/source digests in saved artifacts. Run on native Windows
   and preserve exit status plus full output. Never reinterpret a skip as PASS.
6. Retain every current mandatory CI check. This exception adds validation; it
   does not waive independent quality verification, consent or real collection
   remaining local-only.

The amendment would update the REQ-007/AC-007 wording and all corresponding
design, acceptance, security, policy and task references through the existing
formal re-review process. Frozen inputs must be re-bound properly; existing
passed records must not be edited retroactively. Before implementation, inspect
all identifier hits and settle the actual Windows isolation mechanism in design.
No implementation of that mechanism is claimed here.

## Alternative without a specification change

Use a user-provided native Windows development host to run the pinned candidate
locally, keeping the current CI boundary unchanged. Transfer only the intended
candidate artifacts, use a dedicated checkout, and collect source digests,
PowerShell version, complete suite output and exit codes. This requires an
available Windows host and a confirmed transfer/execution path.

## Current external state

Open PRs: 245, 371, 381, 390, 394, 400; heads unchanged from the prior audit.
PR 400 required checks passed at head
`8fa3eb8561d6f59b692ec574900f87e181145928`, run `34033392134`; its separate formal
review condition remains unresolved, so the approval-review administrative
bypass does not justify merging it. Recent workflow runs observed were terminal.
Open issue inventory returned 26 issues; none was closed by this investigation.

## Historical requested decision

Approve the narrow offline-only CI exception above and its formal specification
re-review, or provide a native Windows host for local verification. Until then,
do not insert collection-runner CI invocation or claim Windows acceptance.

## Human decision received (2026-09-08)

The user explicitly approved:

> 外部通信を遮断し、疑似CLIだけを使うCIテストを例外として許可する仕様変更・再レビューを承認する

This resolves the requested decision above and supersedes its pending-approval
status. All six conditions in the proposed limited exception remain mandatory.
The approval does not waive native Windows execution, permit provider calls,
authorize production credentials, relax consent for real collection, or treat
historical failures as passing. RT-20260908-002's production-fix scope remains
unchanged; this is an additional specification/verification-boundary decision.

Before enabling any CI invocation, specify and independently review the actual
network-denial mechanism, its process-tree coverage, negative-control test,
fixture executable attestation and fail-closed behavior. Preserve previous
review rounds and re-bind amended inputs through the formal gates. A process
with no network calls observed is not evidence that outbound access is denied.
No workflow, protected runner or frozen specification was changed by recording
this decision, and no native Windows result is claimed.
