# Task Review Round 1 — Proposed Changes: epic-192-a4-facet-manifest

Verdict: NEEDS_WORK (findings: Critical 0 / Major 1 / Minor 0)

- Reviewer A (RUN-epic-192-a4-facet-manifest-task-task-reviewer-a-seq0324): PASS 14/14
- Reviewer B (RUN-epic-192-a4-facet-manifest-task-task-reviewer-b-seq0325): NEEDS_WORK
  (RISK-APPROPRIATE Major; HIGH-CRITICAL-EVIDENCE and the remaining 6 checks PASS;
  BUGFIX-DIAGNOSTIC-PATH SKIP — no bugfix/debugging task in scope)

## Finding 1 — RISK-APPROPRIATE (Major)

T-002 declared `Risk: medium` while authoring
`contracts/capability-summary.schema.json`, a new externally-visible API
contract design.md's own Cross-Layer Dependencies names as "consumed by
Epic A5's Capability Resolver." `plugins/sdd-quality-loop/references/
risk-classification-policy.md`'s `high` tier explicitly names "public API
contracts" as a sensitive surface, and separately states "An agent MUST NOT
self-certify its own risk tier as the basis for relaxing a gate." T-002's
original Risk Rationale relaxed the tier via exactly that kind of
self-certified narrowing — arguing the artifact's *current* absence of an
already-committed downstream consumer (unlike T-001's `affected_components`,
which Epic A3 already reads) made it materially lower-risk than T-001's
sibling schema. The policy's `high` trigger for "public API contracts" names
no such carve-out; both T-001 and T-002 author a new `contracts/
*.schema.json` file in the same Architecture diagram, with the same
downstream Epic A5 consumer.

### Proposed change (applied)

Re-classify T-002 to `Risk: high` / `Required Workflow: tdd`, matching
T-001's/T-003's/T-004's own tier for the identical "new public API contract"
trigger. Rewrite the Risk Rationale to cite the policy trigger directly
(public API contract, Epic A5 consumer) rather than a self-certified
narrowing, matching the wording discipline T-001/T-003/T-004 already use.
Add the same "TDD evidence" Done When item T-001/T-003/T-004 carry (RED
fixtures against a deliberately non-conformant schema/validator; GREEN
against the correct one; captured in `specs/epic-192-a4-facet-manifest/
verification/T-002/{red,green}-sh.log`; an independent quality-gate verdict
recorded), replacing the "Acceptance-first evidence" item the medium tier
previously required. Update the task header's `Requirements Field`
line-level parenthetical unaffected (no AC/REQ scope changes — this is a
risk-tier correction only, not a scope change). Update
`traceability.md`'s Task Mapping row for T-002 to reflect the corrected
evidence expectation (implementation report with TDD red/green evidence,
replacing "acceptance-first evidence").

No other task, no REQ/AC coverage, and no dependency edge is affected by
this fix — it is scoped entirely to T-002's own Risk/Required
Workflow/Risk Rationale/Done-When-evidence-item fields.

## Edit summary (for round 2 re-invocation)

"Re-classified T-002 (Capability Summary schema authoring) from Risk:
medium/acceptance-first to Risk: high/tdd, per reviewer-b's RISK-APPROPRIATE
finding: risk-classification-policy.md names 'public API contracts' as a
high-tier trigger with no self-certified-narrowing exception, and T-002
authors the same class of new, Epic-A5-consumed contracts/*.schema.json
file T-001/T-003/T-004 already correctly classify high. Rewrote T-002's
Risk Rationale to cite the policy trigger directly; replaced its
acceptance-first evidence Done When item with the TDD RED/GREEN +
independent-quality-gate-verdict item matching T-001/T-003/T-004's own
wording. traceability.md's Task Mapping row for T-002 updated to match (TDD
evidence, not acceptance-first evidence). No REQ/AC/Blockers/scope change.
Edit applied by the orchestrating agent under the delegated Phase 2
authority (epic #187 / issue #192); tasks remain Draft for human approval."
