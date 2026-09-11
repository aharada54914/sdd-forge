# PR #381: distinguish suite execution from path mentions

Base commit: 9964b46b
Review thread: https://github.com/aharada54914/sdd-forge/pull/381#discussion_r3993000965

The fallback runner searched every non-comment workflow line for the suite
path. Removing a command while retaining its name in metadata could therefore
silently remove coverage. The old wiring test repeated that same predicate.

The runner now recognizes explicit step `run` fields in this repository's
workflow layout. A complete run body must consist of literal suite invocations,
optional existing tee logging, comments, blank lines or syntax-only preflights.
Unknown syntax retains the suite in the fallback instead of asserting execution.
This is deliberately not a general YAML or shell interpreter. In particular,
heredocs and conditional shell bodies do not establish execution. Bash `-n`
is allowed before execution but never counts as executing a suite itself.
No workflow job, dependency, check, suite registration or failure handling was
removed. The behavioral tests call the actual runner with a controlled inventory
instead of duplicating its implementation.

## Actual verification

- RED: the original runner failed the step-name control, omitting the only
  registered suite even though the workflow only echoed `done` (exit 1).
- Additional RED: the first candidate redundantly scheduled the installer shape
  that starts with a syntax preflight; the added syntax-then-execution control
  reproduced this (exit 1), then passed after recognizing syntax-only preflights.
- GREEN: `bash tests/ci-suite-wiring.tests.sh`: existing live-workflow checks and
  12 behavioral controls passed, exit 0. These include metadata, assertions,
  echoed commands, heredocs, shell conditionals, direct/multiline/logged
  execution, path-prefix mismatches and both syntax-preflight cases.
- `python3 tests/required-checks-posix.tests.py`: four tests passed, including
  failure/cancellation/skipping/empty-result checks for each of nine mandatory
  job dependencies. The required-checks body and workflow were not edited.
- Bash syntax and whitespace checks passed.
- Compared the old substring inventory with the new runner on the current live
  workflow: zero differences. Thus this repair neither drops suites nor adds
  duplicate execution for the current workflow.
- Local behavioral log: `/tmp/pr381-ci-wiring-final-20260912.log`.
  SHA-256: `da4ac169990e780a0c090680cd8d94332c8b44eaab604b49305353cc012ca2db`.

This report records scoped local verification, not full CI success or an
independent review verdict. Latest-head CI and independent review remain required.
The separate scratch-root reservation finding is not resolved by this repair.
