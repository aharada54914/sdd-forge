# T-004 Independent Review

Result: **FAIL**

Reviewer: `T-004-independent-reviewer` (standard tier, fresh agent)

Independence: I reviewed only the hash-bound inputs in
`manifests/T-004-review.json`, ran the scoped tests independently, and did not
use implementation chat history or modify product code, tests, task state, or
traceability.

## Findings

1. **Major — fallback evidence and host capability are not actually proven by
   the green fixture.** The contract text requires one batch-wide capability
   decision, a persisted evidence artifact, disk reread, and revalidation.
   However, the fixture only checks for policy strings and a nonempty 64-hex
   value. An invented hash with no evidence artifact passes
   `TASK_INPUT_OK`; a mixed `fresh-agent`/`same-session-file-reload` batch that
   reuses the same physical session and agent IDs also passes batch validation.
   Thus the passing tests do not establish that fallback is limited to
   incapable hosts or that saved artifacts were actually reloaded. Add a
   deterministic, executable check binding the capability decision and evidence
   path/content to the batch, plus negative fixtures for fabricated evidence
   and mixed modes.

2. **Major — the required orchestration policies conflict.**
   `implement-tasks/SKILL.md` requires incapable hosts to reuse physical
   session/agent IDs across tasks, while its required delegation policy says
   “Enforce one session per task.” The latter was a planned T-004 file and is
   followed “in full” by the orchestration skill. State the incapable-host
   fallback as the explicit exception so one execution cannot be required both
   to reuse and not reuse the session.

3. **Major — a T-004 Done-When condition remains unmet.** `tasks.md` requires
   an isolated rollback fixture restoring the 1.4.0 loop and passing identity
   tests. The implementation report explicitly records that this fixture was
   not runnable and remains dependent on T-008. T-004 cannot pass its approved
   task contract until that criterion runs successfully or the task contract is
   revised and reapproved.

## Commands and Evidence

- Manifest/hash validation:
  `bash plugins/sdd-implementation/scripts/validate-task-input-manifest.sh --manifest reports/implementation/agent-cost-context-isolation/manifests/T-004-review.json --snapshot-root . --expected-task T-004`
  → `TASK_INPUT_OK`.
- `bash -n tests/turn-first-workflow.tests.sh` → PASS.
- `bash tests/turn-first-workflow.tests.sh` → PASS.
- `bash tests/task-context-isolation.tests.sh` → PASS.
- `pwsh -NoLogo -NoProfile -File tests/task-context-isolation.tests.ps1` → PASS.
- Independent temporary-manifest probes:
  fabricated reload hash → `TASK_INPUT_OK`; mixed fresh/fallback batch with
  reused physical identities → `TASK_INPUT_OK`.

The orchestration text does explicitly require fresh per-task capable-host
agents, adjacent and nonadjacent identity uniqueness, file-only handoff,
recorded incapable-host fallback, and no reviewer/evaluator fallback. The
findings above prevent those statements and the approved Done-When contract
from being verified as implemented.
