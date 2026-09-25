# Investigation: SDD context continuity

| Field | Value |
|-------|-------|
| Feature | sdd-context-continuity |
| Mode | feature |
| Date | 2026-09-26 |
| Investigator | Codex investigation agent; primary-agent source verification |
| Baseline | `5d5ada70636b3c4774095b8e4139ed83c21f30c3` |
| Source | Issue #137 |

## Scope

Durable local conversation capture and recovery after compaction, while keeping
existing specification and task files authoritative. Investigation only: no
implementation, approval, review PASS, or runtime-support claim is recorded here.

## Summary

Reuse the existing read-only task-state interpretation. Add conversation storage
only after retention, redaction, failure handling, and runtime hook support are
settled. Upstream hook documentation is not evidence of installed-host activation.

## Findings

All repository line references are relative to the baseline above. Recheck shared
hook registrations, path allowlists, and ignore rules immediately before design
review and implementation; this feature does not exclusively own them.

| INV-ID | Category | Finding | Evidence | Confidence |
|--------|----------|---------|----------|------------|
| INV-001 | constraint | Task approval/state and traceability remain authoritative; a recovered conversation must not overwrite them. | `AGENTS.md:36` Sources Of Truth | high |
| INV-002 | pattern | `parseTaskState` already reads task rows, normalizes CRLF, and rejects duplicate IDs. Reuse its interpretation rather than creating a competing task parser. | `mcp/sdd-forge-mcp/src/parsers/tasks.ts:58`, `:67`, `:93` | high |
| INV-003 | api | Active-feature and task-state readers already exist. | `mcp/sdd-forge-mcp/src/tools/core.ts:82`, `:135`, `:163` | high |
| INV-004 | constraint | These readers are internal MCP modules, not a published shared context API; reuse requires an explicit dependency boundary. | `mcp/sdd-forge-mcp/src/tools/core.ts:18`, `mcp/sdd-forge-mcp/src/parsers/tasks.ts:1` | high |
| INV-005 | constraint | MCP root/path validation and guarded reads are not authorization to write a journal. Keep MCP read-only. | `mcp/sdd-forge-mcp/src/root.ts:39`, `mcp/sdd-forge-mcp/src/path-guard.ts:97`, `:175`, `:240` | high |
| INV-006 | test-coverage | Existing read-only tests cover prohibited write APIs and unchanged core-tool snapshots, not journal durability. | `mcp/sdd-forge-mcp/tests/readonly/static-check.test.ts:37`, `mcp/sdd-forge-mcp/tests/readonly/core-tools-snapshot.test.ts:37` | high |
| INV-007 | pattern | The quality-loop hook registrations inspected contain PreToolUse enforcement, not conversation lifecycle handlers. | `plugins/sdd-quality-loop/hooks/claude-hooks.json:1`, `plugins/sdd-quality-loop/hooks/hooks.json:1` | high |
| INV-008 | test-coverage | No matching continuity symbols were found in the bounded source search below. Issue AC1–4 / S1–7 need append-before-interpret and extraction-failure tests. This is not a claim that every repository file was searched. | Search A below; INV-007 | high |
| INV-009 | test-coverage | The task reader can supply authoritative state, but does not validate a recovered materialization cursor or HANDOFF conflict. AC5–6 / S8, S10 need explicit stale-projection tests. | `mcp/sdd-forge-mcp/src/parsers/tasks.ts:67`; Search A | high |
| INV-010 | constraint | Existing guarded reads do not provide journal session identity, retry deduplication, partial-tail recovery, or worktree separation. AC7–8 / S9, S11–12, S16 require separate contracts. | `mcp/sdd-forge-mcp/src/path-guard.ts:240`; Search A | high |
| INV-011 | test-coverage | AC9–11 / S13–15 require host-specific lifecycle and compaction behavior; PreToolUse activation alone cannot prove them. | INV-007; installed-host check described below | high |
| INV-012 | constraint | MCP validates an SDD root. That is not evidence that a future hook is a safe no-op outside an SDD project (AC12 / S18). | `mcp/sdd-forge-mcp/src/index.ts:15`, `mcp/sdd-forge-mcp/src/root.ts:74` | high |
| INV-013 | dependency | Runtime hook contracts must be checked separately for Claude and Codex, including absent transcript/turn IDs and compaction events. Upstream documentation is discovery input only. | Official hook references below | medium |
| INV-014 | dependency | A real Codex native canary denial was accepted by the current handshake verifier as HOOK_ACTIVE. This proves that enforcement call only, not lifecycle callbacks or a candidate plugin's installed entry point. | Private raw denial and verifier result retained locally; no conversation data committed | high |
| INV-015 | constraint | The baseline root ignore file has no `.sdd/context/` exclusion. Privacy needs both untracked-state handling and detection of already-tracked journal paths. | `.gitignore:1` through `:18` | high |
| INV-016 | pattern | Core readers are transport-independent, but the package is private, has no exports map, and bundles only `src/index.ts`. That entry starts stdio transport; do not import it from a hook. | `mcp/sdd-forge-mcp/src/tools/core.ts:1`, `mcp/sdd-forge-mcp/package.json:1`, `:11`, `mcp/sdd-forge-mcp/src/index.ts:11`, `:38` | high |
| INV-017 | constraint | `getSpecStatus` maps every failed guarded read to `exists: false`; it does not preserve the distinction between a missing file and an unsafe/unreadable file. A continuity safety decision must retain guarded-read errors instead of treating that inventory response as proof of absence. | `mcp/sdd-forge-mcp/src/tools/core.ts:141`; `mcp/sdd-forge-mcp/src/path-guard.ts:240` | high |

