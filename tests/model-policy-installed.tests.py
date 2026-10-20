#!/usr/bin/env python3
"""T-008 renderer slice; installed adapter/caller/native acceptance remains separate.

Proposed public surface (requires primary admission before product work):
  bash  render-agent-frontmatter.sh --model-controls FILE --model-controls-sha256 SHA --run-id ID
        --session-id ID --managed-target RELPATH [--root DIR] [--check]
  pwsh  render-agent-frontmatter.ps1 -ModelControls FILE -ModelControlsSha256 SHA -RunId ID
        -SessionId ID -ManagedTarget RELPATH [-RepoRoot DIR] [-Check]
Without these flags the legacy renderer contract (reference comments, epic-159 staging) is unchanged.

Oracle: the passed T-007 launch-controls validation (real helper CLI) over a real selector selection,
reused through the T-007 LaunchFixture, plus T-007's trusted role frontmatter alignment. Evidence
class: FIXTURE ONLY. Selections use verified-configuration fixture observations and fixture adoption
files; no live discovery, native model execution or paid run happens (PATH shims record any native
invocation). This slice proves rendering only; installed/native entry proof remains outstanding.

PowerShell uses the official development-environment binary where present, otherwise
SDD_TEST_PWSH or pwsh on PATH. Both shells are required; absence is a setup failure.
"""
import copy
import hashlib
import importlib.util
import os
from pathlib import Path
import re
import shutil
import sys
import tomllib
from typing import TYPE_CHECKING
import unittest

ROOT = Path(__file__).resolve().parents[1]
_SPEC = importlib.util.spec_from_file_location('t008_launch_fixture', ROOT / 'tests/model-policy-launch.tests.py')
assert _SPEC is not None and _SPEC.loader is not None
launch = importlib.util.module_from_spec(_SPEC)
sys.modules[_SPEC.name] = launch
_SPEC.loader.exec_module(launch)
if TYPE_CHECKING:
    from typing import Any as LaunchFixture
else:
    LaunchFixture = launch.LaunchFixture

WORKSPACE_PWSH = '/workspace/.tools/sdd-forge-dev/bin/pwsh'
PWSH = (WORKSPACE_PWSH if os.access(WORKSPACE_PWSH, os.X_OK)
        else os.environ.get('SDD_TEST_PWSH') or shutil.which('pwsh'))
SHELLS = ('bash', 'pwsh')
FROZEN = 'specs/epic-159-pillar-c/human-copy'
CURRENT = 'specs/ci-model-modernization/verification/T-008/current-human-copy'
ADAPTER = 'plugins/sdd-implementation/scripts/managed-model-entry.py'
PROTECTED_SKILLS = ('plugins/sdd-review-loop/skills/impl-review-loop/SKILL.md',
                    'plugins/sdd-review-loop/skills/task-review-loop/SKILL.md')
RUNTIME_TOML = ('model', 'model_reasoning_effort')
# Managed target -> policy role. The host follows the file family and must equal the bound controls.
CLAUDE = {
    'plugins/sdd-quality-loop/agents/evaluator.md': 'evaluator',
    'plugins/sdd-bootstrap/agents/investigator.md': 'investigator',
    'plugins/sdd-review-loop/agents/spec-reviewer-a.md': 'spec-reviewer-a',
    'plugins/sdd-review-loop/agents/spec-reviewer-b.md': 'spec-reviewer-b',
    'plugins/sdd-domain/agents/domain-reviewer-a.md': 'domain-reviewer-a',
    'plugins/sdd-domain/agents/domain-reviewer-b.md': 'domain-reviewer-b',
    'plugins/sdd-quality-loop/agents/wfi-auditor-a.md': 'workflow-auditor-a',
    'plugins/sdd-quality-loop/agents/wfi-auditor-b.md': 'workflow-auditor-b',
}
CODEX = {'.codex/agents/sdd-evaluator.toml': 'evaluator', '.codex/agents/sdd-investigator.toml': 'investigator'}
COPILOT = {'plugins/sdd-quality-loop/copilot-agents/sdd-evaluator.agent.md': 'evaluator',
           'plugins/sdd-bootstrap/copilot-agents/sdd-investigator.agent.md': 'investigator'}
