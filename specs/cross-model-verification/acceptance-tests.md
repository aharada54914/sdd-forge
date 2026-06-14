# Acceptance Tests: cross-model-verification

Every AC links a REQ to a TEST id, a test type, and a concrete target.
Same format as `specs/risk-adaptive-layer/acceptance-tests.md` (REQ-004 standard).

| AC | Requirement | Test ID | Test Type | Test Target | Status |
|---|---|---|---|---|---|
| AC-001 | REQ-001 | TEST-001 | gate (unit) | `tests/cross-model.tests.{sh,ps1}` :: critical contract `cross_model:required` missing passing `cross-model-verification` ⇒ fail; present+passing ⇒ pass | Planned |
| AC-002 | REQ-002 | TEST-002 | gate (unit) | check-cross-model: verdict set anthropic-only ⇒ fail (diversity); ≥1 non-anthropic + ≥2 distinct ⇒ pass (both runtimes) | Planned |
| AC-003 | REQ-003 | TEST-003 | gate (unit) | check-cross-model: verdict missing `blind:true` or non-64-hex `input_digest` ⇒ exit 2; schema-valid ⇒ proceeds | Planned |
| AC-004 | REQ-004 | TEST-004 | gate (unit) | check-cross-model: any panelist NEEDS_WORK or Critical ⇒ fail; all PASS ⇒ pass; `--evaluator` divergence ⇒ result NEEDS_HUMAN + requires_human_decision | Planned |
| AC-005 | REQ-005 | TEST-005 | gate (unit) | prepare-panelist-input: no consent (no flag, no valid sudo) ⇒ fail closed; with consent ⇒ runs and planted secret fixture stripped from output | Planned |
| AC-006 | REQ-006 | TEST-006 | gate (integration) | aggregate JSON appears in evidence bundle `artifacts[]` with matching sha256; `review_verdict` byte-unchanged | Planned |
| AC-007 | REQ-007 | TEST-007 | config (lint) | gate-layer CI job runs check-cross-model on fixtures offline; no CI job invokes run-panelist-* / prepare-panelist-input | Planned |
| AC-008 | REQ-008 | TEST-008 | parity + dogfood | `.sh`/`.ps1` parity (crlf-parity + scenario); `cross-model-verification-policy.md` enumerates selection/aggregation/conflict/consent; self-evidence passes | Planned |
| AC-009 | (all) | TEST-009 | regression | every pre-feature fixture in gates/guards/scripts/eval suites still passes unchanged (no gate-engine regression from T-003 wiring) | Planned |
