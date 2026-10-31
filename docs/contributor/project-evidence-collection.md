# Project execution evidence collection

`plugins/sdd-quality-loop/scripts/collect-project-evidence.py` reuses the project
skill runner and existing contract/report/bundle formats. It executes the selected
check; it does not import a PASS observation, issue an independent review, approve
a task, or set Done. Execution currently requires the runner's Linux process
ownership backend. Unsupported platforms retain their actual not-run result.

The ordinary options are `--execution-root`, `--contract`,
`--task-input-manifest`, `--skill`, `--check`, and bounded `--timeout` (default 30
seconds). Inputs and outputs remain subject to the existing task manifest and
skill closure validators. Other checks are retained unchanged. A mechanical
report explicitly identifies its limited verdict scope.

## Prospective TDD

For `required_workflow: tdd` and `unit-tests` / `acceptance-tests`, start the
collector **before implementation**, with `--tdd-input-stdin` and one
`--tdd-source <relative-path>` per implementation input allowed to change.
All other input hashes, the skill/test closure, command, runtime executable,
and process environment must remain fixed. Source declarations are an explicit
caller-owned boundary: put test code in the sealed skill closure and never
classify a test or dependency as mutable implementation merely to pass a check.
This is provenance validation, not an OS sandbox or proof against malicious
same-user code or changes to every external runtime dependency.

After an actual completed nonzero Red, the collector prints its observation path
and waits for one line on stdin: the Green task manifest path. Make the intended
implementation change, write that manifest with a distinct run ID and updated
hashes only for the declared implementation inputs, and supply its path. Preserve
all task/session/model identity and output grants; replace only the exact old
observation directory grant with the new run's directory. The process must remain
alive during this handoff. The Python `collect` API alternatively accepts a
`tdd_transition(red_result)` callback returning the Green manifest path, and
`tdd_sources` containing the same allowed paths.

The collector holds Red's original bytes in memory across the transition, binds
both executions to their admitted manifests, and retains both phases' raw streams,
observations, and manifests in the existing hash-bound execution artifact. Both
`red_evidence` and `green_evidence` refer to that artifact; no new contract fields
are introduced. An interrupted process retains runner observations and logs, but
cannot resume them as an authenticated Red checkpoint. Do not reconstruct Red
against old source after implementation or modify frozen historical evidence.
Failed Green stays failed. Timeouts, cancellation, unavailable runtime, and
runner-boundary violations cannot serve as Red.

## Critical preparation and signing

Use `--prepare` for high or critical capture; automatic bundling from the
mechanical report is refused for both tiers. It writes the candidate contract and a
mechanical report, returns the contract SHA-256, and generates **no bundle**.
Contract failures still produce a failing exit status. Keep signing credentials
out of the execution environment: the collector refuses `SDD_EVIDENCE_KEY` and
`SDD_EVIDENCE_KEY_FILE` at every execution boundary. The runner is not a secret
isolation sandbox; run capture in the existing isolated environment without
access to the signing account's home key or other credentials.

Then use the existing quality/review route:

1. Complete every required check and obtain the actual independent review report.
   The collector's mechanical report is not that review.
2. Review the prepared contract and original artifacts, including its returned
   digest. Commit those inputs and the independent report normally. Verify a clean
   checkout. Do not weaken risk, TDD, signature, or human approval requirements.
3. In the separate signing environment, invoke existing
   `generate-evidence-bundle.sh CONTRACT INDEPENDENT_REPORT ROOT OUTPUT` (or its
   PowerShell equivalent), with `OUTPUT` outside the checkout and the existing key
   resolver. Use the required `T-<number>.evidence.json` basename. Creating the
   bundle must not dirty its own source checkout.
4. Run existing `check-evidence-bundle.sh OUTPUT ROOT` (or its PowerShell
   equivalent). Existing task transition and two-person critical approval remain
   outside the collector.

The collector suite exercises actual Red/Green and the complete critical
prepare/dirty rejection/clean commit/sign/verify route using explicitly synthetic
manual checks, an explicitly synthetic independent report, and a synthetic key.
This verifies integration, not production reviewer authority or real acceptance.

## Measured preparation scope

The [source-pinned collector comparison](../../reports/verification/collector-comparison-20261025/README.md)
retains six matched pairs of the same smoke fixture and its original checker
results. Caller-side field transfers fell from 20 to 0; both paths required zero
post-validation corrections. These are scripted machine operations, not measured
human active time, lower error rate, or whole-project speedup. The existing optional-check
waivers in the legacy-format smoke fixture remain explicit, and high/critical acceptance is not inferred
from that comparison.
