"""Generate only T-002 fixture restoration evidence; never original RED proof."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
OUT = Path(tempfile.mkdtemp(prefix='current-restoration-', dir=HERE))
WORK = OUT / 'checkout'
BACKUP = OUT / 'before'
TARGETS = ['AGENTS.md',
    'plugins/sdd-review-loop/scripts/review-hash-normalization.ps1',
    'plugins/sdd-review-loop/scripts/impl-review-precheck.ps1',
    'plugins/sdd-review-loop/scripts/task-review-precheck.ps1',
    'plugins/sdd-quality-loop/scripts/validate-review-context-set.sh',
    'plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1',
    'tests/traceability-freeze-contract.tests.py',
    'tests/review-hash-normalization.tests.ps1']

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def copy(relative):
    src, dst = ROOT / relative, WORK / relative
    dst.parent.mkdir(parents=True, exist_ok=True)
    if src.is_dir():
        shutil.copytree(src, dst, ignore=shutil.ignore_patterns('__pycache__', 'node_modules'))
    else:
        shutil.copy2(src, dst)

def run(label, argv):
    proc = subprocess.run(['rtk', 'proxy', *argv], cwd=WORK, text=True, capture_output=True)
    (OUT / (label + '.log')).write_text(proc.stdout + proc.stderr)
    row = {'label': label, 'argv': ['rtk', 'proxy', *argv], 'cwd': str(WORK), 'exit_code': proc.returncode}
    results.append(row)
    (OUT / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
    assert proc.returncode == 0, row

results = []
clone = subprocess.run(['rtk', 'proxy', 'git', 'clone', '--shared', '--no-checkout', str(ROOT), str(WORK)], text=True, capture_output=True)
(OUT / 'checkout-creation.log').write_text(clone.stdout + clone.stderr)
assert clone.returncode == 0, clone.stderr
for rel in ['plugins/sdd-review-loop', 'plugins/sdd-quality-loop',
            'contracts/workflow-state-registry.schema.json',
            'specs/workflow-state-integrity', 'specs/workflow-state-registry.json',
            'reports/spec-review/workflow-state-integrity',
            'reports/impl-review/workflow-state-integrity',
            'reports/task-review/workflow-state-integrity', 'AGENTS.md',
            'tests/workflow-state.tests.sh', 'tests/downstream-review-precheck-parity.tests.sh',
            'tests/traceability-freeze-contract.tests.py', 'tests/review-hash-normalization.tests.ps1']:
    copy(rel)
registry = WORK / 'specs/workflow-state-registry.json'
registry_hash = digest(registry)
directories = []
for entry in json.loads(registry.read_text())['entries']:
    feature = entry['feature']
    assert isinstance(feature, str) and feature not in ('', '.', '..')
    assert '/' not in feature and '\\' not in feature
    relative = Path('specs') / feature
    assert (ROOT / relative).is_dir(), relative
    (WORK / relative).mkdir(exist_ok=True)
    directories.append(str(relative))
assert digest(registry) == registry_hash
(OUT / 'registry-topology.json').write_text(json.dumps({
    'directories': directories, 'registry_sha256': registry_hash,
    'reason': 'Workflow validation checks registered directory existence before feature filtering; no registry bytes changed.'
}, indent=2) + '\n')
before = {}
for rel in TARGETS:
    dst = BACKUP / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ROOT / rel, dst)
    assert digest(WORK / rel) == digest(dst)
    before[rel] = digest(dst)
(OUT / 'before-hashes.json').write_text(json.dumps(before, indent=2) + '\n')
run('before-hash-parity', ['pwsh', '-NoProfile', '-File', 'tests/review-hash-normalization.tests.ps1'])
run('before-traceability', ['python3', 'tests/traceability-freeze-contract.tests.py'])
mutated = {}
for rel in TARGETS:
    path = WORK / rel
    path.write_bytes(path.read_bytes() + b'\nT002 disposable restoration sentinel\n')
    mutated[rel] = digest(path)
    assert mutated[rel] != before[rel]
(OUT / 'mutated-hashes.json').write_text(json.dumps(mutated, indent=2) + '\n')
for rel in TARGETS:
    shutil.copy2(BACKUP / rel, WORK / rel)
restored = {rel: digest(WORK / rel) for rel in TARGETS}
assert restored == before
(OUT / 'restored-hashes.json').write_text(json.dumps(restored, indent=2) + '\n')
run('restored-hash-parity', ['pwsh', '-NoProfile', '-File', 'tests/review-hash-normalization.tests.ps1'])
run('restored-traceability', ['python3', 'tests/traceability-freeze-contract.tests.py'])
run('restored-downstream-parity', ['bash', 'tests/downstream-review-precheck-parity.tests.sh'])
run('unreadable-equivalence', ['pwsh', '-NoProfile', '-File', str(HERE / 'unreadable-equivalence.ps1'),
    '-Root', str(WORK), '-FixtureDirectory', str(OUT / 'unreadable')])
assert {rel: digest(ROOT / rel) for rel in TARGETS} == before, 'owning candidate changed during fixture verification'
(OUT / 'scope-check.json').write_text(json.dumps({'owner_bytes_unchanged': True, 'restored_target_count': len(TARGETS),
    'kind': 'current dirty candidate restoration; not historical pre-fix RED or installed rollback'}, indent=2) + '\n')
print(OUT.relative_to(ROOT))
print('ok: 8 current dirty candidate targets restored exactly; before/after behavior and unreadable equivalence passed')
