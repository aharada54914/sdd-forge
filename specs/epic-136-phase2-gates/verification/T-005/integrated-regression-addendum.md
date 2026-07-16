# T-005 integrated-regression addendum

Date: 2026-07-15

## RED

The final 18-entry immutable manifest intentionally superseded T-001's former
three-entry manifest. The old T-001 Bash integrity check rejected the other 15
reviewed entries as `unexpected`, although the PowerShell cross-runtime corpus
was green (12/12). The old TEST-004 static parser also required a literal
`{64}` expression and rejected the equivalent generated invariant expression
`{$SudoSignatureHexLength}` twice.

## Correction

- `phase2-guard-tokenizer.tests.sh` now requires the original three T-001
  bindings while validating every ordered staged manifest entry for regular
  source and SHA-256 binding. Exact complete-inventory enforcement remains in
  TEST-013.
- `phase2-sudo-signature-static.tests.sh` accepts the generated-length form
  only when the guard sources it from `SUDO_SIGNATURE_HEX_LENGTH` and retains
  the fail-closed exact-64 guard. The literal exact-64 form remains accepted.

## GREEN

The integrated staged batch passed without protected live writes:

- TEST-001/002: PowerShell 12/12; Bash 19/19.
- TEST-003: PowerShell 7/7; TEST-004 static PS5.1 oracle passed.
- TEST-005/006: PowerShell 138/138.
- TEST-007/008/009: PowerShell 33/33; Bash 33/33.
- TEST-010/011/012/013: PowerShell 68/68; Bash 33/33.
- The staged generator `--check` and `check-workflow-state.ps1 --feature
  epic-136-phase2-gates` both passed.

The corrected test sources are intentionally agent-editable. The 18 protected
runtime, workflow, CI, canonical, generated, and runner candidates remain
staged only under `human-copy/`.
