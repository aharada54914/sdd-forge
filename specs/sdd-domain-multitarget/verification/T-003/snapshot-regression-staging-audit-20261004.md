# T-003 immutable-snapshot regression staging audit (2026-10-04)

Diagnostic evidence only. This is not implementation, an independent review, a quality-gate verdict, or a task-status change. The original `snapshot-c43e18b9f2a7` and its 179-entry manifest were not edited.

## Root cause and bounded staging decision

- `prepare-task-snapshot.sh` makes original snapshot files `0444` and directories `0555` (`plugins/sdd-implementation/scripts/prepare-task-snapshot.sh:76-105`). This is the required immutable handoff, not a writable test workspace. `implement-tasks/SKILL.md:132-143,183-188` requires a validated immutable snapshot as the agent input; it does not require test-generated temporary fixtures to remain read-only.
- The existing regression driver deliberately copies real dependencies into `tempfile.TemporaryDirectory` test repositories and then overlays a stub to exercise failure paths (`tests/resolve-project-context-block-check.py:1485-1507,447-457`). `shutil.copy2` preserves the original snapshot file's `0444` mode on the destination. The subsequent fixture overwrite raises `PermissionError`. No SDD hook or protected-file policy refused this operation.
- A byte-identical *derived test stage* is permissible for these existing regressions: keep the admitted snapshot immutable, copy its listed files into a disposable directory, grant user write permission **only to that copy** for fixture assembly, and validate the copy against the same manifest. This does not change the handoff snapshot, input hashes, owner files, or any security setting. It is not a new implementation input or a substitute for the immutable snapshot.
- The staged match suite initially had two failures because the staged copy lacked `.git` metadata. The real `validate-facet-manifest.py:54-101` discovers the schema at a packaged path or at the Git root's `contracts/` path. The temporary stage had the admitted root schema but no discoverable Git root. `git init -q` **in the disposable test stage only** provided the normal repository-root metadata; it added no source input and did not modify the owner repository.

## Measured checks

Commands below were run through `rtk proxy`; `<owner>`, `<snapshot>`, and `<stage>` denote the owner checkout, the immutable snapshot, and a disposable `/tmp` derivative. No protected or frozen file was changed.

| Check | Exit | Observed result |
|---|---:|---|
| `sh plugins/sdd-implementation/scripts/validate-task-input-manifest.sh --manifest specs/sdd-domain-multitarget/verification/T-003/task-input-manifest-c43e18b9f2a7.json --snapshot-root <snapshot> --expected-task T-003` | 0 | `TASK_INPUT_OK`; original 179 input hashes remain valid. |
| Same validator with `--snapshot-root <stage>` after copy, permission staging, and temporary `git init -q` | 0 | `TASK_INPUT_OK`; all 179 staged source bytes match the admitted manifest. |
| `sh tests/resolve-project-context-cli.tests.sh` from immutable snapshot | 0 | 13 passed, 0 failed. |
| `sh tests/resolve-project-context-block.tests.sh` from writable derivative | 0 | 404 passed, 0 failed. |
| `sh tests/resolve-project-context-match.tests.sh` from writable derivative before test-stage Git-root metadata | 1 | 123 passed, 2 failed; both failures were schema discovery, not a resolver assertion. |
| Same match suite after `git init -q <stage>` | 0 | 125 passed, 0 failed. |

The smallest durable testing instruction is to run existing suites from a validated, writable temporary copy of the immutable snapshot with a temporary Git root. Do **not** chmod the original snapshot or treat this as a protection-refusal workaround. T-003 implementation and formal quality gate remain unperformed.
