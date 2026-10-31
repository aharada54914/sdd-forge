# Requirements (lite): JUnit summary CLI

- Source: repository REQUEST.md (complete local requirement body).
- Purpose: summarize local JUnit reports reliably using Python's standard library.
- Profile: lite; local low-stakes developer utility. Specification proposal only.

## User stories / requirements

- REQ-001: A developer runs `python3 junit_summary.py REPORT.xml [REPORT.xml ...]` to aggregate one or more files into one deterministic JSON object. Keys, in order: `tests`, `passed`, `failures`, `errors`, `skipped`; values are nonnegative integer counts.
- REQ-002: Accept `testsuite` and `testsuites` roots, including namespace-qualified tags and nested suites. Recursively count actual `testcase` elements once each. Ignore all aggregate suite attributes, even stale or contradictory ones. An empty valid suite produces five zero counts.
- REQ-003: Classify each testcase using its direct outcome children, with precedence `error > failure > skipped > passed`. Repeated or conflicting outcome children never count a testcase more than once. Namespace-qualified standard JUnit outcome tags work too.
- REQ-004: Exit 0 when every case passes or skips (including empty suites); exit 1 when any failure or error is counted.
- REQ-005: Exit 2 on no input, unreadable files, malformed XML, or unsupported root. Emit a concise stderr diagnostic without a traceback and no partial stdout, including when a later file is invalid after earlier valid input. `argparse` help is allowed.
- REQ-006: Preserve every input file's bytes. Use only Python standard-library dependencies and local files; no service or deployment.
- REQ-007: Provide a short README explaining invocation, JSON fields, outcome precedence, exits, and the unittest command. Provide meaningful standard-library unittest tests invoking the actual CLI.
- REQ-008: During the authorized implementation stage, run a real behavioral test before the application exists, retain its raw failing output, then implement and retain raw passing output. No invented test evidence or approvals. Independent final review occurs in another context.

## Out of scope

Application implementation in this stage; task approval; production release;
remote CI, commits, remotes, dependencies, services, XML rewriting, HTML/UI,
traceability/ADR/evidence-bundle artifacts, and other-model review or delegation.

## Open Questions

None blocking the proposed task. The exact output formatting and diagnostics
below are proposed conventions for human scope review, not previously observed behavior.
