"""Complete independent evidence after the retained minimal-fixture setup failure."""
import hashlib
import json
from pathlib import Path
import re
import subprocess

here = Path(__file__).resolve().parent
root = here.parents[3]
out = here / 'current-restoration-z04ertpw'
work = out / 'checkout'
before = json.loads((out / 'before-hashes.json').read_text())
digest = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
assert json.loads((out / 'restored-hashes.json').read_text()) == before
assert all(digest(root / p) == h and digest(work / p) == h for p, h in before.items())
argv = ['rtk', 'proxy', 'pwsh', '-NoProfile', '-File', str(here / 'unreadable-equivalence.ps1'),
        '-Root', str(work), '-FixtureDirectory', str(out / 'unreadable')]
result = subprocess.run(argv, cwd=root, text=True, capture_output=True)
(out / 'unreadable-equivalence.log').write_text(result.stdout + result.stderr)
assert result.returncode == 0, result.stderr
recipe = (root / 'tests/review-hash-normalization.tests.ps1').read_text()
recipe = re.search(r'function Get-BaselineReviewedHash\([^\n]+\) \{\n.*?^\}', recipe, re.M | re.S).group()
recipe = recipe.replace('Get-BaselineReviewedHash', 'Get-ReviewedHash')
comparisons = {}
for stage in ['impl', 'task']:
    path = f'plugins/sdd-review-loop/scripts/{stage}-review-precheck.ps1'
    cmd = ['rtk', 'proxy', 'git', 'show', f'9ce19abe90df0cb83e385f96855e4843318a8807:{path}']
    old = subprocess.run(cmd, cwd=root, text=True, capture_output=True, check=True).stdout
    old_recipe = re.search(r'function Get-ReviewedHash\([^\n]+\) \{\n.*?^\}', old, re.M | re.S).group()
    comparisons[path] = old_recipe == recipe
assert all(comparisons.values()), comparisons
assert all(digest(root / p) == h and digest(work / p) == h for p, h in before.items())
(out / 'independent-checks.json').write_text(json.dumps({
    'unreadable_command': argv, 'unreadable_exit_code': result.returncode,
    'owner_bytes_unchanged': True, 'restored_target_count': len(before),
    'baseline_recipe_exact_match_at_head': comparisons,
    'kind': 'current dirty candidate restoration and pre-extraction recipe equivalence',
    'not_claimed': ['historical pre-fix RED', 'installed baseline rollback', 'formal gate PASS'],
    'downstream_fixture_result': 'retained exit 1: missing unrelated registry directories; not product regression proof'
}, indent=2) + '\n')
print('ok: unreadable equivalence, exact baseline recipe identity, eight restored and owner hashes unchanged')
