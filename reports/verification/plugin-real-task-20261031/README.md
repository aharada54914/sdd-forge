# Native plugin development completed: JUnit summary CLI

## Outcome and use

One real low-stakes development task ran through native sdd-forge adoption,
Lite specification, human task approval, implementation, actual tests and an
independent Lite gate. T-001 is **Done**, with a final **PASS** report.

The resulting [standard-library Python CLI](project/junit_summary.py) summarizes
actual testcase elements from one or more local JUnit XML reports:

```sh
python3 project/junit_summary.py REPORT.xml [REPORT.xml ...]
python3 -m unittest discover -s project/tests -v
```

It handles nested/namespaced suites and deterministic outcome precedence, ignores
stale aggregate counters, preserves input bytes and emits no partial JSON on
invalid input. Exit codes are 0 (pass/skip), 1 (failure/error), and 2 (invalid input).
See the [usage README](project/README.md) and [task](project/specs/junit-summary/tasks.md).

## What actually ran

1. Native Codex in the isolated verify profile used installed sdd-adopt and lite-spec
   against product source b9d3062ebd3fd172053dd9bf5e9df8b08d413eed. The six plugin
   payloads were refreshed through native registration and compared to that source.
2. Independent specification review found no blockers. It suggested the unknown
   XML encoding negative case within existing REQ-005.
3. The human changed only Approval: Draft to Approved in commit
   0dffce05e1e3438bb9f327288db4ec3fcf58040b. Parent verification used GitHub's actual
   commit/blob data, recorded in human-approval-origin.json and approved-snapshot.json.
   That approved snapshot was restored into the isolated app. No agent wrote the
   approval or issued a sudo token/signature.
4. Native implementation captured a real initial failing behavioral test before
   the application existed, then implemented the CLI and passed the full suite.
   Raw Red/Green and completed native events are retained, not reconstructed.
5. A separate fresh native session re-ran the tests and found a Lite gate report-path
   inconsistency. It returned FAIL and left Implementation Complete unchanged.
6. The product instruction was corrected, independently reviewed, and the sdd-lite
   plugin was reinstalled through its native registration path. Another fresh
   independent session re-ran verification, returned PASS, set Done, and then
   successfully executed the final task-state checker. Parent additionally ran
   the PowerShell checker against this actual Done workspace: exit 0.

The suite has four unittest methods with matrix subtests covering precedence,
namespaces, multiple/duplicate files, malformed XML/unknown encodings, exit behavior
and byte preservation. The first failing test remains in the final suite. No separate
lint/typecheck/build commands exist for this interpreted standard-library utility.

## Product defect found and repaired

implement-task writes reports/implementation/<feature>/<task-id>.md. Both existing
Bash and PowerShell Lite state validators already search recursively, but the
Lite gate's precondition text required only reports/implementation/<task-id>.md.
The actual first independent run therefore stopped despite passing app tests.

Commit 287f6d805df5da7bd47908eceb8df980540a8e90 fixes that single instruction to
recognize the standard feature path and retain legacy flat paths. It explicitly
requires matching the target feature/task. Approval rules, checks and Done ordering
are unchanged; no duplicate report was manufactured. The refreshed skill hash is
4aff3a213c1fcc9e9af8aa0ba23524ed77ca16e5e8ff935be22fbb5f0ff40d61.

The first FAIL is retained in gate-1-failed. The subsequent PASS is separate in
gate-2-passed and project/reports/quality-gate. The app, tests, README and author
report were unchanged by both reviewers; the final task change was Status only.

## Evidence and limits

- independent-assessment.json and artifact-index.json bind the final reviewed files.
- project/reports/quality-gate/T-001.direct.execution.json records actual project
  test execution. The adapter's empty-registry PASS alone is not test evidence.
- project/reports/quality-gate/T-001.final-state.execution.json records the post-Done
  validation. The source workspace was dirty; this is not a reusable clean-commit
  certificate. Exported file hashes bind the actual reviewed result instead.
- Each gate was a new native session, separate from implementation. This is
  independent context review, not a claim of different-model review. Runtime was
  the existing verify profile default; no unobserved exact model is asserted.
- The retained implementation report's phrase 'clarified by the user' for unknown
  encoding is corrected here: it was the independent specification review's
  suggestion, carried into the implementation prompt under existing REQ-005.
- The isolated native checkout did not contain the parent approval commit object;
  its report states that limitation. Parent GitHub verification is retained above.
- Historical Draft-stage prose in the specifications is preserved as authored;
  the explicit implementation request and human approval authorized the later stage.
- Raw traces stay in task scratch; published selections omit session/item identifiers
  where feasible, usage/debug logs, credentials and unrelated history. Execution
  paths remain in genuine error/output records for provenance.

This demonstrates one local Python CLI through the Lite flow. It does not establish
all-host support, production release operation, Project Context promotion or a
measured productivity improvement. Original issues: 31 closed; #602/#593 still need
Claude native evaluation. The separately deferred operational acceptance is #678.
