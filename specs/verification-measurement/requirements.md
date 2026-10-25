# Requirements: verification-measurement

Spec-Review-Status: Pending

## Overview

Source issue: [#614](https://github.com/aharada54914/sdd-forge/issues/614) (parent #613, P0, no dependencies), including its 2026-10-19 personal-factory appendix. All findings this specification relies on are cited in place below (file:line at the investigation HEAD); no external or machine-local document is normative or required. Investigation HEAD: `07ed2e984ec58160892e765d7c437c47d5daf332`.

Add the smallest deterministic measurement foundation that separates where verification time actually goes (gates, commands, review preparation, model execution, human waiting and active human review) before any quality check is shortened for speed. Measurement observes existing execution owners; it never executes, decides, approves, caches or changes a gate result.

Authorization: the 2026-10-22 user instruction authorizes this feature's work generally, specification and implementation alike, superseding the issue's original "registration only" limitation. That authorization does not replace the workflow: no independent review, task approval or implementation has occurred, every status field below remains Pending/Draft, and implementation starts only after the normal spec, impl and task review gates and a human task approval.

## Target Users

Maintainers deciding which verification work to optimize (#613/#615), the factory planning work (#621–#623) that consumes lead-time measurements, and the #600 model evaluation that consumes the same run references.

## Problems

- Individual gates take milliseconds to tens of milliseconds, while the whole-repository `check-workflow-state.sh` (invoked without `--feature` by `plugins/sdd-quality-loop/skills/quality-gate/SKILL.md:99-100`) dominated a preliminary measurement. The share of CI, evidence transcription, independent review and human waiting in the full cycle is unmeasured.
- `plugins/sdd-quality-loop/scripts/emit-run-record.sh:13-19` aggregates repository artifacts after execution into counts; it records no live timing.
- `tests/verification.py:138-165` records per-suite `seconds` from `time.monotonic()` (lines 149, 160) and exit codes in `verification-receipt/v1`, but has no feature/task, attempt, rerun reason or input identity.
- `plugins/sdd-lite/lib/run-lite-gate.py:142-183` records `duration_ms` (line 171) and `timed_out` per Lite check, but clips output (`_clip`, lines 134-139) so its stored streams are not a complete raw log.
- Existing owner outputs are written only after execution ends: `tests/verification.py:222-226` writes or prints the receipt after `execute` returns, and `run-lite-gate.py:265-286` adds `source`, `recorded_at` (UTC, every invocation, line 278) and then writes `--output` and prints the same JSON. A per-check record cannot hash these outputs; a join must be attached after publication. Their volatile fields (`seconds`, `duration_ms`, `recorded_at`, receipt `revision`/`clean_*`/`catalog_sha256` at `tests/verification.py:140-142,164`, Lite `source` at `run-lite-gate.py:263-277`) depend on the clock and the checkout.
- Existing gate suites invoke gate scripts directly inside their own helpers and often discard per-case output (`tests/gates.tests.sh:25-53`); wrapping a whole suite with measurement does not observe individual gate cases.
- `plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py:2213` forcibly rewrites any piped run record to `sdd-run-record/v2`; a new run-record version upstream of it would be silently downgraded. Measurement therefore cannot be added by bumping the run-record version.

## Investigation Traceability

INV-001 run-record aggregate (`emit-run-record.sh:13-30`, v1 no-flag goldens `tests/fixtures/emit-run-record/v1-no-flag.{sh,ps1}.golden.json`) → REQ-001/REQ-009. INV-002 suite execution owner (`tests/verification.py:138-180`) → REQ-007. INV-003 Lite execution owner (`run-lite-gate.py:142-183`) → REQ-007. INV-004 run-record v2 coercion (`validate-nontty-spec-launch.py:2213`) → REQ-001. INV-005 whole-repository workflow-state call (`quality-gate/SKILL.md:99-100`) → REQ-008. These are observations at the investigation HEAD; re-verify each cited line at spec review and again before the owning task edits it (shared, git-tracked state — WFI-013).

## Goals

| ID | Requirement |
|---|---|
| REQ-001 | **Separate versioned sidecar.** Record measurements in a new `sdd-run-measurement/v1` contract stored beside, never inside, existing artifacts. Join to run records, verification receipts and Lite results only by reference: a `{kind, path, sha256, target_run_id}` artifact reference attached to the session span's finish record after the owner has published that artifact in the same execution; the referenced artifacts are never modified or retrofitted. Existing `sdd-run-record/v1`/`v2` bytes, flags and goldens are unchanged. A measurement's `run_id` is never silently equated with a different emitter's run identity. |
| REQ-002 | **True monotonic durations.** Every duration comes from `time.monotonic_ns()` differences inside one verified clock domain. UTC timestamps are correlation-only and never compute any duration, lead time or estimate. A negative difference or a clock-domain mismatch yields `null` with a reason, never clamping or absolute value. A UTC step during a span does not change its monotonic duration and is reported as a diagnostic. |
| REQ-003 | **Phase separation.** Distinguish phases `session`, `gate`, `command`, `review-preparation`, `model`, `human-wait` and `human-active`. Report session wall elapsed, machine elapsed (interval union of gate/command/review-preparation/model), machine effort (sum over outermost machine spans, so a nested wrapper and its children are never double-counted), per-phase union and sum, human-wait elapsed and explicitly measured human-active time as separate values. Parallel child sums are labelled effort, never elapsed. Human-wait and human-active are never summed as a partition. A phase with no observed span is `null` with reason `not-observed`, never 0; 0 means observed spans of zero length. |
| REQ-004 | **All outcomes observable.** Terminal outcomes are `success`, `failure`, `timeout`, `interrupted`, `rejected`, `abandoned`, `undecided`, declared by the execution owner. A start without a finish remains visible as `open` (right-censored at `as_of`), never as success. Exit code 124 alone is not a timeout. Every started span stays in the denominator. |
| REQ-005 | **Identity and reproduction.** Record measurement id, run id, optional parent run id, scope (`all`/`feature`), feature, task, attempt, rerun reason (`initial`/`fix`/`resume`/`repeat`/`other` with bounded detail for `other`), scenario id, trial id, HEAD, dirty flag, OS, architecture, runtime/tool versions, target count, input file hashes and log references. Per-command invocation counts are derived from unique spans and count launch attempts; a suite skipped for a missing runtime has no span, and a launch whose process failed to start is a `failure` span with null exit code. Resumed or repeated attempts are separate measurements linked by `scenario_id`, `trial_id`, `attempt` and `parent_run_id`; none overwrites another. A retried helper call with identical caller-supplied fields returns the persisted original record without re-timestamping. |
| REQ-006 | **No secret collection.** Never capture raw environment variables, arbitrary argv, prompts, credentials, private identity-ledger content or machine identifiers beyond the allowlisted fields. Free text is bounded and rejects control characters. Missing token usage or cost is `null` with a reason; never zero or estimated. |
| REQ-007 | **Opt-in reuse of existing owners.** Suite and Lite timing are captured by the existing owners (`tests/verification.py`, `run-lite-gate.py`) behind one new optional flag each. Shell/PowerShell callers use the same helper's CLI. No new executor, runner, scheduler, cache, daemon, database, approval field or authority is introduced. Without the flag, stdout, stderr, exit codes and output files are byte-identical to the pre-change behavior under identical controlled repository/catalog state, apart from the named pre-existing volatile fields (`seconds`, `duration_ms`, `recorded_at`), whose format is still asserted. The only exit-code effect of the flag is a pre-execution configuration error (exit 2, nothing executed); after execution starts, measurement failures never change the owner's exit code. |
| REQ-008 | **Behavior equivalence and overhead.** With and without measurement, gate verdicts, exit codes, stable diagnostics, required check sets and review-independence checks are identical per individual case on existing normal, invalid, tampered and boundary fixtures, compared case by case (not only by a suite's overall exit). The measurement overhead is measured by an outer timer on paired runs and reported, never asserted as a CI threshold. |
| REQ-009 | **Fixed benchmark.** A frozen manifest fixes scenarios (scope one-feature/all × lifecycle initial/after-repair/resume × cold/warm) with executable setup and command recipes and expected outcomes per lifecycle state, input hashes, trial count (5) and statistics (n, attempts_started, successful, failed, censored, median, min, max, MAD over successful samples). Every trial sample stays in `n` and every started attempt in `attempts_started` (a resume trial has two attempts). A comparison fingerprint separates fixed fixture inputs from the implementation revision being compared; the code under test is selected explicitly, separately from the pinned fixture baseline, and the recorded implementation revision is the code actually executed; results with different fingerprints are not comparable. Raw samples and logs remain traceable from each reported value. It runs only on demand, never as a seconds threshold in normal CI. The primary #613 half-time statistic is fixed by this manifest: median `session_ns` of `full-correction-cycle`, scope all, lifecycle initial, cold, admissible only when all 5 samples are successful. |
| REQ-010 | **Factory lead times.** Optional milestones `idea-received`, `comparable-ready`, `human-decision`, `implementation-verified` produce three independent lead times. Missing or cross-domain milestones yield `null` with a reason (no UTC-derived estimate). `experiment_ref`, `variant_ref`, `decision_ref` are opaque nullable references, never correctness evidence and never looked up. Measurement creates no decision or verdict. A deterministic attempt chain over linked measurements reports, per attempt, its outcome counts, decision reference and whether the decision changed from the previous decided attempt, keeping undecided, rejected and censored attempts in the denominator; judgment validity, budget and evidence status are supplied by #600/#622 records joined on these references, not by #614. |
| REQ-011 | **Role separation from #600.** Deterministic measurement and its tests require no paid model call, network access or credentials. Model and human phases are exercised with fixed timeline fixtures; in #614 they are recorded only through the documented manual helper CLI protocol (no change to model launch paths or authority), and real model/human phases are reported as `not-observed` until actually recorded. |
| REQ-012 | **Registration and documentation.** Register every new suite in `tests/verification-catalog.json` (mandatory registration; this does not change any gate's required check set). Document usage and reproduction in `docs/verification.md`, `PLUGIN-CONTRACTS.md`, `CHANGELOG.md` and the affected product skill. Only report hosts actually exercised; native Windows/macOS and Claude/Codex/Copilot product paths stay explicitly unverified until run. |

## Non-goals

Optimizing any gate (#615), evidence translation (#617), queue/scheduling (#623), human-facing decision material (#622), model quality evaluation (#600), changing approval/risk/required-set policy, publishing logs, seconds-based CI thresholds, hardware cold-cache claims, p95 from five samples, and retrofitting frozen specs, reports or evidence.

## Acceptance Criteria

AC-001–AC-012 in `acceptance-tests.md` map one-to-one to REQ-001–REQ-012; each AC is expanded into TEST rows with concrete assertions there.

## Edge Cases

Kill -9 between start and finish; concurrent child spans; nested command/gate spans; mechanical-only run; identical repeated write; retried call after time has advanced; missing-runtime skip and process-start failure; referenced artifact missing or changed after finish; resumed attempt with changed decision; same id with different content; host restart or resumed session on another host; UTC step backwards; missing log file; truncated Lite output; feature-scope without feature; `other` rerun reason without detail; unknown/case-variant enum values; human-active overlap; milestone order reversed.

## Security Boundaries

The helper reads only explicitly named input, log and artifact files to hash them and writes only under an explicitly given measurement directory (resolved, not a symlink, no `..` escape in record names). It never runs a subprocess. Record files are bounded strict JSON (duplicate keys rejected, size limit). Diagnostics do not echo local absolute paths or file contents.

## Assumptions

- A1: Linux exposes a per-boot identifier at `/proc/sys/kernel/random/boot_id`, so cross-process monotonic differences on Linux are valid within one boot. Re-verify on the implementation host before T-001.
- A2: No current protected-file guard entry covers `tests/verification.py`, `plugins/sdd-lite/lib/run-lite-gate.py` or `plugins/sdd-quality-loop/skills/quality-gate/SKILL.md` (checked against `plugins/sdd-quality-loop/references/guard-invariants.json` at the investigation HEAD). Re-verify immediately before T-002 edits; if any is protected, stop and use the existing human-copy route.
- A3: The ADR number 0039 was free at drafting (`docs/adr/` max 0038; 0033 is reserved by a pending root-checkout ADR per `docs/adr/0034-a9-domain-component-ownership.md:41`). Re-verify before the ADR is accepted.

## Open Questions

- OQ-1: Clock-domain source on macOS and Windows for cross-process (shell-caller) spans. Default until resolved: per-process domain, so cross-process durations there are `null` with `clock-domain-unverifiable`. In-process Python owners are unaffected. Resolution is required in T-002 before claiming shell-caller timing on those hosts.
- OQ-2: Which single feature is the pinned one-feature benchmark fixture. Default: `risk-adaptive-layer` if its read-only workflow-state check passes at the T-003 baseline HEAD; otherwise the T-003 author records the reason and pins another currently valid registered feature.

## Risks

Overclaiming precise human or cross-session time; mistaking clipped Lite streams for raw logs; measurement failures masking gate failures. Mitigated by null-with-reason, explicit truncation flags, and separating helper exit status from gate exit status.
