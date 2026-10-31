# Codex app-server idle-allocation diagnostic (2026-10-05 JST)

Scope: alternative host lifecycle only. This was **not** a formal A7 or A8 reviewer launch, a precheck, an identity reservation, or a verdict. No reviewer inputs were supplied and no model turn was started.

## Installed CLI and local contract

- The former `/Applications/ChatGPT.app/Contents/Resources/codex` path is absent (`ls`: No such file or directory). `/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex` is present, reports `codex-cli 0.159.0-alpha.12.1`, and its shell wrapper executes the bundled `CodexCLI.app/Contents/MacOS/codex`. `app-server --help` exits 0 and lists stdio transport.
- The installed `plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md` independent-reviewer step 2 expressly permits an empty, idle host context to obtain host-issued identity **before** reservation, followed by the first turn only after `REVIEW_CONTEXT_OK`. Failure handling says an allocation receipt must show no review execution and forbids retroactive reservation. This is the local lifecycle contract used here; it does not authorize bypassing a guard denial.
- The installed CLI's generated JSON schemas (`app-server generate-json-schema`) separate `thread/start` and `turn/start`. `ThreadStartResponse.thread.id` is described as a Codex-generated UUIDv7; its response has `thread.status` and `thread.turns`. `TurnStartParams` requires `threadId` and `input`. No `run_id` or second host-issued review identity appears in `ThreadStartResponse`.

## Independent bounded probe

An isolated app-server stdio process was initialized with client name `codex-idle-allocation-diagnostic`. It received only `initialize`, `initialized`, then `thread/start` with the A8 owner checkout as `cwd` and `ephemeral: true`. No approval-policy or sandbox overrides were passed. The process was terminated after the response. Its filtered response was:

```json
{"result":"ok","error":null,"threadId":"01a10790-c982-7cf2-a890-1b326b959604","status":{"type":"idle"},"turnCount":0,"instructionSourceCount":2}
```

This proves that this bundled CLI can allocate a host-generated empty thread and return its ID before a model turn. It does **not** prove that a reviewer can subsequently complete a guarded first turn, that a host-issued `run_id` distinct from the thread/session ID can be acquired before execution, or that this ephemeral diagnostic thread can be used as a formal review context. No `turn/start`, review input, `validate-review-context-set --reserve`, or existing-session operation occurred. Existing Claude Read/Bash denials were not retried through Codex.

## Minimal next step

Before any formal reservation, settle and document the exact mapping from app-server-issued values to the invocation's `run_id` and `host_session_id`. The observed pre-turn response supplies one UUIDv7 thread ID, while the spec-review contract names both host-issued run and session identities; inventing a second ID or equating two fields silently would not establish that contract. Once that mapping is validated against the installed role/validator contract, a separate fresh idle context may be allocated for one named role, its receipt preserved, the normal manifest/precheck/reservation run, and only then the first `turn/start` in that same context. A reservation or first-turn refusal remains a hard stop, not a reason to retry through another executor.
