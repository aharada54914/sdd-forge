# Workflow batch/session: independent execution measurements

The elapsed-time halving target was **not met in any measured workload**. The original historical repository is ineligible and reuses nothing. On a separate eligible 48-feature fixture, two requests became slower despite halving actual scan count; five and ten requests became faster, but remained above half the ordinary execution time. These results support restricting the optional batch to workloads independently shown to benefit, not recommending it by default for two requests.

No product code, original specifications or approval states were edited for this experiment. Exact product/test source snapshots and hashes are preserved with the evidence. All before/after source hashes matched the initial source snapshot. A changed-source receipt would be ineligible for this comparison; the probe exits nonzero rather than treating it as reusable.

## Workloads and scope

1. **Original historical repository:** exported unchanged at `c5a02f06c2aa6d6b287c0b81e203ce0d65f96620`, the frozen input revision used by the earlier #614 benchmark. It contains 19,069 files, exceeding the batch's 4,096-file admission limit. This experiment repeats the original recipe's two full-workflow scans. It does not rerun the six other mandatory mechanical gates in that recipe, and does not remove them or claim whole-development-cycle timing. One matched ordinary/batch-with-fallback comparison was run; it is not a five-trial performance acceptance sample.
2. **Additional eligible workload:** 48 newly constructed Full-profile features with `Spec-Review-Status: Pending`, `Impl-Review-Status: Pending`, and an acceptance document, using the actual product checker. This is a separate small synthetic input tree, not a repaired/reclassified historical repository or evidence that approved/completed projects qualify. Two requests used five matched pairs; five and ten requests each used three exploratory matched pairs.
3. **Additional negative workload:** the same fresh 48-feature shape, with one design declaring Passed without the required review evidence. Three matched two-request pairs confirmed failure and diagnostic preservation without caching a failed result. No existing approval artifact was modified.

Each request is a distinct opaque label. Ordinary execution invokes the real Bash checker for every request. Batch execution uses the actual session module and its real runner, sealed inputs, runtime probe, before/after fingerprints and final batch binding. The measurement wrapper counts actual executor calls; it does not substitute synthetic PASS results. Each measured batch runs in a new Python process, so reuse is only between requests in that same batch, never between trials.

The instrumented API comparison records full executor commands and logs. Separate actual `check-workflow-state.sh --batch requests.json` calls confirmed CLI exits: original repository **2/cold-required**, eligible fixture **0**, negative fixture **1**. The original ordinary fallback was really executed; it is not an estimated timing.

## Elapsed time and actual work

Seconds below are medians of complete measured operations, including initial admission/sealing, runtime probing, re-fingerprinting for every request, final binding, and actual fallback where needed. The original row contains one observation per route. Ordinary subprocesses use the same fixed PATH/locale settings as the sealed profile. Batch/ordinary order alternates for repeated eligible/negative pairs. Host load and OS page caches were uncontrolled; the parent task also ran repository verification. These are observed comparisons, not universal causal speedup estimates.

| Workload | Pairs | Requests | Ordinary seconds | Batch seconds | Actual full scans, ordinary → batch | Reused results | Batch / ordinary elapsed |
|---|---:|---:|---:|---:|---:|---:|---:|
| Original historical repository | 1 | 2 | 78.003 | 79.237 | 2 → 2 fallback | 0 | 101.6% |
| Additional 48 Pending Full | 5 | 2 | 1.388 | 1.575 | 2 → 1 | 1 | 113.4% |
| Additional 48 Pending Full | 3 | 5 | 3.293 | 2.562 | 5 → 1 | 4 | 77.8% |
| Additional 48 Pending Full | 3 | 10 | 6.347 | 3.588 | 10 → 1 | 9 | 56.5% |
| Additional invalid 48 Full | 3 | 2 | 1.475 | 2.747 | 2 → 2 | 0 | 186.2% |

For the original repository, batch admission refused with `snapshot-file-limit` after 0.212 seconds and before any sealed full scan. The caller then ran both ordinary scans. No original input was changed to make admission succeed. The elapsed difference between the two complete routes also includes ordinary-run variation; it is not all refusal overhead.

