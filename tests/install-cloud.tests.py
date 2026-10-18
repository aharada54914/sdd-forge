"""T-007 offline packaging tests; real installers and extracted validator boundary.

The validation block is read verbatim from validate-repository.ps1. Its global
workflow-state/role-render prechecks belong to the full repository validation,
not these isolated manifest mutations. No provider credentials or writes.
"""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
PWSH = os.environ.get('SDD_TEST_PWSH') or shutil.which('pwsh') or '/workspace/.tools/sdd-forge-dev/bin/pwsh'
SHELLS = ('pwsh',) if os.name == 'nt' else ('bash', 'pwsh')
PROVIDERS = ('azure', 'aws')
MODULES = ('cloud_contracts.py', 'cloud_authorization.py', 'cloud_verification.py', 'cloud_dependencies.py')
HOSTS = ('.claude-plugin', '.codex-plugin', '.plugin')
MARKETS = ('.agents/plugins/marketplace.json', '.claude-plugin/marketplace.json')


def run(args: list[str], cwd: Path, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, cwd=cwd, env=env, text=True, capture_output=True, timeout=180)


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + '\n')


def runtime_sources() -> dict[str, Path]:
    result = {'scripts/' + name: ROOT / 'plugins/sdd-quality-loop/scripts' / name for name in MODULES}
    result['references/cloud-verification-registry.json'] = ROOT / 'plugins/sdd-quality-loop/references/cloud-verification-registry.json'
    for path in (ROOT / 'contracts').glob('cloud-*.schema.json'):
        result['contracts/' + path.name] = path
    for name in ('verification-contract-v3.schema.json', 'selected-verification-plan-v2.schema.json'):
        result['contracts/' + name] = ROOT / 'plugins/sdd-quality-loop/contracts' / name
    return result


def seeded_manifests(root: Path) -> None:
    """Supply complete records even before registration exists; no missing setup Red."""
    for provider in PROVIDERS:
        name = f'sdd-{provider}-cloud'
        for host in HOSTS:
            path = root / f'plugins/{name}/{host}/plugin.json'
            if not path.exists():
                write_json(path, dict(name=name, version='1.18.0', description='Synthetic packaging fixture',
                                     author=dict(name='Harada'), skills=['./skills/'] if host == '.claude-plugin' else './skills/' if host == '.codex-plugin' else 'skills/'))
        for rel in MARKETS:
            path = root / rel
            value = json.loads(path.read_text())
            if not any(p['name'] == name for p in value['plugins']):
                source: object = './plugins/' + name
                entry: dict = dict(name=name, version='1.18.0', source=source)
                if rel.startswith('.agents'):
                    entry['source'] = dict(source='local', path=source)
                    entry['policy'] = dict(installation='AVAILABLE', authentication='ON_INSTALL')
                    entry['category'] = 'Developer Tools'
                value['plugins'].append(entry)
                write_json(path, value)
        for rel, source_path in runtime_sources().items():
            dest = root / f'plugins/{name}/runtime' / rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source_path, dest)


def fixture(root: Path) -> None:
    for directory in ('plugins', 'contracts', '.agents', '.claude-plugin', '.codex'):
        shutil.copytree(ROOT / directory, root / directory, ignore=shutil.ignore_patterns('__pycache__', 'node_modules'))
    for name in ('README.md', 'CHANGELOG.md', 'install.sh', 'install.ps1', 'uninstall.sh', 'uninstall.ps1'):
        shutil.copy2(ROOT / name, root / name)
    (root / 'tests').mkdir()
    shutil.copy2(ROOT / 'tests/validate-repository.ps1', root / 'tests/validate-repository.ps1')
    # Commit explicit fixture directories; never touches the real index.
    for args in (['git', 'init', '-q'], ['git', 'add', '--', 'plugins', 'contracts', '.agents', '.claude-plugin', '.codex', 'README.md', 'CHANGELOG.md', 'install.sh', 'install.ps1', 'uninstall.sh', 'uninstall.ps1', 'tests'],
                 ['git', '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', '-c', 'core.hooksPath=/dev/null', 'commit', '-qm', 'isolated packaging fixture']):
        p = run(args, root)
        if p.returncode:
            raise AssertionError(p.stderr)


