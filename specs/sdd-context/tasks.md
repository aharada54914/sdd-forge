# Tasks: sdd-context

Task-Review-Status: Passed

## Lifecycle

`Draft -> Approved -> In Progress -> Implementation Complete -> Done`

A task may enter `Blocked` from any active state. Humans approve tasks.
`implement-task` may set `In Progress`, `Blocked`, or `Implementation Complete`.
Only `quality-gate` may set `Done`.

**`Blockers` is authoritative for execution order; document order is not.**
T-002 declares T-003 as a blocker because the snapshot writer consumes the
boundary value the classifier produces, so T-003 runs first despite appearing
later in this document. The numbering follows REQ-001..REQ-008; the dependency
graph follows the data flow.

## T-001 Triple manifest discovery and plugin skeleton

Source Issue: https://github.com/aharada54914/sdd-forge/issues/137

Approval: Draft

Status: Planned

Risk: medium

Risk Rationale: Adds three discovery manifests that agent runtimes parse at
startup; a malformed entry is observable behaviour across every host, but the
change touches no authentication, data mutation, or secret-handling surface.

Required Workflow: acceptance-first

Requirements: REQ-001

Planned Files: `.claude-plugin/marketplace.json`, `.codex-plugin/plugin.json`,
`.plugin/plugin.json`, `plugins/sdd-context/` (directory skeleton), `.gitignore`,
`tests/sdd-context/manifests.Tests.ps1`

Data Migration: None

Breaking API: None — additive registration only; no existing manifest entry is
renamed or removed.

### Goal
Make `sdd-context` discoverable from Claude Code, Codex, and Copilot through the
three manifest formats, and establish the plugin directory that later tasks fill
in.

### Must Read
- specs/sdd-context/requirements.md
- specs/sdd-context/design.md
- specs/sdd-context/acceptance-tests.md
- specs/sdd-context/traceability.md

### Scope
Register `./plugins/sdd-context` at version `1.14.0` in all three manifests per
design.md `## Components`. Create the plugin directory skeleton (`scripts/`,
`hooks/`, `docs/`) without implementing hook logic. Add `.sdd/context/` to
`.gitignore` per INV-003, keeping `reports/context/` committable. This is step 1
and step 2 of design.md's Deployment execution order, and is the blocker of
every other task in this decomposition.

### Done When
- [ ] Implementation complete
- [ ] Required tests added or updated
- [ ] Related regression tests pass
- [ ] Implementation report created
- [ ] Quality gate passes
- [ ] Implementation report cross-references REQ-001 and the TEST-001 evidence
      path under `specs/sdd-context/verification/`
- [ ] AC-001 verified by TEST-001: all three manifests validate against their
      schemas/linters and reference `./plugins/sdd-context` at version `1.14.0`
- [ ] `.sdd/context/` is git-ignored and `reports/context/` is not

### Out of Scope
Hook descriptors and any Node core logic (T-002 through T-006). Documentation
content (T-008).

### Blockers
None

## T-002 Deterministic snapshot writer

Source Issue: https://github.com/aharada54914/sdd-forge/issues/137

Approval: Draft

Status: Planned

Risk: medium

Risk Rationale: Writes the handoff artefacts that a resumed session trusts as
its record of in-flight state; a non-deterministic or partial write produces a
misleading recovery, but the write path is confined to `.sdd/context/` and
touches no SDD source or state file.

Required Workflow: acceptance-first

Requirements: REQ-002

Planned Files: `plugins/sdd-context/scripts/snapshot-writer.mjs`,
`tests/sdd-context/determinism.Tests.ps1`,
`tests/sdd-context/snapshot-shape.Tests.ps1`,
`tests/sdd-context/context-dir.Tests.ps1`

Data Migration: None — file-only persistence, no schema version.

Breaking API: None

### Goal
Produce `.sdd/context/handoff.json` and `.sdd/context/HANDOFF.md`
deterministically from repository state at compaction time, with no
model-generated text, and degrade gracefully when the directory is unavailable.

### Must Read
- specs/sdd-context/requirements.md
- specs/sdd-context/design.md
- specs/sdd-context/acceptance-tests.md
- specs/sdd-context/traceability.md

