# T-005 — `mcp/sdd-forge-mcp/src/server.ts` tool registry enumeration (AC-014, TEST-014)

## Method

```
$ grep -n "server.registerTool(" mcp/sdd-forge-mcp/src/server.ts
64:  server.registerTool(
76:  server.registerTool(
88:  server.registerTool(
100:  server.registerTool(
110:  server.registerTool(
120:  server.registerTool(
129:  server.registerTool(
140:  server.registerTool(
153:  server.registerTool(
166:  server.registerTool(
179:  server.registerTool(
193:  server.registerTool(
205:  server.registerTool(
218:  server.registerTool(
$ grep -c "server.registerTool(" mcp/sdd-forge-mcp/src/server.ts
14
$ grep -rn "registerTool(" mcp --include="*.ts" | grep -v "\.test\.ts" | grep -v "/dist/" | grep "sdd-forge-mcp"
(all 14 lines above; none outside src/server.ts)
```

Fourteen `server.registerTool(` call sites, all inside this one file — none
elsewhere under `mcp/sdd-forge-mcp/src/`. This matches `investigation.md`
INV-006's independently-recorded count ("fourteen `sdd-forge-mcp` tools, all
read-only") and `acceptance-tests.md:62`'s cited range
(`mcp/sdd-forge-mcp/src/server.ts:65-219`, the tool-name-string lines from
the first tool's name at `:65` to the last tool's name at `:219`).

