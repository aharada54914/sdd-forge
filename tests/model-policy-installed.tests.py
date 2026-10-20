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
import uuid

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


    def test_crlf_claude_native_fields_preserve_body_bytes(self):
        rel = 'plugins/sdd-quality-loop/agents/evaluator.md'
        resolved = self.bind('evaluator')
        original = self.originals[rel].replace(b'\r\n', b'\n').replace(b'\n', b'\r\n')
        original_body = original.split(b'---\r\n', 2)[2]
        for shell in SHELLS:
            with self.subTest(shell=shell):
                (self.root / rel).write_bytes(original)
                result = self.render(shell, rel)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr[-1200:])
                generated = (self.root / rel).read_bytes()
                self.assertNotIn(b'\n', generated.replace(b'\r\n', b''), 'CRLF style must be preserved')
                self.assertGreaterEqual(generated.count(b'---\r\n'), 2, 'frontmatter delimiters must remain present')
                self.assertEqual(generated.split(b'---\r\n', 2)[2], original_body)
                fields = frontmatter(generated.decode('utf-8').replace('\r\n', '\n'))[0]
                self.assertEqual((fields.get('model'), fields.get('effort')),
                                 (resolved['native_id'], resolved['effort']))
                self.assertEqual(self.render(shell, rel, check=True).returncode, 0)
                self.assertEqual((self.root / rel).read_bytes(), generated)

    def test_unknown_managed_arguments_are_typed_rejections(self):
        rel = 'plugins/sdd-quality-loop/agents/evaluator.md'
        self.bind('evaluator')
        for shell in SHELLS:
            with self.subTest(shell=shell):
                positive = self.render(shell, rel)
                self.assertEqual(positive.returncode, 0, positive.stdout + positive.stderr[-1200:])
                before = tree(self.root)
                unknown = '--unexpected-managed-input' if shell == 'bash' else '-UnexpectedManagedInput'
                self.rejected(self.render(shell, rel, extra=(unknown, 'canary')), 'input-invalid')
                self.assertEqual(tree(self.root), before, 'unknown managed arguments must write nothing')


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



    def test_crlf_codex_native_fields_preserve_instructions(self):
        rel = '.codex/agents/sdd-evaluator.toml'
        resolved = self.bind('evaluator')
        original = self.originals[rel].replace(b'\r\n', b'\n').replace(b'\n', b'\r\n')
        prior = tomllib.loads(original.decode('utf-8'))
        instruction_marker = b'developer_instructions = '
        original_instructions = original.split(instruction_marker, 1)[1]
        for shell in SHELLS:
            with self.subTest(shell=shell):
                (self.root / rel).write_bytes(original)
                result = self.render(shell, rel)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr[-1200:])
                generated = (self.root / rel).read_bytes()
                self.assertNotIn(b'\n', generated.replace(b'\r\n', b''), 'CRLF style must be preserved')
                self.assertIn(instruction_marker, generated)
                self.assertEqual(generated.split(instruction_marker, 1)[1], original_instructions)
                parsed = tomllib.loads(generated.decode('utf-8'))
                self.assertEqual([parsed.get(key) for key in RUNTIME_TOML],
                                 [resolved['native_id'], resolved['effort']])
                self.assertEqual({k: v for k, v in parsed.items() if k not in RUNTIME_TOML},
                                 {k: v for k, v in prior.items() if k not in RUNTIME_TOML})
                self.assertEqual(self.render(shell, rel, check=True).returncode, 0)
                self.assertEqual((self.root / rel).read_bytes(), generated)


