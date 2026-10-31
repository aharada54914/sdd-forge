# A7 attempt-16 recovery candidate — independent local code audit

Date: 2026-10-05

This is a non-formal, read-only candidate audit, not an SDD review, gate verdict,
approval, reviewer reservation, or authorization to apply the candidate. No
owner implementation, historical evidence, identity ledger, or task status was
changed during the audit. This note is non-frozen verification evidence.

## Audited snapshot and scope

- Candidate patch: `reports/verification/a7-attempt16-recovery-candidate-20261005/mechanical-integration.patch`
- Independently checked patch SHA-256: `e215fb743bcc85ecab6a1c3a872b5957b7da4d63d827ea045efba9153f6f4f8b`
- Author report: `reports/verification/a7-attempt16-candidate-validation-20261005.md`; its success counts were treated as claims, not independent execution evidence.
- Read the five-target patch, `failed-last-attempt.py.candidate`,
  `failed-last-attempt.fixture.py`, `full-caller.fixture.py`, existing
  `fresh-review-recovery.py`, and the relevant Bash contract-validation and
  Bash/PowerShell caller paths. Reviewer skill guided the scoped defect audit.
- Focus: preserve historical NEEDS_WORK, admit only a new attempt, bind inputs,
  historical reservations and failed turn, and retain Bash/PowerShell parity.

## Findings against the audited snapshot

### Major M1 — historical invocation manifest is not aligned with its precheck

Location: `reports/verification/a7-attempt16-recovery-candidate-20261005/failed-last-attempt.py.candidate:104-109`.

The new helper requires exactly one matching precheck item but does not require
the complete requirements, acceptance-tests, calibration, and optional
investigation input set. The previous partial-attempt path explicitly builds and
checks that exact historical set in
`plugins/sdd-review-loop/scripts/fresh-review-recovery.py:255-270`.

The canonical ledger validator at `fresh-review-recovery.py:115-129` establishes
that the supplied manifest equals the reserved manifest, not that this manifest
is the correct input set for the precheck. The completed-round validator checks
contract/output manifests (`spec-review-precheck.sh:293-343`) but does not read
the invocation manifest. The failed round has no completed reviewer contract to
provide any additional check. Thus an originally reserved but incomplete or
misaligned manifest can satisfy the new recovery checks. This is not a claim
that changing an existing invocation alone bypasses its ledger hash binding.

Independent executable check: loaded the actual historical-ledger validator
without running its CLI, constructed a synthetic canonical two-record chain and
a precheck-only reserved manifest entirely in memory, evaluated the new helper's
manifest predicate, and called that actual ledger validator. Both accepted.
Observed output:

```text
ACCEPT: new helper manifest predicate + actual historical ledger validator accept precheck-only reserved manifest (requirements/AC/calibration absent). Synthetic in-memory data only; no file or ledger writes.
```

This was a focused predicate/ledger unit reproduction, not a full end-to-end
precheck run. No real reservation was created or resealed.

Minimal correction: compare each invocation with the exact manifest derived
from that round's historical precheck, adding the integrated summary for reviewer
B. Do not compare old historical inputs against revised current documents.
Add a negative case with a canonical ledger-bound but incomplete/mismatched
manifest so ledger mismatch cannot mask this semantic check.

### Minor m1 — unfinished-turn fixture fails at the hash pin instead

Location: `reports/verification/a7-attempt16-recovery-candidate-20261005/failed-last-attempt.fixture.py:87-94`.

The `unfinished` mutation removes end-turn events but does not update
`failed_turn.transcript_sha256`. The helper checks that hash before checking
completion (`failed-last-attempt.py.candidate:157-170`), so the fixture can pass
without exercising the missing-end-turn rejection. This follows directly from
the fixture mutation and validation order; the fixture was not independently
rerun during this audit.

Minimal correction: repin the mutated transcript inside this isolated negative
fixture and check that rejection identifies the incomplete first turn.

## Confirmed boundaries and limitations

- Historical complete rounds are required to remain NEEDS_WORK; the helper does
  not rewrite them or manufacture a replacement verdict.
- The exception targets the immediately preceding attempt, with exact round
  inventory and failed final round 2 or 3; the caller retains new-attempt rules.
- Both patched callers invoke their existing complete-round validator for each
  returned historical completed round.
- Guard-list absence was not counted as a new regression: the existing recovery
  helper also lacked an explicit entry. No broader guard expansion was required
  by this audit.
- Independent execution was limited to patch SHA verification and the in-memory
  reproduction described above. The author's 56 existing, 12 new helper, and
  four caller checks were not independently rerun here.
- Findings describe the pinned snapshot only. Corrections require a separate
  follow-up check; this note does not imply acceptance of later candidate bytes.

Summary: Critical 0, Major 1, Minor 1. Non-formal findings only; no SDD gate
status or formal verdict is asserted.
