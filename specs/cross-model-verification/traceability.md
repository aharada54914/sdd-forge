# Traceability: cross-model-verification

Human-readable REQ → AC → TEST → Task → Evidence map. The machine-readable
`traceability.json` (validated by `check-traceability.{sh,ps1}`) is generated in
T-006 (dogfood). Evidence paths are `Planned` until implementation.

| REQ | Summary | AC | TEST | Task(s) | Evidence (planned) |
|---|---|---|---|---|---|
| REQ-001 | check-cross-model gate; critical required (waiver-able), high opt-in | AC-001 | TEST-001 | T-002, T-003 | verification/T-003.red.log, T-003.green.log |
| REQ-002 | Diversity: ≥1 non-Anthropic vendor (≥2 distinct) | AC-002 | TEST-002 | T-002, T-005 | verification/T-002.red.log, T-002.green.log |
| REQ-003 | Blind parallel panelists; verdict schema (blind, input_digest) | AC-003 | TEST-003 | T-002, T-005 | verification/T-002.green.log |
| REQ-004 | Consensus: unanimous PASS / no Critical; divergence ⇒ human | AC-004 | TEST-004 | T-002 | verification/T-002.green.log |
| REQ-005 | Consent-gated + sanitized external send (fail-closed) | AC-005 | TEST-005 | T-004 | verification/T-004.red.log, T-004.green.log |
| REQ-006 | Aggregate into evidence bundle artifacts[]; review_verdict untouched | AC-006 | TEST-006 | T-003 | verification/T-006.green.log |
| REQ-007 | Gate CI-testable offline; collection never auto-run in CI | AC-007 | TEST-007 | T-003 | verification/T-003.config.log |
| REQ-008 | Parity + policy doc + dogfood self-evidence | AC-008 | TEST-008 | T-001, T-006 | verification/T-006.gates.log |
| (all) | No regression of existing gates | AC-009 | TEST-009 | T-003 | verification/T-003.gates.log |

## Notes
- Source-of-truth chain: `requirements.md` (REQ) → `acceptance-tests.md`
  (AC/TEST) → `tasks.md` (T) → `verification/` (evidence) → `traceability.json`.
- All tasks are `Approval: Draft` pending human approval before implementation
  reaches quality-gate / Done.
