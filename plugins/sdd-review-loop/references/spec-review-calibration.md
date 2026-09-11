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

## Amendment Re-Review Context

A specification package can be legitimately re-reviewed after a human
approved a post-implementation amendment (for example, correcting or
extending Phase 1 artifacts once implementation, task, or quality-gate work
already exists for this feature). Ordinarily this gate treats the mere
existence or citing of any later-phase artifact while `Spec-Review-Status` is
`Pending` as an unsafe or unauthorized workflow-boundary violation -- a
"phase-sequencing" finding -- because a spec package should not describe work
from a phase it has not yet been approved to unlock. An amendment re-review
inverts that: the later-phase work already exists, is being disclosed
honestly, and disclosure is precisely what makes the amendment reviewable.
Without an explicit exception the calibration classifies the honest
disclosure itself as the violation.

### Recognizing a declared amendment re-review

Treat this package as being in a declared amendment re-review context only
when `specs/<feature>/investigation.md` contains a section with the exact
heading `## Amendment Re-Review Context` whose body meets the same evidence
bar the rest of a diligent investigation record applies to its own claims:
every citation is a file:line, a SHA-256 fingerprint, or a PR/commit
reference -- never a bare, uncited path or an unqualified assertion. The
section body must include all of:

1. The amendment commit hashes, given in full (not abbreviated, and not
   described only as "recent changes").
2. The SHA-256 of each amended document (`requirements.md`,
   `acceptance-tests.md`, and this `investigation.md` itself, as applicable)
   as of the amendment commit.
3. A verbatim, dated quotation of the human's approval statement authorizing
   the post-implementation amendment (not a paraphrase or summary). Because
   this approval currently exists only in conversation, this entry -- once
   committed into a hash-pinned, review-pinned document -- is itself the
   durable, citable approval record; that is what makes it citable evidence
   rather than a bare self-declaration.
4. For every later-phase artifact the entry or the amended requirements/
   acceptance-tests text references (design, tasks, traceability,
   implementation, evidence, or quality-gate material): a commit reference or
   a SHA-256 fingerprint for that artifact, never a bare path alone.

If the section heading is absent, or any of the four elements is missing,
abbreviated where a full hash is required, given only as a bare path with no
commit or sha256, or the approval quotation is missing, paraphrased, or
undated, the declaration does not apply: judge phase-sequencing exactly as
the default Phase-1 calibration above requires, with no benefit of the doubt.
An agent can write the heading and prose into `investigation.md` -- this gate
does not independently verify the cited hashes or commits against any
external source -- so it is the entry's conformance to this full evidence
bar, not its mere existence, that is the safety property this rule relies on.

### What the declaration suppresses

When, and only when, a conforming entry (per the previous section, meeting
the full evidence bar) is present, do not emit a finding whose *sole* basis
is that a later-phase artifact (design, tasks, traceability, implementation,
evidence, or quality-gate material) exists, is referenced, or is quoted in
the reviewed specification package while `Spec-Review-Status` is `Pending`.
This is the phase-sequencing class only.

- Suppressed example: the amended `requirements.md` states "AC-010 was
  clarified to match the constant name introduced in commit `a1b2c3d4e5f6`"
  and the `## Amendment Re-Review Context` entry cites that same full commit
  hash, the SHA-256 of the amended `requirements.md`, the SHA-256 of the
  referenced constant's file, and a verbatim dated human-approval quotation.
  The sole issue is that a later-phase artifact is referenced pre-approval,
  and every reference is fully cited -- suppressed.
- NOT suppressed example (evidence bar unmet): the entry says only "the human
  approved this in chat" with no quotation, or cites `tasks.md and
  traceability.md exist` with a bare path and no commit or sha256, or gives
  an abbreviated commit hash. The declaration does not apply, so the
  phase-sequencing finding stands under the default calibration.
- NOT suppressed example (other defect): the same amendment's AC-010 text is
  internally contradicted by AC-004 elsewhere in `requirements.md`, or the
  cited implementation artifact does not actually contain what the amendment
  claims it contains, or the amendment leaves a goal without a matching
  acceptance criterion. These findings do not rest solely on
  phase-sequencing -- they stand on their own defect, so review and report
  them exactly as usual even when the evidence bar above is met.

Every other check and severity class -- testability, goal/acceptance-criteria
traceability, observability, scope boundary, non-phase-sequencing
constraints, risk validation surface, domain conformance, ambiguity,
contradiction not arising from phase-sequencing, edge-case coverage,
assumption resolvability, non-phase-sequencing approval boundaries, and
downstream readiness -- is judged exactly as it would be without this
section. This declaration modulates one finding basis and nothing else.

### Why this is bounded even if the entry is fabricated

An agent can forge the investigation.md entry: quote invented words as "the
human's approval," and cite invented-but-well-formed commit hashes and SHA-256
fingerprints that satisfy the shape rules above without being independently
verified by this gate. The full evidence bar raises the cost of a convincing
forgery -- a bare "recent changes" or an unqualified "human approved this" no
longer qualifies, the fabricator must produce syntactically valid full hashes
for every reference -- but it does not make forgery impossible, so the bound
still rests on scope, not on detection. The worst case is that
phase-sequencing findings are suppressed for a package whose other findings
this gate still reports in full, and whose pins the workflow-state gate
(`check-workflow-state.sh`) still verifies independently against the actual
repository state -- the forged entry does not relax any hash, contract, or
identity check outside this gate's own findings. A forged entry cannot make
an otherwise-failing specification pass this gate on any basis except the
single, narrowly-scoped phase-sequencing suppression described above.

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