Each tool's handler is a thin wrapper (`toCallToolResult(...)`) around a pure
function imported from `./tools/core.js` (8 tools) or `./tools/evidence.js`
(6 tools). Supplementary fs/child_process import sweep (diligence beyond the
registry declarations themselves, since a `description` string is prose and
this feature's own `acceptance-tests.md:118` warns against trusting prose):

```
$ grep -rln 'from "fs"\|from "node:fs"\|require("fs")' mcp/sdd-forge-mcp/src --include="*.ts" | grep -v "\.test\.ts"
mcp/sdd-forge-mcp/src/root.ts
mcp/sdd-forge-mcp/src/path-guard.ts

$ grep -n 'from "node:fs"' mcp/sdd-forge-mcp/src/path-guard.ts
24:import { readdirSync, readFileSync, realpathSync, statSync } from "node:fs";

$ grep -n 'from "node:fs"' mcp/sdd-forge-mcp/src/root.ts
12:import { realpathSync, existsSync, statSync } from "node:fs";

$ grep -rniE "writeFile|appendFile|unlink|rmSync|mkdirSync|execSync|spawnSync|fs\.rm\b" mcp/sdd-forge-mcp/src --include="*.ts" | grep -v "\.test\.ts"
(no output)

$ grep -rn 'from "child_process"\|from "node:child_process"' mcp/sdd-forge-mcp/src --include="*.ts"
(no output)
```

The only two files anywhere under `mcp/sdd-forge-mcp/src/` that touch the
filesystem (`root.ts`, `path-guard.ts`) import exclusively read-only Node
`fs` primitives (`readFileSync`, `readdirSync`, `realpathSync`, `statSync`,
`existsSync`) — no `writeFile`/`appendFile`/`unlink`/`rmSync`/`mkdirSync`
anywhere in the tree, and no `child_process` import at all, so no tool can
spawn a process either. This corroborates the per-tool judgment below at the
implementation-behavior level, not just the registry-declaration level.

## Registered tools (14 of 14)

| # | Tool name | `registerTool(` line | Backing function (file:line) | Read-only judgment |
|---|---|---|---|---|
| 1 | `list_active_specs` | `server.ts:64` | `listActiveSpecs` (`tools/core.ts`, imported `server.ts:30`) | Lists feature dirs under `AGENTS.md`'s Active Spec Directories with an Approval/Status flag. No input at all (`server.ts:73`: zero-arg handler) — cannot target any specific file for mutation. Read-only. |
| 2 | `get_spec_status` | `server.ts:76` | `getSpecStatus` (`tools/core.ts`) | Reports which Phase 1/2 artifacts exist and their review-status header. Query only. Read-only. |
| 3 | `get_task_state` | `server.ts:88` | `getTaskState` (`tools/core.ts`) | "Shell-equivalent to `check-task-state.sh`" (`server.ts:93`) — `check-task-state.sh` is itself a read-only verdict script; this tool parses `tasks.md`'s state machine and returns pass/fail, no write. Read-only. |
| 4 | `list_approved_tasks` | `server.ts:100` | `listApprovedTasks` (`tools/core.ts`) | Lists tasks with an Approved-shaped Approval field. Query only. Read-only. |
| 5 | `list_blocked_tasks` | `server.ts:110` | `listBlockedTasks` (`tools/core.ts`) | Lists tasks whose Status is Blocked. Query only. Read-only. |
| 6 | `list_review_tickets` | `server.ts:120` | `listReviewTicketsTool` (`tools/core.ts`) | Lists parsed `docs/review-tickets/RT-*.yml` entries. Zero-arg, query only. Read-only. |
| 7 | `get_quality_gate_summary` | `server.ts:129` | `getQualityGateSummary` (`tools/core.ts`) | Lists `reports/quality-gate/*.md` reports with a VERDICT line and finding counts. Zero-arg, query only. Read-only. |
| 8 | `get_next_sdd_command` | `server.ts:140` | `getNextSddCommand` (`tools/core.ts`, wraps `computeNextSddCommand` from `next-command.ts`) | "Determines the next SDD workflow command … by walking `AGENTS.md`'s Required Workflow gates" (`server.ts:145-147`) — this is the probe tool T-001/T-002 name explicitly; it computes and reports a recommendation, it does not itself flip any `Approval`/`Status` field. Read-only / advisory, matching REQ-005's guarantee that the probe never decides. |
| 9 | `evidence_get_bundle` | `server.ts:153` | `evidenceGetBundle` (`tools/evidence.ts`, imported `server.ts:39`) | "Reads and echoes … as-is (including its signature field); never verifies the signature or reads any signing key" (`server.ts:158-160`). Pure echo-read. Read-only. |
| 10 | `evidence_validate_paths` | `server.ts:166` | `evidenceValidatePaths` (`tools/evidence.ts`) | Reports whether each artifact path is within the path-guard allowlist and whether it currently exists — a `statSync`-shaped check, no content mutation. Read-only. |
| 11 | `evidence_find_missing` | `server.ts:179` | `evidenceFindMissing` (`tools/evidence.ts`) | Reports which Done-transition evidence requirements are present vs. missing, "shell-equivalent to `check-task-state.sh`'s Done evidence checks" (`server.ts:186-187`). Read-only. |
| 12 | `evidence_summarize_contract_checks` | `server.ts:193` | `evidenceSummarizeContractChecks` (`tools/evidence.ts`) | Reads `<taskId>.contract.json` and summarizes fields. Read-only. |
| 13 | `evidence_compare_to_traceability` | `server.ts:205` | `evidenceCompareToTraceability` (`tools/evidence.ts`) | Cross-checks `traceability.md` against `tasks.md` ids and each task's verification contract; a read-side diff report, not a write. Read-only. |
| 14 | `evidence_deep_verify` | `server.ts:218` | `evidenceDeepVerify` (`tools/evidence.ts`) | "Reads … and recomputes every artifact's sha256 from disk … reducing them to a deterministic pass/fail verdict with a failures list. Never reads a signing key, never verifies a signature (echoed with `verified:false`), and never spawns git" (`server.ts:223-228`). Explicitly documents its own non-mutation and non-spawn boundary in the registered `description` itself. Read-only. |

## Conclusion (AC-014)

All 14 registered tools in `mcp/sdd-forge-mcp/src/server.ts` are `get_*` /
`list_*` / `evidence_get_*` / `evidence_validate_*` / `evidence_find_*` /
`evidence_summarize_*` / `evidence_compare_*` / `evidence_deep_verify` query
operations. None registers a create/update/delete/write/approve/advance
verb. The supplementary fs/child_process import sweep confirms no
implementation path anywhere in this server's `src/` tree can write a file
or spawn a process, independent of what each tool's `description` string
claims. **PASS — no write, mutate, or advance tool is registered.**
