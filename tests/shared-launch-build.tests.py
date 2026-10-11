"""Assemble FilesOnly distribution without changing the checkout's index or host."""
import hashlib
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = [
    'plugins/sdd-review-loop/scripts/' + name for name in (
        'validate-nontty-spec-launch.py', 'probe-nontty-review.py',
        'preflight-host-review.py', 'launch-impl-review.py',
        'nontty-impl-pretool-guard.mjs')
] + [
    'plugins/sdd-quality-loop/scripts/' + name for name in (
        'preflight-evaluator-delivery.py', 'review-conditional-inputs.py')
]


class DistributionTests(unittest.TestCase):
    def test_files_only_assembly(self):
        index = Path(subprocess.check_output(
            ['git', 'rev-parse', '--git-path', 'index'], cwd=ROOT,
            text=True).strip())
        if not index.is_absolute():
            index = ROOT / index
        before = index.read_bytes()
        with tempfile.TemporaryDirectory(prefix='shared-launch-build-') as folder:
            temp = Path(folder)
            env = dict(os.environ, GIT_INDEX_FILE=str(temp / 'index'))
            def run(args):
                subprocess.run(args, cwd=ROOT, env=env, check=True)
            try:
                # Include approved, still-untracked runtime additions without staging the owner.
                run(['git', 'read-tree', 'HEAD'])
                run(['git', 'add', '--', *SCRIPTS])
                installed = temp / 'installed'
                run(['bash', 'install.sh', '--source-directory', str(ROOT),
                     '--install-root', str(installed), '--target', 'FilesOnly',
                     '--plugins', 'sdd-review-loop,sdd-quality-loop',
                     '--skip-plugin-install', '--skip-agent-install', '--skip-mcp'])
                for name in SCRIPTS:
                    with self.subTest(path=name):
                        self.assertEqual(hashlib.sha256((ROOT / name).read_bytes()).digest(),
                                         hashlib.sha256((installed / name).read_bytes()).digest())
                for name in SCRIPTS:
                    if name.endswith('.py') and not name.endswith('probe-nontty-review.py'):
                        run([sys.executable, '-B', str(installed / name), '--help'])
                run(['node', '--check', str(installed / SCRIPTS[4])])
            finally:
                self.assertEqual(index.read_bytes(), before, 'owner index changed')


if __name__ == '__main__':
    unittest.main()
