# PR 404 registration regression and dependency follow-up

Base: 759663a50273f2c9e43e678bd891771d71c1cf9d.

The PowerShell structural suite failed its final registration assertion:
43 passed, 1 failed. The aggregate runner already registers the suite with
single quotes and a trailing comma; the assertion required double quotes
and no comma. The scoped fix recognizes either literal quote style, with
an optional trailing comma, while requiring exactly one complete matching
line. Five fixtures exercise both valid forms and reject a comment, a
different path, and a case change. Re-run: 49 passed, 0 failed. Bash twin:
44 passed, 0 failed (unchanged). Both suites still emit four dependency
SKIPs; these are not successful execution of the skipped acceptance tests.

Scoped self-review: no production code or runner inventory changes. The
matching quote backreference, line anchors, case-sensitive comparison and
exactly-one count retain the registration check. This is not independent
approval or an overall A7 completion verdict.

Separate unresolved finding: A4 issue 192 was closed by merged PR 301
(02166dbabb0979081337b1d408b26019be3668d6). The allowlist evaluator first
requires a currently present epic-named branch. No such A4 branch remains.
Branch deletion must not make a merged dependency appear unmerged. This
requires a separate regression and Bash/PowerShell parity fix before A7
can be considered complete; do not count the current A4 SKIP as verified.
