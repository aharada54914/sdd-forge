# ADR 0026: High/Critical-Only Cross-Critique Phase for the Review Loops

Status: Proposed

Date: 2026-08-07

## Primary Sources

This ADR draws on two bodies of prior art:

1. **Internal prior art**: `skills/adversarial-review/` (proving run 2026-07-07,
   `SKILL.md` "Real-world impact"), issue #128 (ENH-21), issue #130 (ENH-23).
2. **External prior art**: *Adversarial Review: Structured Disagreement for
   Grounded Agentic Code Review* (arXiv:2608.18167, published 2026-08-16,
   verified 2026-08-25). URL: https://arxiv.org/abs/2608.18167

The paper post-dates the initial ADR draft. Its findings partially confirm and
partially diverge from the design choices recorded here. The correspondence is
documented in `## arXiv:2608.18167 Correspondence` below.

## Definitions (from arXiv:2608.18167, adapted to this repository's vocabulary)

**Evidence-backed dissent**: a `PROPOSE-REJECT` or `PROPOSE-SEVERITY-CHANGE`
verdict accompanied by a `code_evidence` or `spec_evidence` citation (file:line
plus a concrete claim). Contrasts with a *concern* — a plausible-but-unverified
objection that cannot be dismissed or adopted without further investigation.

**False consensus**: a verdict of `SUPPORT` or an absence of `PROPOSE-REJECT`
that does not reflect the critic's genuine assessment, but rather deference to
the finding author. The paper reports false consensus as the primary failure mode
of naive mutual-critique loops. This ADR mitigates it by requiring evidence for
every `PROPOSE-REJECT` and `PROPOSE-SEVERITY-CHANGE` (see §2, Basis requirement).

**Scope creep**: a finding-driven change that exceeds the approved requirement /
acceptance-test / task boundary. The paper reports scope creep as a secondary
failure mode when critics surface plausible concerns outside the approved scope
and the author implements them. This ADR mitigates it by labelling each finding
with `in_scope | out_of_scope | unclear` relative to the approved task (see
`## arXiv:2608.18167 Correspondence`, point 3).

## Context

The spec/impl/task review loops run two reviewers **blind-parallel**:
reviewer B receives only reviewer A's check IDs and counts via
`integrated-summary.json`, never A's raw findings (all three loop skills
state this; the reviewer role files list `reviewer-*.json` under
`disallowedPaths`). That blindness is a deliberate independence property
(ADR-0001): two reviewers who cannot see each other's reasoning cannot
anchor on it. What the design gives up in exchange — issue #130's finding
(A-3) — is **mutual criticism**: nothing in the loop ever attacks a
finding. A severity-inflated Major sails through as easily as a genuine
one; a plausible-but-wrong FAIL costs a full extra round; and the one
protocol in the repository built to catch exactly these failure modes
(`skills/adversarial-review`, whose proving run re-calibrated four of five
initial severities) is excluded from the gates by its own charter
(`SKILL.md:25-26`) and by ADR-0027, which wires it *outside* them.

All three loops share the same structural seam: STEP 5 (merge verdicts)
and STEP 6 (state-machine outcome) are adjacent in each skill, with both
reviewers' JSONs persisted and hash-bound by the end of STEP 5. And the
repository already has the severity/risk vocabulary a firing condition
needs (`Critical/Major/Minor` per finding; `Risk` tier per task,
`risk-classification-policy.md`).

Running a critique round on every review is rejected up front: it roughly
doubles reviewer cost on the ~90% of rounds that end PASS or carry only
Minor findings, where a critique has nothing of value to attack.

## Decision

1. **A post-verdict, advisory critique phase, inserted between STEP 5 and
   STEP 6 of each loop.** It runs only when, after STEP 5's merge, the
   round satisfies **any** of:
   - the merged round contains at least one **Critical** finding;
   - the round's verdict is **BLOCKED**, or this is round 3 (the
     escalation round, where the next stop is a human);
   - the feature carries a human-confirmed `Risk: high` or
     `Risk: critical` tier.

   Everything else — PASS rounds, Minor-only rounds, low/medium-risk
   NEEDS_WORK rounds — proceeds directly to STEP 6, unchanged.

