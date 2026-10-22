# Proposed tasks: verification-measurement

Proposal-Status: Draft (not a tasks.md; not reviewed)

## Why this is not `tasks.md`

`check-workflow-state.sh` rejects a `tasks.md` unless Spec and Impl review are both Passed ("tasks.md requires Spec and Impl Passed", `plugins/sdd-quality-loop/scripts/check-workflow-state.sh:1904-1905`). Writing `tasks.md` now would break the repository-wide gate that this feature measures. After spec-review and impl-review pass, `sdd-bootstrap-interviewer` Phase 2 converts this proposal into `tasks.md` with `Task-Review-Status: Pending`, `Approval: Draft`, `Status: Planned`, plus `traceability.md`, then `task-review-loop` runs. Only a human sets Approved.

## Ordering

T-001 → T-002 → T-003. One task at a time; each has a fresh implementation context, an implementation report at `reports/implementation/verification-measurement/T-NNN.md` (with `Run ID:` and `Task Attempt Count:`), task-local evidence under `specs/verification-measurement/verification/T-NNN/`, and independent `quality-gate`. #614 stays open until T-003 is Done; reducer fixtures alone (T-001) do not unblock #615 implementation.

## T-001 Measurement contract, writer and reducer

Approval: Draft
Status: Planned
Risk: medium
Risk Rationale: New versioned contract and helper; no existing behavior or caller changes.
Required Workflow: tdd
Data Migration: None
Breaking API: No
Requirements: REQ-001, REQ-002, REQ-003, REQ-004, REQ-005, REQ-006, REQ-010, REQ-011, REQ-012 (registration part)
Tests: TEST-001, TEST-002 (c, e, f via CLI/API), TEST-004–TEST-024 (including TEST-008a, TEST-008b, TEST-019; not TEST-019a), TEST-033 (statistics function), TEST-037–TEST-042 (including TEST-039a)

### Planned Files

- `plugins/sdd-quality-loop/scripts/run_measurement.py` (new)
- `contracts/run-measurement.schema.json` (new)
- `tests/run-measurement.tests.py` (new)
- `tests/fixtures/run-measurement/` (new: `timeline-basic/`, `nested/`, `attempts/` and one directory per negative case)
- `tests/verification-catalog.json` (registration of `tests/run-measurement.tests.py` only, in `local-posix` and the existing python CI profile used by sibling `verification-*.tests.py` suites)

### Done When

- Failing tests and fixtures are committed before the helper exists (Red), then pass (Green): `python3 tests/verification.py --suite tests/run-measurement.tests.py --run` and `python3 tests/verification.py --suite tests/verification-catalog.tests.py --run`.
- Expected values in tests are the literal numbers from `acceptance-tests.md` (e.g. 5000/7000/6000/8000/10000/1500/500/6000/3500, MAD 2), not values computed by helper code.
- Each listed negative branch has its own fixture and assertion: duplicate identical write, conflicting write, UTC jump, domain mismatch, negative delta, open span with and without `as_of` (time injected only via the private `_clock`), semantic retry after time advances via API and CLI, `suite:` command id with `/`, nested spans, mechanical-only `not-observed`, artifact missing/changed, attempt chain with undecided/rejected attempt, changed decision, broken chain and duplicate attempt, each of 7 outcomes, invalid/case-variant enums, 124-not-timeout, parallel union vs effort, human-active null and overlap, missing/truncated log, milestone missing/cross-domain/reversed, token/cost null reasons, secret sentinel, unsafe ids/symlinked directory.
- Schema/emitter mismatch test: every key the helper writes for each record kind equals the schema's `required` set, and a fixture with an extra key fails validation.
- Standard library only; `grep -n "subprocess\|socket\|os.environ" run_measurement.py` finds no use. No file outside the new paths and the one catalog registration changes (TEST-031 diff check).

### Out of Scope

Owner integration, CLI caller docs, benchmark, CHANGELOG/doc updates, any run-record/receipt change.

### Blockers

Spec, impl and task review Passed; human approval.

## T-002 Opt-in integration with existing owners

Approval: Draft
Status: Planned
Risk: high
Risk Rationale: Changes CLIs of existing execution owners used by gates and CI; must prove byte-identical no-flag behavior.
Required Workflow: tdd
Data Migration: None
Breaking API: No
Requirements: REQ-001 (late artifact binding by owners), REQ-007, REQ-002 (shell caller domains, OQ-1), REQ-012 (skill docs)
Tests: TEST-002 (a, b, d, g), TEST-019a, TEST-025–TEST-029, TEST-031, TEST-003

### Planned Files

- `tests/verification.py`
- `plugins/sdd-lite/lib/run-lite-gate.py`
- `plugins/sdd-quality-loop/skills/quality-gate/SKILL.md` (optional caller snippets only)
- `tests/run-measurement-integration.tests.py` (new) and its catalog registration
- `tests/lite_normalize.py` (new, one function `normalize_lite_payload`: the TEST-027 Lite volatile-field rule, reused unchanged by T-003 `--compare`)
- `tests/verification-catalog.tests.py` / `tests/lite-gate-cli-chain.tests.sh` only if an existing assertion must extend to the new flag

### Done When

