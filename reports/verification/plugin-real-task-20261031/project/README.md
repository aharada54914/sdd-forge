# JUnit summary CLI

Small local developer tool to summarize JUnit XML test reports using Python standard library. No network, service deployment, dependency installation, or git remote.

Run with Python 3:

```sh
python3 junit_summary.py REPORT.xml [REPORT.xml ...]
```

One compact JSON line contains `tests`, `passed`, `failures`, `errors`, and
`skipped`, in that order. Actual testcase elements are counted recursively;
suite totals are ignored. Both testsuite and testsuites roots, nested suites,
and namespace-qualified tags work. Direct outcome children use precedence
error > failure > skipped > passed. Repeated paths count as repeated reports.
Empty suites produce zero counts. Input files are read without modification.

Exit status is 0 for passing/skipped reports, 1 if any testcase fails or errors,
and 2 for missing arguments, unreadable files, invalid XML (including unknown
encodings), or unsupported roots. Invalid input produces a stderr diagnostic
and no JSON, even when earlier reports were valid. `--help` shows usage.

Run the standard-library CLI tests:

```sh
python3 -m unittest discover -s tests -v
```
