# Investigation: Claude workflow compatibility

## Scope

Investigate why the public Claude Code command `/sdd-bootstrap:run` is not
available after installing the SDD marketplace, and identify workflow defects
that would still block the bootstrap flow after command discovery is restored.

## Findings

### INV-001: `sdd-bootstrap` is rejected by the current Claude manifest validator

`claude plugin validate plugins/sdd-bootstrap` on Claude Code 2.1.177 reports
`agents: Invalid input`. The installed marketplace copy consequently has status
`failed to load`; no namespaced slash command can be registered from it.

### INV-002: The same unsupported `agents` declaration disables two required internal plugins

`sdd-quality-loop` and `sdd-review-loop` use the same `"agents": ["./agents/"]`
manifest form and are rejected for the same reason. `sdd-review-loop` is required
by the bootstrap implementation-policy and task-decomposition review gates.

### INV-003: `rules` is not a recognized Claude plugin manifest key

The validator warns that `rules` is ignored at load time. Keeping it in Claude
manifests creates an apparent path-scoped policy mechanism that Claude Code does
not apply.

### INV-004: One skill has invalid YAML frontmatter

`sdd-quality-loop/skills/wfi-audit-cycle/SKILL.md` has an unquoted colon-space
sequence in its `description`. Claude Code reports that its frontmatter cannot be
parsed and will be dropped at runtime.

### INV-005: CI does not validate the Claude plugin manifests

The cross-platform CI job installs Claude Code, but uses it only to exercise hook
tooling. `tests/claude-registration.tests.ps1` replaces the CLI with a fake and
therefore verifies installation commands and messaging, not actual manifest
loadability.

### INV-006: The full bootstrap workflow references a missing prerequisite

`sdd-bootstrap-interviewer` requires `/spec-review-loop` before
`impl-review-loop`, but no such skill or plugin exists in this repository or
marketplace. The current full workflow cannot advance from Phase 1 even when the
visible plugins load.

## Evidence

- `claude plugin list` — `sdd-bootstrap`, `sdd-quality-loop`, and
  `sdd-review-loop` are reported as failed to load with `agents: Invalid input`.
- `claude plugin validate` — reproduces INV-001 through INV-004 from source.
- `claude plugin validate plugins/sdd-ship`, `sdd-implementation`, and
  `sdd-lite` — pass, proving that the `skills/run/SKILL.md` layout and
  `/plugin:run` naming convention are valid.
- `.github/workflows/test.yml` and `tests/claude-registration.tests.ps1` — show
  the missing real-manifest validation in CI.
