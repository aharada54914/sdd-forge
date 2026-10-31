# A8 AC-016 inventory candidate experiment

Status: candidate-only; not a formal review, implementation completion, or native-host proof.

Owner checkout: `/Users/jrmag/.codex/worktrees/a8-release-sync-oct01/sdd-forge`.
Observed HEAD: `495c88d67af44530687ecea3ce9fb0a90a336539`.

## Inputs

- `reports/verification/a8-ac016-inventory-candidate-20261006.md`: SHA-256 `f81af0f41c4e3331c84638805b0e3325fe472013f6fd9e9351843f333f75b366`.
- `reports/verification/a8-ac016-inventory-prototype-20261006.py`: SHA-256 `a400388bca1bba1ccf1bf32daef24c68982b35ee2633180e2cf6d331d39cb2fd`.

## Executed experiment

Command, from owner checkout:

```sh
rtk proxy python3 -B reports/verification/a8-ac016-inventory-prototype-20261006.py
```

Final execution returned 0:

```text
test_complete_each_cell_and_existing_signatures ... ok
test_inventory_mutation_breaks_existing_two_signature_target ... ok
test_red_current_validator_discharges_without_consumer_inventory ... ok
test_rejection_matrix ... ok
test_source_inventory_matches_actual_git_objects ... ok

Ran 5 tests in 0.350s
OK
RED reproduced: current validator discharges AC-015 fixtures without AC-016 observations
```

The RED observation uses the unmodified existing validator: a valid AC-015 fixture is discharged without per-consumer observations. This demonstrates the AC-016 evidence gap, not failure of an already-implemented AC-015 requirement. The candidate experiment checks five cells, twelve rejection mutations for each cell, post-signature inventory mutation for each cell, and the existing source inventory against actual Git objects.

The first prototype run failed because an extra path-prefix check supplied a trailing slash to a helper that adds its own slash. The prototype was corrected to use the existing `safe_repo_file` check directly; the production validator was not changed.

## Boundaries and next operation

The source inventory proves source availability only. It does not prove the five consumers executed in each cell. The candidate adds distinct request/result references and hashes under the existing two whole-record JCS signatures; the prototype uses synthetic fixture keys and captures. Actual consumer invocation, session binding and real operator attestations remain unproven.

No protected original, frozen artifact, approval, task status, verdict, identity reservation or Git history was changed. No CI or native host execution ran. The existing A9 round-2 NEEDS_WORK remains authoritative.

Next: owner coordinates the minimal AC-016/version amendment and normal adoption scope described in the candidate, then implements and tests the actual validator/fixture path. Do not reserve another formal review until that coordination and the ordinary prerequisites are satisfied. Preserve old v1 signed records; never relabel them as v2 evidence.
