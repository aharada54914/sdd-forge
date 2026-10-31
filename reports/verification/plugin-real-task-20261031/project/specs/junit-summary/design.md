# Design (lite): JUnit summary CLI

## 1. Approach

There is no existing application or test pattern to extend. Add one Python
standard-library script, with a `main(argv=None)` entry and a main guard.
Use argparse for file arguments/help, xml.etree.ElementTree for reading XML,
and json for serialization. No dependency or packaging setup is needed.

## 2. New / changed files

- `junit_summary.py`: argument parsing, XML validation/counting, aggregate output and exit handling.
- `tests/test_junit_summary.py`: unittest CLI subprocess coverage using temporary XML files.
- `README.md`: extend the existing short description with usage and verification.
- `reports/implementation/junit-summary/T-001.md`: implementation summary and commands.
- `reports/implementation/junit-summary/T-001-red.txt` and `T-001-green.txt`: raw stdout/stderr and recorded exit statuses from actual test executions.

## 3. Data / interface

Proposed serialization: one compact JSON line followed by newline, with keys in
the specified order, for example
`{"tests":4,"passed":1,"failures":1,"errors":1,"skipped":1}`.
Successful parsing emits no stderr. Help exits 0 with argparse's help text;
the JSON contract applies to report runs, not help.

Parse each path without opening for write. Validate the root's XML local name
(strip a leading `{namespace}` prefix) against `testsuite` / `testsuites`.
Walk the full element tree once; for each element with local name `testcase`,
inspect direct children by local name and select exactly one outcome. Do not
read suite totals or treat namespaced and unqualified cases differently.
Unknown elements/outcome children do not themselves add counts. Identical
paths supplied twice count twice as two supplied reports; no deduplication.

Accumulate counts in memory, printing only after every report validates.
Catch expected file-read and XML parse errors at the CLI boundary; include
the offending path and a short reason in stderr, return 2. Unsupported roots
get the same treatment. No arguments uses argparse's stderr error path and
exit 2. Avoid broad exception handling that would conceal programming bugs.
Files are never rewritten or normalized; binary XML parsing honors XML encoding.

## 4. Test strategy

Use `sys.executable` and subprocess against the script's absolute path, capturing
stdout, stderr and status. Create fixtures in TemporaryDirectory, using only
unittest and other standard-library modules. Check exact JSON serialization in
at least one case and decoded integer counts throughout.

- Single passing testcase; mixed pass/failure/error/skipped; skip-only and empty roots.
- Both allowed root forms, nested suites, bogus aggregate attributes and multiple files.
- Every precedence combination, repeated outcomes, unknown children, namespace-qualified roots/cases/outcomes (default and prefixed namespaces).
- No arguments, missing/unreadable path (use a directory path for a portable read failure), malformed XML, unsupported root, and valid file followed by invalid file: exit 2, empty stdout, concise stderr without traceback.
- Help exits 0. Compare fixture bytes before/after valid and invalid runs.
- Verify invariant `tests == passed + failures + errors + skipped`.

First create a meaningful CLI behavior test, execute it before creating the
application, and preserve actual failing output/status in the Red file. Then
implement, expand coverage above, and capture the complete passing suite in the
Green file using `python3 -m unittest discover -s tests -v`. A missing-script
failure must be visible as a failed behavioral assertion, not reported as a pass.
No test or application execution evidence exists at specification time.

## 5. Intake boundaries

Structure checker passed with host local; optional contracts and architecture
directories and remote CI/templates are omitted. AGENTS.md/CLAUDE.md were adapted
from the installed adoption templates for the explicitly selected lite flow.
No existing project files were overwritten during adoption; no ADR drift exists.
The handshake's real canary write was denied; recorded raw result is in
`reports/implementation/hook-response.json`; installed verification returned
`HOOK_ACTIVE` for nonce `e1ea7aee12629214d1c8d1ec17468f84`.
Project Context is physically absent: C1 compatibility fallback / disabled-legacy,
using AGENTS.md's lite profile. No Project Context or approval sidecar was invented.
Installed `check-risk-upgrade.sh REQUEST.md` returned `lite-eligible` (exit 0).
Capability fragments are not applicable in disabled-legacy mode. No delegation,
other models, or application implementation occurred. Task approval belongs to a human.

## 6. Promotion to full SDD

If scope or risk requires full SDD, stop lite execution and use
`sdd-bootstrap:sdd-bootstrap-interviewer` to create the required full artifacts
and obtain human approval for the revised scope. Re-run the installed risk check
at ship time as required by the plugin; intake success does not replace it.

## Open Questions

None blocking this proposal. Human review may revise serialization, duplicate-path,
or diagnostic conventions before task approval.