### Scope
Implement the snapshot writer named in design.md `## Components`. `handoff.json`
carries the deterministic fields listed in AC-003 (boundary, feature/task status,
implementation-report presence, file-change indicator, timestamp source, artifact
paths); `HANDOFF.md` is rendered from that JSON rather than assembled separately.
Two consecutive invocations on an unchanged repository must be byte-identical.
This task owns the availability handling for `.sdd/context/`: when the directory
is absent or read-only, exit 0 with at most a warning and write nothing. Consumes
the boundary value produced by T-003, which is why T-003 blocks this task.

### Done When
- [ ] Implementation complete
- [ ] Required tests added or updated
- [ ] Related regression tests pass
- [ ] Implementation report created
- [ ] Quality gate passes
- [ ] Implementation report cross-references REQ-002 and the TEST-002, TEST-003,
      TEST-022, TEST-023 evidence paths under `specs/sdd-context/verification/`
- [ ] AC-002 verified by TEST-002: two consecutive PreCompact invocations on an
      unchanged repository produce byte-identical output
- [ ] AC-003 verified by TEST-003: handoff.json field shape, HANDOFF.md rendered
      from it
- [ ] AC-013 verified by TEST-022 and TEST-023: absent and read-only
      `.sdd/context/` both exit 0 with at most a warning

### Out of Scope
Boundary classification (T-003). SessionStart output (T-004). The wrapper and
node detection that invoke this writer (T-006).

### Blockers
T-001, T-003

## T-003 Compaction boundary detector

Source Issue: https://github.com/aharada54914/sdd-forge/issues/137

Approval: Draft

Status: Planned

Risk: medium

Risk Rationale: Classifies whether a compaction boundary is safe; a wrong SAFE
verdict understates the risk of losing working state, but the detector never
blocks compaction and touches no sensitive surface.

Required Workflow: acceptance-first

Requirements: REQ-003

Planned Files: `plugins/sdd-context/scripts/boundary-detector.mjs`,
`tests/sdd-context/boundary-safe.Tests.ps1`,
`tests/sdd-context/boundary-unsafe.Tests.ps1`,
`tests/sdd-context/boundary-emergency.Tests.ps1`

Data Migration: None

Breaking API: None

### Goal
Classify each compaction event as exactly one of `SAFE`, `UNSAFE`, or
`EMERGENCY_AUTO` using only deterministic on-disk signals.

### Must Read
- specs/sdd-context/requirements.md
- specs/sdd-context/design.md
- specs/sdd-context/acceptance-tests.md
- specs/sdd-context/traceability.md

### Scope
Implement the four SAFE conditions of AC-004, the five UNSAFE conditions of
AC-005, and the `EMERGENCY_AUTO` upgrade of AC-006 with the precedence
`EMERGENCY_AUTO > UNSAFE > SAFE`. `auto_compaction` absent or `false` must leave
the normal classification untouched, and `auto_compaction: true` with no UNSAFE
condition present must still report `SAFE` (AC-015). Signals are task lifecycle
status, implementation-report presence, and uncommitted/projected file changes
only — no model judgement. This task produces the boundary value T-002 consumes,
so it runs before T-002 despite the numbering.

### Done When
- [ ] Implementation complete
- [ ] Required tests added or updated
- [ ] Related regression tests pass
- [ ] Implementation report created
- [ ] Quality gate passes
- [ ] Implementation report cross-references REQ-003 and the TEST-004, TEST-005,
      TEST-006, TEST-013 through TEST-021 and TEST-027 evidence paths under
      `specs/sdd-context/verification/`
- [ ] AC-004 verified by TEST-004, TEST-013, TEST-014, TEST-027 (all four SAFE
      conditions)
- [ ] AC-005 verified by TEST-005, TEST-015, TEST-016, TEST-017, TEST-018 (all
      five UNSAFE conditions)
- [ ] AC-006 verified by TEST-006, TEST-020, TEST-021 and AC-015 by TEST-019
      (the EMERGENCY_AUTO upgrade and its three non-upgrade cases)

### Out of Scope
Writing the snapshot (T-002). Reading it back on SessionStart (T-004).

### Blockers
T-001

## T-004 SessionStart recovery-context injection

