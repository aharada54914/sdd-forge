# Specification Review Calibration

Calibration rules for `spec-review-loop`. Apply these rules before emitting any
finding.

## Source Lessons

- Superpowers-style process discipline is useful here only as a specification
  gate: clarify intent before implementation, require planned verification, and
  keep review independent.
- Everything Claude Code execution commands such as `/test-coverage`, `/e2e`,
  Go-specific commands, and `/eval` are not live duties for this gate. Translate
  them into inspectable acceptance criteria or future verification paths.
- Everything Claude Code documentation, codemap, checkpoint, learning, and
  evolution commands are source-of-truth or continuous-improvement workflows.
  They are not requirements for passing a Phase 1 specification review.

## Gate Responsibility

The specification review gate reviews only Phase 1 artifacts:

- `specs/<feature>/requirements.md`
- `specs/<feature>/acceptance-tests.md`
- optional `specs/<feature>/investigation.md`
- the current `precheck-result.json`
- for reviewer B only, the sanitized `integrated-summary.json`

Do not require design decisions, task decomposition, implementation commands,
test files, or quality-gate evidence. Those belong to later gates.

## Finding Evidence Gate

Before emitting a FAIL finding, cite all of the following:

1. The exact requirement, acceptance criterion, non-goal, constraint, or
   investigation claim that exposes the issue.
2. The downstream failure mode: what implementer, task author, or verifier
   would be unable to decide.
3. Why the issue belongs to specification review rather than implementation
   review, task review, or quality-gate verification.
4. Why the chosen severity is justified by the concrete ambiguity or
   contradiction.

If any item is missing, do not emit a FAIL. Emit PASS or SKIP when the scoped
surface is absent and the check has a skip condition.

## Severity Calibration

- Critical: contradictory goals, impossible acceptance criteria, unsafe or
  unauthorized workflow boundary, or missing approval boundary that makes the
  specification unreviewable.
- Major: ambiguous requirement, missing observable acceptance criterion, missing
  constraint, unbounded scope, or high-risk claim with no planned validation
  surface.
- Minor: useful clarification that does not block design, task decomposition, or
  later verification.

Do not inflate severity because a best practice is absent. Severity follows the
downstream failure mode.

## False-Positive Guard

Do not fail a specification because it omits:

- concrete implementation architecture
- implementation tasks or task ordering
- test command names when acceptance outcomes are still observable
- documentation-generation, codemap, checkpoint, learning, or prompt-evolution
  workflows
- language-specific commands unless the requirement explicitly depends on that
  language or toolchain

## Reproducibility

The gate must be reproducible. Do not use memories, prior raw reviewer reports,
or adaptive prompt evolution while reviewing. Recurring misses belong in
workflow retrospectives or explicit prompt-evaluation fixtures outside this
gate.
