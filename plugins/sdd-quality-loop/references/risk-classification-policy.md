# Risk Classification Policy

Every task carries a `Risk` tier that determines how much assurance the quality
gate requires. Classification is **proposed by the implementation agent** and
**confirmed (or changed) by a human**. An agent MUST NOT self-certify its own
risk tier as the basis for relaxing a gate — the tier is validated deterministically
by `check-risk.(sh|ps1)` and enforced by `check-contract.(sh|ps1)` via the
`risk-gate-matrix.md`.

## Tiers

| Tier | Use when the change… | Required Workflow |
|------|----------------------|-------------------|
| `low` | is cosmetic or non-behavioral: docs, comments, wording, pure formatting, isolated UI copy. No control-flow, data, or security impact. | `test-after` |
| `medium` | is a normal feature or fix with observable behavior but no sensitive surface: typical app logic, internal tooling, refactors with tests. | `acceptance-first` |
| `high` | touches a **sensitive surface**: authentication/authorization, billing/payments, data mutation/migration, access control, secrets handling, public API contracts, or anything where a silent defect causes material harm. | `tdd` (Red→Green) |
| `critical` | touches a **safety/regulated** surface: medical, financial settlement, physical safety, legal/regulatory compliance, or irreversible destructive operations. | `tdd` + two-person approval + signed evidence |

When a task spans tiers, classify at the **highest** applicable tier.

## Required Workflow derivation

- `low` → `test-after`: tests may follow implementation; `unit-tests` may be
  waived with a `waiver_reason`.
- `medium` → `acceptance-first`: write the acceptance test before/with the
  implementation; regression tests required.
- `high` / `critical` → `tdd`: capture **Red** (failing test) evidence before the
  fix and **Green** (passing) evidence after. For refactor/bugfix tasks the Red
  evidence may be the failing differential-baseline case.

## Who classifies

1. The interview / `implement-task` agent **proposes** `Risk` + `Risk Rationale`.
2. A human **confirms** by approving the task (Approval gate). The proposal alone
   never authorizes a gate change.
3. Lowering an already-approved tier (e.g. `high → low`) is a **judgment** action:
   it requires human re-approval and a recorded spec-change (diff + reason +
   approver). Sudo mode never auto-passes a tier downgrade.

## Rationale requirement

`Risk Rationale` MUST name the sensitive surface or reason for the tier (e.g.
"verifies session tokens (REQ-AUTH-004)"). An empty rationale fails `check-risk`.

## Examples

| Change | Tier |
|--------|------|
| Fix a typo in README | low |
| Add a new list-filtering option with tests | medium |
| Change password-reset token TTL | high |
| Modify the payment capture / settlement path | critical |
| Add a DB migration that drops a column | critical |
| Refactor an internal helper, behavior preserved | medium |

## Backward compatibility

A task or contract with **no** `Risk`/`risk` field is **legacy mode**: the
risk-tier pass is skipped entirely and NO tier minimum applies, so
pre-feature artifacts keep validating. Do **NOT** map absent to `medium` -
an absent field carries no tier and must never be silently promoted to one
(design.md, requirements.md and risk-gate-matrix.md all state this rule;
this paragraph previously contradicted them - corrected 2026-08-21,
RT-20260821-001, verified against measured `check-contract` behavior: a
no-risk fixture passes while the identical fixture with `risk: medium`
fails on the medium tier minimum). New tasks MUST set `Risk`; `check-risk`
fails closed when it is absent in a task that opts into the risk-adaptive
flow.

See `risk-gate-matrix.md` for the tier → required-checks mapping the gate enforces.
