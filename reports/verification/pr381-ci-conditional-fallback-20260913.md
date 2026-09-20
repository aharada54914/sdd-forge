# PR #381: conditional CI execution is not coverage

Base commit: `1f00cea6385b7df1607ade73982243f959e358a6`
Worktree: `/Users/jrmag/.local/share/sdd-forge-pr381-main-sync-20260912`
Branch: `fix/pr381-main-sync-20260912`

## Root cause and repair

The fallback runner recognized a direct suite invocation without considering
the enclosing YAML step or job `if` condition. A disabled step therefore
removed its suite from fallback execution. A condition appearing after `run`
had the same problem. The repair buffers recognized invocations until the
whole step and job have been inspected. Conditional invocations do not prove
execution; their suites remain eligible for fallback execution.

No existing workflow job, check, inventory entry, or assertion was removed.
The parser continues to recognize the repository's explicit indentation and
simple run-body format; this is not a general YAML/expression interpreter.

## Executed evidence

- Baseline minimal disabled-step reproduction: exit 0 with an empty fallback
  list (incorrect). Reproduction inputs are the adjacent
  `ci-disabled-step-repro-20260913.yml` and
  `ci-disabled-step-inventory-20260913.txt`.
- Added step regression before the repair: exit 1, `disabled-step: expected
  fallback [tests/ci-suite-wiring.tests.sh], got []`.
- Added job regression before the job repair: exit 1, `disabled-job: expected
  fallback [tests/ci-suite-wiring.tests.sh], got []`.
- Final `bash tests/ci-suite-wiring.tests.sh`: exit 0; structural checks and
  17 behavioral controls passed. Controls cover conditions before/after run,
  job conditions before/after steps, and a subsequent enabled step.
- `bash -n tests/run-ci-unwired.sh tests/ci-suite-wiring.tests.sh`: exit 0.
- `git diff --check`: exit 0.
- Baseline fallback list: 59 suites. Repaired fallback list: 123 suites.
  Conditional POSIX steps are conservatively re-executed. The complete local
  run took 19m57.977s; this must not be described as a speedup.

## Complete local aggregate and remaining conditions

The complete repaired fallback run finished with exit 0:
`All 123 previously-unwired POSIX suites passed.`
Command: `bash tests/run-ci-unwired.sh`, with pipefail and output captured to
`/tmp/pr381-ci-conditional-fallback-20260913.log`; terminal session 21297 is
complete. Timing: real 19m57.977s, user 13m50.399s, sys 7m1.068s.
Log SHA-256: `213ca9c40c0ac7beec7fdc402baaafedd71f4cdd12710b494e74f7bbded4476e`.
Tested runner SHA-256: `b19beea5d9f6a5e295479207b71ca1f6204f84e53fb016eb83ebe3c6b60eca28`.
Tested wiring suite SHA-256: `6a02acc81a72a619dfc6cc5247ac3143868f07bbeaeff77da603d3308126cf1f`.
Post-run `git diff --check` returned 0. The aggregate's success is its suite
exit-status contract, not a claim that every environment-specific branch ran,
that a real host was activated, or that latest-head GitHub CI passed.

Scoped source review found no critical defect in the change. Performance
remains a warning until latest-head CI measures the expanded run. This is a local code
review, not an independent SDD verdict. PR #381's separate scratch-isolation
finding and required approval remain unresolved. No commit, push, merge,
review verdict, task status, or Issue closure was performed for this repair.

Next: complete publication checks, commit/push the scoped repair, check
latest-head CI, and obtain required review before merge.
Do not merge on the strength of the 17 focused controls alone.
