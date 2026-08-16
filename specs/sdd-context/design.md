# Design: sdd-context

Impl-Review-Status: Passed

## Architecture

A new standalone plugin, `sdd-context`, implemented as a runtime-adaptive
wrapper around a single deterministic Node core. No SDD state-machine code is
modified. The plugin is installed alongside the existing sdd-forge plugins and
does not belong to `sdd-ship`.

```
hooks/claude-hooks.json ─▶ node scripts/hook-wrapper.mjs ─▶ Node core
hooks/hooks.json       ─▶ sh wrapper                    ─▶ scripts/hook-wrapper.mjs
                          └─ hooks/hooks.ps1 (PowerShell fallback)
                                                          ├─ detect-node
                                                          ├─ boundary detector
                                                          ├─ snapshot writer
                                                          └─ session-start injector
```

The boundary between the host runtime and the plugin is the hook descriptor.
Descriptors only launch the wrapper with normalized argv; all decisions,
snapshot generation, and recovery-text selection live in the Node core so the
three runtimes cannot drift apart.

### Storage Layout

- `.sdd/context/HANDOFF.md` — human-readable deterministic handoff.
- `.sdd/context/handoff.json` — machine-readable deterministic snapshot.
- `.sdd/context/compact-log.jsonl` — append-only optional PostCompact record.
- `reports/context/<feature>/<timestamp>-handoff.md` — committable report.

## Components

- `.claude-plugin/marketplace.json`, `.codex-plugin/plugin.json`,
  `.plugin/plugin.json` — triple manifest discovery.
- `hooks/claude-hooks.json` — Claude Code node exec hook descriptor.
- `hooks/hooks.json` — Codex POSIX `sh` hook descriptor.
- `hooks/hooks.ps1` — Codex PowerShell hook wrapper fallback for Windows and
  WSL PowerShell invocation paths.
- `plugins/sdd-context/scripts/*.mjs` — deterministic Node core: `detect-node`,
  `boundary detector`, `snapshot writer`, `session-start injector`.
- `plugins/sdd-context/docs/` — install and Codex trust documentation.

## API / Contract Plan

Hooks expose a minimal, version-free JSON contract. The plugin introduces no
new HTTP endpoints and no SDK surface. No existing SDD endpoint, hook,
validator rule, or state-machine artifact is deprecated, renamed, or given a
breaking change; `sdd-context` is additive and callable only through the hook
descriptors listed here.

### PreCompact

- Trigger: host fires the PreCompact hook event.
- Input object:
  - `source` (string, required) — the hook input source; normally `compact`.
  - `auto_compaction` (boolean, optional) — `true` means host-initiated
    automatic compaction; absent or `false` means manual compaction.
- Output object (stable JSON on stdout):
  - `boundary` (string) — exactly one of `SAFE`, `UNSAFE`, or
    `EMERGENCY_AUTO`.
  - `artifact_path` (string|null) — path to the written `handoff.json`, or
    `null` when the write was skipped for a degraded condition.
  - `warnings` (string[]) — human-readable warnings; empty when no warning.
- Side effects: deterministically writes `.sdd/context/HANDOFF.md` and
  `.sdd/context/handoff.json` when the directory is writable.
- Exit code: always `0`; a missing runtime, unwritable directory, or internal
  failure downgrades to a warning and never blocks compaction.

### SessionStart

- Trigger: host fires the SessionStart hook event.
- Input object:
  - `source` (string, required) — must equal `compact` for this feature.
- Output (stdout): when a valid `.sdd/context/handoff.json` exists, prints the
  latest handoff path and the first eligible task using the AC-016 rule;
  otherwise prints nothing.
- Output object:
  - `injected` (boolean) — `true` when recovery context was printed, `false`
    otherwise.
- Exit code: always `0`.

### PostCompact

- Trigger: host fires the PostCompact hook event.
- Input object:
  - `source` (string, required) — normally `compact`.
  - `compact_summary` (string, optional) — deliberately not read, consumed,
    required, or persisted (REQ-005).
- Output object:
  - `recorded` (boolean) — `true` when one record was appended, `false` on a
    degraded condition.
- Side effects: appends exactly one JSON line to
  `.sdd/context/compact-log.jsonl` when writable.
- Exit code: always `0`.

Unknown input fields are ignored. All untrusted values are passed as argv or
JSON string values; the wrappers never interpolate them into a shell command.

## Decision Justification

The implementation choices below are recorded in
`docs/adr/0031-context-handoff.md`.

- Single deterministic Node core: the snapshot writer and boundary detector
  must satisfy AC-002 byte-identical output and cross-runtime consistency. One
  implementation removes divergence risk and uses only Node 18+ built-ins,
  adding no third-party runtime dependency.
- POSIX `sh` plus PowerShell wrappers: Codex hooks can be shell-invoked and
  Windows/WSL can reach hooks through PowerShell. The wrappers only perform
  `node` detection and argv normalization, then delegate all logic to the same
  Node core; this keeps behavior identical without duplicating detector or
  writer logic in two languages.
- Triple manifest discovery: Claude Code, Codex, and Copilot use different
  plugin discovery formats, so one source tree is published through
  `.claude-plugin/marketplace.json`, `.codex-plugin/plugin.json`, and
  `.plugin/plugin.json`. Copilot is discovery-only for now.

## Test Strategy

1. Unit-test the deterministic snapshot writer with fixed fixtures.
2. Unit-test the boundary detector across SAFE/UNSAFE/EMERGENCY_AUTO cases.
3. Integration-test the wrappers with node present and node removed.
4. Cross-runtime tests: bash and PowerShell wrappers produce identical core
   behavior.
