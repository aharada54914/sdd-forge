# BLOCKED continuation v3: independent technical re-review

Date: 2026-10-05
Owner: `/Users/jrmag/.codex/worktrees/a8-release-sync-oct01/sdd-forge`
Observed HEAD: `495c88d67af44530687ecea3ce9fb0a90a336539`
Scope: four-file candidate diff, existing callers and canonical history validators, isolated regressions. Risk: high. This is not a formal SDD review, quality-gate verdict, approval, or protected-application authority.

Reviewed final patch: `a8-blocked-continuation-v3-20261005.patch`, SHA256 `5d9463812a38d4a85f26e82fc10c4f194f4a4f95f04b13b45831bfd5ac4d803b`.
Reviewed final runner: `a8-blocked-continuation-v3.tests.py`, SHA256 `1c6ac6f754cb844fe26aeade69328d149b31540e08a7774cf4723995644e65b3`.

## Result

No actionable defect found in the final candidate within this bounded review. Both earlier findings are resolved; retain the v1/v2 reports as historical evidence, not amended verdicts.

- The v1 Pending/count bypass is closed: explicit `--impl-history` dispatch invokes existing `workflow_adr_history_bindings` / `Read-AdrHistoryEvidence` independently of current design status. Pending/no-tasks and Passed/provenance-rereview fixtures both reject forged critical/major counts, verdict mismatch, reviewer identity and manifest hash mismatch. The explicit history failure remains fatal after the outer provenance-advisory failure.
- The v2 legacy regression is closed: Bash invokes history validation only after paired ADR extension detection; PowerShell does so after its existing legacy return. Both runtimes accept the same legacy BLOCKED/design-change scenario and reject each one-sided extension with the intended diagnostic. Existing legacy behavior was preserved, not newly strengthened.
- ADR-extended BLOCKED continuation is allowed only before round 3; attempts to continue a terminal round are rejected. Existing NEEDS_WORK behavior is unchanged. No-flag workflow-state dispatch is textually unchanged; the new mode has a distinct success marker and does not claim lifecycle completion.
- Canonical validator internals are reused unchanged: snapshot-bound hashes, reviewer identities/roles, counts and verdict agreement remain authoritative. The core-only `assert_contract_reviewer_agreement` is not mistaken for a counts validator. PowerShell child stdout is suppressed inside the JSON-returning helper.

## Executed evidence

Final-byte independent runner execution: exit 0; `owner_history_unchanged=true; failures=0`.

- 2 baseline RED assertions.
- 36 Passed/Pending assertions across Bash and PowerShell, including legitimate BLOCKED, forged counts, integrated verdict, run identity, case/unknown verdict, manifest hash and round cap.
- 6 legacy/one-sided assertions, with success/output-round and intended diagnostic checks.
- Existing ADR generation regression: `passed=30 failed=0` (design and ADR-only changes, unchanged inputs, legacy behavior, extension mismatches, reservation/output hash mismatches).
- 18 direct CLI assertions: positive exact history, missing feature/value, zero, option case, repeated history option, incompatible opening mode, unsafe feature and absent round.

Final-run fixture: `/var/folders/7z/hjmz6jdj4wb40srf64sl368w0000gn/T/a8-blocked-candidate-xy0v_ra9`.

Additional independent negative tests: 24/24 rejected across both runtimes. The 18 CLI/evidence cases cover terminal newline, leading zero, negative/decimal/missing/extra numeric fields, oversized integer, unknown feature and persisted attempt mismatch. Six additional cases mutate reviewer role, persisted feature and persisted round. Fixture: `/var/folders/7z/hjmz6jdj4wb40srf64sl368w0000gn/T/a8-v2-independent-cli-pp858c8l` (name retained from reused independent driver; v3 patch was applied). Drivers: `/tmp/a8-v2-independent-cli.py` executed with the patch filename replaced in memory, and `/tmp/a8-v3-extra-history-review.py`.

An earlier v3 runner (SHA256 `182a8d7c3b9ef2fffc57ee0a6bae5064fa1af1c45efc5aa8b6aafe270b0bfdd2`) failed 6 legacy assertions because its new fixture loop appended literal backslash-n to JSON. This was reported to the author and repaired before the final run above. That failed run is not counted as final verification. Its fixture is retained at `/var/folders/7z/hjmz6jdj4wb40srf64sl368w0000gn/T/a8-blocked-candidate-zzb91xx6`.

## Boundaries

Review used the reviewer skill's concrete-reproduction and regression criteria. Original candidate sources, protected product files, historical evidence, ledger/reservations, approvals and task states were not edited by this reviewer. Existing dirty work was preserved. Only disposable fixtures and this new non-frozen report were written.

Full workflow suite, Windows-native execution, formal SDD review, protected application/readback, exact-final-head CI and delivery status remain unverified by this technical review. No task is declared Done and no previous verdict is replaced.
