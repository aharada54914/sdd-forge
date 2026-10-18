# Exact-union counterpart completion (before generator edit)

The original input snapshot already includes the generator bytes. The supplemental
manifest adds its necessary output path; the original manifest is preserved.
`generate-guard-invariants.py:304-316` derives an exact ordered union from
BASELINE_SUFFIXES, PHASE2_TARGETS and EPIC_A1_TARGETS. Adding paths only to JSON
fails with `protected_gate_suffixes must be the exact baseline/inventory union`;
see initial-generate.log and initial invariant checks. This is an executed
field/counterpart mismatch, not guard execution proof. The separate committed
Red remains the actual consumer proof.

Complete preflight row: persisted protected_gate_suffixes ↔ generator
BASELINE_SUFFIXES exact ordered union ↔ executed JSON-only generation failure.
Fix only the five members in the existing baseline and corresponding JSON
position. Preserve every old member and all validation logic. No new inventory,
exemption, schema, scanner behavior or runtime parser change.
