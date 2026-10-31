# Deterministic measurement and workflow feedback evaluation

Baseline fixtures and owner code: `c5a02f06c2aa6d6b287c0b81e203ce0d65f96620`. Candidate executable overlay: `dc0c17c24aff554e2535281ac5d9ee5f1db389b0`. Later collector/guard hardening is outside this performance candidate. The baseline registry contains 54 entries; feature runs select `workflow-state-integrity`, task `T-001` (high risk).

The baseline Git tree supplies frozen specifications and reports. Only the manifest code paths are replaced with candidate code. This evaluates those gate implementations against the fixed historical inputs, not every change in the candidate repository.

## Results

| Workload | Revision | n | Median seconds | Min–max seconds | MAD seconds |
|---|---|---:|---:|---:|---:|
| full-correction-cycle-initial-cold | baseline | 5 | 90.539606 | 81.142007–93.756997 | 3.217391 |
| scoped-correction-cycle-initial-cold | baseline | 5 | 48.546505 | 45.772097–65.815811 | 2.774408 |
| full-correction-cycle-initial-cold | candidate | 5 | 117.063604 | 94.137013–120.731934 | 3.668330 |
| scoped-correction-cycle-initial-cold | candidate | 5 | 42.405108 | 40.626096–45.542900 | 1.779012 |
| feature-feedback-initial-cold | baseline | 5 | 0.637192 | 0.570548–0.744866 | 0.055743 |
| feature-feedback-initial-warm | baseline | 5 | 0.591549 | 0.576098–0.648247 | 0.015451 |
| feature-feedback-resume-cold | baseline | 5 | 0.609877 | 0.593102–0.660743 | 0.014166 |
| feature-feedback-resume-warm | baseline | 5 | 0.539222 | 0.504361–0.597232 | 0.022409 |
| feature-feedback-after-repair-cold | baseline | 5 | 0.499416 | 0.487947–0.530825 | 0.011468 |
| feature-feedback-after-repair-warm | baseline | 5 | 0.504603 | 0.492162–0.523021 | 0.006537 |
| feature-feedback-initial-cold | candidate | 5 | 0.551166 | 0.528637–0.639110 | 0.022529 |
| feature-feedback-initial-warm | candidate | 5 | 0.552518 | 0.518526–0.578255 | 0.021187 |
| feature-feedback-resume-cold | candidate | 5 | 0.523796 | 0.485517–0.555435 | 0.031639 |
| feature-feedback-resume-warm | candidate | 5 | 0.507369 | 0.484768–0.528676 | 0.008331 |
| feature-feedback-after-repair-cold | candidate | 5 | 0.525729 | 0.497151–0.843064 | 0.028578 |
| feature-feedback-after-repair-warm | candidate | 5 | 0.534223 | 0.478975–0.882796 | 0.044798 |

All measured scenarios retain five trials, including failed/censored classifications. See summary.json for exact counts; expected invalid-registry repair controls are retained separately as setup executions. Resume trials contain linked attempts. Each full/scoped recipe keeps the same mandatory mechanical checks and final full scan.

Concurrent repository verification ran during these samples. System load and OS page caches were uncontrolled. “Cold” means a fresh exported worktree; “warm” means one discarded warmup and repeated use of that export. These observations identify expensive repeated scans but do not establish a causal source-level speedup or a strict half-time acceptance result.

Five alternating bare/measured pairs observed a median overhead of 28.112 ms (5.487%), range -10.115 to 32.200 ms. Signed differences, including negative noise, are retained; no fixed overhead threshold is claimed. These samples include initial measurement setup; the earlier partial-wrapper overhead samples are also retained separately in the archive.

## Behavioral checks

- Real workflow fixtures: valid, malformed JSON, stale design, forged task provenance and empty registry. All five cases preserve expected exit and normalized diagnostics with timing off/on at both revisions.
- Actual pre-change owner comparison: verification success/failure and Lite success/failure/timeout all preserve exit, diagnostics and serialized payload after removing only predeclared duration/timestamp fields. Raw outputs and the reproduction script are archived.
- Deterministic suites: measurement 16, owner integration 5, benchmark 9, project-evidence collector 7 and fixed-review inputs 34 tests passed (71 total). The extracted workflow-state Bash/PowerShell fixture suite passed. Independent review reproduced the collector observation-swap attack before the fix and confirmed rejection afterward.

## Boundaries

No model call, human interaction, model cost/token observation, or real-app acceptance is inferred from these gate runs. Missing human lifecycle quantities remain unavailable. Native macOS/Windows runtime execution was not performed here. Heavy build/test result reuse and an incremental workflow cache are not implemented: the observed repeated scan is handled by feature feedback with a mandatory final full scan. The reviewer index uses the existing fixed inventory, retains full originals and carries no verdict. The project-evidence bridge still refuses original Red/Green-pair and critical-signing routes it cannot substantiate.

## Evidence and reproduction

Reproduction commands and manifest semantics are in `tests/fixtures/run-measurement/README.md`. `summary.json` retains exact aggregate data and fingerprints. `raw-evidence.zip` retains stdout/stderr, measurement records, full results, the owner comparison script, and exact harness sources; generated fixture tree copies are excluded and reproducible from the frozen baseline and hashed builder.

Archive SHA-256: `eab0b3b459990e3b3cfd7996b6ac1b557037f7cd1936f9ea614eadff23be408a`.

`archive-index.json` maps every member to its size and SHA-256 and records the original scratch prefix. References in raw measurement records keep their original paths; resolve that prefix to the archive root when inspecting extracted evidence. The archived bytes are unmodified. Tool binary versions/hashes collected at packaging are labelled as such; they are not a complete interpreter/dependency closure or cache authorization.
