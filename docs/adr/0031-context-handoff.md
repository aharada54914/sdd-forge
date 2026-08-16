# ADR 0031: Context Handoff

Status: Proposed

Date: 2026-08-15

Numbering note: this ADR was re-verified with `ls docs/adr/` before
drafting. The original handoff reference in `specs/sdd-context/security-spec.md`
used 0030, but 0030 is occupied on `origin/main` by the Component Path
Ownership Resolver Semantics decision, so the next free slot is 0031.

## Context

Issue #137 adds `sdd-context`, a compaction-safe Context Safety Layer for
Claude Code and Codex. A compaction hook must (a) generate a deterministic
pre-compaction snapshot, (b) inject a minimal recovery context on SessionStart,
and (c) never block the host compaction path. The same source tree needs to be
discoverable by multiple agent runtimes with different plugin manifest and hook
formats.

## Decision

`plugins/sdd-context` uses one deterministic Node core, thin POSIX/PowerShell
wrappers, and triple manifest discovery.

- **Single deterministic Node core.** All snapshot generation, boundary
  classification, and recovery-text selection live in
  `plugins/sdd-context/scripts/*.mjs`. AC-002 requires byte-identical output
  for unchanged input; one implementation removes cross-runtime divergence.
  The core uses only Node 18+ built-ins and adds no third-party runtime
  dependency.
- **Thin POSIX/PowerShell wrappers.** `hooks/hooks.json` delegates through a
  POSIX `sh` wrapper; `hooks/hooks.ps1` provides the PowerShell fallback for
  Windows and WSL invocation paths. Both wrappers only detect `node`, normalize
  argv, and delegate to the same Node core. Detector and writer logic are not
  duplicated in two languages.
- **Triple manifest discovery.** `.claude-plugin/marketplace.json`,
  `.codex-plugin/plugin.json`, and `.plugin/plugin.json` publish one source
  tree to Claude Code, Codex, and Copilot respectively. Copilot is
  discovery-only for now.

The manifest target is `./plugins/sdd-context` at version `1.14.0`.

## Consequences

- No SDD state-machine code is modified; the plugin is additive and callable
  only through the hook descriptors.
- A missing Node runtime, unwritable `.sdd/context/` directory, or corrupt
  handoff file degrades to a warning and exit 0 during compaction.
- Behavior is centralized in one Node core, reducing drift but adding Node 18+
  as an implementation-runtime assumption.
- The wrappers are intentionally minimal; any logic added in the future must
  remain in the Node core unless a new ADR justifies otherwise.
