# RT004 PowerShell history composition and routing

Status: candidate DATA only; incomplete implementation, not an independent gate.

The composed candidate now inserts the history helpers and routes impl-stage
contract/verdict acquisition through Read-AdrHistoryEvidence before the existing
invalid-verdict opening return. Reviewer A, reviewer B and summary consumers use
the same verified snapshot objects. Other stages retain their existing readers.
Errors are reported without interpolating arbitrary evidence content.

Candidate: adr-workflow-powershell-history-composed-candidate-20260909.patch
SHA256: 38de09c09f6f76d567d31539061905bdef4d7f4e3d484845c691ba9aee7df7d1

Format validation initially failed because the first routing hunk declared one
extra added line. Its count and the subsequent new-line offset were corrected.
git apply --numstat then exited 0, reporting 661 insertions / 6 deletions.
git diff --check exited 0. These are format checks, not application or execution.
The protected original PowerShell validator remains SHA256
7a4663e154e7877362d43916087986849dd7625121d5c058332d3e27eb7b2644.

Root static review of routing: the impl branch obtains all objects before the
existing opening exception; the second reader block does not replace them with
fresh unvalidated JSON. This narrow observation is not a whole-candidate PASS.

Unresolved: before/after path and hash checks are not atomic no-follow opens;
concurrent substitution still needs explicit security review. Strict UTF-8/raw
member checks need Bash parity. Full current-stage ADR freshness and declaration
lexer routing, integration with all consumers, runtime regression verification,
and complete independent review remain required before human application.
Generic ADR diagnostics do not prove each negative fixture's specific rejection
cause. No historical FAIL was changed and no candidate runtime was executed.

Next action: inspect the complete composed reader for legacy compatibility and
path-race handling, finish current-stage and Bash integration, then obtain the
required independent review of the complete patch before requesting application.
No commit, push, merge, issue closure or task-state transition occurred.

## Follow-up static composition review

Found and removed one accidental extra plus before the safe-path helper's
comment. The preceding format-only success did not detect this source-level
defect; it must not be represented as PowerShell syntax verification.
The corrected candidate SHA256 is
748d6b63eb0dfba4ed5371367fb86e85482822d80b549e6223e664e29efcdb97.
git apply --numstat again exited 0 with 661 insertions / 6 deletions.
No candidate was applied or executed.

Fresh GitHub read: seven open PRs, all reported check runs terminal. PR400 has
no failed checks but is Draft/BLOCKED with local formal conditions outstanding.
PR245 is DIRTY; an empty failure list is not evidence of required CI success.
PR401, PR394, PR390, PR381 and PR371 retain failed checks. No live check handle
exists in this observation to justify an idle wait.