PROTECTED = {'plugins/sdd-review-loop/agents/' + name + '.md': name
             for name in ('impl-reviewer-a', 'impl-reviewer-b', 'task-reviewer-a', 'task-reviewer-b')}
TARGETS = {**CLAUDE, **CODEX, **COPILOT, **PROTECTED}


def frontmatter(text):
    """Top-level `key: value` frontmatter lines and the body without x-sdd reference comments."""
    lines = text.split('\n')
    end = lines.index('---', 1) if lines[:1] == ['---'] and '---' in lines[1:] else 0
    keys = {}
    for line in lines[1:end]:
        match = re.match(r'([A-Za-z][A-Za-z0-9_-]*):(.*)$', line)
        if match:
            keys[match.group(1)] = match.group(2).strip()
    return keys, [line for line in lines[end + 1:] if not line.startswith('<!-- x-sdd-')]


def tree(root):
    return {p.relative_to(root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in root.rglob('*') if p.is_file() and not p.is_symlink()}


class ManagedFixture(LaunchFixture):
    """T-007 LaunchFixture plus copied renderers, current role files and the frozen epic-159 copy."""
    host = launch.HOST

    def setUp(self):
        self.assertTrue(PWSH and os.access(PWSH, os.X_OK), 'PowerShell is required; fixture setup failure')
        super().setUp()
        copilot = self.base / 'shims' / 'copilot'
        copilot.write_text('#!/bin/sh\necho "$0 $*" >> "' + str(self.marker) + '"\nexit 97\n')
        copilot.chmod(0o755)
        # New adapter absence is product RED, never a copy-time setup exception.
        copied = [ADAPTER] if (ROOT / ADAPTER).is_file() else []
        for rel in ('render-agent-frontmatter.sh', 'render-agent-frontmatter.ps1', *TARGETS, *PROTECTED_SKILLS, *copied):
            (self.root / rel).parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / rel, self.root / rel)
        if (ROOT / FROZEN).is_dir():
            shutil.copytree(ROOT / FROZEN, self.root / FROZEN)
        else:  # stand-in only when the frozen copy is absent; it must never change either
            (self.root / FROZEN).mkdir(parents=True)
            (self.root / FROZEN / 'MANIFEST.sha256').write_text('0' * 64 + '  frozen-fixture-sentinel\n')
        self.originals = {rel: (self.root / rel).read_bytes() for rel in TARGETS}
        self.transport = launch.load_module(launch.TRANSPORT_SCRIPT, 'transport')
        self.addCleanup(sys.modules.pop, self.transport.__name__, None)

    def bind(self, role, *, budget=False):
        """Real selector selection accepted by the real T-007 launch-controls CLI; returns its resolution."""
        self.observation = self.fresh_observation()
        self.request = self.fresh_request(role)
        self.request['host'] = self.host
        if budget:
            self.request['budget'] = {'amount': 2, 'unit': 'USD'}
            self.request['estimates'] = [{'catalog_id': 'anthropic/opus', 'amount': 1, 'unit': 'USD',
                                         'source_url': 'https://example.invalid/fixture-price',
                                         'source_date': '2026-10-18T00:00:00Z'}]
        selection, result = self.try_select()
        self.assertIsNotNone(selection, 'fixture selection failed (setup, not T-008 RED): ' + result.stderr[:800])
        self.assertEqual(self.observation['source'], 'verified-configuration', 'fixture evidence only')
        trusted = next(m for m in self.trusted_policy['models'] if m['id'] == selection['resolved']['catalog_id'])
        self.assertEqual(selection['resolved']['native_id'], trusted['hosts'][self.host], 'trusted mapping only')
        self.write('selection.json', selection)
        self.selection = selection
        self.sha = self.controls(mutate=lambda document: document.update(host=self.host))
        return self.accepted(self.cli(sha=self.sha, host=self.host))['selection']['resolved']

    def native(self, model):
        return self.cli(sha=self.sha, host=self.host, native=model)

    def render(self, shell, target=None, *, check=False, legacy=False, omit=None, extra=()):
        script = str(self.root / ('render-agent-frontmatter.' + ('sh' if shell == 'bash' else 'ps1')))
        if shell == 'bash':
            command = [launch.BASH, script, '--root', str(self.root)]
            if not legacy:
                command += ['--model-controls', 'controls.json', '--model-controls-sha256', self.sha,
                            '--run-id', self.run_id, '--session-id', self.session_id, '--managed-target', target]
            command += ['--check'] if check else []
        else:
            command = [PWSH, '-NoProfile', '-File', script, '-RepoRoot', str(self.root)]
            if not legacy:
                command += ['-ModelControls', 'controls.json', '-ModelControlsSha256', self.sha,
                            '-RunId', self.run_id, '-SessionId', self.session_id, '-ManagedTarget', target]
            command += ['-Check'] if check else []
        if omit:
            index = command.index(omit)
            del command[index:index + 2]
        command.extend(extra)
        result = self.run_process(command, timeout=120, label=shell + ' renderer')
        self.assertFalse(self.marker.exists(), 'the renderer invoked a native model executable')
        return result

    def restore(self, *rels):
        for rel in rels:
            (self.root / rel).write_bytes(self.originals[rel])

    def text(self, rel):
        return (self.root / rel).read_text(encoding='utf-8')

    def assert_drift(self, shell, rel):
        before = tree(self.root)
        check = self.render(shell, rel, check=True)
        self.assertEqual((check.returncode, 'DRIFT' in check.stdout), (1, True), check.stdout + check.stderr[-800:])
        self.assertEqual(tree(self.root), before, 'managed --check must never write anywhere')

    def assert_rendered(self, shell, rel):
        self.assert_drift(shell, rel)
        result = self.render(shell, rel)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr[-1500:])
        self.assertEqual(self.render(shell, rel, check=True).returncode, 0, 'rendered target must be drift-free')

    def toml(self, rel):
        try:
            return tomllib.loads(self.text(rel))
        except tomllib.TOMLDecodeError as error:
            self.fail(rel + ' is not valid TOML: ' + str(error))


