# Requirements: sdd-context

Spec-Review-Status: Passed
Source Issues: https://github.com/aharada54914/sdd-forge/issues/137
Epic: N/A (new standalone plugin)

## Overview

Long-running SDD sessions lose working context when the host agent compacts
its conversation history. The ship workflow already records durable state on
disk (`tasks.md` Status fields, `reports/quality-gate/`, review tickets), but
the records are task-oriented and are not available to a fresh session at the
moment compaction happens. This feature adds a new Context Safety Layer
plugin, `sdd-context`, that survives compaction by generating a deterministic,
machine-readable snapshot before compaction and injecting a minimal recovery
context on SessionStart. The layer never uses an LLM to summarize, never
blocks compaction, and never mutates SDD source/state files.

## Target Users

- Agents running `/sdd-ship:ship` and other long multi-task SDD sessions that
  may be compacted by the host.
- Humans resuming a compacted session and needing a deterministic record of
  what was in flight.
- Maintainers installing the plugin across Claude Code, Codex, and Copilot
  environments.

## Problems

1. Host-side compaction destroys in-context working state (open files, partial
   verification state, the precise task boundary) at a time chosen by the
   host, not by the SDD workflow.
2. Existing disk state is durable but not assembled into a single compaction
   artifact. A resumed session must re-discover task state from several files
   and cannot distinguish a SAFE compaction boundary from an UNSAFE one.
3. Cross-agent support differs: Claude Code exposes node exec hooks, Codex
   hooks may be invoked through shell, and Copilot support is placeholder
   only. A single hook implementation cannot be reused without a
   runtime-adapting wrapper layer.
4. A compaction hook must not introduce a new failure mode by blocking or
   throwing during the host's compaction path.

## Goals

- REQ-001: The plugin ships a triple manifest
  (`.claude-plugin/marketplace.json`, `.codex-plugin/plugin.json`,
  `.plugin/plugin.json`) and a documented install surface so the same source
  tree can be discovered by Claude Code, Codex, and Copilot (placeholder),
  with Node scripts under `scripts/*.mjs` and hook descriptors under
  `hooks/`.
- REQ-002: A `PreCompact` hook deterministically writes
  `.sdd/context/HANDOFF.md` and `.sdd/context/handoff.json` from the
  repository state present at compaction time. Output is reproducible for the
  same input and contains no model-generated summarization.
- REQ-003: A boundary detector classifies the compaction event as exactly one
  of `SAFE`, `UNSAFE`, or `EMERGENCY_AUTO` using only deterministic signals:
  task lifecycle status, presence of an implementation report, and
  uncommitted/projected file changes.
- REQ-004: A `SessionStart` hook with `source=compact` emits a minimal
  recovery context to stdout from the latest `.sdd/context/handoff.json`, and
  exits without output when no handoff exists.
- REQ-005: A `PostCompact` hook optionally appends one record to
  `.sdd/context/compact-log.jsonl`. It must not read, consume, or require the
  host's `compact_summary` input.
- REQ-006: All hook entry points degrade to a graceful no-op when `node` is
  unavailable, and never exit nonzero during the host compaction path.
- REQ-007: The plugin is read-only with respect to SDD source/state. It writes
  only under `.sdd/context/` and `reports/context/`, performs no network
  access, reads no secrets, and never writes to protected workflow paths.
- REQ-008: Documentation explains install, hook trust procedures (including
  Codex hook trust), storage layout, and the SAFE/UNSAFE/EMERGENCY_AUTO
  contract.

## Non-goals

- No LLM-based summarization of conversation history. The snapshot is
  deterministic and file-based only.
- No change to the SDD state machine, task validator rules, or the ship
  workflow's existing task-boundary compaction guidance.
- No blocking of host compaction under any condition.
- No integration with the host's private conversation payload beyond the
  documented hook input fields.
- No retroactive reconstruction of past compactions.

## User Stories

- As a ship-session agent, when the host triggers PreCompact I get a
  deterministic HANDOFF.md that lets me resume from the exact on-disk state
  without re-deriving it from scratch.
- As an agent resuming after compaction, SessionStart prints only the minimal
  context needed to continue from the first eligible task.
- As a maintainer, I can install the same plugin source in Claude Code and
  Codex and verify the hook executes without `node` by observing a clean
  no-op.

## Acceptance Criteria

- AC-001 (REQ-001): The triple manifests validate against their respective
  JSON schemas/linters and reference `./plugins/sdd-context` with version
  `1.14.0`.
- AC-002 (REQ-002): Two consecutive PreCompact invocations on an unchanged
  repository produce byte-identical `HANDOFF.md` and `handoff.json`.
- AC-003 (REQ-002): `handoff.json` includes deterministic fields for
  boundary, feature/task status, implementation-report presence, file-change
  indicator, timestamp source, and artifact paths; `HANDOFF.md` is rendered
  from that JSON.
- AC-004 (REQ-003): The detector reports `SAFE` exactly when none of the
  AC-005 UNSAFE conditions hold and at least one of these holds: (a) every
  task in `specs/<feature>/tasks.md` is `Status: Done`; (b) every task in that
  file is in a BLOCKED stop state; (c) bootstrap outputs are saved; or
  (d) every targeted task is Implementation Complete before a quality gate.
