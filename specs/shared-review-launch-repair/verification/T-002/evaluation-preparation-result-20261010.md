# T-002 evaluation input preparation

Status: BLOCKED before reservation or evaluator launch.

The bounded helper reuses `reports/verification/shared-launch-handoff/prepare-t005-evaluation.py` with explicit, checked substitutions for T-002, its authentic implementation manifest, 242 Outputs, and an invocation under T-002 verification. Source digest and checkout/dirty scope are recorded in `evaluation-preparation-scope-20261010.json`. No source, report, task state, or identity ledger was changed.

## Successful preparation

- Declaration: `specs/shared-review-launch-repair/verification/T-002/supplemental-delivery-corrected-20261010.json`
- Declaration SHA-256: `87f64a1e26e0a3214c0cf2dd1d1ba3d3c20522a1f2c46329ae5cd46b53f2ed8c`
- Invocation: `specs/shared-review-launch-repair/verification/T-002/evaluation-input-f50ccdad-d20d-41e2-a3d3-0fe24f0e5d23.json`
- Invocation SHA-256: `6cbdf13cb9df5163db8de56aee0fd9043e59113523217d4cc1d0d026131942d1`
- Scratch: `/private/var/folders/7z/hjmz6jdj4wb40srf64sl368w0000gn/T/sdd-t002-evaluator-zzgpjozf`
- 269 unique allowed inputs copied and rehashed; all 242 canonical report Outputs match. Supplemental declaration resolver succeeded.
- Supplemental artifacts retain authentic historical extraction RED, current native four-suite GREEN, deterministic checks, corrected contract, and old failed check/harness logs. Historical structural RED is ordinary refactoring TDD evidence; fixture failures and iconv PATH failure are not RED. RT-20261009-001 remains T-001-only.

## Actual commands and results

Working directory: `/Users/jrmag/.codex/worktrees/shared-review-launch-integration/sdd-forge`.

```sh
rtk proxy python3 -B plugins/sdd-quality-loop/scripts/preflight-evaluator-delivery.py --manifest specs/shared-review-launch-repair/verification/T-002/evaluation-input-f50ccdad-d20d-41e2-a3d3-0fe24f0e5d23.json --manifest-sha256 6cbdf13cb9df5163db8de56aee0fd9043e59113523217d4cc1d0d026131942d1 --repository-root /Users/jrmag/.codex/worktrees/shared-review-launch-integration/sdd-forge --scratch-root /private/var/folders/7z/hjmz6jdj4wb40srf64sl368w0000gn/T/sdd-t002-evaluator-zzgpjozf
```

Exit 1; output:

```text
EVALUATOR_DELIVERY_REJECTED: canonical-contract
```

Read-only diagnostic:

```sh
rtk proxy bash plugins/sdd-quality-loop/scripts/validate-review-context-set.sh /Users/jrmag/.codex/worktrees/shared-review-launch-integration/sdd-forge/specs/shared-review-launch-repair/verification/T-002/evaluation-input-f50ccdad-d20d-41e2-a3d3-0fe24f0e5d23.json /Users/jrmag/.codex/worktrees/shared-review-launch-integration/sdd-forge
```

Exit 1; output:

```text
REVIEW_CONTEXT_CONTRACT: required fields, file-manifest input, read-only mode, or no-fallback contract is invalid
```

Cause: `plugins/sdd-quality-loop/scripts/validate-review-context-set.sh:440` requires `implementation_manifest.path` to match `^handoffs/[A-Za-z0-9._-]+/manifest(-[A-Za-z0-9][A-Za-z0-9_-]*)?[.]json$`. The canonical implementation report identifies the authentic manifest at `specs/shared-review-launch-repair/verification/T-002/admission-attempt-3-20261010/manifest.json`, which is outside that grammar. No alias, copy, report rewrite, manifest relocation, validator change, or alternate executor was attempted. Later canonical checks are NOT EVALUATED. No formal reviewer verdict exists from this preparation.

The recorded invocation is unreserved and binds the ledger tip when prepared; it must not be reserved after ledger drift without fresh preparation. The helper uses exclusive creation to preserve prior attempts. The command above is the exact non-reserving recheck, not authorization to reserve or launch.
