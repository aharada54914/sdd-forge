# BLOCKED continuation v2: independent technical review

Date: 2026-10-05
Owner: `/Users/jrmag/.codex/worktrees/a8-release-sync-oct01/sdd-forge`
Observed HEAD: `495c88d67af44530687ecea3ce9fb0a90a336539`
Scope: four-file candidate diff, caller and canonical history validators, disposable regressions. This is not a formal SDD review or quality-gate verdict.
Risk: high. Existing dirty changes retained; no protected sources, original history, reservations, approvals or task states edited.

Reviewed patch SHA256: `23b6de2e8887170f5ae827b658162ab4439408182417cf2c37ed1377962db17e`
Reviewed runner SHA256: `4747d2b0ed21ff76e4859209cbe9a7a462e297d8541c80d0c2061342dc4a1b61`

## Finding: P2 / Major — legacy BLOCKED continuation regresses

Locations: new branch in candidate `plugins/sdd-review-loop/scripts/impl-review-precheck.sh:392-397` and `plugins/sdd-review-loop/scripts/impl-review-precheck.ps1:730-734`.

The new explicit history validator deliberately requires `adr_inputs`. However, both prechecks invoke it for every BLOCKED previous contract before determining whether that history has the ADR extension. Existing legacy handling explicitly allows paired absence of the extension and preserves design-only progress (Bash original lines 494-500; PowerShell `Get-AdrPreviousRoundJson` returns null for the legacy branch). Thus an existing legacy BLOCKED round that formerly allowed correction becomes impossible to continue.

Reproduced with a disposable Pending/no-tasks fixture: preserve BLOCKED findings/verdicts; omit both contract/precheck ADR extensions and remove ADR manifest entries to model legacy history; correct current design differs from the historical design. Run original and candidate precheck entrypoints on the same copied data.

| Runtime | Original precheck | v2 precheck |
|---|---|---|
| Bash | exit 0; round-2 emitted | exit 1; no output round; `explicit ADR history validation requires binding extension` |
| PowerShell | exit 0; round-2 emitted | exit 1; no output round; `explicit ADR history validation failed` |

Reproduction: `/tmp/a8-v2-legacy-review.py`.
Fixture: `/var/folders/7z/hjmz6jdj4wb40srf64sl368w0000gn/T/a8-v2-legacy-review-7oap1vu8`.

Minimal repair direction: preserve the existing paired-extension/legacy decision, and invoke the new mandatory history validation for ADR-extended BLOCKED rounds only. Keep one-sided or malformed extensions rejected. Retain the existing legacy design-change and reviewer-agreement checks. Add a legacy BLOCKED continuation regression on both runtimes; the current generation suite's legacy example does not cover this verdict. If rejecting legacy BLOCKED is intended policy, it needs explicit scope/contract authority rather than being presented as unchanged behavior.

## Previous finding and verification

The v1 Pending/count-bypass finding is resolved in v2 for ADR-extended history: `--impl-history` calls `workflow_adr_history_bindings` / `Read-AdrHistoryEvidence` directly, independently of status. These existing validators recalculate reviewer and aggregate counts, bind verdict/identity/manifests, and compare explicit feature/attempt/round. The added caller failure is fatal even after provenance advisory failure. `assert_contract_reviewer_agreement` only compares core document hashes and is not relied upon for count checks.

Independently reran the final-byte v2 runner: exit 0, `owner_history_unchanged=true; failures=0`. This includes 2 RED assertions, 36 Passed/Pending GREEN assertions, unchanged ADR generation 30/0, and 18 direct CLI assertions. Retained fixture: `/var/folders/7z/hjmz6jdj4wb40srf64sl368w0000gn/T/a8-blocked-candidate-x5p_zy38`.

Additional independently authored CLI/evidence negatives: 18/18 rejected on Bash and PowerShell, covering terminal newline, leading zero, negative/decimal/missing/extra numeric fields, oversized integer, unknown feature, and persisted attempt mismatch. Script: `/tmp/a8-v2-independent-cli.py`; fixture: `/var/folders/7z/hjmz6jdj4wb40srf64sl368w0000gn/T/a8-v2-independent-cli-tk3h9gnu`.

No new CLI bypass was found in those cases. Normal no-flag dispatch remains textually unchanged, but the new caller's legacy BLOCKED regression above prevents accepting the candidate as behavior-preserving. Recommendation: repair this finding before application. Full workflow suite, Windows-native execution, formal review, protected application and exact-final-head CI remain outside this technical review.
