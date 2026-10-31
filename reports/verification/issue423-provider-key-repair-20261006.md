# RT-20261006-002 repair preflight

- Issue/task: #423 / sdd-domain-multitarget T-002.
- Owner: issue423-approved-recovery/sdd-forge; HEAD 3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9.
- Existing dirty changes are retained, including the already-modified validator and historical review records. This repair owns only the incremental provider-key check and its existing boundary suite.
- Risk: protected contract enforcement. Formal workflow and sanctioned application remain required.
- Contract: REQ-002, T-002 provider neutrality, existing case-insensitive provider vocabulary and diagnostic format. No new vocabulary or acceptance relaxation.
- Root cause: the shared recursive dictionary branch visits values but not keys; both trigger and conditional predicates reach it through run/check_g_provider_name_contamination.
- Persisted evidence: no new fields. Existing boolean rejection and provider-name-detected diagnostics must agree; negative tests assert both, with schema-valid direct/nested/list keys in both predicate boundaries. Neutral controls must remain accepted.
- Validation: demonstrate new negatives fail before the fix; run the complete contract-boundaries suite and existing Bash/PowerShell registry suites after it; independently review exact bytes before a fresh quality cycle. Distribution, formal gate, native activation and CI are separate pending conditions.
- RED: the new test failed against the original validator in all 192 subcases (exit 1).
- GREEN: dictionary keys now use the existing string walker. Full contract boundaries: 29 tests passed; registry Bash: 27 passed; registry PowerShell on macOS: 27 passed. All exited 0. This is not native Windows evidence.
- The independent evaluator's original reproduction now rejects all four bypass inputs, with no schema errors and provider-name-detected diagnostics. Existing string-value controls also remain rejected.
- `git diff --check`: exit 0.
- Verified validator SHA-256: `843f473f1234572426d1a4b23e6a4cd03515dc214ae3b9b16590df7ed9f819c5`.
- Verified boundary suite SHA-256: `cb053e841ca41379ee7a0313e0132e9baca4efc05b66051a5f1fe143ff4793ca`.
- Independent limited diff review: session `01a1109f-c67e-75f1-8682-b4b4ba72ffc6`, turn `01a110b4-914c-7a42-99ff-e2a68fcdb231`, completed with no additional findings. It independently reran 29 boundary tests, 27 Bash checks and 27 PowerShell checks on macOS; reconstructed the old walker in memory and observed all 192 new cases fail; verified four original bypasses rejected and six neutral inputs unchanged. This is not a formal quality verdict.
- Distribution runner now pins the repaired validator above; installer and discovery-helper hashes were rechecked unchanged. Historical build logs remain intact and prove only the old validator. The refreshed human-only runner has not been executed.
- Status: local repair, affected regressions and independent limited diff review passed. Fresh formal gate, updated distribution evidence, CI and merge remain pending. Historical NEEDS_WORK and task status remain unchanged.