5. Security scan: no network, no secret reads, no writes outside the allowed
   paths.

## Security Boundaries

The plugin is read-only toward SDD artifacts. Writes are confined to
`.sdd/context/` and `reports/context/`. No network, no secrets, no LLM. The
hook wrapper catches all errors and exits 0 during compaction.

## External Integrations

- Claude Code:
  - Descriptor: `hooks/claude-hooks.json`.
  - Format: Claude Code hook descriptor; the `PreCompact`, `SessionStart`,
    and `PostCompact` events launch `node scripts/hook-wrapper.mjs`.
  - Failure behavior: missing `node` or a descriptor error produces a warning
    and exit 0, so compaction is not blocked.
- Codex:
  - Descriptor: `hooks/hooks.json`.
  - Format: Codex `sh` hook descriptor. On Windows/WSL PowerShell invocation
    the same descriptor delegates to `hooks/hooks.ps1`, which performs the
    same `node` detection and delegates to the Node core.
  - Failure behavior: missing `node` produces at most a warning and exit 0.
- Copilot:
  - Descriptor: `.plugin/plugin.json` placeholder only; current Copilot CLI
    support is discovery-only and does not execute the hook events.
- Runtime/hook interface unavailable:
  - If the host does not invoke a hook (for example because the operator has
    not trusted the descriptor), nothing is written and the host compaction
    path proceeds normally. The Node core can still be invoked manually for
    deterministic snapshot generation.

## Deployment / CI Plan

- Target environments: Claude Code (macOS/Linux, node exec), Codex CLI
  (macOS/Linux/WSL with POSIX sh or PowerShell), and Copilot CLI
  (discovery-only placeholder). Node 18+ is the implementation runtime.
- Feature-flag policy: no runtime feature flag. Activation is the operator's
  explicit hook trust/install step; an untrusted or uninstalled hook is a
  no-op by absence and cannot affect the SDD workflow.
- CI changes:
  - Add `tests/sdd-context/*.Tests.ps1` to the repository's existing Pester
    test job in `.github/workflows/test.yml`; no new CI infrastructure.
  - Run `validate-repository.ps1` against the triple manifests, the ADR index,
    the `.gitignore` entry, and the `sdd-ship` documentation cross-reference.
- Execution order for the change:
  1. Add `.sdd/context/` to `.gitignore`.
  2. Register `sdd-context` in `.claude-plugin/marketplace.json` and
     `.agents/plugins/marketplace.json`.
  3. Add hook descriptors and `plugins/sdd-context/scripts/*.mjs`.
  4. Add `plugins/sdd-context/docs/` install and trust documentation.
  5. Add `docs/adr/0031-context-handoff.md` and index it.
  6. Add the cross-reference from `plugins/sdd-ship/skills/ship/SKILL.md`.
- Data migration: none. Persistence is local files only; there is no database,
  no schema version, and no rolling-deploy or rollback ordering requirement.

## Cross-Layer Dependencies

- `specs/sdd-context/tasks.md` consumes this design.
- `sdd-ship` documentation references this plugin for context compaction.
- No runtime dependency on other SDD plugins.

## Design Assumptions and Accepted Risks

These assumptions come from `requirements.md` and are grounded in
`investigation.md`.

- Hook runtimes provide the documented input fields (`source`, optional
  `compact_summary`, optional `auto_compaction`). Basis: INV-001. Mitigation:
  unknown fields are ignored and a missing required field produces a warning
  plus exit 0. Accepted risk: if a runtime omits `source`, recovery injection
  is skipped but compaction is never blocked.
- Node 18+ is the implementation runtime. Basis: INV-002. Mitigation: REQ-006
  and AC-010 require a graceful no-op when `node` is absent. Accepted risk:
  without `node`, a snapshot is not generated for that compaction event.
- `.sdd/context/` is git-ignored and `reports/context/` is committable.
  Basis: INV-003. Mitigation: REQ-007 restricts all writes to those two paths
  regardless of gitignore state. Accepted risk: an operator who misconfigures
  gitignore may see local context files in `git status`, but no protected SDD
  path is written.

## Acceptance Criteria Traceability

- AC-001 — triple manifests validate and reference `./plugins/sdd-context` at version `1.14.0`.
- AC-002 — consecutive PreCompact invocations on unchanged input are byte-identical.
- AC-003 — handoff.json shape and HANDOFF.md rendering are deterministic and machine-renderable.
- AC-004 (a)(b)(c)(d) — detector reports `SAFE` for all required stop/complete bootstrap/quality-gate states.
- AC-005 (a)(b)(c)(d)(e) — detector reports `UNSAFE` for each required in-flight/dirty-state condition.
- AC-006 — `auto_compaction=true` plus UNSAFE signals yields `EMERGENCY_AUTO`; absent/false yields normal classification.
- AC-007 — SessionStart prints latest handoff path and first eligible task when handoff exists.
- AC-008 — SessionStart exits 0 with no output when no handoff exists.
- AC-009 — PostCompact appends exactly one valid JSON line and tolerates absent/empty compact_summary.
- AC-010 — node missing produces a graceful zero-exit no-op with at most a warning.
- AC-011 — security scan proves no network, no secret reads, and no writes outside allowed paths.
- AC-012 — documentation includes Codex hook trust and the storage/status contract.
- AC-013 — missing or read-only `.sdd/context/` degrades gracefully without blocking compaction.
- AC-014 — corrupt or partially written handoff.json makes SessionStart fail soft.
- AC-015 — `auto_compaction=true` with no UNSAFE condition still reports `SAFE`.
- AC-016 — first-eligible-task selection is deterministic document order + Approved + Planned/In Progress.