2. **Blindness is preserved where it matters and lifted where it no
   longer does.** The initial judgments stay fully independent: the
   critique begins only after both reviewer JSONs are persisted and the
   round's integrated verdict is computed. At that point the exchange of
   raw findings can no longer contaminate the judgments it critiques.
   Each reviewer agent is **resumed in its existing context** (same
   run_id / host_session_id — a continuation, not a new identity, so the
   identity ledger gains no record and the reservation semantics are
   untouched) and receives the other's persisted findings verbatim. Each
   returns a per-finding verdict — `SUPPORT` / `PROPOSE-SEVERITY-CHANGE`
   / `PROPOSE-REJECT` / `SUPPLEMENT` — with file:line evidence, the same
   verdict vocabulary `skills/adversarial-review` Phase 2 already
   defines.

3. **The critique is an annex, never a verdict mutation.** The
   orchestrator persists the exchange as `cross-critique.json` in the
   round directory, alongside — never inside — the round's contract. The
   persisted reviewer JSONs, the integrated verdict, and the state
   transition STEP 6 derives from them are byte-identical whether or not
   the phase ran. What the annex feeds is the two places judgment already
   flows: the **next round's edit** (a PROPOSE-REJECT with evidence tells
   the author which finding not to chase; a severity-change proposal
   recalibrates what must be fixed first), and the **human at an
   escalation** (a BLOCKED round arrives with its findings already
   stress-tested, and disputed ones labeled as disputed). Rationale: the
   deterministic gates' value is that their outcome is a pure function of
   persisted artifacts; letting a conversational exchange rewrite a
   persisted verdict would spend exactly the property ADR-0001 exists to
   protect. This is also the deliberate contrast with
   `skills/adversarial-review` Phase 3, where the orchestrator *does*
   adopt/reject findings — that protocol runs outside any deterministic
   contract (ADR-0027), so it can afford synthesis authority the in-gate
   phase must not have.

4. **Failure containment.** If a resumed reviewer cannot be continued
   (context lost, API failure), the phase is recorded as
   `cross-critique.json` with `"status": "unavailable"` and the loop
   proceeds — the phase is advisory, so its absence degrades information,
   not integrity. A phase that cannot run never blocks a round.

