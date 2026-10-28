"""Exercise actual local Copilot skill discovery and removal on synthetic data."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]
BASE = Path('/workspace/.tools/sdd-forge-dev/verification-workspace')
CLI = Path(os.environ.get('SDD_COPILOT_CLI', '/tmp/sdd-forge-host-cli-check/node_modules/.bin/copilot'))
PRODUCT = ROOT / 'plugins/sdd-bootstrap/scripts/project-skill.py'
with tempfile.TemporaryDirectory(prefix='copilot-discovery-', dir=BASE) as directory:
    root = Path(directory)
    skill = root / 'sdd/skills/inspect-copilot-cleanup'
    skill.mkdir(parents=True)
    source = skill / 'SKILL.md'
    source.write_text('---\nname: inspect-copilot-cleanup\ndescription: Inspect the synthetic note.\n---\nRead note.txt.\n')
    (skill / 'run.py').write_text('print("synthetic")\n')
    original = hashlib.sha256(source.read_bytes()).hexdigest()
    environment = os.environ.copy()
    environment['COPILOT_HOME'] = str(root / 'copilot-state')
    def run(args):
        result = subprocess.run(args, cwd=root, env=environment, capture_output=True, text=True, timeout=30)
        if result.returncode:
            raise RuntimeError('native or project command failed')
        return result.stdout
    seal = json.loads(run(['python3', str(PRODUCT), 'seal', '--root', str(root), '--name',
                           'inspect-copilot-cleanup', '--runtime', 'python3', '--entry', 'run.py', '--check', 'probe']))
    projection = json.loads(run(['python3', str(PRODUCT), 'project', '--root', str(root), '--name',
                                 'inspect-copilot-cleanup', '--host', 'copilot']))
    wrapper = root / projection['path']
    def discovered():
        rows = json.loads(run([str(CLI), 'skill', 'list', '--json']))
        return [entry for entry in rows if entry.get('name') == 'inspect-copilot-cleanup'
                and Path(entry['path']).resolve() == wrapper.parent.resolve()]
    first = discovered()
    assert len(first) == 1 and first[0]['enabled'] and first[0]['source'] == 'project'
    wrapper_sha = hashlib.sha256(wrapper.read_bytes()).hexdigest()
    shutil.rmtree(wrapper.parent)
    second = discovered()
    assert not second and hashlib.sha256(source.read_bytes()).hexdigest() == original
    result = {'cli_version': run([str(CLI), '--version']).splitlines()[0],
              'source_sha256': hashlib.sha256(PRODUCT.read_bytes()).hexdigest(),
              'seal_status': seal['status'], 'wrapper_sha256': wrapper_sha,
              'discovered_before': len(first), 'discovered_after': len(second),
              'canonical_source_unchanged': True, 'model_run': 'not-run'}
assert not root.exists()
result['fixture_removed'] = True
print(json.dumps(result, indent=2))
