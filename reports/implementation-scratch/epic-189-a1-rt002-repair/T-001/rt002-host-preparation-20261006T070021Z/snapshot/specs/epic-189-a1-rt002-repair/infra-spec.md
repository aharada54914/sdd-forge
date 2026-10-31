# Infrastructure Specification: A1 RT002 bounded repair

## Deployment Topology

Existing local shell wrapper → repository Python verifier for fixtures; installed plugin → actual native host for activation. These are distinct environments and results. No cloud resource, network service, new package or deployment platform is added (REQ-005 / AC-006).

## CI/CD Sequence

1. New repair-only spec/design/task provenance reviews with ordinary identity/hash/schema/cycle rules; recovery contract item 4 is the only unavailable-activation exception.
2. Human task approval and permitted application to protected installed paths; confirm actual installed version and source hashes. If agent application is denied, request only the necessary human operation.
3. Fresh challenge, one native dispatch, unchanged response and original installed-path verifier; exact `HOOK_ACTIVE` is required before ordinary entry resumes. Do not manufacture or normalize captures.
4. Full original-path Bash and PowerShell suites, independent quality gate, latest-head applicable CI including native Windows, conflict/latest-main checks and safe merge. Confirm post-merge CI before closing associated Issues. Approval-review exception, if used, never bypasses CI.

## Environments

| Environment | Trigger | Promotion Rule |
|---|---|---|
| macOS checkout | Original suites and input-hash checks | No substitution for Windows or activation |
| Native Windows CI | Current candidate commit | Original PowerShell suite and all applicable required checks succeed |
| Installed Codex host | Permitted protected application and fresh native challenge | TEST-089 succeeds with actual installed candidate |

## Observability and Retention

Record command, original path, candidate/installed hash, runtime version, start/end, exit, assertions and raw response in new verification addenda. No secrets. Preserve old FAIL/BLOCKED, approvals and task states; no existing record deletion. Challenge freshness is an invocation obligation, not a claim of persistent replay storage. TEST-087–TEST-089 cover these distinctions.

## Rollback

If candidate validation or installed activation fails, remain unavailable and stop ordinary work. Preserve the previous human-created backup; maintainer may restore the pinned prior installed artifact through the same permitted path. Verify its hash and refusal behavior, but do not treat restoring legacy code as RT002 completion. No automatic guard disabling or cache rewrite. Owner: maintainer.

## Capacity, Cost and SLOs

N/A — no change: one existing local verifier invocation, no service availability promise, storage service or paid infrastructure. Reuse existing CI; do not add redundant lanes or weaken checks.

## Open Questions

None; native Windows and installed-host outcomes remain pending evidence.