5. **Wiring is gated on this ADR's acceptance, via the WFI lane.**
   The change edits the three loop SKILL.md files and the four reviewer
   role files (the role files must gain a "you may receive a
   post-verdict critique request for your own persisted round" clause,
   and their `disallowedPaths` must carve out the *other* reviewer's
   persisted JSON **only after** the round's contract exists). Reviewer
   role files are protected artifacts (human-copy staging), and workflow
   changes require human approval regardless of sudo state — so
   implementation follows a human's acceptance of this ADR, staged
   through the existing human-copy convention. Until then, the same
   effect is available manually by invoking `skills/adversarial-review`
   on a contested round's artifacts after the fact.

## Consequences

- **Cost is confined to the rounds that earn it.** Critical findings,
  escalations, and high/critical-risk features — the cases where a wrong
  severity or a phantom finding is most expensive — gain a critique;
  routine rounds pay nothing.
- **Severity calibration gets an in-gate mechanism** instead of relying
  solely on calibration prose that each reviewer applies alone.
- **Determinism is untouched, and auditable:** the annex's presence or
  absence changes no verdict, and its content is hash-recorded next to
  the contract it annotates.
- **Two accepted limits.** (a) A critique that would legitimately
  *overturn* a verdict (a demonstrated-false Critical) still costs one
  more round or a human ruling — the annex can argue but not decide;
  accepted as the price of verdict determinism. (b) Continuation depends
  on the reviewer agents' transcripts surviving to the end of STEP 5;
  where they do not, the phase degrades to `unavailable` rather than
  re-running reviewers in fresh contexts, because a fresh context
  critiquing findings it never made is a different (weaker) property
  than mutual critique and should not silently impersonate it.
- **Relationship to ADR-0027:** complements, not overlap — ADR-0027's
  lane reviews a whole branch diff from outside the gates before a PR;
  this phase attacks one round's findings inside a gate. A feature can
  trigger both, each for its own reason.

## arXiv:2608.18167 Correspondence

The table below documents where this ADR's design aligns with, diverges from,
or deliberately does not adopt the paper's recommendations. Points not listed
are outside the paper's scope or outside this ADR's scope.

| # | Paper finding / recommendation | This ADR's position | Reason |
|---|-------------------------------|---------------------|--------|
| 1 | Evidence-backed dissent reduces false consensus | **Adopted.** `PROPOSE-REJECT` and `PROPOSE-SEVERITY-CHANGE` require `code_evidence` or `spec_evidence` with file:line citations (issue #347). | Directly addresses the paper's primary failure mode. |
| 2 | ~4.5× token cost increase for full adversarial panels (§4.3 Cost Analysis) | **Acknowledged; mitigated.** The phase fires only on Critical findings, BLOCKED rounds, or high/critical-risk features — not on every review. | Cost is confined to the rounds that earn it (§"Consequences"). |
| 3 | Scope creep from out-of-scope concerns | **Adopted.** Each finding carries `scope: in_scope \| out_of_scope \| unclear`; out_of_scope findings are not converted to implementation directives (issue #348). | Paper reports scope creep as a significant failure mode. |
| 4 | Immutable target identity (hash-binding the reviewed artifact) | **Adopted.** Report metadata includes `head_sha`, `merge_base_sha`, `diff_sha256`; stale reports cannot satisfy `Adversarial-Lane: fired` (issue #349). | Prevents post-hoc report substitution. |
| 5 | Sequential Reviewer→Critic model (not blind-parallel first) | **Not adopted for the in-gate phase.** Blind independence of the first pass is `BL-001` and is a non-negotiable floor in the SDD review loops. The paper's sequential model is available outside the gates via `skills/adversarial-review` and ADR-0027's pre-PR lane. | Adopting sequential order inside a gate destroys the independence property the gate exists to enforce. |
| 6 | Automated evaluation metrics for AR runs | **Partially adopted.** Structural metrics (finding counts, basis counts, scope counts, human dispositions) are recorded in `evaluation.json` per triggering run (issue #350). Token telemetry is deferred — no token budget surface exists (INV-021). | Structural metrics are observable today; token telemetry is a separate feature. |
| 7 | Concern classification (basis type) | **Adopted.** `basis.kind` discriminates `code_evidence \| spec_evidence \| concern`; concerns alone cannot drive automatic rejection or adoption (issue #347). | Paper shows that mixing evidence and concern in a single "objection" category inflates false consensus rates. |

### Why blind-parallel first pass is maintained (not replaced by sequential)

The paper studies sequential Reviewer→Critic panels and shows improved accuracy.
This ADR does **not** adopt sequential ordering for the in-gate phase for three
reasons, each grounded in this repository's specific constraints:

1. **Independence is the gate's assurance property.** Two reviewers who cannot
   see each other's reasoning cannot anchor on it — this is what makes their
   agreement corroborating evidence rather than an echo. Replacing the blind
   pass with a sequential one would make the merged verdict weaker, not
   stronger, even if the sequential critic finds more findings.
2. **The SDD loop's identity ledger prevents resumption.** The paper's
   sequential model relies on passing the first reviewer's output directly to
   the second before any round record is committed. Inside `sdd-review-loop`,
   `validate-review-context-set.sh:262-265` prevents resuming a reserved
   session, so the sequential pass would be a fresh-context launch that re-reads
   all inputs — the same cost as the current blind launch, without the
   independence benefit.
3. **ADR-0027's pre-PR lane already offers the sequential option.** A human who
   wants sequential Reviewer→Critic outside the gates can invoke
   `skills/adversarial-review` directly, or trigger the ADR-0027 lane. The
   in-gate phase is for cost-bounded, deterministic, gate-compatible critique,
   not for replacing the full adversarial panel protocol.