- AC-005 (REQ-003): The detector reports `UNSAFE` when at least one of these
  deterministic conditions holds: (a) a specification interview is running;
  (b) a task in `specs/<feature>/tasks.md` has `Status: In Progress`; (c) a
  quality gate is running; (d) the current task's implementation report is
  missing; or (e) uncommitted/projected file changes exist.
- AC-006 (REQ-003): The detector reports `EMERGENCY_AUTO` exactly when
  `auto_compaction` is `true` and the same signals would otherwise classify
  the event as `UNSAFE` under AC-005. When `auto_compaction` is absent or
  `false`, the normal `SAFE`/`UNSAFE` classification applies. Classification
  precedence is `EMERGENCY_AUTO` > `UNSAFE` > `SAFE`.
- AC-007 (REQ-004): SessionStart with `source=compact` prints the latest
  handoff path and the first eligible task when a handoff exists. The first
  eligible task is the first task in `specs/<feature>/tasks.md` document
  order whose `Approval` is `Approved` and whose `Status` is `Planned` or
  `In Progress`.
- AC-008 (REQ-004): SessionStart exits 0 and prints nothing when no handoff
  exists.
- AC-009 (REQ-005): PostCompact appends exactly one valid JSON line per
  invocation and does not fail when `compact_summary` is absent or empty.
- AC-010 (REQ-006): When `node` is not on PATH, every hook exits 0 and emits
  at most a warning; the host compaction path is not blocked.
- AC-011 (REQ-007): A security scan of the hook execution path confirms no
  network calls, no secret reads, and no writes outside `.sdd/context/` and
  `reports/context/`.
- AC-012 (REQ-008): Documentation includes Codex hook trust instructions and
  the storage/status contract.
- AC-013 (REQ-002/REQ-006): When `.sdd/context/` is absent or read-only,
  PreCompact exits 0 and emits at most a warning; the host compaction path is
  never blocked.
- AC-014 (REQ-004): When `.sdd/context/handoff.json` is corrupt or partially
  written, SessionStart exits 0 and emits no recovery context (or at most a
  warning); it never exits nonzero.
- AC-015 (REQ-003): When `auto_compaction` is `true` but every AC-005 UNSAFE
  condition is absent, the detector still reports `SAFE`, not
  `EMERGENCY_AUTO`.
- AC-016 (REQ-004): The `first eligible task` selection rule used by AC-007
  is deterministic: document order in `specs/<feature>/tasks.md`, `Approval:
  Approved`, and `Status` equal to `Planned` or `In Progress`.

## Field Definitions

- `boundary` — one of `SAFE`, `UNSAFE`, or `EMERGENCY_AUTO`, derived
  deterministically.
- `source` — the hook input that triggered SessionStart; this feature handles
  the `compact` value.
- `compact_summary` — host-provided input that this plugin deliberately does
  not consume.
- `auto_compaction` — optional boolean PreCompact input. The value `true`
  indicates host-initiated automatic compaction and, only when the
  AC-005 UNSAFE signals are present, upgrades the boundary to
  `EMERGENCY_AUTO`. Absent or `false` means manual compaction and leaves the
  boundary as the normal `SAFE`/`UNSAFE` classification.

## Roles and Permissions

- Agents may write only `.sdd/context/` and `reports/context/` during hook
  execution; no other paths.
- Humans are responsible for trusting hooks in their agent runtime (the
  documented trust procedure).

## Main Workflows

1. Host fires PreCompact.
2. Wrapper locates `node`; if absent, exits 0 with a warning.
3. Detector classifies `EMERGENCY_AUTO` > `UNSAFE` > `SAFE` using the
   AC-004/AC-005/AC-006 signals, including the optional `auto_compaction`
   boolean.
4. Snapshot writer generates HANDOFF.md and handoff.json.
5. SessionStart reads handoff.json and prints minimal recovery context.
6. PostCompact appends one compact-log record.

## Edge Cases

- No handoff file exists on SessionStart.
- `node` is missing or unexecutable.
- `.sdd/context/` is absent or read-only; the hook must not fail the
  compaction path.
- `handoff.json` is corrupt or partially written; SessionStart must fail soft.
- Auto-compaction arrives during an UNSAFE state.
- Auto-compaction arrives during a SAFE state; the boundary remains `SAFE`.

## Security Boundaries

- The plugin is read-only toward SDD artifacts and never modifies
  `tasks.md`, review tickets, or protected gate scripts.
- No network, no secret access, no LLM summarization.
- Deterministic output only, so an agent cannot inject privileged actions
  through the compaction path.

## Assumptions

- Hook runtimes provide the documented input fields (`source`, optional
  `compact_summary`).
- Node 18+ is the implementation runtime, but its absence is handled.
- `.sdd/context/` is git-ignored; `reports/context/` is committable.

## Open Questions

None. Boundary semantics are defined in REQ-003 and the ADR.

## Risks

- A hook failure blocking compaction would be worse than losing context.
  Mitigation: REQ-006 requires graceful no-op and AC-010 proves it.
- Non-deterministic snapshots would make compaction state unreproducible.
  Mitigation: AC-002 requires byte-identical output for identical input.
- Over-permissive writes could corrupt SDD state. Mitigation: REQ-007
  restricts write paths and AC-011 scans the execution path.
