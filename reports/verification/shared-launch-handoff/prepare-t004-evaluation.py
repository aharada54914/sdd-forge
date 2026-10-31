"""Prepare pinned T-004 delivery inputs; never reserve or change task state."""
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import uuid

root = Path(__file__).resolve().parents[3]
public = Path('/tmp/sdd-shared-launch-public-20261011')
head = 'be9c13829581cf5e80ed8abcece74a718eadf14c'
base = '0b2951b6855bbd136938fafa901ee8af8bbe4855'
feature = 'shared-review-launch-repair'
task = 'T-004'
report = f'reports/implementation/{feature}/{task}.md'
implementation = f'handoffs/{feature}-{task}-attempt-1/manifest.json'

def digest(path):
    assert path.is_file() and not path.is_symlink(), path
    return hashlib.sha256(path.read_bytes()).hexdigest()

def command(*args):
    return subprocess.check_output(['rtk', 'proxy', *args], cwd=public)

assert digest(root / report) == '266f4c37db646ba7eee2e5719a68e9b26df89a4b6c108f3175ee8f87825f0e5c'
assert digest(root / implementation) == '565e5fcccf4b60629d24aad73a3d246c9e69b036a634829c211be63c68688a90'
for revision in (base, head):
    assert command('git', 'rev-parse', '--verify', f'{revision}^{{commit}}').decode().strip() == revision
ci = json.loads(command('gh', 'run', 'view', '38150318997', '--repo',
                        'aharada54914/sdd-forge', '--json', 'headSha,status,conclusion,url,jobs'))
assert ci['headSha'] == head and ci['status'] == 'completed' and ci['conclusion'] == 'success'
assert len(ci['jobs']) == 37 and all(j['conclusion'] == 'success' for j in ci['jobs'])
pr = json.loads(command('gh', 'pr', 'view', '558', '--repo',
                        'aharada54914/sdd-forge', '--json', 'state,headRefOid,mergeCommit,mergedAt,url'))
merge = '9b16ffba39a090cd3cf2305e986341e24096b835'
assert pr['state'] == 'MERGED' and pr['headRefOid'] == head and pr['mergedAt']
assert pr['mergeCommit']['oid'] == merge
post_ci = json.loads(command('gh', 'run', 'view', '38185550821', '--repo',
                            'aharada54914/sdd-forge', '--json', 'headSha,status,conclusion,url,jobs'))
assert post_ci['headSha'] == merge
assert post_ci['status'] == 'completed' and post_ci['conclusion'] == 'success', 'post-merge CI not successful'
assert len(post_ci['jobs']) == 37 and all(j['conclusion'] == 'success' for j in post_ci['jobs'])
entries = {}
for name in ('requirements', 'acceptance-tests', 'design', 'tasks', 'traceability',
             'ux-spec', 'frontend-spec', 'infra-spec', 'security-spec', 'baseline-behavior', 'authority'):
    path = f'specs/{feature}/{name}.md'
    if (root / path).exists():
        entries[path] = digest(root / path)
for path in (report, implementation, 'plugins/sdd-quality-loop/references/quality-gate-calibration.md'):
    entries[path] = digest(root / path)
outputs = (root / report).read_text().split('## Outputs\n', 1)[1].split('\n## ', 1)[0]
pairs = re.findall(r'\| `([^`]+)` \| `([0-9a-f]{64})` \|', outputs)
assert len(pairs) == len(dict(pairs)) == 27
for path, expected in pairs:
    assert not Path(path).is_absolute() and '..' not in Path(path).parts
    # The later workflow revision is supplied separately, not relabelled as the old output.
    if path != '.github/workflows/test.yml':
        assert digest(root / path) == expected, path
        entries[path] = expected
dependencies = {}
for entry in json.loads((root / implementation).read_bytes())['allowed_inputs']:
    path = entry['path']
    if path.startswith('reports/') or (path.startswith('specs/') and not path.startswith(f'specs/{feature}/')):
        continue
    dependencies[path] = digest(root / path)
for suffix in ('public-ci-delivery-20261011.md', 'public-e97-delivery-20261011.md',
               'public-2f1-delivery-20261011.md',
               'premerge-authority-20261011.md',
               'current-delivery-20261012.md',
               'combined-rollback-20261011/combined-summary.json'):
    path = f'specs/{feature}/verification/{task}/{suffix}'
    dependencies[path] = digest(root / path)

identity = str(uuid.uuid4())
bundle = root / f'specs/{feature}/verification/{task}/delivery-{identity}'
bundle.mkdir()
projection = []
def forbidden_review_output(path):
    return bool(re.search(r'^reports/(spec|impl|task)-review/.*/reviewer-[^/]*\.json$|(^|/)reviewer-[ab]\.json$', path))

