# RT004 workflow opening ADR regression — 2026-09-09

Scope: RT-20260908-004 approved ADR contract and downstream-consumer tests.
This is an actual current-validator RED result, not candidate execution or a
quality-gate verdict. No protected implementation, historical evidence,
reservation, task status, or PR was modified by this test run.

## Reproduction

Command: `rtk proxy bash tests/impl-review-adr-inputs.tests.sh --workflow-only`

The fixture copies only workflow-state-integrity specification/review data
and four reference documents to a private temporary directory. The registry
is explicitly full-profile. It uses the same next-round fixture arrangement
as tests/workflow-state.tests.sh:1055: change the isolated latest impl
integrated verdict to NEEDS_WORK, then request `--opening impl:1:3`.
Original repository validators are invoked using `--registry`; no copied,
extracted, or candidate validator is executed. The original evidence is not
rewritten. This legacy compatibility fixture is not claimed to be a fully
consistent new ADR-bound failed review.

The legacy positive control must succeed for each runtime before any negative
case may count as passing. Negatives require exit 1, a stage-provenance
diagnostic and an ADR-specific diagnostic; unrelated failure is not success.
Tests also run by default with the existing admission suite; workflow-only
avoids repeating unchanged admission tests during this focused investigation.

Final test SHA-256:
`e5ce411d69daa75b55790a6280982e17fdab483b2c74604dd02d8bdacc48a008`

Actual Bash validator SHA-256:
`15a4ef0a72c8be78c40b38e692ee7a46d8664d825e61ab99915086dae0f02d1e`

Actual PowerShell validator SHA-256:
`7a4663e154e7877362d43916087986849dd7625121d5c058332d3e27eb7b2644`

## Complete focused output

```text
ok: workflow history bash legacy
not ok: workflow history bash null-set (exit=0 expected=1 baseline=true)
workflow-state: ok
not ok: workflow history bash object-set (exit=0 expected=1 baseline=true)
workflow-state: ok
not ok: workflow history bash missing-precheck (exit=0 expected=1 baseline=true)
workflow-state: ok
ok: workflow history pwsh legacy
not ok: workflow history pwsh null-set (exit=0 expected=1 baseline=true)
workflow-state: ok
not ok: workflow history pwsh object-set (exit=0 expected=1 baseline=true)
workflow-state: ok
not ok: workflow history pwsh missing-precheck (exit=0 expected=1 baseline=true)
workflow-state: ok
ADR workflow history: passed=2 failed=6
```

Exit: 1. PowerShell runs on macOS, not native Windows. Bash syntax and
repository diff whitespace checks passed. Full admission/CI was not rerun.

## Review and next action

Primary test review: no Critical findings; normal legacy acceptance controls
both runtimes and rejection requires explicit diagnostics. This is not an
independent quality gate. Coverage remains deliberately partial: no valid
extended historical round, complete missing/reordered reviewer bindings,
identity/severity/summary isolation, current-PASS ADR integrity, or Windows
behavior is proven here.

Current Bash check-workflow-state.sh:826 and PowerShell
check-workflow-state.ps1:1060 return for a verified opening before validating
the failed round's contract and reviewer bindings. Loading JSON beforehand
does not validate them. An ADR extension cannot rely on the later PASS-only
checks: validation of its complete internal historical binding must run
before this return, while preserving no-extension legacy semantics and the
existing limited downstream freshness tolerance. Historical ADR bytes must
not be compared to today's ADR bytes.

Continue the approved patch-data implementation for BOTH workflow consumers,
including a PS5.1-compatible implementation, then broaden actual regression
coverage and obtain independent review before human application of protected
changes. Existing partial patches are not ready for application or merge.

GitHub observation this turn: 7 open PRs, unchanged heads for #401, #400,
#394, #390, #381, #371 and #245. #245 reports DIRTY; the others are draft,
BEHIND or BLOCKED. This observation does not prove required CI success.
