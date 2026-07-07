# Domain Review Calibration

Calibration rules for `domain-review-loop`. Apply these rules before emitting
any finding.

## Source Lessons

- The domain artifact set is a strategic and tactical modeling deliverable,
  not an implementation-ready specification. It gates human approval of
  `domain/context-map.md`'s `Domain-Model-Status`, not a design.md or
  tasks.md.
- Reviewer A owns strategic soundness (context boundaries, relation
  patterns, event coverage, ubiquitous-language uniqueness). Reviewer B owns
  tactical implementability (invariant verifiability, transaction-boundary
  realism, aggregate design health). Neither reviewer duplicates the other's
  checks; do not fail a strategic concern under a tactical check ID or vice
  versa.
- Downstream conformance (`check-domain-conformance`, DOMAIN-CONFORMANCE
  findings in spec/impl review) and cross-model verification are separate
  gates (T-007, T-008, T-011). This gate does not simulate or anticipate
  their findings.

## Gate Responsibility

The domain review gate reviews only the seven canonical `domain/` Markdown
artifacts plus the machine-readable projection:

- `domain/domain-story.md`
- `domain/event-storming.md`
- `domain/ubiquitous-language.md`
- `domain/context-map.md`
- `domain/aggregates/<name>.md` (one per aggregate)
- `domain/message-flow.md`
- `domain/c4-container.md`
- `domain/domain-contract.json`
- the current round's `precheck-result.json`
- for reviewer B only, the sanitized `integrated-summary.json`

Do not require downstream artifacts (`requirements.md`, `design.md`,
`tasks.md`), quality-gate evidence, cross-model verdicts, or code. Those
belong to later gates or are out of this gate's scope entirely.

## Finding Evidence Gate

Before emitting a FAIL finding, cite all of the following:

1. The exact artifact section, table row, or field that exposes the issue.
2. The downstream failure mode: what a later reviewer, downstream feature
   author, or implementer would be unable to decide or would decide
   inconsistently.
3. Why the issue belongs to domain review rather than downstream conformance
   checking, cross-model verification, or spec/impl review.
4. Why the chosen severity is justified by the concrete modeling defect.

If any item is missing, do not emit a FAIL. Emit PASS or SKIP when the scoped
surface is absent and the check has a skip condition.

## Severity Calibration

- Critical: a context boundary, relation, or aggregate definition that is
  self-contradictory, an aggregate with no verifiable invariant at all, or a
  missing/undefined `Domain-Model-Status` field that makes the model
  unreviewable or unapprovable.
- Major: an ambiguous context boundary, an undeclared relation between two
  contexts that interact, a term reused across contexts with conflicting
  meaning, an aggregate whose transaction boundary spans another aggregate's
  root, or a domain event with no producing/consuming context traced in the
  message flow.
- Minor: a useful clarification, naming polish, or documentation gap that
  does not block a human approval decision or a downstream implementer's
  concrete choice.

Do not inflate severity because a best practice (e.g. CQRS, event sourcing)
is absent — those are explicit non-goals of this plugin (`requirements.md`
Non-goals). Severity follows the downstream failure mode, not stylistic
preference.

## False-Positive Guard

Do not fail the domain model because it omits:

- language-specific code generation templates or repository/service
  implementation sketches (explicit non-goal)
- CQRS or event-sourcing structure (explicit non-goal)
- C4 Component or Code level diagrams (Container level only, explicit
  non-goal)
- downstream `Bounded-Context:` field wiring in `requirements.md`/`design.md`
  (owned by `domain-sync`, T-007, a separate gate)
- cross-model vendor verdicts (owned by cross-model-verify, T-011, invoked
  only after this gate reaches PASS)
- an aggregate card for every noun mentioned in the domain story — only
  aggregates actually identified during Event Storming's candidate-aggregate
  clustering are in scope

## Reproducibility

The gate must be reproducible. Do not use memories, prior raw reviewer
reports, or adaptive prompt evolution while reviewing. Recurring misses
belong in workflow retrospectives or explicit prompt-evaluation fixtures
outside this gate.
