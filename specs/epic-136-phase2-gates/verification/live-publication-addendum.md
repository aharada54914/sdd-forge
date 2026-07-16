# Phase 2 live-publication verification addendum

Date: 2026-07-15

## Human publication observation

After the human bootstrap procedure, every one of the 18 protected targets
listed in `human-copy/MANIFEST.sha256` was present in the live tree and its
SHA-256 matched the staged manifest entry: **18/18 matched**. This includes the
four guard runtimes, evidence-path validator, risk policy/checkers/skills,
canonical data, generator, all four native generated modules, CI workflow, and
the reviewed human-copy runner.

## Gate-time deterministic rerun

The following commands were run against the now-live guard paths (where a test
is intentionally staged-bound, its staged source was already bound to the
matching live byte by the 18/18 manifest observation):

- `phase2-guard-tokenizer.tests.ps1`: 12 passed, 0 failed.
- `phase2-guard-tokenizer.tests.sh`: 19 passed, 0 failed.
- `phase2-sudo-signature.tests.ps1`: 7 passed, 0 failed.
- `phase2-sudo-signature-static.tests.sh`: passed.
- `phase2-contract-path-helper.tests.ps1`: 138 passed, 0 failed.
- `phase2-risk-upgrade.tests.ps1`: 33 passed, 0 failed.
- `phase2-risk-upgrade.tests.sh`: 33 passed, 0 failed.
- `phase2-guard-invariants.tests.ps1`: 68 passed, 0 failed.
- `phase2-guard-invariants.tests.sh`: 33 passed, 0 failed.
- `python plugins/sdd-quality-loop/scripts/generate-guard-invariants.py --check`:
  passed without writing.
- `check-workflow-state.ps1 --feature epic-136-phase2-gates`:
  `workflow-state: ok`.

## Remaining critical-tier gates

This record does not constitute a quality-gate PASS or task completion. T-005
and T-006 still require fresh complete blind panel input, PASS verdicts from
Anthropic and a non-Anthropic vendor over the same digest, a signed evidence
bundle, a distinct second human approval, an accessible identity ledger for the
isolated evaluator, and the independent quality-gate decision.