def validate(root: Path, skills: bool = False) -> subprocess.CompletedProcess[str]:
    text = (ROOT / 'tests/validate-repository.ps1').read_text()
    block = text[text.index('$expectedPlugins ='):text.index('$forbiddenPaths =' if skills else '$skillFiles =')]
    if skills:
        block += text[text.index('$userVisibleSkills ='):text.index('Write-Host "Repository validation passed."')]
    driver = root / 'boundary.ps1'
    driver.write_text('param([string]$repositoryRoot)\n$ErrorActionPreference="Stop"\nSet-StrictMode -Version Latest\n' + block)
    return run([PWSH, '-NoProfile', '-File', str(driver), str(root)], root)


class ManifestBoundary(unittest.TestCase):
    temp: tempfile.TemporaryDirectory[str]
    root: Path

    @classmethod
    def setUpClass(cls) -> None:
        cls.temp = tempfile.TemporaryDirectory(prefix='cloud-package-fields-')
        cls.root = Path(cls.temp.name).resolve()
        fixture(cls.root)
        seeded_manifests(cls.root)

    @classmethod
    def tearDownClass(cls) -> None:
        cls.temp.cleanup()

    def test_matched_control(self) -> None:
        p = validate(self.root)
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)

    def test_existing_name_and_version_guards(self) -> None:
        path = self.root / 'plugins/sdd-domain/.claude-plugin/plugin.json'
        raw = path.read_bytes()
        for key, value in (('name', 'SDD-DOMAIN'), ('version', '0.0.0')):
            with self.subTest(key=key):
                record = json.loads(raw)
                record[key] = value
                try:
                    write_json(path, record)
                    p = validate(self.root)
                    self.assertNotEqual(p.returncode, 0)
                    self.assertIn('differ', p.stderr)
                finally:
                    path.write_bytes(raw)

    def test_cloud_manifest_field_mismatches(self) -> None:
        for provider in PROVIDERS:
            name = f'sdd-{provider}-cloud'
            for host in HOSTS:
                path = self.root / f'plugins/{name}/{host}/plugin.json'
                raw = path.read_bytes()
                for key, value in (('name', name.upper()), ('version', '0.0.0'), ('skills', './SKILLS/')):
                    with self.subTest(provider=provider, host=host, field=key):
                        record = json.loads(raw)
                        record[key] = value
                        try:
                            write_json(path, record)
                            p = validate(self.root)
                            self.assertNotEqual(p.returncode, 0, f'validator accepted mismatched {name}/{host}/{key}')
                        finally:
                            path.write_bytes(raw)

    def test_marketplace_field_mismatches(self) -> None:
        for rel in MARKETS:
            path = self.root / rel
            raw = path.read_bytes()
            for provider in PROVIDERS:
                name = f'sdd-{provider}-cloud'
                fields = ['name', 'source', 'version'] + (['policy', 'authentication'] if rel.startswith('.agents') else [])
                for key in fields:
                    with self.subTest(market=rel, provider=provider, field=key):
                        record = json.loads(raw)
                        entry = next(p for p in record['plugins'] if p['name'] == name)
                        if key == 'authentication':
                            entry['policy']['authentication'] = 'on_install'
                        else:
                            entry[key] = {'installation': 'REQUIRED', 'authentication': 'ON_INSTALL'} if key == 'policy' else name.upper() if key == 'name' else '0.0.0' if key == 'version' else '../outside'
                        try:
                            write_json(path, record)
                            p = validate(self.root)
                            self.assertNotEqual(p.returncode, 0, f'validator accepted mismatched {rel}/{name}/{key}')
                        finally:
                            path.write_bytes(raw)

    def test_runtime_field_mismatches(self) -> None:
        for provider in PROVIDERS:
            for rel in runtime_sources():
                path = self.root / f'plugins/sdd-{provider}-cloud/runtime' / rel
                raw = path.read_bytes()
                with self.subTest(provider=provider, runtime=rel):
                    try:
                        path.write_bytes(raw + b'\n')
                        p = validate(self.root)
                        self.assertNotEqual(p.returncode, 0, f'validator accepted divergent runtime {provider}/{rel}')
                    finally:
                        path.write_bytes(raw)



