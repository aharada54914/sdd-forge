# T-001 evidence alignment — one human-only batch candidate

`reports/verification/issue290-t001-alignment-human.sh --check` is read-only.
`--apply` is reserved for a human operator; it has **not** been run by the
agent. A prior protected-hook refusal must not be bypassed by another executor.

The batch reuses `issue290-t001-test-id-labels-20261002.patch` and adds
`issue290-t001-done-when-path.patch`. It changes only the displayed TEST IDs in
the Bash and PowerShell Markdown-mismatch helpers and the T-001 Done When
report path. Fixture IDs/paths, inputs, validator calls, assertions and test
conditions are unchanged. The task path becomes the existing
`reports/implementation/sdd-domain-concept-test/T-001.md`.

The launcher pins SHA-256 of both patch files and all three pre-apply target
files. Before any write, it checks patch applicability and copies the three
targets to a printed temporary backup directory. Its single `git apply` call
applies both patches; readback checks reverse applicability, whitespace,
post-apply hashes and the corrected task path. It does not commit or push.

Read-only verification on 2026-10-03: `--check` returned `CHECK_OK` with all
five SHA checks OK, and `git apply --check` accepted both patches together.
No post-application test, review or CI result is claimed.

Changing `tasks.md` alters a task-review hash-bound body. After human apply,
the task-stage provenance re-review must re-bind the changed document under
AGENTS.md's post-implementation rule before treating the task gate as valid.
Then rerun the affected Bash and PowerShell suites and the independent quality
gate. T-001 remains In Progress; neither Implementation Complete nor Done is
implied by this candidate.