Source Issue: https://github.com/aharada54914/sdd-forge/issues/137

Approval: Draft

Status: Planned

Risk: medium

Risk Rationale: Prints the recovery context a resumed session acts on; naming
the wrong "first eligible task" would send an agent to the wrong work, but the
hook only writes to stdout and mutates nothing.

Required Workflow: acceptance-first

Requirements: REQ-004

Planned Files: `plugins/sdd-context/scripts/session-start-injector.mjs`,
`tests/sdd-context/session-start.Tests.ps1`,
`tests/sdd-context/handoff-recovery.Tests.ps1`,
`tests/sdd-context/first-eligible.Tests.ps1`

Data Migration: None

Breaking API: None

### Goal
On `SessionStart` with `source=compact`, emit the minimal recovery context from
the latest handoff, and stay silent and successful when there is nothing to
recover.

### Must Read
- specs/sdd-context/requirements.md
- specs/sdd-context/design.md
- specs/sdd-context/acceptance-tests.md
- specs/sdd-context/traceability.md

### Scope
Print the latest handoff path and the first eligible task when a valid
`.sdd/context/handoff.json` exists. The first-eligible rule is exactly the one
AC-016 states: document order in `specs/<feature>/tasks.md`, an approval field
already carrying the approved value, and `Status` equal to `Planned` or
`In Progress`. Exit 0 and print nothing when no handoff exists, and exit 0
emitting no recovery context when the handoff is corrupt or partially written.
Consumes the artefact written by T-002, which is why T-002 blocks this task.

### Done When
- [ ] Implementation complete
- [ ] Required tests added or updated
- [ ] Related regression tests pass
- [ ] Implementation report created
- [ ] Quality gate passes
- [ ] Implementation report cross-references REQ-004 and the TEST-007, TEST-008,
      TEST-024, TEST-025, TEST-026 evidence paths under
      `specs/sdd-context/verification/`
- [ ] AC-007 verified by TEST-007 and AC-008 by TEST-008
- [ ] AC-014 verified by TEST-024 and TEST-025 (corrupt and partially written
      handoff both exit 0 with no recovery context)
- [ ] AC-016 verified by TEST-026 (deterministic first-eligible-task selection)

### Out of Scope
Producing the handoff (T-002). Boundary classification (T-003).

### Blockers
T-001, T-002

## T-005 PostCompact compact-log record

Source Issue: https://github.com/aharada54914/sdd-forge/issues/137

Approval: Draft

Status: Planned

Risk: medium

Risk Rationale: Appends an audit line per compaction; a malformed line corrupts
a log a human later reads, and the task must provably never consume the host's
`compact_summary` payload, but it holds no secret and mutates no SDD state.

Required Workflow: acceptance-first

Requirements: REQ-005

Planned Files: `plugins/sdd-context/scripts/post-compact-logger.mjs`,
`tests/sdd-context/post-compact.Tests.ps1`

Data Migration: None

Breaking API: None

### Goal
Append exactly one valid JSON line per PostCompact invocation, without ever
reading the host's conversation summary.

### Must Read
- specs/sdd-context/requirements.md
- specs/sdd-context/design.md
- specs/sdd-context/acceptance-tests.md
- specs/sdd-context/traceability.md

### Scope
Append one record to `.sdd/context/compact-log.jsonl` per invocation. Per REQ-005
the `compact_summary` input must not be read, consumed, required, or persisted —
absent or empty values are equally acceptable and neither is an error (AC-009).
Directory-availability handling for `.sdd/context/` is owned by T-002 under
AC-013; this task reuses it rather than asserting its own coverage of that path.

### Done When
- [ ] Implementation complete
- [ ] Required tests added or updated
- [ ] Related regression tests pass
- [ ] Implementation report created
- [ ] Quality gate passes
- [ ] Implementation report cross-references REQ-005 and the TEST-009 evidence
      path under `specs/sdd-context/verification/`
- [ ] AC-009 verified by TEST-009: exactly one valid JSON line per invocation,
      no failure when `compact_summary` is absent or empty
- [ ] The implementation demonstrably never reads `compact_summary` (assertion,
      not documentation)

### Out of Scope
Snapshot generation (T-002) and recovery output (T-004).

### Blockers
T-001

