"""T-007 offline packaging tests; real installers and extracted validator boundary.

The validation block is read verbatim from validate-repository.ps1. Its global
workflow-state/role-render prechecks belong to the full repository validation,
not these isolated manifest mutations. No provider credentials or writes.
"""
from __future__ import annotations

import copy
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
PWSH = os.environ.get('SDD_TEST_PWSH', '/workspace/.tools/sdd-forge-dev/bin/pwsh')
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
    driver = root / 'boundary.ps1'
    driver.write_text('param([string]$repositoryRoot)\n$ErrorActionPreference="Stop"\nSet-StrictMode -Version Latest\n' + block)
    return run([PWSH, '-NoProfile', '-File', str(driver), str(root)], root)


class ManifestBoundary(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.temp = tempfile.TemporaryDirectory(prefix='cloud-package-fields-')
        cls.root = Path(cls.temp.name)
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
                fields = ['name', 'source', 'version'] + (['policy'] if rel.startswith('.agents') else [])
                for key in fields:
                    with self.subTest(market=rel, provider=provider, field=key):
                        record = json.loads(raw)
                        entry = next(p for p in record['plugins'] if p['name'] == name)
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


if __name__ == '__main__':
    unittest.main(verbosity=2)
