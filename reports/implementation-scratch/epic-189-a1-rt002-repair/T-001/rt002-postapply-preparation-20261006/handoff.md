# RT002 post-application input preparation

Preparation only; no implementation identity or gate verdict.

- Owner HEAD: `1e86fb272643e798db4e1ca0c89f0402317a2fc8`; existing 17 tracked modified paths and untracked evidence preserved.
- Risk: high/protected context and snapshot contract. No protected edits, reservations, lifecycle changes, Git writes or sealed-snapshot changes.
- `scripts/check-sdd-structure.sh` exited 0 with `advisory: CLAUDE.md`, `host: github`, `check-sdd-structure: OK`; no missing items.
- Read owner AGENTS, implement-task and implement-tasks skills and implementation-policy, implementation-craft-policy, agent-delegation-policy references. This is preparation, not direct implementation/task-state transition or an automatic quality gate.
- `input-inventory.json` records 86 actual current path/content SHA-256/mode observations: all 79 prior entries retained plus seven necessary current builder/validator/runtime-test/workflow/ticket/postapply evidence inputs. Only the Bash builder content changed relative to the prior 79-entry manifest. Source modes are supplementary inventory, not a new manifest-v1 field or stronger mode-binding claim.
- Applied originals already passed both original-path runtime suites; see the admitted `original-path-postapply-20261006.md`. Native Windows, installed activation, current CI and formal quality gate are not inferred from those fixture runs.

## Identity boundary and remaining preparation

The preparing agent is a resumed, compacted context previously used for other bounded investigations. It cannot truthfully use a new `fresh-agent` claim or reuse its former session/agent IDs for a fresh implementation launch. `implement-tasks/SKILL.md:142–145` requires exactly one fresh implementation agent, no inherited chat history and no reuse of a prior run/session/agent instance. Agent-delegation-policy Context Hygiene likewise requires fresh task context and does not permit a capable host to invent unavailable-host fallback.

Parent was notified that a real fresh receiving context's session/agent/model and current invocation cost metadata are required before constructing a launch-valid full `task-input-manifest/v1`. No placeholder identity or copied old planning estimate is used. Existing USD 10.00 is historical provisional planning only, not actual usage, billed cost or authorization.

Once actual metadata is supplied, construct the new full manifest using the inventory's path and sha256 pairs (source_mode stays inventory-only), declared task-specific output root, and T-001. Rehash every input immediately before preparation. Use the existing `prepare-task-snapshot.sh --manifest NEW_MANIFEST --repo-root OWNER --snapshot-root NEW_ROOT`, then `validate-task-input-manifest.sh --manifest NEW_MANIFEST --snapshot-root NEW_ROOT --expected-task T-001`, and required complete batch validation before launch. NEW_ROOT must not exist. Do not alter the old sealed snapshot or reuse old declarations. The fresh receiver must check structure/executable readiness, task/report state and applicable preflight before any test/implementation. T-002 remains outside scope.

At this handoff creation, full manifest and snapshot are not created or validated; input inventory is ready. This is a specific identity-metadata dependency, not a request for renewed human approval and not a formal Blocked state change.