## T-006 Runtime wrappers and non-blocking node detection

Source Issue: https://github.com/aharada54914/sdd-forge/issues/137

Approval: Draft

Status: Planned

Risk: high

Risk Rationale: Runs inside the host's compaction path, so a non-zero exit or a
throw degrades the host agent itself rather than this plugin — REQ-006 forbids
it unconditionally and a silent defect here causes material harm to unrelated
work.

Required Workflow: tdd

Requirements: REQ-006

Planned Files: `hooks/claude-hooks.json`, `hooks/hooks.json`, `hooks/hooks.ps1`,
`plugins/sdd-context/scripts/hook-wrapper.mjs`,
`plugins/sdd-context/scripts/detect-node.mjs`,
`tests/sdd-context/node-absent.Tests.ps1`

Data Migration: None

Breaking API: None

Rollback: Revert this task's commits per `infra-spec.md` `## Rollback` — the
plugin directory and the marketplace/validate-repository expectations revert in
one commit. There is no runtime feature flag (design.md `## Deployment / CI
Plan`), so reversion removes the hook descriptors this task registered; with no
descriptor present the host invokes nothing and its compaction path returns to
its pre-task behaviour. Existing `.sdd/context/` files become inert.

### Goal
Give all three host runtimes a descriptor that reaches the same Node core, and
guarantee that a missing or unusable `node` degrades to a clean no-op instead of
failing the host's compaction.

### Must Read
- specs/sdd-context/requirements.md
- specs/sdd-context/design.md
- specs/sdd-context/acceptance-tests.md
- specs/sdd-context/traceability.md
- specs/sdd-context/infra-spec.md

### Scope
Implement the Claude Code node-exec descriptor, the Codex POSIX `sh` descriptor,
and the PowerShell fallback for Windows and WSL invocation paths, all delegating
to one wrapper per design.md `## Architecture`. Node detection happens at every
wrapper call site before the core is invoked, per the AC-010 entry in the UI
Integration Checklist — enforced in code, not by documentation. Every hook entry
point exits 0 and emits at most a warning when `node` is absent. The wrappers
perform no logic beyond detection and argv normalization so the three runtimes
cannot drift. Delegates to the core built by T-002 through T-005, which is why
all four block this task.

### Done When
- [ ] Implementation complete
- [ ] Required tests added or updated
- [ ] Related regression tests pass
- [ ] Implementation report created
- [ ] Quality gate passes
- [ ] Implementation report cross-references REQ-006 and the TEST-010 evidence
      path under `specs/sdd-context/verification/`
- [ ] AC-010 verified by TEST-010: with `node` absent from PATH every hook exits
      0 and emits at most a warning
- [ ] Red→Green evidence captured (Required Workflow: tdd)
- [ ] Independent review verdict recorded
- [ ] Provenance recorded with `spec_revision`
- [ ] Rollback verified: reverting this task's commits removes the hook
      descriptors and restores the host's pre-task compaction behaviour, per
      `infra-spec.md` `## Rollback`

### Out of Scope
The core logic the wrappers delegate to (T-002 through T-005). The security
assertion of the write boundary (T-007).

### Blockers
T-001, T-002, T-003, T-004, T-005

## T-007 Write-boundary and no-exfiltration verification

Source Issue: https://github.com/aharada54914/sdd-forge/issues/137

Approval: Draft

Status: Planned

Risk: high

Risk Rationale: Establishes the enforced security boundary of a component that
runs with host privileges — no network, no secret reads, and writes confined to
two paths (REQ-007). A silent defect here lets a compaction hook reach protected
SDD state or exfiltrate repository content.

Security-Sensitive: true

Required Workflow: tdd

Requirements: REQ-007

Planned Files: `tests/sdd-context/security-scan.Tests.ps1`; hardening edits, only
where the scan proves them necessary, to the six Node-core files this task's
blockers deliver: `plugins/sdd-context/scripts/snapshot-writer.mjs`,
`plugins/sdd-context/scripts/boundary-detector.mjs`,
`plugins/sdd-context/scripts/session-start-injector.mjs`,
`plugins/sdd-context/scripts/post-compact-logger.mjs`,
`plugins/sdd-context/scripts/hook-wrapper.mjs`,
`plugins/sdd-context/scripts/detect-node.mjs`

