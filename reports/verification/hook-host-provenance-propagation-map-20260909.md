# RT002 provenance propagation inventory

Date: 2026-09-09
State: preparation only; canonical frozen specifications unchanged
Authority: hook-recovery-entry-contract-20260909.md

The identifier sweep covered requirements, design, acceptance tests, all four
layer specifications, and tasks for epic-189-a1-project-context. It searched
plugin_hooks, denied_by_plugin_hooks, PLUGIN_HOOKS_DISABLED, REQ-010, AC-027,
TEST-027 and review status fields. The following spans must be reconciled in
the scoped provenance amendment; a report outside allowed reviewer inputs
cannot silently supersede them for a formal gate.

| Artifact / observed line | Required treatment |
|---|---|
| requirements.md:107, 994, 2245 | Retain the historical plugin-origin adapter as legacy; distinguish absent evidence metadata from observed configuration; define the explicit operation-bound adapter and re-verification of current host bytes. |
| requirements.md:1472 (AC-027) | Expand exact adapter branches into concrete acceptance rows, including nonce/type/schema/duplicate/whole-envelope negatives; retain legacy and live-proof scope boundaries. |
| design.md:1104, 1752 | Version-select before runtime dispatch; pin exact envelope and emitted nonce; preserve no-schema legacy and cleanup semantics. |
| design.md:141 | Empty/placeholder sentinel description must distinguish the new Codex challenge content without implying real approval content. |
| acceptance-tests.md:49 (TEST-027), :54 (TEST-032) | Add explicit new-adapter assertions and duplicate cleanup rejection; retain all existing stale-start, sidecar non-mutation and cleanup requirements. |
| security-spec.md:71, 86, 121 | Explain exact operation binding and plain-file trust limit; update “no defined content shape” for the Codex template only. |
| infra-spec.md:94 | Reconcile transient sentinel content description, retaining no backup/lasting mutation and mandatory cleanup behavior. |
| tasks.md:1954 and T-008 repair addendum | Record scoped repair and preflight without rewriting historical Done or counting advisory review as quality-gate completion. |
| ux-spec.md / frontend-spec.md | No plugin-origin literal found in this sweep; keep content unless full-input review identifies a concrete conflict. |

Shared decision document docs/ai-dlc-foundation-decision-v2.md:262 contains
the historical plugin flag prerequisite. Record explicit dated supersession
for this adapter rather than making an unsupported global runtime claim.
Investigation facts remain historical; any conflicting span needs an explicit
precedence note in an allowed governing input (AGENTS.md WFI-023).

Current requirements, design and tasks headers are respectively
Spec-Review-Status: Passed, Impl-Review-Status: Passed, Task-Review-Status:
Passed. The spec-review skill requires Pending and a legal next attempt/round;
do not launch a normal round on these Passed artifacts, overwrite prior rounds,
or mark the recovery addendum itself as a canonical passed specification.
Next preparation must resolve the sanctioned reopening and exact input set
before formal reservation/launch. The RT002 exception only admits its own
repair reviews; it does not admit unrelated PR implementation or waive any
other precheck.

## 2026-09-09 sanctioned reset-path clarification

The original `plugins/sdd-review-loop/scripts/spec-review-precheck.sh`
accepts a Passed or Pending header with --reset (lines 144-147), requires the
previous terminal PASS/BLOCKED contract to validate (349-357), and changes
Passed to Pending only after validation, recomputing hashes (385-395).
Thus the required reopening mechanism exists; the preceding paragraph's
discovery task is resolved, not an instruction to edit status manually.
Do not run it against the old canonical text merely to reserve a new round:
the scoped human-applied amendment must be the input being rebound. Keep
all previous review records. Any remaining precheck failure remains a real
failure, not covered by the handshake-only admission.
