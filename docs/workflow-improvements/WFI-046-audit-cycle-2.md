# WFI Audit Report — Cycle 2

## Header

| Field | Value |
|---|---|
| WFI-ID | WFI-046 |
| Category | plugin-improvement |
| Cycle | 2 of 2 |
| Auditor Agent | wfi-auditor-b (fresh isolated agent; Cycle-1 raw output not read) |
| Verdict | BLOCKED |
| Critical Findings | 2 |
| Major Findings | 6 |
| Minor Findings (Advisory) | 3 |
| Generated | 2026-08-23T15:20:00Z |

## Verdict: BLOCKED

**The proposed change has provably zero behaviour impact. It cannot fix the bypass it targets.**

_shell_targets_protected_gate_file has a second early return immediately after the short-circuit: `if not has_write: return False` (py:1464, js:618, ps1:968). The short-circuit's third clause IS `not has_write`, so its guarded set is a strict subset — a disqualifier added there alone changes no verdict. Verified three ways: patched scratch copies of both the .py and .js leave both bypass probes at exit 0; deleting the branch outright produces 0 verdict differences over a 67-command corpus. The Expected Effect's central claim (2 to 0) is therefore false as specified, and because the metric is the return value of the very function being changed, nothing in the plan would have caught it. Measurement also falsifies plan step 2: under the corrected placement process substitution flips to deny, but bare & and physical newline stay allowed, because the fail-closed analysis triggers only on write-target tokens. Additionally: & over-triggers on 5 legitimate test invocations; all four target files are themselves write-protected so both apply and revert need the human-copy route; the sibling change touched 14 files not 4; and the drift invariant is untestable in a black-box exit-code harness because the approval gate masks the write-protection verdict.

## Failed Checks

- IMPACT-PROPORTIONATE
- META-CHANGE-ANTI-GOODHART
- VERIFICATION-COMPLETE
- SCOPE-PROPORTIONAL
- RISK-IDENTIFIED
- ROLLBACK-VIABLE
- BLAST-RADIUS-BOUNDED
- DRIFT-INVARIANT-TESTABLE
- EFFECT-CONSISTENT-WITH-EVIDENCE
- ALTERNATIVES-CONSIDERED
- CHANGE-INSTRUCTION-APPLYABLE

## Disposition

All Cycle-2 revisions were applied to the WFI by the orchestrator, which is the only
entity that writes WFI content during an audit. Where a revision reversed a claim the
WFI previously made, the withdrawn claim is recorded in the document rather than
deleted, so the distinction that motivated the correction stays visible.
