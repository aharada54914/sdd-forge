"""Exercise SQL skill delivery through the real FilesOnly installer."""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SKILL = Path('plugins/sdd-implementation/skills/sql-develop')


class SqlSkillDistributionTests(unittest.TestCase):
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
