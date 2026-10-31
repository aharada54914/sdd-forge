# A8 Claude Read availability: normal-TTY diagnostic (2026-10-05 JST)

Status: inconclusive for the normal-TTY Read tool. No formal reviewer or quality-gate run was started, and no existing reservation, verdict, or implementation report was changed.

## Observations

- Before this diagnostic, `claude agents --json` still listed the A8 background session `46eca1b7-e7be-432f-84c0-1ff770416b4f` as `idle` / `working` (PID 58899). It was not resumed, restarted, or sent a prompt.
- A direct PTY call to `claude` through `rtk proxy` exited before interactive startup with `Input must be provided either through stdin or as a prompt argument when using --print`. The normal-TTY test therefore used `/usr/bin/script -q /dev/null` with the same installed Claude executable. This changes only terminal attachment; it did not disable hooks or broaden permissions.
- The fresh interactive session was `aeb7ba9f-8597-4e95-bb85-3b582baf5988`, Claude Code v2.1.289, Sonnet 5.5, medium effort, `dontAsk`. The launch declared only `Read,Grep,Glob` as available and allowed; `Bash,Write,Edit,NotebookEdit` were disallowed. The prompt requested exactly one `Read` of repository `AGENTS.md`, expressly forbidding substitution or writes.
- The session reached the model quota before any tool call: `You've hit your session limit · resets 1:10am (Asia/Tokyo)` and displayed 5h usage 105%, 7d usage 51%. The automatically scheduled continuation was cancelled with Escape; this newly created diagnostic session was then exited normally. Its local transcript is `~/.claude/projects/-Users-jrmag--codex-worktrees-a8-release-sync-oct01-sdd-forge/aeb7ba9f-8597-4e95-bb85-3b582baf5988.jsonl`. Filtering its tool-use events yields zero rows. No Read success or failure was observed in this session.
- The earlier background session's transcript (`46eca1b7-e7be-432f-84c0-1ff770416b4f.jsonl`) recorded `No such tool available: Read. Read is disabled for this session, in subagents as well as here.` Its startup advertised Read but its prompt snapshot omitted Read. That earlier fact does not establish the effective tool set of a new normal-TTY session.

## Boundary and next check

Read omission in a normal-TTY session remains unverified because the quota prevented a model tool call. After the 01:10 JST reset, launch a *new* normal-TTY Sonnet diagnostic under the same limited read-only flags and ask for exactly one `Read` of `AGENTS.md`; capture the new session ID, actual tool event/error, and prompt snapshot tool names. Do not resume the background recovery session, reuse a review identity, substitute a different read executor after a Read denial, or alter hooks or permissions. A successful normal-TTY Read would narrow the failure to background-session tool setup; another unavailable Read would warrant inspecting Claude's effective tool-filter construction without altering policy.
