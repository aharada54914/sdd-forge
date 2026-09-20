# verification-contract/v2 — contract-side spec_revision enforcement (RT-20260821-005, option c)

Status: design + implementation draft (2026-08-21). The implementation is
staged as `docs/ci-staging/rt-20260821-005-contract-schema-v2.patch` and
applies AFTER `rt-20260821-check-contract-family.patch` (check-contract.* and
tests/gates.tests.sh are guard-protected, so both travel the human-apply
route). Farm-validated; results at the bottom.

## Problem

AC-005 (risk-adaptive-layer) reads: "check-contract / check-evidence-bundle:
high/critical missing `spec_revision` ⇒ fail". The bundle side is
implemented; the contract side is not — a `risk: high` contract with no
`spec_revision` passes the contract gate (measured, both runtimes, T-006
cycle-1 evaluation seq 0815).

## Why not the two obvious fixes

| Option | Why rejected |
|---|---|
| (a) Enforce unconditionally | Measured blast radius: **~40 shipped high/critical contracts across 8 features carry an EMPTY `spec_revision`** (sdd-forge-mcp 8, ci-mcp 10, local-env-mcp 7, evidence-deep-verify 5, cross-model-verification 3, sdd-domain 3, sdd-forge-refactor 1, plus legacy rows). They would redden retroactively, and backfilling a months-old corpus hash today would **fabricate provenance** — the hash attests "the spec looked like X when this contract was authored", which is unknowable now. |
| (b) Date-gated grandfather (`created` >= cutoff) | The gate's verdict would no longer be a pure function of the artifact's declared intent — a copied `created` value flips enforcement silently, and clock semantics differ across the twins. Violates the determinism-from-content principle the gates are built on. |

## Design (option c): explicit schema versioning

A new OPTIONAL top-level contract field:

```json
{ "schema": "verification-contract/v2", ... }
```

Measured precondition: **0 of 194 shipped contracts carry any `schema` key**,
so the marker is collision-free and absence is a well-defined state.

### Semantics

| Contract state | Behavior |
|---|---|
| `schema` absent | **v1 / legacy.** Behavior byte-for-byte unchanged. All 194 shipped contracts are v1. |
| `schema: "verification-contract/v2"` + risk high/critical | `spec_revision` MUST be well-formed: 40-hex (git commit, the 7-contract convention) or 64-hex (corpus digest, the 119-contract convention), lowercase only (the recurring ps1 case-class is closed at birth). Missing/empty/malformed ⇒ fail. |
| `schema: "verification-contract/v2"` + risk low/medium | `spec_revision` not required (AC-005 scopes the rule to high/critical). |
| `schema` = anything else | **Fail closed**: `contract schema is unrecognized: <value>` on both runtimes. Future versions extend the recognized set explicitly. |

Enforcement lives in `check-contract.py` (schema recognition in `run()` next
to the family patch's non-string guard; the spec_revision rule inside
`_pass4_risk_tier` where risk context exists) and identically in
`check-contract.ps1` (`-ceq`/`-cne`/`-cmatch` throughout — case-sensitive
from the start).

### Migration

- **Authoring**: new contracts SHOULD declare `schema:
  "verification-contract/v2"`. The quality-gate SKILL's authoring guidance is
  the natural home for this instruction; SKILL.md is guard-protected, so that
  one-line addition belongs in the next human maintenance batch (noted here
  rather than staged, to keep this patch behavior-only).
- **Existing contracts**: never rewritten. A v1 contract upgrades only when a
  human (or a re-gate cycle) deliberately adds the schema field AND a
  truthful spec_revision measured at that moment.
- **AC-005 wording**: after this ships, AC-005's contract-side clause is
  satisfied for every v2 contract; the residual v1 exemption should be
  recorded in the same frozen-doc amendment batch as RT-014 (one sentence:
  "contract-side enforcement applies to verification-contract/v2").

### Tests (both polarities, both runtimes — T-004V.1–7 in gates.tests.sh)

1. v2 + high + missing spec_revision ⇒ fail (sh and ps1)
2. v2 + high + 64-hex ⇒ pass
3. v2 + high + 40-hex ⇒ pass
4. v2 + high + UPPERCASE hex ⇒ fail (case-class pinned)
5. absent schema + high + missing spec_revision ⇒ **still passes** (the
   grandfather is asserted, not assumed)
6. unknown schema value ⇒ fail closed (sh and ps1)
7. v2 + medium + missing spec_revision ⇒ pass (tier scope)

## Apply order

```
git apply docs/ci-staging/rt-20260821-006-gates-tests.patch
git apply docs/ci-staging/rt-20260821-check-contract-family.patch
git apply docs/ci-staging/rt-20260821-005-contract-schema-v2.patch
bash tests/gates.tests.sh   # expected: all green (farm result below)
```

## Farm validation

(recorded at staging time — see the commit message for the exact tally)
