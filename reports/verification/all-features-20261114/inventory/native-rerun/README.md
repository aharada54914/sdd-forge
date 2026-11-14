# Native rerun — 2026-11-14

Requested MySQL, SQL Server and Windows recovery executions all succeeded.

Tested PR head: `3f879030039a78f1bed7b118dd91b19e33e8b5bb`.
GitHub tested merge: `b8b92233dc979b0f6475c7fe2e2b55393833bec3`.
Run: https://github.com/aharada54914/sdd-forge/actions/runs/43569832964

| Execution | Result | Actual job |
|---|---|---|
| MySQL 8.4.13 / Flyway 13.12.1 | 68 checks PASS, owned cleanup PASS | 132372549649 |
| SQL Server 17.0.5035.5 / .NET 10.0.403 / SqlPackage 170.5.96.0 | 48 checks PASS, owned cleanup PASS | 132372549624 |
| Windows 10.0.26100 / PowerShell 7.6.9 recovery | 731 admission + 61 transition + 163 consumption = 955 PASS, zero failures | 132372549580 |

MySQL also passed 68 checks in real local Docker on the same head, with no
remaining owned containers or networks; see ../mysql-verification/.
SQL Server proof and MySQL proof were downloaded from their actual GitHub
artifacts. Sanitized summaries retain source identity, versions, checks,
cleanup and artifact hashes. Windows evidence retains runtime and final counts.

## Repairs

- Docker cleanup falsely failed because newer Docker printed `no such object`
  in lowercase. Cleanup now requires a successful, exact-filter listing of
  all containers (including stopped containers). Ownership checks remain;
  survivors and daemon failures are still errors. Five contract tests pass.
- Windows consumption fixtures passed a noncanonical temporary path to the
  real CLI. Resolve the generated directory before invocation; production
  canonical-root validation remains intact. Local PowerShell consumption
  regression passed before the actual Windows full-job success.
- Tracked in #758 (SQL cleanup) and #751 (recovery fixtures).

## Scope limits

The POSIX FIFO case is not applicable on Windows and was explicitly skipped.
The optional historical SDD_RECOVERY_ROLLBACK_REF comparison was not requested
or run. These executions do not establish that every unrelated PR CI job,
production database, cloud deployment or browser integration has passed.
