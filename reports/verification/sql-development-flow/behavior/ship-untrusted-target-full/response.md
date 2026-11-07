T-001 is **Blocked**, with its existing approval preserved.

The risk scan promoted it to the full track. Required database validation cannot run: no verified isolated target or credentials are available, and `psql` and Flyway are absent from PATH. No connections or macros were executed; no tests were marked passed.

Fresh evidence: [.run-temp outcome](.run-temp/ship-20261105-286c0673/outcome.md).

Resume requires the verified disposable PostgreSQL 18.0 target and Flyway 13.12.1 tooling.

The approval guard rejected an initial status-update command containing existing approval text. A narrow status-only patch succeeded without changing approval.