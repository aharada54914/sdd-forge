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
import json
import os
from pathlib import Path
import re
import shlex
from typing import Any
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


# ---- T-008 installed Codex entry: generated native configuration only (codex-entry batch) ----------------------
# Proposed public surface (requires primary admission before product work); cwd is the execution-input root:
#   python3 -I -B <installed>/plugins/sdd-implementation/scripts/managed-model-entry.py codex-entry --request REL
#       --registry REL --role ROLE --host codex-cli --run-id ID --session-id ID --attempt N --output-dir REL
#       --require-actual-id true|false
# Oracle: independent recomputation from the pinned installed bytes plus the recorded JSONL transcript of a real
# fixture `codex` child process (version + app-server) that the product's genuine CodexClient spawns through PATH.
# Nothing is mocked inside the product. Evidence class: FIXTURE ONLY (configured response shapes, no model, no
# inference, no actual backend ID, no T-010 adoption and no organization access). A turn is never started.
NATIVE_HOST = 'codex-cli'
NATIVE_VERSION = 'codex-cli 0.159.2'
NATIVE_FILES = ['agent.toml', 'controls.json', 'observation.json', 'selection.json', 'validation.json']
NATIVE_METHODS = {'initialize', 'initialized', 'account/read', 'model/list', 'thread/start'}
NATIVE_INIT = {'codexHome': '/fixture/codex-home', 'platformFamily': 'unix', 'platformOs': 'linux',
               'userAgent': 'codex_cli_rs/0.159.2'}
NATIVE_ACCOUNT = {'requiresOpenaiAuth': True, 'account': None, 'workspaceRouting': None}
OTHER_ACCOUNT = {'requiresOpenaiAuth': False, 'account': {'type': 'amazonBedrock'}}
CODEX_TEMPLATE = '.codex/agents/sdd-evaluator.toml'
THREAD_START_SCHEMA = ('specs/ci-model-modernization/verification/T-004/quality-cycle1-fix/final/native-readonly/'
                       'generated-schema/v2/ThreadStartParams.json')

# Fixture `codex`: `--version` prints the configured version; `app-server` speaks JSON-lines JSON-RPC (no jsonrpc
# header). Every process start and every request (with the generated config's existence) is logged BEFORE replying.
# The mutation fires once, at the first account/read that finds the generated config on disk, and is logged
# before the otherwise valid reply is written, so the drift is deterministic without sleeps or polling.
FAKE_CODEX = r'''
import hashlib, json, os, re, sys, tomllib

CONFIG = json.load(open(sys.argv[1], encoding='utf-8'))
ARGV = sys.argv[2:]
LOG = open(CONFIG['log'], 'a', encoding='utf-8')


def note(**entry):
    LOG.write(json.dumps(dict(entry, pid=os.getpid()), sort_keys=True) + '\n')
    LOG.flush()


def reply(value):
    sys.stdout.buffer.write(json.dumps(value).encode('utf-8') + b'\n')
    sys.stdout.buffer.flush()


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def semantic(raw):
    try:
        return tomllib.loads(raw.decode('utf-8'))
    except (tomllib.TOMLDecodeError, UnicodeDecodeError):
        return None


def mutate(spec):
    edits = []
    for edit in spec['edits']:
        raw = open(edit['file'], 'rb').read()
        text, counts = raw.decode('utf-8'), []
        for op in edit['ops']:
            if 'sub' in op:
                text, count = re.subn(op['sub'][0], op['sub'][1], text, count=1)
            elif 'append' in op:
                text, count = text + op['append'], 1
            else:
                text, count = op['prepend'] + text, 1
            counts.append(count)
        changed = text.encode('utf-8')
        with open(edit['file'], 'wb') as stream:
            stream.write(changed)
        record = {'label': edit['label'], 'counts': counts, 'before': sha(raw), 'after': sha(changed),
                  'semantic_same': None}
        if edit['file'].endswith('.toml'):
            record['semantic_same'] = semantic(raw) is not None and semantic(raw) == semantic(changed)
        edits.append(record)
    return edits


def model_page():
    efforts = CONFIG['efforts']
    return {'data': [{'id': name, 'model': name, 'displayName': name, 'description': 'Fixture model.',
                      'hidden': False, 'isDefault': False, 'defaultReasoningEffort': efforts[0],
                      'supportedReasoningEfforts': [{'reasoningEffort': e, 'description': e + ' effort'}
                                                    for e in efforts]} for name in CONFIG['models']]}


def thread_result(params):
    cwd = params.get('cwd')
    return {'activePermissionProfile': None, 'approvalPolicy': 'never', 'approvalsReviewer': 'user', 'cwd': cwd,
            'disabledPluginIds': [], 'instructionSources': [], 'model': params.get('model'),
            'modelProvider': 'openai', 'multiAgentMode': 'explicitRequestOnly',
            'reasoningEffort': (params.get('config') or {}).get('model_reasoning_effort'),
            'runtimeWorkspaceRoots': [], 'sandbox': {'type': 'readOnly', 'networkAccess': False},
            'serviceTier': None,
            'thread': {'cliVersion': CONFIG['version'].split()[-1], 'createdAt': 1, 'cwd': cwd, 'ephemeral': True,
                       'id': 'thread-fixture-1', 'modelProvider': 'openai', 'preview': '', 'projectId': None,
                       'sessionId': 'session-fixture-1', 'source': 'appServer', 'status': {'type': 'idle'},
                       'turns': [], 'updatedAt': 1}}


def patched(value, patch):
    for op in patch:
        target = value
        for key in op['path'][:-1]:
            target = target[key]
        if op.get('delete'):
            target.pop(op['path'][-1], None)
        else:
            target[op['path'][-1]] = op['value']
    return value


if ARGV == ['--version']:
    note(event='version', argv=ARGV)
    print(CONFIG['version'], flush=True)
    sys.exit(0)
if ARGV != ['app-server']:
    note(event='unsupported', argv=ARGV)
    sys.exit(3)
note(event='server', argv=ARGV)
ACCOUNT, FIRED, THREAD = CONFIG['account'], False, CONFIG['thread'] or {}
for raw in sys.stdin.buffer:
    try:
        message = json.loads(raw)
    except ValueError:
        message = None
    if not isinstance(message, dict):
        note(event='invalid')
        continue
    exists = bool(CONFIG['trigger']) and os.path.isfile(CONFIG['trigger'])
    note(event='request', message=message, config_exists=exists)
    if 'id' not in message:
        continue
    method, rid, params = message.get('method'), message['id'], message.get('params')
    if method == 'initialize':
        result = CONFIG['init']
    elif method == 'account/read':
        spec = CONFIG['mutation']
        if spec and not FIRED and exists:
            FIRED = True
            edits = mutate(spec)
            changed_account = spec.get('account') is not None
            if changed_account:
                ACCOUNT = spec['account']
            note(event='mutation', edits=edits, account_changed=changed_account, config_exists=exists)
        result = ACCOUNT
    elif method == 'model/list':
        result = model_page()
    elif method == 'thread/start' and not THREAD.get('error'):
        result = patched(thread_result(params), THREAD.get('patch', []))
    elif method == 'thread/start':
        reply({'id': rid, 'error': THREAD['error']})
        continue
    else:
        reply({'id': rid, 'error': {'code': -32601, 'message': 'method not found'}})
        continue
    reply({'id': rid, 'result': result})
'''