def local_request(root: Path, provider: str) -> dict:
    def put(path: str, value: object) -> dict[str, str]:
        data = value if isinstance(value, bytes) else (json.dumps(value, sort_keys=True) + '\n').encode()
        dest = root / path
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(data)
        return dict(path=path, sha256=hashlib.sha256(data).hexdigest())

    owner = 'bicep' if provider == 'azure' else 'cdk'
    scope = dict(account_id='synthetic-account', region='synthetic-region', deployment_scope='synthetic-scope')
    source = put('bundle/unit/main.bicep' if provider == 'azure' else 'bundle/unit/cdk.json', b'// synthetic\n' if provider == 'azure' else {})
    upstream = put('bundle/upstream/reference.md', b'Synthetic local integrity fixture.\n')
    evidence = 'specs/cloud-orchestration/verification/T-007/cloud/synthetic-run/synthetic-unit'
    (root / evidence).mkdir(parents=True, exist_ok=True)
    profile = dict(schema='cloud-verification-profile/v1', id='cloud-compute', version='2', required_check_ids=['resource', 'network', 'identity', 'monitoring', 'workload'], max_age_seconds=300)
    return dict(schema='cloud-run-request/v1', run_id='synthetic-run', unit_id='synthetic-unit', provider=provider,
        binding_id='synthetic-binding', environment='synthetic', scope=scope, owner=owner,
        route='azure-bicep' if provider == 'azure' else 'aws-cdk', operation='apply', predecessor_receipts=[],
        source_revision='a' * 40, input_artifacts=[dict(kind='source', **source)],
        dependency_lock=put('bundle/lock.json', dict(schema='cloud-dependency-lock/v1', adapter_version='1.0.0', upstream=[dict(repository='https://example.invalid/synthetic', commit='a' * 40, root='bundle/upstream', files=[dict(**upstream, references=[])])], tools=[dict(name=owner, version='1.0.0', sha256='a' * 64)], managed_endpoints=[])),
        policy=put('bundle/policy.json', dict(schema='cloud-deployment-policy/v1', allowed_scopes=[scope], allowed_resource_types=['synthetic'], backup_required=False, private_networking=True, budget=dict(ceiling_minor_units=10000, currency='USD'), evidence=dict(residency='synthetic', retention_days=7, access='restricted'))),
        verification_profile=dict(id='cloud-compute', version='2', **put('bundle/profile.json', profile)),
        local_context=dict(workspace_anchor='CLOUD_WORKSPACE_ROOT', artifact_root='bundle', unit_roots=['bundle/unit'], evidence_directory=evidence, feature='cloud-orchestration', task_id='T-007', ownership=put('bundle/ownership.json', dict(schema='cloud-ownership/v1', owners=[dict(owner=owner, root='bundle/unit')], existing_resources=[])), provider_config=put('bundle/config.json', dict(schema=provider+'-local-config/v1', import_resources=False))))


