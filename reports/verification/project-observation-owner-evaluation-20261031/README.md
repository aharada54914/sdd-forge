# Independent observation v2 → owner evaluation

No repository implementation was edited. `evaluate.py` imports existing isolated collector and selected-plan fixtures, creates temporary project roots, executes actual project runners, and removes those roots. `result.json` preserves the receipts and tested product hashes.

## Selected-plan path

The existing medium-risk Registry/Facet Manifest selected-plan fixture retains every required baseline check. Its selected `cli-library` observation starts incomplete, so the owner returns BLOCKED. An actual project runner creates observation v2; the collector replaces exactly this check in a derived contract. The real selected-plan CLI then returns PASS. The original contract and all required booleans/IDs remain unchanged. Removing the separate required `unit-tests` check returns BLOCKED despite the collected project check passing.

This verifies adapter connectivity and required-set ownership. The other baseline checks retain the test fixture's synthetic evidence: this is not a real Full project's quality-gate acceptance, approval, or completion. The owner consumes the derived ordinary contract, not raw observation JSON; fresh v2/runtime validation happens at collection/projection.

## Lite path

An explicit fixture `scripts/emit-proof.sh` / `.ps1` adapter invokes the actual project runner under the unchanged Lite gate executor. The summary requires `emit-proof`; an explicit baseline `test` is also executed. Linux POSIX and Linux PowerShell both pass. A baseline exit 7 still makes Lite FAIL while the project observation is passed. Absence of prior observation and an unrelated forged v999 observation produce the same owner outcome. The runner creates fresh observation v2 in each case.

There is no automatic import of arbitrary observation files into the Lite required set. Existing script/CLI wiring is necessary; adding observation support does not select, waive, or replace owner checks.

## Negative identities and existing tests

Unknown schema/toolchain shape is rejected as `observation-invalid`. Changed toolchain digest and environment fingerprint are rejected as `runtime-changed`. Observation v1 remains `legacy-runtime-unbound` and cannot project a `passes` field.

Existing suites: collector 21 passed; observation 37 passed; selected-plan 32 run with 1 real-Windows-junction skip and no failures; Lite CLI chain 8 passed. Native Windows/macOS and actual Full approval workflows were not executed. All capability/context fixtures here remain explicitly synthetic, even where the project subprocess is real.
