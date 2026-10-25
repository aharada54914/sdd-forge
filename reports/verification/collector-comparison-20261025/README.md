# Collector versus scripted manual-format evidence preparation

This fixture comparison completed six matched pairs (12 actual executions) at product revision `aecd3136278cdc18c377fac269e60b037d34dc25`. Each pair starts from byte-identical fixture files and uses the same project-skill runner, check identity, contract obligations, report format, bundle generator and independent contract/bundle checkers. Three pairs exercise a successful command; three exercise a real exit-3 command. All six pairs preserved the same checker verdicts, contract semantics and report bytes. Failed execution remained failed in both routes.

The comparison establishes a narrower result than observed human productivity: the collector removes the explicit caller-side transfer operations scripted here. Nobody performed a manual editing task, so human time, cognitive burden and error-rate reduction remain unmeasured.

## Protocol

`compare.py` imports the existing `CollectorTests` fixture builder from a clean detached checkout of the pinned revision. It constructs each scenario once, then copies the complete fixture, including its Git metadata, for each run. The initial non-Git file inventory is hashed and must match before every invocation. The original contract must remain unchanged afterward. The legacy-format smoke fixture retains its existing optional-check waivers; this is not an application build or a high/critical-risk acceptance experiment.

The manual-format route independently calls the existing runner and observation validator, authenticates observation/log hashes against the actual runner result, transfers observed fields and retained bytes into the existing formats, then invokes `check-contract.py`, `generate-evidence-bundle.sh` and `check-evidence-bundle.sh`. It does not call the collector or its projection helper. The other route calls the real collector API, which invokes those existing mechanisms itself. Neither route changes task state or claims an independent review.

Pairs run manual→collector, collector→manual, then manual→collector in each scenario. Imports, fixture construction/copying and evidence packaging are outside the timed intervals. Both routes run in the same warmed Python harness; these are API-path measurements, not CLI startup measurements. Host load and OS caches were uncontrolled, and the parent task ran other verification concurrently.

The timer records each complete preparation path and the actual runner call separately. Runner time includes its isolation, execution, cleanup, validation and receipt publication. The remainder includes field handling, report/contract preparation and existing generator/checker calls. Instrumentation also records controller-launched process argv/cwd/exit values, checker stdout/stderr, runner receipts, original logs and every produced artifact's digest. It does not claim to trace every descendant process launched inside a shell checker.

## Observed machine time

All values below are milliseconds. Each row has three samples; medians are computed independently, so component medians need not sum to the total median. Full ranges, MAD and individual samples are in `summary.json` and the raw archive.

| Scenario | Route | Total median | Runner median | Remaining preparation median | Total range |
|---|---|---:|---:|---:|---:|
| Success | Scripted manual-format | 291.480 | 125.258 | 152.162 | 274.564–293.205 |
| Success | Collector | 266.073 | 107.755 | 159.466 | 264.085–291.285 |
| Exit 3 | Scripted manual-format | 285.025 | 126.658 | 153.010 | 254.702–294.425 |
| Exit 3 | Collector | 286.687 | 118.981 | 157.765 | 267.825–287.721 |

There is no causal speedup claim: sample size is small, system load is uncontrolled, and the scripted baseline additionally records its transfer events. The collector's extra authentication is included in its measured path. Machine time is reported separately from the transfer counts below.

## Scripted transfer and correction events

These counts describe actions actually emitted by this harness per execution, with field/blob hashes retained for inspection. Their granularity is part of this fixed protocol, not an estimate of keystrokes or time.

| Caller-side action | Scripted manual-format | Collector invocation |
|---|---:|---:|
| Transfer retained log/observation/manifest blobs | 5 | 0 |
| Transfer contract execution fields | 6 | 0 |
| Transfer report fields | 9 | 0 |
| Explicitly create transcript, contract and report | 3 | 0 |
| Post-validation evidence corrections | 0 | 0 |
| Human active time | Unobserved | Unobserved |

Zero caller-side transfers does **not** mean the collector performs no data copying or writes. It still generates the transcript, contract, report and bundle; those operations moved behind its API. The same three top-level generator/checker subprocess calls occurred in every run. Both scripted routes required zero corrections, so this experiment supplies no evidence of a lower correction/error rate. There were no induced transcription mistakes and no fabricated fixes of the real exit-3 outcome.

## Behavioral comparison and limits

- Each pair has the same initial file-inventory digest and equal result identities/verdicts. Contract comparison excludes only actual `started_at`/`finished_at` values; all other fields, including required checks and waivers, must match. Report bytes match exactly.
- All six successful executions passed both existing validators. All six exit-3 executions failed both validators while retaining real failure logs. No failed result was promoted to success.
- Raw execution artifacts, checker outputs and commands remain available with hashes. Expected negative outcomes remain in the dataset; no trial was dropped.
- This experiment covers a Linux smoke-check route. It does not compare Red/Green transitions, critical signing/clean-tree ordering, native macOS/Windows execution, model reviews or human/application acceptance. Their separate tests are not implied by these timings.

## Reproduction and evidence

From the repository, choose previously unused paths:

```bash
git worktree add --detach /tmp/collector-comparison-source aecd3136278cdc18c377fac269e60b037d34dc25
python3 reports/verification/collector-comparison-20261025/compare.py \
  --source-root /tmp/collector-comparison-source \
  --output /tmp/collector-comparison-results
git worktree remove /tmp/collector-comparison-source
```

The harness rejects a different source revision or a dirty source checkout and never runs a model or makes a network request. Its assertions verify matched inputs, retained original contracts, correct actual success/failure outcomes, validator agreement, equivalent contracts and identical reports. Reproduction creates fresh timestamps, run receipts and fixture Git commits; exact output bytes are not expected to repeat across executions.

`raw-evidence.zip` contains 203 files: raw records, input fixtures, transfer events, command outputs, runner artifacts and full results. `archive-index.json` binds every member's size/SHA-256 and preserves the original output prefix for resolving retained absolute command/reference paths. All archive members were re-read and checked against that index. `summary.json` keeps per-pair outcomes, action counts and timings without duplicating every raw record.

Archive SHA-256: `d436f4af4240c630aea54fa35ff7ad52c9de1e793507d1ef0e009ca766fa08ba`.
