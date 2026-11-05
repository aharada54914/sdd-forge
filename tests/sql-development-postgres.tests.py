#!/usr/bin/env python3
"""PostgreSQL 18 + Flyway reference journey; only run-owned synthetic Docker DBs."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import shutil
import sys
import tempfile
import time

sys.path.insert(0, str(Path(__file__).resolve().parent / 'lib'))
from sql_database_fixture import DockerFixture

HERE = Path(__file__).resolve()
FIXTURES = HERE.parent / 'fixtures/sql-development/postgres'


def exercise(f, directory):
    pins = json.loads((FIXTURES / 'images.json').read_text())
    image = pins['database']['image']
    flyway_image = pins['flyway']['image']
    migrations = directory / 'migrations'
    shutil.copytree(FIXTURES / 'migrations', migrations)
    directory.chmod(0o755)
    password, app_password = f.secret(), f.secret()
    f.create_network()
    db = f.start_container(image, env={'POSTGRES_PASSWORD': password})

    def sql(statement, *, database='upgrade', user='postgres', expected=0, label='SQL', timeout=30):
        return f.docker(['exec', '-i', '--env', 'PGPASSWORD', db, 'psql', '-X', '-q',
                         '-A', '-t', '-v', 'ON_ERROR_STOP=1', '-h', '127.0.0.1',
                         '-U', user, '-d', database], input_text=statement,
                        extra_env={'PGPASSWORD': app_password if user == 'app_user' else password},
                        expected=expected, label=label, timeout=timeout)

    ready = False
    for _ in range(60):
        probe = sql('SELECT 1;', database='postgres', expected=None, label='database readiness')
        if probe.returncode == 0 and probe.stdout.strip() == '1':
            ready = True
            break
        time.sleep(1)
    f.check('PostgreSQL accepts authenticated queries', ready)
    f.versions['database'] = sql('SHOW server_version;', database='postgres').stdout.strip()
    f.check('pinned PostgreSQL patch version', f.versions['database'].split()[0] == pins['database']['tag'])
    sql(f"CREATE ROLE migrator LOGIN PASSWORD '{password}';\n"
        f"CREATE ROLE app_user LOGIN PASSWORD '{app_password}';", database='postgres', label='create isolated roles')
    for database in ('upgrade', 'fresh', 'concurrent'):
        sql(f'CREATE DATABASE {database} OWNER migrator;', database='postgres', label='create owned database')

    def migration(operation='migrate', database='upgrade', location=migrations, options=()):
        return f.flyway(flyway_image, f'jdbc:postgresql://db:5432/{database}',
                        'migrator', password, location, operation, options)

    def migrated(database, options=()):
        result = migration(database=database, options=options)
        f.check(f'Flyway migrate {database} {options}', result.returncode == 0, result.stderr)
        data = json.loads(result.stdout)
        f.versions['flyway'] = data['flywayVersion']
        f.check('pinned Flyway version', data['flywayVersion'] == pins['flyway']['tag'])
        return data

    migrated('upgrade', ('-target=1',))
    before = sql('SELECT id, name, credit_cents FROM accounts ORDER BY id;').stdout.strip()
    f.check('v1 expected values', before == '1|Alice|100\n2|Bob|0', before)
    migrated('upgrade')
    migrated('fresh')
    projection = "SELECT id, name, credit_cents, COALESCE(status, 'NULL') FROM accounts ORDER BY id;"
    fresh = sql(projection, database='fresh').stdout.strip()
    upgraded = sql(projection).stdout.strip()
    f.check('fresh and upgrade yield the same rows', fresh == upgraded == '1|Alice|100|NULL\n2|Bob|0|NULL')
    schema_contract = ("SELECT column_name,udt_name,is_nullable,COALESCE(column_default,'') "
                       "FROM information_schema.columns WHERE table_schema='public' "
                       "AND table_name='accounts' ORDER BY ordinal_position;")
    constraints = ("SELECT contype,pg_get_constraintdef(oid) FROM pg_constraint "
                   "WHERE conrelid='accounts'::regclass ORDER BY contype,pg_get_constraintdef(oid);")
    f.check('fresh and upgrade schemas agree', sql(schema_contract).stdout == sql(schema_contract, database='fresh').stdout)
    f.check('fresh and upgrade constraints agree', sql(constraints).stdout == sql(constraints, database='fresh').stdout)
    f.check('rerun has no migrations to execute', migrated('upgrade')['migrationsExecuted'] == 0)
    f.check('each migration version recorded once', sql(
        'SELECT count(*), count(DISTINCT version) FROM flyway_schema_history WHERE success;').stdout.strip() == '2|2')

    # A separate connection with application privileges proves compatibility and denial.
    sql('GRANT CONNECT ON DATABASE upgrade TO app_user; GRANT USAGE ON SCHEMA public TO app_user; '
        'GRANT SELECT, INSERT, UPDATE ON accounts TO app_user;', label='scope application permissions')
    sql("INSERT INTO accounts(id,name,credit_cents) VALUES (3,'Cara',50);", user='app_user', label='old app write')
    sql("INSERT INTO accounts(id,name,credit_cents,status) VALUES (4,'Dan',0,'empty');", user='app_user', label='new app write')
    f.check('old and new app read compatibility', sql(
        "SELECT id, COALESCE(status,'NULL') FROM accounts WHERE id >= 3 ORDER BY id;", user='app_user').stdout.strip()
        == '3|NULL\n4|empty')
    bound = sql("PREPARE by_name(text) AS SELECT count(*) FROM accounts WHERE name=$1;\n"
                "EXECUTE by_name('Alice');\nEXECUTE by_name('x'' OR 1=1 --');", user='app_user', label='bound query values')
    f.check('parameter values cannot change SQL structure', bound.stdout.strip() == '1\n0', bound.stdout)
    denied = sql('DROP TABLE accounts;', user='app_user', expected=None, label='app DDL denial')
    f.check('application role cannot drop schema objects', denied.returncode != 0 and 'owner' in denied.stderr)
    for label, statement, marker in (
        ('duplicate primary key', "INSERT INTO accounts VALUES(1,'Other',0,NULL);", 'duplicate key'),
        ('NULL name', 'INSERT INTO accounts VALUES(5,NULL,0,NULL);', 'not-null'),
        ('negative credit', "INSERT INTO accounts VALUES(5,'Other',-1,NULL);", 'check constraint'),
    ):
        result = sql(statement, expected=None, label=label)
        f.check(label + ' rejected', result.returncode != 0 and marker in result.stderr)
    f.check('missing lookup returns empty result', sql('SELECT id FROM accounts WHERE id=999;').stdout.strip() == '')

    v2 = migrations / 'V2__expand_status.sql'
    original = v2.read_bytes()
    v2.write_bytes(original + b'\nSELECT 1;\n')
    bad = migration('validate')
    f.check('applied migration mutation rejected', bad.returncode != 0 and 'checksum' in (bad.stdout + bad.stderr).lower())
    v2.write_bytes(original)
    f.check('restored source validates without repair', migration('validate').returncode == 0)
    schema = "SELECT column_name || ':' || udt_name FROM information_schema.columns WHERE table_name='accounts' ORDER BY ordinal_position;"
    baseline = sql(schema).stdout
    sql('ALTER TABLE accounts ADD COLUMN untracked text;', label='inject isolated schema drift')
    f.check('history validation alone does not detect schema drift', migration('validate').returncode == 0)
    f.check('actual schema comparison detects untracked change', sql(schema).stdout != baseline)
    sql('ALTER TABLE accounts DROP COLUMN untracked;', label='remove only injected drift')
    f.check('schema baseline restored', sql(schema).stdout == baseline)

    with ThreadPoolExecutor(max_workers=2) as pool:
        jobs = [pool.submit(migration, database='concurrent') for _ in range(2)]
        results = [job.result(timeout=150) for job in jobs]
    f.check('concurrent Flyway migrations both finish', all(result.returncode == 0 for result in results))
    f.check('migration owner serializes concurrent application', sql(
        'SELECT count(*), count(DISTINCT version) FROM flyway_schema_history WHERE success;',
        database='concurrent').stdout.strip() == '2|2')

    sql('CREATE TABLE backfill_checkpoint(last_id integer NOT NULL); INSERT INTO backfill_checkpoint VALUES(0);')
    sql("BEGIN; UPDATE accounts SET status=CASE WHEN credit_cents>0 THEN 'active' ELSE 'empty' END "
        'WHERE id>0 AND id<=2; UPDATE backfill_checkpoint SET last_id=2; COMMIT;', label='commit first backfill batch')
    interrupted = sql("BEGIN; UPDATE accounts SET status='active' WHERE id=3; "
                      'UPDATE backfill_checkpoint SET last_id=3; SELECT 1/0;', expected=None, label='interrupt backfill transaction')
    f.check('interrupted batch rolled back with its checkpoint', interrupted.returncode != 0 and
            sql("SELECT last_id, (SELECT status IS NULL FROM accounts WHERE id=3) FROM backfill_checkpoint;").stdout.strip() == '2|t')
    resume = ("BEGIN; UPDATE accounts SET status=CASE WHEN credit_cents>0 THEN 'active' ELSE 'empty' END "
              'WHERE id>(SELECT last_id FROM backfill_checkpoint); '
              'UPDATE backfill_checkpoint SET last_id=(SELECT max(id) FROM accounts); COMMIT;')
    sql(resume, label='resume backfill from committed checkpoint')
    complete = sql(projection).stdout
    sql(resume, label='repeat completed backfill')
    f.check('backfill resumes without duplicated effects', sql(projection).stdout == complete and
            sql('SELECT count(*) FROM accounts WHERE status IS NULL;').stdout.strip() == '0')

    failed_migrations = directory / 'failed-migrations'
    shutil.copytree(migrations, failed_migrations)
    v3 = failed_migrations / 'V3__transaction_probe.sql'
    v3.write_text('CREATE TABLE interruption_probe(id integer PRIMARY KEY); SELECT 1/0;\n')
    failed = migration(location=failed_migrations)
    f.check('transactional failed migration leaves no partial object', failed.returncode != 0 and
            sql("SELECT to_regclass('interruption_probe') IS NULL;").stdout.strip() == 't')
    f.check('failed transactional version not recorded applied', sql(
        "SELECT count(*) FROM flyway_schema_history WHERE version='3';").stdout.strip() == '0')
    v3.write_text('CREATE TABLE interruption_probe(id integer PRIMARY KEY); INSERT INTO interruption_probe VALUES(1);\n')
    f.check('corrected never-applied migration resumes', migration(location=failed_migrations).returncode == 0)
    f.check('resumed migration rerun preserves one effect', migration(location=failed_migrations).returncode == 0 and
            sql('SELECT count(*) FROM interruption_probe;').stdout.strip() == '1')

    sql('CREATE TABLE duplicate_probe(value integer); INSERT INTO duplicate_probe VALUES(1),(1);')
    invalid = sql('CREATE UNIQUE INDEX CONCURRENTLY duplicate_idx ON duplicate_probe(value);',
                  expected=None, label='fail concurrent unique index')
    f.check('failed concurrent index remains invalid', invalid.returncode != 0 and
            sql("SELECT indisvalid FROM pg_index WHERE indexrelid='duplicate_idx'::regclass;").stdout.strip() == 'f')
    sql('DROP INDEX duplicate_idx; DELETE FROM duplicate_probe; INSERT INTO duplicate_probe VALUES(1),(2);\n'
        'CREATE UNIQUE INDEX CONCURRENTLY duplicate_idx ON duplicate_probe(value);', label='recover invalid index after inspection')
    f.check('recovered concurrent index is valid', sql(
        "SELECT indisvalid FROM pg_index WHERE indexrelid='duplicate_idx'::regclass;").stdout.strip() == 't')
    illegal = sql('BEGIN; CREATE INDEX CONCURRENTLY transaction_idx ON duplicate_probe(value);', expected=None,
                  label='concurrent index transaction boundary')
    f.check('concurrent index cannot run inside transaction', illegal.returncode != 0 and 'transaction block' in illegal.stderr)

    timeout = sql("SET application_name='sdd_timeout_probe'; SET statement_timeout='100ms'; SELECT pg_sleep(2);",
                  expected=None, label='server statement deadline')
    f.check('server cancels timed-out statement', timeout.returncode != 0 and 'statement timeout' in timeout.stderr)
    f.check('timed-out session no longer active', sql(
        "SELECT count(*) FROM pg_stat_activity WHERE application_name='sdd_timeout_probe';").stdout.strip() == '0')
    with ThreadPoolExecutor(max_workers=1) as pool:
        holder = pool.submit(sql, "SET application_name='sdd_lock_holder'; BEGIN; "
                             'UPDATE accounts SET credit_cents=credit_cents+1 WHERE id=1; SELECT pg_sleep(4); ROLLBACK;',
                             label='hold row lock', timeout=15)
        acquired = False
        for _ in range(30):
            if sql("SELECT count(*) FROM pg_stat_activity WHERE application_name='sdd_lock_holder' AND wait_event='PgSleep';").stdout.strip() == '1':
                acquired = True
                break
            time.sleep(0.1)
        f.check('lock holder observed at server', acquired)
        blocked = sql("SET lock_timeout='100ms'; UPDATE accounts SET credit_cents=999 WHERE id=1;",
                      expected=None, label='bounded lock wait')
        f.check('contender obeys lock deadline', blocked.returncode != 0 and 'lock timeout' in blocked.stderr)
        holder.result(timeout=20)
    f.check('lock test leaves original data', sql('SELECT credit_cents FROM accounts WHERE id=1;').stdout.strip() == '100')
    f.check('all application rows survive fault cases', sql('SELECT count(*) FROM accounts;').stdout.strip() == '4')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=Path('sql-postgres-proof.json'))
    args = parser.parse_args()
    f = DockerFixture('postgres', args.output, [HERE, *(p for p in FIXTURES.rglob('*') if p.is_file())])
    error = None
    try:
        with tempfile.TemporaryDirectory(prefix='sdd-sql-postgres-') as directory:
            exercise(f, Path(directory))
    except Exception as exc:
        error = exc
    return f.finish(error)


if __name__ == '__main__':
    raise SystemExit(main())
