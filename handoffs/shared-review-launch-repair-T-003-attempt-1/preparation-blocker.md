# T-003 native implementation admission preparation

Date: 2026-10-10
Task: shared-review-launch-repair T-003
Owning checkout: /Users/jrmag/.codex/worktrees/shared-review-launch-integration/sdd-forge
Observed HEAD: 9ce19abe90df0cb83e385f96855e4843318a8807
Risk: high / protected entrypoint inventory and generated projections
Native implementation session: NOT STARTED
Reservation: NOT RUN
Formal review / quality gate / CI: NOT RUN

## Read-only preflight

Read the owning AGENTS.md, implement-task skill and its three required references, T-003 approved scope and acceptance mapping, existing T-002 attempt-4 helper and manifest. `rtk proxy bash scripts/check-sdd-structure.sh` returned exit 0, `check-sdd-structure: OK`, advisory `CLAUDE.md`. Existing dirty work was inspected and preserved. Status transitions remain the parent orchestrator's responsibility.

## Admission blocker

T-003 TEST-013 requires removing actual permanent CI transport registration from a disposable copy and observing rejection. Its source input is `.github/workflows/test.yml` (current registration at lines 37-39). The admitted implementation manifest cannot name that root-relative path:

- `plugins/sdd-implementation/scripts/prepare-task-snapshot.sh:55` requires a path matching `\A[A-Za-z0-9][A-Za-z0-9._/-]*\Z` in `path_ok`.
- `plugins/sdd-implementation/scripts/validate-task-input-manifest.sh:97` requires the same leading alphanumeric character.
- `contracts/task-input-manifest.schema.json:152` imposes the equivalent leading-alphanumeric restriction.
- `plugins/sdd-implementation/scripts/prepare-task-snapshot.ps1:17` and `plugins/sdd-implementation/scripts/validate-task-input-manifest.ps1:33` impose the same restriction in PowerShell.

The source path starts with a dot. This is a static, deterministic admission incompatibility, not an executed hook denial or native test failure. No snapshot, manifest, native identity or reviewer reservation was created. No alias, source-path rewrite, synthesized workflow, or alternative executor was used. The bounded T-003 Planned Files do not authorize repairing the manifest admission contract or validators. RT-20261009-001 remains T-001-only.

## Available regression results (2026-10-10)

- `rtk proxy python3 -B tests/host-review-preflight.tests.py`: 7 tests passed, exit 0.
- `rtk proxy bash tests/phase2-guard-invariants.tests.sh`: 42 passed, 0 failed, exit 0.

These existing-candidate checks are not T-003 native admission, new mutation coverage, formal review, Windows execution, or CI evidence. No task status or reservation was changed by these runs.

## Required scope decision

### Independent ownership check (2026-10-10)

The existing owner is `specs/agent-cost-context-isolation/tasks.md`, T-003
(Approved / Implementation Complete), not the shared-launch T-003.
Its design (`specs/agent-cost-context-isolation/design.md:109-113`) requires
repository-relative paths and rejects absolute paths, drive paths, backslashes,
`.` and `..` components, duplicates, symlinks and undeclared output roots. It
does not state a blanket prohibition on a leading-dot directory. Nevertheless,
the schema and four runtime consumers above currently impose that restriction.
An independent read-only ownership audit found no existing admission route for
the required workflow file. The old task's approval is not a new authorization
to alter this shared boundary or its frozen lifecycle evidence.

The current owner checkout was rechecked: `python3 tests/host-review-preflight.tests.py`
passed all 7 tests and `git diff --check` exited 0. These checks do not exercise
the blocked manifest path or replace the required T-003 mutation tests.
RT-20261009-001 is resolved under its explicitly T-001-only substitute-evidence
authorization; no additional chronology approval is needed for that ticket.

The five path-contract locations above are outside T-003 Planned Files. A bounded repair must admit the required `.github/workflows/test.yml` input consistently without allowing absolute paths, traversal components, symlinks or paths outside the declared input set, and add Bash/PowerShell/schema parity regressions. No such contract repair has been applied under the RT-20261009-001 evidence exception.

Resolve the admitted-input path boundary through the owning approved workflow before native launch. Then pin the finite T-003 dependency set, create the actual native session identity, execute task preflight and fixture mutation RED/restoration GREEN, collect exact output hashes, and hand off before owner adoption. Existing eight candidate registrations must be preserved. CI wiring remains T-004's responsibility.

## Superseding bounded repair — 2026-10-10

The user explicitly approved the limited repair. Five admission-contract/runtime
files and two existing regression drivers now admit dot-prefixed relative paths
while retaining traversal, symlink, hash and scope checks. Both complete local
Bash/PowerShell suites passed after reproduced original failures; independent
diff inspection found no remaining defect. See `dot-path-repair.md` beside this
record. The original blocker above is retained as history; path admission is
locally repaired, not proof of native task execution or formal quality approval.
