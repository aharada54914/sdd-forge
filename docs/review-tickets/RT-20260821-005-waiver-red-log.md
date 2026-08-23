# Waiver Record: RT-20260821-005 item 3 — ral T-006 missing original red log

- Date: 2026-08-23
- Decision maker: repository maintainer (aharada54914), via session directive
- Verbatim directive: 「標準判断についても承認する」 — approving the recorded
  recommendation for this item: "waiver + 補償統制として現行差分の捕獲"
  (the recommendation list is preserved in the session transcript of
  2026-08-21/23 and summarized in docs/review-tickets/RT-20260821-STATUS.md)
- Recorded by: the session agent, from the maintainer's directive. The
  DECISION is the maintainer's; only the transcription is agent-authored.

## What is waived

risk-adaptive-layer T-006 (Risk: high, Required Workflow: tdd) has no
preserved original red log from its 2026-06 implementation. The true
historical red state is unreconstructable 14 months later; any backfilled
"original" log would be provenance fabrication. The tdd red-evidence
requirement for the ORIGINAL implementation increment is waived.

## Compensating control (captured 2026-08-23, this branch)

A present-day differential proving the delivered enforcement is real:

- `specs/risk-adaptive-layer/verification/T-006.red-compensating-20260823.log`
  (sha256 `ee6e3c6d49ca883bb4dbd33043905bec5e4e0faa0eceaf7e218bf084a3541355`):
  the spec_revision emission in generate-evidence-bundle.sh disabled by a
  one-token mutation in a clone-based scratch tree -> gate suite exit 1,
  T-006.2b fails closed.
- `specs/risk-adaptive-layer/verification/T-006.green-compensating-20260823.log`
  (sha256 `cdd9bc44ef9877b002db8124722317463cfaec7af19bc880c6e65824157cf688`):
  pristine generator restored byte-for-byte -> suite exit 0, all 17 T-006
  assertions green.

Both logs carry honest headers stating they are 2026-08-23 compensating
captures, NOT the original red. Same method as the agci T-006 recapture
ratified in that task's cycle-2/3 gates.

## Scope

This waiver covers ONLY the missing historical red log. It does not waive
any other check for T-006; the quality gate still runs in full.