# Executed by isolated Python with ONLY the installed scripts directory added.
# No fixture imports from the repository; the fake authenticated response here
# is synthetic. Network access is intercepted with a scoped unittest mock.
RUNTIME_PROBE = r"""
import json, os, sys
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
runtime = Path(sys.argv[1])
sys.path.insert(0, str(runtime / 'scripts'))
import cloud_contracts as c
import cloud_authorization as a
import cloud_verification as v
import cloud_dependencies as d
for module in (c, a, v, d):
    assert Path(module.__file__).parent == runtime / 'scripts'
profile = dict(schema='cloud-verification-profile/v1', id='cloud-compute', version='2', required_check_ids=['resource','network','identity','monitoring','workload'], max_age_seconds=300)
selection = v.protected_selection(profile, dict(backup_required=False))
assert selection[0] == ['iac-validate','policy-validation','iac-preview','identity','monitoring','network','resource','workload']
registry = runtime / 'references/cloud-verification-registry.json'
raw = registry.read_bytes()
try:
    registry.unlink()
    try: v.protected_selection(profile, dict(backup_required=False))
    except FileNotFoundError: pass
    else: raise AssertionError('missing registry accepted')
    value = json.loads(raw); value['profiles'][0]['version'] = '200'
    registry.write_text(json.dumps(value))
    try: v.protected_selection(profile, dict(backup_required=False))
    except c.ContractError as exc: assert str(exc) == 'PROFILE_REGISTRY_INVALID'
    else: raise AssertionError('tampered registry accepted')
finally: registry.write_bytes(raw)
for name, version in [('verification-contract-v3.schema.json','verification-contract/v3'),('selected-verification-plan-v2.schema.json','selected-verification-plan/v2')]:
    assert json.loads((runtime / 'contracts' / name).read_bytes())['properties']['schema']['const'] == version
root = Path.cwd().resolve()
if os.name == 'nt':
    try: c.read_verified(root, dict(path='probe.json', sha256='a'*64))
    except c.ContractError as exc: assert str(exc) == 'UNSUPPORTED_FILESYSTEM'
    else: raise AssertionError('native Windows unexpectedly admitted POSIX runtime')
    print('installed schemas/modules PASS; native Windows cloud filesystem explicitly unsupported')
    sys.exit(0)
receipt = root / 'prior.json'; receipt.write_bytes(b'synthetic authenticated receipt')
ref = dict(path='prior.json', sha256=v.digest(receipt.read_bytes()))
pin = dict(unit_id='prior-unit', verification=ref)
policy = SimpleNamespace(predecessor_trust=(pin,), dependency_request_sha256='a'*64)
request_ref = dict(path='request.json', sha256='a'*64)
request = dict(predecessor_receipts=[dict(unit_id='prior-unit', **ref)])
deadline = c._utc(v.utc(200))
# This isolates installed dependency admission, NOT native GitHub provenance.
with patch('urllib.request.OpenerDirector.open', side_effect=AssertionError('network forbidden')), patch.object(d, '_verified', return_value=({}, receipt.read_bytes(), deadline)):
    assert d.admit_predecessors(root, request, request_ref, policy, None, None, clock=lambda:100) == deadline
    for mutated, expected in [(dict(predecessor_receipts=[]),'DEPENDENCY_SET_MISMATCH'), (dict(predecessor_receipts=[dict(unit_id='prior-unit', path='prior.json', sha256='b'*64)]),'DEPENDENCY_SET_MISMATCH')]:
        try: d.admit_predecessors(root, mutated, request_ref, policy, None, None, clock=lambda:100)
        except c.ContractError as exc: assert str(exc) == expected
        else: raise AssertionError('mismatched predecessor accepted')
        original = c._require
        def bypass(condition, code='INVALID_ARTIFACT'):
            if code != expected: original(condition, code)
        with patch.object(c, '_require', side_effect=bypass):
            assert d.admit_predecessors(root, mutated, request_ref, policy, None, None, clock=lambda:100) == deadline
    receipt.unlink()
    try: d.admit_predecessors(root, request, request_ref, policy, None, None, clock=lambda:100)
    except (OSError, c.ContractError): pass
    else: raise AssertionError('missing predecessor accepted')
print('installed modules, protected selection, registry denial, schemas, dependency controls/sensitivity: OK')
"""


