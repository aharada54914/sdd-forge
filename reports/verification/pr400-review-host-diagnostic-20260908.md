# PR #400 reviewer-host diagnostic (2026-09-08 JST)

Scope: read-only host diagnosis, not a specification review or quality-gate verdict.

## Current external state

GitHub snapshot f93dc3: open PRs 245, 371, 381, 390, 394, 400 retain their
previous heads. Run snapshot 93c291 shows PR400 run 34033392134 completed
successfully and PR394 run 34023439393 completed with failure. No active CI
wait is claimed. No PR was merged or issue closed by this diagnosis.

## Hook warning is not evidence that SDD guards were discarded

The installed CLI is 0.147.0. `codex doctor --summary --no-color` (13a08e)
reported working authentication/connectivity/configuration, and availability
of 0.153.4. Its exit 1 was accompanied by the TERM=dumb terminal failure;
this is not an inference/review failure. No update was installed.

A diagnostic app-server was started with its existing settings, RUST_LOG=warn,
and stdio transport. `initialize` succeeded (dae160). An ephemeral, read-only,
network-disabled thread with no model turn was allocated (ffca9b):
`01a07ca2-4086-7a31-962d-8fc83ccc4a6a`.
It is a diagnostic identity, NOT a reviewer reservation or review result.
Four manifest warnings reproduced; their log target is
`codex_core_plugins::manifest`, with no source path attached.

Crucially, `hooks/list` for `/Users/jrmag/sdd-forge` (901316) returned both:

| SDD hook | enabled | trustStatus | currentHash |
|---|---|---|---|
| kill-switch.sh | true | trusted | sha256:3eb9f8d1359b411fde8f67c2aa1e791c22068150231a242a414dc85aed9f5d04 |
| sdd-hook-guard.sh --emit exit | true | trusted | sha256:28f5ea576551dd2fe287fc22645a2f4b57256ada78e9cd5b89029335b0c275d6 |

Both originate from the installed sdd-quality-loop 1.17.0 hooks/hooks.json;
the listing reports no warnings or errors. This is discovery/trust evidence,
not a fresh end-to-end protected-write denial test. It supersedes treating
the four unattributed manifest warnings as proof that SDD hooks are unavailable.

The installed browser/chrome 26.901.51231 manifests contain inline Stop
mcp_tool handlers; SDD quality-loop uses a string hook-file path (0cf516).
They remain warning-source candidates, not proven attribution. Official
[hook documentation](https://learn.chatgpt.com/ja-JP/docs/hooks) permits both
inline objects and paths, and documents hook trust separately from plugin
enablement. Therefore neither an object-valued hooks field nor installed=true
alone proves a defect or enforcement. The official
[app-server reference](https://learn.chatgpt.com/docs/app-server) documents
hooks/list as a read operation.

The diagnostic server was stopped using its own PTY Ctrl-C (2f6c37, exit 1).
No model turn, hook disabling, trust bypass, configuration mutation, or
protected-file write was performed.

## Next formal-launch prerequisite

Re-read spec-review-loop's sequential-launch boundary, reviewer A's role,
calibration, and review-context-boundary. The skill requires the ledger to
contain the invoking host/implementation identity before reviewer reservation.

A read-only full-chain/uniqueness check (53503a) validated all 959 current
records. Ledger SHA-256:
`968a789a9a597b9c9e6aac294dd9dd230b25793fd687d6f498cb3b58cff4a956`.
Tip: `bfba486d3d7ffd5b94db7b2388594d37cb118c4d5221bcd88e9347139b666f29`.
The current host-issued CODEX_THREAD_ID,
`01a06d01-11b5-7bd3-83a3-7e29bb3c96cd`, is absent. The two existing host-stage
records identify older hosts, not this invoking context. Do not relabel them
or reconstruct history. Resolve current-host registration by an append-only,
audited operation before reserving fresh independent reviewer identities.
The review reservation validator itself only authorizes reviewer/evaluator
stage-role pairs (validate-review-context-set.sh:286); do not misuse a
reviewer role to register an orchestrator.

No review was launched, no reservation appended, and no historical verdict
or specification hash was rewritten during this diagnosis.

## Invoking-host registration follow-up

Appended sequence 960 as stage `host`, role `codex-orchestrator`, using the
actual host-issued CODEX_THREAD_ID above for both identity fields. This is
host bookkeeping, not a reviewer reservation or a review verdict. The
reservation validator was not used with a false reviewer role.

Verification 99878a compared the ledger to HEAD: all 959 historical records
remain identical, exactly one record was appended, all 960 record hashes and
links validate, run/session identities remain unique, and the new identity
matches the invoking process's CODEX_THREAD_ID. New tip:
`54fa8d6d0249ab01745e1231e2ea92655878847805b4b0e61191518f021e7957`.
`git diff --check` passed (08bbbe). No independent reviewer has yet been
launched; the registration alone does not satisfy any review gate.

## Compatible host located and actual review launched

The PATH-selected CLI 0.147.0 accepted thread allocation but its Astra turn
was rejected with HTTP 400 requiring a newer Codex version. Sequence 961 is
a consumed reservation with no review output; the round's
`reviewer-a-launch-error-20260908.md` preserves the failure.

The already-installed `/Applications/ChatGPT.app/Contents/Resources/codex`
reports 0.153.4 (cf676e). No installation, settings change, or hook bypass
was necessary. Its `hooks/list` response (ca1fdb) again shows both SDD hooks
enabled/trusted with the same hashes recorded above, with no listing errors.

Fresh read-only/network-disabled Astra thread and session:
`01a07cab-aa38-7890-aa11-5f0684290712`.
Reservation sequence 962 succeeded (2dcf5c), record
`227348cf04f3ac93546742fa39fc84e8fe20925b409af9b61ac45217e046948f`.
The first model turn `01a07cac-4b97-73c1-964d-3a3ea5cd5ce1` was accepted
(d43572) and performed read-only review input reads. Both SDD pre-tool hooks
emitted completed events during those reads. Unlike the old CLI attempt,
this is an actual running review, not merely an allocated host. Its result
must still be captured and validated before any gate decision.

## Actual review completion

Both independent turns completed and their raw JSON was preserved in
`reports/spec-review/epic-136-phase4-docs/attempt-3/round-1/`.
Reviewer A returned NEEDS_WORK (2 Major failed checks). Reviewer B, fresh
session `01a07caf-a72a-7b12-aa7a-a05bf6d6ab9b`, reserved sequence 963 and
returned NEEDS_WORK (1 Critical and 4 Major failed checks). B received only
the canonical allowed inputs and the sanitized A summary, not A's findings.

Read-only validation da7c8c checked identities against the invocations,
distinct sessions, exact schema keys, current allowed-input hashes, ordered
checks, and the derived sanitized summary. The integrated result is
NEEDS_WORK, Critical 1 / Major 6 / Minor 0, warningCount 0; these are
per-check counts, not unique issue counts. The contract and rendered report
were persisted only after this validation. `git diff --check` passed
(b9434c). Requirements remain Pending; no Done, commit, push, or merge.

Next corrections must establish observable completion ordering for boundary
tests, resolve the documented empty-verdict exit-code contradiction without
changing the gate's safety behavior, explicitly test both default-timeout
fallback branches, and condition shared protected-list assumptions on
review-time re-verification. Preserve the round and pass amended inputs
through the next official precheck before new independent review. Existing
implementation/design/task provenance is not satisfied by CI alone.

The user's latest cost preference supersedes routine parallel delegation:
the main agent handles ordinary investigation, fixes, and tests directly;
fresh independent contexts remain limited to mandatory review gates.
