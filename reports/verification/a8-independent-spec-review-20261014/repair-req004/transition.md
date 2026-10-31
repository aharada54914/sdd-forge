# REQ-004 scoped specification correction — 2026-10-14

This is a non-frozen development record, not a formal review or quality-gate verdict.

- Owner: `/Users/jrmag/.codex/worktrees/a8-release-sync-oct01/sdd-forge`.
- HEAD before correction: `495c88d67af44530687ecea3ce9fb0a90a336539` (detached).
- Existing dirty state: 184 status entries, including 29 tracked modifications. All unrelated work is preserved.
- Scope: issue #196 / A8, REQ-004; T-006 remains Approved (`sudo 2026-08-08T16:33:11Z`), Planned, Risk medium, with dependencies T-001/T-002/T-003 (ordering) and T-005 (functional). No implementation or task-state transition is authorized here.
- Governance classification: amendment of an existing reviewed specification; retain its formal lifecycle rather than treating this as routine unbound work. Applicable instructions: root AGENTS.md; no nested AGENTS.md under specs or reports. Development policy lines 65–102 requires retained old inputs and fresh review for changed bytes.
- Authority: parent delegated the user's already-approved limited correction on 2026-10-14: constrain REQ-004's `.gitattributes` oracle to text/EOL and explicitly assign Unicode to AC-020's dedicated contract. The separate user-approved independent Codex route has no conversation inheritance, does not use the old formal ledger, and does not require product hooks. This record does not broaden that exception or waive later gates.
- Trigger: independent reviewer `/root/a8_independent_spec_oct14` reported NEEDS_WORK, Major 1: REQ-004's all-fixture `.gitattributes` oracle contradicts AC-020, the Unicode-normalization definition, and TEST-020. Its original JSON values and order, delivered directly by that reviewer, are preserved in `review-before.json` (whitespace reformatted; JSON parsing checked). This historical result applies only to the pre-edit input hashes it lists.
- Acceptance obligations unchanged: AC-018–AC-021 and TEST-018–TEST-021; preserve the path/EOL/Unicode pairwise matrix and Epic A1 non-goal.

## Preserved inputs and historical boundary

`requirements.before.md` is the complete pre-edit requirements input, SHA-256 `9d14fb9f40153e53f63d2d88e45366473d0054699d50330697dd36477851e1e4`. The existing attempt-4/round-1 precheck remains unchanged, SHA-256 `3718c701f23907c710c3c98cb1cc64faec5d906bdbd577b2882c92d5bca32467`. Its old requirements hash is historical and cannot admit the revised requirements. Identity ledger remains unchanged, SHA-256 `c95ef67d1c227c8d31320a2dd526d50940dd52745240189e7e29eb9460986264`.

No historical PASS proves the changed bytes. No old precheck is rerun or overwritten, no reviewer is reserved, and no formal ledger/status field is edited. Requirements remains Pending. The correction must receive a fresh independent review with its new hash before being presented as reviewed.

## Required validation

Compare exact pre/post diff; verify preserved preimage and unchanged acceptance/investigation/calibration/precheck/ledger hashes; sweep REQ-004, AC-020, TEST-020, Unicode-normalization and `.gitattributes` across requirements, acceptance, investigation, design, all four layers, tasks, and traceability. Only the inconsistent REQ-004 oracle sentence may change. The sweep is consistency diagnosis, not independent review or runtime test evidence.

## Executed validation

- Exact `diff -u` against `requirements.before.md`: one hunk only, replacing the three-line all-fixture oracle with five lines distinguishing text/EOL from Unicode. Exit 1 means the expected difference, not validation failure.
- `git diff --check -- specs/epic-196-a8-integration/requirements.md`: exit 0.
- New requirements SHA-256: `244f2c539a8242e36fe7a2d88a04b32476c15306534fa83db043bc0132b9775e`.
- Preimage hash matches the historical requirements hash above. Unchanged inputs: acceptance `60b2696d14cc9438a58c3c258c2117531249564c3aaa7c7c2b1500ce70bbcf4b`; investigation `888868de019e903375b3cf8b8d25c89f2abf84b950178e99afb534ab8495a77f`; calibration `537f776558cf4b4a99ee455a974857a67e249242dce5806e23d37d6802f2a385`. Precheck and ledger match their preserved hashes above.
- Identifier sweep completed across the ten listed governing documents: revised requirements lines 174–178 agrees with AC-020 lines 472–486, glossary lines 638–643, acceptance TEST-020 line 24, design Unicode contract lines 906–915 and matrix line 1544, frontend text/EOL line 51, tasks lines 1194–1206, and traceability line 25. Other identifier hits are matrix/coverage references, not alternate normalization oracles. Investigation INV-022 line 61 already distinguishes git text/EOL from Epic A1 canonicalization and needs no supersession edit. Historical candidate copies were left untouched.
- Requirements line 3 remains `Spec-Review-Status: Pending`. No PASS, approval, task status, old review result, or ledger mutation. Native/runtime/CI tests not run for this prose-only correction; fresh independent specification re-review remains required.

## Independent re-review and next dependency

After the validation above, `/root/a8_remaining_oct14/fresh_a8_spec_after_req004` was launched with `fork_turns: none`, the five exact input paths/hashes, and no prior verdict or repair discussion. It independently returned PASS with no findings; the returned JSON values/order are preserved in `review-after.json` (whitespace reformatted). This satisfies the user-approved independent specification review only: `formal_sdd_gate` remains false, the old precheck is historical, and no formal status was promoted.

Next, tasks.md lines 1692–1693 explicitly requires independent re-review of affected design and task inputs before implementing the AC-016 delta. Design lines 1840–1893 defines v2 inventory and source/signature rules; tasks lines 1674–1693 assigns validator/negative coverage to T-005 and five-cell inventory population to T-008. Their historical Passed headers do not prove the amended bytes. T-005 remains Planned and depends on T-001/T-002; T-008 remains Planned with its declared dependencies. No implementation is authorized merely by this specification result.
