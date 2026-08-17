# Specification Review Report: epic-191-a3-path-ownership

- Attempt: 2
- Round: 3
- Input hashes: requirements `10f1595a4496faa82db202297fb16fd7f3c79e74d11288cae76176b0d725a62e`, acceptance tests `2dbe99480b135d3e645a1a7987cdaf7d43eddcf690a62090b26fea5a24b496f4`
- Reviewer A: run `RUN-epic-191-a3-path-ownership-spec-spec-reviewer-a-a2r3-seq0667`, host session `SESS-spec-spec-reviewer-a-epic-191-a3-path-ownership-a2r3-0667`
- Reviewer B: run `RUN-epic-191-a3-path-ownership-spec-spec-reviewer-b-a2r3-seq0668`, host session `SESS-spec-spec-reviewer-b-epic-191-a3-path-ownership-a2r3-0668`
- Verdict: `BLOCKED`
- Warning count: 0

Round 3 was opened after the human-directed amendment `2bb10bac`, which
resolved the two a2r2 Major findings (AMBIGUITY + DOWNSTREAM-READINESS, one
gap): requirements.md REQ-004 gained a present-but-malformed-config
sub-bullet stating the Gate-side fail-closed crash contract, AC-035 was
extended with the Gate-side half of the end-to-end guarantee, TEST-035d was
added, and Edge Cases / Main Workflows step 4 / Security Boundaries carry
matching dated extensions. The `--edit-summary` in `precheck-result.json`
describes the amendment. Identities seq0667 (reviewer A) and seq0668
(reviewer B) were validator-reserved; the documented orphan seq0664 was not
reused.

## Findings

Reviewer A: verdict `PASS` — 6 PASS, 0 FAIL, 1 SKIP (DOMAIN-CONFORMANCE, no
`domain/` directory). Reviewer A found both a2r2 findings resolved: the
Gate-side present-but-malformed clauses are concrete and mutually consistent
across REQ-001, REQ-004, Problems, Main Workflows step 4, and Security
Boundaries, and the caught-parse-exception risk is bound to the
AC-035/TEST-035c+TEST-035d validation surface.

Reviewer B: verdict `NEEDS_WORK` — 5 PASS, 1 FAIL (Major), 1 SKIP. Reviewer
B confirmed both a2r2 findings resolved (AMBIGUITY and DOWNSTREAM-READINESS
now PASS: the absent vs. exists-but-unparseable vs. parses-but-invalid-enum
triggers are "drawn with concrete, non-overlapping triggers that two
implementers would resolve identically", and no product behavior is left
for a downstream reviewer to invent), but surfaced one new gap introduced
by the amendment itself:

1. Major — `EDGE-CASE-COVERAGE` (reviewer B, verbatim): "requirements.md
   Goals REQ-001, the 'Config-read contract on a present-but-malformed
   file' bullet (~lines 339-353), added in this round's amendment, states
   that resolve-component-paths' own `--config` file existing-but-
   unparseable is a fail-closed load-time error (non-zero exit, diagnostic
   naming the parse failure) and explicitly extends this to the
   `--diagnose` subcommand ('The resolver-only diagnostic subcommand ...
   inherits this identical contract'). This clause is assigned no
   Acceptance Criterion number (it is not AC-006/AC-008/AC-018, which the
   same paragraph cites as analogous-but-distinct existing clauses covering
   unsupported metacharacters, an empty include list, and an ill-shaped
   shared_paths entry respectively — none of which is 'file cannot be
   parsed as YAML at all'), and consequently acceptance-tests.md contains
   no TEST ID for it. acceptance-tests.md's own header states TEST IDs map
   1:1 to AC-001..AC-055 with none omitted, so this normative resolver-side
   behavior has zero acceptance-test traceability. This is exactly the risk
   class round 2's Gate-side finding addressed (an implementation could
   catch its own parse exception and silently fall back to different
   behavior than the mandated diagnostic-and-crash), but here it is left
   open for the resolver/`--diagnose` path even though the Gate-side twin
   (REQ-004) received a full AC-035 extension plus dedicated TEST-035d
   (acceptance-tests.md lines 63-67). A task author decomposing Phase 2
   work has no acceptance test to point implementation or evidence at for
   this resolver behavior, and a verifier has nothing to check it against."

All other checks from both reviewers (REQ-TESTABILITY, GOAL-AC-TRACE,
AC-OBSERVABLE, SCOPE-BOUNDARY, CONSTRAINTS-EXPLICIT,
RISK-VALIDATION-SURFACE, AMBIGUITY, CONTRADICTION, ASSUMPTIONS-RESOLVABLE,
APPROVAL-BOUNDARY, DOWNSTREAM-READINESS) passed; DOMAIN-CONFORMANCE was
SKIP for both (no `domain/` directory).

## Transition

Per the state table ("Pending, round 2 NEEDS_WORK | `--edit-summary`,
round 3 | Minor-only produces PASS with `warningCount > 0`; Major/Critical
produces BLOCKED"), a round-3 Major finding produces `BLOCKED`. The merged
verdict is `BLOCKED`, terminal for attempt 2. Findings are recorded
verbatim, never waived or negotiated. `Spec-Review-Status` remains
`Pending`; no status field was modified this round. A future re-review
requires a human decision to open attempt 3 (`--reset`, round 1) after an
amendment that assigns the REQ-001 resolver-side present-but-malformed
clause an Acceptance Criterion number and a matching acceptance-tests.md
TEST row (reviewer B judged the gap "resolvable by adding a matching AC
number and TEST row"; the round budget of this attempt is what made it
terminal, not the gap's difficulty).
