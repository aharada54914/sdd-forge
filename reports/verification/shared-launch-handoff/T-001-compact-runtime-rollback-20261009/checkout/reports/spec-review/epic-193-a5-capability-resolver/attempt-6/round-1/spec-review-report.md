# Specification Review Report: epic-193-a5-capability-resolver

- Attempt: 6
- Round: 1
- Input hashes: requirements `0f8837e3fd6ec58270e4b637b9411e2557648c224e8a7bc767338487fb569d1f`,
  acceptance tests `49e022097b2b0c6a89198eb8f605c98393e75b89e9c063ac27d5c7c810577bb9`
- Reviewer A: run `RUN-epic-193-a5-capability-resolver-spec-spec-reviewer-a-a6r1-seq0821`,
  host session `SESS-spec-epic-193-a5-capability-resolver-spec-reviewer-a-a6r1-0821`,
  allowed input manifest
  `reports/review-context/pending-epic-193-a5-capability-resolver-spec-reviewer-a-a6r1-seq0821-manifest.json`
  (5 entries: requirements.md, acceptance-tests.md, investigation.md,
  spec-review-calibration.md, precheck-result.json)
- Reviewer B: run `RUN-epic-193-a5-capability-resolver-spec-spec-reviewer-b-a6r1-seq0822`,
  host session `SESS-spec-epic-193-a5-capability-resolver-spec-reviewer-b-a6r1-0822`,
  allowed input manifest
  `reports/review-context/pending-epic-193-a5-capability-resolver-spec-reviewer-b-a6r1-seq0822-manifest.json`
  (the same 5 entries plus integrated-summary.json)
- Verdict: `NEEDS_WORK`
- Warning count: `0`

## Why this attempt exists

Attempt 5 passed. Commit `fa1ad0e0` then amended the frozen specification
under the repository owner's 2026-08-27 ruling (option 4), adding a third
exception to REQ-002's Evidence-on-every-Block rule and rescoping the AC-047
wording. This attempt re-reviews the amended bytes. Both reviewers ran fresh
and read-only; neither was told the amendment was sound.

## Integrated Summary

| Reviewer | PASS | FAIL | SKIP |
| --- | --- | --- | --- |
| spec-reviewer-a | 3 | 3 | 1 |
| spec-reviewer-b | 1 | 5 | 1 |

Finding counts (merged): Critical 3, Major 5, Minor 0.

| Check ID | Reviewer | Severity |
| --- | --- | --- |
| REQ-TESTABILITY | A | Critical |
| CONTRADICTION | B | Critical |
| APPROVAL-BOUNDARY | B | Critical |
| AC-OBSERVABLE | A | Major |
| CONSTRAINTS-EXPLICIT | A | Major |
| AMBIGUITY | B | Major |
| EDGE-CASE-COVERAGE | B | Major |
| DOWNSTREAM-READINESS | B | Major |

PASS: GOAL-AC-TRACE (A), SCOPE-BOUNDARY (A), RISK-VALIDATION-SURFACE (A),
ASSUMPTIONS-RESOLVABLE (B). SKIP: DOMAIN-CONFORMANCE (both — no `domain/`
directory in this repository).

Full finding text is in `reviewer-a.json` and `reviewer-b.json` in this
directory. Only IDs, severities, and counts are reproduced above, per the
template's reviewer-isolation rule.

## The three defect clusters, and who must decide them

The eight findings collapse into three clusters. Two are mechanical; the
third is not, and needs the repository owner.

### Cluster 1 — un-propagated siblings (mechanical)

The amendment widened the exception list in REQ-002 and in AC-012 but left
two sibling normative statements asserting the opposite:

- `requirements.md:564-568` (REQ-004) still says Evidence is written on every
  invocation "with the **sole exception**" of the B3 self-validation case, and
  that "that one case writes nothing at all". Two cases now write nothing.
- `requirements.md:1176-1184` (Security Boundaries) still guarantees every
  live path is left "fully absent, fully unchanged …, or (Resolver Evidence
  only, on a Block reached before publication) fully written". The new
  sub-case is detected at REQ-001 step 0 — before publication — and writes
  nothing.

This is the amendment-propagation defect class this repository has now hit
ten times: an authorised change lands in the text that triggered it and
misses the siblings that state the same fact elsewhere.

