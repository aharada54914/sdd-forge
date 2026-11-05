# Tasks: orders-note

## T-001 Add optional order note
Approval: Approved
Status: Blocked

Risk: low
Risk Rationale: Additive schema change restricted to an owned disposable database; shared target is rejected.
Required Workflow: test-after
Requirements: REQ-001, REQ-002, REQ-003

### Scope
- Add nullable note and a bound integer id query in db/migrations and db/queries.
- Evaluate new installation, upgrades and SQL contract on a newly created isolated PostgreSQL 18.0 database using Flyway 13.12.1.

### Done When
- Real database evidence proves the requirements, correct isolated target and retained values.
- No unsupported test is marked passed; no secrets are printed.

### Blockers
- No verified isolated database resource or credentials are available yet.
- Required PostgreSQL 18.0/Flyway 13.12.1 execution is unavailable; psql and flyway are not on PATH. No connection attempted. See .run-temp/ship-20261105-286c0673/outcome.md.
