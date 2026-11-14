"""Exercise SQL skill delivery through the real FilesOnly installer."""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent / 'lib'))
from sql_database_fixture import DockerFixture

ROOT = Path(__file__).resolve().parents[1]
SKILL = Path('plugins/sdd-implementation/skills/sql-develop')


class SqlSkillDistributionTests(unittest.TestCase):
    def test_completed_flyway_is_released_after_result_capture(self):
        for code in (0, 9):
            with self.subTest(upstream_exit=code), tempfile.TemporaryDirectory() as folder:
                fixture = DockerFixture('contract', Path(folder) / 'proof.json', [])
                fixture.containers = ['database', 'migration']
                removed = []

                def daemon(args, **kwargs):
                    if args == ['wait', 'migration']:
                        return subprocess.CompletedProcess(args, 0, str(code), '')
                    if args == ['logs', 'migration']:
                        self.assertFalse(removed, 'logs must precede container removal')
                        return subprocess.CompletedProcess(args, 0, '{"operation":"migrate"}', 'warning')
                    if args == ['inspect', 'migration']:
                        if removed:
                            return subprocess.CompletedProcess(args, 1, '', 'No such object')
                        labels = {'sdd.sql.test-run': fixture.run_id}
                        return subprocess.CompletedProcess(args, 0, json.dumps([{'Config': {'Labels': labels}}]), '')
                    self.assertEqual(args, ['rm', '--force', '--volumes', 'migration'])
                    removed.append('migration')
                    return subprocess.CompletedProcess(args, 0, 'migration', '')

                with patch.object(fixture, 'start_container', return_value='migration'), \
                        patch.object(fixture, 'docker', side_effect=daemon):
                    result = fixture.flyway('image', 'url', 'user', 'password', folder, 'migrate')
                self.assertEqual(result.returncode, code)
                self.assertEqual(result.stdout, '{"operation":"migrate"}')
                self.assertEqual(result.stderr, 'warning')
                self.assertEqual(removed, ['migration'])
                self.assertEqual(fixture.containers, ['database'])

    def test_flyway_keeps_cleanup_registration_when_capture_or_ownership_fails(self):
        for failure in ('logs', 'ownership'):
            with self.subTest(failure=failure), tempfile.TemporaryDirectory() as folder:
                fixture = DockerFixture('contract', Path(folder) / 'proof.json', [])
                fixture.containers = ['migration']

                def daemon(args, **kwargs):
                    self.assertNotEqual(args[0], 'rm', 'uncaptured or unowned containers must not be removed')
                    if args[0] == 'wait':
                        return subprocess.CompletedProcess(args, 0, '0', '')
                    if args[0] == 'logs':
                        if failure == 'logs':
                            raise RuntimeError('log capture failed')
                        return subprocess.CompletedProcess(args, 0, '{}', '')
                    self.assertEqual(args, ['inspect', 'migration'])
                    return subprocess.CompletedProcess(args, 0, '[{"Config":{"Labels":{}}}]', '')

                with patch.object(fixture, 'start_container', return_value='migration'), \
                        patch.object(fixture, 'docker', side_effect=daemon), self.assertRaises(RuntimeError):
                    fixture.flyway('image', 'url', 'user', 'password', folder, 'migrate')
                self.assertEqual(fixture.containers, ['migration'])

    def test_locked_database_images_pass_before_any_daemon_operation(self):
        with tempfile.TemporaryDirectory(prefix='sql-image-contract-') as folder:
            fixture = DockerFixture('contract', Path(folder) / 'proof.json', [])
            lock = ROOT / 'tests/fixtures/sql-development'
            images = [json.loads((lock / 'tsql/lock.json').read_text())['sql_server_image']]
            for engine in ('postgres', 'mysql'):
                pins = json.loads((lock / engine / 'images.json').read_text())
                images.extend(pins[key]['image'] for key in ('database', 'flyway'))
            with patch.object(fixture, 'docker') as daemon:
                for image in images:
                    with self.subTest(image=image):
                        fixture.pull(image)
                self.assertEqual(set(fixture.images), set(images))
                daemon.reset_mock()
                for mutable in ('postgres:latest', images[0].split('@')[0],
                                'mysql:8.4@sha256:not-a-digest'):
                    with self.subTest(mutable=mutable), self.assertRaises(AssertionError):
                        fixture.pull(mutable)
                daemon.assert_not_called()

    def test_installed_resources_are_reachable_from_each_host_manifest(self):
        files = sorted(path for path in (ROOT / SKILL).rglob('*') if path.is_file())
        self.assertTrue(files, 'SQL skill payload is missing')
        index = Path(subprocess.check_output(
            ['git', 'rev-parse', '--git-path', 'index'], cwd=ROOT, text=True).strip())
        if not index.is_absolute():
            index = ROOT / index
        original_index = index.read_bytes()
        with tempfile.TemporaryDirectory(prefix='sql-skill-distribution-') as folder:
            temp = Path(folder)
            env = dict(os.environ, GIT_INDEX_FILE=str(temp / 'index'))

            def run(argv):
                result = subprocess.run(argv, cwd=ROOT, env=env, text=True,
                                        capture_output=True, timeout=180, check=False)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

            try:
                run(['git', 'read-tree', 'HEAD'])
                # The private index includes this candidate without staging another worker.
                run(['git', 'add', '--', str(SKILL)])
                installed = temp / 'installed'
                run(['bash', 'install.sh', '--source-directory', str(ROOT),
                     '--install-root', str(installed), '--target', 'FilesOnly',
                     '--plugins', 'sdd-implementation', '--skip-plugin-install',
                     '--skip-agent-install', '--skip-mcp'])
                for path in files:
                    relative = path.relative_to(ROOT)
                    with self.subTest(resource=str(relative)):
                        self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),
                                         hashlib.sha256((installed / relative).read_bytes()).hexdigest())
                plugin = installed / 'plugins/sdd-implementation'
                for host in ('.claude-plugin', '.codex-plugin', '.plugin'):
                    # Native hosts cache one plugin/version independently of its peers.
                    cached = temp / 'cache' / host / 'sdd-implementation' / 'candidate'
                    shutil.copytree(plugin, cached)
                    manifest = json.loads((cached / host / 'plugin.json').read_text())
                    skill_roots = manifest['skills']
                    if isinstance(skill_roots, str):
                        skill_roots = [skill_roots]
                    with self.subTest(host=host):
                        self.assertTrue(any((cached / name / 'sql-develop/SKILL.md').is_file()
                                            for name in skill_roots))
                    for document in (cached / 'skills/sql-develop').rglob('*.md'):
                        for target in re.findall(r'\]\(([^)]+)\)', document.read_text()):
                            if target.startswith(('https://', 'http://', '#')):
                                continue
                            resolved = (document.parent / target.split('#', 1)[0]).resolve()
                            with self.subTest(host=host, resource=document.name, link=target):
                                self.assertTrue(resolved.is_relative_to(cached.resolve()))
                                self.assertTrue(resolved.is_file())
                for source in (installed / SKILL).rglob('*.md'):
                    for target in re.findall(r'\]\(([^)]+)\)', source.read_text()):
                        if target.startswith(('https://', 'http://', '#')):
                            continue
                        resolved = (source.parent / target.split('#', 1)[0]).resolve()
                        with self.subTest(document=source.name, link=target):
                            self.assertTrue(resolved.is_relative_to(installed.resolve()))
                            self.assertTrue(resolved.is_file(), f'Missing installed reference: {target}')
            finally:
                self.assertEqual(index.read_bytes(), original_index, 'Owner index changed')


if __name__ == '__main__':
    unittest.main()