Search A, run at the baseline (exit 1, no matches):

```sh
rg -n 'NormalizedContextEvent|events\.jsonl|transcript_path|UserPromptSubmit|PreCompact|SessionStart|last_assistant_message' plugins mcp/sdd-forge-mcp
```

Official runtime references for subsequent contract verification:

- Claude: <https://code.claude.com/docs/en/hooks>
- Codex: <https://learn.chatgpt.com/docs/hooks>

Installed CLI version observations were Codex `0.155.0-alpha.16.4` and Claude
`2.1.278`. Re-observe versions and actual event payloads before accepting support;
app-server protocol schemas are not command-hook input schemas.

### Codex contract audit (2026-09-26)

The [official hook reference](https://learn.chatgpt.com/docs/hooks) documents:

| Event | Identity / payload | Control relevant to continuity |
|-------|--------------------|--------------------------------|
| UserPromptSubmit | `session_id`, `turn_id`, prompt | `decision: block` or exit 2 rejects input |
| Stop | Turn-scoped; final assistant output | Blocking requests more model work; it is not a write-failure stop |
| PreCompact | Turn-scoped; manual/auto trigger | `continue: false` prevents compaction; never use for automatic compaction |
| SessionStart | Session-scoped; compact source | Context can be injected before resumed work; do not require a turn ID |

Transcript paths may be null and their file format is not stable. The documented
contract supplies no event-unique retry identifier. A turn ID alone therefore
does not prove two deliveries are the same event; content equality is insufficient.
Local `features list` reported `hooks: stable, true` and `plugin_hooks: removed,
false`. These flags are not proof of candidate registration or event delivery.
Actual payloads, retry behavior and failure barriers remain unverified.

## Open Questions

| ID | Question | Owner / resolution | Blocking |
|----|----------|--------------------|----------|
| OQ-001 | Retain until explicit deletion or impose a retention period? | Product owner; interview response | yes |
| OQ-002 | Which secrets must be removed before persistence, and what recovery loss is acceptable? | Product/security owner; interview response and concrete examples | yes |
| OQ-003 | If durable append fails, stop incoming prompt processing or continue with a warning? Automatic compaction must not be blocked. | Product owner; interview response plus runtime feasibility | yes |
| OQ-004 | Local-only, Git-excluded, worktree-separated storage. | Issue #137 already requires project-local, Git-excluded state; worktree identity/isolation is an implementation decision to verify, not a new permission request. | no |
| OQ-005 | How are retries identified when the host supplies no stable turn ID? Identical legitimate messages must remain distinct. | Implementer; inspect actual host events, then design | yes |
| OQ-006 | Which durability and atomic-replacement guarantees are portable across supported OSes? | Implementer; filesystem/API contract and fault-injection checks | yes |
| OQ-007 | What ordering and recovery are possible when transcript paths are missing or contain a partial tail? | Implementer; actual payload probes and bounded recovery design | yes |
| OQ-008 | Which installed host versions support each required event and failure barrier? | Implementer; isolated candidate registration and real tool history | yes |
| OQ-009 | How should missing ignore entries and already-tracked journal paths fail safely? | Implementer/security review; no deletion or silent Git index changes | yes |

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Conversation or secret data enters Git/review uploads | medium | high | Local-only boundary, explicit redaction policy, tracked-path rejection |
| Acknowledging input before durable storage loses context | medium | high | Commit ordering and simulated write failures |
| Repeated text is confused with a retried event | medium | high | Stable event identity; never deduplicate by content alone |
| Stale projection changes the perceived task status | medium | high | Reconcile against current authoritative files before display |
| Documentation is mistaken for live host support | medium | high | Versioned adapter probes and actual registered-entry-point evidence |

## Recommended Next Steps

1. Resolve product-policy questions without assuming answers.
2. Specify the smallest journal and recovery contract, reusing authoritative readers.
   Preferred reuse candidate: a small read-only entry point bundling existing core
   readers and root/path validation, without importing MCP startup. Existing
   esbuild can produce this artifact; no additional dependency or parser copy is
   needed. Installer placement and error-preserving reads still need design and
   tests. Calling the existing MCP server is an alternative, but adds a transport
   process to hook execution. This is a recommendation, not an implemented API.
3. Map all issue AC/scenario branches to concrete assertions before review.
4. Implement only after the required reviews and task approval; retain negative tests.
