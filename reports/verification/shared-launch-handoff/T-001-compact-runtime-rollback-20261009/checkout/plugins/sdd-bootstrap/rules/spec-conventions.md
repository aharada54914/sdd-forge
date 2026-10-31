---
paths:
  - "docs/specs/**"
  - "specs/**"
---

# SDD Spec Conventions

## ID Prefixes

| Prefix | Artifact | Example |
|--------|----------|---------|
| `INV-NNN` | Investigation finding | `INV-001` |
| `BL-NNN` | Baseline observable behavior | `BL-001` |
| `REQ-NNN` | Requirement | `REQ-001` |
| `T-NNN` | Implementation task | `T-001` |
| `ADR-NNN` | Architecture decision record | `ADR-001` |
| `AC-NNN` | Acceptance criterion | `AC-001` |
| `TEST-NNN` | Test case | `TEST-001` |

Assign IDs in order starting at `001`. IDs are unique within `specs/<feature>/`. Never reuse a number.

## API Contracts

- Prefer OpenAPI 3.1 for HTTP APIs.
- Define request schemas, response schemas, and validation error schemas.
- Define authentication and authorization requirements when known.
- Do not change API behavior without updating contracts.
- If there is no HTTP API, create JSON Schema or `data-contract.md` instead.
