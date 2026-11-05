#!/usr/bin/env python3
"""Real, isolated SQL Server acceptance. No external target/DSN is accepted.

Build the checked-in Microsoft.Build.Sql projects; run real SqlPackage and
sqlcmd. The fixture is not a migration runner or an Azure SQL acceptance test.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import sys
import tempfile
import time
import xml.etree.ElementTree as ET

sys.path.insert(0, str(Path(__file__).resolve().parent / 'lib'))
from sql_database_fixture import DockerFixture

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / 'tests/fixtures/sql-development/tsql'
DATABASES = ('reference_fresh', 'reference_upgrade')


def read_generated_text(path):
    data = path.read_bytes()
    return data.decode('utf-16' if data[:2] in (b'\xff\xfe', b'\xfe\xff') else 'utf-8-sig')


def publish_profile(path, port, database, password):
    """A generated target only: never take a user's connection string."""
    if database not in DATABASES or not 1 <= port <= 65535:
        raise ValueError('Only this fixture\'s generated loopback targets are allowed')
    root = ET.Element('Project', ToolsVersion='4.0',
                      xmlns='http://schemas.microsoft.com/developer/msbuild/2003')
    properties = ET.SubElement(root, 'PropertyGroup')
    values = {
        'TargetDatabaseName': database,
        'TargetConnectionString': (
            f'Server=tcp:127.0.0.1,{port};Initial Catalog={database};'
            f'User ID=sa;Password={password};Encrypt=True;TrustServerCertificate=True;'
            'Connection Timeout=10;Application Name=SDDSqlReference;'),
        'BlockOnPossibleDataLoss': 'True',
        'DropObjectsNotInSource': 'True',
        'BlockWhenDriftDetected': 'True',
        'RegisterDataTierApplication': 'True',
        'CommandTimeout': '30',
        'DatabaseLockTimeout': '5',
        'ScriptDeployStateChecks': 'True',
    }
    for key, value in values.items():
        ET.SubElement(properties, key).text = value
    fd = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    with os.fdopen(fd, 'wb') as stream:
        ET.ElementTree(root).write(stream, encoding='utf-8', xml_declaration=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--sqlpackage', default='sqlpackage')
    args = parser.parse_args()
    output = args.output.resolve()
    artifacts = output.parent / 'tsql-artifacts'
    lock = json.loads((FIXTURE / 'lock.json').read_text())
    inputs = [Path(__file__).resolve(), *sorted(FIXTURE.rglob('*'))]
    fixture = DockerFixture('tsql', output, [p for p in inputs if p.is_file()])
    error = None
    try:
        artifacts.mkdir(parents=True, exist_ok=False)
        package = shutil.which(args.sqlpackage)
        if package is None and Path(args.sqlpackage).is_file():
            package = str(Path(args.sqlpackage).resolve())
        if package is None:
            raise RuntimeError('Pinned SqlPackage is required; see fixture lock.json')
        package = str(Path(package).resolve())
        sdk = fixture.run(['dotnet', '--version'], label='dotnet-version').stdout.strip()
        fixture.check('pinned-dotnet-sdk', sdk == lock['dotnet_sdk'], sdk)
        fixture.versions['dotnet'] = sdk
        version = fixture.run([package, '/Version'], label='sqlpackage-version').stdout.strip()
        fixture.check('pinned-sqlpackage', lock['sqlpackage'] in version, version)
        fixture.versions['sqlpackage'] = version
        fixture.versions['microsoft_build_sql'] = lock['microsoft_build_sql']
        fixture.create_network()
        password = fixture.secret()
        container = fixture.start_container(
            lock['sql_server_image'], env={'ACCEPT_EULA': 'Y', 'MSSQL_PID': 'Developer',
                                          'MSSQL_SA_PASSWORD': password},
            publish=['127.0.0.1::1433'], memory='3g')

        def sql(statement, database='reference_upgrade', *, expected=0, query_timeout=15):
            if database not in (*DATABASES, 'master'):
                raise ValueError('Unexpected target database')
            return fixture.docker(
                ['exec', '-i', '-e', 'SQLCMDPASSWORD', container, lock['sqlcmd'],
                 '-S', 'localhost', '-U', 'sa', '-C', '-b', '-r', '1', '-h', '-1', '-W',
                 '-l', '5', '-t', str(query_timeout), '-d', database],
                label=f'sqlcmd-{database}', input_text='SET NOCOUNT ON;\n' + statement + '\n',
                extra_env={'SQLCMDPASSWORD': password}, expected=expected,
                timeout=query_timeout + 20)

        # Doctor the actual generated instance, not just its listening socket.
        ready = False
        deadline = time.monotonic() + 120
        while time.monotonic() < deadline:
            result = sql("SELECT 'SDD_SQL_READY'", 'master', expected=None, query_timeout=5)
            if result.returncode == 0 and 'SDD_SQL_READY' in result.stdout:
                ready = True
                break
            time.sleep(2)
        fixture.check('server-ready', ready)
        observed = sql("SELECT CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(60)) + '|' + "
                       "CAST(SERVERPROPERTY('Edition') AS nvarchar(100));", 'master').stdout.strip()
        fixture.check('sql-server-2025-developer',
                      bool(re.match(r'17\.', observed)) and 'Developer' in observed, observed)
        fixture.versions['sql_server'] = observed
        client = fixture.docker(['exec', container, lock['sqlcmd'], '-?'], label='sqlcmd-version')
        fixture.versions['sqlcmd'] = '\n'.join(client.stdout.splitlines()[:3])
        bindings = json.loads(fixture.docker(
            ['inspect', '--format', '{{json .NetworkSettings.Ports}}', container],
            label='inspect-loopback-binding').stdout)
        binding = bindings['1433/tcp']
        fixture.check('loopback-only-port', len(binding) == 1 and binding[0]['HostIp'] == '127.0.0.1')
        port = int(binding[0]['HostPort'])

        with tempfile.TemporaryDirectory(prefix='sdd-tsql-build-') as temporary:
            work = Path(temporary)
            (work / 'global.json').write_text(json.dumps({
                'sdk': {'version': lock['dotnet_sdk'], 'rollForward': 'disable'}}) + '\n')
            dacpacs = {}
            for stage in ('v1', 'v2', 'loss'):
                directory = work / stage
                shutil.copytree(FIXTURE / stage, directory)
                fixture.run(['dotnet', 'build', str(directory / 'Reference.sqlproj'),
                             '--configuration', 'Release', '--nologo'],
                            label=f'build-{stage}', timeout=240, cwd=work)
                found = list((directory / 'bin/Release').glob('*.dacpac'))
                fixture.check(f'built-{stage}-dacpac', len(found) == 1)
                dacpacs[stage] = found[0]
            profiles = {}
            for database in DATABASES:
                profile = work / f'{database}.publish.xml'
                publish_profile(profile, port, database, password)
                profiles[database] = profile

            def deploy(action, stage='v2', database='reference_upgrade', *, target=None, expected=0):
                argv = [package, f'/Action:{action}', f'/Profile:{profiles[database]}']
                argv.append(f'/SourceFile:{dacpacs[stage]}')
                if target is not None:
                    argv.append(f'/OutputPath:{target}')
                return fixture.run(argv, label=f'{action.lower()}-{stage}-{database}',
                                   expected=expected, timeout=180)

            def scalar(statement, database='reference_upgrade'):
                return sql(statement, database).stdout.strip()

            seed = "INSERT dbo.Account(Id,Label,Amount) VALUES(1,N'old-app',10.25),(2,N'empty',0);"
            deploy('Publish', 'v1')
            sql(seed)
            report = artifacts / 'upgrade-plan.xml'
            script = artifacts / 'upgrade.sql'
            deploy('DeployReport', target=report)
            deploy('Script', target=script)
            plan_xml = ET.parse(report)
            fixture.check('upgrade-plan-has-operation',
                          any(e.tag.rsplit('}', 1)[-1] == 'Operation' for e in plan_xml.iter()))
            script_text = read_generated_text(script)
            fixture.check('upgrade-script-adds-memo', 'Memo' in script_text and 'ALTER TABLE' in script_text)
            fixture.check('planning-did-not-apply', scalar(
                "SELECT COUNT(*) FROM sys.columns WHERE object_id=OBJECT_ID('dbo.Account') AND name='Memo'") == '0')
            deploy('Publish')
            fixture.check('upgrade-retains-data', scalar(
                "SELECT CONCAT(Id,'|',Label,'|',Amount,'|',COALESCE(Memo,N'<null>')) "
                "FROM dbo.Account ORDER BY Id") == '1|old-app|10.25|<null>\n2|empty|0.00|<null>')
            fixture.check('old-procedure-compatible', 'old-app' in sql('EXEC dbo.ReadAccount @Id=1').stdout)
            sql("INSERT dbo.Account(Id,Label,Amount,Memo) VALUES(3,N'new-app',42.50,N'hello');")
            fixture.check('new-application-write', scalar("SELECT Memo FROM dbo.Account WHERE Id=3") == 'hello')
            # A parameter value containing SQL syntax remains data, even in a server-side dynamic query.
            injection = scalar("EXEC sys.sp_executesql N'SELECT COUNT(*) FROM dbo.Account WHERE Label=@value', "
                               "N'@value nvarchar(80)', @value=N'x''; DROP TABLE dbo.Account;--';")
            fixture.check('parameterized-value-is-data', injection == '0' and
                          scalar("SELECT COUNT(*) FROM dbo.Account") == '3')
            fixture.check('empty-result', sql('EXEC dbo.ReadAccount @Id=999').stdout.strip() == '')
            for name, statement in (
                ('duplicate-key', "INSERT dbo.Account(Id,Label,Amount) VALUES(1,N'bad',1)"),
                ('missing-label', "INSERT dbo.Account(Id,Label,Amount) VALUES(4,NULL,1)"),
                ('decimal-overflow', "INSERT dbo.Account(Id,Label,Amount) VALUES(4,N'bad',10000000000.00)"),
            ):
                failed = sql(statement, expected=None)
                fixture.check(name + '-rejected', failed.returncode != 0 and
                              scalar('SELECT COUNT(*) FROM dbo.Account') == '3')

            # The fresh database reaches the same schema and data contract as the upgraded one.
            deploy('Publish', database='reference_fresh')
            sql(seed + "INSERT dbo.Account(Id,Label,Amount,Memo) VALUES(3,N'new-app',42.50,N'hello');",
                'reference_fresh')
            schema_query = ("SELECT CONCAT(name,'|',TYPE_NAME(user_type_id),'|',max_length,'|',precision,'|',scale,'|',is_nullable) "
                            "FROM sys.columns WHERE object_id=OBJECT_ID('dbo.Account') ORDER BY column_id")
            data_query = "SELECT CONCAT(Id,'|',Label,'|',Amount,'|',COALESCE(Memo,N'<null>')) FROM dbo.Account ORDER BY Id"
            fixture.check('fresh-upgrade-schema-parity', scalar(schema_query) == scalar(schema_query, 'reference_fresh'))
            fixture.check('fresh-upgrade-data-parity', scalar(data_query) == scalar(data_query, 'reference_fresh'))
            before = scalar(data_query)
            deploy('Publish')
            fixture.check('repeat-publish-preserves-data', scalar(data_query) == before)

            # SqlPackage registration is the state baseline; an out-of-band schema edit is separate from source history.
            baseline_schema = scalar(schema_query)
            sql('ALTER TABLE dbo.Account ADD Unplanned INT NULL;')
            drifted_schema = scalar(schema_query)
            (artifacts / 'drift.json').write_text(json.dumps({
                'baseline': baseline_schema, 'observed': drifted_schema}, indent=2) + '\n')
            fixture.check('real-schema-drift-detected', baseline_schema != drifted_schema and
                          'Unplanned' in drifted_schema)
            refused = deploy('Publish', expected=None)
            fixture.check('drift-publication-refused', refused.returncode != 0 and
                          'drift' in (refused.stdout + refused.stderr).lower() and
                          scalar("SELECT COUNT(*) FROM sys.columns WHERE object_id=OBJECT_ID('dbo.Account') AND name='Unplanned'") == '1')
            sql('ALTER TABLE dbo.Account DROP COLUMN Unplanned;')
            refused = deploy('Publish', 'loss', expected=None)
            fixture.check('destructive-publication-refused', refused.returncode != 0 and
                          'data loss' in (refused.stdout + refused.stderr).lower() and
                          scalar(data_query) == before and scalar(
                              "SELECT COUNT(*) FROM sys.columns WHERE object_id=OBJECT_ID('dbo.Account') AND name='Amount'") == '1')

            # A real database principal can use the application contract but not alter its schema.
            sql("CREATE USER reference_app WITHOUT LOGIN; GRANT SELECT, INSERT, UPDATE ON dbo.Account TO reference_app; "
                "GRANT EXECUTE ON dbo.ReadAccount TO reference_app;")
            sql("EXECUTE AS USER='reference_app'; UPDATE dbo.Account SET Memo=N'app-write' WHERE Id=3; "
                "EXEC dbo.ReadAccount @Id=3; REVERT;")
            denied = sql("EXECUTE AS USER='reference_app'; ALTER TABLE dbo.Account ADD Forbidden INT NULL;", expected=None)
            fixture.check('application-role-cannot-ddl', denied.returncode != 0 and scalar(
                "SELECT COUNT(*) FROM sys.columns WHERE object_id=OBJECT_ID('dbo.Account') AND name='Forbidden'") == '0')

            failed = sql("SET XACT_ABORT ON; BEGIN TRANSACTION; "
                         "INSERT dbo.Account(Id,Label,Amount) VALUES(9,N'rolled-back',9); "
                         "THROW 51000, 'Expected fixture failure', 1; COMMIT;", expected=None)
            fixture.check('failed-transaction-rolled-back', failed.returncode != 0 and
                          scalar('SELECT COUNT(*) FROM dbo.Account WHERE Id=9') == '0')
            sql("INSERT dbo.Account(Id,Label,Amount) VALUES(9,N'recovered',9);")
            fixture.check('roll-forward-after-observation', scalar("SELECT Label FROM dbo.Account WHERE Id=9") == 'recovered')

            started = time.monotonic()
            timed = sql("BEGIN TRANSACTION; INSERT dbo.Account(Id,Label,Amount) VALUES(10,N'timeout',10); "
                        "WAITFOR DELAY '00:00:06'; COMMIT;", expected=None, query_timeout=1)
            elapsed = time.monotonic() - started
            # Observe the server after cancellation; process exit alone is not proof of rollback.
            no_row = scalar('SELECT COUNT(*) FROM dbo.Account WHERE Id=10') == '0'
            no_other_session = scalar("SELECT COUNT(*) FROM sys.dm_exec_sessions WHERE is_user_process=1 "
                                      "AND program_name='SQLCMD' AND session_id<>@@SPID") == '0'
            fixture.check('timeout-cancel-observed-on-server',
                          timed.returncode != 0 and elapsed < 15 and no_row and no_other_session,
                          {'elapsed_seconds': round(elapsed, 3), 'row_absent': no_row, 'session_closed': no_other_session})

            with ThreadPoolExecutor(max_workers=1) as pool:
                holding = pool.submit(sql, "BEGIN TRANSACTION; UPDATE dbo.Account SET Amount=99 WHERE Id=1; "
                                      "WAITFOR DELAY '00:00:04'; ROLLBACK;", query_timeout=15)
                for _ in range(20):
                    if scalar("SELECT COUNT(*) FROM sys.dm_exec_requests WHERE database_id=DB_ID() AND command='WAITFOR'") == '1':
                        break
                    time.sleep(0.1)
                else:
                    raise AssertionError('Did not observe the lock holder')
                blocked = sql('SET LOCK_TIMEOUT 200; UPDATE dbo.Account SET Amount=999 WHERE Id=1;', expected=None)
                fixture.check('bounded-lock-wait', blocked.returncode != 0 and '1222' in blocked.stdout + blocked.stderr)
                holding.result(timeout=20)
            fixture.check('lock-release-and-no-partial-update', scalar('SELECT Amount FROM dbo.Account WHERE Id=1') == '10.25')

            hashes = {stage: hashlib.sha256(path.read_bytes()).hexdigest() for stage, path in dacpacs.items()}
            (artifacts / 'build-hashes.json').write_text(json.dumps(hashes, indent=2) + '\n')
            fixture.check('evidence-secret-free', all(password not in read_generated_text(path)
                                                    for path in artifacts.iterdir() if path.is_file()))
    except Exception as failure:
        error = failure
    return fixture.finish(error)


if __name__ == '__main__':
    raise SystemExit(main())
