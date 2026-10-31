# A8 normal idle identity candidate — preparation

Task: A8 spec launch identity-source repair, candidate only.
Owner: /Users/jrmag/.codex/worktrees/a8-release-sync-oct01/sdd-forge
HEAD: 495c88d67af44530687ecea3ce9fb0a90a336539
Risk: high — changes identity issuer guarantee; formal independent review and sanctioned protected application remain mandatory.
RELEASE_READY: false

Before editing, read owner AGENTS.md and docs/development-policy.md. Existing dirty changes include shared validators, workflow-state, other skills, ledger, A8 specifications and historical reports; none are owned by this repair. The spec-review-loop SKILL is clean. Only new files in this candidate directory are written. No protected originals, frozen specification bytes, reservations, verdicts or prior outputs may change.

## Scope and persisted-field preflight

The application patch changes only three spans in spec-review-loop/SKILL.md. Invocation schema, ledger uniqueness/hash chain, reviewer role, model and permissions remain unchanged. The small launcher adaptation reuses A7's native empty-child pattern, not its non-TTY recovery exception. It is candidate support material, not a production launcher or permission grant.

| Evidence field | Counterpart | Required mismatch rejection |
| --- | --- | --- |
| invocation.run_id | orchestrator fresh per-reviewer allocation record, ledger and returned output | reused run, partial run/session match, output run mismatch |
| invocation.host_session_id | actual host allocation receipt, idle child, returned output | caller UUID substituted for host receipt, wrong child, reused session |
| receipt idle state | first turn occurs after REVIEW_CONTEXT_OK | prior user/assistant turn, inherited review inputs, reserve failure followed by dispatch |
| role/model/read-only | actual child configuration and exact role source | wrong role, model or write capability |

Existing deterministic uniqueness and output-match checks are retained; no new fixture receipt oracle is presented as enforcement. Live host identity/idle/configuration acceptance remains an explicit required observation.

## Baseline SHA-256

- SKILL: b816d5a7f09d458ecd9cab3cf23b7a2f52433ddde3badf80b3ff8d22bf46dad9
- identity-ledger.json: c95ef67d1c227c8d31320a2dd526d50940dd52745240189e7e29eb9460986264
- attempt-4/round-1/precheck-result.json: 3718c701f23907c710c3c98cb1cc64faec5d906bdbd577b2882c92d5bca32467

## Consumer search and compatibility

The issuing-authority wording resides at spec SKILL lines 44, 71–80 and 134–136. Shared validator sh lines 496–498, 562–563, 660–668 and 989–993 checks syntax, independent uniqueness and partial matches, not run issuer. Its PS twin remains unchanged. Spec precheck sh lines 172–173, 254–257 and 333–338 requires output identity matching. Workflow-state sh lines 1337–1338, 1474–1478 and 1555–1560 retains matching and distinct A/B identities. Contract template already distinguishes reviewer run IDs from integrated orchestrator run ID. Review-context-boundary and role contracts remain unchanged.

A7 non-TTY recovery is not reusable here: its opt-in requires run_id == host_session_id and post-reservation CLI acceptance. This candidate instead requires real host idle allocation before reservation. No claim is made that every host supplies it, or that an unavailable API does not exist.

## Required production sequence (not executed)

1. Allocate a fresh native Claude custom-agent empty child using the existing --bg pattern, Sonnet, dontAsk, read-only tools and DEVNULL stdin; no review prompt or inherited conversation. Preserve actual child metadata and transcript, not only parent warning text.
2. Obtain actual host-issued session/thread ID from host state. Verify exact role definition, effective Sonnet/dontAsk/read-only configuration, no review input, zero user/assistant turns. Stop if unprovable. No caller --session-id substitute.
3. Separately allocate a fresh orchestrator per-reviewer run ID and persist correspondence with that host receipt. This record is neither host-issued run identity nor human signature. Integrated orchestration run ID is separate.
4. Bind current admitted input hashes and ledger tip in a single-role invocation; normal validator --reserve exactly once. Require REVIEW_CONTEXT_OK.
5. Deliver the first review turn to exactly that host session, then validate raw canonical output and matching IDs with original validators. No dispatch on reservation refusal.
6. Only after A succeeds, allocate independent fresh B by the same process. B receives only canonical sanitized A summary, never A raw output.

No host allocation, dispatch, reservation, formal review, CI or native acceptance is authorized by this candidate's fixture success alone.

## Concrete existing host route and limits

The reused source is A7 owner `reports/verification/a7-impl-attempt6-custom-idle-launch.py`, with native --bg and stdin=DEVNULL. The candidate adapts owner, spec role/name/description and exposes functions for mocked inspection. Independent review found the source's Bash tool inappropriate for spec roles: the candidate now uses `--tools Read,Grep,Glob` and the same custom-agent tool list, matching spec A/B frontmatter. It adds no --allowedTools, --session-id, resume option or skip-permissions flag.

Existing A7 `a7-impl-attempt5-custom-idle-receipt-20261006.md` records `claude agents --json --cwd <owner>`, `claude logs <actual-job-id>` and `claude attach <actual-job-id>` for the actual allocated child. The attach route, after receipt and normal reservation, targets the same existing child for its first prompt; no new caller-UUID session is substituted. A8-specific receipt, first-prompt byte fidelity and output acceptance are NOT VERIFIED. Do not treat a TTY-delivered prompt as byte-identical without observing it.

The prior A7 `a7-impl-attempt6-host-policy-diagnosis-20261006.md:9` records actual Bash denial under dontAsk. This candidate does not solve or waive a host permission refusal. If A8 encounters one, stop with its exact diagnostic; no permission-rule replacement, executor change, or additional reservation is part of this package.

Spec role A lines 50–64 delegates the pre-reservation validator to the caller and requests verification from REVIEW_CONTEXT_OK/manifest. The shared boundary additionally requires record/input digest computation. A native hash-computation route using only the spec role's Read/Grep/Glob has NOT been demonstrated by this package. No Bash allowance is inferred from that requirement; if unavailable, it is a separate launch-contract inconsistency to resolve before formal dispatch.
