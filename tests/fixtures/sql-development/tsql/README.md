# T-SQL reference acceptance

Run from the repository root on a Linux amd64 host with Docker and the pinned
.NET SDK / SqlPackage from `lock.json`, plus Linux `nsenter`, `setpriv` and
passwordless `sudo` as provided by the GitHub Ubuntu runner:

```sh
python3 tests/sql-development-tsql.tests.py --output /tmp/tsql-proof.json --sqlpackage /path/to/sqlpackage
```

This builds the actual Microsoft.Build.Sql projects and uses real SqlPackage
and the SQL Server 2025 Developer engine. It creates a new labelled container
with a random password on an internal Docker network, without publishing a host
port. No existing database or connection string is accepted. The test owns and removes only its container
and network. Accepting the Developer image EULA is limited to these nonproduction
fixtures; it is not a license for production use.

The host builds the SQL projects. For database operations, the test verifies the
owned container ID, label, running PID and internal network, then uses `nsenter`
to enter only that network namespace. `setpriv` immediately restores the host
user/group and disables privilege gain before the already installed SqlPackage
runs. It connects to `127.0.0.1:1433` inside the container network; Docker internal
networks do not expose published ports to the host. A real namespace/UID probe
must pass before deployment. This is Linux CI validation, not a Windows-native
client test. Missing namespace tools or sudo access fail the test; they do not
select a shared network or another database.

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
