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
| cross-model-verification   |  —  |   —    |  ◐³  |    ✓³    |

¹ `low`: `unit-tests` may be `required:false` **only** with a non-empty `waiver_reason`.
² Enforced as: when `required_workflow == "tdd"`, every test-type check must carry
  non-empty, existing, path-safe `red_evidence` **and** `green_evidence`.
³ `◐` = opt-in (high), `✓` = required (critical). Like `signature`/`two-person`, this
  is a **conditional control**, NOT part of the machine-form `RISK_TIERS` set below.
  It activates only when a contract declares the `cross_model` descriptor
  (`required` ⇒ a passing `cross-model-verification` check; `waived` ⇒ that check
  `required:false` with a `waiver_reason`; absent/`legacy` ⇒ no enforcement,
  backward compatible). Enforced by `check-contract` Pass 6; the consensus itself is
  computed by `check-cross-model` (see `references/cross-model-verification-policy.md`).

## Stack descriptor (toolchain applicability)

The tier minimums above are calibrated for compiled application code. A repository
without a compile toolchain (pure shell / Markdown / JSON / docs) genuinely cannot
satisfy `lint` / `typecheck` / `build` — forcing them `required:true` would invite
fabricated evidence. The optional contract field `stack` resolves this:

| `stack` value          | effect on the tier minimum |
|------------------------|----------------------------|
| absent / `""` / `code` | **legacy/default** — `lint`/`typecheck`/`build` stay `required:true` (no change) |
| `shell` / `docs` / `spec` | the three **compile-oriented** checks `{lint, typecheck, build}` may be `required:false` **with a non-empty `waiver_reason`** |

Hard rules (enforced by `check-contract` Pass 4, tested in `tests/gates.tests.sh`
T-012 and `tests/scripts.tests.ps1`):

- **Only** `{lint, typecheck, build}` become waivable on a non-code stack. Every
  test/quality check — `unit-tests`, `acceptance-tests`, `regression`,
  `requirement-traceability`, `placeholder-scan`, `task-state-check` — stays
  mandatory at its tier for **all** stacks. A code task cannot set `stack: docs`
  to skip its tests.
- A waived compile check still needs a non-empty `waiver_reason` (Pass 2/3).
- An unknown `stack` value fails the gate (`contract stack is invalid: <value>`)
  and falls back to the strictest (`code`) interpretation for the rest of the pass.

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
| `high`/`critical` task declares `Required Workflow: tdd` | `check-risk` (task-level, before contract) |
| tdd Red→Green evidence | `check-contract` (when `required_workflow == tdd`) |
| `spec_revision` present (high/critical) | `check-contract` + `check-evidence-bundle` |
| provenance fields, `review_verdict == PASS` (high/critical) | `check-evidence-bundle` |
| bundle signature, reject dirty tree (critical) | `check-evidence-bundle` |
| distinct `Second Approval` (critical) | `check-task-state` |
| REQ→AC→TEST→evidence chain | `check-traceability` |

## Backward compatibility

A contract with **no** `risk` field runs in **legacy mode**: `check-contract`
applies only its historical behavior (baseline-protection of {lint, typecheck,
unit-tests, build, placeholder-scan, task-state-check}) and enforces **no tier
minimum**. Tier-minimum enforcement is opt-in — it activates only when `risk` is
present. (Absent is NOT mapped to `medium`: the `medium` minimum adds
`acceptance-tests`/`regression`, which pre-feature contracts do not carry, so an
absent→medium mapping would fail every existing contract. Pre-feature contracts
and their tests therefore pass unchanged.)
