# Infrastructure specification: Research evidence foundation

DRAFT. REQ-003, REQ-004, REQ-010, REQ-013–REQ-015; AC-002, AC-009,
AC-012–AC-014. All paths below are planned implementation outputs unless
explicitly described as this draft's registrations.

## Files and runtime

- `contracts/research-evidence.schema.json` and byte-identical packaged copy
  under `plugins/sdd-quality-loop/contracts/`.
- `plugins/sdd-quality-loop/scripts/validate-research-evidence.{py,sh,ps1}`:
  Python stdlib, existing schema helper and canonicalizer, no installed
  dependency, network, Git executor or service.
- `tests/research-evidence.tests.py` and synthetic fixtures under
  `tests/fixtures/research-evidence/`; future suite registration uses existing
  `tests/verification-catalog.json` path/runtime/ci_jobs conventions. Select
  actual current CI jobs during implementation and register affected paths.
- `PLUGIN-CONTRACTS.md`, `CHANGELOG.md`, optional backstop ignore entry, and
  final ADR treatment under the normal approval workflow. README/USERGUIDE/
  skill-reference counts change only when their actual counted surface changes.
  A validator is not a new skill/plugin.

This draft adds only its spec directory to AGENTS.md and
`specs/workflow-state-registry.json` with profile `full`, plus Proposed
ADR-0041 and its index row. No runtime invocation is wired into an existing
flow. Feature-scoped workflow checks do not establish full-repository health.

## Storage and export

Only `specs/<feature>/research/records/research-evidence.json` is owned by
this contract. The records subtree is closed; sibling map/log/edge artifacts
are downstream. Consumers choose explicit metadata/receipt paths and must
not recursively package a research directory. Normal bundle reference paths
are repo-relative (requirements G-7/G-8), not private cache paths.

#606 must enforce cache placement outside configured worktrees, CI workspace,
CI temp and export staging roots using resolved paths, with actual access,
retention and deletion controls. #606/#610 test unauthorized access, expiry,
revocation and accidental CI artifact inclusion. A static ignore or filename
check alone is insufficient. #605's passive validator does not enforce live
storage authorization or scan every system worktree.

## Platform and execution status

Linux, macOS, Windows and Claude/Codex/Copilot runtime usage are unverified.
Planned wrapper parity checks compare argv/stdout/stderr/exit codes; PowerShell
case-sensitivity negatives are required. This docs-only packet runs no full
suite and no formal managed review. Sparse omitted reports/verification files
are not deletions and must not be reported as missing historical evidence.
