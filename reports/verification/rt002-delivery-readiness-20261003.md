# RT002 T-001 delivery readiness — 2026-10-03

This is a non-frozen continuation inventory, not a reviewer input manifest, implementation report, identity reservation, quality-gate result, or authorization to bypass a refused hook. No historical artifact or protected installed source was changed for this observation.

## Three missing owner-relative governing inputs

The current T-001 `Must Read` in `specs/epic-189-a1-rt002-repair/tasks.md` names all three paths below. They are absent at those paths in this owner worktree. Each exists in the primary `/Users/jrmag/sdd-forge` checkout with the following raw SHA-256 (observed 2026-10-03):

| Repository-relative path | Primary SHA-256 | Authority boundary |
|---|---|---|
| `docs/review-tickets/RT-20260909-002.yml` | `ae2b554aa9416c2997bef00143183f3cbcc7d79610c000d7c7b8928175241d74` | Open, human-authorized **limited** repair ticket; not a quality verdict or general bypass. |
| `reports/verification/hook-recovery-entry-contract-20260909.md` | `2ca4125082c495724b0bbde33e7451edb21fc4042827c1e67b4354eb9215e79f` | Human-scoped recovery-entry contract, marked proposed; its repair-specific route is not ordinary implementation or quality-gate approval. |
| `specs/epic-189-a1-rt002-repair/verification/T-001/two-envelope-extra1-20260928/candidate-precedence-20260928.md` | `e6aa4354777a9b5b844cd9565d85dcdef275f941e1e1543d3dd777db73f5cd3a` | Its own header records candidate-only generation. Later `requirements.md:6` and `tasks.md:5,55` explicitly adopt the limited two-envelope precedence for re-review; that later adoption does not turn the historical generation event into a PASS. |

The earlier `verification/T-001/completion-preparation-20261003/entry-observation.md:74` records a read from primary, but expressly says that read did not assemble a formal evaluator input. The 2026-10-02 split-plan adoption reconciliation records human adoption of the amended two-task plan; do not ask for the same adoption again. The current T-001 plan is Approved/In Progress, not Implementation Complete or Done. Its latest independent task re-review is plan evidence, not implementation or quality-gate proof.

## Minimum lawful continuation input preparation

1. The owner/maintainer must intentionally make the three exact primary bytes available at the three canonical owner-relative paths through the permitted input-preparation workflow, then independently rehash them in the owner checkout. This note does not copy them, alter protected source, or authorize mechanical replacement of the shared identity ledger. If that preparation is refused, stop at the refusal; do not reroute it.
2. A fresh T-001 implementation continuation must start with its **own** path/SHA-pinned input manifest and real run/session identity. At minimum, pin the current owner `AGENTS.md`, `specs/epic-189-a1-rt002-repair/tasks.md` (currently SHA-256 `75d0e1d8a837ef22ea6d6df4e90d57c6328a87828205c668de4bd26b6a0fe696`), the eight task `Must Read` feature documents (`requirements.md`, `design.md`, `acceptance-tests.md`, `traceability.md`, `ux-spec.md`, `frontend-spec.md`, `infra-spec.md`, `security-spec.md`), and the three rows above. Pin any additional prior evidence, code, scripts, review records, or policy inputs actually read; no undeclared primary-checkout reads may stand in for owner inputs.
3. Reconcile the real current T-001 evidence and Done When 1–5 in a **new canonical** `reports/implementation/epic-189-a1-rt002-repair/T-001.md`, with its own Run ID, Task Attempt Count, exact output path/SHA declarations and honest gaps. Preserve the historical flat preflight report. Do not create a historical-worker identity or copy a ledger entry. A fresh run can establish only its own identity and evidence; it cannot retroactively become the historical worker.
4. Only after actual Implementation Complete, seek independent quality-gate launch on declared inputs. The current launch contract/validator provenance mismatch and the unapplied shared launch repair remain separate blockers; the Issue #423-style repair is not established as applied here. Do not manufacture a PASS or consume the remaining reviewer launches merely to probe a known-invalid boundary. No local-suite rerun is needed for unchanged already-green bytes; a changed input or implementation requires proportionate revalidation.

This inventory is deliberately smaller than a final evaluator manifest. Before either formal launch, the responsible owner must expand it to **every** byte actually admitted or consumed, with exact canonical paths, current SHA-256 values, and the corresponding permitted provenance. T-002 is Draft/Planned; native Windows/latest-head CI, integration, merge, and post-merge acceptance belong to its separate boundary.
