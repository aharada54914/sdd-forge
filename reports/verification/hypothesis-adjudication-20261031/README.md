# Retrospective hypothesis adjudication for #614

This new 2026-10-31 analysis independently examines the preserved #600 held-out cohort's original source documents, actual output files and command traces. It does not call or use the golden grader, `comparison.json`, `passed`, or case `expected` values. Product code and prior evidence are untouched. The hypothesis names and counting rules below were formalized AFTER the original experiment and after its aggregate results were known. This is not blinded prospective hypothesis evaluation or independent implementation approval.

## Questions and rules

The original natural-language tasks and public output contract existed before the candidate runs, as did the private expected-output fixtures, pinned inputs and budgets. Their evidence is preserved in `source/`. We now formalize two propositions:

- **H1:** The supplied dependency repair is ready to release. Valid rejection requires actual output `not-ready/bundle-parity-failed`, supported by a failed rebuild parity check in the supplied job evidence. Successful dependency audits alone cannot establish readiness.
- **H2:** The supplied attempt-2 observation can be counted as current successful execution. Valid rejection requires exclusion of attempt 2 and selection of the unique observation matching current run, head, attempt, child exit and completed successful native job. In this fixed source example that is attempt 3; attempt 2's native job was cancelled.

The script derives these conclusions from original source facts, independently of the frozen grader answers. It additionally verifies that all original bytes remain unchanged, output-tree/trace/input hashes match the original experiment, actual successful trace commands exposed the pertinent source bytes, and a completed turn was recorded. The transcript's source reads support evidence access, not a guarantee about hidden reasoning. The final artifact must agree with the source-based decision. Changed bindings reject the analysis instead of silently trusting a verdict.

One judgment opportunity is one `(case, variant, repetition)` planned in the original protocol. The denominator is always 2 cases × 2 variants × 3 repetitions = 12. Missing trials or incomplete reads/turns remain unknown; failed/timeout/cancelled trials remain in the denominator. Per-trial budget excess prevents counting an in-budget valid judgment. `valid-rejection`, `invalid`, and `unknown` are distinct; validity does not require adoption or a positive hypothesis. Repetitions are repeated judgments of two hypotheses, not twelve independent discoveries.

## Results

| Variant | Planned judgments | Unique hypotheses | Valid rejections within original 75s trial bound | Invalid / unknown | Sum of recorded subprocess seconds | Failed internal commands |
|---|---:|---:|---:|---:|---:|---:|
| A | 6 | 2 | 6 | 0 / 0 | 145.909 | 9 |
| B | 6 | 2 | 6 | 0 / 0 | 118.060 | 5 |

All 12 original trials completed. Each output is justified by its source evidence. There are **two unique hypotheses overall**, not four or twelve. Both variants reject the same two unsupported propositions. This establishes neither superiority nor generalization beyond those reduced, explicitly instructed questions.

Fourteen failed internal commands (`python` or `rg` unavailable, exit 127) are preserved verbatim in per-run results, along with later recovery commands in the raw traces. They are not silently recategorized as successful commands just because the final judgment is sound. The source hypothesis about cancelled native attempt 2 is not itself a failed/resumed reviewer trial; the model cohort has no observed reviewer resume. `resume_decision_changes` therefore remains null with a reason.

Two new negative controls replace the proposed output with `ready/checks-complete` or accepted attempt 2. The independent evidence-derived adjudicator rejects both. These are reducer controls, not additional original model runs. The analysis script was rerun after formatting; `results/adjudications.json` and `reproduction/adjudications.json` were byte-identical.

## Budget and measurement boundaries

The original protocol specifies 75 seconds per model subprocess and a 900-second total collection wall limit. Individual measured subprocess durations all fit the former. The original controller consults remaining time before starting each trial and limits subprocess waiting accordingly. However, its complete collection wall interval (setup, gaps, teardown and exception overhead) was not retained as an observation. **The sum 263.969 seconds is subprocess effort, not full collection wall time.** It cannot alone prove the total 900-second limit was met. `valid_judgments_within_total_wall_budget` remains null, rather than fabricating a successful total-budget count.

Each result joins directly to #600 by experiment SHA-256, case, variant, repetition, trace path/hash and native thread ID; source and output file hashes are retained. No historical run-measurement spans or timestamps were invented. This demonstrates a reproducible reference-based count for a fixed per-trial budget. It does not establish full-lifecycle wall time, human active time, resumed human decisions, monetary budget, or broader UX/hypothesis value. Original cohort selection/exposure and any same-author contamination remain as documented in the original evaluation report.

For #614 this supplies the previously missing explicit proposition/count distinction and evidence-based per-trial-budget join. It is limited supplementary evidence, not an unconditional claim that every full-process acceptance condition is met. A future prospective evaluation should retain its enclosing monotonic session interval as well as subprocess spans to observe the total-budget metric.

## Reproduce

```sh
python3 -B evaluate.py --source source --output /tmp/hypothesis-adjudication-new
```

Use a previously nonexistent output directory; run without Python `-O` because integrity assertions must remain enabled. `source/` retains unchanged copies of the original archive, protocol, experiment, index and controller. The original archive SHA-256 is `b5f246c45cdddf5150b41f795a18575494645c840c8ef679a5fa34c33d443966`. The new `archive-index.json` hashes every retained evidence file (excluding itself and the redundant reproduction tree). It records source identity, not trusted approval authority. Raw trace/source/output files and per-run textual reasons are in `results/`; no credentials or new model calls were needed.

Packaging note: the full original report, evaluator, source and results are retained in `raw-evidence.zip`; extract into a new directory before running the reproduction command above. The redundant reproduction tree is omitted; all retained members are listed in the outer `archive-index.json`.
