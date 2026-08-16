# Traceability: sdd-context

Every Layer Spec cell must contain one or more canonical
`<layer>-spec.md#<section>` anchors, or
`N/A — cross-layer only: <reason>`. Blank cells and bare `N/A` are invalid.

| Requirement | Design | Layer Spec | Code Target | Test ID | Status |
|---|---|---|---|---|---|
| REQ-001 | design.md#components | infra-spec.md#deployment-topology | `.claude-plugin/marketplace.json`, `.codex-plugin/plugin.json`, `.plugin/plugin.json` | TEST-001 | Planned |
| REQ-002 | design.md#api--contract-plan | infra-spec.md#deployment-topology | plugins/sdd-context/scripts/snapshot-writer.mjs | TEST-002, TEST-003, TEST-022, TEST-023 | Planned |
| REQ-003 | design.md#architecture | N/A — cross-layer only: the boundary classifier is deterministic logic with no single layer owner; its inputs are task lifecycle state and file-change signals rather than any layer's surface | plugins/sdd-context/scripts/boundary-detector.mjs | TEST-004, TEST-005, TEST-006, TEST-013, TEST-014, TEST-015, TEST-016, TEST-017, TEST-018, TEST-019, TEST-020, TEST-021, TEST-027 | Planned |
| REQ-004 | design.md#api--contract-plan | ux-spec.md#interaction-sequence | plugins/sdd-context/scripts/session-start-injector.mjs | TEST-007, TEST-008, TEST-024, TEST-025, TEST-026 | Planned |
| REQ-005 | design.md#api--contract-plan | infra-spec.md#observability | plugins/sdd-context/scripts/post-compact-logger.mjs | TEST-009 | Planned |
| REQ-006 | design.md#external-integrations | infra-spec.md#deployment-topology | plugins/sdd-context/scripts/hook-wrapper.mjs; plugins/sdd-context/scripts/detect-node.mjs; hooks/claude-hooks.json; hooks/hooks.json; hooks/hooks.ps1 | TEST-010 | Planned |
| REQ-007 | design.md#security-boundaries | security-spec.md#trust-boundaries; security-spec.md#data-classification-and-protection | plugins/sdd-context/scripts/*.mjs (write-path confinement) | TEST-011 | Planned |
| REQ-008 | design.md#deployment--ci-plan | ux-spec.md#scope-and-user-journeys | plugins/sdd-context/docs/ | TEST-012 | Planned |

## Investigation Grounding

Stated as a list rather than a table: the layer-traceability validator inspects
every table row whose first cell matches `REQ-NNN`, and a second such table
would be read as a second set of Layer Spec cells.

- **REQ-001** — no INV finding applies. Manifest registration was not a
  contested assumption.
- **REQ-002** — INV-001, INV-003. Hook input contract, and the write-path
  gitignore layout.
- **REQ-003** — INV-001. The documented `source` and `auto_compaction` input
  fields the classifier consumes.
- **REQ-004** — INV-001. The documented `source` input field for SessionStart.
- **REQ-005** — INV-001. `compact_summary` is documented as optional and is
  deliberately left unconsumed.
- **REQ-006** — INV-002. Node 18+ accepted as the implementation runtime, its
  absence handled as a graceful no-op.
- **REQ-007** — INV-003. Write paths confined regardless of the repository's
  gitignore configuration.
- **REQ-008** — no INV finding applies. Documentation content was not a
  contested assumption.

## Task Mapping

| Task | Requirements | Acceptance Criteria | Test Target | Risk | Required Workflow |
|---|---|---|---|---|---|
| T-001 | REQ-001 | AC-001 | tests/sdd-context/manifests.Tests.ps1 | medium | acceptance-first |
| T-002 | REQ-002 | AC-002, AC-003, AC-013 | tests/sdd-context/determinism.Tests.ps1; tests/sdd-context/snapshot-shape.Tests.ps1; tests/sdd-context/context-dir.Tests.ps1 | medium | acceptance-first |
| T-003 | REQ-003 | AC-004, AC-005, AC-006, AC-015 | tests/sdd-context/boundary-safe.Tests.ps1; tests/sdd-context/boundary-unsafe.Tests.ps1; tests/sdd-context/boundary-emergency.Tests.ps1 | medium | acceptance-first |
| T-004 | REQ-004 | AC-007, AC-008, AC-014, AC-016 | tests/sdd-context/session-start.Tests.ps1; tests/sdd-context/handoff-recovery.Tests.ps1; tests/sdd-context/first-eligible.Tests.ps1 | medium | acceptance-first |
| T-005 | REQ-005 | AC-009 | tests/sdd-context/post-compact.Tests.ps1 | medium | acceptance-first |
| T-006 | REQ-006 | AC-010 | tests/sdd-context/node-absent.Tests.ps1 | high | tdd |
| T-007 | REQ-007 | AC-011 | tests/sdd-context/security-scan.Tests.ps1 | high | tdd |
| T-008 | REQ-008 | AC-012 | tests/sdd-context/docs.Tests.ps1 | low | test-after |

## Layer Coverage

| Layer | Applicable Requirements | Acceptance Criteria | Primary Sections | Gaps / Reasoned N/A |
|---|---|---|---|---|
| UX | REQ-004, REQ-008 | AC-007, AC-008, AC-012, AC-014, AC-016 | ux-spec.md#scope-and-user-journeys; ux-spec.md#interaction-sequence | None. The user-facing surface is agent hook descriptors and generated Markdown, not a graphical UI; ux-spec.md records reasoned N/A for each graphical-UI section. |
| Frontend | None | None | frontend-spec.md#technology-stack | N/A — no change: the plugin ships no graphical frontend, no web runtime, and no client-side state, as frontend-spec.md records. No requirement maps to this layer. |
| Infrastructure | REQ-001, REQ-002, REQ-005, REQ-006 | AC-001, AC-002, AC-003, AC-009, AC-010, AC-013 | infra-spec.md#deployment-topology; infra-spec.md#ci-cd-sequence; infra-spec.md#observability | None. |
| Security | REQ-007 | AC-011 | security-spec.md#trust-boundaries; security-spec.md#data-classification-and-protection | None. A security impact assessment is recorded even though REQ-007 is the only requirement owned by this layer, because every hook runs in the host privilege context. |

REQ-003 appears in no layer row by design: its Layer Spec cell records
`N/A — cross-layer only`, since the boundary classifier is deterministic logic
whose inputs are task lifecycle state and file-change signals rather than any
one layer's surface. Its acceptance criteria (AC-004, AC-005, AC-006, AC-015)
are verified through T-003 and are covered in the requirement table above.

## Verification Evidence Paths

Evidence is written per test id under `specs/sdd-context/verification/` as
`TEST-NNN.log`, and is the only source that may change a requirement's Status.

## Final Status

Update requirement status only from saved test evidence and quality-gate
reports. Keep implementation reports as claims, not verification evidence.
