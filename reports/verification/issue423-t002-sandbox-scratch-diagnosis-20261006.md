# T-002 sandbox and historical scratch diagnosis

Non-frozen diagnostic record, not a formal quality-gate verdict. No reservation,
task state, prior evidence, protected source or contract was changed.

## Observed sandbox narrowing

The existing caller `01a10d0e-ba06-71f1-b9fe-8ea38f4194e2` was resumed with
`codex exec resume -c 'sandbox_mode="read-only"' <caller-id> --json` in the owner
checkout. Execution handle 78745 completed with exit 0. Its actual persisted
turn context reports `sandbox_policy: {"type":"read-only"}` and approval `never`;
native SESSION_ID and THREAD_ID both remain the caller UUID. This proves caller
permission narrowing, not evaluator execution or activation.

Existing shipped-role child `01a10d20-5c8c-7940-9d81-bd54e116f6bf` was absent from
the live agent list and was not resumed. Its last persisted sandbox remains
`danger-full-access`; its post-narrowing sandbox is UNVERIFIED. No new child was
created, and no manifest was delivered, validator rerun or identity reserved.
The earlier default came from the global `sandbox_mode = "danger-full-access"`;
the role file separately requests read-only. The CLI's internal reason for not
applying that role setting is not established. A heredoc diagnostic attempted a
shell temporary file and was denied by the read-only sandbox; that rejection was
retained, and subsequent diagnostics required no temporary file.

Metadata inspected (only identity and turn-context fields):

- Caller: local session rollout ending `01a10d0e-ba06-71f1-b9fe-8ea38f4194e2.jsonl`.
- Child: local session rollout ending `01a10d20-5c8c-7940-9d81-bd54e116f6bf.jsonl`.

Caller-child session equality alone is not the failure condition: the governing
comparison is with the implementation and prior review/evaluation identities.
The prior STOP record remains unchanged.

## Actual preflight blocker

The original non-reserving invocation failed with exit 1:

```text
REVIEW_CONTEXT_PATH: scratch history contains a non-canonical root
REVIEW_CONTEXT_PATH: feature scratch-history check failed
```

`reports/implementation/sdd-domain-multitarget/T-003-attempt2.md:55` declares
`specs/sdd-domain-multitarget/verification/T-003/run-30ca86925cd6/`.
Its SHA-256 is
`a204e954986c2207f9719174f11c5fca2cf9fcbb877828d78f06f5fea7a6d462`.
The report says the attempt stopped before RED or production changes. The matching
task-input manifest binds the same relative output, logical run/session identity
and input hashes, but has no absolute owner field. The current snapshot directory
exists; the declared run directory does not (`ls -ld`, exit 1). Current location
and matching relative strings do not prove the original execution owner.

The examined report, task-input manifest, handoff-baseline and input-closure audit
therefore do NOT establish a canonical historical owner. Native contemporaneous
launch metadata or an equally bound original receipt is still needed; no owner
has been inferred from the current checkout.

## Existing recovery contract and minimal next scope

`review-context-boundary.md:314-334` requires every known historical declared
root to participate in overlap rejection, preserves original records, and
requires missing bound evidence to be restored rather than synthesized.
The approved recovery described in `issue423-quality-launch-contract-20261002.md`
allows fresh isolated hash-pinned revalidation while retaining old reports.
Versioned same-task manifests at boundary lines 336-348 can be reused for fresh
implementation evidence; they do not authorize remapping a relative historical
root or skipping the feature-wide check.

No existing sanctioned historical-root mapping path was found in those contracts.
First recover contemporaneous owner evidence. If that evidence is absent or
ambiguous, retain BLOCKED: a new run cannot retroactively prove the old root.
If the owner is provable, the smallest candidate contract extension is a separate
hash-bound recovery record linking the unchanged report, exact original root,
original owner receipt, and canonical absolute root. It must not assert historical
OS isolation or successful execution. This is a high-risk evidence-contract change,
not an implementation permission or an approved candidate in this record.

Potential scope: the two `validate-review-context-set` validators, the scratch
boundary contract, and the existing scratch-history regression driver. Reuse the
existing canonical/overlap checks and immutable evidence pins; do not introduce
an unconditional cwd-relative fallback. Require identical Bash/PowerShell results.
Tests must reject missing or altered receipts/reports, wrong attempt/run bindings,
duplicate/conflicting mappings, absolute/relative escapes, ambiguous owners,
symlink escape, missing required evidence, and equal/ancestor/descendant overlap;
retain sibling-prefix acceptance and unchanged canonical legacy behavior. A
missing historical run directory must not be recreated as evidence of past use.

The separate `build passes=false` contract result remains unresolved even though
the historical human FilesOnly assembly and installed-validator run passed. Those
are distinct evidence scopes. No repeated build or protected-operation reroute was
performed. Native canary `WRITE_EXECUTED` / exit 63 remains failed activation;
T-002's documented legacy fallback does not satisfy AC-011/AC-014.

## Resume boundary

There is no live execution handle from this diagnostic and no evaluator reservation.
Do not re-reserve or label diagnostic success as formal PASS. Resolve historical
owner evidence and the sandbox of the actual fresh evaluator under the normal
contract before any formal launch. Existing STOP and failure artifacts are retained.

## Follow-up: contemporaneous owner evidence recovered

The earlier absence finding was limited to repository artifacts inspected above.
A subsequent, read-only examination of historical tool calls (not peer reasoning)
found direct owner evidence in local session
`01a1030d-9eeb-7453-95eb-5fece30a5976` (agent path
`/root/other_pr_readiness/issue423_t003_impl_attempt2`). At
`2026-10-03T18:36:35.103Z`, its `pwd` and exact
`task-input-manifest-30ca86925cd6.json` read used the explicit workdir
`/Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge`.
The tool response at `18:36:35.296Z` returned that exact owner path with exit 0.
At `18:37:59.449Z`, the report-creation patch named that same absolute owner
and `T-003-attempt2.md`, with the identical relative Scratch Root and run id.
Its response completed at `18:37:59.531Z`. These are source tool observations,
not a signed approval or proof that a scratch directory was ever created.

Thus this report's intended owner-relative declaration can be resolved uniquely
to `/Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge/specs/sdd-domain-multitarget/verification/T-003/run-30ca86925cd6`.
The original declaration also has a trailing slash; blindly prefixing owner would
still fail the existing canonical check. Preserve the original raw declaration
and distinguish normalized comparison value from historical bytes.

This eliminates the need to invent an owner or broaden recovery to unknown
owners. It does not supply a currently sanctioned input route: the Bash validator
at lines 1116–1126 reads every original report declaration directly and calls
`overlap`, which calls `canonical` (1076–1081). Neither the existing versioned
same-task manifest nor a new correct current manifest overrides that history.
Consequently an addendum alone cannot clear this deterministic failure without a
bounded consumer change. Retain the old report; bind only this exact report hash,
run id and raw declaration to the independently observed owner if a limited
recovery is adopted. Reject conflicting owner evidence, altered report/source,
unbound mappings, traversal and overlap. Missing historical execution remains
unproven; do not create its directory to manufacture evidence.

Local evidence source: `/Users/jrmag/.codex/sessions/2026/10/04/rollout-2026-10-04T03-36-26-01a1030d-9eeb-7453-95eb-5fece30a5976.jsonl`.
Only a minimal redacted, hash-bound extract should be considered for future
recovery inputs; do not publish the full session transcript or local paths to GitHub.
