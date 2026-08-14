# ADR 0027: Risk-Adaptive Adversarial Review Lane

Status: Proposed

Date: 2026-08-07

## Context

`skills/adversarial-review/` packages a two-reviewer mutual-critique
protocol (blind parallel review → cross-critique → synthesis → fresh-context
fix verification) with a proven record: the review round that produced the
epic-136 plan found an RCE with it, and its own proving run re-calibrated
four of five initial severities and caught a defect *inside a fix text*
(SKILL.md "Real-world impact"). Yet the skill is completely orphaned today —
zero references from `plugins/` (verified 2026-08-07, issue #128 Finding
A-1/A-8) — because both of its boundaries are stated but no lane exists
between them:

- It is explicitly **not** for SDD gate reviews (`SKILL.md:25-26`): the
  spec/impl/task review loops have their own deterministic contracts
  (ADR-0001 independence, hash-bound manifests, identity ledger), and
  grafting a conversational protocol into them would dilute exactly the
  properties those gates exist to enforce.
- It is explicitly not for routine diffs (`SKILL.md:24`): two reviewers,
  a critique round, and a fresh verification pass cost several agent-runs
  per target. Applying that to every task is cost-prohibitive, which is
  why "wire it everywhere" has never happened and never should.

What the repository already has, and this decision reuses rather than
reinvents, is a **risk vocabulary**: every task carries a `Risk` tier
(`low`/`medium`/`high`/`critical`, `risk-classification-policy.md`)
proposed by the agent, confirmed by a human, and enforced via
`risk-gate-matrix.md`; `high`/`critical` already trigger stricter
workflows (TDD, two-person approval). What is missing is a review lane
keyed to that same tier.

## Decision

1. **A named lane, outside the gates.** The adversarial-review protocol
   runs as a **pre-PR lane**: after the quality gate has marked the
   branch's tasks Done and before the PR is opened (or, for changes that
   bypass the SDD pipeline entirely — direct chore/fix branches — before
   requesting merge). It reviews the branch's **cumulative diff against
   the merge base**, not individual tasks. The SDD gates themselves are
   untouched: no reviewer role, precheck, contract, or ledger schema
   changes. This preserves `SKILL.md:25-26` and ADR-0001 rather than
   overriding them. (The narrower question of strengthening the gates'
   *own* internal critique is issue #130's, decided separately in
   ADR-0026 — the two are complements, not alternatives: this lane sees
   the whole diff coarsely; #130's phase sees one artifact deeply.)

2. **Deterministic, auditable firing predicate.** The lane fires when the
   branch satisfies **any** of:
   - **Risk tier**: any task on the branch carries `Risk: high` or
     `Risk: critical` (the tier already human-confirmed at the Approval
     gate — no new judgment is introduced);
   - **Workflow surface**: the diff touches `plugins/*/skills/`,
     `plugins/*/agents/`, `plugins/*/scripts/`, or applies a WFI;
   - **MCP surface**: the diff touches `mcp/`;
   - **Security surface**: the diff touches guard scripts, hook
     configuration, CI workflows, or anything `risk-classification-
     policy.md:16-17` names as sensitive (auth/secrets/access-control),
     including human-copy staged candidates for protected files.

   The predicate is path-and-field based so a script can evaluate it; the
   PR body MUST record the evaluation either way (`Adversarial-Lane:
   fired` with the report path, or `Adversarial-Lane: not-required` with
   the reason), so silence is auditable — the same discipline the skill
   itself applies to verified non-findings.

3. **The protocol is the existing skill, unmodified.** Phases 0–3 and R
   of `skills/adversarial-review/SKILL.md` run as written (disjoint
   lenses, blind first pass, per-finding cross-critique verdicts,
   synthesis with rejected findings retained, fresh-context fix
   verification). The lane adds only an invocation context, an input
   definition (the merge-base diff plus AGENTS.md house rules), and an
   output location: `reports/adversarial-review/<branch-slug>/report.md`,
   linked from the PR body.

4. **Findings do not gate deterministically; they gate socially.** The
   lane's report is review input for the human merger, exactly like a
   human review comment. It creates no new machine-enforced gate — a
   CRITICAL finding does not block CI. Rationale: the protocol's value is
   judgment (severity calibration, over-engineering critique), and
   machine-enforcing judgment is how severity inflation gets laundered
   into process; ADR-0001's deterministic gates already cover what must
   never merge. If experience shows CRITICAL findings being merged over,
   a follow-up ADR can revisit.

5. **Wiring is gated on this ADR's acceptance.** Because the lane's
   invocation instructions live in workflow documents (a new
   `references/` entry for the lane, a pointer from the PR-creation
   step, and the PR-body field), the wiring lands as its own change
   after a human accepts this ADR — workflow changes require human
   approval (`sudo-mode-policy.md:52` class), and this document is the
   artifact that approval attaches to. Until then the lane may be invoked
   manually by asking for an adversarial review, which the skill already
   supports.

## Consequences

- **Cost stays bounded.** The lane fires only on the enumerated
  surfaces; routine feature branches (`Risk: low`/`medium`, no
  workflow/MCP/security paths) see zero added cost.
- **The orphan gains a contract.** The skill stops being dead weight:
  its "when to use" section acquires a repository-specific, mechanical
  answer instead of ad-hoc human memory.
- **Two known gaps, accepted.** (a) A mis-tiered task (`Risk: medium`
  that should be `high`) escapes the lane — mitigated by the existing
  human confirmation of tiers and by the path-based predicates, which
  fire regardless of tier for the highest-value surfaces. (b) The lane
  reviews diffs, so a defect whose harm is only visible in unchanged code
  it interacts with can be missed — accepted as inherent to any
  diff-scoped review; the fresh-context Phase R mitigates the fix-side
  half of that risk.
- **No gate-determinism impact.** The SDD loops' contracts, manifests,
  and ledger are byte-identical before and after this decision.