### Cluster 2 — the exception is not testable as written (mechanical)

- "fixed publication write set" (`requirements.md:390-391`, `:395`) is defined
  nowhere; REQ-002 points "immediately below" (nothing below states one) and
  AC-012 points at "REQ-001's fixed write set" (REQ-001 defines only a
  track-exclusive *output* set). Under the only enumerated set, the staging
  area is never a member, so the predicate is universally true; under
  Security Boundaries `:1153-1158` the staging area is explicitly *inside*
  the boundary, so it can never fire. Neither reading is the intended
  path-escape semantics.
- The trigger has no home in the taxonomy. `publication-journal-recovery`
  (`requirements.md:356`) admits exactly two conditions, both journal
  convergence failures, gated on first finding a stale journal. A staging
  containment failure is neither, and the enum is declared "closed at sixteen
  rows" with "no fail-open path". An uncontained staging area with no stale
  journal matches no row at all.
- `acceptance-tests.md:54` says "its fixture asserts …" but no row anywhere
  creates that fixture. `TEST-010` is a closed sixteen-fixture enumeration
  and `TEST-047` covers the corrupted-pre-image case.
- Pre-existing, not from this amendment: `AC-057`/`AC-058` exist only in
  `acceptance-tests.md` (lines 97-98, after a blank line, with no table
  header) while `requirements.md`'s AC table ends at AC-056 — yet REQ-002
  `:364`/`:368` cites both. The 2026-08-26 follow-up left this half-landed.

### Cluster 3 — the amendment's premise is refuted by the specification itself

This is the finding that changes what the correct fix is, and it is not
mechanical.

The amendment justifies writing no Evidence by asserting it is "structurally
impossible: the write would itself have to pass through the very staging area
just found to be uncontained" (`requirements.md:392-395`, repeated at
`acceptance-tests.md:54`).

`requirements.md:1026` (Main Workflows 4, the `disabled-legacy-invocation`
Block) already specifies the opposite capability, verbatim:

> minimal Resolver Evidence written directly (no staging area ever exists in
> this branch)

A non-staged Evidence write path therefore already exists in this
specification. The impossibility premise is false by the package's own text,
so the third exception is not forced — it was a choice made on a mistaken
reading. The same Block could instead write minimal Resolver Evidence
directly, exactly as Main Workflows 4 does, which would leave REQ-002's
two-exception rule, REQ-004's "sole exception" sentence, and the Security
Boundaries guarantee all intact and unamended.

Deciding between "keep the third exception and make it well-formed" and
"drop the third exception and write Evidence directly" is a requirement
decision about fail-closed write behaviour. Under this project's rules an
agent may not make it, and the 2026-08-27 ruling cannot be read as covering
it, because the ruling was given on the premise this finding refutes.

### Cluster 3b — the approval record (mechanical, and required either way)

`investigation.md`'s `## Amendment Re-Review Context` contains no entry for
the 2026-08-27 ruling: no occurrence of "2026-08-27", no "option 4", no
amendment commit pin, no per-document SHA-256 of the amended bytes, and no
verbatim dated quotation of the approval. Four locations in the two frozen
documents nevertheless cite that approval as their authority. The 2026-08-24
A(1)/B(1) and 2026-08-26 C(1)/C(2) lineages all supply the full record and
are pointed at from the amended rows; this one supplies none of it.

The remedy is additive and touches no frozen prose: append a conforming
entry with the commit hash, the post-amendment document hashes, and the
verbatim dated approval, and add the same `approval evidence:` pointer the
C(1)/C(2) rows already carry.

## Transition

`Spec-Review-Status` is `Pending` (set by `spec-review-precheck.sh --reset`
at the start of this attempt) and remains `Pending`. The orchestrator is the
sole writer of that field and does not set it to `Passed` on a NEEDS_WORK
round.

Round 1 of 3. Round 2 requires human edits to the specification followed by
re-invocation with `--edit-summary`. Clusters 1, 2 and 3b are mechanical and
can be drafted immediately once cluster 3's direction is chosen; cluster 3
is blocked on the repository owner, because both candidate resolutions change
a fail-closed write rule in a frozen document.
