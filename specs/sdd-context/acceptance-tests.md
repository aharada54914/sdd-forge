# Acceptance Tests: sdd-context

| Acceptance Criterion | Requirement | Test ID | Test Type | Test Target | Status |
|---|---|---|---|---|---|
| AC-001 triple manifests validate against their schemas/linters and reference `./plugins/sdd-context` version `1.14.0` | REQ-001 | TEST-001 | unit | tests/sdd-context/manifests.Tests.ps1 | Planned |
| AC-002 two consecutive PreCompact invocations on an unchanged repository produce byte-identical HANDOFF.md and handoff.json | REQ-002 | TEST-002 | integration | tests/sdd-context/determinism.Tests.ps1 | Planned |
| AC-003 handoff.json contains deterministic boundary/feature/task/report/change/timestamp/artifact fields; HANDOFF.md is rendered from that JSON | REQ-002 | TEST-003 | unit | tests/sdd-context/snapshot-shape.Tests.ps1 | Planned |
| AC-004 (a) every task has `Status: Done` and the detector reports `SAFE` | REQ-003 | TEST-004 | unit | tests/sdd-context/boundary-safe.Tests.ps1 | Planned |
| AC-004 (b) every task is in a BLOCKED stop state and the detector reports `SAFE` | REQ-003 | TEST-013 | unit | tests/sdd-context/boundary-safe.Tests.ps1 | Planned |
| AC-004 (c) bootstrap outputs are saved and the detector reports `SAFE` | REQ-003 | TEST-014 | unit | tests/sdd-context/boundary-safe.Tests.ps1 | Planned |
| AC-004 (d) every targeted task is Implementation Complete before a quality gate and the detector reports `SAFE` | REQ-003 | TEST-027 | unit | tests/sdd-context/boundary-safe.Tests.ps1 | Planned |
| AC-005 (a) a specification interview is running and the detector reports `UNSAFE` | REQ-003 | TEST-005 | unit | tests/sdd-context/boundary-unsafe.Tests.ps1 | Planned |
| AC-005 (b) a task has `Status: In Progress` and the detector reports `UNSAFE` | REQ-003 | TEST-015 | unit | tests/sdd-context/boundary-unsafe.Tests.ps1 | Planned |
| AC-005 (c) a quality gate is running and the detector reports `UNSAFE` | REQ-003 | TEST-016 | unit | tests/sdd-context/boundary-unsafe.Tests.ps1 | Planned |
| AC-005 (d) the current task implementation report is missing and the detector reports `UNSAFE` | REQ-003 | TEST-017 | unit | tests/sdd-context/boundary-unsafe.Tests.ps1 | Planned |
| AC-005 (e) uncommitted/projected file changes exist and the detector reports `UNSAFE` | REQ-003 | TEST-018 | unit | tests/sdd-context/boundary-unsafe.Tests.ps1 | Planned |
| AC-006 auto_compaction=true while UNSAFE and the detector reports `EMERGENCY_AUTO` | REQ-003 | TEST-006 | unit | tests/sdd-context/boundary-emergency.Tests.ps1 | Planned |
| AC-015 auto_compaction=true while no AC-005 UNSAFE condition holds and the detector reports `SAFE` | REQ-003 | TEST-019 | unit | tests/sdd-context/boundary-emergency.Tests.ps1 | Planned |
| AC-006 auto_compaction absent uses normal SAFE/UNSAFE classification | REQ-003 | TEST-020 | unit | tests/sdd-context/boundary-emergency.Tests.ps1 | Planned |
| AC-006 auto_compaction=false uses normal SAFE/UNSAFE classification | REQ-003 | TEST-021 | unit | tests/sdd-context/boundary-emergency.Tests.ps1 | Planned |
| AC-007 SessionStart with source=compact prints latest handoff path and first eligible task when handoff exists | REQ-004 | TEST-007 | integration | tests/sdd-context/session-start.Tests.ps1 | Planned |
| AC-008 SessionStart exits 0 and prints nothing when no handoff exists | REQ-004 | TEST-008 | integration | tests/sdd-context/session-start.Tests.ps1 | Planned |
| AC-009 PostCompact appends exactly one valid JSON line and does not fail when compact_summary is absent/empty | REQ-005 | TEST-009 | integration | tests/sdd-context/post-compact.Tests.ps1 | Planned |
| AC-010 node missing from PATH: every hook exits 0 and emits at most a warning | REQ-006 | TEST-010 | integration | tests/sdd-context/node-absent.Tests.ps1 | Planned |
| AC-011 security scan confirms no network calls, no secret reads, and no writes outside `.sdd/context/` and `reports/context/` | REQ-007 | TEST-011 | integration | tests/sdd-context/security-scan.Tests.ps1 | Planned |
| AC-012 documentation includes Codex hook trust instructions and the storage/status contract | REQ-008 | TEST-012 | unit | tests/sdd-context/docs.Tests.ps1 | Planned |
| AC-013 `.sdd/context/` absent: PreCompact exits 0 and emits at most a warning | REQ-002/REQ-006 | TEST-022 | integration | tests/sdd-context/context-dir.Tests.ps1 | Planned |
| AC-013 `.sdd/context/` read-only: PreCompact exits 0 and emits at most a warning | REQ-002/REQ-006 | TEST-023 | integration | tests/sdd-context/context-dir.Tests.ps1 | Planned |
| AC-014 `handoff.json` corrupt: SessionStart exits 0 and emits no recovery context | REQ-004 | TEST-024 | integration | tests/sdd-context/handoff-recovery.Tests.ps1 | Planned |
| AC-014 `handoff.json` partially written: SessionStart exits 0 and emits no recovery context | REQ-004 | TEST-025 | integration | tests/sdd-context/handoff-recovery.Tests.ps1 | Planned |
| AC-016 first-eligible-task rule is deterministic (document order, Approval Approved, Status Planned or In Progress) | REQ-004 | TEST-026 | unit | tests/sdd-context/first-eligible.Tests.ps1 | Planned |

## UI Integration Checklist

> The user-facing entry points are agent hook descriptors (Claude Code
> `hooks/claude-hooks.json`, Codex `hooks/hooks.json`) and generated Markdown
> handoff artifacts; there is no graphical UI.

- [ ] AC-001: The plugin is discoverable from the Claude Code / Codex command
  surface via its triple manifest entry (`plugins/sdd-context` referenced at
  version `1.14.0`).
- [ ] AC-010: The graceful no-op safety precondition is enforced at every hook
  wrapper call site (node detection before invoking the Node core), not only
  by documentation.
- [ ] AC-012: The Codex hook trust procedure is documented and links the exact
  `hooks/hooks.json` path the operator must trust.