- High-risk preflight recorded before edits: for each persisted field (span `outcome`, `exit_code`, `command_id`, input sha256), its counterpart (receipt `status`/`exit_code`/`source_sha256`, Lite `exit_code`/`timed_out`) and a failing mismatch test.
- Before editing, re-verify assumption A2 (no guard entry for the three edited files); if protected, stop and use the existing human-copy route.
- No-flag equality under identical controlled state (same non-git fixture directory and catalog for verification.py; same fixture `--repo-root` for Lite): receipts, Lite `--output` and Lite stdout equal after asserting the format of and removing only `seconds`/`duration_ms`/`recorded_at`; stderr and exit codes equal (TEST-025, TEST-027).
- Owners finish their session span after publishing their output and attach it as an artifact reference; skip/process-start-failure mapping per design (TEST-002, TEST-019a).
- Flag path: correct spans and preserved exit codes for passing, failing and timed-out cases; measurement I/O failure after execution starts does not change exit codes; invalid measurement configuration exits 2 before anything runs (TEST-026–TEST-028).
- Bash and PowerShell snippets produce equivalent records and propagate exit codes 0 and 3 (TEST-029), run with an installed PowerShell 7 (`pwsh`). OQ-1 is resolved in the report (implemented macOS/Windows domain source, or the null default kept and documented); native macOS/Windows remain marked unverified unless exercised.
- `plugins/sdd-review-loop/`, emit-run-record scripts and goldens, Lite required-check catalogs and tier-minimum contracts unchanged (TEST-031, TEST-003).

### Out of Scope

Benchmark driver, baseline evidence, model launch paths (`managed-model-entry.py`, review launchers), any gate order or required-set change.

### Blockers

T-001

## T-003 Frozen benchmark, semantic equivalence, overhead and documentation

Approval: Draft
Status: Planned
Risk: medium
Risk Rationale: Adds a manual benchmark tool and docs; no gate behavior change.
Required Workflow: tdd
Data Migration: None
Breaking API: No
Requirements: REQ-008, REQ-009, REQ-011, REQ-012
Tests: TEST-030, TEST-030a, TEST-030b, TEST-032–TEST-036 (including TEST-033a, TEST-034a, TEST-034b, TEST-034c), TEST-043

### Planned Files

- `tests/benchmark-gates.py` (new), `tests/benchmark-gates.tests.py` (new, registered; no wall-time assertions)
- `tests/fixtures/run-measurement/benchmark.json` (new manifest, including `code_paths`) and `tests/fixtures/run-measurement/benchmark-resume-trials/` (TEST-033a)
- `tests/lib/workflow-state-cases.sh` (new functions-only case builder moved from `tests/workflow-state.tests.sh`) and `tests/workflow-state.tests.sh` (sources it for `valid`, `stale`, `forged`; assertions unchanged) — test-helper edits only
- `docs/verification.md`, `PLUGIN-CONTRACTS.md`, `CHANGELOG.md`
- Evidence: `specs/verification-measurement/verification/T-003/` (raw samples, logs, `results.json`, comparison output)

### Done When

- OQ-2 resolved and recorded: pinned single feature validated at the baseline HEAD.
- Manifest validation negatives (TEST-034), fingerprint/`comparable` (TEST-034a), lifecycle recipes with stub gates (TEST-034b), code-under-test selection with distinguishable stub markers (TEST-034c) and sample-class/resume-trial/traceability tests (TEST-033, TEST-033a, TEST-035) pass first; the manifest (recipes, `repeat_count`, `pinned` task/risk/contract, `defect_patch`, `resume_after`, `primary`, `compare_cases`) is frozen before any baseline sample is collected.
- `--compare` shows identical `(exit_code, normalized output hash)` per `compare_cases` entry, bare and measured, with at least one normal/invalid/tampered/boundary case per wrapped family; a measured-run diagnostic change with unchanged exit fails (TEST-030); Lite cases use `normalize_lite_payload` unchanged (TEST-030a); real generated normal/tampered workflow-state cases come from the shared builder, not copied validators (TEST-030b).
- Before moving the builder, re-verify the cited `tests/workflow-state.tests.sh` lines and that it has no `guard-invariants.json` entry; if protected, stop and use the existing human-copy route. `tests/workflow-state.tests.sh` passes whole after the move; production validators (`plugins/sdd-quality-loop/scripts/`) and original evidence (`reports/`) are unchanged.
- Real runs on this Linux host: full matrix with 5 trials (`--run`) and paired AB/BA overhead (`--overhead`), raw logs retained and every statistic traceable to `implementation_revision` (the explicitly selected `--code-revision`), `baseline_head`, OS, runtime versions, target count, trial count and temperature. Results reported honestly, including negative overhead; no seconds threshold added to CI (TEST-036).
- Docs name the contract, flags, CLI, the manual protocol for review-preparation/model/human phases and milestones, the `join` attempt chain and its #600/#622 handoff, reproduction command including `--code-revision` selection, cold/warm definitions, primary statistic, fingerprint rule and limitations; hosts not exercised (native Windows/macOS, Claude/Codex/Copilot product paths) are listed as unverified.

### Out of Scope

Any optimization (#615), evidence translation (#617), scheduling (#623), paid model or human-time evaluation (#600/#622), publishing logs externally.

### Blockers

T-002
