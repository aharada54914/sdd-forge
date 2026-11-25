# Non-Interactive & Cloud Factory Execution Guide (F-8)

SDD Forge v2.1 supports lightweight, zero-daemon non-interactive execution across local CI runners, ephemeral cloud workspaces, and scheduled autonomous runs — without adding mandatory external task-tracker dependencies (behavior stays unchanged when unconfigured).

## 1. Non-Interactive CLI Execution Across Supported Hosts

Always set `SDD_SESSION_NONINTERACTIVE=1` so `SessionStart` model-selection prompts are suppressed cleanly:

| Host | Non-Interactive Command | Read-Only / Guardrail Notes |
|---|---|---|
| **Claude Code** | `SDD_SESSION_NONINTERACTIVE=1 claude -p "<prompt>" --output-format json` | Native `PreToolUse` soft guard (`sdd-soft-guard.mjs --emit exit`) active |
| **Codex CLI** | `SDD_SESSION_NONINTERACTIVE=1 codex exec "<prompt>"` | Native `PreToolUse` soft guard (`sdd-soft-guard.mjs --emit exit`) active |
| **Antigravity CLI (`agy`)** | `SDD_SESSION_NONINTERACTIVE=1 agy -p "<prompt>" --model gemini-4-neon-high --output-format json` | Native `PreToolUse` soft guard (`sdd-soft-guard.mjs --emit antigravity`) active via plugin root `hooks.json` |

> Legacy `gemini` CLI personal OAuth accounts are deprecated by Google in favor of Antigravity (`agy`). Prefer `agy` for Google Gemini 4 Neon / Argon / Hydrogen workflows.

## 2. Optional GitHub Issue Ingestion

When starting from a GitHub Issue, pass the Issue URL directly to `/sdd-bootstrap:bootstrap`:

```bash
# Fetch issue context in CI or local automation
gh issue view 123 --json title,body,labels > /tmp/issue-123.json
```

Then hand the issue context to `/sdd-bootstrap:bootstrap feature --feature issue-123 <summary>`.

## 3. Execution Control & Safe Parallelism

Before invoking autonomous implementation in CI or multi-worker pipelines:

```bash
# 1. Prevent duplicate concurrent runs (fail-closed atomic lock).
#    RUN_ID names this run (e.g. the CI run id). The lock is held by that owner
#    until --ttl seconds pass; acquiring again with the same owner renews it.
node <installed-root>/plugins/sdd-quality-loop/scripts/v2/task-lock.mjs acquire --feature <slug> --owner "$RUN_ID" --root .

# 2. Compute safe parallel execution waves and check Scope conflicts
node <installed-root>/plugins/sdd-quality-loop/scripts/v2/check-traceability.mjs --feature <slug> --plan-batches --format markdown

# 3. Release lock upon completion (always in trap/finally)
node <installed-root>/plugins/sdd-quality-loop/scripts/v2/task-lock.mjs release --feature <slug> --owner "$RUN_ID" --root .
```

Acquisition, renewal, and release coordinate through short-lived writer intents
in `.sdd/lock-mutations/`. Upgrade all workers sharing a workspace together.
A process that detects a dead peer on the same host removes its intent. If a
contention result repeatedly names the same `peerIntent`, stop all workers
sharing the workspace and remove that specific file before restarting them.
The task lock itself keeps its recorded owner and TTL.

## 4. Human-on-the-Loop Governance

- Automated runs MUST NEVER write `Approval: Approved` (blocked deterministically by `sdd-soft-guard.mjs`).
- Unconverged issues after `limits.max_auto_fix_rounds` (default `2`) are recorded as `OQ-NNN` (`Provisional`) and handed to humans via `render-decision-view.mjs --format html`.
- After merge/completion, extract confirmed decisions into `sdd/knowledge/` with `sync-knowledge.mjs extract --feature <slug>` and monitor factory health via `factory-metrics.mjs --format markdown`.
