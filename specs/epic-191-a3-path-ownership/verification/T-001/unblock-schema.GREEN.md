# T-001 final GREEN evidence — 2026-08-08

Run ID: t001-20260808-codex-02

## Target twin suites

```text
bash tests/component-path-resolver.tests.sh
pwsh -NoProfile -File tests/component-path-resolver.tests.ps1
```

- Bash: 59 passed, 0 failed.
- PowerShell: 59 passed, 0 failed.

This includes the landed A1 schema/template conformance check, JSON Schema
instance validation, empty `components: []`, canonical `components[].id`,
canonical `ownership_input.components[].id`, raw-byte sorting, both
case-sensitivity layers, all classification branches, and CI/runner
registration checks.

## Downstream regression suites

```text
bash tests/component-path-diff-basis.tests.sh
pwsh -NoProfile -File tests/component-path-diff-basis.tests.ps1
bash tests/check-component-coverage.tests.sh
pwsh -NoProfile -File tests/check-component-coverage.tests.ps1
```

- Diff-basis Bash: 17 passed, 0 failed.
- Diff-basis PowerShell: 17 passed, 0 failed.
- Component-coverage Bash: 29 passed, 0 failed.
- Component-coverage PowerShell: 29 passed, 0 failed.

## Static and repository checks

```text
python3 -m py_compile plugins/sdd-quality-loop/scripts/resolve-component-paths.py
bash -n plugins/sdd-quality-loop/scripts/resolve-component-paths.sh tests/component-path-resolver.tests.sh
pwsh -NoProfile -Command '[ScriptBlock]::Create(...)' # product + test twin
git diff --check
rg -n 'component-path-resolver.tests.(sh|ps1)' tests/run-all.sh tests/run-all.ps1
git diff --name-only -- specs/epic-191-a3-path-ownership/tasks.md 'specs/*/human-copy/**' .github/workflows/test.yml
```

- Syntax checks: 3 passed, 0 failed.
- `git diff --check`: passed.
- Runner registrations: one matching entry in each runner.
- Protected/task diff check: empty.
- The non-protected CI-step draft's `MANIFEST.sha256` check is exercised by
  TEST-045.5 and passed in both target twins.

The long aggregate `tests/run-all.sh` / `.ps1` runs were started but stopped
after the scoped target and dependent suites had already passed; no aggregate
full-suite pass is claimed here.

## Re-capture — 2026-08-11 (RT-20260811-001 remediation)

The counts above describe the 2026-08-08 suite state and are superseded for
the delivered suite: the seq0680 gate found they matched no shipping version
(59-assertion counts against a then-66-assertion suite, and a
check-component-coverage 29/0 that had since inverted). Every number below is
from a fresh execution on 2026-08-11, after the RT-20260811-001 suite edits
(TEST-045.5 repointed to the human-copy candidate, TEST-045.6 replaced by
the commit-attribution check, TEST-056 + AC-049 self-check added) and the
RT-20260811-003 coverage-suite remediation:

```text
bash tests/component-path-resolver.tests.sh
pwsh -NoProfile -File tests/component-path-resolver.tests.ps1
bash tests/component-path-diff-basis.tests.sh   # with GIT_*_NAME/EMAIL set
pwsh -NoProfile -File tests/component-path-diff-basis.tests.ps1
bash tests/check-component-coverage.tests.sh
pwsh -NoProfile -File tests/check-component-coverage.tests.ps1
```

- Resolver Bash: 73 passed, 0 failed (exit 0).
- Resolver PowerShell: 73 passed, 0 failed (exit 0).
- Diff-basis Bash: 18 passed, 0 failed.
- Diff-basis PowerShell: 18 passed, 0 failed.
- Component-coverage Bash: 46 passed, 0 failed (exit 0).
- Component-coverage PowerShell: 47 passed, 0 failed (exit 0).

The full per-assertion transcripts of the resolver runs are the recaptured
`component-path-resolver.GREEN.log` / `component-path-resolver-ps1.GREEN.log`
in this directory (written by redirecting the real runs, not edited), and
the mutation evidence for every changed assertion is
`remedy-20260811-mutation.log` alongside them.
