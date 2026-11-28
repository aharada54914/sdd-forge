#!/usr/bin/env python3
"""The weekly registry proposal adds only newer versions of known families, from allowlisted tokens (ADR-0055)."""
import importlib.util
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'scripts/update-model-registry.py'
COPIED = ('contracts', 'plugins/sdd-implementation/contracts', 'scripts/render-model-routing-docs.py',
          'docs/agent-capability-matrix.md',
          'plugins/sdd-implementation/skills/implement-task/references/agent-delegation-policy.md',
          'plugins/sdd-bootstrap/agents/investigator.md', 'plugins/sdd-review-loop/agents/spec-reviewer-a.md',
          'plugins/sdd-quality-loop/agents/evaluator.md', 'plugins/sdd-domain/agents/domain-reviewer-a.md',
          'plugins/sdd-quality-loop/agents/wfi-auditor-a.md', 'scripts/update-model-registry.py')
PAGES = {
    'anthropic': ('<h1>Models</h1><table><tr><td><code>claude-opus-5-5</code></td></tr><tr><td><code>claude-haiku-6</code></td></tr>'
                  '<tr><td><code>claude-opus-4-8</code></td></tr><tr><td><code>claude-mythos-5-2</code></td></tr>'
                  '<tr><td><code>claude-opus-6-20270101</code></td></tr><tr><td><code>claude-sonnet-5-5</code></td></tr>'
                  '<tr><td><code>anthropic.claude-opus-9</code></td></tr><tr><td>claude-sonnet-8 (prose only)</td></tr></table>'
                  '<script>var x="`claude-sonnet-9`";</script><p>See <code>claude-haiku-5-5</code> and <code>claude-fable-5-2</code>.</p>'),
    'openai': ('<ul><li><code>gpt-6.2-sol</code></li><li><code>codex -m gpt-7-luna</code></li><li><code>gpt-7-nova</code></li>'
               '<li><code>gpt-6-luna</code></li><li><code>gpt-6.2-astra</code></li><li><code>gpt-6.1-terra</code></li>'
               '<li><code>gpt-6.1-sol</code></li><li><code>gpt-6-astra</code></li><li><code>gpt-9-sol</code></li></ul>'),
    'google': ('## Gemini 2.5 Flash-Lite  {% id="gemini-25-flash-lite" %}\n'
               '*Model code* **gemini-5-carbon**\n* `gemini-4-carbon`\n* `gemini-5-flash-preview`\n* `gemini-3.8-flash`\n'
               '* `gemini-4-neon`\n* `gemini-4-hydrogen`\n* `gemini-4-argon`\n* `gemini-3.5-flash-lite`\n'
               '[link](/docs/models/gemini-6-hydrogen)\n'),
}


