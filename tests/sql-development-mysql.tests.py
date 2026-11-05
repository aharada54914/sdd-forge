#!/usr/bin/env python3
"""MySQL 8.4 + Flyway reference journey; only run-owned synthetic Docker DBs."""
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
FIXTURES = HERE.parent / 'fixtures/sql-development/mysql'


def exercise(f, directory):
    pins = json.loads((FIXTURES / 'images.json').read_text())
    image, flyway_image = pins['database']['image'], pins['flyway']['image']
    migrations = directory / 'migrations'
    shutil.copytree(FIXTURES / 'migrations', migrations)
    directory.chmod(0o755)
    password, app_password = f.secret(), f.secret()
    f.create_network()
    db = f.start_container(image, env={'MYSQL_ROOT_PASSWORD': password},
                           command=['--innodb-buffer-pool-size=128M', '--max-connections=50'])

    def sql(statement, *, database='upgrade', user='root', expected=0, label='SQL', timeout=30):
        return f.docker(['exec', '-i', '--env', 'MYSQL_PWD', db, 'mysql', '--batch', '--raw',
                         '--skip-column-names', '--connect-timeout=5', '--protocol=TCP',
                         '--host=127.0.0.1', '--user=' + user, '--database=' + database],
                        input_text=statement, extra_env={'MYSQL_PWD': app_password if user == 'app_user' else password},
                        expected=expected, label=label, timeout=timeout)

    ready = False
    for _ in range(90):
        result = sql('SELECT 1;', database='mysql', expected=None, label='database readiness')
        if result.returncode == 0 and result.stdout.strip() == '1':
            ready = True
            break
        time.sleep(1)
    f.check('MySQL accepts authenticated queries', ready)
    f.versions['database'] = sql('SELECT VERSION();', database='mysql').stdout.strip()
    f.check('pinned MySQL patch version', f.versions['database'] == pins['database']['tag'])
    sql(f"CREATE USER 'migrator'@'%' IDENTIFIED BY '{password}'; "
        f"CREATE USER 'app_user'@'%' IDENTIFIED BY '{app_password}';", database='mysql', label='create isolated roles')
    for database in ('upgrade', 'fresh', 'concurrent', 'faults', 'recovered'):
        sql(f"CREATE DATABASE {database} CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci; "
            f"GRANT ALL ON {database}.* TO 'migrator'@'%';", database='mysql', label='create owned database')

    def migration(operation='migrate', database='upgrade', location=migrations, options=()):
        # TLS is not exercised by this internal, run-owned synthetic fixture.
        url = f'jdbc:mysql://db:3306/{database}?allowPublicKeyRetrieval=true&useSSL=false&permitMysqlScheme=true'
        return f.flyway(flyway_image, url, 'migrator', password, location, operation, options)

    def migrated(database, options=()):
        result = migration(database=database, options=options)
        f.check(f'Flyway migrate {database} {options}', result.returncode == 0, result.stderr)
        data = json.loads(result.stdout)
        f.versions['flyway'] = data['flywayVersion']
        f.check('pinned Flyway version', data['flywayVersion'] == pins['flyway']['tag'])
        return data

    migrated('upgrade', ('-target=1',))
    before = sql('SELECT id, name, credit_cents FROM accounts ORDER BY id;').stdout.strip()
    f.check('v1 expected values', before == '1\tAlice\t100\n2\tBob\t0', before)
    migrated('upgrade')
    migrated('fresh')
    projection = "SELECT id,name,credit_cents,COALESCE(status,'NULL') FROM accounts ORDER BY id;"
    f.check('fresh and upgrade yield the same rows', sql(projection).stdout == sql(projection, database='fresh').stdout)
    f.check('upgraded expected values', sql(projection).stdout.strip() == '1\tAlice\t100\tNULL\n2\tBob\t0\tNULL')
    schema_contract = ("SELECT COLUMN_NAME,COLUMN_TYPE,IS_NULLABLE,COALESCE(COLUMN_DEFAULT,'') "
                       "FROM information_schema.columns WHERE TABLE_SCHEMA=DATABASE() "
                       "AND TABLE_NAME='accounts' ORDER BY ORDINAL_POSITION;")
    constraints = ("SELECT tc.CONSTRAINT_TYPE,tc.CONSTRAINT_NAME,COALESCE(cc.CHECK_CLAUSE,'') "
                   "FROM information_schema.TABLE_CONSTRAINTS tc LEFT JOIN information_schema.CHECK_CONSTRAINTS cc "
                   "ON tc.CONSTRAINT_SCHEMA=cc.CONSTRAINT_SCHEMA AND tc.CONSTRAINT_NAME=cc.CONSTRAINT_NAME "
                   "WHERE tc.TABLE_SCHEMA=DATABASE() AND tc.TABLE_NAME='accounts' "
                   "ORDER BY tc.CONSTRAINT_TYPE,tc.CONSTRAINT_NAME;")
    f.check('fresh and upgrade schemas agree', sql(schema_contract).stdout == sql(schema_contract, database='fresh').stdout)
    f.check('fresh and upgrade constraints agree', sql(constraints).stdout == sql(constraints, database='fresh').stdout)
    f.check('rerun has no migrations to execute', migrated('upgrade')['migrationsExecuted'] == 0)
    f.check('each migration version recorded once', sql(
        'SELECT COUNT(*),COUNT(DISTINCT version) FROM flyway_schema_history WHERE success=1;').stdout.strip() == '2\t2')

    sql("GRANT SELECT, INSERT, UPDATE ON upgrade.accounts TO 'app_user'@'%';", label='scope application permissions')
    sql("INSERT INTO accounts(id,name,credit_cents) VALUES(3,'Cara',50);", user='app_user', label='old app write')
    sql("INSERT INTO accounts(id,name,credit_cents,status) VALUES(4,'Dan',0,'empty');", user='app_user', label='new app write')
    f.check('old and new app read compatibility', sql(
        "SELECT id,COALESCE(status,'NULL') FROM accounts WHERE id>=3 ORDER BY id;", user='app_user').stdout.strip()
        == '3\tNULL\n4\tempty')
    bound = sql("PREPARE by_name FROM 'SELECT COUNT(*) FROM accounts WHERE name=?'; "
                "SET @needle='Alice'; EXECUTE by_name USING @needle; "
                "SET @needle='x'' OR 1=1 --'; EXECUTE by_name USING @needle; DEALLOCATE PREPARE by_name;",
                user='app_user', label='bound query values')
    f.check('parameter values cannot change SQL structure', bound.stdout.strip() == '1\n0', bound.stdout)
    denied = sql('DROP TABLE accounts;', user='app_user', expected=None, label='app DDL denial')
    f.check('application role cannot drop schema objects', denied.returncode != 0 and 'denied' in denied.stderr.lower())
    for label, statement, marker in (
        ('duplicate primary key', "INSERT INTO accounts VALUES(1,'Other',0,NULL);", '1062'),
        ('NULL name', 'INSERT INTO accounts VALUES(5,NULL,0,NULL);', '1048'),
        ('negative credit', "INSERT INTO accounts VALUES(5,'Other',-1,NULL);", '3819'),
    ):
        result = sql(statement, expected=None, label=label)
        f.check(label + ' rejected', result.returncode != 0 and marker in result.stderr)
    f.check('missing lookup returns empty result', sql('SELECT id FROM accounts WHERE id=999;').stdout.strip() == '')

    v2 = migrations / 'V2__expand_status.sql'
    original = v2.read_bytes()
    v2.write_bytes(original + b'\nSELECT 1;\n')
    bad = migration('validate')
    f.check('applied migration mutation rejected', bad.returncode != 0 and 'checksum' in (bad.stdout + bad.stderr).lower(),
            {'exit_code': bad.returncode, 'stdout': bad.stdout, 'stderr': bad.stderr})
    v2.write_bytes(original)
    f.check('restored source validates without repair', migration('validate').returncode == 0)
    schema = ("SELECT CONCAT(column_name,':',column_type) FROM information_schema.columns "
              "WHERE table_schema='upgrade' AND table_name='accounts' ORDER BY ordinal_position;")
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
        'SELECT COUNT(*),COUNT(DISTINCT version) FROM flyway_schema_history WHERE success=1;',
        database='concurrent').stdout.strip() == '2\t2')

    sql('CREATE TABLE backfill_checkpoint(last_id integer NOT NULL); INSERT INTO backfill_checkpoint VALUES(0);')
    sql("START TRANSACTION; UPDATE accounts SET status=CASE WHEN credit_cents>0 THEN 'active' ELSE 'empty' END "
        'WHERE id>0 AND id<=2; UPDATE backfill_checkpoint SET last_id=2; COMMIT;', label='commit first backfill batch')
    interrupted = sql("START TRANSACTION; UPDATE accounts SET status='active' WHERE id=3; "
                      'UPDATE backfill_checkpoint SET last_id=3; SELECT missing_column FROM backfill_checkpoint;',
                      expected=None, label='interrupt backfill transaction')
    f.check('interrupted DML rolls back with its checkpoint', interrupted.returncode != 0 and
            sql('SELECT last_id,(SELECT status IS NULL FROM accounts WHERE id=3) FROM backfill_checkpoint;').stdout.strip() == '2\t1')
    resume = ("START TRANSACTION; UPDATE accounts SET status=CASE WHEN credit_cents>0 THEN 'active' ELSE 'empty' END "
              'WHERE id>(SELECT last_id FROM backfill_checkpoint); '
              'UPDATE backfill_checkpoint SET last_id=(SELECT MAX(id) FROM accounts); COMMIT;')
    sql(resume, label='resume backfill from committed checkpoint')
    complete = sql(projection).stdout
    sql(resume, label='repeat completed backfill')
    f.check('backfill resumes without duplicated effects', sql(projection).stdout == complete and
            sql('SELECT COUNT(*) FROM accounts WHERE status IS NULL;').stdout.strip() == '0')

    # Preserve a pre-change backup, then observe the actual owner's failed
    # history. Recovery uses a separate restored DB, never automatic `repair`.
    migrated('faults')
    backup = f.docker(['exec', '--env', 'MYSQL_PWD', db, 'mysqldump',
                       '--host=127.0.0.1', '--user=root', '--single-transaction',
                       '--set-gtid-purged=OFF', '--no-tablespaces', '--skip-comments',
                       '--skip-dump-date', 'faults'], extra_env={'MYSQL_PWD': password},
                      label='backup before nontransactional migration').stdout
    f.check('pre-change backup contains schema and owner history',
            'CREATE TABLE' in backup and 'flyway_schema_history' in backup)
    failed_migrations = directory / 'failed-migrations'
    shutil.copytree(migrations, failed_migrations)
    v3 = failed_migrations / 'V3__partial_probe.sql'
    v3.write_text('CREATE TABLE partial_probe(id integer PRIMARY KEY); '
                  'INSERT INTO partial_probe VALUES(1); SELECT missing_column FROM partial_probe;\n')
    failed = migration(database='faults', location=failed_migrations)
    f.check('Flyway DDL failure leaves committed object and row', failed.returncode != 0 and
            sql('SELECT id FROM partial_probe;', database='faults').stdout.strip() == '1')
    f.check('Flyway records failed nontransactional version', sql(
        "SELECT version,success FROM flyway_schema_history WHERE version='3';", database='faults').stdout.strip() == '3\t0')
    retry = migration(database='faults', location=failed_migrations)
    f.check('owner refuses blindly retrying failed migration', retry.returncode != 0 and
            sql('SELECT COUNT(*) FROM partial_probe;', database='faults').stdout.strip() == '1')
    sql('ROLLBACK;', database='faults', label='observe rollback cannot undo committed DDL')
    f.check('rollback cannot erase implicitly committed partial migration', sql(
        'SELECT id FROM partial_probe;', database='faults').stdout.strip() == '1')
    sql(backup, database='recovered', label='restore pre-change backup to separate owned DB')
    f.check('restored backup preserves original business data', sql(projection, database='recovered').stdout
            == sql(projection, database='fresh').stdout)
    f.check('restored owner history predates failed version', sql(
        'SELECT COUNT(*),MAX(version) FROM flyway_schema_history;', database='recovered').stdout.strip() == '2\t2')
    v3.write_text('CREATE TABLE partial_probe(id integer PRIMARY KEY, verified boolean NOT NULL); '
                  'INSERT INTO partial_probe VALUES(1,TRUE);\n')
    recovered = migration(database='recovered', location=failed_migrations)
    f.check('reviewed corrected migration rolls forward on restored DB', recovered.returncode == 0 and
            sql('SELECT id,verified FROM partial_probe;', database='recovered').stdout.strip() == '1\t1')
    repeated = migration(database='recovered', location=failed_migrations)
    f.check('recovered migration is not applied twice', repeated.returncode == 0 and
            json.loads(repeated.stdout)['migrationsExecuted'] == 0)
    f.check('original failed state remains available for investigation', sql(
        "SELECT version,success FROM flyway_schema_history WHERE version='3';", database='faults').stdout.strip() == '3\t0')

    timed = sql('SET SESSION MAX_EXECUTION_TIME=100; SELECT id,SLEEP(2) FROM accounts;',
                expected=None, label='server statement deadline')
    f.check('server cancels timed-out statement', timed.returncode != 0 and
            any(marker in timed.stderr for marker in ('3024', '1317')))
    f.check('timed-out query no longer active', sql(
        "SELECT COUNT(*) FROM information_schema.processlist WHERE DB='upgrade' "
        "AND ID<>CONNECTION_ID() AND INFO LIKE 'SELECT id,SLEEP%';").stdout.strip() == '0')
    with ThreadPoolExecutor(max_workers=1) as pool:
        holder = pool.submit(sql, 'START TRANSACTION; UPDATE accounts SET credit_cents=credit_cents+1 WHERE id=1; '
                             'SELECT SLEEP(4); ROLLBACK;', label='hold row lock', timeout=15)
        acquired = False
        for _ in range(30):
            if sql("SELECT COUNT(*) FROM information_schema.processlist WHERE DB='upgrade' "
                   "AND ID<>CONNECTION_ID() AND INFO LIKE 'SELECT SLEEP(4)%';").stdout.strip() == '1':
                acquired = True
                break
            time.sleep(0.1)
        f.check('lock holder observed at server', acquired)
        blocked = sql('SET innodb_lock_wait_timeout=1; UPDATE accounts SET credit_cents=999 WHERE id=1;',
                      expected=None, label='bounded lock wait')
        f.check('contender obeys lock deadline', blocked.returncode != 0 and '1205' in blocked.stderr)
        holder.result(timeout=20)
    f.check('lock test leaves original data', sql('SELECT credit_cents FROM accounts WHERE id=1;').stdout.strip() == '100')
    f.check('all application rows survive fault cases', sql('SELECT COUNT(*) FROM accounts;').stdout.strip() == '4')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=Path('sql-mysql-proof.json'))
    args = parser.parse_args()
    f = DockerFixture('mysql', args.output, [HERE, *(p for p in FIXTURES.rglob('*') if p.is_file())])
    error = None
    try:
        with tempfile.TemporaryDirectory(prefix='sdd-sql-mysql-') as directory:
            exercise(f, Path(directory))
    except Exception as exc:
        error = exc
    return f.finish(error)


if __name__ == '__main__':
    raise SystemExit(main())
