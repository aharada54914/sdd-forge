# SDD Forge MCP v2 Architecture Specification

- **Status**: Normative Specification (**v2.1.0**) — Companion to [ADR-0052](../adr/0052-mcp-architecture-and-v2-consolidation.md)
- **JSON Schema Contract**: [`contracts/sdd-mcp.v2.schema.json`](../../contracts/sdd-mcp.v2.schema.json)
- **Runtime Requirement**: Node.js >= 20 LTS (zero runtime drift from `plugins/sdd-quality-loop/scripts/v2/v2-readonly-core.mjs`)

---

## 1. Design Principle: When to Use MCP vs. Direct v2 Scripts

| Execution Surface | Recommended Interface | Rationale |
|---|---|---|
| **Local CLI Agents** (Claude Code, Codex CLI, Copilot CLI, Antigravity CLI `agy`, legacy Gemini CLI) | **Direct v2 ESM CLIs** (`node scripts/v2/*.mjs`) + `gh` CLI; MCP registration **opt-in** (`--with-mcp`) | Agents already have native file/shell tools. Avoiding 3 always-on MCP registrations saves ~3,300 tokens/turn and 3 idle Node processes, and avoids non-interactive MCP approval friction. Note: `mcp/sdd-forge-mcp/dist/index.js` is still placed locally as a CLI runtime for `/sdd-ship:status` without registering any MCP server. |
| **Non-Shell / Read-Only Clients** (Claude Desktop, ChatGPT, Web IDE, Dashboard viewers, Read-only cross-repo auditors) | **Single `sdd-forge-mcp` v2** (4 coarse-grained read-only tools + 2 resources) | Provides strict `path-guard.ts`-enforced read-only access without exposing shell execution, delivering complete SDD decision state in 1 round-trip (~600 tokens schema overhead). |
| **Sandboxed CI-Only Auditors** (no `gh` CLI / no shell token access) | Optional `ci-mcp` (`--mcp ci-mcp` opt-in only) | Strictly scoped GET-only GitHub Actions proxy; never enabled by default on local dev machines. |
| **`local-env-mcp`** | **Deprecated (removal in v2.2.0)** | Fully superseded by `sdd-doctor.mjs` and native shell probes. |

---

## 2. Single Source of Truth (SSOT) & Pure Read-Only Boundary

`sdd-forge-mcp` v2 MUST NOT re-implement markdown, task-state, traceability, or spec-drift parsers in a parallel codebase, and MUST NOT import CLI write modules (`fs.writeFileSync`/`fs.mkdirSync`/`process.env` root escalation) into its bundled binary:

```mermaid
flowchart LR
    subgraph PURE["Pure Read-Only SSOT Core (0 fs / 0 env / 0 write APIs)"]
        PL["v2-pure-lib.mjs"]
        RC["v2-readonly-core.mjs"]
    end

    CLI["Local v2 CLIs\n(check-spec-drift / check-traceability /\nrender-decision-view / sdd-doctor)"] -->|createFsReadonlyIo(root)| RC
    MCP["sdd-forge-mcp v2\n(4 read-only tools + 2 resources)"] -->|createGuardedIo(root) via path-guard.ts| RC
    EXT["Non-Shell / Read-Only Clients\n(Desktop / Web / Dashboard / Antigravity)"] -->|stdio JSON-RPC| MCP
```

---

## 3. Tool Surface (4 Coarse-Grained Read-Only Tools)

All tools MUST:
- Declare MCP annotations: `{ "readOnlyHint": true, "destructiveHint": false, "idempotentHint": true }`.
- Enforce strict input validation (`additionalProperties: false`) and never accept a `root` or arbitrary filesystem path argument (repository root is frozen once at server startup via `--root` > `SDD_FORGE_ROOT` > `cwd`, ignoring `CLAUDE_PROJECT_DIR`/`SDD_PROJECT_ROOT`). Note: protocol-level Zod input-schema rejections (e.g., invalid `feature` regex such as `../etc`, or unknown keys) are rejected by the MCP SDK before tool execution and return `isError: true` with `MCP error -32602` text, whereas application-level errors inside tool handlers return the JSON `Result<T>` envelope `{ ok: false, error: { code, message, details? } }`.
- Return a uniform `Result<T>` envelope (`{ ok: true, data }` or `{ ok: false, error: { code, message, details? } }`) conforming to `contracts/sdd-mcp.v2.schema.json`.
- Route every filesystem read/stat/list through `path-guard.ts`:
  - **Allowlist**: `AGENTS.md`, `dashboard-labels.json`, `sdd/guardrails.{yaml,json}`, `.sdd/drift-events.jsonl`, `.sdd/factory-metrics.jsonl`, and directories `specs/`, `reports/`, `sdd/knowledge/`, `docs/review-tickets/`, `docs/workflow-improvements/`.
  - **Denylist**: `.env`, `.env.*`, `SDD_SUDO`, `~/.sdd/evidence-key` (even when reached via symlink).
  - **Size Cap**: 2 MiB per file; zero absolute host path leakage in error messages.

### Tool 1: `sdd_project_overview`
- **Replaces**: `list_active_specs`, `get_spec_status`, `get_quality_gate_summary`, `get_next_sdd_command` (no-arg).
- **Input**: `{ includeDoctor?: boolean }` (default `true`, `additionalProperties: false`).
- **Output (`kind: "project-overview"`)**:
  - `activeFeatures`: array of `{ feature, highestRisk, taskCounts: { total, approved, inProgress, implComplete, done, blocked }, driftStatus: "CLEAN" | "AMENDED" | "UNDECLARED_DRIFT" | "UNVERIFIABLE" | "UNBASELINED" | "BASELINE_ERROR", nextAction: { phase, command, rationale } }`.
    `UNVERIFIABLE`: a baselined spec file exists but is over the server's 2 MiB read limit, so drift was not checked; it is never reported as a deletion, and `nextAction` is `blocked` with the local `check-spec-drift.mjs` CLI as the next step (#834).
  - `doctor`: optional compact `sdd-doctor` summary (`status: "CLEAN" | "WARN" | "NG"`, `ngCount`, `warnCount`, `driftEventCount`).

