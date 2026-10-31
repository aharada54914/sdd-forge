# Reviewer input preparation comparison (#618)

This is a scripted machine preparation comparison, not independent model review or observed human work. It found no demonstrated speedup. Both routes consumed all six required originals (35,038 bytes) and identical quoted state fields in all five matched pairs. Heavy build/test result reuse remains unimplemented.

Source HEAD: b1c828355d3b3ff5633f23c4b1d8f28b030817b0. Exact four helper hashes matched before/after every experiment as an aggregate check (not a continuous mutation monitor); summary.json records them and sources/ retains their bytes. The parent session may make unrelated edits/commits concurrently. Host load and OS caches are uncontrolled.

## Method

The actual current launcher's required_input_paths and review-conditional-inputs resolver determine the impl-reviewer-a, attempt-1/round-1 set for workflow-state-integrity at the pinned Git revision. Six actual repository documents, including the historical precheck and conditional investigation, are exported byte-for-byte to a separate local fixture Git repository, then materialized by the existing fixed-input helper. This is the required-set assembly shape, NOT a claim that historical precheck hashes approve current review state. No task is approved or reviewer launched. It does not exercise reviewer B, later rounds, research-enabled projects or every conditional branch.

Baseline calls the existing source-map CLI, obtains the existing state_reference API result and reads every full original. Candidate calls the reviewer-index CLI, obtains its state_reference and reads every full original. Both consumers check exact required path set and original digest. Candidate verdict and unresolved_findings must remain null. The script reads bytes; it does not comprehend or independently assess their content. Current selection/snapshot validation remains enabled in both product CLI paths.

Five matched pairs alternate baseline/index and index/baseline. Each measured route includes CLI process startup, its real Git operations and validation, state-reference preparation and complete source reads/hash checks. Initial conditional discovery, fixture Git creation and snapshot materialization are shared setup outside both timers; output recording is outside the timers. Baseline state_reference runs in the warmed controller while the candidate computes it inside its CLI. These are two actual preparation paths, not isolated algorithm microbenchmarks. No dummy PASS or reduced mandatory input set is substituted.

| Route | Median ms | Min–max ms | Original files | Original bytes |
|---|---:|---:|---:|---:|
| source-map + state_reference + read originals | 106.926 | 104.583–114.250 | 6 | 35,038 |
| reviewer-index + read originals | 106.025 | 104.234–112.734 | 6 | 35,038 |

The 0.901 ms median difference is smaller than run variability. No causal speedup, human review time, cognitive load, token saving, correctness of review conclusions or reduced defect rate is established. All pairs preserve exact input path/hash/byte records and state-reference objects. The index adds navigation metadata, not permission to omit originals. Human active time is unobserved.

## Negative controls

- Tampered snapshot bytes: both actual product CLIs exit 1.
- Missing required snapshot original: both actual product CLIs exit 1.
- Dirty selected working original: index exits 1; source-map exits 0 because it still refers to the fixed historical snapshot. This is intentional additional current-presentation protection, not claimed negative verdict parity or a bypass of the launcher's later admission.
- Missing conditional investigation binding: actual launcher required_dependencies rejects it before review admission.
- Omitted or replaced original in the handoff map: the experiment's independent fixed-set/hash consumer rejects it. These last checks are harness assertions, not new product functionality or proof of model compliance.

No normal pair was omitted. summary.json retains all 10 timings and all control outcomes, exact negative stdout/stderr and argv. commands.json retains successful CLI Git/owner commands and outputs. Pair JSON files retain raw product output. Fixture and snapshot retain the actual inputs. The original compare.py is retained without post-run editing; its isolated unused always-true assertion before the real tamper probe performs no operation and is not the tamper test. The real probe immediately afterward invokes both CLIs and asserts their exit 1 results.

For reproduction, use a copy of compare.py in a NEW empty output directory and the pinned product source at its ROOT location. The script deliberately refuses existing fixture directories. No paid model, external service, product edit or approval is required. archive-index.json hashes retained evidence excluding fixture .git internals and the index itself; the fixture commit and source revision are in summary.json.
