# Issue 618 first real test candidate measurement

Protocol was written before either measured execution. No product files were edited. Source is a fixed git archive of bda9e3dcc8ca282d1fcfc0bc761303d7a6f5309d, not concurrent working changes. The archive SHA and complete regular-file SHA inventory are retained. Inventory was identical before and after each run; this is observation, not an ABA-resistant admission guarantee.

## Selection and actual result

Existing registered owner: `tests/verification.py --suite tests/bootstrap-cross-layer-index.tests.sh --run --measure-dir <new> --receipt <new>`.
Existing CI timing data recorded 16.629/15.407 seconds. The unchanged suite tests real bootstrap templates and Python/PowerShell traceability validators: valid examples, ignored auxiliary tables, rejected malformed/displaced headers, and six heading-depth table boundaries with valid/invalid anchors. No artificial sleeps, artificial expensive workload or new cache were added.

| Trial | Owner wall seconds | Measured command seconds | Measured session seconds | Result |
|---|---:|---:|---:|---|
| 1 | 5.841151 | 5.728630 | 5.736402 | 54 PASS / 0 FAIL, owner exit 0 |
| 2 | 5.847523 | 5.706706 | 5.714507 | 54 PASS / 0 FAIL, owner exit 0 |

PowerShell parity actually executed (no skip). Existing #614 observer saved complete spans, source suite hash, owner receipt reference/hash and success outcomes. Each trial contains one actual suite invocation; result reuse count is zero, execution rate 2/2. The second run is a repeat, NOT a result-cache warm hit. Neither run flushes OS page caches. No reviewer preparation/model/token/cost measurement occurred. Current duration exceeds five seconds but only marginally; do not claim a dominant heavy build or economically justified cache from n=2.

## Input and dependency closure

Known repository inputs: owner `tests/verification.py`, registration `tests/verification-catalog.json`, measurement `plugins/sdd-quality-loop/scripts/run_measurement.py`, selected suite, bootstrap interviewer `design.template.md` and `traceability.template.md`, review-loop `validate-layer-traceability.py` and `.ps1`, `specs/ci-mcp/{traceability,requirements}.md`. Catalog loading also tests existence/containment of every registered suite. Full export bytes are retained, avoiding a speculative narrow source copy.

Owner reads Git revision/status; export has no .git and GIT_CEILING_DIRECTORIES prevents parent discovery, so its receipt truthfully has null revision/cleanliness. Protocol and archive SHA separately identify the source. Measurement reads boot identity, clocks, platform, UUID randomness. Shell tests synthesize temporary Markdown fixtures, invoke Python/Pwsh, compare actual exits and diagnostics, and remove their owned temp directory. These generated fixtures are outputs of fixed test bytes, not external application state.

Exact child environment allowlist is in protocol.json: no inherited credentials, isolated HOME/TMPDIR, fixed PATH/locale, no global Git config, bytecode disabled, telemetry opt-out. No network/service access exists in the inspected test/validator logic. Network was not namespace-blocked, and runtime incidental accesses are not attested. This is a local test candidate, not a claim of complete syscall isolation.

Runtime identities record owner Python separately from PATH-resolved child Python, Bash, Git, grep/awk/coreutils and official pwsh wrapper/real executable. Uncaptured dependencies include Python standard library/site startup/import resolution, Python and tool dynamic libraries/loader, PowerShell/.NET assemblies/modules and module autoload, kernel/filesystem semantics and resources, locale/timezone/runtime configuration. Main executable hashes are NOT a complete runtime closure.

The required official `/workspace/.tools/sdd-forge-dev/bin/pwsh` wrapper overrides XDG_CACHE_HOME/CONFIG_HOME/DATA_HOME to shared runtime directories and mkdir creates them if absent. These shared locations were not inspected for contents, sealed, reset, or copied. Their mutable caches/module analysis can affect timing; unknown semantic runtime dependencies are not assumed absent. The isolated HOME does not override this wrapper behavior. Thus literal complete absence of external mutable state is NOT established, even though the test has no explicit application/service dependency.

## Eligibility and next decision

NOT eligible for safe result reuse as measured: runtime/config closure and process/filesystem enforcement are incomplete. Repeat success plus source pre/post hashes cannot authorize a cached PASS. Unknown dependencies must cold-run or BLOCKED. No existing required check was removed, no receipt reused, and no model review was cached.

This supplies a real non-workflow test cost observation for candidate screening only; it does not complete #618 first AC or cold/warm reuse comparison. A single repeat can avoid at most roughly 5.7 seconds before capture/validation costs. Reusing the full suite would require freezing the above Bash/Python/PowerShell runtime/config boundary and fresh private temp side effects; do not build a general cache on this evidence. Prefer further candidate selection or explicit measured no-go unless an existing safe backend can cover this closure at demonstrably lower cost. Python-only shortcuts would omit mandatory parity coverage and are not an equivalent optimization.

## Reproduction and preserved artifacts

`evaluate.py` records exact commands, timeout, environment and pre/post file hashes. Existing run directories intentionally cannot be overwritten; use a new output directory for fresh reproduction. protocol.json, source.tar/source hashes, runtime identities, run-1/2.log, receipt-1/2.json, measure-1/2 records, summary-1/2.json and results.json are original retained observations. No native model comparison, user acceptance or production approval is claimed.

Packaging note: `raw-evidence.zip` preserves measurements, receipts, logs, protocol, runtime identities, evaluator and source hashes. The redundant full export and source.tar remain in the original scratch directory, not this archive. Reconstruct the source using `git archive bda9e3dcc8ca282d1fcfc0bc761303d7a6f5309d` and check `source-archive-sha256.txt` and `source-hashes.json`. Extract into a new scratch directory; inspect and adapt historical absolute paths in the protocol before a new run. Never overwrite archived observations. The outer `archive-index.json` lists only packaged members.