### Tool 2: `sdd_feature_state`
- **Replaces**: `get_spec_status`, `get_task_state`, `list_approved_tasks`, `list_blocked_tasks`, `get_next_sdd_command(feature)`.
- **Input**: `{ feature: string, includeDecisionViewMarkdown?: boolean }` (`feature` matches `^[A-Za-z0-9._-]+$` excluding `.` and `..`, `additionalProperties: false`).
- **Output (`kind: "feature-state"`)**:
  - `feature`, `highestRisk`, `files` (`requirements`, `design`, `tasks`, `baseline` booleans).
  - `traceability`: `{ complete, requirementCount, acCount, taskCount, gapCount }` (returns zeroed summary with `nextAction.phase: "bootstrap"` when `requirements.md` or `tasks.md` is not yet created).
  - `drift`: `{ status, changedFiles, amendmentCount }`.
  - `openQuestions`: `{ total, provisionalCount, provisionalIds }`.
  - `nextAction`: deterministic v2 command (`/sdd-bootstrap:bootstrap`, human approval, `/sdd-ship:ship`, blocked remediation, or `feature complete` only when all tasks are `Approved` and `Done`).
  - `decisionViewMarkdown`: optional rendered Decision View (including source file:line citations and 8 common × product review perspective matrix).

### Tool 3: `sdd_gate_audit`
- **Replaces**: `evidence_get_bundle`, `evidence_validate_paths`, `evidence_find_missing`, `evidence_summarize_contract_checks`, `evidence_compare_to_traceability`, `evidence_deep_verify`, `list_review_tickets`.
- **Input**: `{ feature: string, taskId?: string }` (`taskId` matches `^T-[A-Za-z0-9._-]+$`, `additionalProperties: false`).
- **Output (`kind: "gate-audit"`)**:
  - `tasks`: per-task v2 gate audit record:
    - `taskId`, `risk`, `approval`, `status`
    - `executionArtifact`: `{ exists, path?, verdict?, executedAt?, specDriftStatus?, failedCommands? }` (from `reports/quality-gate/<feature>-<taskId>.execution.json`, verifying `feature` and `taskId` match)
    - `reviewReport`: `{ exists, path?, verdict? }` (from `reports/quality-gate/<feature>-<taskId>.md`, fail-closed on any explicit `FAIL` verdict line)
    - `readyForDone`: boolean — fail-closed, requiring `Approved`, `Implementation Complete` or `Done`, `executionArtifact.verdict === "PASS"`, `reviewReport.verdict === "PASS"`, `drift.status` in `["CLEAN", "AMENDED"]`, and zero unresolved `Provisional` `OQ-NNN` on `Risk: high`.

### Tool 4: `sdd_dashboard_snapshot`
- **Replaces**: `get_dashboard_snapshot`.
- **Input**: `{}` (`additionalProperties: false`).
- **Output (`kind: "dashboard-snapshot"`)**: Uniform `Result<T>` envelope `{ ok: true, data: { kind: "dashboard-snapshot", snapshot } }` where `snapshot` conforms to `contracts/sdd-dashboard.v1.schema.json`.

---

## 4. Resources (2 Read-Only Resources)

| URI | Backing Function |
|---|---|
| `sdd://overview` | `sdd_project_overview({ includeDoctor: true })` |
| `sdd://feature/{feature}` | `sdd_feature_state({ feature, includeDecisionViewMarkdown: true })` |

---

## 5. Context Budget Comparison

| Metric | v2.0.0 (3 servers) | v2.1.0 (`sdd-forge-mcp` v2 opt-in) | Reduction |
|---|---:|---:|---:|
| Default local CLI MCP registrations | 3 | **0** (opt-in `--with-mcp`: 1) | -100% default / -67% opt-in |
| Exposed tools | 23 | **4** | -82.6% |
| Schema payload (bytes) | 13,216 B | ~2,400 B | -81.8% |
| Est. prompt tokens / turn | ~3,304 tokens | **0** (default) / ~600 tokens (opt-in) | -100% / -81.8% |
| Duplicate parser codebases | 2 (v1 TS + v2 ESM) | **1** (`v2-readonly-core.mjs` SSOT) | Eliminates v1/v2 drift |

---

## 6. Release & Migration Policy

1. **v2.1.0 (Current Release)**:
   - Ships `sdd-forge-mcp` v2 (4 tools + 2 resources) backed by pure `v2-readonly-core.mjs` + `path-guard.ts`.
   - Switches `install.sh` / `install.ps1` MCP client registration to opt-in (`--with-mcp`), while still placing `mcp/sdd-forge-mcp/dist/index.js` locally for `/sdd-ship:status` and pruning dangling `local-env-mcp`/`ci-mcp` registrations on upgrade.
   - Adds native Antigravity CLI (`agy`) support (`--target Antigravity`, `~/.gemini/config/mcp_config.json`).
   - Deprecates `local-env-mcp` (warning on explicit opt-in) and moves `ci-mcp` to explicit `--mcp ci-mcp`.
2. **v2.2.0 (Scheduled Removal)**:
   - Remove deprecated `mcp/local-env-mcp/` and remaining internal legacy v1 parser files once `DashboardReader` fully migrates off `tools/core.ts`.