Data Migration: None

Breaking API: None

Rollback: Revert this task's commits per `infra-spec.md` `## Rollback`. The scan
is additive test surface, and any hardening edit is a narrowing of behaviour
inside files T-002 through T-006 already delivered, so reverting restores those
files to their post-T-006 state without removing the feature itself.

### Goal
Prove, by executable scan rather than assertion in prose, that the hook execution
path makes no network calls, reads no secrets, and writes nowhere outside
`.sdd/context/` and `reports/context/`.

### Must Read
- specs/sdd-context/requirements.md
- specs/sdd-context/design.md
- specs/sdd-context/acceptance-tests.md
- specs/sdd-context/traceability.md
- specs/sdd-context/security-spec.md
- specs/sdd-context/infra-spec.md

### Scope
Implement the security scan covering the whole hook execution path established by
T-002 through T-006, against the Trust Boundaries, Authorization, and Data
Classification tables of security-spec.md. The scan must fail closed: an
unclassifiable write target or an unexpected outbound call is a failure, not a
warning. Hardening is limited to the six files listed under Planned Files, and
only where the scan proves it necessary. T-006 blocks this task so that those
files are complete before any hardening edit opens them.

### Done When
- [ ] Implementation complete
- [ ] Required tests added or updated
- [ ] Related regression tests pass
- [ ] Implementation report created
- [ ] Quality gate passes
- [ ] Implementation report cross-references REQ-007 and the TEST-011 evidence
      path under `specs/sdd-context/verification/`
- [ ] AC-011 verified by TEST-011: no network calls, no secret reads, no writes
      outside `.sdd/context/` and `reports/context/`
- [ ] Red→Green evidence captured (Required Workflow: tdd)
- [ ] Independent review verdict recorded
- [ ] Provenance recorded with `spec_revision`
- [ ] Cross-model verification completed (Security-Sensitive: true)
- [ ] Rollback verified: reverting this task's commits restores the six Node-core
      files to their post-T-006 state, per `infra-spec.md` `## Rollback`

### Out of Scope
Implementing the hooks themselves (T-002 through T-006); this task verifies and
hardens what they built.

### Blockers
T-001, T-006

## T-008 Install, trust, and storage-contract documentation

Source Issue: https://github.com/aharada54914/sdd-forge/issues/137

Approval: Draft

Status: Planned

Risk: low

Risk Rationale: Documentation only — no control flow, no data, and no security
behaviour changes. The Codex trust procedure it describes is enforced by the
operator's runtime, not by this text.

Required Workflow: test-after

Requirements: REQ-008

Planned Files: `plugins/sdd-context/docs/`,
`plugins/sdd-ship/skills/ship/SKILL.md` (cross-reference only),
`tests/sdd-context/docs.Tests.ps1`

Data Migration: None

Breaking API: None

### Goal
Document installation, the Codex hook trust procedure, the storage layout, and
the SAFE/UNSAFE/EMERGENCY_AUTO contract so an operator can adopt the plugin
without reading its source.

### Must Read
- specs/sdd-context/requirements.md
- specs/sdd-context/design.md
- specs/sdd-context/acceptance-tests.md
- specs/sdd-context/traceability.md

### Scope
Write the install and trust documentation under `plugins/sdd-context/docs/`,
naming the exact `hooks/hooks.json` path the Codex operator must trust per the
AC-012 entry in the UI Integration Checklist. Document the storage layout of
design.md `### Storage Layout` and the boundary contract. Add the cross-reference
from the ship skill named in design.md's Deployment execution order step 6. This
is the last step of that order.

### Done When
- [ ] Implementation complete
- [ ] Required tests added or updated
- [ ] Related regression tests pass
- [ ] Implementation report created
- [ ] Quality gate passes
- [ ] Implementation report cross-references REQ-008 and the TEST-012 evidence
      path under `specs/sdd-context/verification/`
- [ ] AC-012 verified by TEST-012: documentation includes the Codex hook trust
      instructions and the storage/status contract
- [ ] The documented trust path names `hooks/hooks.json` exactly

### Out of Scope
Any behavioural change to the hooks or the Node core.

### Blockers
T-001