class ManagedClaudeRoles(ManagedFixture):

    def test_frontmatter_runtime_fields_follow_bound_selection_for_each_role(self):
        # TEST-134/135/139/144/145 renderer portion and TEST-096/162 alignment through generated files.
        for rel, role in CLAUDE.items():
            resolved = self.bind(role)
            self.assertEqual(resolved['effort_control'], 'frontmatter')
            old, old_body = frontmatter(self.originals[rel].decode('utf-8'))
            for shell in SHELLS:
                with self.subTest(target=rel, shell=shell):
                    self.restore(rel)
                    self.assert_rendered(shell, rel)
                    new, body = frontmatter(self.text(rel))
                    self.assertEqual(new.get('model'), resolved['native_id'])
                    self.assertEqual(new.get('effort'), resolved['effort'])
                    alignment = self.transport.role_frontmatter_alignment(
                        self.text(rel).split('---', 2)[1], resolved['native_id'], resolved['effort'])
                    self.assertEqual(alignment, 'matching', 'T-007 trusted alignment must see the selection')
                    self.assertEqual({k: v for k, v in new.items() if k not in ('model', 'effort')},
                                     {k: v for k, v in old.items() if k not in ('model', 'effort')},
                                     'identity, tools and permissions are preserved')
                    self.assertEqual(body, old_body)
                    self.accepted(self.native(new['model']))
                    if old['model'] != resolved['native_id']:
                        self.rejected(self.native(old['model']), 'native-precedence-conflict')

    def test_effort_reference_comment_alone_is_runtime_drift(self):  # TEST-120 (Claude carrier)
        rel = 'plugins/sdd-quality-loop/agents/evaluator.md'
        resolved = self.bind('evaluator')
        lines = [line for line in self.originals[rel].decode('utf-8').split('\n')
                 if not line.startswith(('model:', 'effort:', '<!-- x-sdd-effort:'))]
        close = lines.index('---', 1)
        lines[close:close + 1] = ['model: ' + resolved['native_id'], '---',
                                  '<!-- x-sdd-effort: ' + resolved['effort'] + ' -->']
        mutated = '\n'.join(lines)
        self.assertEqual(self.transport.role_frontmatter_alignment(
            mutated.split('---', 2)[1], resolved['native_id'], resolved['effort']), 'generated')
        for shell in SHELLS:
            with self.subTest(shell=shell):
                self.restore(rel)
                self.assertEqual(self.render(shell, rel).returncode, 0)
                self.assertEqual(self.render(shell, rel, check=True).returncode, 0)
                (self.root / rel).write_text(mutated, encoding='utf-8')
                self.assert_drift(shell, rel)
                self.assertEqual(self.render(shell, rel).returncode, 0)
                self.assertEqual(self.render(shell, rel, check=True).returncode, 0)
                stale_effort = 'low' if resolved['effort'] != 'low' else 'high'
                stale = re.sub(r'(?m)^effort:.*$', 'effort: ' + stale_effort, self.text(rel))
                (self.root / rel).write_text(stale, encoding='utf-8')
                self.assert_drift(shell, rel)

    def test_paired_roles_bind_independently(self):  # TEST-134/144 domain, TEST-135/145 auditors
        pairs = [(a, a[:-4] + 'b.md') for a in CLAUDE if a.endswith(('domain-reviewer-a.md', 'wfi-auditor-a.md'))]
        self.assertEqual(len(pairs), 2)
        for a, b in pairs:
            for shell in SHELLS:
                with self.subTest(pair=a, shell=shell):
                    self.restore(a, b)
                    self.bind(CLAUDE[a])
                    self.assertEqual(self.render(shell, a).returncode, 0,
                                     'positive A render required before crossed controls')
                    crossed = self.render(shell, b)
                    self.rejected(crossed, launch.MISMATCH)
                    self.assertEqual((self.root / b).read_bytes(), self.originals[b])
                    self.assertEqual(self.render(shell, a).returncode, 0)
                    rendered_a = (self.root / a).read_bytes()
                    resolved_b = self.bind(CLAUDE[b])
                    self.assertEqual(self.render(shell, b).returncode, 0)
                    self.assertEqual(frontmatter(self.text(b))[0].get('model'), resolved_b['native_id'])
                    self.assertEqual((self.root / a).read_bytes(), rendered_a, 'B render must not touch A')

    def test_copilot_agents_reject_cross_host_selection(self):  # TEST-118 current unsupported branch
        self.assertFalse([m['id'] for m in self.trusted_policy['models'] if 'copilot-cli' in m['hosts']],
                         'a trusted Copilot mapping exists now: replace this branch with a precedence test')
        for rel, role in COPILOT.items():
            self.bind(role)  # a valid claude-code selection must not be transplanted into a Copilot agent
            for shell in SHELLS:
                with self.subTest(target=rel, shell=shell):
                    counterpart = next(p for p, r in CLAUDE.items() if r == role)
                    self.assertEqual(self.render(shell, counterpart).returncode, 0,
                                     'positive same-host render required before unsupported target')
                    before = tree(self.root)
                    result = self.render(shell, rel)
                    self.rejected(result, {'config-conflict', 'model-unavailable', 'discovery-unavailable'})
                    self.assertEqual(tree(self.root), before)

    def test_protected_reviewers_stage_exact_current_copy_and_raw_pin(self):
        for rel, role in PROTECTED.items():
            resolved = self.bind(role)
            for shell in SHELLS:
                with self.subTest(target=rel, shell=shell):
                    staged = self.root / CURRENT / rel
                    manifest = self.root / CURRENT / 'MANIFEST.sha256'
                    self.assert_drift(shell, rel)
                    before = tree(self.root)
                    result = self.render(shell, rel)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr[-800:])
                    self.assertIn('STAGED:', result.stdout)
                    after = tree(self.root)
                    self.assertEqual({k: after.get(k) for k in before}, before,
                                     'live protected roles/skills and frozen human-copy must be unchanged')
                    self.assertEqual(set(after) - set(before), {CURRENT + '/' + rel, CURRENT + '/MANIFEST.sha256'})
                    fields, body = frontmatter(staged.read_text(encoding='utf-8'))
                    old, old_body = frontmatter(self.originals[rel].decode('utf-8'))
                    self.assertEqual((fields.get('model'), fields.get('effort')),
                                     (resolved['native_id'], resolved['effort']))
                    self.assertEqual({k: v for k, v in fields.items() if k not in ('model', 'effort')},
                                     {k: v for k, v in old.items() if k not in ('model', 'effort')})
                    self.assertEqual(body, old_body)
                    self.assertEqual(manifest.read_text(), hashlib.sha256(staged.read_bytes()).hexdigest() + '  ' + rel + '\n')
                    clean = tree(self.root)
                    self.assertEqual(self.render(shell, rel, check=True).returncode, 0)
                    self.assertEqual(tree(self.root), clean)
                    # Native staged effort drift and manifest-only corruption must both be detected.
                    raw = staged.read_bytes()
                    self.assertNotEqual(resolved['effort'], 'low')
                    staged.write_text(re.sub(r'(?m)^effort:.*$', 'effort: low', raw.decode('utf-8')))
                    self.assert_drift(shell, rel)
                    staged.write_bytes(raw)
                    manifest.write_text('0' * 64 + '  ' + rel + '\n')
                    self.assert_drift(shell, rel)
                    manifest.write_text(hashlib.sha256(raw).hexdigest() + '  ' + rel.upper() + '\n')
                    self.assert_drift(shell, rel)
                    staged.unlink()
                    manifest.unlink()
        for shell in SHELLS:
            with self.subTest(shell=shell, case='manifest-upsert-and-idempotence'):
                expected = {}
                for rel in list(PROTECTED)[:2]:
                    self.bind(PROTECTED[rel])
                    self.assertEqual(self.render(shell, rel).returncode, 0)
                    staged = self.root / CURRENT / rel
                    self.assertTrue(staged.is_file(), 'managed render did not create the protected proposal')
                    expected[rel] = hashlib.sha256(staged.read_bytes()).hexdigest()
                    manifest = self.root / CURRENT / 'MANIFEST.sha256'
                    self.assertTrue(manifest.is_file(), 'managed render did not create the current manifest')
                    entries = [line.split('  ', 1) for line in manifest.read_text().splitlines()]
                    self.assertEqual(len(entries), len(expected), 'no duplicate manifest entries')
                    self.assertEqual({path: digest for digest, path in entries}, expected)
                    before = tree(self.root)
                    self.assertEqual(self.render(shell, rel).returncode, 0)
                    self.assertEqual(self.render(shell, rel, check=True).returncode, 0)
                    self.assertEqual(tree(self.root), before, 'repeated render is byte-idempotent')
                for rel in expected:
                    self.assertTrue((self.root / CURRENT / rel).is_file(), 'existing protected proposal was removed')
                    self.assertEqual(hashlib.sha256((self.root / CURRENT / rel).read_bytes()).hexdigest(),
                                     expected[rel], 'staging another role preserves the existing proposal')
                    (self.root / CURRENT / rel).unlink()
                manifest.unlink()

    def test_managed_controls_reject_each_field_mismatch(self):
        rel = 'plugins/sdd-quality-loop/agents/evaluator.md'
        self.bind('evaluator', budget=True)
        # Include allocated identity and non-null budget/estimate fields in the matrix.
        bound = self.accepted(self.cli(sha=self.sha))['selection']
        self.write('selection.json', bound)
        self.sha = self.controls()
        controls = copy.deepcopy(self.controls_doc)
        for shell in SHELLS:
            with self.subTest(shell=shell):
                for document_name, baseline in [('controls.json', controls), ('selection.json', bound)]:
                    for path in launch.leaf_paths(baseline):
                        with self.subTest(document=document_name, field='/'.join(map(str, path))):
                            self.write('selection.json', bound)
                            self.sha = self.write('controls.json', controls)
                            self.assertEqual(self.render(shell, rel).returncode, 0,
                                             'positive managed render required before mismatch')
                            changed = copy.deepcopy(baseline)
                            launch.set_path(changed, path, launch.altered(launch.get_path(changed, path)))
                            if document_name == 'selection.json':
                                if path != ('selection_sha256',):
                                    changed['selection_sha256'] = launch.digest(changed, 'selection_sha256')
                                self.write('selection.json', changed)
                                self.sha = self.controls()
                            else:
                                self.sha = self.write('controls.json', changed)
                            before = tree(self.root)
                            self.rejected(self.render(shell, rel), launch.REASONS)
                            self.assertEqual(tree(self.root), before, 'invalid controls must write nothing')
                self.write('selection.json', bound)
                self.sha = self.write('controls.json', controls)
                self.assertEqual(self.render(shell, rel).returncode, 0)
                self.sha = launch.flip(self.sha)
                before = tree(self.root)
                self.rejected(self.render(shell, rel), 'input-invalid')
                self.assertEqual(tree(self.root), before)

    def test_partial_mixed_and_mis_cased_managed_inputs_are_typed_rejections(self):
        rel = 'plugins/sdd-quality-loop/agents/evaluator.md'
        self.bind('evaluator')
        flags = {'bash': ['--model-controls', '--model-controls-sha256', '--run-id', '--session-id', '--managed-target'],
                 'pwsh': ['-ModelControls', '-ModelControlsSha256', '-RunId', '-SessionId', '-ManagedTarget']}
        mixed = {'bash': [('--registry', 'registry.json'), ('--targets-file', 'targets.json'),
                          ('--resolve-target-raw', rel, '0')],
                 'pwsh': [('-Registry', 'registry.json'), ('-TargetsFile', 'targets.json'),
                          ('-ResolveTargetRawPath', rel, '-ResolveTargetRawProtected', '0')]}
        for shell in SHELLS:
            for omitted in flags[shell]:
                with self.subTest(shell=shell, omitted=omitted):
                    self.assertEqual(self.render(shell, rel).returncode, 0)
                    before = tree(self.root)
                    self.rejected(self.render(shell, rel, omit=omitted), launch.MISMATCH)
                    self.assertEqual(tree(self.root), before)
            for extra in mixed[shell]:
                with self.subTest(shell=shell, mixed=extra[0]):
                    self.assertEqual(self.render(shell, rel).returncode, 0)
                    before = tree(self.root)
                    self.rejected(self.render(shell, rel, extra=extra), launch.MISMATCH)
                    self.assertEqual(tree(self.root), before)
            with self.subTest(shell=shell, case='target'):
                self.assertEqual(self.render(shell, rel).returncode, 0)
                before = tree(self.root)
                self.rejected(self.render(shell, rel.upper()), launch.MISMATCH)
                self.assertEqual(tree(self.root), before)
            with self.subTest(shell=shell, case='role'):
                self.assertEqual(self.render(shell, rel).returncode, 0)
                controls = copy.deepcopy(self.controls_doc)
                controls['role'] = controls['role'].upper()
                good = (self.root / 'controls.json').read_bytes()
                self.sha = self.write('controls.json', controls)
                before = tree(self.root)
                self.rejected(self.render(shell, rel), launch.MISMATCH)
                self.assertEqual(tree(self.root), before)
                (self.root / 'controls.json').write_bytes(good)
                self.sha = launch.sha_bytes(good)

    def test_managed_target_rejects_escape_alias_and_symlink(self):
        rel = 'plugins/sdd-quality-loop/agents/evaluator.md'
        self.bind('evaluator')
        for shell in SHELLS:
            self.bind('evaluator')
            for target in ('../' + rel, './' + rel, rel.replace('/', '//', 1),
                           str(self.root / rel), rel.replace('/', '\\')):
                with self.subTest(shell=shell, target=target):
                    self.assertEqual(self.render(shell, rel).returncode, 0)
                    before = tree(self.root)
                    self.rejected(self.render(shell, target), launch.MISMATCH)
                    self.assertEqual(tree(self.root), before)
            with self.subTest(shell=shell, target='symlink'):
                self.assertEqual(self.render(shell, rel).returncode, 0)
                target = self.root / rel
                original = target.read_bytes()
                outside = self.base / 'outside.md'
                outside.write_bytes(original)
                target.unlink()
                target.symlink_to(outside)
                try:
                    before = tree(self.root)
                    self.rejected(self.render(shell, rel), launch.MISMATCH)
                    self.assertEqual(tree(self.root), before)
                    self.assertTrue(target.is_symlink())
                    self.assertEqual(outside.read_bytes(), original)
                finally:
                    target.unlink()
                    target.write_bytes(original)
            protected_rel = 'plugins/sdd-review-loop/agents/impl-reviewer-a.md'
            for case in ('staging-ancestor', 'staged-target', 'manifest'):
                with self.subTest(shell=shell, staging_symlink=case):
                    resolved = self.bind('impl-reviewer-a')
                    self.assertEqual(self.render(shell, protected_rel).returncode, 0)
                    current = self.root / CURRENT
                    staged = current / protected_rel
                    manifest = current / 'MANIFEST.sha256'
                    self.assertTrue(staged.is_file(), 'positive protected render must create staged target')
                    self.assertTrue(manifest.is_file(), 'positive protected render must create manifest')
                    fields = frontmatter(staged.read_text())[0]
                    self.assertEqual((fields.get('model'), fields.get('effort')),
                                     (resolved['native_id'], resolved['effort']))
                    self.assertEqual(self.render(shell, protected_rel, check=True).returncode, 0)
                    outside = self.base / ('stage-outside-' + shell + '-' + case)
                    if case == 'staging-ancestor':
                        target = current.parent
                        saved = self.base / ('saved-staging-' + shell)
                        target.rename(saved)
                        shutil.copytree(saved, outside)
                        outside_before = tree(outside)
                        target.symlink_to(outside, target_is_directory=True)
                    else:
                        target = staged if case == 'staged-target' else manifest
                        original = target.read_bytes()
                        outside.write_bytes(original)
                        target.unlink()
                        target.symlink_to(outside)
                    try:
                        before = tree(self.root)
                        self.rejected(self.render(shell, protected_rel), launch.MISMATCH)
                        self.assertEqual(tree(self.root), before)
                        self.assertTrue(target.is_symlink())
                        if case == 'staging-ancestor':
                            self.assertEqual(tree(outside), outside_before)
                        else:
                            self.assertEqual(outside.read_bytes(), original)
                    finally:
                        target.unlink()
                        if case == 'staging-ancestor':
                            saved.rename(target)
                        else:
                            target.write_bytes(original)


