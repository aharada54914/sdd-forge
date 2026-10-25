# ADR 0039: Verification measurement is passive observation joined by reference

Status: Proposed
Date: 2026-10-22
Normative design: specs/verification-measurement/design.md. Drafted under the user's 2026-10-22 instruction; specification and implementation-policy review have not run.

## Context

Issue #614 requires separating where verification time goes before any check is shortened. Execution is already owned by `tests/verification.py` (suites), `plugins/sdd-lite/lib/run-lite-gate.py` (Lite checks) and the quality-gate callers (Full gates); model launch belongs to the managed entry and review launch validators. `emit-run-record` aggregates artifacts after the fact, and `validate-nontty-spec-launch.py` rewrites piped run records to v2, so a new run-record version would be silently downgraded.

## Decision

Add one versioned sidecar contract, `sdd-run-measurement/v1`, written by a standard-library helper that never starts a process. Existing owners call it at their real process boundary behind an opt-in flag; shell callers use its CLI. Records are immutable per span start/finish and milestone; durations come only from monotonic differences in one verified clock domain. Measurements join run records, receipts and Lite outputs only by `{kind, path, sha256, target_run_id}` references that the owner attaches to its session finish after publishing those artifacts in the same execution; the artifacts themselves are never changed. Measurement never decides a verdict, approval, required set, cache reuse or review identity. Once execution starts, a measurement failure never changes an owner's exit code; the one exception is an invalid measurement configuration detected before execution, which exits 2 with nothing executed. Cross-attempt (resume) analysis is a pure reducer over linked measurement directories; judgment validity, budget and evidence status remain with #600/#622.

## Alternatives

A v3 live run-record conflicts with v1 no-flag goldens and the v2 coercion in review launch. A new runner or event database would duplicate existing execution ownership and create a second workflow state. Parsing agent prose or file timestamps for elapsed time cannot distinguish machine, waiting and active human time.

## Consequences

Owners gain small optional code paths and the helper must be locatable as a sibling plugin from Lite. Cross-process timing on hosts without a verified boot identifier is reported as null until OQ-1 is resolved. UTC is correlation-only; no duration or estimate is derived from it. Review-preparation, model and human phases have no automated owner in #614 and stay `not-observed` unless recorded through the helper CLI. Benchmarks are manual artifacts, not CI thresholds; optimization work (#615) must compare under the frozen manifest.
