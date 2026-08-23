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
  (sha256 `e9dc024a7eabbbe10447aceaa08c61a65a4333d29c1bb19e2c19962d19b4be07`):
  the spec_revision EMISSION line in generate-evidence-bundle.sh renamed in a
  clone-based scratch tree -> gate suite exit 1 with three T-006 assertions
  failing inline (T-006.2b missing field, T-006.3b bundle check, T-006.3c not
  valid 64-char hex), plus three T-007a signature assertions that depend on the
  same field. 6 failing assertions total.
- `specs/risk-adaptive-layer/verification/T-006.green-compensating-20260823.log`
  (sha256 `ec184ea2afa988242ae70a020d69e7bcecf33bb944bf0125ac02ecd46ce77872`):
  pristine generator restored byte-for-byte -> suite exit 0, all
  21 distinct T-006 assertion ids green.

**Correction, 2026-08-23 (seq 845 quality gate, Critical):** the FIRST version
of these logs was invalid and has been superseded. The capture script replaced
the first textual occurrence of the quoted token, which is the HMAC signature
canonicalizer rather than the emission, so the run failed only T-007a.1d while
every T-006 assertion stayed green - contradicting the header the agent wrote
over it. The evaluator reproduced both mutations independently and rejected the
artifact as false provenance. The counts above (and the '17 assertions' figure
in the text superseded at seq 845) are from the corrected capture. Both logs
were RE-RUN again at seq 846 against the shipped suite: the earlier pair was
honest for its time but predated the checks[] telemetry pins, so it recorded
16 T-006 assertion ids where the suite now has 21.

Both logs carry honest headers stating they are 2026-08-23 compensating
captures, NOT the original red. Same method as the agci T-006 recapture
ratified in that task's cycle-2/3 gates.

## Scope

This waiver covers ONLY the missing historical red log. It does not waive
any other check for T-006; the quality gate still runs in full.
