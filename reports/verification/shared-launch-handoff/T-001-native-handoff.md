# T-001 native handoff: implementation turn completed; acceptance pending

## Completed execution (supersedes execution status below)

Native turn 01a119f1-18ad-7c90-bd08-acc0fe8e04e1 completed without error at 2026-10-08T05:27:36Z; exact observed notification is T-001-native-turn-completed.json. The child coordinator retained monitoring because shell handle 2986 is child-owned. No duplicate implementation turn was started. The app-server remains idle; the task is In Progress, not Implementation Complete or Done.

Canonical output report: T-001-output/staged/reports/implementation/shared-review-launch-repair/T-001.md. Adoption inventory: T-001-output/verification/T-001/adoption-inventory.json. Two source/test files changed, 24 staged inputs unchanged, all 48 immutable input hashes rechecked. This run recorded 43 GREEN; disposable rollback restored 26 before-byte hashes, reproduced the added-test RED against original code and passed the 42 original baseline tests. Native reviewer permissions, CI, independent review and quality gate remain NOT RUN.

For a later task, reuse only the configuration/procedure shape in T-001-native-thread-start.json, T-001-effective-mcp-status.json, T-001-snapshot-inputs-v2.json and T-001-turn-start.json. Never replay their task, identity, paths or cost without fresh per-task resolution: create a new output root and immutable snapshot, obtain a new native identity, inspect effective tools, bind a fresh manifest and validate individual plus batch before turn/start. T-005 has NOT been started.

## Resolved and execution started (supersedes stop record below)

At 2026-10-08T05:16:33Z the actual approved T-001 implementation turn started. Live app-server shell handle: 2986. Native thread/session/agent instance: 01a119f0-3fc5-7b31-998e-34f90076b5ba. Native turn: 01a119f1-18ad-7c90-bd08-acc0fe8e04e1. Response status inProgress and turn/started observed. Parent coordinator owns monitoring from this point.

Isolation resolution used --no-daemon and session-local explicit per-server enabled=false with preserved transport command, including plugin-contributed servers, not empty merge tables. Effective mcpServerStatus/list returned all 10 servers disabled, tools={}, nextCursor=null; full response is T-001-effective-mcp-status.json. No global configuration or hooks were changed. SessionStart hooks still ran normally. Final thread/start config is preserved in T-001-native-thread-start.json. PTY was switched to noncanonical/no-echo before starting the server to avoid JSON line-length truncation; no wrapper program was created.

Current T-001-manifest.json binds the real fresh identity above. Individual snapshot-v2 and sole-active-manifest batch validation each returned TASK_INPUT_OK immediately before the exact saved T-001-turn-start.json request was sent. The never-executed earlier manifest is preserved as T-001-retired-bootstrap-manifest.txt and excluded from the execution batch. Earlier immutable snapshots and failed metadata sessions remain preserved. The additional never-executed metadata thread 01a119ef-8c5f-7603-928b-24ecc6789563 showed four plugin MCP channels before final per-server disable; it has no implementation turn.

This is launch evidence only, not implementation completion, independent review, quality gate, CI or Done.

## Final stop record

Both metadata-only native sessions were stopped without any turn/start. Session 6804 / thread 01a119e8-7853-72c3-8d05-3ebe31651645 was stopped after inherited MCP channels were observed. A process-local explicit mcp_servers.node_repl.enabled=false override failed before startup with invalid transport in mcp_servers.node_repl. A second metadata-only session 63903 / thread 01a119ea-560e-7892-a54c-08b3bf909be8 used process-local mcp_servers={}, plugins={}, features.apps=false, features.browser_use=false, features.computer_use=false. It still started inherited node_repl, pencil, playwright, computer-history, cua_repl, openai-api-key-local-confirmation and creative_production_mcp. Therefore it too was stopped before a model turn. No global configuration changed. These failures are preserved; the previous live-stdin instruction is now stale and MUST NOT be executed.

The remaining blocker is an effective session-local MCP/tool disable configuration supported by this native app-server build. A config request alone is not proof. The manifest validation is genuine but does not prove complete host tool isolation. Use a fresh actual implementation identity after resolving this capability, and rebind/revalidate the manifest and pending request. Global AGENTS is standard host governance, not inherited chat history; it is not a blocker.

This record supersedes unresolved routing/identity statements in T-001-preparation.md; it does not authorize or claim implementation.

## Actual native identity and isolation observation

- Native app-server CLI 0.160.0, initialized with sdd-t001-file-handoff/1.
- Live shell session: 6804. Parent may continue it through write_stdin.
- Native thread.id and thread.sessionId: 01a119e8-7853-72c3-8d05-3ebe31651645. Created 2026-10-08T05:07:08Z, idle, no model turns, no parent or fork.
- agent_instance_id is the actual native root agent thread.id, not a synthetic additional host identity. run_id is the orchestration label T-001- followed by that identity.
- thread/start response: gpt-6-astra, openai, high; cwd/runtimeWorkspaceRoots are this checkout's reports/verification/shared-launch-handoff/T-001-output only.
- workspaceWrite, writableRoots [], networkAccess false, excludeTmpdirEnvVar true, excludeSlashTmp true, approvalPolicy never.
- model/list actually returned gpt-6-astra with high support before thread/start.
- Automatically loaded instructionSources: /Users/jrmag/.codex/AGENTS.md and owning checkout AGENTS.md. Global working agreements were read; repository AGENTS is snapshot-pinned.
- Existing MCP servers also started (node_repl, codex_apps, playwright, creative_production_mcp, cua_repl, openai-api-key-local-confirmation, pencil, computer-history). Their ability to bypass the shell write boundary is NOT verified. No model has received tools or started execution yet.

## Pinned handoff

- Original snapshot preserved. T-001-snapshot-v2 contains 48 current hashed inputs, including v2 registry, historical cost provenance and known runtime/test dependencies; prepared by checked-in prepare-task-snapshot.sh: TASK_INPUT_OK.
- T-001-manifest.json is real identity-bound task-input-manifest/v1. Individual validation against snapshot-v2: TASK_INPUT_OK. Batch validation (sole persisted execution manifest): TASK_INPUT_OK. These are manifest validation results, not launch permission or task acceptance.
- Selector with --registry contracts/agent-model-capabilities.v2.json and historical launch-candidates selected strong / gpt-6-astra / high / 48.22 USD. This is an explicitly historical API-equivalent workload estimate dated 2026-09-28T05:01:53Z; not this task's measured charge, subscription billing, or cost cap. Source documents are snapshot-pinned.
- T-001-turn-start.json holds the exact pending JSON-RPC request, with only immutable input handoff and approved T-001 validation/deficiency-fix scope. It has NOT been sent.

## Exact remaining operation and constraints

Before sending turn/start, resolve effective tool isolation: inherited MCP channels must not allow writes outside the declared output root, and inherited global instructions must be handled as explicit host governance rather than silently claiming snapshot-only context. If the host configuration needs a fresh thread, do not reuse this identity: republish an identity-bound manifest and update request, validate again, and leave this attempted metadata bootstrap visible.

When that condition is satisfied, send the complete bytes of T-001-turn-start.json followed by a newline to the live app-server stdin (shell session 6804). Do not use codex exec resume as a substitute without re-verifying the effective configuration. No dedicated launcher was created.

The coordinator must inspect the first response and progress, preserve the dirty owner candidate, and alone handle task lifecycle. No reviewer identities reserved; tasks.md, implementation sources, report acceptance, ledger and Git were not modified. RED/GREEN, rollback, independent review, quality gate and CI remain NOT RUN.
