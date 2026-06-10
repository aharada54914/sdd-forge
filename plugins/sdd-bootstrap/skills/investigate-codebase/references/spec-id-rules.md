# Spec ID Rules

## ID Prefixes

| Prefix | Artifact | Example |
|--------|----------|---------|
| `INV-NNN` | Investigation finding | `INV-001` |
| `BL-NNN` | Baseline observable behavior | `BL-001` |
| `REQ-NNN` | Requirement | `REQ-001` |
| `T-NNN` | Implementation task | `T-001` |
| `ADR-NNN` | Architecture decision record | `ADR-001` |

## Sequencing

- Assign IDs in the order findings are recorded, starting at `001`.
- IDs are unique within a feature's `specs/<feature>/` directory.
- Never reuse a number even after a finding is removed.

## Cross-Referencing

- Each requirement in `requirements.md` must list the INV-xxx and BL-xxx IDs
  that motivated it in a `Source` column or field.
- `traceability.md` includes an `Investigation` column referencing INV/BL IDs
  alongside the Requirement, Design, and Test columns.
- ADRs that resolve an Open Question from `investigation.md` must cite the
  relevant INV-xxx IDs in their Context section.

## Deprecation

- Never delete an ID that was previously assigned.
- If a finding is superseded or no longer relevant, mark it
  `[DEPRECATED: reason]` in the Finding column.
- Deprecated IDs remain in the table so traceability links do not break.

## Scope Isolation

- INV and BL IDs are scoped to a single feature investigation.
- When two features share overlapping findings, each feature maintains its own
  independent sequence; cross-references use the full qualified form
  `<feature>/INV-NNN`.