# ---- T-008 installed prepare entry and installer runtime closure (prepare/install batch only) -------------------
# Proposed public surface (requires primary admission before product work); cwd is the execution-input root:
#   python3 <installed>/plugins/sdd-implementation/scripts/managed-model-entry.py prepare --request REL
#       --registry REL --role ROLE --host HOST --run-id ID --session-id ID --attempt N --output-dir REL
#       --require-actual-id true|false
# Oracle: the unchanged real selector, T-007 launch-controls and T-005 bind CLIs run from the source-copied
# LaunchFixture repository over the same project bytes. Evidence class: FIXTURE ONLY (verified-configuration
# observation, fixture adoption, FilesOnly installs). No native model, thread or turn is ever started.
MANAGED_RUNTIME = sorted([ADAPTER, *launch.TRUSTED_PATHS])
# Union of install.sh REQUIRED_PATHS and install.ps1 Get-RequiredPaths (non-cloud) at authoring time; the positive
# installs prove this minimal package satisfies the actual installer contract.
INSTALLER_REQUIRED = sorted({'.agents/plugins/marketplace.json', '.claude-plugin/marketplace.json', *CODEX,
                             'plugins/sdd-bootstrap/skills/bootstrap/SKILL.md', 'plugins/sdd-ship/skills/ship/SKILL.md',
                             *('plugins/' + plugin + '/' + manifest + '/plugin.json'
                               for plugin in ('sdd-bootstrap', 'sdd-implementation', 'sdd-quality-loop', 'sdd-lite',
                                              'sdd-review-loop', 'sdd-ship', 'sdd-domain')
                               for manifest in ('.codex-plugin', '.claude-plugin', '.plugin'))})
PACKAGE = sorted({'install.sh', 'install.ps1', *INSTALLER_REQUIRED, *MANAGED_RUNTIME, *launch.COPIED})
OUTPUT_FILES = ['controls.json', 'selection.json', 'validation.json']
# Invalid under the existing T-007 identifier grammar without being flag-shaped argument syntax.
BAD_IDS = ('run id', 'run;id', '.run', 'r' * 129)
BAD_ATTEMPTS = ('0', '01', '+1', '1.0', 'one')


def runtime_tree(root):
    """Installed bytes; interpreter caches are not installation content."""
    return {path: digest for path, digest in tree(root).items() if '__pycache__' not in path.split('/')}


