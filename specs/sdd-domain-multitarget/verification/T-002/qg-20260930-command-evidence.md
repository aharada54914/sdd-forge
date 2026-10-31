# T-002 quality-gate command evidence, 2026-09-30 UTC

Commands ran from the repository root via `rtk proxy`. These are captured final outputs and exit codes, not inferred PASS claims.

## Focused unit, acceptance, and regression suite

Command: `rtk proxy python3 specs/sdd-domain-multitarget/verification/T-002/contract-boundaries.tests.py --repo-root . -q`

Exit: 0

```text
----------------------------------------------------------------------
Ran 28 tests in 0.067s

OK
```

The same 28-method suite also passed in verbose mode before this gate; `nested-state-extra1-evidence.json` retains its original red/green proof.

## Scripted checks

Command: `rtk proxy sh plugins/sdd-quality-loop/scripts/check-risk.sh specs/sdd-domain-multitarget/tasks.md T-002`

Exit: 0

```text
Risk check passed for task T-002.
```

Command: `rtk proxy sh plugins/sdd-quality-loop/scripts/check-placeholders.sh contracts/project-context.schema.json contracts/context-projection.schema.json plugins/sdd-quality-loop/contracts/context-projection.schema.json plugins/sdd-quality-loop/scripts/validate-capability-registry.py`

Exit: 0

```text
Placeholder scan passed.
```

Command: `rtk proxy bash plugins/sdd-quality-loop/scripts/check-workflow-state.sh`

Exit: 0; two repeated `epic-196-a8-integration` and two repeated `epic-195-a7-compatibility` amendment-growth tolerances were reported, followed by:

```text
workflow-state: ok
```

An initial `sh` invocation exited 2 on Bash-only syntax at line 677; it is not counted as the workflow-state verdict.

Command: `rtk proxy sh plugins/sdd-quality-loop/scripts/check-task-state.sh specs/sdd-domain-multitarget/tasks.md reports/quality-gate reports/implementation .`

Exit: 0

```text
Task state check passed for 6 task(s).
```

## Blocking canonical Registry validation

Command: `rtk proxy sh plugins/sdd-quality-loop/scripts/validate-capability-registry.sh --registry contracts/capability-registry.json`

Exit: 1

```text
registry: implementation-ref-missing: check-update-migration (path does not exist: plugins/sdd-quality-loop/scripts/check-update-migration.py)
registry: unregistered-script: plugins/sdd-quality-loop/scripts/check-component-coverage.py
registry: unregistered-script: plugins/sdd-quality-loop/scripts/check-contract.py
registry: unregistered-script: plugins/sdd-quality-loop/scripts/check-criterion-freeze.py
registry: unregistered-script: plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py
```

Command: `rtk proxy git diff --check`

Exit: 0, no output.
