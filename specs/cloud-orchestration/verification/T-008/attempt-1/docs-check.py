"""Scoped documentation acceptance; no provider transport or release actions."""
from pathlib import Path
import re
import sys

root = Path(sys.argv[1]).resolve()
checks = {
    'README.md': ['sdd-azure-cloud', 'sdd-aws-cloud'],
    'docs/cloud-orchestration.md': ['CLOUD_SHARED_RUNTIME_ROOT', 'NO_CHANGE', 'UNKNOWN', 'max_age_seconds', 'sandbox-verify', 'dependency_request_sha256', '11.17.0', 'UNSAFE_ROOT'],
    'docs/workflow-guide.md': ['sandbox-prepare', 'sandbox-apply', 'UNKNOWN'],
    'docs/skill-reference.md': ['sdd-azure-cloud:orchestrate', 'sdd-aws-cloud:orchestrate'],
    'docs/contributor/skill-reference-detail.md': ['sdd-azure-cloud:orchestrate', 'sdd-aws-cloud:orchestrate'],
    'docs/architecture/overview.md': ['9 プラグイン', '29', 'cloud_dependencies'],
    'docs/adr/README.md': ['cloud-orchestration'],
    'docs/contributor/release-runbook.md': ['native-stderr.log', 'workflow_dispatch'],
    'docs/verification.md': ['cloud-orchestration', 'UNSAFE_ROOT'],
}
failures = []
for path, terms in checks.items():
    content = (root / path).read_text()
    for term in terms:
        if term not in content:
            failures.append(f'{path}: missing {term}')
    for target in re.findall(r'\]\(([^\s)]+)\)', content):
        if ':' in target or target.startswith('#') or '<' in target:
            continue
        target = target.split('#')[0]
        if target and not (root / path).parent.joinpath(target).exists():
            failures.append(f'{path}: unresolved relative link {target}')
for provider, ref in [('azure', 'local-contract'), ('aws', 'local-preparation')]:
    path = f'plugins/sdd-{provider}-cloud/references/{ref}.md'
    content = (root / path).read_text()
    for stale in ['This adapter is local-only', 'T-013 owns any later authorized publication']:
        if stale in content:
            failures.append(f'{path}: obsolete capability statement')
guide = (root / 'docs/cloud-orchestration.md').read_text()
if '--ref \"$W\"' in guide or '--ref \"$CONTROL_REF\"' not in guide:
    failures.append('dispatch selector must be CONTROL_REF, with exact W admission retained')
print('\n'.join(failures) if failures else 'PASS: documentation matrix and relative file links')
sys.exit(bool(failures))
