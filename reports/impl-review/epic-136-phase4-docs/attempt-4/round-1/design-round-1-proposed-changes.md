# Implementation Policy Review Report: epic-136-phase4-docs — Round 1 / Attempt 4

## Verdict: NEEDS_WORK

| Field | Value |
|---|---|
| Feature | epic-136-phase4-docs |
| Round | 1 of 3 |
| Attempt | 4 |
| Reviewer-A Verdict | NEEDS_WORK |
| Reviewer-B Verdict | NEEDS_WORK |
| Critical Findings | 0 |
| Major Findings | 4 |
| Minor Findings | 0 |
| Generated | 2026-09-07T23:50:51Z |

Counts include every FAIL across both reviewers, without deduplicating overlapping concerns. Severity labels on PASS/SKIP checks are not findings. Raw reviewer results remain unchanged.

## Reviewer-A Findings (Structural Soundness)

### SECURITY-COVERAGE — Major

PowerShell descendant cleanup remains an unresolved implementation-policy decision. design.md:154-173 requires tree termination and independent descendant liveness, expressly states that the concrete descendant-cleanup mechanism remains a design-review prerequisite, and acknowledges that Kill($true) cannot alone prove the no-orphan requirement. The subsequently selected mechanism at :175-205 resolves I/O ownership but still only requests tree termination; it does not select how the runner retains descendant reachability when the root exits before termination or enumeration. security-spec.md:21-27 explicitly requires this gap resolved before implementation review passes. A c2 child can be observed live, exit before the tree-kill request, and leave its descendant running; returning exit 1 or independently detecting that survivor in TEST-004 does not fulfill requirements.md:53-75 and acceptance-tests.md:64,80. This is Major because the design leaves a required security outcome dependent on an unspecified mechanism. Specify the bounded descendant-ownership/cleanup mechanism, including the root-exits-first case, for each supported PowerShell platform.

### ADR-PRESENT — Major

Required ADR existence evidence cannot be verified within this review's authorized scope. design.md:89-112 selects a process-ownership architectural change and references proposed docs/adr/0033-panelist-supervisor-process-ownership.md, but that ADR is not an allowed manifest input. No unlisted existence probe or file read was performed. This finding does not assert that the ADR is absent; it records the missing admissible evidence for the mandatory ADR-PRESENT check. Major because the new architectural decision cannot receive a verified ADR-PRESENT result until the review contract supplies an authorized way to establish the referenced ADR's existence.

## Reviewer-B Findings (Implementability/Risk)

### OPEN-QUESTIONS-RESOLVABLE — Major

TYPE-H: A blocking implementation decision remains unresolved without an owner or concrete resolution path. design.md:158-165 explicitly says root exit cannot establish descendant termination and calls the concrete descendant-cleanup mechanism a design-review prerequisite. The subsequently selected mechanism at :175-205 resolves I/O ownership, but its timeout path still only requests tree termination and observes fixture liveness; it does not select how descendants remain identifiable and terminable after their root exits or when tree enumeration skips them, limitations acknowledged at :170-173. security-spec.md:21-27 explicitly requires this prerequisite to be resolved before implementation review passes. A competent implementer must therefore still invent a mechanism central to AC-004's no-orphan outcome. Resolve and assign this substantive open decision, with its implementation-blocking status and concrete resolution path. This is not a finding for the absent legacy Open Questions heading.

### ASSUMPTIONS-VALID — Major

TYPE-H: Current protection classification is not grounded for this review's complete target set. requirements.md:186 and :194-203 require refreshed, source-hash-bound classification at every design-review boundary, and :234 requires additional targets to be classified before consumption. The bound observation at requirements.md:206-240 is expressly collected for specification review and classifies runners, policy, threat model and the untouched gate. design.md:40, :45-46 and :255 additionally include the shared helper and both test suites, but the reviewed package contains neither a refreshed design-review observation nor source-backed classification of those additional targets. Merely labeling the helper protected at design.md:40 and infra-spec.md:24 does not supply the required observation. This can misassign which implementation changes require human application and leaves BL-005's present review prerequisite unsatisfied. Obtain and bind the prescribed current evidence; no unlisted guard source was inspected. [LEGACY COMPAT] The absent standalone Assumptions heading is itself only advisory.