class NativeProbe:
    """One fixture `codex` executable on its own PATH entry and the JSONL transcript it appends to."""

    def __init__(self, path, log):
        self.path, self.log = path, log

    def entries(self, event=None):
        lines = self.log.read_text(encoding='utf-8').splitlines() if self.log.exists() else []
        records = [json.loads(line) for line in lines]
        return [record for record in records if event is None or record['event'] == event]

    def requests(self):
        return self.entries('request')

    def methods(self):
        return [record['message'].get('method') for record in self.requests()]

    def starts(self):
        return [record for record in self.requests() if record['message'].get('method') == 'thread/start']


class NativeRun:
    """One installed codex-entry invocation with the byte snapshots taken after staging and before launch."""

    def __init__(self, result, output, request, probe, session_id, before, installed):
        self.result, self.output, self.request, self.probe = result, output, request, probe
        self.session_id, self.before, self.installed = session_id, before, installed


class InstalledNativeEntryTests(LaunchFixture):
    """Installed codex-entry from an unrelated cwd: ONE genuine product client against a fixture `codex` child."""

    root: Path
    # Explicit reuse of the admitted fixtures' helpers; no inherited test methods, so discovery stays unduplicated.
    codex_model = ManagedCodexRoles.codex_model
    fixture_policy = ManagedCodexRoles.fixture_policy
    build_package = InstalledEntryTests.build_package
    run_installer = InstalledEntryTests.run_installer
    install = InstalledEntryTests.install
    poison_source = InstalledEntryTests.poison_source

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
        self.policy = self.fixture_policy()  # trusted policy; only the Codex mapping's lifecycle/adoption differ
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
        self.probes = 0

    # ---- fixture codex executable, staged inputs and the installed entry ---------------------------------------

    def native_probe(self, *, trigger=None, mutation=None, thread=None):
        """Fresh isolated `codex`: its own PATH directory, scenario file and append-only transcript."""
        self.probes += 1
        folder = self.base / ('native-%02d' % self.probes)
        (folder / 'bin').mkdir(parents=True)
        config = {'log': str(folder / 'log.jsonl'), 'version': NATIVE_VERSION, 'init': NATIVE_INIT,
                  'account': NATIVE_ACCOUNT, 'models': [self.codex_model()['hosts'][NATIVE_HOST]],
                  'efforts': launch.EFFORTS, 'trigger': trigger, 'mutation': mutation, 'thread': thread}
        (folder / 'config.json').write_text(json.dumps(config), encoding='utf-8')
        (folder / 'server.py').write_text(FAKE_CODEX, encoding='utf-8')
        executable = folder / 'bin' / 'codex'
        executable.write_text('#!/bin/sh\nexec %s -I -B %s %s "$@"\n' % (
            shlex.quote(sys.executable), shlex.quote(str(folder / 'server.py')), shlex.quote(str(folder / 'config.json'))))
        executable.chmod(0o755)
        return NativeProbe(str(folder / 'bin') + os.pathsep + self.environment['PATH'], folder / 'log.jsonl')

    def stage(self, label, output, *, role='evaluator', host=NATIVE_HOST, observation_path=None):
        """Per-run request and policy; the request declares the observation the entry will own inside OUTPUT."""
        request = self.fresh_request(role)
        request.update(host=host, policy_path='policy-' + label + '.json',
                       observation_path=output + '/observation.json' if observation_path is None else observation_path)
        path = 'request-' + label + '.json'
        self.write(path, request)
        self.write(request['policy_path'], self.policy)
        (self.root / 'registry.json').write_bytes(self.registry_raw)
        return path

    def launch_entry(self, install_root, label, *, probe=None, output=None, request=None, mutation=None, thread=None,
                     **flags):
        """Stage inputs, snapshot bytes, then run the installed codex-entry once from the unrelated project."""
        output = output or 'runs/' + label
        request_path = self.stage(label, output, **(request or {}))
        if probe is None:
            targets = {name: str(self.root / output / name) for name in NATIVE_FILES}
            targets.update(policy=str(self.root / ('policy-' + label + '.json')), request=str(self.root / request_path))
            if mutation is not None:
                mutation = dict(mutation, edits=[{'label': edit['target'], 'file': targets[edit['target']],
                                                  'ops': edit['ops']} for edit in mutation['edits']])
            probe = self.native_probe(trigger=targets['agent.toml'], mutation=mutation, thread=thread)
        options = dict({'role': 'evaluator', 'host': NATIVE_HOST, 'run_id': self.run_id,
                        'session_id': str(uuid.uuid4()), 'attempt': '1', 'require_actual_id': 'false'}, **flags)
        before, installed = tree(self.root), runtime_tree(install_root)
        command = [sys.executable, '-I', '-B', str(install_root / ADAPTER), 'codex-entry', '--request', request_path,
                   '--registry', 'registry.json', '--role', options['role'], '--host', options['host'],
                   '--run-id', options['run_id'], '--session-id', options['session_id'],
                   '--attempt', options['attempt'], '--output-dir', output,
                   '--require-actual-id', options['require_actual_id']]
        result = self.run_process(command, env={'PATH': probe.path}, timeout=300, label='installed codex entry')
        self.assertFalse(self.marker.exists(), 'codex-entry invoked an unsupported native executable')
        self.assertFalse(self.poison.exists(), 'the installed entry fell back to the removed source package')
        return NativeRun(result, output, request_path, probe, options['session_id'], before, installed)

    # ---- assertions shared by the five methods ------------------------------------------------------------------

    def assert_reaped(self, probe):
        for server in probe.entries('server'):
            with self.assertRaises(ProcessLookupError, msg='the owned app-server child outlived the entry'):
                os.kill(server['pid'], 0)

    def assert_entry_accepted(self, install_root, run):
        """Complete positive: success first, then outputs, every raw pin, the generated config and the transcript."""
        value = self.accepted(run.result)
        helper, out = self.helper(), self.root / run.output
        self.assertEqual(sorted(path.name for path in out.iterdir()), NATIVE_FILES)
        after = tree(self.root)
        self.assertEqual({path: after.get(path) for path in run.before}, run.before,
                         'codex-entry changed an existing input')
        self.assertEqual(sorted(set(after) - set(run.before)), [run.output + '/' + name for name in NATIVE_FILES])
        self.assertEqual(runtime_tree(install_root), run.installed, 'codex-entry changed installed templates or runtime')
        self.assertEqual(tree(self.home / '.codex'), self.codex_home, 'native/global Codex configuration changed')
        validation_raw = (out / 'validation.json').read_bytes()
        self.assertEqual(helper.strict_json(validation_raw), value, 'the saved validation must equal stdout')
        self.assertEqual(validation_raw, run.result.stdout.rstrip('\n').encode('utf-8'))
        request = helper.strict_json((self.root / run.request).read_bytes())
        self.assertEqual(request['observation_path'], run.output + '/observation.json')
        closure = {request['policy_path'], request['observation_path'],
                   *(ref['path'] for model in self.policy['models'] for ref in model['adoption'])}
        controls_raw = (out / 'controls.json').read_bytes()
        controls = helper.strict_json(controls_raw)
        self.assertEqual(controls, {'schema': 'model-launch-controls/v1', 'role': 'evaluator', 'host': NATIVE_HOST,
                                    'attempt': 1, 'require_actual_id': False,
                                    'selection': self.ref(run.output + '/selection.json'),
                                    'request': self.ref(run.request), 'registry': self.ref('registry.json'),
                                    'inputs': [self.ref(path) for path in sorted(closure)]},
                         'controls must raw-pin the exact sorted request/policy/observation/adoption closure')
        self.assertEqual(set(value), launch.VALIDATION_FIELDS)
        self.assertEqual(value['controls'], {'path': run.output + '/controls.json',
                                             'sha256': launch.sha_bytes(controls_raw)})
        self.assertEqual(value['pins'], self.expected_pins(controls))
        self.assertEqual(value['trusted'], [{'path': path, 'sha256': launch.sha_file(install_root / path)}
                                            for path in launch.TRUSTED_PATHS], 'trusted runtime is the installed copy')
        for entry in value['trusted']:
            self.assertEqual(entry['sha256'], launch.sha_file(ROOT / entry['path']), 'installed bytes are current')
        self.assertEqual([value[key] for key in ('role', 'host', 'run_id', 'session_id', 'attempt')],
                         ['evaluator', NATIVE_HOST, self.run_id, run.session_id, 1])
        self.assertIs(type(value['attempt']), int)
        self.assertIs(value['require_actual_id'], False)
        # The live observation the entry owns: complete, launch-purpose, client-scoped and the one the controls pin.
        trusted = self.codex_model()
        observation = helper.strict_json((out / 'observation.json').read_bytes())
        helper.validate_observation_record(observation)
        self.assertEqual({key: observation[key] for key in ('schema', 'host', 'cli_version', 'scope_kind', 'purpose',
                                                            'source', 'status')},
                         {'schema': 'model-observation/v1', 'host': NATIVE_HOST, 'cli_version': NATIVE_VERSION,
                          'scope_kind': 'client', 'purpose': 'launch', 'source': 'live-discovery',
                          'status': 'complete'})
        self.assertTrue(observation['scope_id'].startswith('client-'))
        self.assertEqual(observation['models'], [{'native_id': trusted['hosts'][NATIVE_HOST],
                                                  'efforts': launch.EFFORTS, 'available': True}])
        self.assertIn(self.ref(run.output + '/observation.json'), controls['inputs'])
        selection = helper.strict_json((out / 'selection.json').read_bytes())
        helper.validate_selection_record(selection, require_bound=True)
        self.assertEqual(selection, value['selection'])
        self.assertEqual(selection['binding'], {'run_id': self.run_id, 'session_id': run.session_id, 'attempt': 1})
        for field in ('observation_sha256', 'observed_at', 'scope_id', 'cli_version'):
            self.assertEqual(selection[field], observation[field], 'selection must come from the pinned live observation')
        self.assertIn('live-discovery', selection['reason'])
        resolved = selection['resolved']
        self.assertEqual((resolved['catalog_id'], resolved['native_id'], resolved['effort_control']),
                         (trusted['id'], trusted['hosts'][NATIVE_HOST], 'flag'), 'trusted mapping only')
        self.assertIn(resolved['effort'], launch.EFFORTS)
        expected_effort = helper.strict_json(self.registry_raw)['role_defaults']['sdd-evaluator']['default_effort']
        self.assertEqual(expected_effort, 'high', 'the trusted evaluator default changed; review this fixture')
        self.assertEqual(resolved['effort'], expected_effort, 'the selected effort must obey the trusted evaluator default')
        # Generated native configuration: parsed fields, never comments or the raw selection.
        generated = tomllib.loads((out / 'agent.toml').read_text(encoding='utf-8'))
        template = tomllib.loads((install_root / CODEX_TEMPLATE).read_text(encoding='utf-8'))
        self.assertEqual([generated.get(key) for key in RUNTIME_TOML], [resolved['native_id'], resolved['effort']])
        self.assertEqual({k: v for k, v in generated.items() if k not in RUNTIME_TOML},
                         {k: v for k, v in template.items() if k not in RUNTIME_TOML},
                         'name, description, instructions, sandbox and unrelated fields stay the installed role')
        self.assertEqual((generated['name'], generated['sandbox_mode']), ('sdd-evaluator', 'read-only'))
        self.assertTrue(generated['developer_instructions'].strip())
        self.assert_transcript(run, generated, resolved)
        return value

    def assert_transcript(self, run, generated, resolved):
        """One genuine client, in order, and the exact native thread/start request produced from the parsed config."""
        probe = run.probe
        servers, requests = probe.entries('server'), probe.requests()
        self.assertEqual((len(servers), len(probe.entries('version'))), (1, 1),
                         'exactly one genuine client: one version read and one app-server child')
        self.assertEqual((probe.entries('unsupported'), probe.entries('invalid')), ([], []))
        self.assertEqual({record['pid'] for record in requests}, {servers[0]['pid']}, 'one server process only')
        methods = probe.methods()
        self.assertEqual(methods[:5], ['initialize', 'initialized', 'account/read', 'model/list', 'account/read'])
        self.assertLessEqual(set(methods), NATIVE_METHODS, 'only discovery and one thread/start are ever sent')
        self.assertEqual(methods.count('initialize'), 1)
        self.assertEqual(requests[0]['message']['params'], {'clientInfo': self.helper().CLIENT_INFO})
        self.assertEqual(requests[1]['message'], {'method': 'initialized', 'params': {}})
        ids = [record['message']['id'] for record in requests if 'id' in record['message']]
        self.assertEqual(ids, list(range(len(ids))), 'request IDs are correlated and strictly increasing')
        for record in requests:
            method, params = record['message'].get('method'), record['message'].get('params')
            if method == 'model/list':
                self.assertEqual(params, {'includeHidden': True})
            elif method == 'account/read':
                self.assertEqual(params, {'refreshToken': False})
        flags = [bool(record['config_exists']) for record in requests]
        self.assertIn(True, flags, 'the entry never revalidated after generating the config')
        first = flags.index(True)
        self.assertLess(methods.index('model/list'), first, 'live capture precedes config generation')
        self.assertEqual(methods[first], 'account/read', 'the same client revalidates after the config exists')
        self.assertTrue(all(flags[first:]))
        self.assertEqual(methods.count('thread/start'), 1)
        self.assertEqual(methods.index('thread/start'), len(methods) - 1)
        self.assertGreater(methods.index('thread/start'), first)
        params = probe.starts()[0]['message']['params']
        self.assertEqual(params, {'model': generated['model'],
                                  'config': {'model_reasoning_effort': generated['model_reasoning_effort']},
                                  'developerInstructions': generated['developer_instructions'],
                                  'sandbox': generated['sandbox_mode'], 'cwd': str(self.root),
                                  'approvalPolicy': 'never', 'ephemeral': True, 'allowProviderModelFallback': False})
        self.assertEqual((params['model'], params['config']['model_reasoning_effort']),
                         (resolved['native_id'], resolved['effort']))
        schema_path = ROOT / THREAD_START_SCHEMA
        self.assertTrue(schema_path.is_file(), 'the admitted ThreadStartParams schema is missing')
        self.assertLessEqual(set(params), set(json.loads(schema_path.read_text(encoding='utf-8'))['properties']))
        self.assert_reaped(probe)

    def assert_entry_rejected(self, install_root, run, reasons, *, changed=()):
        """Typed rejection: no stdout, no new validation, existing bytes (except declared mutations) unchanged."""
        error = self.rejected(run.result, reasons)
        after = tree(self.root)
        kept = {path: digest for path, digest in run.before.items() if path not in changed}
        self.assertEqual({path: after.get(path) for path in kept}, kept, 'a rejected entry changed an existing input')
        self.assertFalse([path for path in set(after) - set(run.before) if path.endswith('validation.json')],
                         'a rejected entry published a validation receipt')
        self.assertEqual(runtime_tree(install_root), run.installed, 'codex-entry wrote into the installed package')
        self.assertEqual(tree(self.home / '.codex'), self.codex_home, 'native/global Codex configuration changed')
        return error

    def assert_blocked_before_thread(self, run):
        self.assertEqual(run.probe.starts(), [], 'thread/start was sent although the configuration drifted')
        self.assertLessEqual(set(run.probe.methods()), NATIVE_METHODS)
        self.assertFalse((self.root / run.output / 'validation.json').exists())
        self.assert_reaped(run.probe)

    def assert_mutated(self, run, labels):
        """The deterministic post-config mutation really ran exactly once, so an inert canary can never pass."""
        marks = run.probe.entries('mutation')
        self.assertEqual(len(marks), 1, 'the post-config mutation must fire exactly once')
        self.assertTrue(marks[0]['config_exists'])
        self.assertEqual([edit['label'] for edit in marks[0]['edits']], list(labels))
        for edit in marks[0]['edits']:
            self.assertTrue(all(count >= 1 for count in edit['counts']), 'a mutation pattern matched nothing')
            self.assertNotEqual(edit['before'], edit['after'], 'the mutation changed no bytes')
        return marks[0]

    # ---- the five bounded acceptance methods -------------------------------------------------------------------

    def test_codex_entry_uses_one_installed_client_and_generated_native_config(self):
        resolved = {}
        installed = {}
        for shell in SHELLS:
            install_root = self.install(shell)
            run = self.launch_entry(install_root, 'native-' + shell)
            value = self.assert_entry_accepted(install_root, run)
            resolved[shell] = value['selection']['resolved']
            installed[shell] = runtime_tree(install_root)
        self.assertEqual(resolved['bash'], resolved['pwsh'], 'both installations must select identically')
        self.assertEqual(installed['bash'], installed['pwsh'], 'both installers must place identical package bytes')

    def test_codex_entry_rejects_unsafe_or_unsupported_preflight(self):
        install_root = self.install('bash')
        positive = self.launch_entry(install_root, 'positive')
        self.assert_entry_accepted(install_root, positive)  # a missing codex-entry fails here, never as a negative
        probe = positive.probe
        allocated = len(probe.entries())
        cases: list[tuple[str, dict[str, str], dict[str, str], str]] = []
        for field in ('run_id', 'session_id'):
            cases += [('bad-%s-%d' % (field, index), {}, {field: value}, 'input-invalid')
                      for index, value in enumerate(BAD_IDS)]
        cases += [('bad-attempt-%d' % index, {}, {'attempt': value}, 'input-invalid')
                  for index, value in enumerate(BAD_ATTEMPTS)]
        cases += [('request-role', {'role': 'investigator'}, {}, 'scope-mismatch'),
                  ('actual-role', {}, {'role': 'investigator'}, 'scope-mismatch'),
                  ('request-host', {'host': 'claude-code'}, {}, 'scope-mismatch'),
                  ('actual-host-claude', {'host': 'claude-code'}, {'host': 'claude-code'}, 'model-unavailable'),
                  ('actual-host-copilot', {'host': 'copilot-cli'}, {'host': 'copilot-cli'}, 'model-unavailable'),
                  ('role-without-template', {'role': 'spec-reviewer-a'}, {'role': 'spec-reviewer-a'},
                   'model-unavailable')]
        for label, request, flags, reason in cases:
            with self.subTest(case=label):
                run = self.launch_entry(install_root, label, probe=probe, request=request, **flags)
                self.assert_entry_rejected(install_root, run, reason)
                self.assertFalse((self.root / run.output / 'validation.json').exists())
        with self.subTest(case='foreign-observation-path'):
            foreign = 'foreign-observation.json'
            canary = (self.root / positive.output / 'observation.json').read_bytes()
            (self.root / foreign).write_bytes(canary)  # valid observation bytes; rejection must be path authorization
            run = self.launch_entry(install_root, 'foreign-observation', probe=probe,
                                    request={'observation_path': foreign})
            self.assert_entry_rejected(install_root, run, 'input-invalid')
            self.assertEqual((self.root / foreign).read_bytes(), canary, 'a foreign observation was overwritten')
        for case, link_rel, output in (('symlink-ancestor', 'linked-runs', 'linked-runs/entry'),
                                       ('symlink-target', 'runs/linked-target', 'runs/linked-target')):
            with self.subTest(case=case):
                outside = self.base / ('outside-' + case)
                outside.mkdir()
                (outside / 'canary.txt').write_text('external canary\n')
                canary = tree(outside)
                (self.root / link_rel).symlink_to(outside, target_is_directory=True)
                run = self.launch_entry(install_root, case, probe=probe, output=output)
                self.assert_entry_rejected(install_root, run, 'input-invalid')
                self.assertTrue((self.root / link_rel).is_symlink())
                self.assertEqual(sorted(path.name for path in outside.iterdir()), ['canary.txt'])
                self.assertEqual(tree(outside), canary, 'a rejected output symlink received writes')
        reused = tree(self.root / positive.output)
        for case, flags in (('identical', {'session_id': positive.session_id}), ('other-session', {})):
            with self.subTest(case='reused-' + case):
                run = self.launch_entry(install_root, 'positive', probe=probe, output=positive.output, **flags)
                self.assert_entry_rejected(install_root, run, 'input-invalid')
                self.assertEqual(tree(self.root / positive.output), reused, 'a reused output was overwritten')
        self.assertEqual(len(probe.entries()), allocated, 'a preflight guard allocated or used a native client')
        with self.subTest(case='require-actual-id'):
            run = self.launch_entry(install_root, 'actual-id', require_actual_id='true')
            self.assert_entry_rejected(install_root, run, 'actual-id-unavailable')
            self.assert_blocked_before_thread(run)

    def test_codex_entry_rejects_generated_config_drift_before_thread_start(self):
        install_root = self.install('pwsh')
        baseline = self.launch_entry(install_root, 'baseline')
        value = self.assert_entry_accepted(install_root, baseline)  # fresh success precedes every mutation
        resolved = value['selection']['resolved']
        other_effort = next(effort for effort in launch.EFFORTS if effort != resolved['effort'])

        def key_line(key, end='$'):
            return r'(?m)^' + key + r'[ \t]*=.*' + end

        cases = [
            ('wrong-model', [{'sub': [key_line('model'), 'model = "wrong-fixture-model"']}], False),
            ('wrong-effort', [{'sub': [key_line('model_reasoning_effort'),
                                       'model_reasoning_effort = "' + other_effort + '"']}], False),
            ('runtime-keys-removed-comments-kept',
             [{'sub': [key_line('model', r'\r?\n'), '']},
              {'sub': [key_line('model_reasoning_effort', r'\r?\n'), '']},
              {'prepend': '# x-sdd-model: ' + resolved['native_id'] + '\n# x-sdd-effort: ' + resolved['effort'] + '\n'}],
             False),
            ('altered-instructions',
             [{'sub': [r'''(?m)^(developer_instructions[ \t]*=[ \t]*["']{1,3})''',
                       r'\g<1>ALTERED FIXTURE INSTRUCTIONS ']}], False),
            ('sandbox-workspace-write', [{'sub': [key_line('sandbox_mode'), 'sandbox_mode = "workspace-write"']}],
             False),
            ('comment-only-raw-drift', [{'append': '\n# comment-only raw drift after generation\n'}], True),
        ]
        for label, ops, comment_only in cases:
            with self.subTest(case=label):
                run = self.launch_entry(install_root, label, mutation={'edits': [{'target': 'agent.toml', 'ops': ops}]})
                self.assert_entry_rejected(install_root, run, 'config-conflict')
                mark = self.assert_mutated(run, ['agent.toml'])
                self.assertIs(mark['edits'][0]['semantic_same'], comment_only,
                              'only the comment-only case may leave the parsed configuration unchanged')
                self.assertFalse(mark['account_changed'])
                self.assert_blocked_before_thread(run)

    def test_codex_entry_rejects_context_or_pinned_input_drift(self):
        install_root = self.install('bash')
        baseline = self.launch_entry(install_root, 'baseline')
        self.assert_entry_accepted(install_root, baseline)  # fresh success precedes every mutation
        cases: list[tuple[str, dict[str, Any], str, tuple[str, ...], tuple[str, ...]]] = [
            ('account-context', {'account': OTHER_ACCOUNT, 'edits': []}, 'scope-mismatch', (), ())]
        for target in ('policy', 'request', 'observation.json', 'selection.json', 'controls.json'):
            cases.append(('pinned-' + target.split('.')[0],
                          {'edits': [{'target': target, 'ops': [{'append': '\n'}]}]}, 'input-invalid',
                          (target,), (target,)))
        for label, mutation, reason, labels, rewritten in cases:
            with self.subTest(case=label):
                run = self.launch_entry(install_root, label, mutation=mutation)
                changed = {'policy': 'policy-' + label + '.json', 'request': run.request}
                self.assert_entry_rejected(install_root, run, reason,
                                           changed={changed[target] for target in rewritten if target in changed})
                mark = self.assert_mutated(run, labels)
                self.assertIs(mark['account_changed'], label == 'account-context')
                self.assert_blocked_before_thread(run)

    def test_codex_entry_rejects_native_response_mismatches_without_turns(self):
        install_root = self.install('pwsh')
        baseline = self.launch_entry(install_root, 'baseline')
        value = self.assert_entry_accepted(install_root, baseline)  # fresh success precedes every response variant
        resolved = value['selection']['resolved']
        other_effort = next(effort for effort in launch.EFFORTS if effort != resolved['effort'])
        turn = {'id': 'turn-fixture-1', 'items': [], 'status': 'completed'}
        cases = [
            ('model', [{'path': ['model'], 'value': 'gpt-fixture-other'}], 'config-conflict'),
            ('effort', [{'path': ['reasoningEffort'], 'value': other_effort}], 'config-conflict'),
            ('effort-missing', [{'path': ['reasoningEffort'], 'delete': True}], 'config-conflict'),
            ('effort-null', [{'path': ['reasoningEffort'], 'value': None}], 'config-conflict'),
            ('cwd', [{'path': ['cwd'], 'value': str(self.base / 'other-project')}], 'config-conflict'),
            ('approval-policy', [{'path': ['approvalPolicy'], 'value': 'on-request'}], 'config-conflict'),
            ('sandbox-type', [{'path': ['sandbox'], 'value': {'type': 'dangerFullAccess'}}], 'config-conflict'),
            ('sandbox-network', [{'path': ['sandbox'], 'value': {'type': 'readOnly', 'networkAccess': True}}],
             'config-conflict'),
            ('thread-id-empty', [{'path': ['thread', 'id'], 'value': ''}], 'config-conflict'),
            ('thread-turns-nonempty', [{'path': ['thread', 'turns'], 'value': [turn]}], 'config-conflict'),
        ]
        for label, patch, reason in cases:
            with self.subTest(case=label):
                run = self.launch_entry(install_root, label, thread={'patch': patch})
                self.assert_entry_rejected(install_root, run, reason)
                self.assert_response_rejected(run, resolved)
        with self.subTest(case='json-rpc-error'):
            error = {'code': -32603, 'message': 'fixture thread/start failure'}
            run = self.launch_entry(install_root, 'rpc-error', thread={'error': error})
            self.assert_entry_rejected(install_root, run, 'discovery-unavailable')
            self.assert_response_rejected(run, resolved)

    def assert_response_rejected(self, run, resolved):
        """Post-send failure: exactly one thread/start for the intended config, never a turn, no success artifact."""
        starts = run.probe.starts()
        self.assertEqual(len(starts), 1, 'exactly one thread/start precedes a response rejection')
        self.assertEqual(starts[0]['message']['params']['model'], resolved['native_id'])
        self.assertEqual(starts[0]['message']['params']['cwd'], str(self.root))
        self.assertLessEqual(set(run.probe.methods()), NATIVE_METHODS, 'no turn or thread method beyond thread/start')
        self.assertEqual(run.probe.entries('mutation'), [])
        self.assertFalse((self.root / run.output / 'validation.json').exists())
        self.assert_reaped(run.probe)


