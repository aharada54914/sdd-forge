# Infrastructure: verification-measurement

Use the installed Python 3 standard library and the existing Bash/PowerShell
callers. No service, daemon, database, cache, network dependency or package is
added. Measurement and benchmark artifacts are local files under an explicitly
chosen directory; the benchmark runs on demand in a disposable worktree/export
and is never a timed CI job. Clock domains use the Linux boot identifier when
readable; other hosts follow OQ-1.