def load_policy_helper():
    spec = importlib.util.spec_from_file_location('mp', ROOT / 'plugins/sdd-implementation/scripts/model-policy.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class RegistryUpdate(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name) / 'repo'
        for rel in COPIED:
            source, target = ROOT / rel, self.root / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            (shutil.copytree if source.is_dir() else shutil.copyfile)(source, target)
        self.pages = Path(self.tmp.name) / 'pages'
        self.pages.mkdir()
        for vendor, text in PAGES.items():
            (self.pages / (vendor + '.html')).write_text(text)

    def run_update(self, vendors=('anthropic', 'openai', 'google'), write=True):
        self.report = Path(self.tmp.name) / 'report.md'
        argv = [sys.executable, str(self.root / 'scripts/update-model-registry.py'), '--root', str(self.root),
                '--today', '2027-01-04T00:00:00Z', '--report', str(self.report)]
        for vendor in vendors:
            argv += ['--source', vendor + '=' + str(self.pages / (vendor + '.html'))]
        if write:
            argv.append('--write')
        result = subprocess.run(argv, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def contracts(self):
        registry = json.loads((self.root / 'contracts/agent-model-capabilities.v2.json').read_text())
        policy = json.loads((self.root / 'contracts/model-policy.v1.json').read_text())
        return {m['name']: m for m in registry['models']}, policy

    def test_adds_only_newer_versions_of_registered_families(self):
        summary = self.run_update()
        added = {a['id']: (a['tier'], a['family']) for a in summary['added']}
        self.assertEqual(added, {'anthropic/haiku-6': ('lightweight', 'haiku'), 'gpt-7-luna': ('lightweight', 'luna'),
                                 'google/gemini-5-carbon': ('strong', 'carbon')})
        self.assertIn('claude-opus-4-8', summary['older_or_listed'])
        for native in ('claude-mythos-5-2', 'gpt-7-nova', 'gemini-3.8-flash'):
            self.assertIn(native, summary['unclassified'])
        listed = json.dumps(summary)
        for never in ('claude-sonnet-9', 'claude-opus-6', 'claude-opus-9', 'claude-sonnet-8', 'gemini-5-flash-preview',
                      'gemini-25-flash-lite', 'gemini-6-hydrogen'):
            self.assertNotIn(never, listed)
        self.assertEqual(summary['suspicious'], ['gpt-9-sol'])
        body = self.report.read_text()
        self.assertIn('| `google/gemini-5-carbon` | `gemini-5-carbon` | strong | carbon |', body)
        self.assertIn('2世代以上の飛び越しとして保留した ID: `gpt-9-sol`', body)
        for never in ('prose only', 'var x', 'Models</h1>', 'Flash-Lite'):
            self.assertNotIn(never, body)
        registry, policy = self.contracts()
        models = {m['id']: m for m in policy['models']}
        self.assertEqual(registry['gpt-7-luna']['supported_efforts'], registry['gpt-6-luna']['supported_efforts'])
        self.assertEqual(models['anthropic/haiku-6']['hosts'], {'claude-code': 'claude-haiku-6'})
        self.assertEqual(models['anthropic/haiku-6']['successor_of'], ['anthropic/haiku-5-5'])
        self.assertEqual(models['google/gemini-5-carbon']['hosts'],
                         {'gemini-cli': 'gemini-5-carbon', 'antigravity-cli': 'gemini-5-carbon'})
        for model in ('anthropic/haiku-6', 'gpt-7-luna', 'google/gemini-5-carbon'):
            self.assertEqual((models[model]['lifecycle'], models[model]['adoption']), ('current', []))
        evaluator = policy['roles']['evaluator']['preferences']
        self.assertLess(evaluator.index('google/gemini-5-carbon'), evaluator.index('google/gemini-4-carbon'))
        self.assertNotIn('anthropic/haiku-6', evaluator)
        investigator = policy['roles']['investigator']['preferences']
        self.assertLess(investigator.index('anthropic/haiku-6'), investigator.index('anthropic/haiku-5-5'))
        self.assertEqual((self.root / 'plugins/sdd-implementation/contracts/agent-model-capabilities.v2.json').read_bytes(),
                         (self.root / 'contracts/agent-model-capabilities.v2.json').read_bytes())
        helper = load_policy_helper()
        reg, regmodels = helper._policy_registry(self.root / 'contracts/agent-model-capabilities.v2.json')
        token = helper._SNAPSHOT_ROOT.set(self.root)
        try:
            helper._validate_role_policy(policy, regmodels, reg['role_defaults'])
        finally:
            helper._SNAPSHOT_ROOT.reset(token)
        matrix = (self.root / 'docs/agent-capability-matrix.md').read_text()
        for native in ('claude-haiku-6', 'gpt-7-luna', 'gemini-5-carbon'):
            self.assertIn('`' + native + '`', matrix)
        check = subprocess.run([sys.executable, str(self.root / 'scripts/render-model-routing-docs.py'),
                                '--root', str(self.root), '--check'], capture_output=True, text=True)
        self.assertEqual(check.returncode, 0, check.stderr)

    def test_second_run_is_idempotent(self):
        self.run_update()
        before = {p: p.read_bytes() for p in self.root.rglob('*') if p.is_file()}
        summary = self.run_update()
        self.assertEqual(summary['added'], [])
        self.assertEqual({p: p.read_bytes() for p in self.root.rglob('*') if p.is_file()}, before)

    def test_unavailable_vendor_changes_nothing_for_it_and_reports_missing_models(self):
        summary = self.run_update(vendors=('openai',))
        self.assertEqual(sorted(summary['unavailable']), ['anthropic', 'google'])
        self.assertEqual([a['id'] for a in summary['added']], ['gpt-7-luna'])
        (self.pages / 'openai.html').write_text('<li>gpt-6.2-sol</li>')
        summary = self.run_update(vendors=('openai',), write=False)
        self.assertIn('gpt-6-luna', summary['not_seen'])
        registry, policy = self.contracts()
        self.assertEqual(next(m for m in policy['models'] if m['id'] == 'gpt-6-luna')['lifecycle'], 'current')

    def test_without_write_no_file_changes(self):
        before = {p: p.read_bytes() for p in self.root.rglob('*') if p.is_file()}
        summary = self.run_update(write=False)
        self.assertTrue(summary['added'])
        self.assertEqual({p: p.read_bytes() for p in self.root.rglob('*') if p.is_file()}, before)


if __name__ == '__main__':
    unittest.main()