assert forbidden_review_output('reports/impl-review/feature/attempt-1/round-1/reviewer-a.json')
assert forbidden_review_output('nested/reviewer-b.json')
assert not forbidden_review_output('reports/impl-review/feature/attempt-1/round-1/summary.json')
assert not forbidden_review_output('plugins/reviewer-helper.py')
deleted = command('git', 'diff', '--no-renames', '--name-only', '--diff-filter=D', '-z', base, head).decode().split('\0')
paths = command('git', 'diff', '--no-renames', '--name-only', '--diff-filter=ACMRT', '-z', base, head).decode().split('\0')
for path in filter(None, paths):
    assert not Path(path).is_absolute() and '..' not in Path(path).parts
    source = command('git', 'show', f'{head}:{path}')
    if forbidden_review_output(path):
        projection.append({'source_path': path, 'git_blob_oid': command('git', 'rev-parse', f'{head}:{path}').decode().strip(),
                           'omitted_reason': 'Raw reviewer output excluded to preserve evaluator independence.'})
        continue
    target = bundle / 'public-source' / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(source)
    name = target.relative_to(root).as_posix()
    dependencies[name] = digest(target)
    projection.append({'source_path': path, 'admitted_path': name, 'sha256': dependencies[name]})
ci_summary = {key: ci[key] for key in ('headSha', 'status', 'conclusion', 'url')}
ci_summary['jobs'] = [{key: job[key] for key in ('name', 'conclusion', 'completedAt', 'url')}
                      for job in ci['jobs']]
for name, document in [('ci.json', ci), ('ci-summary.json', ci_summary),
                       ('merged-pr.json', pr), ('post-merge-ci.json', post_ci), ('projection.json', {
        'head': head, 'base': base, 'purpose': 'Exact public changed files; owner inputs are separate, not asserted identical.',
        'deleted_paths': list(filter(None, deleted)), 'artifacts': projection})]:
    target = bundle / name
    target.write_text(json.dumps(document, indent=2) + '\n')
    dependencies[target.relative_to(root).as_posix()] = digest(target)
proof_helper = Path(__file__).with_name('public-git-evidence.py')
proof_spec = importlib.util.spec_from_file_location('public_git_evidence', proof_helper)
proof = importlib.util.module_from_spec(proof_spec)
proof_spec.loader.exec_module(proof)
projection_document = json.loads((bundle / 'projection.json').read_bytes())
git_evidence = proof.collect(public, projection_document)
proof.verify(root, projection_document, git_evidence, base, head)
for target in proof.write_bundle(bundle, git_evidence):
    dependencies[target.relative_to(root).as_posix()] = digest(target)
assert proof.read_bundle(bundle) == git_evidence
target = bundle / proof_helper.name
shutil.copy2(proof_helper, target)
dependencies[target.relative_to(root).as_posix()] = digest(target)
declaration = bundle / 'declaration.json'
declaration.write_text(json.dumps({'schema': 'supplemental-delivery-declaration/v2', 'feature': feature,
    'task_id': task, 'implementation_report': {'path': report, 'sha256': entries[report]},
    'implementation_manifest': {'path': implementation, 'sha256': entries[implementation]},
    'artifacts': [{'path': p, 'sha256': h} for p, h in dependencies.items()]}, indent=2) + '\n')
pointer = {'path': declaration.relative_to(root).as_posix(), 'sha256': digest(declaration)}
entries.update(dependencies)
entries[pointer['path']] = pointer['sha256']
scratch = Path(tempfile.mkdtemp(prefix='sdd-t004-evaluator-')).resolve(strict=True)
for path, expected in entries.items():
    assert digest(root / path) == expected, path
    target = scratch / path
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(root / path, target)
    assert digest(target) == expected, path
ledger_path = 'reports/review-context/identity-ledger.json'
ledger = (root / ledger_path).read_bytes()
tip = json.loads(ledger)['records'][-1]
invocation = {'schema': 'review-context-invocation/v2', 'input_mode': 'file-manifest',
    'fallback_mode': 'none', 'read_only': True, 'feature': feature, 'stage': 'quality',
    'role': 'sdd-evaluator', 'task_id': task, 'run_id': identity, 'host_session_id': identity,
    'identity_ledger_path': ledger_path, 'identity_ledger_sha256': hashlib.sha256(ledger).hexdigest(),
    'sequence': tip['sequence'] + 1, 'previous_record_sha256': tip['record_sha256'],
    'implementation_manifest': {'path': implementation, 'sha256': entries[implementation]},
    'scratch_root': str(scratch), 'allowed_input_manifest': [{'path': p, 'sha256': h} for p, h in entries.items()],
    'supplemental_delivery_declaration': pointer}
target = bundle / 'invocation.json'
target.write_text(json.dumps(invocation, indent=2) + '\n')
spec = importlib.util.spec_from_file_location('delivery', root / 'plugins/sdd-quality-loop/scripts/supplemental-delivery-inputs.py')
delivery = importlib.util.module_from_spec(spec)
spec.loader.exec_module(delivery)
delivery.resolve(root, target)
assert (root / ledger_path).read_bytes() == ledger, 'ledger changed; discard unreserved preparation'
print(json.dumps({'invocation': str(target), 'sha256': digest(target), 'scratch': str(scratch),
    'inputs': len(entries), 'public_files': len(projection), 'output': str(root / f'reports/quality-gate/launch-{identity}'),
    'reservation': 'NOT PERFORMED'}))
