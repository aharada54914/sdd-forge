# A7 implementation provenance attempt 6

Existing impl-review-loop Post-Implementation Provenance Re-Review steps 1–3 authorize the new M+1 attempt with Passed unchanged and historical PASS. impl-review-precheck.sh:253–273 checks historical PASS; no completed immediately preceding attempt is required. Same-session recovery is not used. Spec recovery extensions are not used.

Ordinary `impl-review-precheck.sh epic-195-a7-compatibility 6 1 --provenance-rereview`: exit 0. Stale impl predecessor hash was the documented advisory. Current `--verify-inputs`: exit 0 before reservation.

Initial unreserved allocation ce20ef78-46c7-401f-bb22-49db012fdefb inherited the orchestrator Python heredoc as stdin, so was not an empty reviewer context. Native user text contained that preparation code, not formal review inputs. It was stopped and is excluded. No reservation or formal prompt was sent. This was an orchestrator launch error, not a product contract change.

Replacement helper `a7-impl-attempt6-custom-idle-launch.py` explicitly supplies DEVNULL stdin. Fresh child 375df7fc-5e82-45ec-bd6a-065258d360a5 has intent empty and native user/assistant count 0. Native UI shows @impl-reviewer-a, Sonnet 5.5, Claude 2.1.290, dontAsk. Job respawn definition prompt SHA256 6d302654a8662e233e038e254548bad68d593cd1181433174f9c950bc6a2b7aa equals the full original role. Tools Read/Grep/Glob/Bash; denied Write/Edit/NotebookEdit. No permission expansion, trust modification, or hook disabling. Read-only is a role/tool contract, not an OS-isolation claim.

The parent bg warning is the already diagnosed parent-side lookup limitation, while the child accepts the custom role. Child state: /Users/jrmag/.claude/jobs/375df7fc/state.json; native transcript under /Users/jrmag/.claude/projects/-Users-jrmag--codex-worktrees-a7-t005-intake-sdd-forge/375df7fc-5e82-45ec-bd6a-065258d360a5.jsonl.

Attempt 5 remains interrupted, no canonical verdict or B. Reserved sequence 1213 is consumed and preserved. New delivery must disclose the orphan, require exact manifest paths only, stdout-only hashing, no temporary writes or globs, and stop on actual refusal. No status transition is justified until genuine canonical A/B and original validation succeed.
