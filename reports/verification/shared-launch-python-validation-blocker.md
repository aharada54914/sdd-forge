# Shared launch T-001: required validation gap

Owner: shared-review-launch-integration/sdd-forge
Observed HEAD: 9ce19abe90df0cb83e385f96855e4843318a8807
Scope: shared-review-launch-repair T-001; high-risk launch permissions.

The existing dirty implementation, approval records and historical evidence are
retained. This record does not change any approval, task state or verdict.

## Evidence and limitation

The implementation report records 43 focused regression successes, a separate
40-test independent diff review, and an unreserved native permission diagnostic.
These are not a formal quality-gate PASS or CI evidence.

`plugins/sdd-quality-loop/references/risk-gate-matrix.md:65-76` requires lint,
typecheck and build for code tasks. Its shell/docs/spec exception cannot be used
to classify this Python implementation as documentation.
`plugins/sdd-quality-loop/references/verification-policy.md:3-8` requires commands
to be detected from repository configuration, prohibits inventing commands and
requires missing checks to be reported.

Repository configuration searches found no Python pyproject, requirements,
setup, Ruff, mypy or Pyright configuration. Reviewed CI provides Python tests and
generator validation, not a Python lint/typecheck/build definition. MCP npm
checks do not verify the changed Python launch code. Syntax checks are not
substitutes for static typing or a defined distribution build.

## Required resolution

Define a bounded, reproducible Python validation configuration for the shared
launch implementation and its dependencies, including the actual artifact
assembly that the build check validates. Obtain approval for that additional
configuration scope before changing the approved task inputs. Do not waive the
checks, fabricate evidence or relabel the stack. Preserve prior review records
and perform the required provenance re-binding if approved inputs change.

Then run the configured checks, address real findings, and resume the existing
formal quality-gate path. T-005 depends on T-001; the subsequent architecture
change remains sequenced after the requested first integration. No reservation,
commit, push, merge, installation or global permission change was performed for
this investigation.

## 2026-10-08 approved resolution

The user approved the bounded configuration scope. Configuration now lives in
`tests/shared-launch-python/pyproject.toml` and
`tests/shared-launch-python-requirements.txt`, covering six shared-launch Python
sources. Ruff and mypy succeeded; the FilesOnly distribution test succeeded with
seven-file byte parity, executable help/syntax checks, and an unchanged owner
Git index. Logs: `shared-launch-handoff/T-001-static-final.log` and
`shared-launch-handoff/T-001-regression-final.log` (relative to this directory).
The latter records 63 focused regression successes and one build-test success.

This resolves the missing configured local checks, not formal quality evaluation
or remote CI. The workflow has a corresponding step but has not run remotely.
No installed plugin, global permissions, approval or frozen verdict was changed.
