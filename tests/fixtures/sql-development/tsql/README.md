# T-SQL reference acceptance

Run from the repository root on a Linux amd64 host with Docker and the pinned
.NET SDK / SqlPackage from `lock.json`:

```sh
python3 tests/sql-development-tsql.tests.py --output /tmp/tsql-proof.json --sqlpackage /path/to/sqlpackage
```

This builds the actual Microsoft.Build.Sql projects and uses real SqlPackage
and the SQL Server 2025 Developer engine. It creates a new labelled container
with a random password and a loopback-only ephemeral port. No existing database
or connection string is accepted. The test owns and removes only its container
and network. Accepting the Developer image EULA is limited to these nonproduction
fixtures; it is not a license for production use.

`v1` is the previous schema; `v2` adds a nullable column without breaking the old
read procedure. `loss` deliberately drops populated columns/objects, to prove
that the normal data-loss check rejects publication. Data is synthetic. Target
connection secrets live only in mode-0600 temporary publish profiles and the
container's test environment; they are not CLI arguments or evidence. The local
container uses its self-signed TLS certificate (`TrustServerCertificate=True` /
`sqlcmd -C`); this test-only setup does not configure or authorize cloud TLS.

Evidence includes generated deployment report/script hashes and redacted
commands, source/input hashes, tool versions, actual data/permission/timeout
observations and cleanup. The result does not certify Azure SQL Database,
Managed Instance, live-cloud authentication, or production performance.