## Proposed Changes

These are proposals, not applied specification changes or passed implementation evidence.

1. **SECURITY-COVERAGE / OPEN-QUESTIONS-RESOLVABLE**: select descendant ownership established at launch, independent of the immediate child's lifetime, for every supported PowerShell OS. Root owns the design correction; implementation stays blocked pending a reviewed concrete mechanism. Windows Job Objects with assignment at process creation are a candidate; do not rely on Start-Process followed by assignment or tree enumeration after root exit. Explicitly specify handle inheritance, nested-job behavior, unsupported-platform failure, bounded termination/observation, argv compatibility, and root-exits-first regression fixtures. POSIX PowerShell needs its own selected ownership mechanism; the Windows candidate alone does not resolve this finding. Propagate the selected decision into design, security/infra specifications and the ADR under the authorized amendment workflow.
2. **ADR-PRESENT**: reconcile the mandatory ADR existence check with the current reviewer-input allowlist. Request a narrowly scoped, separately reviewed change admitting only the design-referenced canonical `docs/adr/NNNN-*.md` paths, hash-bound in precheck/invocation/contracts and checked consistently by downstream validators. Preserve path traversal/symlink exclusions and A/B isolation; no arbitrary repository input access, ad hoc reviewer exception or fabricated PASS. This expands the protected review-contract/validator scope and requires explicit human authorization and the applicable ticket workflow before implementation.
3. **ASSUMPTIONS-VALID**: before the next design review, collect current source-hash-bound protection classification for the full target set, explicitly including the shared helper and both test suites. Bind the resulting classification to the review's authorized inputs through the sanctioned specification/addendum workflow. The user's attachment records `errors=0` but expressly is source excerpts only, not a computed protection verdict. Do not treat collection success as a runtime protection test, and do not silently broaden the earlier specification-review observation. Re-verify shared registrations at the review boundary.

### Research grounding for the process-ownership proposal

- Microsoft documents Job Objects as process groups whose ordinary child processes inherit job association, subject to documented exceptions: [Job Objects](https://learn.microsoft.com/en-us/windows/win32/procthread/job-objects).
- `PROC_THREAD_ATTRIBUTE_JOB_LIST` assigns job handles during child creation and requires Windows 10 / Windows Server 2016 or newer; an explicit inherited-handle list has separate requirements: [UpdateProcThreadAttribute](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-updateprocthreadattribute).
- `TerminateJobObject` terminates associated processes including nested jobs, with explicit rights and failure reporting: [TerminateJobObject](https://learn.microsoft.com/en-us/windows/win32/api/jobapi2/nf-jobapi2-terminatejobobject).

These APIs inform a design candidate; no Windows implementation or real-OS validation was performed in this review.

## Next Steps

The impl-review-loop skill STEP 6 says: “Halt and await human action.” Its boundaries forbid self-approving findings. Present this report, resolve the substantive design and the new review-contract scope with human involvement, then re-invoke round 2 with an accurate edit summary and fresh reviewer identities after input verification.

No frozen spec, task status, product script, guard, or CI requirement was changed by this report. The retained historical Passed header does not supersede this NEEDS_WORK result. No commit, push, merge or issue closure is justified by this round.

## Post-persistence checks

- `check-workflow-state.sh --feature epic-136-phase4-docs`: exit 1, `stage-provenance: impl integrated verdict is not a valid PASS`. This is an unresolved gate, consistent with the recorded NEEDS_WORK; it is not reported as success.
- `git diff --check`: exit 0.
