# Reviewer Calibration

Shared calibration rules for `sdd-review-loop` reviewers. Apply these rules
before emitting any finding.

## Source Lessons

- Superpowers emphasizes process discipline: brainstorm before implementation,
  plan with explicit verification, require evidence before completion, debug
  from root cause, use independent review, and avoid blind acceptance.
- Everything Claude Code commands such as `/test-coverage`, `/e2e`, and `/eval`
  are execution and evaluation workflows. In review-loop prompts, translate
  them into requirements for concrete planned evidence, not live execution.
- In the reviewed Everything Claude Code clone, `/eval` was not present at
  `commands/eval.md`. The reviewed source path was
  `docs/ja-JP/commands/eval.md`; a compatibility shim also existed at
  `legacy-command-shims/commands/eval.md`.
- Everything Claude Code commands such as `/update-docs`, `/update-codemaps`,
  `/checkpoint`, `/learn`, and `/evolve` are operational or learning workflows.
  In formal review gates, use them only as controlled signals for stale
  artifacts, prompt evaluation fixtures, or retrospective improvements.
- Go-specific commands and git-worktree workflows are out of scope for generic
  implementation-policy and task-decomposition review prompts unless the input
  artifacts explicitly declare that stack or workflow.

## Adopted Prompt Changes

- Require reviewers to pass an evidence gate before emitting FAIL findings.
- Require task and implementation review prompts to check whether verification
  evidence is concrete enough for a downstream implementer or quality gate.
- Require bugfix or debugging tasks to preserve a diagnostic path from symptom
  to root cause, fix, and regression evidence.
- Keep the reviewer's job at artifact review: require planned commands,
  evidence artifacts, or inspectable completion criteria, not command execution.

## Rejected Or Out-Of-Scope Ideas

- Do not add documentation or codemap generation to reviewer responsibilities.
  Those are source-of-truth maintenance workflows.
- Do not add checkpoint, learning, import/export, or evolution workflows to the
  formal gate. Use explicit prompt evaluation fixtures or retrospectives
  outside the gate instead.
- Do not add Go-specific build, test, or review checks to generic reviewers
  unless the reviewed artifacts declare Go as the relevant implementation stack.
- Do not make `/eval` a required runtime dependency for this review loop. Its
  useful lesson here is reproducible prompt evaluation, not mandatory execution.

## Finding Evidence Gate

Before emitting a FAIL finding, verify all of the following:

1. Cite the exact artifact and section, field, task ID, requirement ID, or
   acceptance criterion that exposes the defect.
2. State the concrete failure mode: what implementation, verification, or
   downstream gate will break or become ambiguous.
3. State why the severity is blocking or non-blocking under the local severity
   reference.
4. Check whether another reviewer-owned check or the precheck already owns the
   issue. If so, do not duplicate it unless this check adds distinct evidence.

If any item is missing, do not emit a FAIL. Emit PASS or SKIP with the evidence
available, or state the limitation in the check finding.

## False-Positive Guard

Do not fail an artifact because it omits a workflow that is outside the current
gate's responsibility:

- Do not require reviewers to run build, coverage, E2E, or Git commands.
- Do not require language-specific tooling unless the design or task explicitly
  declares that toolchain.
- Do not require automatic learning, memory updates, checkpoint creation, or
  prompt evolution during a formal gate.
- Do not fail documentation-only tasks for missing test commands when they name
  exact files or sections and the Done When outcome is inspectable.

## Precheck Separation

Prechecks own invocation validity, predecessor status, stale predecessor hashes,
symlink/path safety, dependency graph construction, and mechanical workflow
pairing errors. Reviewers still emit their ordered check entries for formal
review IDs, but should not create extra findings for precheck-owned failures
unless the required artifact is present and contains a distinct substantive
defect.

Legacy compatibility is narrower: when `legacy_design: true` is present, absent
template fields become `[LEGACY COMPAT]` Minor advisories where the reviewer
prompt says so. Do not convert them into Major or Critical findings.

## Cannot-Verify Handling

Use SKIP only when the check has an explicit skip condition or the scoped
surface does not exist. Examples:

