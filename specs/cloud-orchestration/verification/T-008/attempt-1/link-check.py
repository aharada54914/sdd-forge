"""Check relative file links in current operator surfaces, excluding vendored snapshots."""
from pathlib import Path
import re
import sys
from urllib.parse import unquote

root = Path(sys.argv[1]).resolve()
paths = [root / p for p in ['README.md', 'CHANGELOG.md', 'docs/cloud-orchestration.md',
    'docs/workflow-guide.md', 'docs/skill-reference.md', 'docs/contributor/skill-reference-detail.md',
    'docs/architecture/overview.md', 'docs/adr/README.md', 'docs/contributor/release-runbook.md',
    'docs/verification.md', 'docs/agent-capability-matrix.md']]
for provider in ('azure', 'aws'):
    base = root / f'plugins/sdd-{provider}-cloud'
    paths += list(base.glob('references/*.md')) + list(base.glob('scripts/*.md'))
    paths += list(base.glob('examples/**/*.md')) + list(base.glob('skills/*/SKILL.md'))
checked = 0
failures = []
for path in paths:
    content = re.sub(r'```.*?```', '', path.read_text(), flags=re.S)
    for target in re.findall(r'\]\(([^\s)]+)\)', content):
        if ':' in target or target.startswith('#') or '<' in target:
            continue
        relative = unquote(target.split('#')[0])
        if relative:
            checked += 1
            if not (path.parent / relative).exists():
                failures.append(f'{path.relative_to(root)}: missing {relative}')
print(f'Checked {checked} relative file links across {len(paths)} current documents; fragments/external URLs not validated')
print('\n'.join(failures) if failures else 'PASS')
sys.exit(bool(failures))