# Additive T-008 maintained caller tests. Insert before the existing unittest.main guard.
# Uses the existing module imports/constants and composes (never inherits) the T-007 fixture.
CALLER_SKILL = 'plugins/sdd-quality-loop/skills/cross-model-verify/SKILL.md'
CALLER_SCRIPTS = 'plugins/sdd-quality-loop/scripts/'
CALLER_DRIVER = 'plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py'
CALLER_RUNTIME = sorted({CALLER_DRIVER, CALLER_SKILL,
    *(CALLER_SCRIPTS + name for name in ('run-panelist-gpt.sh', 'run-panelist-gpt.ps1',
        'run-panelist-gemini.sh', 'run-panelist-gemini.ps1', 'prepare-panelist-input.sh',
        'prepare-panelist-input.ps1', 'lib/panelist-common.sh', 'emit-run-record.sh', 'emit-run-record.ps1'))})


class InstalledPanelistCallerTests(unittest.TestCase):
    """Execute maintained fences with real installed preparation/consent/runners and a recording native CLI."""

    def fixture(self, shell):
        self.assertTrue(PWSH and os.access(PWSH, os.X_OK), 'Official PowerShell is required for both-shell coverage')
        f = launch.SelectedPanelistLaunch(methodName='runTest')
        self.addCleanup(f.doCleanups)
        f.setUp()
        f.helper()  # keep the unchanged policy oracle in its separate source-copied fixture
        oracle = f.root
        project = f.base / 'unrelated-project'
        project.mkdir()
        for name in ('request.json', 'registry.json', 'policy.json', 'observation.json',
                     'gpt-fixture-adoption.json', 'raw-input.txt'):
            shutil.copyfile(oracle / name, project / name)
        shutil.copytree(oracle / 'specs', project / 'specs')
        f.root = project
        f.tasks = project / 'specs' / f.FEATURE / 'tasks.md'
        f.bundle = f.tasks.parent / 'verification' / (f.TASK + '.panelist-input.txt')
        f.bundle.parent.mkdir(parents=True, exist_ok=True)
        f.bundle.write_bytes(f.original_bundle)
        (project / 'runs').mkdir()
        self.assertFalse((project / 'plugins').exists(), 'Execution inputs must contain no runtime fallback')
        self.assertFalse((project / 'contracts').exists(), 'Execution inputs must contain no trusted runtime copy')
        f.home = f.base / 'caller-home'
        (f.home / '.codex').mkdir(parents=True)
        (f.home / '.codex/config.toml').write_text('# caller native configuration canary\n')
        f.codex_home = tree(f.home / '.codex')
        f.poison = f.base / 'caller-source-fallback'
        f.environment.update(HOME=str(f.home), SDD_CODEX_HOME=str(f.home / '.codex'),
                             SDD_CURSOR_DIR=str(f.base / 'cursor-absent'),
                             SDD_VSCODE_USER_DIR=str(f.base / 'vscode-absent'), SDD_TEST_PWSH=str(PWSH),
                             GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL=os.devnull, GIT_TERMINAL_PROMPT='0')
        package = f.base / 'caller-package'
        package.mkdir()
        empty = f.base / 'empty-git-template'
        empty.mkdir()
        for relative in sorted(set(PACKAGE) | set(CALLER_RUNTIME)):
            source, target = ROOT / relative, package / relative
            self.assertTrue(source.is_file(), 'Admitted package input missing: ' + relative)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
        for args in (['init', '-q', '--template=' + str(empty)], ['add', '--all'],
                     ['-c', 'user.name=Caller Fixture', '-c', 'user.email=caller@example.invalid',
                      '-c', 'gc.auto=0', 'commit', '-qm', 'Explicit current caller package']):
            result = f.run_process(['git', '-C', str(package), *args], label='caller package setup')
            self.assertEqual(result.returncode, 0, 'Package setup failed: ' + result.stderr[-1200:])
        installed = f.base / ('caller-installed-' + shell)
        result = InstalledEntryTests.run_installer(f, shell, package, installed)
        self.assertEqual(result.returncode, 0, 'Installer setup failed: ' + result.stderr[-1600:])
        for relative in sorted(set(MANAGED_RUNTIME) | set(CALLER_RUNTIME)):
            self.assertTrue((installed / relative).is_file(), 'Installed caller runtime is missing: ' + relative)
            self.assertEqual(launch.sha_file(installed / relative), launch.sha_file(ROOT / relative))
        # The installed consent authorities are original product bytes, not the T-007 audit forwarding wrappers.
        InstalledEntryTests.poison_source(f, package)
        f.scripts = installed / CALLER_SCRIPTS
        return f, installed

    def snippet(self, installed, vendor, shell):
        """The maintained skill is the oracle; no replacement implementation excerpt is authored by the test."""
        source = (installed / CALLER_SKILL).read_text(encoding='utf-8')
        heading = '**GPT panelist**' if vendor == 'gpt' else '**Gemini panelist**'
        self.assertIn(heading, source)
        section = source.split(heading, 1)[1]
        if vendor == 'gpt':
            section = section.split('**Gemini panelist**', 1)[0]
        else:
            section = section.split('Each runner writes', 1)[0]
        languages = ('sh', 'bash') if shell == 'bash' else ('powershell', 'pwsh', 'ps1')
        choices = [body for language, body in re.findall(r'```([^\s`]*)[^\n]*\n(.*?)\n```', section, re.S)
                   if language.lower() in languages and 'run-panelist-' + vendor in body]
        self.assertEqual(len(choices), 1, 'Expected one maintained ' + shell + ' ' + vendor + ' command fence')
        return choices[0]

    def run_snippet(self, f, installed, shell, label, *, vendor='gpt', request=None,
                    stale=False, consent='enabled', mutation=None):
        f.request.update(role='panelist-' + vendor, host='codex-cli' if vendor == 'gpt' else 'gemini-cli',
                         requested_effort='high', cli={'model_id': 'gpt-6-astra', 'policy': 'pinned'})
        f.request.update(request or {})
        f.observation = f.fresh_observation('2000-01-01T00:00:00Z' if stale else None)
        if vendor == 'gemini':
            f.observation.update(host='gemini-cli', cli_version='fixture-gemini-cli', models=[])
        f.save()
        f.task_consent(consent == 'enabled' or consent == 'changed-task',
                       task='T-999' if consent == 'changed-task' else None)
        (f.root / 'SDD_SUDO').unlink(missing_ok=True)
        if consent in ('sudo', 'sudo-invalid'):
            f.signed_sudo()
            f.prepare_bundle()
            f.original_bundle = f.bundle.read_bytes()
            if consent == 'sudo-invalid':
                f.signed_sudo(valid=False)
        f.audit.unlink(missing_ok=True)
        f.verdict_path(vendor).unlink(missing_ok=True)
        f.session_id = str(uuid.uuid4())
        output = 'runs/' + label
        text = self.snippet(installed, vendor, shell)
        replacements = {'<T-NNN>': f.TASK, '<feature>': f.FEATURE, '<policy-request>': 'request.json',
                        '<registry>': 'registry.json', '<run-id>': f.run_id, '<session-id>': f.session_id,
                        '<output-dir>': output}
        for old, new in replacements.items():
            text = text.replace(old, new)
        for relative in [ADAPTER, *CALLER_RUNTIME]:
            text = text.replace(relative, str(installed / relative))
        self.assertIsNone(re.search(r'<[A-Za-z][A-Za-z0-9_-]*>', text), 'Undocumented fixture placeholder')
        runner = str(installed / (CALLER_SCRIPTS + 'run-panelist-' + vendor +
                                  ('.sh' if shell == 'bash' else '.ps1')))
        if mutation:
            lines = text.splitlines(keepends=True)
            indexes = [index for index, line in enumerate(lines) if runner in line]
            self.assertEqual(len(indexes), 1, 'Mutation needs the actual maintained runner invocation')
            index = indexes[0]
            if mutation == 'remove-forwarding':
                tail = ''.join(lines[index:])
                pattern = r'--(?:model-controls-sha256|model-controls|run-id|session-id)\s+(?:"[^"\n]*"|\x27[^\x27\n]*\x27|[^\s`\\]+)'
                tail, count = re.subn(pattern, '', tail)
                self.assertEqual(count, 4, 'Mutation must remove exactly the four runner controls, leaving prepare intact')
                text = ''.join(lines[:index]) + tail
            elif mutation == 'raw-control-drift':
                target = output + '/controls.json'
                if shell == 'bash':
                    injection = 'printf "\\n" >> ' + shlex.quote(target) + '\n'
                else:
                    injection = '[System.IO.File]::AppendAllText(\'' + target + '\', "`n")\n'
                text = ''.join(lines[:index]) + injection + ''.join(lines[index:])
            else:
                self.fail('Unknown deliberate snippet mutation')
        script = f.base / ('caller-' + label + ('.sh' if shell == 'bash' else '.ps1'))
        script.write_text(text + '\n')
        command = [launch.BASH, str(script)] if shell == 'bash' else [PWSH, '-NoProfile', '-File', str(script)]
        installed_before = runtime_tree(installed)
        result = f.run_process(command, timeout=120, label='maintained ' + shell + ' panelist snippet')
        self.assertFalse(f.poison.exists(), 'Caller used the poisoned source package')
        self.assertEqual(runtime_tree(installed), installed_before, 'Caller changed installed runtime')
        self.assertFalse((f.root / 'plugins').exists(), 'Caller copied runtime into the execution-input project')
        self.assertFalse((f.root / 'contracts').exists(), 'Caller copied trusted runtime into the project')
        self.assertEqual(tree(f.home / '.codex'), f.codex_home, 'Caller changed user native configuration')
        return result, output

    def accepted(self, f, result, output, *, consent='human-flag'):
        self.assertEqual(result.returncode, 0, 'Valid maintained snippet failed: ' + result.stderr[-1800:])
        self.assertTrue(f.audit.is_file(), 'Valid snippet never reached the recording native CLI')
        self.assertTrue(f.verdict_path().is_file(), 'Valid snippet did not publish a verdict')
        # Baseline valid Bash legacy command reaches this meaningful missing-managed-output assertion first.
        directory = f.root / output
        self.assertTrue((directory / 'controls.json').is_file(), 'Maintained caller omitted installed prepare controls')
        self.assertTrue((directory / 'selection.json').is_file(), 'Maintained caller omitted a bound selection')
        self.assertTrue((directory / 'validation.json').is_file(), 'Maintained caller omitted real controls validation')
        controls = json.loads((directory / 'controls.json').read_bytes())
        selection = json.loads((directory / 'selection.json').read_bytes())
        validation = json.loads((directory / 'validation.json').read_bytes())
        expected_inputs = sorted({'policy.json', 'observation.json', 'gpt-fixture-adoption.json'})
        def ref(path):
            return {'path': path, 'sha256': launch.sha_file(f.root / path)}
        self.assertEqual(controls, {'schema': 'model-launch-controls/v1', 'role': 'panelist-gpt', 'host': 'codex-cli',
            'attempt': 1, 'require_actual_id': False, 'selection': ref(output + '/selection.json'),
            'request': ref('request.json'), 'registry': ref('registry.json'),
            'inputs': [ref(path) for path in expected_inputs]})
        self.assertEqual(set(validation), launch.VALIDATION_FIELDS)
        self.assertEqual(validation['schema'], 'model-launch-validation/v1')
        self.assertEqual(validation['controls'], ref(output + '/controls.json'))
        self.assertEqual(validation['pins'], sorted([controls['selection'], controls['request'], controls['registry'],
                                                    *controls['inputs']], key=lambda item: item['path']))
        self.assertEqual(validation['trusted'], [{'path': path, 'sha256': launch.sha_file(f.scripts.parents[2] / path)}
                                                 for path in launch.TRUSTED_PATHS])
        self.assertEqual(validation['selection'], selection)
        self.assertEqual(selection['binding'], {'run_id': f.run_id, 'session_id': f.session_id, 'attempt': 1})
        self.assertEqual((selection['resolved']['catalog_id'], selection['resolved']['native_id'],
                          selection['resolved']['effort']), ('gpt-6-astra', 'gpt-6-astra', 'high'))
        verdict, audit = json.loads(f.verdict_path().read_bytes()), json.loads(f.audit.read_bytes())
        self.assertIn('model_policy', verdict, 'Maintained caller did not forward selected controls')
        policy = verdict['model_policy']
        self.assertEqual(policy['selection'], selection, 'Runner verdict must bind the exact prepared selection')
        self.assertEqual(policy['transport'], 'codex-exec')
        self.assertEqual(policy['actor_slot'], 'reviewers')
        self.assertIsNone(policy['delivery']['actual_id'])
        self.assertEqual(policy['delivery']['proof'], 'unverified')
        argv = audit['argv']
        self.assertIn('-C', argv)
        scratch = argv[argv.index('-C') + 1]
        self.assertEqual(argv, ['exec', '--model', 'gpt-6-astra', '-c', 'model_reasoning_effort=high',
                               '--sandbox', 'read-only', '--skip-git-repo-check', '-C', scratch, '-'])
        self.assertEqual(audit['cwd'], scratch)
        self.assertNotEqual(Path(scratch), f.root)
        self.assertFalse(Path(scratch).exists(), 'Native scratch leaked')
        self.assertFalse(any(audit['key_presence'].values()))
        self.assertIn(f.original_bundle.decode(), audit['stdin'])
        self.assertEqual(audit['stdin'].count('# Panelist Input Bundle'), 1)
        self.assertEqual(verdict['consent']['kind'], consent)
        self.assertEqual(verdict['model'], 'fixture-self-report-not-attested')

    def rejected(self, f, result, reasons, vendor='gpt'):
        self.assertEqual(result.returncode, 2, 'Expected typed failure: ' + result.stderr[-1600:])
        error = json.loads(result.stderr)
        self.assertEqual(error['schema'], 'model-policy-error/v1')
        self.assertIn(error['reason'], reasons)
        self.assertFalse(f.audit.exists(), 'Rejected preparation or consent reached a native CLI')
        self.assertFalse(f.verdict_path(vendor).exists(), 'Rejected caller published a verdict')
        return error

    def test_maintained_panelist_snippets_prepare_and_forward_installed_controls(self):
        for shell in SHELLS:
            with self.subTest(shell=shell):
                f, installed = self.fixture(shell)
                result, output = self.run_snippet(f, installed, shell, 'happy')
                self.accepted(f, result, output)
                result, output = self.run_snippet(f, installed, shell, 'missing-forwarding', mutation='remove-forwarding')
                # Deliberately remove only runner forwarding from the actual maintained command. Legacy standalone
                # runner compatibility remains valid, but that legacy result cannot satisfy the managed oracle.
                self.assertEqual(result.returncode, 0, result.stderr[-1200:])
                self.assertTrue(f.audit.is_file())
                with self.assertRaises(AssertionError):
                    self.accepted(f, result, output)
                self.assertNotIn('model_policy', json.loads(f.verdict_path().read_bytes()))

    def test_maintained_panelist_snippets_stop_on_preparation_failure(self):
        for shell in SHELLS:
            with self.subTest(shell=shell):
                f, installed = self.fixture(shell)
                result, output = self.run_snippet(f, installed, shell, 'positive')
                self.accepted(f, result, output)
                cases = [('wrong-role', {'role': 'investigator'}, False, {'model-unverified'}),
                         ('wrong-host', {'host': 'claude-code'}, False, {'scope-mismatch'}),
                         ('stale-observation', {}, True, {'discovery-stale'})]
                for label, request, stale, reasons in cases:
                    with self.subTest(case=label):
                        result, output = self.run_snippet(f, installed, shell, label, request=request, stale=stale)
                        self.rejected(f, result, reasons)
                        self.assertFalse((f.root / output / 'validation.json').exists())
                result, output = self.run_snippet(f, installed, shell, 'raw-control-drift', mutation='raw-control-drift')
                self.rejected(f, result, {'input-invalid'})
                self.assertTrue((f.root / output / 'validation.json').is_file(), 'Mutation must follow real prepare')

    def test_maintained_panelist_snippets_preserve_consent_and_typed_unsupported_host(self):
        for shell in SHELLS:
            with self.subTest(shell=shell):
                f, installed = self.fixture(shell)
                result, output = self.run_snippet(f, installed, shell, 'positive')
                self.accepted(f, result, output)
                for consent in ('disabled', 'changed-task'):
                    with self.subTest(consent=consent):
                        result, output = self.run_snippet(f, installed, shell, 'consent-' + consent, consent=consent)
                        error = self.rejected(f, result, {'input-invalid'})
                        self.assertIn('consent', error['message'].lower())
                result, output = self.run_snippet(f, installed, shell, 'consent-sudo', consent='sudo')
                self.accepted(f, result, output, consent='sudo')
                result, output = self.run_snippet(f, installed, shell, 'consent-sudo-invalid', consent='sudo-invalid')
                error = self.rejected(f, result, {'input-invalid'})
                self.assertIn('consent', error['message'].lower())
                result, output = self.run_snippet(f, installed, shell, 'gemini', vendor='gemini')
                self.rejected(f, result, {'model-unavailable'}, vendor='gemini')
                self.assertFalse((f.root / output / 'selection.json').exists(), 'Gemini must not receive a fake selection')
                self.assertFalse((f.root / output / 'validation.json').exists())


if __name__ == '__main__':
    unittest.main()