- A fullstack-only consistency check on an `api-only` feature.
- A bugfix diagnostic check when no task is a bugfix/debugging task.
- A high-risk verification-path check when no high-risk claim or risk surface
  is present.

Use FAIL when the surface is present but the required evidence is absent.
Use BLOCKED only for missing required input files or invalid invocation context.

## Severity Calibration

- Critical: unimplementable artifact, impossible execution order, hard policy
  violation, direct contradiction of required constraints, or missing evidence
  that the local prompt explicitly marks Critical.
- Major: a gap likely to cause implementation mismatch, failed verification,
  security or migration exposure, ambiguous execution, or invalid risk/scope
  planning.
- Minor: advisory polish, legacy compatibility note, or improvement that does
  not block a competent implementer.

Do not inflate severity because a best practice is absent. Severity follows the
project's check contract and the concrete failure mode.

## Formal Gate Reproducibility

Reviewer prompts must remain deterministic and reproducible. Do not use learned
memories, prior raw reviewer reports, or adaptive prompt evolution while running
the gate. Capture recurring false positives or misses outside the gate through
explicit prompt eval fixtures or workflow retrospectives.

## Amendment Re-Review Context (impl and task stages)

An implementation-policy or task-decomposition package can be legitimately
re-reviewed after a human approved a post-implementation amendment to the
documents an earlier attempt of this same stage already reviewed and pinned.
Ordinarily a reviewer treats the reviewed inputs differing from what a prior
attempt pinned -- or the presence of amendment history, later-phase evidence,
or recovery narrative inside the package -- as grounds for a finding: an
"amendment-supersession" finding, whose basis is the difference or the
disclosure itself rather than any defect in the content. An amendment
re-review inverts that: the amendment already happened, was human-approved,
and is being disclosed honestly; disclosure is what makes it reviewable.

### Recognizing a declared amendment re-review

Treat the package as being in a declared amendment re-review context only
when `specs/<feature>/investigation.md` contains a section with the exact
heading `## Amendment Re-Review Context` meeting the full evidence bar
defined in `spec-review-calibration.md`'s section of the same name: full
amendment commit hashes, per-document SHA-256 as of each amendment commit, a
verbatim dated quotation of the human's approval statement, and a commit or
SHA-256 reference (never a bare path) for every later-phase artifact
mentioned. The entry must cover the whole completion chain -- an amendment
that grew across several commits lists every one. If any element is missing,
abbreviated, paraphrased, or given as a bare path, the declaration does not
apply and the default calibration stands with no benefit of the doubt.

### What the declaration suppresses

When, and only when, a conforming entry is present, do not emit a finding
whose *sole* basis is that the reviewed documents differ from what a prior
attempt of this stage pinned, or that amendment history, later-phase
artifacts, or recovery narrative exist or are referenced in the package.
This is the amendment-supersession class only.

- Suppressed example: the design under review reflects an amendment commit
  the entry cites in full, and the prior attempt's contract pinned the
  pre-amendment bytes; the sole observation is "this is not what attempt N
  reviewed" -- suppressed.
- NOT suppressed example: the amended design's activation predicate
  contradicts a requirement, an amended task's Done-When is unobservable, or
  the amendment introduced an unmitigated security exposure. These stand on
  their own defect and are reviewed and reported exactly as usual even when
  the evidence bar is met.

Every other check and severity class is judged exactly as it would be
without this section. This declaration modulates one finding basis and
nothing else. The bounded-even-if-fabricated analysis in
`spec-review-calibration.md` applies unchanged: the bound rests on scope,
not on detection, and the durable replacement is proposed as WFI-047.

Operational notes, recorded so the next operator does not rediscover them:
a mid-attempt edit to `investigation.md` (adding this very entry) can make a
*prior* round's contract unverifiable against current disk bytes; the
disclosed fixed-point procedure is to validate the prior contract against
the bytes it reviewed, then restore the amended bytes and let the new
round's manifests pin them. And the entry must be re-extended whenever the
completion chain gains another commit, or the next gate will correctly
refuse it as incomplete.