class ManagedCodexRoles(ManagedFixture):
    host = 'codex-cli'

    def codex_model(self):
        return next(m for m in self.trusted_policy['models'] if 'codex-cli' in m['hosts'])

    def fixture_policy(self):
        """Trusted policy; only fixture lifecycle/adoption of the trusted Codex mapping differ."""
        policy = copy.deepcopy(self.trusted_policy)
        evidence = launch.canonical({'fixture_only': True,
                                     'claim': 'T-008 fixture adoption; no access, behavior or adoption claim'})
        (self.root / 'codex-fixture-adoption.json').write_bytes(evidence)
        model = next(m for m in policy['models'] if m['id'] == self.codex_model()['id'])
        model['lifecycle'] = 'current'
        model['adoption'] = [{'role': role, 'path': 'codex-fixture-adoption.json',
                              'sha256': launch.sha_bytes(evidence)} for role in sorted(set(CODEX.values()))]
        return policy

    def fresh_observation(self, observed_at=None):
        return {'schema': 'model-observation/v1', 'host': 'codex-cli', 'cli_version': 'codex-cli 0.159.2',
                'scope_id': 'fixture-t008-client', 'scope_kind': 'client', 'purpose': 'diagnostic',
                'observed_at': observed_at or launch.utc_now(), 'source': 'verified-configuration',
                'status': 'complete', 'models': [{'native_id': self.codex_model()['hosts']['codex-cli'],
                                                  'efforts': launch.EFFORTS[:], 'available': True}],
                'reason': 'Verified-configuration fixture only; no live access or actual backend proof.'}

    def test_toml_runtime_keys_follow_bound_selection(self):  # TEST-116 render portion, TEST-139
        for rel, role in CODEX.items():
            resolved = self.bind(role)
            self.assertEqual(resolved['effort_control'], 'flag', 'Codex effort is a native configuration value')
            original = tomllib.loads(self.originals[rel].decode('utf-8'))
            for shell in SHELLS:
                with self.subTest(target=rel, shell=shell):
                    self.restore(rel)
                    self.assert_rendered(shell, rel)
                    data = self.toml(rel)
                    self.assertEqual([data.get(k) for k in RUNTIME_TOML], [resolved['native_id'], resolved['effort']])
                    self.assertEqual({k: v for k, v in data.items() if k not in RUNTIME_TOML},
                                     {k: v for k, v in original.items() if k not in RUNTIME_TOML})
                    self.accepted(self.native(data['model']))

    def test_reference_comments_neither_satisfy_nor_mask_runtime_selection(self):  # TEST-120 (Codex)
        rel = '.codex/agents/sdd-evaluator.toml'
        resolved = self.bind('evaluator')
        current = ['# x-sdd-model: ' + resolved['native_id'], '# x-sdd-effort: ' + resolved['effort']]

        def with_current_comments(text):
            return '\n'.join(current + [line for line in text.split('\n') if not line.startswith('# x-sdd-')])
        comment_only = with_current_comments(self.originals[rel].decode('utf-8'))
        for shell in SHELLS:
            with self.subTest(case='comments-name-selection-without-runtime-keys', shell=shell):
                self.restore(rel)
                self.assertEqual(self.render(shell, rel).returncode, 0)
                self.assertEqual(self.render(shell, rel, check=True).returncode, 0)
                (self.root / rel).write_text(comment_only, encoding='utf-8')
                self.assertFalse(set(RUNTIME_TOML) & set(self.toml(rel)))
                self.assert_drift(shell, rel)
            with self.subTest(case='stale-runtime-key-behind-current-comments', shell=shell):
                self.restore(rel)
                self.assertEqual(self.render(shell, rel).returncode, 0)
                self.assertEqual(self.render(shell, rel, check=True).returncode, 0)
                stale = 'gpt-5.2-codex'
                text = re.sub(r'(?m)^model\s*=.*$', 'model = "' + stale + '"', self.text(rel), count=1)
                (self.root / rel).write_text(with_current_comments(text), encoding='utf-8')
                self.assertEqual(self.toml(rel).get('model'), stale)
                self.assert_drift(shell, rel)
                self.rejected(self.native(stale), 'native-precedence-conflict')

    def test_effort_only_runtime_drift_is_not_hidden_by_current_comments(self):
        rel = '.codex/agents/sdd-evaluator.toml'
        resolved = self.bind('evaluator')
        stale_effort = 'low' if resolved['effort'] != 'low' else 'high'
        for shell in SHELLS:
            with self.subTest(shell=shell):
                self.restore(rel)
                self.assertEqual(self.render(shell, rel).returncode, 0)
                self.assertEqual(self.render(shell, rel, check=True).returncode, 0)
                self.assertEqual([self.toml(rel).get(key) for key in RUNTIME_TOML],
                                 [resolved['native_id'], resolved['effort']],
                                 'positive managed render must create both native TOML fields before mutation')
                text = re.sub(r'(?m)^model_reasoning_effort\s*=.*$',
                              'model_reasoning_effort = "' + stale_effort + '"', self.text(rel), count=1)
                text = '# x-sdd-effort: ' + resolved['effort'] + '\n' + '\n'.join(
                    line for line in text.split('\n') if not line.startswith('# x-sdd-effort:'))
                (self.root / rel).write_text(text, encoding='utf-8')
                self.assertEqual(self.toml(rel)['model'], resolved['native_id'])
                self.assertEqual(self.toml(rel)['model_reasoning_effort'], stale_effort)
                self.assert_drift(shell, rel)

    def test_legacy_default_render_remains_comment_only(self):  # preservation guard, expected GREEN at baseline
        for shell in SHELLS:
            with self.subTest(shell=shell):
                self.restore(*TARGETS)
                result = self.render(shell, legacy=True)
                self.assertEqual(result.returncode, 0, result.stderr[-1500:])
                for rel in CODEX:
                    self.assertTrue(self.text(rel).startswith('# x-sdd-model: '))
                    self.assertFalse(set(RUNTIME_TOML) & set(self.toml(rel)), 'legacy mode adds no runtime keys')



if __name__ == '__main__':
    unittest.main()
