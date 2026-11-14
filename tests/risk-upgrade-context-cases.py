"""Bounded exclusions must not hide positive requirements or capability triggers."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument('--powershell')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
checker = root / 'plugins/sdd-lite/scripts/check-risk-upgrade'
command = ([args.powershell, '-NoProfile', '-File', str(checker.with_suffix('.ps1')), '-Path']
           if args.powershell else ['bash', str(checker.with_suffix('.sh'))])
meta = 'General authorization to create and test does not supply that task approval.'
cases = [
    ('generated exclusion', '## Scope exclusions\n- Accounts, authentication, server, sharing, sync, editing, priorities, drag and drop, deployment and remote publication.\n', 0),
    ('workflow metadata', '### Blockers\n- Human review is required. ' + meta, 0),
    ('combined input', '### Blockers\n- ' + meta + '\n# Requirements\n## Scope exclusions\n- authentication\n## Open Questions\nNone', 0),
    ('Japanese heading', '## スコープ外\n- oauth, tokens, secrets\n', 0),
    ('case CRLF', '## OUT OF SCOPE\r\n- AUTHENTICATION.\r\n', 0),
    ('indented code is not a heading', '    ## Scope exclusions\n    - authentication', 10),
    ('tabbed code is not a heading', '\t## Scope exclusions\n\t- authentication', 10),
    ('tilde code fence', '~~~markdown\n## Scope exclusions\n- authentication\n~~~', 10),
    ('ordinary feature requirement', 'Implement authentication.', 10),
    ('positive despite exclusion', '## Requirements\n- Implement authentication.\n## Scope exclusions\n- authentication', 10),
    ('positive after exclusion', '## Scope exclusions\n- authentication\n## Requirements\n- authentication', 10),
    ('verb in exclusion', '## Scope exclusions\n- implement authentication', 10),
    ('conditional negation', '## Scope exclusions\n- no authentication except OAuth login', 10),
    ('clause injection', '## Scope exclusions\n- authentication; implement it anyway', 10),
    ('prose contradicts list', '## Scope exclusions\n- authentication\nImplement the above anyway.', 10),
    ('unknown exclusion item', '## Scope exclusions\n- authentication, enable login', 10),
    ('not an exclusion heading', '## Scope exclusions and requirements\n- authentication', 10),
    ('code fence', '```markdown\n## Scope exclusions\n- authentication\n```', 10),
    ('short fence cannot close', '````\n```\n## Scope exclusions\n- authentication\n````', 10),
    ('fence trailing text cannot close', '```\n```not a close\n## Scope exclusions\n- authentication\n```', 10),
    ('metadata outside blockers', '## Requirements\n' + meta, 10),
    ('metadata plus real auth', '### Blockers\n- ' + meta + ' Implement authentication.', 10),
    ('nonmatching approval meaning', '### Blockers\n- General authorization to create and test requires OAuth login.', 10),
    ('unstructured negation remains conservative', 'No authentication is required.', 10),
    ('bounded design token baseline', 'Use design tokens for the UI.', 0),
    ('all excluded noun types', '## Out of scope\n- auth, passwords, mcp, external APIs, secrets and GitHub Actions.', 0),
    ('remaining actual trigger', '## Out of scope\n- authentication\n## Requirements\n- external API integration', 10),
]
with tempfile.TemporaryDirectory(prefix='sdd-risk-context-') as temp:
    source = Path(temp) / 'source.md'
    for label, body, expected in cases:
        source.write_text(body, encoding='utf-8')
        result = subprocess.run([*command, str(source)], capture_output=True, text=True, check=False)
        assert result.returncode == expected, (label, result.returncode, result.stdout, result.stderr)
        assert result.stdout.startswith('lite-eligible' if expected == 0 else 'full-required:'), (label, result.stdout)
        print('PASS:', label)
    source.write_text('## Scope exclusions\n- authentication\n', encoding='utf-8')
    fragment = Path(temp) / 'capabilities.json'
    fragment.write_text(json.dumps({'capabilities': [{'id': 'auth-service', 'eligible': False, 'upgrade_reasons': ['auth-required']}]}), encoding='utf-8')
    flag = '-CapabilityReasons' if args.powershell else '--capability-reasons'
    result = subprocess.run([*command, str(source), flag, str(fragment)], capture_output=True, text=True, check=False)
    assert result.returncode == 10 and 'auth-required' in result.stdout, result
    print('PASS: capability ineligibility cannot be suppressed')
print(f'{len(cases) + 1} checks passed')
