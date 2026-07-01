# Independent Implementation Review: T-002

Reviewer: T-002-independent-reviewer

Round: 1

Result: FAIL

## Findings

1. Critical: terminal resume accepts an arbitrary
   `blocked_task_contract_sha256` because neither validator binds it to trusted
   blocked-state evidence.
2. Major: a scalar candidate JSON document is rejected by Bash but accepted by
   PowerShell.
3. Major: fractional-second approval timestamps are rejected by Bash but
   normalized and accepted by PowerShell.
4. Major: escalation output omits prior tier, next tier, failure class, attempt
   number, and reason.
5. Major: red/green evidence does not explicitly identify the committed failing
   test or directly exercise deterministic-runtime-unavailable behavior.

## Reproduction Summary

- Forged all-`f` blocked hash: both resume validators returned
  `TERMINAL_RESUME_OK`.
- Scalar candidate root: Bash rejected it; PowerShell selected a model.
- Fractional timestamp: Bash rejected it; PowerShell accepted it.
- Repeated-failure selector output lacked the REQ-004 audit fields.

## Required Resolution

Bind resume to a strict persisted blocked-state record, align Bash and
PowerShell parsing, emit the complete escalation record, and strengthen the
TDD/runtime-unavailable fixtures before requesting a new independent review.