class InstalledEntryTests(LaunchFixture):
    """Installed prepare entry from an unrelated cwd plus the installers' managed runtime closure."""

    root: Path

    def setUp(self):
        self.assertTrue(PWSH and os.access(PWSH, os.X_OK), 'PowerShell is required; fixture setup failure')
        super().setUp()
        copilot = self.base / 'shims' / 'copilot'
        copilot.write_text('#!/bin/sh\necho "$0 $*" >> "' + str(self.marker) + '"\nexit 97\n')
        copilot.chmod(0o755)
        self.fixture_repo = self.root
        self.helper()  # the T-007 oracle module stays bound to the source-copied fixture repository
        self.root = self.base / 'project'  # unrelated execution-input root: no product copies live here
        (self.root / 'runs').mkdir(parents=True)
        self.policy = self.fixture_policy()
        self.request = self.fresh_request('evaluator')
        self.observation = self.fresh_observation()
        self.save()
        self.poison = self.base / 'source-package-used'
        self.home = self.base / 'home'
        codex = self.home / '.codex'
        (codex / 'agents').mkdir(parents=True)
        (codex / 'config.toml').write_text('# user configuration canary\nmodel = "user-choice"\n')
        (codex / 'agents' / 'sdd-evaluator.toml').write_text('# user agent canary; never replaced\n')
        self.codex_home = tree(codex)
        self.environment.update(HOME=str(self.home), XDG_DATA_HOME=str(self.home / '.local/share'),
                                SDD_CODEX_HOME=str(codex), SDD_CURSOR_DIR=str(self.base / 'cursor-absent'),
                                SDD_VSCODE_USER_DIR=str(self.base / 'vscode-absent'),
                                GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL=os.devnull, GIT_TERMINAL_PROMPT='0')

    # ---- actual installers over a minimal current-byte package -------------------------------------------------

    def build_package(self, label, omit=None):
        """Explicit current working-tree byte overlay, Git-tracked only inside this disposable source."""
        package = self.base / ('package-' + label)
        package.mkdir()
        for rel in PACKAGE:
            if rel in MANAGED_RUNTIME:
                self.assertTrue((ROOT / rel).is_file(), 'managed runtime source is missing: ' + rel)
            if rel == omit or not (ROOT / rel).is_file():
                continue  # an absent installer-required file is the installer's own rejection to report
            (package / rel).parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / rel, package / rel)
        for command in (['init', '-q'], ['add', '-A'],
                        ['-c', 'user.name=Installer Test', '-c', 'user.email=installer-test@example.invalid',
                         '-c', 'gc.auto=0', 'commit', '-qm', 'T-008 installed entry fixture']):
            result = self.run_process(['git', '-C', str(package), *command], label='fixture git')
            self.assertEqual(result.returncode, 0, 'fixture package (setup, not T-008 RED): ' + result.stderr[-800:])
        return package

    def run_installer(self, shell, package, install_root):
        if shell == 'bash':
            command = [launch.BASH, str(package / 'install.sh'), '--source-directory', str(package),
                       '--install-root', str(install_root), '--target', 'FilesOnly',
                       '--plugins', 'sdd-implementation', '--skip-mcp']
        else:
            command = [PWSH, '-NoProfile', '-File', str(package / 'install.ps1'), '-SourceDirectory', str(package),
                       '-InstallRoot', str(install_root), '-Target', 'FilesOnly',
                       '-Plugins', 'sdd-implementation', '-SkipMcp']
        result = self.run_process(command, timeout=300, label=shell + ' installer')
        self.assertFalse(self.marker.exists(), 'the installer invoked a native host executable')
        self.assertEqual(tree(self.home / '.codex'), self.codex_home, 'native/global Codex configuration changed')
        return result

    def install(self, shell):
        """One actual successful install; the source package is then poisoned so it cannot be a fallback."""
        package = self.build_package(shell)
        install_root = self.base / ('installed-' + shell)
        result = self.run_installer(shell, package, install_root)
        self.assertEqual(result.returncode, 0, result.stdout[-800:] + result.stderr[-1500:])
        self.assertIn('SDD plugins installed at: ' + str(install_root), result.stdout)
        for rel in MANAGED_RUNTIME + sorted(CODEX):
            self.assertTrue((install_root / rel).is_file(), 'installed package lacks ' + rel)
            self.assertEqual(launch.sha_file(install_root / rel), launch.sha_file(ROOT / rel),
                             'installed bytes must be the current-byte overlay: ' + rel)
        self.poison_source(package)
        return install_root

    def poison_source(self, package):
        marker = str(self.poison)
        bodies = {'.py': 'import pathlib\npathlib.Path(%r).write_text("python")\nraise SystemExit(97)\n' % marker,
                  '.sh': '#!/bin/sh\necho sh >> "%s"\nexit 97\n' % marker,
                  '.ps1': 'Set-Content -LiteralPath "%s" -Value ps1\nexit 97\n' % marker}
        for path in list(package.rglob('*')):
            if path.is_file() and not path.is_symlink() and '.git' not in path.relative_to(package).parts:
                path.write_text(bodies.get(path.suffix, '{"poisoned": "source package fallback"'))

    # ---- installed prepare entry and unchanged T-005/T-007 oracles ---------------------------------------------

    def prepare(self, install_root, output, *, role='evaluator', host=launch.HOST, run_id=None, session_id=None,
                attempt='1', require_actual_id='false'):
        command = [sys.executable, '-I', '-B', str(install_root / ADAPTER), 'prepare', '--request', 'request.json',
                   '--registry', 'registry.json', '--role', role, '--host', host,
                   '--run-id', self.run_id if run_id is None else run_id,
                   '--session-id', self.session_id if session_id is None else session_id,
                   '--attempt', attempt, '--output-dir', output, '--require-actual-id', require_actual_id]
        result = self.run_process(command, timeout=120, label='installed prepare entry')
        self.assertFalse(self.marker.exists(), 'prepare allocated or invoked a native model executable')
        self.assertFalse(self.poison.exists(), 'the installed entry fell back to the removed source package')
        return result

    def oracle_selection(self):
        result = self.run_process([launch.BASH, str(self.fixture_repo / launch.SELECTOR_SH), '--policy-input',
                                   'request.json', '--registry', 'registry.json'], label='oracle selector')
        self.assertEqual(result.returncode, 0, 'oracle selector failed (fixture, not product): ' + result.stderr[:800])
        return self.helper().strict_json(result.stdout)

    def oracle_validation(self, output, sha, *, role='evaluator', host=launch.HOST, run_id=None, session_id=None):
        return self.run_process([sys.executable, '-B', str(self.fixture_repo / launch.HELPER), 'launch-controls',
                                 '--controls', output + '/controls.json', '--controls-sha256', sha, '--role', role,
                                 '--host', host, '--run-id', self.run_id if run_id is None else run_id,
                                 '--session-id', self.session_id if session_id is None else session_id],
                                label='T-007 launch-controls oracle')

    def assert_prepared(self, install_root, output, *, role='evaluator', host=launch.HOST, attempt=1):
        """Complete positive: exact outputs, every raw pin, installed trusted bytes and the T-007 recomputation."""
        project, installed = tree(self.root), runtime_tree(install_root)
        value = self.accepted(self.prepare(install_root, output, role=role, host=host, attempt=str(attempt)))
        helper, out = self.helper(), self.root / output
        self.assertEqual(sorted(path.name for path in out.iterdir()), OUTPUT_FILES)
        after = tree(self.root)
        self.assertEqual({path: after.get(path) for path in project}, project, 'prepare changed an existing input')
        self.assertEqual(sorted(set(after) - set(project)), [output + '/' + name for name in OUTPUT_FILES])
        self.assertEqual(runtime_tree(install_root), installed, 'prepare changed installed templates or runtime')
        self.assertEqual(tree(self.home / '.codex'), self.codex_home, 'native/global Codex configuration changed')
        self.assertEqual(helper.strict_json((out / 'validation.json').read_bytes()), value)
        controls_raw = (out / 'controls.json').read_bytes()
        controls = helper.strict_json(controls_raw)
        self.assertEqual(controls, {'schema': 'model-launch-controls/v1', 'role': role, 'host': host,
                                    'attempt': attempt, 'require_actual_id': False,
                                    'selection': self.ref(output + '/selection.json'),
                                    'request': self.ref('request.json'), 'registry': self.ref('registry.json'),
                                    'inputs': [self.ref(path) for path in sorted(self.closure())]},
                         'controls must raw-pin the exact sorted request/policy/observation/adoption closure')
        self.assertEqual(set(value), launch.VALIDATION_FIELDS)
        self.assertEqual(value['controls'], {'path': output + '/controls.json',
                                             'sha256': launch.sha_bytes(controls_raw)})
        self.assertEqual(value['pins'], self.expected_pins(controls))
        self.assertEqual(value['trusted'], [{'path': path, 'sha256': launch.sha_file(install_root / path)}
                                            for path in launch.TRUSTED_PATHS], 'trusted runtime is the installed copy')
        for entry in value['trusted']:
            self.assertEqual(entry['sha256'], launch.sha_file(ROOT / entry['path']), 'installed bytes are current')
        self.assertEqual([value[key] for key in ('role', 'host', 'run_id', 'session_id', 'attempt')],
                         [role, host, self.run_id, self.session_id, attempt])
        self.assertIs(type(value['attempt']), int)
        self.assertIs(value['require_actual_id'], False)
        selection = helper.strict_json((out / 'selection.json').read_bytes())
        helper.validate_selection_record(selection, require_bound=True)
        self.assertEqual(selection, value['selection'])
        self.assertEqual(selection['binding'], {'run_id': self.run_id, 'session_id': self.session_id,
                                                'attempt': attempt})
        self.assertEqual(selection, helper.bind_selection(self.oracle_selection(), run_id=self.run_id,
                                                          session_id=self.session_id, attempt=attempt))
        self.assertEqual((selection['observation_sha256'], self.observation['source']),
                         (self.observation['observation_sha256'], 'verified-configuration'), 'fixture evidence only')
        trusted = next(m for m in self.trusted_policy['models'] if m['id'] == selection['resolved']['catalog_id'])
        self.assertEqual(selection['resolved']['native_id'], trusted['hosts'][host], 'trusted mapping only')
        self.assertEqual(value, self.accepted(self.oracle_validation(output, value['controls']['sha256'],
                                                                     role=role, host=host)),
                         'stdout must equal the unchanged T-007 validation of the persisted controls')
        return value

    def assert_prepare_rejected(self, install_root, output, reasons, **options):
        """Typed rejection: no stdout, no new validation receipt, no native run, existing bytes unchanged."""
        project, installed = tree(self.root), runtime_tree(install_root)
        error = self.rejected(self.prepare(install_root, output, **options), reasons)
        after = tree(self.root)
        self.assertEqual({path: after.get(path) for path in project}, project, 'rejected prepare changed bytes')
        self.assertFalse([path for path in set(after) - set(project) if path.endswith('validation.json')],
                         'a rejected prepare published a validation receipt')
        self.assertEqual(runtime_tree(install_root), installed, 'prepare wrote into the installed package')
        self.assertEqual(tree(self.home / '.codex'), self.codex_home, 'native/global Codex configuration changed')
        return error

    # ---- the four bounded acceptance methods -----------------------------------------------------------------

    def test_prepare_from_both_installed_packages(self):
        installed = {}
        for shell in SHELLS:
            install_root = self.install(shell)
            self.assert_prepared(install_root, 'runs/prepare-' + shell)
            # Mutate only the generated artifact, then use its real unchanged T-007 consumer.
            output = 'runs/prepare-' + shell
            controls_path = self.root / output / 'controls.json'
            original = controls_path.read_bytes()
            for case in ('controls-self-reference', 'conflicting-cross-reference-pin'):
                with self.subTest(shell=shell, controls_mismatch=case):
                    self.accepted(self.oracle_validation(output, launch.sha_bytes(original)))
                    document = self.helper().strict_json(original)
                    if case == 'controls-self-reference':
                        reference = {'path': output + '/controls.json', 'sha256': launch.sha_bytes(original)}
                    else:
                        reference = dict(document['request'], sha256='0' * 64)
                        self.assertNotEqual(reference['sha256'], document['request']['sha256'])
                    document['inputs'].append(reference)
                    document['inputs'].sort(key=lambda entry: entry['path'])
                    changed = launch.canonical(document)
                    controls_path.write_bytes(changed)
                    try:
                        self.rejected(self.oracle_validation(output, launch.sha_bytes(changed)), 'input-invalid')
                    finally:
                        controls_path.write_bytes(original)
                    self.assertEqual(controls_path.read_bytes(), original)
            installed[shell] = runtime_tree(install_root)
        self.assertEqual(installed['bash'], installed['pwsh'], 'both installers must place identical package bytes')

    def test_prepare_rejects_role_host_and_actual_id_mismatches(self):
        install_root = self.install('bash')
        positive = self.assert_prepared(install_root, 'runs/positive')
        # A changed ordinary request before a fresh legitimate preparation recomputes; it is not a rejection.
        self.request['risk'] = 'medium'
        self.save()
        self.assert_prepared(install_root, 'runs/recomputed')
        self.request = self.fresh_request('evaluator')
        self.save()
        cases = [('role', {'role': 'investigator'}, 'scope-mismatch'),
                 ('host', {'host': 'codex-cli'}, 'scope-mismatch')]
        cases += [(field + '=' + value[:12], {field.replace('-', '_'): value}, 'input-invalid')
                  for field in ('run-id', 'session-id') for value in BAD_IDS]
        cases += [('attempt=' + value, {'attempt': value}, 'input-invalid') for value in BAD_ATTEMPTS]
        cases += [('require-actual-id', {'require_actual_id': 'true'}, 'actual-id-unavailable')]
        for index, (label, options, reason) in enumerate(cases):
            with self.subTest(case=label):
                # Genuine identity/attempt failures under the unchanged T-007/T-005 grammar, not absent syntax.
                if 'run_id' in options or 'session_id' in options:
                    self.rejected(self.oracle_validation('runs/positive', positive['controls']['sha256'], **options),
                                  'input-invalid')
                if 'attempt' in options:
                    self.rejected(self.run_process(
                        [sys.executable, '-B', str(self.fixture_repo / launch.HELPER), 'bind', '--selection',
                         'runs/positive/selection.json', '--run-id', self.run_id, '--session-id', self.session_id,
                         '--attempt', options['attempt'], '--output', 'runs/attempt-oracle.json'],
                        label='T-005 bind oracle'), 'input-invalid')
                self.assert_prepare_rejected(install_root, 'runs/case-%02d' % index, reason, **options)

    def test_prepare_rejects_unsupported_and_reused_outputs(self):
        install_root = self.install('pwsh')
        self.assert_prepared(install_root, 'runs/positive')
        self.assertFalse([m['id'] for m in self.trusted_policy['models'] if 'copilot-cli' in m['hosts']],
                         'a trusted Copilot mapping exists now: replace this branch with a supported test')
        with self.subTest(case='copilot-absent-mapping'):
            self.request['host'] = self.observation['host'] = 'copilot-cli'
            self.save()
            self.assert_prepare_rejected(install_root, 'runs/copilot', 'model-unavailable', host='copilot-cli')
        with self.subTest(case='serialized-live-observation'):
            self.request = self.fresh_request('evaluator')
            self.observation = dict(self.fresh_observation(), source='live-discovery', purpose='launch')
            self.save()
            self.assert_prepare_rejected(install_root, 'runs/live', 'scope-mismatch')
        self.request = self.fresh_request('evaluator')
        self.observation = self.fresh_observation()
        self.save()
        for case, link_rel, output in (('symlink-ancestor', 'linked-runs', 'linked-runs/entry'),
                                       ('symlink-target', 'runs/linked-target', 'runs/linked-target')):
            with self.subTest(case=case):
                outside = self.base / ('outside-' + case)
                outside.mkdir()
                (outside / 'canary.txt').write_text('external canary\n')
                canary = tree(outside)
                (self.root / link_rel).symlink_to(outside, target_is_directory=True)
                self.assert_prepare_rejected(install_root, output, 'input-invalid')
                self.assertTrue((self.root / link_rel).is_symlink())
                self.assertEqual(sorted(path.name for path in outside.iterdir()), ['canary.txt'])
                self.assertEqual(tree(outside), canary, 'a rejected output symlink received writes')
        reused = tree(self.root / 'runs/positive')
        for case, options in (('identical', {}), ('other-session', {'session_id': str(uuid.uuid4())})):
            with self.subTest(case='reused-' + case):
                self.assert_prepare_rejected(install_root, 'runs/positive', {'input-invalid', 'resume-conflict'},
                                             **options)
                self.assertEqual(tree(self.root / 'runs/positive'), reused, 'a reused output was overwritten')

    def test_installers_reject_missing_managed_runtime_closure(self):
        for shell in SHELLS:
            self.install(shell)  # actual positive: the complete package satisfies every existing installer check
            for index, rel in enumerate(MANAGED_RUNTIME):
                with self.subTest(shell=shell, missing=rel):
                    install_root = self.base / ('incomplete-%s-%d' % (shell, index))
                    package = self.build_package('%s-missing-%d' % (shell, index), omit=rel)
                    self.assertFalse((package / rel).exists())
                    result = self.run_installer(shell, package, install_root)
                    self.assertNotEqual(result.returncode, 0, 'installer accepted a package without ' + rel)
                    self.assertNotIn('SDD plugins installed at:', result.stdout)
                    self.assertFalse(install_root.exists(), 'an incomplete managed runtime was left installed')


if __name__ == '__main__':
    unittest.main()
