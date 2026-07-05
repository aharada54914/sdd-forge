# Independent Implementation Review: T-006 (Review 2)

## Review Identity

- Task: `T-006`
- Feature: `agent-cost-context-isolation`
- Run ID: `agent-cost-context-isolation-T-006-review-run-02`
- Session ID: `agent-cost-context-isolation-T-006-review-session-02`
- Agent Instance ID: `agent-cost-context-isolation-T-006-review-agent-02`
- Model Tier: `standard`
- Provider/Model: `openai/gpt-5.1-codex`
- Isolation Mode: `fresh-agent`
- Fallback Mode: `none`

## Manifest Verification

PASS. Before substantive review, I read
`reports/implementation/agent-cost-context-isolation/manifests/T-006-review-2.json`
and verified:

- the task, feature, run, session, agent-instance, model-tier,
  provider/model, isolation, and fallback fields exactly match this review;
- the sole allowed output is
  `reports/implementation/agent-cost-context-isolation/T-006-review-2.md`;
- all 14 allowed inputs exist and their SHA-256 values exactly match the
  manifest.

No unlisted project input was opened for review.

## Scope

Reviewed REQ-008, REQ-009, AC-005, TEST-004, the T-006 Done When contract,
the implementation-report template and validator, retrospective skill and
template, focused tests, green log, and implementation report.

## Commands And Results

The following checks passed:

```text
bash -n plugins/sdd-implementation/scripts/validate-implementation-report.sh
bash -n tests/turn-first-workflow.tests.sh
bash -n tests/retrospective-loop.tests.sh
bash tests/turn-first-workflow.tests.sh
bash tests/retrospective-loop.tests.sh
bash plugins/sdd-implementation/scripts/validate-implementation-report.sh reports/implementation/agent-cost-context-isolation/T-006.md
```

Observed focused-suite output:

```text
ok: turn-first orchestration enforces three-task identity and fallback fixtures
ok: implementation report v2 enforces complete file-backed handoff fields with legacy compatibility
ok: retrospective loop prompts and templates are synchronized
IMPLEMENTATION_REPORT_OK
```

Temporary direct adversarial fixtures produced:

```text
invalid-result                exit=0  IMPLEMENTATION_REPORT_OK
invalid-status                exit=0  IMPLEMENTATION_REPORT_OK
traversal-evidence-path       exit=0  IMPLEMENTATION_REPORT_OK
drive-qualified-output-path   exit=0  IMPLEMENTATION_REPORT_OK
arbitrary-fallback-reason     exit=0  IMPLEMENTATION_REPORT_OK
zero-attempt-count            exit=1  IMPLEMENTATION_REPORT_FIELD: invalid Task Attempt Count
invalid-output-hash           exit=1  IMPLEMENTATION_REPORT_FIELD: malformed Output Paths And Hashes entry
empty-schema-downgrade        exit=0  IMPLEMENTATION_REPORT_LEGACY_OK
```

The empty-schema fixture was byte-identical before and after validation, so
legacy-mode validation itself is read-only. All temporary fixtures were
removed.

## Findings

### Major — F-001: A malformed or removed v2 schema marker downgrades a current report to unchecked legacy mode

`validate-implementation-report.sh:22-25` classifies every document that does
not match the exact non-empty `Report Schema: <value>` regular expression as
legacy and returns success before checking any v2 field. A complete v2 report
whose schema value was emptied was accepted as
`IMPLEMENTATION_REPORT_LEGACY_OK`; removing the schema line has the same
effect. This allows all required handoff validation to be bypassed by deleting
or damaging one line.

Legacy reports must remain accepted without mutation or fabricated values, but
documents containing v2 headings/labels or a malformed `Report Schema:` marker
must fail closed. Tests currently cover only a genuine pre-schema report, not
the downgrade boundary.

### Major — F-002: Required result, status, path, and fallback semantics are presence-only or incomplete

The validator calls `label()` for test fields at
`validate-implementation-report.sh:96-97`, but it does not validate the result
domain or canonicalize the evidence path. It also rejects only `Done` for
Current Status at lines 161-165, accepts drive-qualified output paths because
lines 85-93 do not reject a drive prefix, and accepts any non-`None` fallback
reason at lines 149-153.

Direct fixtures proved that all of these invalid records pass:

- `Test Result: DEFINITELY-NOT-A-RESULT`;
- `Current Status: BANANA`;
- `Test Evidence Path: ../../outside.log`;
- output path `C:/outside.md`;
- `same-session-file-reload` with
  `Fallback Reason: operator-prefers-one-session` and a syntactically valid
  hash.

Consequently, a v2 report can claim an invalid lifecycle state, carry
non-result test evidence, point outside the repository, or record fallback
evidence inconsistent with the host-capability-only exception. This does not
satisfy the requested fail-closed validation of invalid status/result/path and
inconsistent fallback evidence. Add closed status/result rules, canonical
repository-relative path validation for every path, the documented fallback
reason constraint, and adversarial fixtures for each boundary.

The validator does correctly reject empty/missing labels, malformed output
hashes, zero attempt counts, invalid escalation transitions/classes/counts,
partial escalation records, fresh-agent fallback evidence, and same-session
fallback without a lowercase 64-hex evidence hash.

### Major — F-003: Retrospective metrics are named but not deterministically derivable

The retrospective skill at lines 37-55 gives prose labels and broad counting
directions, but does not define deterministic selection and de-duplication:

- “latest” current-schema implementation report has no ordering key or
  tie-break;
- review rounds have no authoritative artifact pattern, round identity, or
  duplicate-handling rule;
- model escalation transitions have no task/run identity or duplicate rule
  when the same transition appears in implementation and review evidence;
- quality-gate report-to-task association is not specified.

`tests/retrospective-loop.tests.sh:33-41` only greps for those phrases. It does
not build multi-attempt/multi-review/multi-gate fixtures and assert exact
derived counts. Different readers can therefore produce different task
attempt, review-round, gate-run, and escalation totals from the same files.
The template exposes the required columns, but REQ-009's metrics are not yet
reliably measurable. Define authoritative artifact matching, ordering and
de-duplication keys (or a checked-in collector), and add exact-count fixtures.

## Severity Summary

- Critical: 0
- Major: 3
- Minor: 0

## Residual Risks

- Genuine schema-less historical reports are accepted read-only and
  byte-preserved, as required, but the current legacy/v2 discriminator is not
  safe.
- The implementation report validator checks output-hash syntax, not whether
  each recorded hash currently matches the named output. If content binding is
  expected at this gate, that behavior needs an explicit contract and test.
- The focused tests are green, but their largely structural assertions do not
  cover the semantic and deterministic-counting failures above.

## Verdict

**FAIL**

PASS requires no Critical or Major findings. T-006 must not be marked Done from
this review.
