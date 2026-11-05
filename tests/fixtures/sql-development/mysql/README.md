# MySQL reference case

Run from a clean checkout on a Linux x86_64 host with Docker:

```sh
python3 tests/sql-development-mysql.tests.py --output ../sql-mysql-proof.json
```

The test pulls the immutable images in `images.json`, creates an internal Docker
network and new databases with synthetic data, invokes actual Flyway and mysql,
and removes only its labelled containers/network. It accepts no existing DSN.
The generated proof survives cleanup; missing tools, mandatory failures and
cleanup failures all exit nonzero. Inspect the proof's source/input hashes,
versions, checks and cleanup result before accepting it.

The account/status migrations are tested on fresh and upgraded databases.
Additional cases cover old/new clients, bound parameters, application privileges,
constraints, migration checksums, actual-schema drift, concurrent migration,
transactional backfill recovery and server-side statement/lock deadlines.
A separate `faults` database deliberately fails a real Flyway DDL migration.
The object and inserted row survive, Flyway records a failed version, and a
blind retry is refused. A pre-change mysqldump is restored to a separate owned
`recovered` database and the reviewed, corrected migration is applied there.
The original failed database/history remain intact for investigation; neither
`repair` nor `clean` is used. The synthetic scenario has no legitimate writes
after its backup; it does not demonstrate zero data loss in a live system.

The internal JDBC fixture disables TLS and permits local public-key exchange;
those settings are not deployment recommendations. This does not test cloud
products, production identities, TLS or application performance, and does not
replace the agent's actual SQL workflow acceptance. Image and Flyway licensing
remain governed by their upstream distributions.
