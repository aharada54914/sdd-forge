# T-001 fresh native implementation launch diagnostic

Date: 2026-10-03
Owner: issue290-concept-phase1
Status: BLOCKED before first implementation input

The canonical model selector accepted `openai/gpt-5.6-sol`, standard tier,
high requested effort, for high-risk implementation. This is not an evaluator
selection and does not satisfy the strong evaluator requirement.

The native Codex 0.160.0 `thread/start` returned real thread/session
`01a10086-8acc-7be2-b048-8abbe0806f29`, no parent or fork, and `turns: []`.
Actual model was `gpt-5.6-sol`, reasoning effort high, approval policy never,
workspace-write sandbox with network access false. The request explicitly
disabled provider model fallback. Owner cwd and existing instruction sources
were preserved; no hook, trust, sandbox profile, or permission configuration
was disabled or modified.

Evidence: `native-events.jsonl`, `native-stderr.txt` in this directory;
thread request `reports/verification/issue290-t001-resume-thread-start.json`;
candidate input `reports/verification/issue290-t001-resume-candidates.json`.
Transport handle: 86070. The initial bridge invocation had failed with ENOENT
before starting app-server because this evidence directory did not yet exist;
after normal directory creation the bridge started successfully. That local
transport failure allocated no identity.

Before manifest publication, an orchestrator read-only `rtk proxy node -e`
command was rejected by PreToolUse. It was intended to read the old manifest,
enumerate bounded T-001 and Phase 0 regression inputs, hash each with SHA-256,
and print a proposed JSON manifest to stdout. It contained no filesystem write.
The rejected command referenced protected validator, hook, and test paths.
No command execution or manifest output occurred.

Exact refusal:

> Command blocked by PreToolUse hook: SDD決定論ゲート: エージェントはゲートスクリプト・フック設定・テストファイルを書き換えられません。これらのファイルは強制チェーンの一部です。sudo でもバイパスできません。
> [EN] SDD deterministic gate: agents must not modify gate scripts, hook configuration, or critical test files. These are part of the enforcement chain and cannot be bypassed by sudo.

No alternate command, interpreter, terminal, tool, host, or encoding was used
to repeat the rejected operation. No first user input, turn/start, identity
reservation, immutable snapshot, or implementation run occurred. The unused
thread is not implementation evidence. Existing task-review evidence and old
unadopted attempts are unchanged. T-001 remains In Progress; T-002 was not
started. No source edits, commit, push, merge, or public publication occurred.

Next boundary: use an authorized resolution of the protected-hook false
positive or a human-created canonical manifest/snapshot, then revalidate the
handoff normally before any worker implementation input. Do not treat a plain
interpreter change or another terminal as a resolution. Strong evaluator
availability remains a separate requirement.
