# PostgreSQL reference case

Run from a clean checkout on a Linux x86_64 host with Docker:

```sh
python3 tests/sql-development-postgres.tests.py --output ../sql-postgres-proof.json
```

The test pulls the immutable images in `images.json`, creates an internal Docker
network and new databases with synthetic data, invokes actual Flyway and psql,
and removes only its labelled containers/network. No existing DSN or container
can be supplied. No PostgreSQL server or cloud account must be preconfigured.
The generated proof survives database cleanup; any mandatory failure or cleanup
failure exits nonzero. Inspect `result`, source/input hashes, engine/tool versions,
individual checks, commands and `cleanup`; never count a partial proof as success.

The two migration files define a small account model and a backward-compatible
nullable status column. New and upgraded databases must agree. Separate cases
exercise old/new clients, bound parameters, application privileges, constraints,
immutable history, actual-schema drift, concurrent migration, transactional
failure, resumable backfill, invalid concurrent indexes and bounded lock waits.

This is an engine reference acceptance test, not a substitute for an agent's
actual `sql-develop → specification → approved ship → independent gate` journey.
It does not test Azure Database for PostgreSQL, RDS, Aurora, TLS, production
identities or application latency. It claims no performance improvement. Image
and Flyway licensing remain governed by their upstream distributions.
