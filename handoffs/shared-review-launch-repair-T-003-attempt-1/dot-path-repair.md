# T-003 repository-relative dot-path repair

Owner: shared-review-launch-integration/sdd-forge
Baseline HEAD: 9ce19abe90df0cb83e385f96855e4843318a8807
Risk: high (manifest admission boundary)
Authorization: user's limited-repair approval, 2026-10-10.

Before editing: 27 tracked modified files and existing untracked integration
artifacts retained. The five production targets and both task-context-isolation
test drivers were clean. This repair changes only their path admission and tests.
No ledger reservation, frozen evidence, approval, or task status is changed.

## Preflight

| Persisted field | Counterpart | Required mismatch regression |
| --- | --- | --- |
| allowed_inputs[].path | repositoryPath schema; immutable snapshot relative path | `.github/workflows/test.yml` must copy and validate; traversal, absolute, drive, backslash and empty components must fail |
| allowed_inputs[].sha256 | bytes copied from source and read from snapshot | existing tampered-byte test must remain failing with HASH diagnostic |
| allowed_outputs[] | declared repository-relative output boundary | dot-prefixed declared output accepted; traversal and input/output overlap rejected |

Callers remain the snapshot builders and manifest validators for Bash and
PowerShell. Existing task-context-isolation suites retain immutable publication,
symlink and identity-negative tests. Validation proceeds through reproduced RED,
five-file focused fix, both full suites, schema check, independent diff review.
Native Windows, formal task evaluation, CI and merge are not proven by local tests.

## Executed result — 2026-10-10

The original Bash and PowerShell builders both reproduced exit 1 with
`TASK_INPUT_PATH: invalid input path: .github/workflows/test.yml`.
After the bounded five-file repair, both complete task-context-isolation suites
exited 0. Four schema-positive and ten schema-negative cases cover dot paths,
internal empty components, traversal, absolute/drive/backslash paths and legacy
terminal output slashes. Existing hash, symlink, identity and publication checks
remain in both suites. `git diff --check` exited 0.

Independent diff inspection found a schema empty-component gap; it was corrected
and the final suites rerun successfully. Final independent inspection reported
no further defect. That reviewer did not rerun the suites or native Windows.
Formal evaluation, native T-003 admission, Windows CI and merge remain pending.
