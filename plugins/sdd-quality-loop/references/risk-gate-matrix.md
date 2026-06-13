# Risk → Gate Matrix

This is the **canonical** mapping from a task's `risk` tier to the set of checks
that `check-contract.(sh|ps1)` requires to be `passes:true` with evidence. The
gate enforces that a contract's `required:true` set is a **superset** of its
tier's minimum (a contract may add more, never fewer). Each higher tier's minimum
is a superset of the tier below it.

> Invariant tested by `tests/gates.tests.sh` (T-003): the tier-minimum sets encoded
> in `check-contract` MUST equal the `Required check ids` lists below. If you change
> one, change both.

## Matrix

`✓` = required (must pass with evidence). `—` = not mandated by the tier (may be
present as an optional check with a `waiver_reason`).

| Check / control            | low | medium | high | critical |
|----------------------------|:---:|:------:|:----:|:--------:|
| lint                       |  ✓  |   ✓    |  ✓   |    ✓     |
| typecheck                  |  ✓  |   ✓    |  ✓   |    ✓     |
| build                      |  ✓  |   ✓    |  ✓   |    ✓     |
| placeholder-scan           |  ✓  |   ✓    |  ✓   |    ✓     |
| task-state-check           |  ✓  |   ✓    |  ✓   |    ✓     |
| unit-tests                 | —¹  |   ✓    |  ✓   |    ✓     |
| acceptance-tests           |  —  |   ✓    |  ✓   |    ✓     |
| regression (related tests) |  —  |   ✓    |  ✓   |    ✓     |
| red→green evidence (tdd)   |  —  |   —    |  ✓²  |    ✓²    |
| requirement-traceability   |  —  |   —    |  ✓   |    ✓     |
| independent-review verdict |  —  |   —    |  ✓   |    ✓     |
| provenance (spec_rev+env)  |  —  |   —    |  ✓   |    ✓     |
| evidence-bundle signature  |  —  |   —    |  —   |    ✓     |
| two-person approval        |  —  |   —    |  —   |    ✓     |

¹ `low`: `unit-tests` may be `required:false` **only** with a non-empty `waiver_reason`.
² Enforced as: when `required_workflow == "tdd"`, every test-type check must carry
  non-empty, existing, path-safe `red_evidence` **and** `green_evidence`.

## Required check ids (machine form — the gate's source of truth)

These id sets are the contract-check ids `check-contract` requires per tier. The
controls above the line that are not contract checks (signature, two-person
approval, provenance) are enforced by `check-evidence-bundle` / `check-task-state`,
not by the contract required-set — they are listed in the matrix for completeness.

```
low      = { lint, typecheck, build, placeholder-scan, task-state-check }
medium   = low      ∪ { unit-tests, acceptance-tests, regression }
high     = medium   ∪ { requirement-traceability }      # + tdd red/green, provenance via other gates
critical = high                                         # + signature, two-person via other gates
```

Notes:
- `low` deliberately omits `unit-tests` from the required set (test-after); it is
  still a baseline id and, if present as `required:false`, needs a `waiver_reason`
  (preserves existing baseline-protection rule in `check-contract`).
- `regression` and `acceptance-tests` are contract-check ids whose evidence is the
  related/acceptance test run output.
- `requirement-traceability` as a contract check means "`check-traceability` passed
  and its report is recorded as evidence".

## Cross-gate enforcement summary

| Concern | Enforced by |
|---------|-------------|
| tier required-set superset | `check-contract` |
| tdd Red→Green evidence | `check-contract` (when `required_workflow == tdd`) |
| `spec_revision` present (high/critical) | `check-contract` + `check-evidence-bundle` |
| provenance fields, `review_verdict == PASS` (high/critical) | `check-evidence-bundle` |
| bundle signature, reject dirty tree (critical) | `check-evidence-bundle` |
| distinct `Second Approval` (critical) | `check-task-state` |
| REQ→AC→TEST→evidence chain | `check-traceability` |

## Backward compatibility

A contract with no `risk` field is treated as `medium` for required-set purposes,
which equals the historical BASELINE_IDS behavior — pre-feature contracts and
their tests pass unchanged.