class InstalledLifecycle(unittest.TestCase):
    temp: tempfile.TemporaryDirectory[str]
    root: Path
    source: Path

    @classmethod
    def setUpClass(cls) -> None:
        if os.name == 'nt':
            print('Native Windows: exercise PowerShell installation; Bash lifecycle and POSIX cloud execution not claimed')
        cls.temp = tempfile.TemporaryDirectory(prefix='cloud-install-lifecycle-')
        cls.root = Path(cls.temp.name).resolve()
        cls.source = cls.root / 'source'
        cls.source.mkdir()
        fixture(cls.source)

    @classmethod
    def tearDownClass(cls) -> None:
        cls.temp.cleanup()

    def installer(self, shell: str, plugins: tuple[str, ...], dest: Path, *, uninstall: bool = False) -> subprocess.CompletedProcess[str]:
        name = 'uninstall' if uninstall else 'install'
        env = dict(PATH=os.environ['PATH'], HOME=str(self.root), PYTHONDONTWRITEBYTECODE='1', SDD_CODEX_HOME=str(self.root / 'codex-home'))
        if shell == 'bash':
            args = ['bash', str(ROOT / (name + '.sh')), '--install-root', str(dest), '--target', 'FilesOnly', '--skip-agent-' + ('uninstall' if uninstall else 'install'), '--skip-mcp' + ('-uninstall' if uninstall else '')]
            if plugins:
                args += ['--plugins', ','.join(plugins)]
            if not uninstall:
                args += ['--source-directory', str(self.source)]
        else:
            # Native -File array binding differs from PowerShell's command parser.
            command = '& ' + "'" + str(ROOT / (name + '.ps1')) + "' -InstallRoot '" + str(dest) + "' -Target FilesOnly -SkipAgent" + ('Uninstall' if uninstall else 'Install') + ' -SkipMcp' + ('Uninstall' if uninstall else '')
            if plugins:
                command += ' -Plugins ' + ','.join("'"+p+"'" for p in plugins)
            if not uninstall:
                command += " -SourceDirectory '" + str(self.source) + "'"
            args = [PWSH, '-NoProfile', '-Command', command]
        return run(args, self.root, env)

    def test_each_provider_and_both_real_install_and_uninstall(self) -> None:
        for shell in SHELLS:
            for providers in (('azure',), ('aws',), PROVIDERS):
                with self.subTest(shell=shell, providers=providers), tempfile.TemporaryDirectory(dir=self.root) as temp:
                    dest = Path(temp) / 'installed'
                    p = self.installer(shell, tuple(f'sdd-{v}-cloud' for v in providers), dest)
                    self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
                    self.assertIn('sdd-quality-loop', p.stdout + p.stderr)
                    for provider in providers:
                        plugin = dest / f'plugins/sdd-{provider}-cloud'
                        for rel, canonical in runtime_sources().items():
                            self.assertEqual((plugin / 'runtime' / rel).read_bytes(), canonical.read_bytes(), rel)
                        self.check_runtime_and_cli(plugin, provider, Path(temp))
                        # Model each host's isolated cache: plugin payload ONLY, no
                        # shared sibling, development root or ambient Python paths.
                        for host in ('codex', 'claude', 'copilot'):
                            cached = Path(temp) / host / 'cache' / f'sdd-{provider}-cloud' / '1.18.0'
                            shutil.copytree(plugin, cached)
                            self.check_runtime_and_cli(cached, provider, Path(temp))
                    shared = dest / 'plugins/sdd-quality-loop/scripts/cloud_dependencies.py'
                    unrelated = dest / 'plugins/sdd-bootstrap/.codex-plugin/plugin.json'
                    before = (shared.read_bytes(), unrelated.read_bytes())
                    for provider in providers:
                        p = self.installer(shell, (f'sdd-{provider}-cloud',), dest, uninstall=True)
                        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
                        self.assertEqual((shared.read_bytes(), unrelated.read_bytes()), before)
                    # Existing behavior: dependencies remain even after last cloud
                    # uninstall, since unrelated plugins are still unselected.
                    p = self.installer(shell, (), dest, uninstall=True)
                    self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
                    self.assertFalse(dest.exists())

    def check_runtime_and_cli(self, plugin: Path, provider: str, parent: Path) -> None:
        with tempfile.TemporaryDirectory(dir=parent) as temp:
            work = Path(temp).resolve()
            runtime = plugin / 'runtime'
            env = dict(PATH=os.defpath, HOME=str(work), CLOUD_WORKSPACE_ROOT=str(work), CLOUD_SHARED_RUNTIME_ROOT=str(runtime / 'scripts'), PYTHONDONTWRITEBYTECODE='1')
            p = run([sys.executable, '-I', '-B', '-c', RUNTIME_PROBE, str(runtime)], work, env)
            self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
            request = local_request(work, provider)
            request_path = work / 'request.json'
            for phase in ('route', 'prepare', 'apply'):
                write_json(request_path, request)
                output = request['local_context']['evidence_directory'] + '/' + phase + '.json'
                p = run([sys.executable, '-B', str(plugin / 'scripts/cloud.py'), phase, '--request', str(request_path), '--output', output], work, env)
                if os.name == 'nt':
                    self.assertEqual(p.returncode, 2, p.stdout + p.stderr)
                    self.assertIn(json.loads(p.stdout)['error_code'], ('UNSUPPORTED_FILESYSTEM', 'UNSAFE_ROOT'))
                    self.assertFalse((work / output).exists())
                    continue
                self.assertEqual(p.returncode, 0 if phase == 'route' else 2, p.stdout + p.stderr)
                result = json.loads(p.stdout)
                self.assertEqual(result['result'], 'PASS' if phase == 'route' else 'BLOCKED')
                if phase != 'route':
                    self.assertEqual(result['error_code'], 'OPERATION_UNIMPLEMENTED')
                    self.assertFalse((work / output).exists())
            if os.name == 'nt':
                return  # Native refusal above is not POSIX cloud execution evidence.
            # Structural LOCAL route integrity only: these saved files confer no
            # authority and are not authenticated/live predecessor evidence.
            # Keep this distinct from the no-executor write denials above and
            # the scoped authenticated-deadline callable probe in RUNTIME_PROBE.
            prior_dir = 'specs/cloud-orchestration/verification/T-007/cloud/prior-run/prior-unit'
            prior = work / prior_dir / 'verification.json'
            observation = work / prior_dir / 'synthetic-observation.json'
            write_json(observation, dict(classification='synthetic', purpose='local structural fixture only'))
            observation_ref = dict(path=observation.relative_to(work).as_posix(), sha256=hashlib.sha256(observation.read_bytes()).hexdigest())
            check_ids = json.loads((work / request['verification_profile']['path']).read_bytes())['required_check_ids']
            receipt = dict(schema='cloud-verification/v1', run_id='prior-run', unit_id='prior-unit', provider=provider,
                           profile=request['verification_profile'], required_check_ids=check_ids,
                           checks=[dict(check_id=check, observation=observation_ref, result='PASS') for check in check_ids],
                           overall_result='PASS', evidence_complete=True)
            for variant, expected_error in (('matched', None), ('missing', 'UNSAFE_OR_UNAVAILABLE_FILE'),
                                            ('invalid', 'CHECK_SET_MISMATCH'), ('restored', None)):
                with self.subTest(provider=provider, plugin=str(plugin), predecessor=variant):
                    # All bodies use the canonical path and actual byte digest.
                    # The invalid body differs ONLY in its required check set;
                    # no path/digest/setup failure can satisfy its assertion.
                    body = dict(receipt)
                    if variant == 'invalid':
                        body['checks'] = receipt['checks'][:-1]
                    write_json(prior, body)
                    request['predecessor_receipts'] = [dict(unit_id='prior-unit', path=prior.relative_to(work).as_posix(),
                                                          sha256=hashlib.sha256(prior.read_bytes()).hexdigest())]
                    if variant == 'missing':
                        prior.unlink()
                    write_json(request_path, request)
                    output = request['local_context']['evidence_directory'] + '/' + variant + '-route.json'
                    p = run([sys.executable, '-B', str(plugin / 'scripts/cloud.py'), 'route', '--request', str(request_path), '--output', output], work, env)
                    self.assertEqual(p.returncode, 0 if expected_error is None else 2, p.stdout + p.stderr)
                    result = json.loads(p.stdout)
                    self.assertEqual(result['result'], 'PASS' if expected_error is None else 'BLOCKED')
                    self.assertEqual(result['error_code'], expected_error)
                    self.assertEqual((work / output).exists(), expected_error is None)
            print(f'installed {provider}: canonical predecessor route matched/restored PASS; missing UNSAFE_OR_UNAVAILABLE_FILE; invalid CHECK_SET_MISMATCH')
            module = runtime / 'scripts/cloud_dependencies.py'
            raw = module.read_bytes()
            try:
                module.unlink()
                p = run([sys.executable, '-I', '-B', '-c', RUNTIME_PROBE, str(runtime)], work, env)
                self.assertNotEqual(p.returncode, 0)
                self.assertIn('cloud_dependencies', p.stderr)
            finally:
                module.write_bytes(raw)
            # Explicit missing trusted root must never fall back to development.
            env['CLOUD_SHARED_RUNTIME_ROOT'] = str(work / 'absent')
            p = run([sys.executable, '-B', str(plugin / 'scripts/cloud.py'), 'route', '--request', str(request_path), '--output', 'out.json'], work, env)
            self.assertEqual(p.returncode, 2)
            self.assertEqual(json.loads(p.stdout)['error_code'], 'SHARED_RUNTIME_UNAVAILABLE')

    def test_missing_shared_dependency_aborts_before_placement(self) -> None:
        path = self.source / 'plugins/sdd-quality-loop/scripts/cloud_dependencies.py'
        raw = path.read_bytes()
        try:
            path.unlink()
            for shell in SHELLS:
                with self.subTest(shell=shell):
                    dest = self.root / ('missing-' + shell)
                    p = self.installer(shell, ('sdd-azure-cloud',), dest)
                    self.assertNotEqual(p.returncode, 0)
                    self.assertFalse(dest.exists())
        finally:
            path.write_bytes(raw)

    def test_sequential_selections_rebuild_prior_runtime(self) -> None:
        for shell in SHELLS:
            for first, second in (PROVIDERS, tuple(reversed(PROVIDERS))):
                with tempfile.TemporaryDirectory(dir=self.root) as temp:
                    dest = Path(temp) / 'installed'
                    installed: list[str] = []
                    selections = ((f'sdd-{first}-cloud',), (f'sdd-{second}-cloud',), (), ('sdd-review-loop',))
                    for step, selection in enumerate(selections):
                        print(f'sequential {shell}: {first}->{second}, step={step}, selection={selection or "default"}', flush=True)
                        p = self.installer(shell, selection, dest)
                        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
                        if step < 2:
                            installed.append((first, second)[step])
                        for provider in PROVIDERS:
                            plugin = dest / f'plugins/sdd-{provider}-cloud'
                            if provider not in installed:
                                self.assertFalse((plugin / 'runtime').exists(), 'unselected provider was materialized')
                                continue
                            with self.subTest(shell=shell, first=first, step=step, provider=provider, check='canonical bytes'):
                                mismatches = [rel for rel, canonical in runtime_sources().items()
                                              if not (plugin / 'runtime' / rel).is_file()
                                              or (plugin / 'runtime' / rel).read_bytes() != canonical.read_bytes()]
                                self.assertEqual(mismatches, [])
                            with self.subTest(shell=shell, first=first, step=step, provider=provider, check='installed CLI'):
                                self.check_runtime_and_cli(plugin, provider, Path(temp))
                            with self.subTest(shell=shell, first=first, step=step, provider=provider, check='direct route'), tempfile.TemporaryDirectory(dir=temp) as work_temp:
                                work = Path(work_temp).resolve()
                                request = local_request(work, provider)
                                write_json(work / 'request.json', request)
                                env = dict(PATH=os.defpath, HOME=str(work), CLOUD_WORKSPACE_ROOT=str(work),
                                           CLOUD_SHARED_RUNTIME_ROOT=str(plugin / 'runtime/scripts'), PYTHONDONTWRITEBYTECODE='1')
                                p = run([sys.executable, '-B', str(plugin / 'scripts/cloud.py'), 'route', '--request', str(work / 'request.json'),
                                         '--output', request['local_context']['evidence_directory'] + '/route.json'], work, env)
                                print(f'direct {shell}/{provider} step={step}: exit={p.returncode} {p.stdout.strip()}', flush=True)
                                self.assertEqual(p.returncode, 2 if os.name == 'nt' else 0, p.stdout + p.stderr)
                                if os.name == 'nt':
                                    self.assertIn(json.loads(p.stdout)['error_code'], ('UNSUPPORTED_FILESYSTEM', 'UNSAFE_ROOT'))
                        # Prior executable/schema bytes are NOT trusted upgrade inputs.
                        # The next real install must regenerate every payload from source.
                        if step < len(selections) - 1:
                            for provider in installed:
                                for rel in runtime_sources():
                                    path = dest / f'plugins/sdd-{provider}-cloud/runtime' / rel
                                    if path.is_file():
                                        path.write_bytes(b'stale or tampered prior payload\n')

    def test_prior_runtime_rebuild_failure_preserves_installation(self) -> None:
        # Remove inputs from the export index, leaving their untracked source
        # bytes available: neither source fallback nor the old runtime is trusted.
        groups = (
            ('plugins/sdd-quality-loop/scripts/cloud_dependencies.py',),
            ('plugins/sdd-quality-loop/references/cloud-verification-registry.json',),
            ('plugins/sdd-quality-loop/contracts/verification-contract-v3.schema.json',),
            tuple(str(p.relative_to(ROOT)) for p in (ROOT / 'contracts').glob('cloud-*.schema.json')),
            ('plugins/sdd-azure-cloud/scripts/cloud.py',),
            ('plugins/sdd-azure-cloud/scripts/azure_local.py',),
            ('plugins/sdd-azure-cloud/.codex-plugin/plugin.json',),
            ('plugins/sdd-azure-cloud/skills/orchestrate/SKILL.md',),
        )
        for shell in SHELLS:
            for missing in groups:
                with self.subTest(shell=shell, missing=missing), tempfile.TemporaryDirectory(dir=self.root) as temp:
                    dest = Path(temp) / 'installed'
                    p = self.installer(shell, ('sdd-azure-cloud',), dest)
                    self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
                    before = {str(p.relative_to(dest)): hashlib.sha256(p.read_bytes()).hexdigest()
                              for p in dest.rglob('*') if p.is_file()}
                    p = run(['git', 'rm', '--cached', '--', *missing], self.source)
                    self.assertEqual(p.returncode, 0, p.stderr)
                    try:
                        p = self.installer(shell, ('sdd-review-loop',), dest)
                    finally:
                        restored = run(['git', 'add', '--', *missing], self.source)
                        self.assertEqual(restored.returncode, 0, restored.stderr)
                    after = {str(p.relative_to(dest)): hashlib.sha256(p.read_bytes()).hexdigest()
                             for p in dest.rglob('*') if p.is_file()}
                    print(f'prior rebuild {shell}: missing={missing}, exit={p.returncode}, preserved={before == after}', flush=True)
                    print(p.stdout + p.stderr, flush=True)
                    self.assertNotEqual(p.returncode, 0, p.stdout + p.stderr)
                    if len(missing) == 1:
                        self.assertIn(Path(missing[0]).name, p.stdout + p.stderr)
                    else:
                        self.assertIn('cloud-' if shell == 'bash' else 'Cloud schemas are missing', p.stdout + p.stderr)
                    self.assertEqual(after, before)
                    self.check_runtime_and_cli(dest / 'plugins/sdd-azure-cloud', 'azure', Path(temp))

    def test_case_variants_at_operator_and_file_discovery_layers(self) -> None:
        for shell in SHELLS:
            for plugin in ('SDD-AZURE-CLOUD', 'sdd-Aws-cloud'):
                with self.subTest(shell=shell, plugin=plugin):
                    dest = self.root / (shell + '-' + plugin)
                    p = self.installer(shell, (plugin,), dest)
                    self.assertNotEqual(p.returncode, 0)
                    self.assertFalse(dest.exists())
        # Independent cmdlet/glob check: uppercase schema name is not packaged.
        marker = self.source / 'contracts/CLOUD-CASE.schema.json'
        marker.write_text('{}\n')
        p = run(['git', 'add', '--', 'contracts/CLOUD-CASE.schema.json'], self.source)
        self.assertEqual(p.returncode, 0, p.stderr)
        try:
            for shell in SHELLS:
                dest = self.root / ('case-schema-' + shell)
                p = self.installer(shell, ('sdd-azure-cloud',), dest)
                self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
                self.assertFalse((dest / 'plugins/sdd-azure-cloud/runtime/contracts' / marker.name).exists())
        finally:
            run(['git', 'rm', '-f', '--', 'contracts/CLOUD-CASE.schema.json'], self.source)


