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

- `specs/risk-adaptive-layer/verification/T-006.red-compensating-20260826.log`
  (sha256 `9083138ace7387bc5c08a427796b31b1179725c82e55c39d9c88fa6f8736f242`):
  the spec_revision EMISSION line in generate-evidence-bundle.sh renamed in a
  clone-based scratch tree -> gate suite exit 1 with three T-006 assertions
  failing inline (T-006.2b missing field, T-006.3b bundle check, T-006.3c not
  valid 64-char hex), plus three T-007a signature assertions that depend on the
  same field. 6 failing assertions total.
- `specs/risk-adaptive-layer/verification/T-006.green-compensating-20260826.log`
  (sha256 `4952d8a2b0fa44670dddb7b3b176e1cb77646a94fd3d1cd0c1be285f67fdfe8a`):
  pristine generator restored byte-for-byte -> suite exit 0, all
  26 distinct T-006 assertion ids green (PASS 161, FAIL 0).

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
16 T-006 assertion ids where the suite then had 21.

**Correction, 2026-08-26 (seq 854 quality gate, two Majors):** the binding
above was BROKEN and is repaired here. Two distinct defects, with distinct
fixes:

1. *Stale tallies (third recurrence).* The 2026-08-23 pair predated
   `T-006.8a`-`T-006.8e`, added to the gate suite by the human apply commit
   `5a60b0f8`. Freshly measured in a `git clone --no-hardlinks` scratch tree:
   pristine = PASS 161 / FAIL 0 over **26** distinct T-006 ids; mutated =
   PASS 155 / FAIL 6, of which 3 are T-006 (`T-006.2b`, `T-006.3b`,
   `T-006.3c`) and 3 are the dependent T-007a signature assertions.
2. *Broken hash binding.* The declared digests were the state at commit
   `6a6566ab`, superseded by `a1052401`, which edited the log bodies and this
   waiver's prose in one change without re-hashing. Because this waiver is the
   sole authority substituting for T-006's missing original red log, that
   binding IS the compensating control, and it bound nothing.

Fixed by capturing to NEW filenames (`...-20260826.log`) rather than
overwriting the 2026-08-23 pair in place. Overwriting is what let the content
drift out from under the digests twice: the seq 845/846/849/854 review-context
manifests hash-pin the 2026-08-23 bytes, and an in-place re-capture silently
falsifies all four. The old pair is retained unmodified so those historical
manifests stay true; the live binding points at the new pair.

Both logs carry honest headers stating they are 2026-08-23 compensating
captures, NOT the original red. Same method as the agci T-006 recapture
ratified in that task's cycle-2/3 gates.

## Scope

This waiver covers ONLY the missing historical red log. It does not waive
any other check for T-006; the quality gate still runs in full.