For the additional Pending fixture, measured elapsed savings were 22.2% at five requests and 43.5% at ten. Break-even is bracketed only between the tested two- and five-request points for this fixture. Its exact location and applicability to another project are unmeasured. Ten requests still did not reach the 50% target, and this additional workload does not replace the original target scenario.

## Cold request, warm reuse and preparation cost

“Cold” here means the first request in a fresh batch. “Warm” means a subsequent request with the same sealed input identity; neither term implies a flushed or controlled OS cache.

| Eligible batch size | First request median seconds | Subsequent request median seconds | Total batch capture/seal/key/revalidation remainder, median seconds |
|---|---:|---:|---:|
| 2 | 1.177 | 0.263 | 0.677 |
| 5 | 1.277 | 0.272 | 1.556 |
| 10 | 1.143 | 0.254 | 2.688 |

The remainder is measured complete batch time minus actual full-executor and runtime-probe time. It includes input/runtime discovery, sealed-copy preparation, key computation, revalidation and controller bookkeeping; those individual costs are not separately attributed. Final batch verification is included in total time even though it sits outside individual request timers. Medians are computed independently and are not additive.

The two-request batch saved one real scan, but setup and repeated fingerprints outweighed that saving. At ten requests most remaining cost was outside the executor/probe intervals. Invalid results were executed again, including another seal/runtime probe, rather than receiving a misleading “warm PASS.”

## Behavioral and source checks

- Actual executor counts were 1 for every eligible batch, N for its ordinary comparator, and 2 in both negative routes. Reused rows retained the original run reference; no cross-process receipt was imported.
- Every compared request preserved exit status and exact stdout/stderr bytes. The negative fixture failed in both routes, and no negative result was cached.
- All measured gate/session/runner/supervisor/validator/schema hashes stayed equal before and after execution and matched the archived source snapshots. The underlying repository base revision was `f7ebf27a1050f63863de11da3696d6c894fe343d`; new batch source was not yet committed, so its SHA-256 identities are the precise measured source identity.
- The large historical input, Git fallback, conditional dependencies and other unsupported input shapes remain ordinary-execution territory. Only the file-count refusal was exercised for the historical tree here; this report does not claim coverage of every unsupported branch.
- This is Linux/bubblewrap execution evidence. It does not establish native macOS/Windows support, human/model performance, independent review approval, or reuse of arbitrary build/test results. Other mandatory gates and approvals remain independent.

## Evidence and reproduction

`summary.json` contains ranges, MAD, per-workload sample counts, pair identities, source hashes, cold/warm observations and the explicit unmet-halving result. `raw-evidence.zip` contains 600 files, including raw command outputs, full batch results, actual executor argv, both synthetic input trees, product source snapshots and controller scripts. The 19,069-file original tree is reconstructed from its Git revision rather than duplicated in the archive. `archive-index.json` binds every member to its size and SHA-256 and records the original prefix used in absolute paths. Every archive member was re-read and hash-verified.

The exact executed probe is archived as `probe-executed.py`. The checked-in `probe.py` differs only by removal of an unused import after execution; both hashes are recorded. The recordings are measurement evidence, not reusable verdict files.

To repeat a case, reconstruct the chosen input tree and the measured product source from their recorded revisions/snapshots, then use fresh output paths:

```bash
python3 reports/verification/workflow-session-comparison-20261025/probe.py \
  --source-root /path/to/measured-product \
  --registry /path/to/fixture/specs/workflow-state-registry.json \
  --mode baseline --requests 2 --output /tmp/workflow-baseline-new
python3 reports/verification/workflow-session-comparison-20261025/probe.py \
  --source-root /path/to/measured-product \
  --registry /path/to/fixture/specs/workflow-state-registry.json \
  --mode batch --requests 2 --output /tmp/workflow-batch-new
```

Archive SHA-256: `e2aa16b40bbe7d1da9a31ecb29465e71ab61c02481c5c9b88c8a15645b0ff5a3`.
