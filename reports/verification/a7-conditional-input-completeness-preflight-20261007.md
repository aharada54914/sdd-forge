# A7 conditional review-input completeness repair: preflight

- Issue/task: A7 shared review-context admission repair (fresh spec/impl conditional dependencies).
- Owning checkout: `/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge`.
- Starting HEAD: `25813ee4baf8ae8fff344a6c979da61fbd23d2c7`.
- Dirty state: both validators already modified; `tests/review-conditional-inputs.tests.py` and many A7 verification records untracked. Preserve all unrelated content.
- Risk: high; this changes reviewer input/evidence admission semantics, not a routine correction.
- Affected contract: fresh review-context manifests must bind all selected conditional inputs; persisted reservations keep their historical manifest and live path/hash/binding checks.
- Validation: fixture-only Bash/PowerShell preview and reserve negative cases, historical reservation compatibility, affected existing regression suites, independent diff review. No canonical ledger reservation, installed-host claim, task-state transition, or CI claim.

## Evidence-field mismatch preflight

| Persisted evidence field | Counterpart | Failing mismatch test before implementation |
|---|---|---|
| `allowed_input_manifest[].path` and `.sha256` for fresh spec/impl | Every selected `review-conditional-inputs.py` `.inputs[]` path/hash | Omit one selected member and omit all selected members; preview and reserve must reject. A wrong hash must reject. |
| `allowed_inputs_sha256` in a persisted identity record | Ordered `allowed_input_manifest` path/hash binding | Reserve a fixture identity, then alter its manifest path/hash and require rejection. |
| Persisted `run_id`, `host_session_id`, `sequence`, `stage`, `role`, `previous_record_sha256` | The exact identity-ledger record | Reverify the same fixture reservation after later conditional inputs become selected; old bound inputs must remain valid, while duplicate reserve is rejected. |

No verdict field or traceability claim is changed or persisted by this repair.

## Local verification (2026-10-07)

- RED before fix: both runtimes accepted `omit-one` and `omit-all` in fresh preview and fixture reserve (eight failing assertions). The test reset the disposable fixture ledger before every mode.
- GREEN after fix: `python3 -B tests/review-conditional-inputs.tests.py` — 13 tests passed, covering spec domain pair, impl design-system triplet, invalid preview/reserve ledger unchanged, historical reservation after new conditional selection, duplicate reserve rejection, and persisted binding/live-file mismatch rejection.
- `python3 -B tests/downstream-conditional-manifest.tests.py` — 2 tests passed.
- `bash -n plugins/sdd-quality-loop/scripts/validate-review-context-set.sh` and `git diff --check` — passed.
- `bash tests/review-context-boundary.tests.sh` — NOT RUN to completion: its first assertion fails because `review-context-boundary.md` cites `validate-review-context-set.sh:367`, but that previously dirty source no longer has the cited construct there. This occurs before the changed admission branch; it is not evidence of behavioral regression passing.
- Independent diff review, exact-final-head CI, native installed-host verification and formal review — not yet performed.
