# T-009 incomplete-candidate handoff

This is implementation evidence, not an independent review or quality verdict.
The implement-task context-management policy requires ending after compaction.

## Executed failures requiring continuation

1. `final-cloud-contracts.log`: 31 passing tests, one failure. Existing closed
   `cloud-*.schema.json` family inventory does not include the new
   `cloud-verification-registry.schema.json`. This is introduced by this
   candidate, not an environment excuse. Resolve within approved scope or ask
   root for the precise test-dependency extension; do not weaken the assertion.
2. Both `final-guard-invariants-*.log` fail their WFI-016 live/staged-byte
   assertion for `check-contract.ps1`. The generator checks themselves pass.
   Historical staged bundles are frozen. Do not overwrite historical bytes;
   root must determine the sanctioned additive projection treatment. Bash has
   41 passes/one failure; PowerShell 54 passes/one failure/one existing skip.
3. Registry parity initial failure lacked Node; retry supplies the actual Node
   directory and has 21 passes/one preexisting dirty-workflow failure. Preserve
   `.github/workflows/test.yml`; a disposable committed candidate or root's
   exact-commit suite is still needed.

## Remaining verification

- Portable `shutil.which("pwsh") or shutil.which("powershell")` discovery and
  additional schema/profile/property case negatives are present in the test
  source, but were edited after final-cloud-verification began. That log's
  70 passing tests do NOT certify the final test bytes. Rerun them with the
  environment's wrapper on PATH. Missing PowerShell explicitly skips only its
  subtest; it must not be described as native consumer coverage.
- Persist separate WFI-012 operator and cmdlet/language-feature sweeps and their
  executed miscase fixtures. These sweeps are not yet complete.
- The pinned ruff and configured mypy commands all exited zero, but a fresh
  final-byte run should accompany the portability rerun. Exact commands and
  MYPYPATH are in final-commands.json; no default-mypy substitution was used.
- Audit every field/counterpart mismatch and sensitivity cell. Initial Red
  actually exercised two existing guards, not every new persisted field. The
  broader checklist had planned cases, which are not retrospective executed
  Red. Sensitivity currently covers preview binding, registry/checkset and AWS
  authenticated preview readback, not every new AWS readback guard separately.
- Disposable task-owned rollback has NOT been executed. Scratch snapshot holds
  initial source bytes including prior T006 candidate work; restore only owned
  source files in a disposable checkout and preserve all other candidate work.
- Python 3.6 legacy grammar/import isolation was tested with the current
  interpreter; an actual Python 3.6 executable was not run.
- No live cloud, native Windows, independent review, quality gate or complete
  repository suite was run. Live acceptance remains BLOCKED by owner inputs.

## Chronology and preview authority

Initial Red commit cba7a7ad contains two actually failing boundary assertions.
AWS post-apply substitution Red commit f2d51e4a shows an AWS PASS despite locally
rehashed empty changes; Azure rejects via authenticated original job title.
The later shape-valid Workload-to-PrivateGroup substitution and bypass
sensitivity are Green-only extensions, not historical Red executions.
AWS now authenticates executed Change Set and original template/asset/parameters
through native readback before and after collection. Azure uses its original
protected workflow job's request/preview digest binding. All tested transport
responses are synthetic protocol fixtures, including native-class mocks; none
establish IAM/live health. Saved files and synthetic collection remain BLOCKED.

The initial entry.json records the then-unresolved provenance question. It is
superseded by root-provenance-design.md and the validated supplemental manifest,
not rewritten as if permission existed earlier. No additional task status,
approval, historical report, frozen spec, or workflow change was made here.
