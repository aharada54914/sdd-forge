# Infrastructure Specification: SQLite Task Board

## Deployment Topology
Local browser -> 127.0.0.1:8000 Python server -> local SQLite file. Logs to terminal; no remote services, containers, cloud resources or external publication (REQ-004/006, AC-004/006/007).

## CI/CD Sequence
Local checks: py_compile, unittest discovery, real browser verification and independent quality gate. No hosted CI configured because host is local and publishing is excluded.

## Environments
Local only: python3 app.py --db data/tasks.sqlite3 --port 8000. Test environment uses a temporary directory and free port with the same implementation. No staging or remote production environment.

## Infrastructure as Code
N/A: no provisioned infrastructure. README owns reproducible launch/stop/check commands and selected database path.

## Scaling Strategy
One local process, one user, <=1000 tasks. ThreadingHTTPServer with per-request SQLite connections, 5-second busy timeout and bounded body size. Horizontal scaling and autoscaling are outside scope.

## Service Level Objectives
AC-007: each of 20 list requests for 100 tasks <=1 second on recorded verification host. No uptime promise for a manually started local process. Errors must preserve committed state and report failure.

## Data Residency and Retention
Tasks stay in the selected local file until deletion. No remote backups. Operator can stop process and copy DB for offline backup; restore only while stopped. Document SQLite live-row deletion is not secure erasure. TEST-004 proves restart durability (REQ-004, AC-004).

## Observability
Log timestamp, HTTP method/path/status and startup database location; omit titles, bodies and secrets. No traces, dashboards or alerts for a single-user local process. Operator diagnoses errors using stderr and HTTP feedback; save test logs under reports/implementation/sqlite-task-board/.

## Cost Estimate
No paid services or network egress. Existing machine CPU/disk only; no recurring service charge. Disk consumption grows with task count; <=1000-task assumption.

## Rollback
Operator stops process, restores previous source and a compatible offline backup, then restarts with the same path and checks list. Refuse future schema versions instead of silently rewriting. Do not delete a database to recover startup. No destructive rollback during this evaluation.

## Open Questions
None; local operator owns file path and backups.
