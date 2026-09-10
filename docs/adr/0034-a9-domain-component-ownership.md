# ADR-0034: A9 independent domain-plugin ownership

Date: 2026-09-08
Status: Human decision accepted; specification review and implementation pending

## Context

A9 OQ-001 named six plugin components plus MCP and installer, omitting domain.
Attempt 1 round 1 reviewer B reported this contradiction. At base commit
`135b147926689bd3adc8c834932a9b82b9f5a607`, `git ls-tree --name-only HEAD:plugins`
lists `sdd-domain`, while `git ls-tree -r --name-only HEAD plugins/domain`
returns no files. The approval prompt's shorter path was a spelling error.

## Decision

The user approved an independent ninth component on 2026-09-08:
「A9 を進めるため、plugins/domain/** を独立した「9番目のコンポーネント」として扱う設計変更を承認」

Use stable ID `sdd-domain` and canonical ownership `plugins/sdd-domain/**`.
Retain the existing eight IDs and their ownership. Do not create a phantom
directory, an alias rule, or a blanket rule accepting future plugins.
The exact set and acceptance oracles are in A9 requirements.md OQ-001/OQ-002
and acceptance-tests.md TEST-003–006.

## Alternatives and consequences

- Independent component: preserves the existing per-plugin boundary, at the
  cost of one more inventory/fixture entry. Selected by the human.
- Fold into another component: keeps eight IDs but hides a plugin boundary.
- Cross-cutting: avoids another ID but loses domain-specific ownership.

Re-verify the actual tracked inventory before review and implementation; stop
for reconciliation on drift. This does not approve live Context publication,
change enforcement, resolve unrelated review findings, or replace old FAILs.
Only fresh formal review can establish that the amended specification passes.

## Related decisions and identifier reservation

ADR-0030 governs ownership resolver semantics; ADR-0019 governs publication
approval. Neither is amended here. Local A9 and origin/main ADR inventories
ended at 0032 when checked; the root checkout already has a pending 0033 ADR.
0034 was unused in those inspected inventories. Recheck all integration inputs
for number collisions before merging; this is not a global reservation.
