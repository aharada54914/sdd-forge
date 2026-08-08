# ADR 0026: High/Critical-Only Cross-Critique Phase for the Review Loops

Status: Proposed

Date: 2026-08-07

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
(`SKILL.md:25-26`) and by ADR-0025, which wires it *outside* them.

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
   contract (ADR-0025), so it can afford synthesis authority the in-gate
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
- **Relationship to ADR-0025:** complements, not overlap — ADR-0025's
  lane reviews a whole branch diff from outside the gates before a PR;
  this phase attacks one round's findings inside a gate. A feature can
  trigger both, each for its own reason.