class SkillVisibility(unittest.TestCase):
    def test_real_export_consumer_ignores_upstream_reference_skills(self) -> None:
        with tempfile.TemporaryDirectory(prefix='cloud-skill-exports-') as temp:
            root = Path(temp).resolve()
            fixture(root)
            result = validate(root, skills=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


    def test_visibility_guards_with_matched_controls(self) -> None:
        with tempfile.TemporaryDirectory(prefix='cloud-visibility-guards-') as temp:
            root = Path(temp).resolve()
            fixture(root)
            self.assertEqual(validate(root, skills=True).returncode, 0)
            for provider in PROVIDERS:
                path = root / f'plugins/sdd-{provider}-cloud/skills/orchestrate/SKILL.md'
                original = path.read_text()
                variants = [
                    original.replace('name: orchestrate', 'name: Orchestrate'),
                    original.replace('disable-model-invocation: true', 'disable-model-invocation: false'),
                    original.replace('disable-model-invocation: true', 'disable-model-invocation: true\nuser-invocable: false'),
                ]
                for index, variant in enumerate(variants):
                    with self.subTest(provider=provider, variant=index):
                        try:
                            path.write_text(variant)
                            result = validate(root, skills=True)
                            self.assertNotEqual(result.returncode, 0)
                        finally:
                            path.write_text(original)
                self.assertEqual(validate(root, skills=True).returncode, 0)

    def test_each_entry_frontmatter_and_relative_links(self) -> None:
        import re
        for provider in PROVIDERS:
            skill = ROOT / f'plugins/sdd-{provider}-cloud/skills/orchestrate/SKILL.md'
            text = skill.read_text()
            frontmatter = text.split('---', 2)[1]
            self.assertIn('name: orchestrate', frontmatter)
            self.assertIn('disable-model-invocation: true', frontmatter)
            self.assertNotIn('user-invocable: false', frontmatter)
            for link in re.findall(r'\]\(([^)]+)\)', text):
                self.assertTrue((skill.parent / link).is_file(), link)

if __name__ == '__main__':
    unittest.main(verbosity=2)
