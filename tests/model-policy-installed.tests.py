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
PACKAGE = sorted({'install.sh', 'install.ps1', *INSTALLER_REQUIRED, *MANAGED_RUNTIME, *launch.COPIED, launch.TRANSPORT_SCRIPT.relative_to(ROOT).as_posix()})
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
    extra_runtime: tuple[str, ...] = ()  # additional real runtime files packaged before install; default is the minimal PACKAGE

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
        self.environment.update(HOME=str(self.home), CLAUDE_CONFIG_DIR=str(self.home / '.claude'),
                                XDG_DATA_HOME=str(self.home / '.local/share'),
                                SDD_CODEX_HOME=str(codex), SDD_CURSOR_DIR=str(self.base / 'cursor-absent'),
                                SDD_VSCODE_USER_DIR=str(self.base / 'vscode-absent'),
                                GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL=os.devnull, GIT_TERMINAL_PROMPT='0')

    # ---- actual installers over a minimal current-byte package -------------------------------------------------

    def build_package(self, label, omit=None):
        """Explicit current working-tree byte overlay, Git-tracked only inside this disposable source."""
        package = self.base / ('package-' + label)
        package.mkdir()
        extra = getattr(self, 'extra_runtime', ())  # InstalledNativeEntryTests aliases this helper without the option
        for rel in [*PACKAGE, *extra]:
            if rel in MANAGED_RUNTIME or rel in extra:
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
        for rel in MANAGED_RUNTIME + sorted(CODEX) + list(getattr(self, 'extra_runtime', ())):
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
                attempt='1', require_actual_id='false', mode='prepare', extra=(), env=None):
        command = [sys.executable, '-I', '-B', str(install_root / ADAPTER), mode, '--request', 'request.json',
                   '--registry', 'registry.json', '--role', role, '--host', host,
                   '--run-id', self.run_id if run_id is None else run_id,
                   '--session-id', self.session_id if session_id is None else session_id,
                   '--attempt', attempt, '--output-dir', output, '--require-actual-id', require_actual_id, *extra]
        result = self.run_process(command, env, timeout=120, label='installed prepare entry')
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

    def assert_prepared(self, install_root, output, *, role='evaluator', host=launch.HOST, attempt=1, **entry):
        """Complete positive: exact outputs, every raw pin, installed trusted bytes and the T-007 recomputation."""
        project, installed = tree(self.root), runtime_tree(install_root)
        value = self.accepted(self.prepare(install_root, output, role=role, host=host, attempt=str(attempt), **entry))
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


# ---- T-008 ordinary Claude preparation: observation-preserving claude-prepare, configuration only -----------------
# Proposed public surface (requires primary admission before product work); cwd is the execution-input root:
#   python3 -I -B <installed>/plugins/sdd-implementation/scripts/managed-model-entry.py claude-prepare
#       <the nine prepare options> --executable ABS          (host claude-code; investigator first)
# Oracle: the installed prepare plus the unchanged real selector and T-007 launch-controls CLIs over the same project
# bytes. The entry consumes the request's supplied observation UNCHANGED, observes only the executable's --help/--version
# and the seven T-007 native override keys, and publishes only selection/controls/validation. Evidence class: FIXTURE ONLY
# (verified-configuration observation, fixture adoption, discovery-only fixture CLI). Nothing here shows Claude availability,
# provenance authentication, managed/remote policy, native allocation, an actual backend ID or a ready_to_launch claim.
CLAUDE_DRIVER = 'plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py'
ENV_CANARY = 'SDD_UNRELATED_ENVIRONMENT_CANARY'
ENV_CANARY_VALUE = 'unrelated-environment-canary-value'
# Discovery-only fixture CLI: logs every invocation, answers only --help/--version, any other argv is model work.
CLAUDE_CLI = '''#!/bin/sh
printf '%s\\n' "$*" >> {calls}
case "$*" in
--help) printf '%s' {help}{edit}; exit {help_exit} ;;
--version) printf '%s\\n' {version}; exit {version_exit} ;;
*) printf '%s\\n' "$0 $*" >> {work}; exit 97 ;;
esac
'''


class InstalledClaudePreparationTests(unittest.TestCase):
    """claude-prepare over an actual InstalledEntryTests instance: its genuine setUp, helpers and cleanups."""

    def setUp(self):
        self.case = case = InstalledEntryTests('runTest')  # composed, never aliased: no inherited test methods
        self.addCleanup(lambda: self.assertTrue(case.doCleanups(), 'composed InstalledEntryTests cleanup failed'))
        case.extra_runtime = (CLAUDE_DRIVER,)  # the original driver joins the fixture package BEFORE install
        case.setUp()
        case.request = case.fresh_request('investigator')
        case.environment[ENV_CANARY] = ENV_CANARY_VALUE
        case.save()
        self.assertFalse(set(launch.NATIVE_OVERRIDES) & set(case.environment), 'baseline carries a native override')
        self.serial = 0
        self.calls, self.work = case.base / 'claude-cli-calls', case.base / 'claude-cli-work'
        self.executable = case.base / 'claude-cli' / 'claude'
        self.write_cli()
        for path in (case.home / '.claude/settings.json', case.home / '.claude.json',
                     case.home / '.claude/projects/canary/session.jsonl', case.root / '.claude/settings.json',
                     case.root / '.claude/settings.local.json'):
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('{"x-sdd-canary": "%s: claude-prepare must neither read-modify nor write it"}\n' % path.name)
        self.home_before = tree(case.home)

    # ---- discovery-only fixture CLI and fixture-wide invariants ------------------------------------------------

    def write_cli(self, *, version=None, help_text=None, self_edit=False, help_exit=0, version_exit=0):
        script = CLAUDE_CLI.format(
            calls=shlex.quote(str(self.calls)), work=shlex.quote(str(self.work)),
            help=shlex.quote(launch.HELP_TEXT if help_text is None else help_text),
            version=shlex.quote(self.case.observation['cli_version'] if version is None else version),
            edit=" ; printf '# self-edit\\n' >> \"$0\"" if self_edit else '',
            help_exit=help_exit, version_exit=version_exit)
        self.executable.parent.mkdir(parents=True, exist_ok=True)
        self.executable.write_text(script)
        self.executable.chmod(0o755)

    def reset_calls(self):
        self.calls.unlink(missing_ok=True)

    def cli_calls(self):
        return self.calls.read_text().splitlines() if self.calls.exists() else []

    def assert_discovery_only(self):
        self.assertFalse(self.work.exists(), 'a model or work invocation reached the fixture CLI')
        self.assertFalse(self.case.marker.exists(), 'a native model executable was invoked')
        self.assertLessEqual(set(self.cli_calls()), {'--help', '--version'})

    def assert_unchanged_world(self):
        case = self.case
        self.assertEqual(tree(case.home), self.home_before, 'user or native Claude/Codex state changed')
        leaked = [path for path in tree(case.root) if ENV_CANARY_VALUE.encode() in (case.root / path).read_bytes()]
        self.assertEqual(leaked, [], 'unrelated environment values were written')

    def output(self):
        self.serial += 1
        return 'runs/case-%02d' % self.serial

    def install(self, shell):
        install_root = self.case.install(shell)  # both official installers; source is poisoned afterwards
        self.assertEqual(launch.sha_file(install_root / CLAUDE_DRIVER), launch.sha_file(ROOT / CLAUDE_DRIVER),
                         'the installed original driver must be the current bytes')
        return install_root

    def entry(self, env=None):
        return {'role': 'investigator', 'mode': 'claude-prepare', 'extra': ('--executable', str(self.executable)),
                'env': env}

    def claude_positive(self, install_root, output, *, env=None):
        """Complete positive through the new mode: the actual prepare oracle plus discovery-only CLI use."""
        self.reset_calls()
        value = self.case.assert_prepared(install_root, output, **self.entry(env))
        self.assertEqual(set(self.cli_calls()), {'--help', '--version'},
                         'the entry must observe only the actual executable help and version')
        self.assert_discovery_only()
        self.assert_unchanged_world()
        return value

    def claude_rejected(self, install_root, output, reasons, *, env=None):
        self.reset_calls()
        error = self.case.assert_prepare_rejected(install_root, output, reasons, **self.entry(env))
        self.assertFalse((self.case.root / output / 'validation.json').exists())
        self.assertNotIn(ENV_CANARY_VALUE, error['message'])
        self.assert_discovery_only()
        self.assert_unchanged_world()
        return error

    def assert_corresponding(self, legacy, new):
        """Existing prepare and claude-prepare outputs differ only by their deliberate output path and hash."""
        helper, root = self.case.helper(), self.case.root
        old = {name: helper.strict_json((root / legacy / name).read_bytes()) for name in OUTPUT_FILES}
        now = {name: helper.strict_json((root / new / name).read_bytes()) for name in OUTPUT_FILES}
        self.assertEqual((root / legacy / 'selection.json').read_bytes(), (root / new / 'selection.json').read_bytes())
        for name, deliberate in (('controls.json', {'selection'}), ('validation.json', {'controls', 'pins'})):
            self.assertEqual({k: v for k, v in old[name].items() if k not in deliberate},
                             {k: v for k, v in now[name].items() if k not in deliberate}, name)
        self.assertEqual(now['controls.json']['selection'], self.case.ref(new + '/selection.json'))
        self.assertEqual(old['controls.json']['selection']['sha256'], now['controls.json']['selection']['sha256'])

        def others(output, pins):
            return [pin for pin in pins if pin['path'] != output + '/selection.json']

        self.assertEqual(others(legacy, old['validation.json']['pins']), others(new, now['validation.json']['pins']))

    # ---- the four bounded acceptance methods -----------------------------------------------------------------

    def test_claude_prepare_preserves_supplied_observation_and_core_evidence(self):
        case = self.case
        names = ('request.json', 'registry.json', 'policy.json', 'observation.json')
        raw, observation = {name: (case.root / name).read_bytes() for name in names}, copy.deepcopy(case.observation)
        for shell in SHELLS:
            install_root = self.install(shell)
            self.reset_calls()
            legacy = case.assert_prepared(install_root, 'runs/prepare-' + shell, role='investigator')
            self.assertEqual(self.cli_calls(), [], 'the existing prepare must not run the external CLI')
            value = self.claude_positive(install_root, 'runs/claude-' + shell)
            self.assert_corresponding('runs/prepare-' + shell, 'runs/claude-' + shell)
            self.assertEqual(value['selection'], legacy['selection'])
            self.assertEqual(value['selection']['observation_sha256'], observation['observation_sha256'])
            self.assertEqual({name: (case.root / name).read_bytes() for name in names}, raw,
                             'the supplied request, policy or observation bytes changed')
            self.assertEqual(case.helper().strict_json(raw['observation.json']), observation)
            self.assertEqual((observation['source'], observation['status']), ('verified-configuration', 'complete'))

    def test_claude_prepare_does_not_repair_unusable_observation(self):
        case = self.case
        install_root = self.install('bash')
        self.claude_positive(install_root, 'runs/positive')
        prior = tree(case.root / 'runs/positive')
        stale = launch.utc_now(launch.timedelta(seconds=-(case.policy['observation_max_age_seconds'] + 120)))
        # A well-formed forged record is outside what the core can reject; only existing typed reasons are claimed.
        cases = [('missing', None, 'input-invalid'),
                 ('stale', {'observed_at': stale}, 'discovery-stale'),
                 ('unsupported', {'source': 'unsupported', 'status': 'unavailable', 'models': []},
                  'discovery-unavailable'),
                 ('unavailable', {'status': 'unavailable', 'models': []}, 'discovery-unavailable'),
                 ('incomplete', {'status': 'incomplete'}, 'discovery-incomplete'),
                 ('relabelled-live', {'source': 'live-discovery', 'purpose': 'launch'}, 'scope-mismatch')]
        for label, changes, reason in cases:
            with self.subTest(observation=label):
                case.observation = dict(case.fresh_observation(), **(changes or {}))
                case.save()  # fixture code deliberately seals the unusable record; the product must not touch it
                if changes is None:
                    (case.root / 'observation.json').unlink()
                self.claude_rejected(install_root, self.output(), reason)
                self.assertEqual(tree(case.root / 'runs/positive'), prior, 'a prior positive changed')
        case.observation = case.fresh_observation()
        case.save()
        self.claude_positive(install_root, 'runs/recovered')

    def test_claude_prepare_checks_executable_and_environment_before_publication(self):
        case = self.case
        install_root = self.install('pwsh')
        self.claude_positive(install_root, 'runs/positive')
        prior, version = tree(case.root / 'runs/positive'), case.observation['cli_version']

        def without(prefix):
            return '\n'.join(line for line in launch.HELP_TEXT.split('\n') if not line.lstrip().startswith(prefix))

        cli_cases: list[tuple[str, dict[str, str | int | bool], str]] = [
            ('version-mismatch', {'version': 'fixture-claude 9.9'}, 'scope-mismatch'),
                     ('help-failure', {'help_exit': 7}, 'discovery-unavailable'),
                     ('version-failure', {'version_exit': 7}, 'discovery-unavailable'),
                     ('help-without-model', {'help_text': without('--model <model>')}, 'config-invalid'),
                     ('help-without-effort', {'help_text': launch.HELP_WITHOUT_EFFORT}, 'config-invalid'),
                     ('help-without-agents', {'help_text': without('--agents <json-or-file>')}, 'config-invalid'),
                     ('help-without-agent', {'help_text': without('--agent <agent>')}, 'config-invalid'),
                     ('version-empty', {'version': ''}, 'config-invalid'),
                     ('version-multiline', {'version': version + '\nsecond line'}, 'config-invalid'),
                     ('version-overlong', {'version': 'v' * 129}, 'config-invalid'),
                     ('self-edit-during-help', {'self_edit': True}, 'input-invalid')]
        for label, options, reason in cli_cases:
            with self.subTest(cli=label):
                if 'help_text' in options:
                    self.assertNotEqual(options['help_text'], launch.HELP_TEXT)
                self.write_cli(**options)
                original = self.executable.read_bytes()
                self.claude_rejected(install_root, self.output(), reason)
                if options.get('self_edit'):
                    self.assertIn('--help', self.cli_calls())
                    self.assertNotEqual(self.executable.read_bytes(), original, 'the fixture CLI did not self-edit')
                self.assertEqual(tree(case.root / 'runs/positive'), prior, 'a prior positive changed')
        self.write_cli()
        original_executable = self.executable
        linked = original_executable.with_name('claude-link')
        linked.symlink_to(original_executable)
        try:
            for path in (Path('relative/claude'), original_executable.with_name('missing'), linked):
                with self.subTest(executable=str(path)):
                    self.executable = path
                    self.claude_rejected(install_root, self.output(), 'input-invalid')
        finally:
            self.executable = original_executable
        resolved = case.oracle_selection()['resolved']
        native, effort = resolved['native_id'], resolved['effort']
        other_effort = next(item for item in launch.EFFORTS if item != effort)
        other_model = next(item for item in ('opus', 'sonnet', 'haiku') if item != native)
        conflicts = [('effort-mismatch', {'CLAUDE_CODE_EFFORT_LEVEL': other_effort}),
                     ('forced-subagent-mismatch', {'CLAUDE_CODE_SUBAGENT_MODEL_FORCE': '1',
                                                   'CLAUDE_CODE_SUBAGENT_MODEL': other_model}),
                     ('alias-remap', {'ANTHROPIC_DEFAULT_%s_MODEL' % native.upper(): 'claude-%s-fixture' % other_model})]
        for label, env in conflicts:
            with self.subTest(override=label):
                self.claude_rejected(install_root, self.output(), 'native-precedence-conflict', env=env)
        for label, env in (('equal-effort', {'CLAUDE_CODE_EFFORT_LEVEL': effort}),
                           ('equal-forced-subagent', {'CLAUDE_CODE_SUBAGENT_MODEL_FORCE': '1',
                                                      'CLAUDE_CODE_SUBAGENT_MODEL': native})):
            with self.subTest(override=label):
                self.claude_positive(install_root, self.output(), env=env)
        self.assertEqual(tree(case.root / 'runs/positive'), prior, 'a prior positive changed')

    def test_installers_require_original_driver_for_claude_prepare(self):
        case = self.case
        for shell in SHELLS:
            self.assertTrue((self.install(shell) / CLAUDE_DRIVER).is_file())  # actual positive with the driver
            with self.subTest(shell=shell, missing=CLAUDE_DRIVER):
                install_root = case.base / ('driver-missing-' + shell)
                package = case.build_package(shell + '-driver-missing', omit=CLAUDE_DRIVER)
                expected = {rel for rel in [*PACKAGE, *case.extra_runtime]
                            if rel != CLAUDE_DRIVER and (ROOT / rel).is_file()}
                present = {path.relative_to(package).as_posix() for path in package.rglob('*')
                           if path.is_file() and '.git' not in path.relative_to(package).parts}
                self.assertEqual(present, expected, 'only the original driver may be missing from this package')
                result = case.run_installer(shell, package, install_root)
                self.assertNotEqual(result.returncode, 0, 'installer accepted a package without ' + CLAUDE_DRIVER)
                self.assertNotIn('SDD plugins installed at:', result.stdout)
                self.assertFalse(install_root.exists(), 'claude-prepare was deployed without its original driver')


# ---- T-008 ordinary Claude local configuration authority: private collector/check/recheck, configuration only ------
# Private API of managed-model-entry.py (no public flag, no system-root override; production derives fixed paths):
#   _collect_local_authority(helper, sources, *, unresolved_tiers=()) -> snapshot dict
#   _check_local_authority(snapshot, native_id, effort, *, explicit_model=True, explicit_effort=True) -> verdict dict
#   _recheck_local_authority(helper, snapshot) -> {'reason': None | 'input-invalid', 'drift': [{'path', 'change'}]}
# Unit methods use owned fixture files and privately injected source descriptors; the fourth method drives both real
# installers and the installed entry. Evidence class: FIXTURE ONLY. No remote/MDM/WSL/parent/policyHelper adapter,
# availability producer or native-ready claim is exercised; only owned settings JSON is read, never .claude.json.
LOCAL_MANAGED = 'etc/claude-code/managed-settings.json'
LOCAL_DROPINS = 'etc/claude-code/managed-settings.d/'
LOCAL_USER, LOCAL_PROJECT = 'home/.claude/settings.json', 'repo/.claude/settings.json'
LOCAL_LOCAL = 'repo/.claude/settings.local.json'
LOCAL_FILES = (('managed', 'file', LOCAL_MANAGED), ('managed', 'dropin-dir', LOCAL_DROPINS.rstrip('/')),
               ('user', 'file', LOCAL_USER), ('project', 'file', LOCAL_PROJECT), ('local', 'file', LOCAL_LOCAL))
LOCAL_ALIASES = ('opus', 'sonnet', 'haiku')


class InstalledClaudeLocalAuthorityTests(unittest.TestCase):
    """Local authority checks over the composed InstalledClaudePreparationTests fixture (genuine setUp and cleanups)."""

    def setUp(self):
        self.prep = prep = InstalledClaudePreparationTests('runTest')  # composed, never aliased: no inherited tests
        self.addCleanup(lambda: self.assertTrue(getattr(prep, 'doCleanups')(), 'composed InstalledClaudePreparationTests cleanup failed'))
        prep.setUp()
        self.case = case = prep.case
        # Normalize without inspecting the inherited value: native-style lookup can only land in the owned HOME.
        case.environment['CLAUDE_CONFIG_DIR'] = str(case.home / '.claude')
        self.owned = case.base / 'local-authority'
        self.owned.mkdir()
        self.serial = 0
        resolved = case.oracle_selection()['resolved']
        self.native, self.effort = resolved['native_id'], resolved['effort']
        self.assertIn(self.native, LOCAL_ALIASES, 'fixture setup: trusted native alias expected')
        self.assertGreater(launch.EFFORTS.index(self.effort), 0, 'fixture setup: a lower effort level must exist')
        self.assertLess(launch.EFFORTS.index(self.effort), len(launch.EFFORTS) - 1, 'fixture setup: a higher level must exist')
        self.lower = launch.EFFORTS[launch.EFFORTS.index(self.effort) - 1]
        self.higher = launch.EFFORTS[launch.EFFORTS.index(self.effort) + 1]
        self.api = {}
        self.others = [alias for alias in LOCAL_ALIASES if alias != self.native]

    # ---- owned source fixtures --------------------------------------------------------------------------------

    def fresh(self):
        self.serial += 1
        return self.owned / ('case-%02d' % self.serial)

    def put(self, base, rel, document=None, raw=None):
        path = base / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(raw if raw is not None else json.dumps(document, sort_keys=True).encode() + b'\n')
        return path

    def sources(self, base, extra=()):
        return [{'tier': tier, 'kind': kind, 'path': str(base / rel)} for tier, kind, rel in LOCAL_FILES] + list(extra)

    @staticmethod
    def injected(tier, document):
        """Hypothetical remote/MDM tier for composition only; it never authenticates or clears 'remote'."""
        return {'tier': tier, 'kind': 'injected', 'path': 'injected:' + tier, 'document': document}

    def private(self, name):
        if 'module' not in self.api:
            try:
                self.api['module'] = launch.load_module(ROOT / ADAPTER, 'local_authority_adapter')
            except Exception as error:  # a broken import is still the intended product RED, never a setup exception
                self.fail('the installed adapter cannot be loaded: %s' % type(error).__name__)
            self.addCleanup(sys.modules.pop, self.api['module'].__name__, None)
        function = getattr(self.api['module'], name, None)
        self.assertTrue(callable(function), 'private local-authority API is missing: ' + name)
        return function

    def collect(self, base, *, extra=(), unresolved=(), sources=None):
        snapshot = self.private('_collect_local_authority')(
            self.case.helper(), self.sources(base, extra) if sources is None else sources, unresolved_tiers=unresolved)
        self.assertIsInstance(snapshot, dict)
        self.assertIs(snapshot['effective_complete'], False, 'local files can never establish complete authority')
        return snapshot

    def check(self, snapshot, **options):
        before = copy.deepcopy(snapshot)
        verdict = self.private('_check_local_authority')(snapshot, self.native, self.effort, **options)
        self.assertEqual(snapshot, before, 'the check must not modify the captured snapshot')
        self.assertIs(verdict['effective_complete'], False, 'no complete effective/native-ready verdict is possible')
        return verdict

    def tree_of(self, base):
        return {p.relative_to(base).as_posix(): p.read_bytes() for p in base.rglob('*') if p.is_file() and not p.is_symlink()}

    @staticmethod
    def sorted_lists(authority):
        """Union lists carry no documented order; sorting also proves duplicates were removed."""
        return {key: sorted(value) if key == 'deniedModels' else value for key, value in authority.items()}

    # ---- the four bounded acceptance methods -----------------------------------------------------------------

    def test_local_authority_source_composition_preserves_documented_exceptions(self):
        native, (other, third) = self.native, self.others
        picker_one = {'replaceBuiltInOptions': False, 'rows': [{'label': 'One', 'model': native}]}
        picker_two = {'replaceBuiltInOptions': True, 'rows': [{'label': 'Two', 'model': other}]}
        main = {'model': native, 'deniedModels': ['a'], 'env': {'A': '1', 'B': '1'}, 'fallbackModel': ['x', 'y'],
                'modelPicker': picker_one, 'modelSettings': {native: {'maxEffortLevel': 'high'}},
                'permissions': {'allow': ['unrelated']}, 'x-sdd-canary': 'unrelated ordinary key'}
        first = {'model': other, 'deniedModels': ['b', 'a'], 'env': {'B': '2', 'C': '3'}, 'fallbackModel': ['z'],
                 'modelPicker': picker_two, 'modelSettings': {native: {'effortLevel': 'high'}, other: {'effortLevel': 'low'}}}
        second = {'deniedModels': ['c'], 'maxEffortLevel': 'high'}
        composed = {'model': other, 'deniedModels': ['a', 'b', 'c'], 'env': {'A': '1', 'B': '2', 'C': '3'},
                    'fallbackModel': ['z'], 'modelPicker': picker_two, 'maxEffortLevel': 'high',
                    'modelSettings': {native: {'maxEffortLevel': 'high', 'effortLevel': 'high'}, other: {'effortLevel': 'low'}}}
        table: list[tuple[str, dict | None, list[tuple[str, dict]], dict, list[str]]] = [  # file-tier composition
            ('main-then-ordered-dropins', main, [('10-a.json', first), ('20-b.json', second)], composed,
             ['', '10-a.json', '20-b.json']),
            ('alphabetical-not-creation-order', {'model': native}, [('20-b.json', {'model': third}), ('10-a.json', {'model': other})],
             {'model': third}, ['', '10-a.json', '20-b.json']),
            ('later-scalar-replaces', {'model': native}, [('10-a.json', {'model': other})], {'model': other}, ['', '10-a.json']),
            ('fallback-whole-replacement', {'fallbackModel': ['a', 'b']}, [('10-a.json', {'fallbackModel': ['c']})],
             {'fallbackModel': ['c']}, ['', '10-a.json']),
            ('model-picker-whole-replacement', {'modelPicker': picker_one}, [('10-a.json', {'modelPicker': picker_two})],
             {'modelPicker': picker_two}, ['', '10-a.json']),
            ('hidden-and-nonjson-ignored', {'model': native},
             [('.hidden.json', {'model': third}), ('30-notes.txt', {'model': third}), ('40-x.json.bak', {'model': third})],
             {'model': native}, ['']),
            ('absent-main-with-dropin', None, [('10-a.json', {'deniedModels': ['q']})], {'deniedModels': ['q']}, ['10-a.json'])]
        for label, document, dropins, expected, order in table:
            with self.subTest(file_tier=label):
                base = self.fresh()
                if document is not None:
                    self.put(base, LOCAL_MANAGED, document)
                for name, content in dropins:
                    self.put(base, LOCAL_DROPINS + name, content)
                raw = self.tree_of(base)
                snapshot = self.collect(base)
                self.assertIsNone(snapshot['reason'], snapshot.get('failures'))
                self.assertEqual(self.sorted_lists(snapshot['tiers']['managed']), expected)
                considered = [str(base / (LOCAL_MANAGED if not name else LOCAL_DROPINS + name)) for name in order]
                self.assertEqual(snapshot['order'], considered, 'main file first, then nonhidden .json drop-ins alphabetically')
                self.assertEqual(snapshot['documents'], {path: launch.sha_bytes(Path(path).read_bytes()) for path in considered})
                self.assertEqual(self.tree_of(base), raw, 'collection must not write, repair or rename a source')
        admin_file = {'model': native, 'deniedModels': ['x'], 'env': {'X': 'file', 'Y': 'file'}, 'maxEffortLevel': self.effort}
        cross: list[tuple[str, dict[str, dict], dict, str, list[str], dict]] = [  # hypothetical composition only
            ('first-wins-fills-only-env-and-cap', {'mdm': {'model': other, 'env': {'X': 'mdm'}, 'maxEffortLevel': self.higher}}, admin_file,
             'first-wins', ['mdm'], {'model': other, 'env': {'X': 'mdm', 'Y': 'file'}, 'maxEffortLevel': self.effort}),
            ('control-only-mdm-is-not-a-policy-source',
             {'mdm': {'managedSourcesBehavior': 'first-wins', 'wslInheritsWindowsSettings': True}}, admin_file,
             'first-wins', ['managed'], admin_file),
            ('merge-unions-lists-but-takes-allowlist-whole',
             {'mdm': {'managedSourcesBehavior': 'merge', 'model': other, 'availableModels': [native, other],
                      'deniedModels': ['m'], 'env': {'X': 'mdm'}}},
             {'model': native, 'availableModels': [third], 'deniedModels': ['x'], 'env': {'X': 'file', 'Y': 'file'}},
             'merge', ['mdm', 'managed'], {'model': other, 'availableModels': [native, other], 'deniedModels': ['m', 'x'],
                                          'env': {'X': 'mdm', 'Y': 'file'}}),
            ('remote-outranks-mdm-and-files-without-authenticating',
             {'remote': {'model': third}, 'mdm': {'model': other}}, {'model': native}, 'first-wins', ['remote'], {'model': third})]
        for label, tiers, document, behavior, selected, managed in cross:
            with self.subTest(cross_source=label):
                base = self.fresh()
                self.put(base, LOCAL_MANAGED, document)
                snapshot = self.collect(base, extra=[self.injected(tier, content) for tier, content in tiers.items()])
                verdict = self.check(snapshot)
                self.assertIsNone(verdict['reason'], verdict.get('conflicts'))
                self.assertEqual((verdict['effective']['behavior'], verdict['effective']['selected_tiers']), (behavior, selected))
                self.assertEqual(self.sorted_lists(verdict['effective']['managed']), managed)
                self.assertIn('remote', verdict['unresolved'], 'an injected tier is composition only, never real remote authority')
        base = self.fresh()
        self.put(base, LOCAL_MANAGED, {'maxEffortLevel': self.higher})
        verdict = self.check(self.collect(base, extra=[self.injected('mdm', {'maxEffortLevel': self.effort})]))
        self.assertEqual(verdict['effective']['max_effort_cap'], {'level': self.effort, 'tier': 'mdm'},
                         'the lowest admin cap applies even though first-wins selected one source')

    def test_local_authority_caps_allowlists_and_remaps_match_selected_controls(self):
        native, (other, third), lower = self.native, self.others, self.lower
        remapped = 'bedrock-fixture/' + other
        baseline = {'managed': {'availableModels': [native, other], 'deniedModels': [third], 'maxEffortLevel': self.effort},
                    'user': {'model': other, 'effortLevel': lower}}

        def verdict_for(change, **options):
            """The baseline with exactly one tier-level change; a None value deletes that baseline key."""
            base = self.fresh()
            for tier, rel in (('managed', LOCAL_MANAGED), ('user', LOCAL_USER), ('project', LOCAL_PROJECT), ('local', LOCAL_LOCAL)):
                merged = {key: value for key, value in {**baseline.get(tier, {}), **change.get(tier, {})}.items() if value is not None}
                if merged:
                    self.put(base, rel, merged)
            return self.check(self.collect(base), **options)

        positive = verdict_for({})
        self.assertEqual((positive['reason'], positive['conflicts']), (None, []))
        self.assertIn('remote', positive['unresolved'])
        # differing file defaults are overridden by the intended explicit --model/--effort, never a constraint
        for label, options in (('explicit-model-and-effort', {}), ('explicit-flags-spelled', {'explicit_model': True, 'explicit_effort': True})):
            with self.subTest(defaults=label):
                self.assertIsNone(verdict_for({}, **options)['reason'])
        for label, options, key in (('model-default-without-explicit-model', {'explicit_model': False}, 'model'),
                                    ('effort-default-without-explicit-effort', {'explicit_effort': False}, 'effortLevel')):
            with self.subTest(defaults=label):
                verdict = verdict_for({}, **options)
                self.assertEqual(verdict['reason'], 'native-precedence-conflict', verdict['conflicts'])
                self.assertIn({'key': key, 'tier': 'user', 'reason': 'native-precedence-conflict'}, verdict['conflicts'])
        with self.subTest(defaults='enforceAvailableModels-does-not-reach-explicit-id'):
            self.assertIsNone(verdict_for({'managed': {'enforceAvailableModels': True}})['reason'])
        negatives = [  # one change from the baseline each: label, documents, reason, conflicting key, tier
            ('denylist', {'managed': {'deniedModels': [native]}}, 'model-unavailable', 'deniedModels', 'managed'),
            ('excluding-allowlist', {'managed': {'availableModels': [other]}}, 'model-unavailable', 'availableModels', 'managed'),
            ('lower-global-cap-user', {'user': {'maxEffortLevel': lower}}, 'effort-unavailable', 'maxEffortLevel', 'user'),
            ('lower-global-cap-local', {'local': {'maxEffortLevel': lower}},
             'effort-unavailable', 'maxEffortLevel', 'local'),
            ('matching-per-model-cap', {'project': {'modelSettings': {native: {'maxEffortLevel': lower}}}},
             'effort-unavailable', 'modelSettings.%s.maxEffortLevel' % native, 'project'),
            ('remap-to-another-provider-id', {'managed': {'availableModels': None}, 'user': {'modelOverrides': {native: remapped}}},
             'native-precedence-conflict', 'modelOverrides', 'user'),
            ('managed-allowlist-not-widened-by-user', {'managed': {'availableModels': [other]}, 'user': {'availableModels': [native]}},
             'model-unavailable', 'availableModels', 'managed'),
            ('nonmanaged-allowlists-without-entry',
             {'managed': {'availableModels': None}, 'user': {'availableModels': [other]}, 'project': {'availableModels': [third]}},
             'model-unavailable', 'availableModels', 'user')]
        for label, documents, reason, key, tier in negatives:
            with self.subTest(negative=label):
                verdict = verdict_for(documents)
                self.assertEqual(verdict['reason'], reason, verdict['conflicts'])
                self.assertIn({'key': key, 'tier': tier, 'reason': reason}, verdict['conflicts'])
        positives = [
            ('developer-deniedModels-is-managed-only', {'user': {'deniedModels': [native]}}),
            ('nonmanaged-allowlists-union-includes-entry',
             {'managed': {'availableModels': None}, 'user': {'availableModels': [other]}, 'project': {'availableModels': [native]}}),
            ('cap-max-sets-no-cap', {'managed': {'maxEffortLevel': 'max'}}),
            ('cap-equal-to-selected', {'user': {'maxEffortLevel': self.effort}}),
            ('per-model-max-exempts-its-own-source', {'user': {'maxEffortLevel': lower, 'modelSettings': {native: {'maxEffortLevel': 'max'}}}}),
            ('higher-allowlist-without-overrides-suppresses-lower-remap',
             {'managed': {'availableModels': [native]}, 'user': {'modelOverrides': {native: remapped}}}),
            ('remap-for-another-model', {'user': {'modelOverrides': {other: remapped}}})]
        for label, documents in positives:
            with self.subTest(positive=label):
                self.assertEqual(verdict_for(documents)['conflicts'], [])
                self.assertIsNone(verdict_for(documents)['reason'])
        with self.subTest(unresolved='empty-managed-allowlist-is-not-guessed'):
            verdict = verdict_for({'managed': {'availableModels': []}, 'user': {'availableModels': [other]}})
            self.assertIsNone(verdict['reason'])
            self.assertIn('empty-allowlist:availableModels', verdict['unresolved'])
            self.assertIs(verdict['effective_complete'], False)
        with self.subTest(positive='suppressed-remap-is-not-effective'):
            verdict = verdict_for({'managed': {'availableModels': [native]}, 'user': {'modelOverrides': {native: remapped}}})
            self.assertIsNone(verdict['effective']['model_overrides'])
        with self.subTest(cap='per-model-max-never-exempts-another-source'):
            verdict = verdict_for({'user': {'modelSettings': {native: {'maxEffortLevel': 'max'}}},
                                   'project': {'maxEffortLevel': lower}})
            self.assertEqual((verdict['reason'], verdict['effective']['max_effort_cap']), ('effort-unavailable', {'level': lower, 'tier': 'project'}))
        with self.subTest(cap='lowest-cap-across-admin-and-developer-sources'):
            verdict = verdict_for({'managed': {'maxEffortLevel': self.higher}, 'user': {'maxEffortLevel': lower}})
            self.assertEqual(verdict['effective']['max_effort_cap'], {'level': lower, 'tier': 'user'})
        for label, documents, key in (
                ('allowlist-version-form-entry', {'managed': {'availableModels': ['claude-%s-5-5' % native]}}, 'availableModels'),
                ('allowlist-prefix-guess', {'managed': {'availableModels': [native[:-1]]}}, 'availableModels'),
                ('denylist-full-id-entry', {'managed': {'deniedModels': ['claude-%s-5-5' % native]}}, 'deniedModels'),
                ('remap-keyed-by-full-id', {'managed': {'availableModels': None}, 'user': {'modelOverrides': {'claude-%s-5-5' % native: remapped}}}, 'modelOverrides')):
            with self.subTest(unresolved=label):  # explicit unresolved: neither guessed-allowed nor guessed-denied
                verdict = verdict_for(documents)
                self.assertIsNone(verdict['reason'], 'no guessed canonicalization may create a conflict')
                self.assertIn('alias-canonicalization:' + key, verdict['unresolved'])

        # Exact full IDs require no alias inference: equality with the selected ID is sufficient.
        exact_id = 'claude-sonnet-fixture-1'
        for key, value, expected_reason in (('availableModels', [exact_id], None),
                                   ('deniedModels', [exact_id], 'model-unavailable'),
                                   ('maxEffortLevel', lower, 'effort-unavailable'),
                                   ('modelSettings', {exact_id: {'maxEffortLevel': lower}}, 'effort-unavailable')):
            with self.subTest(exact_full_id=key):
                work = self.fresh()
                self.put(work, LOCAL_MANAGED, {key: value})
                result = self.private('_check_local_authority')(self.collect(work), exact_id, self.effort)
                self.assertEqual(result['reason'], expected_reason)
                self.assertNotIn('alias-canonicalization:' + key, result['unresolved'])

    def test_local_authority_rechecks_sources_and_rejects_unresolved_resolution(self):
        case, native, lower = self.case, self.native, self.lower
        recheck = self.private('_recheck_local_authority')
        clean: dict[str, object] = {'reason': None, 'drift': []}
        dropin = LOCAL_DROPINS + '20-b.json'
        documents = {LOCAL_MANAGED: {'model': native}, LOCAL_DROPINS + '10-a.json': {'deniedModels': ['q']},
                     dropin: {'env': {'A': '1'}}}

        def layout():
            work = self.fresh()
            for rel, document in documents.items():
                self.put(work, rel, document)
            return work

        def managed_only(work):
            return [source for source in self.sources(work) if source['tier'] == 'managed']

        # real fixture canaries: unknown ordinary keys are compatible, and only owned settings JSON participates
        canary_sources = [{'tier': tier, 'kind': 'file', 'path': str(path)} for tier, path in (
            ('user', case.home / '.claude/settings.json'), ('project', case.root / '.claude/settings.json'),
            ('local', case.root / '.claude/settings.local.json'))]
        canaries = {source['path']: Path(source['path']).read_bytes() for source in canary_sources}
        work = layout()
        snapshot = self.collect(work, sources=managed_only(work) + canary_sources)
        self.assertIsNone(snapshot['reason'], snapshot.get('failures'))
        for source in canary_sources:
            self.assertEqual(snapshot['tiers'][source['tier']], {}, 'unknown ordinary keys never enter the decision projection')
        self.assertIsNone(self.check(snapshot)['reason'])
        self.assertEqual({path: Path(path).read_bytes() for path in canaries}, canaries)
        self.assertEqual(recheck(case.helper(), snapshot), clean)

        def same_length_bytes(work):
            main = work / LOCAL_MANAGED
            main.write_bytes(main.read_bytes().replace(b'"model"', b'"modeL"'))

        def longer_bytes(work):
            main = work / LOCAL_MANAGED
            main.write_bytes(main.read_bytes() + b' ')

        def add_dropin(work):
            self.put(work, LOCAL_DROPINS + '15-new.json', {'model': 'late'})

        def delete_dropin(work):
            (work / dropin).unlink()

        def link(rel):  # identical bytes behind a link: only identity, not content, can detect the change
            def mutation(work):
                original, target = work / rel, work / 'linked-copy.json'
                target.write_bytes(original.read_bytes())
                original.unlink()
                original.symlink_to(target)
            return mutation

        def delete_main(work):
            (work / LOCAL_MANAGED).unlink()

        drift = [('same-length-bytes', same_length_bytes, LOCAL_MANAGED, 'bytes-changed'),
                 ('longer-bytes', longer_bytes, LOCAL_MANAGED, 'bytes-changed'),
                 ('dropin-added', add_dropin, LOCAL_DROPINS + '15-new.json', 'added'),
                 ('dropin-deleted', delete_dropin, dropin, 'deleted'),
                 ('dropin-replaced-by-symlink', link(dropin), dropin, 'symlink'),
                 ('main-replaced-by-symlink', link(LOCAL_MANAGED), LOCAL_MANAGED, 'symlink'),
                 ('main-deleted', delete_main, LOCAL_MANAGED, 'disappeared')]
        for label, mutation, rel, change in drift:
            with self.subTest(drift=label):
                work = layout()
                captured = self.collect(work, sources=managed_only(work))
                self.assertIsNone(captured['reason'])
                self.assertEqual(recheck(case.helper(), captured), clean)
                mutation(work)
                result = recheck(case.helper(), captured)
                self.assertEqual(result['reason'], 'input-invalid', result)
                self.assertIn({'path': str(work / rel), 'change': change}, result['drift'])
        with self.subTest(drift='absent-to-present'):
            work = self.fresh()
            captured = self.collect(work)  # every source absent is valid and is not a failure
            self.assertIsNone(captured['reason'])
            self.assertEqual({source['state'] for source in captured['sources']}, {'absent'})
            self.assertEqual(recheck(case.helper(), captured), clean)
            for rel in (LOCAL_MANAGED, LOCAL_DROPINS + '10-a.json', LOCAL_USER, LOCAL_PROJECT, LOCAL_LOCAL):
                with self.subTest(appears=rel):
                    path = self.put(work, rel, {'model': native})
                    result = recheck(case.helper(), captured)
                    path.unlink()
                    if rel.startswith(LOCAL_DROPINS):
                        path.parent.rmdir()
                    self.assertEqual(result['reason'], 'input-invalid', result)
                    self.assertIn({'path': str(path), 'change': 'added' if rel.startswith(LOCAL_DROPINS) else 'appeared'},
                                  result['drift'])
                    self.assertEqual(recheck(case.helper(), captured), clean)
        # present-but-unusable authority is failure, never absence
        bad: list[tuple[str, str, dict, str]] = [('malformed', LOCAL_MANAGED, {'raw': b'{"model": '}, 'malformed'),
               ('duplicate-key', LOCAL_USER, {'raw': b'{"model": "opus", "model": "sonnet"}'}, 'duplicate-key'),
               ('nested-duplicate-key', LOCAL_PROJECT, {'raw': b'{"env": {"A": "1", "A": "2"}}'}, 'duplicate-key'),
               ('not-an-object', LOCAL_LOCAL, {'raw': b'[]'}, 'not-object'),
               ('directory-at-file-path', LOCAL_USER, {'directory': True}, 'unreadable'),
               ('file-as-parent-directory', LOCAL_PROJECT, {'parent_file': True}, 'unreadable')]
        for label, rel, how, kind in bad:
            with self.subTest(unusable=label):
                work = self.fresh()
                path = work / rel
                if how.get('directory'):
                    path.mkdir(parents=True)  # genuine EISDIR on read; chmod 000 proves nothing when running as root
                elif how.get('parent_file'):
                    path.parent.parent.mkdir(parents=True, exist_ok=True)
                    path.parent.write_text('not a directory\n')  # genuine ENOTDIR for the settings path below it
                else:
                    self.put(work, rel, raw=how['raw'])
                result = self.collect(work)
                self.assertEqual(result['reason'], 'config-invalid', result)
                self.assertIn(kind, {failure['kind'] for failure in result['failures'] if failure['path'] == str(path)})
                self.assertNotIn(str(path), [source['path'] for source in result['sources'] if source['state'] == 'absent'])
        with self.subTest(unusable='symlink-at-capture'):
            work = self.fresh()
            target = self.put(work, 'elsewhere/real.json', {'model': native})
            (work / LOCAL_USER).parent.mkdir(parents=True)
            (work / LOCAL_USER).symlink_to(target)
            self.assertEqual(self.collect(work)['reason'], 'input-invalid')
        # unresolved authority never yields a complete verdict; known local conflicts still reject
        marker, helper_script = self.owned / 'policy-helper-ran', self.owned / 'policy-helper'
        helper_script.write_text('#!/bin/sh\necho ran >> %s\nexit 0\n' % shlex.quote(str(marker)))
        helper_script.chmod(0o755)
        contexts = [('policy-helper-active', {LOCAL_MANAGED: {'policyHelper': str(helper_script)}}, (), 'policy-helper'),
                    ('parent-managed-unresolved', {}, ('parent',), 'parent'),
                    ('mdm-lookup-unresolved', {}, ('mdm',), 'mdm'),
                    ('wsl-lookup-unresolved', {}, ('wsl',), 'wsl'),
                    ('remote-unobserved', {}, (), 'remote')]
        for label, files, extra, name in contexts:
            with self.subTest(unresolved=label):
                work = self.fresh()
                for rel, document in files.items():
                    self.put(work, rel, document)
                snapshot = self.collect(work, unresolved=extra)
                self.assertIn(name, snapshot['unresolved'])
                verdict = self.check(snapshot)
                self.assertIsNone(verdict['reason'], 'no local conflict exists, so this is incompleteness, not rejection')
                self.assertIn(name, verdict['unresolved'])
            with self.subTest(known_conflict_with_unknown_tiers=label):
                work = self.fresh()
                for rel, document in {**files, LOCAL_USER: {'maxEffortLevel': lower}}.items():
                    self.put(work, rel, document)
                verdict = self.check(self.collect(work, unresolved=extra))
                self.assertEqual(verdict['reason'], 'effort-unavailable', verdict)
                self.assertIn({'key': 'maxEffortLevel', 'tier': 'user', 'reason': 'effort-unavailable'}, verdict['conflicts'])
        self.assertFalse(marker.exists(), 'the policy helper must never be executed')

    def test_installed_claude_prepare_rejects_owned_local_conflicts_without_rewriting_state(self):
        prep, case, effort = self.prep, self.case, self.effort
        other_model = self.others[0]
        other_effort = next(item for item in launch.EFFORTS if item != effort)
        settings = {'user': case.home / '.claude/settings.json', 'project': case.root / '.claude/settings.json',
                    'local': case.root / '.claude/settings.local.json'}
        untouched = [case.home / '.claude.json', case.home / '.claude/projects/canary/session.jsonl']
        names = ('request.json', 'registry.json', 'policy.json', 'observation.json')
        supplied = {name: (case.root / name).read_bytes() for name in names}
        canaries = {path: path.read_bytes() for path in [*settings.values(), *untouched]}
        self.assertTrue(all(b'x-sdd-canary' in raw for raw in canaries.values()), 'fixture setup: canaries expected')

        def write_setting(path, change):
            document = json.loads(canaries[path])
            document.update(change)
            path.write_text(json.dumps(document) + '\n')
            prep.home_before = tree(case.home)  # fixture bookkeeping for the one deliberate owned edit

        def restore(path):
            path.write_bytes(canaries[path])
            prep.home_before = tree(case.home)

        def assert_state_intact():
            self.assertEqual({path: path.read_bytes() for path in canaries}, canaries, 'settings or canary bytes changed')
            self.assertEqual({name: (case.root / name).read_bytes() for name in names}, supplied)
            self.assertFalse(prep.work.exists(), 'a model or work invocation reached the fixture CLI')
            self.assertFalse(case.marker.exists(), 'a native model executable was invoked')

        for shell in SHELLS:
            install_root = self.prep.install(shell)
            prep.claude_positive(install_root, prep.output())  # limited baseline: no readiness or remote-absence claim
            for tier, path in settings.items():
                with self.subTest(shell=shell, tier=tier, defaults='differing-model-and-effort-defaults'):
                    write_setting(path, {'model': other_model, 'effortLevel': other_effort})
                    try:  # defaults are overridden by the explicit --model/--effort the launch supplies
                        prep.claude_positive(install_root, prep.output())
                    finally:
                        restore(path)
            conflicts = [('cap-below-selected-effort', {'maxEffortLevel': self.lower}, 'effort-unavailable'),
                         ('excluding-model-allowlist', {'availableModels': [other_model]}, 'model-unavailable')]
            for tier, path in settings.items():
                for label, change, reason in conflicts:
                    with self.subTest(shell=shell, tier=tier, conflict=label):
                        output = prep.output()
                        write_setting(path, change)
                        try:
                            prep.claude_rejected(install_root, output, reason)
                            self.assertFalse((case.root / output).exists(), 'a rejected preparation created an output directory')
                        finally:
                            restore(path)
            assert_state_intact()
            prep.claude_positive(install_root, prep.output())  # restored owned bytes prepare again: the cause was the settings


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
        self.environment.update(HOME=str(self.home), CLAUDE_CONFIG_DIR=str(self.home / '.claude'),
                                XDG_DATA_HOME=str(self.home / '.local/share'),
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

    # T-008 split-root additions: append these members to InstalledPanelistCallerTests.
    def root_positive(self, shell):
        f, installed = self.fixture(shell)
        result, output = self.run_snippet(f, installed, shell, 'root-positive')
        self.accepted(f, result, output)
        return f, installed

    def root_prepare(self, f, installed, label):
        f.session_id = str(uuid.uuid4())
        f.request.update(role='panelist-gpt', host='codex-cli', requested_effort='high',
                         cli={'model_id': 'gpt-6-astra', 'policy': 'pinned'}, policy_path='policy.json')
        f.observation = f.fresh_observation()
        f.save()
        f.task_consent(True)
        (f.root / 'SDD_SUDO').unlink(missing_ok=True)
        output = 'runs/' + label
        result = f.run_process([sys.executable, '-I', '-B', str(installed / ADAPTER), 'prepare',
            '--request', 'request.json', '--registry', 'registry.json', '--role', 'panelist-gpt',
            '--host', 'codex-cli', '--run-id', f.run_id, '--session-id', f.session_id, '--attempt', '1',
            '--output-dir', output, '--require-actual-id', 'false'], label='real split-root preparation')
        self.assertEqual(result.returncode, 0, result.stderr[-1800:])
        controls = f.root / output / 'controls.json'
        self.assertTrue(controls.is_file(), 'Real prepare did not create controls')
        value = json.loads(result.stdout)
        self.assertEqual(value['controls'], {'path': output + '/controls.json', 'sha256': launch.sha_file(controls)})
        self.assertEqual(value['selection']['resolved']['native_id'], 'gpt-6-astra')
        return output, json.loads(controls.read_bytes())

    def root_selected(self, f, shell, controls, *, env=None):
        f.audit.unlink(missing_ok=True)
        f.verdict_path().unlink(missing_ok=True)
        script = f.scripts / ('run-panelist-gpt.' + ('sh' if shell == 'bash' else 'ps1'))
        command = [launch.BASH, str(script)] if shell == 'bash' else [PWSH, '-NoProfile', '-File', str(script)]
        command += ['--task', f.TASK, '--feature', f.FEATURE,
                    '--input', f.bundle.relative_to(f.root).as_posix(), '--spec-root', 'specs',
                    '--digest', f.bundle_digest, '--consent', 'human-flag', '--model-controls', controls,
                    '--model-controls-sha256', launch.sha_file(f.root / controls),
                    '--run-id', f.run_id, '--session-id', f.session_id]
        result = f.run_process(command, env, timeout=60, label='real installed selected runner')
        self.assertFalse(f.poison.exists(), 'Installed boundary fell back to poisoned package')
        return result

    def root_record(self, f, driver, output, *, mode='model-installed-run-record', feature=None):
        binding = output / 'model-delivery-binding.json'
        launch_path = output / 'model-launch.json'
        self.assertTrue(binding.is_file(), 'A complete positive must precede retrospective consumption')
        args = [sys.executable, '-I', '-B', str(driver), mode, str(f.root),
                '--launch', launch_path.relative_to(f.root).as_posix(), '--launch-sha256', launch.sha_file(launch_path),
                '--delivery-binding', binding.relative_to(f.root).as_posix(),
                '--delivery-binding-sha256', launch.sha_file(binding), '--slot', 'reviewers',
                '--feature', feature or f.FEATURE]
        record = {'schema': 'sdd-run-record/v1', 'feature': feature or f.FEATURE,
                  'model_ids': {'main': 'unknown', 'reviewers': 'unknown'}}
        try:
            return launch.subprocess.run(args, input=json.dumps(record), cwd=f.root, env=f.environment,
                                         text=True, capture_output=True, timeout=60, check=False)
        except launch.subprocess.TimeoutExpired:
            self.fail('Bounded retrospective CLI timed out')

    def root_record_accepted(self, f, installed, output, policy):
        audit = f.audit.read_bytes() if f.audit.exists() else None
        result = self.root_record(f, installed / CALLER_DRIVER, output)
        self.assertEqual(result.returncode, 0, result.stderr[-1800:])
        record = json.loads(result.stdout)
        self.assertEqual(record['schema'], 'sdd-run-record/v2')
        self.assertEqual(record['model_policy'], policy)
        self.assertEqual(f.audit.read_bytes() if f.audit.exists() else None, audit,
                         'Retrospective CLI invoked a vendor')
        return record

    def test_installed_panelist_rejects_runtime_alias_and_postsend_drift_with_project_decoys(self):
        for shell in SHELLS:
            with self.subTest(shell=shell):
                f, installed = self.root_positive(shell)
                extension = 'sh' if shell == 'bash' else 'ps1'
                gate_rel = CALLER_SCRIPTS + 'prepare-panelist-input.' + extension
                gate, decoy = installed / gate_rel, f.root / gate_rel
                original, mode = gate.read_bytes(), gate.stat().st_mode & 0o777
                decoy.parent.mkdir(parents=True)
                decoy.write_bytes(original)
                outside = f.base / ('outside-consent.' + extension)
                outside.write_bytes(original)
                output, _ = self.root_prepare(f, installed, 'gate-alias')
                try:
                    gate.unlink()
                    gate.symlink_to(outside)
                    result = self.root_selected(f, shell, output + '/controls.json')
                    error = self.rejected(f, result, {'input-invalid'})
                    self.assertIn('consent', error['message'].lower(), 'Failure must be at installed consent authority')
                    self.assertEqual(outside.read_bytes(), original)
                    self.assertEqual(decoy.read_bytes(), original)
                finally:
                    gate.unlink()
                    gate.write_bytes(original)
                    gate.chmod(mode)
                # A real current-byte positive after restoring the gate distinguishes source rejection from setup.
                output, _ = self.root_prepare(f, installed, 'gate-restored')
                result = self.root_selected(f, shell, output + '/controls.json')
                self.accepted(f, result, output)
                for target in (gate_rel, CALLER_SCRIPTS + 'run-panelist-gpt.' + extension):
                    with self.subTest(postsend_source=target):
                        source, project_decoy = installed / target, f.root / target
                        raw, permission = source.read_bytes(), source.stat().st_mode & 0o777
                        project_decoy.parent.mkdir(parents=True, exist_ok=True)
                        project_decoy.write_bytes(raw)
                        output, _ = self.root_prepare(f, installed, 'drift-' + Path(target).stem)
                        try:
                            result = self.root_selected(f, shell, output + '/controls.json', env={
                                'SDD_TEST_NATIVE_MODE': 'mutate-source', 'SDD_TEST_MUTATE_PATH': str(source)})
                            self.assertTrue(f.audit.is_file(), 'Existing fixture CLI must actually perform the mutation')
                            self.assertNotEqual(source.read_bytes(), raw)
                            self.assertEqual(project_decoy.read_bytes(), raw, 'Project decoy changed')
                            self.assertEqual(result.returncode, 2, result.stderr[-1800:])
                            self.assertFalse(f.verdict_path().exists())
                            self.assertFalse((f.artifact_dir() / 'model-delivery-binding.json').exists(),
                                             'Runtime drift published accepted delivery')
                        finally:
                            source.write_bytes(raw)
                            source.chmod(permission)

    def test_installed_record_reconstructs_fixed_runtime_and_keeps_generic_and_protected_roots(self):
        f, installed = self.root_positive('bash')
        output = f.artifact_dir()
        policy = json.loads(f.verdict_path().read_bytes())['model_policy']
        self.root_record_accepted(f, installed, output, policy)
        for shell in SHELLS:
            with self.subTest(installed_emitter=shell):
                shutil.rmtree(f.root / 'reports/runs', ignore_errors=True)
                script = installed / (CALLER_SCRIPTS + 'emit-run-record.' + ('sh' if shell == 'bash' else 'ps1'))
                if shell == 'bash':
                    command = [launch.BASH, str(script), f.FEATURE]
                    names = ['--model-launch', '--model-launch-sha256', '--model-delivery-binding',
                             '--model-delivery-binding-sha256', '--model-slot']
                else:
                    command = [PWSH, '-NoProfile', '-File', str(script), '-Feature', f.FEATURE]
                    names = ['-ModelLaunch', '-ModelLaunchSha256', '-ModelDeliveryBinding',
                             '-ModelDeliveryBindingSha256', '-ModelSlot']
                values = [(output / 'model-launch.json').relative_to(f.root).as_posix(),
                          launch.sha_file(output / 'model-launch.json'),
                          (output / 'model-delivery-binding.json').relative_to(f.root).as_posix(),
                          launch.sha_file(output / 'model-delivery-binding.json'), 'reviewers']
                for name, value in zip(names, values):
                    command.extend([name, value])
                audit = f.audit.read_bytes()
                emitted = f.run_process(command, timeout=60, label='actual installed selected emitter')
                self.assertEqual(emitted.returncode, 0, emitted.stderr[-1800:])
                records = list((f.root / 'reports/runs').glob('RUN-*.json'))
                self.assertEqual(len(records), 1, 'Installed emitter did not publish exactly one bound record')
                self.assertEqual(json.loads(records[0].read_text(encoding='utf-8-sig'))['model_policy'], policy)
                self.assertEqual(f.audit.read_bytes(), audit, 'Retrospective emitter invoked the native CLI')
        binding_path, context_path = output / 'model-delivery-binding.json', output / 'model-execution-context.json'
        binding_raw, context_raw = binding_path.read_bytes(), context_path.read_bytes()
        context, binding = json.loads(context_raw), json.loads(binding_raw)
        deps_path, consent_path = f.root / context['dependencies']['path'], f.root / context['consent_result']['path']
        originals = {path: path.read_bytes() for path in (deps_path, consent_path, output / 'model-launch.json')}
        for case in ('dependency-project-root', 'gate-project-pin', 'wrapper-project-pin', 'trusted-project-pin'):
            with self.subTest(resealed=case):
                changed_context, changed_binding = copy.deepcopy(context), copy.deepcopy(binding)
                if case == 'dependency-project-root':
                    value = json.loads(originals[deps_path])
                    old = str(installed / launch.HELPER)
                    self.assertIn(old, value)
                    value[str(f.root / launch.HELPER)] = value.pop(old)
                    deps_path.write_bytes(launch.canonical(value))
                    changed_context['dependencies']['sha256'] = launch.sha_file(deps_path)
                elif case in ('gate-project-pin', 'wrapper-project-pin'):
                    value = json.loads(originals[consent_path])
                    key = 'gate' if case.startswith('gate') else 'wrapper'
                    rel = value[key]['path']
                    decoy = f.root / rel
                    decoy.parent.mkdir(parents=True, exist_ok=True)
                    decoy.write_bytes((installed / rel).read_bytes() + b'\n# project decoy\n')
                    value[key]['sha256'] = launch.sha_file(decoy)
                    consent_path.write_bytes(launch.canonical(value))
                    changed_context['consent_result']['sha256'] = launch.sha_file(consent_path)
                else:
                    launch_path = output / 'model-launch.json'
                    value = json.loads(originals[launch_path])
                    ref = next(ref for ref in value['trusted'] if ref['path'] == launch.HELPER)
                    decoy = f.root / ref['path']
                    decoy.parent.mkdir(parents=True, exist_ok=True)
                    decoy.write_bytes((installed / ref['path']).read_bytes() + b'\n# project decoy\n')
                    ref['sha256'] = launch.sha_file(decoy)
                    launch_path.write_bytes(launch.canonical(value))
                    changed_binding['launch_sha256'] = launch.sha_file(launch_path)
                context_path.write_bytes(launch.canonical(changed_context))
                changed_binding['execution_context']['sha256'] = launch.sha_file(context_path)
                binding_path.write_bytes(launch.canonical(changed_binding))
                try:
                    before = f.audit.read_bytes()
                    result = self.root_record(f, installed / CALLER_DRIVER, output)
                    self.assertNotEqual(result.returncode, 0, 'Resealed runtime substitution was accepted')
                    self.assertEqual(result.stdout, '')
                    self.assertEqual(f.audit.read_bytes(), before)
                finally:
                    for path, raw in originals.items():
                        path.write_bytes(raw)
                    context_path.write_bytes(context_raw)
                    binding_path.write_bytes(binding_raw)
                self.root_record_accepted(f, installed, output, policy)
        # Existing explicit-root CLI and direct API intentionally use a verifier from another source tree.
        legacy = launch.SelectedPanelistLaunch(methodName='runTest')
        self.addCleanup(legacy.doCleanups)
        legacy.setUp()
        verdict, _ = legacy.accepted_panelist('bash')
        result = self.root_record(legacy, ROOT / CALLER_DRIVER, legacy.artifact_dir(), mode='model-run-record')
        self.assertEqual(result.returncode, 0, result.stderr[-1600:])
        self.assertEqual(json.loads(result.stdout)['model_policy'], verdict['model_policy'])
        transport = launch.load_module(ROOT / CALLER_DRIVER, 'root_compatibility')
        self.addCleanup(sys.modules.pop, transport.__name__, None)
        artifact = legacy.artifact_dir()
        self.assertEqual(transport.verify_model_run(legacy.root,
            (artifact / 'model-launch.json').relative_to(legacy.root).as_posix(), launch.sha_file(artifact / 'model-launch.json'),
            (artifact / 'model-delivery-binding.json').relative_to(legacy.root).as_posix(),
            launch.sha_file(artifact / 'model-delivery-binding.json'), 'reviewers', feature=legacy.FEATURE),
            verdict['model_policy'])
        protected = launch.ModelRunRecords(methodName='runTest')
        self.addCleanup(protected.doCleanups)
        protected.setUp()
        protected.records('spec-reviewer-a')
        result = self.root_record(protected.fixture, installed / CALLER_DRIVER, protected.output, feature='example')
        self.assertEqual(result.returncode, 0, 'Fixed mode redirected protected roots: ' + result.stderr[-1600:])
        self.assertEqual(json.loads(result.stdout)['model_policy']['selection'], protected.selection)
        self.assertFalse(protected.fixture.marker.exists(), 'Protected retrospective consumption invoked a native host')

    def test_installed_controls_allow_distinct_namespace_names_but_reject_snapshot_collisions(self):
        f, installed = self.root_positive('bash')
        output, controls = self.root_prepare(f, installed, 'allowed-aliases')
        selected_raw = (f.root / output / 'selection.json').read_bytes()
        selection_alias, controls_alias = launch.HELPER, launch.TRUSTED_POLICY
        for relative in (selection_alias, controls_alias):
            (f.root / relative).parent.mkdir(parents=True, exist_ok=True)
        (f.root / selection_alias).write_bytes(selected_raw)
        controls['selection'] = {'path': selection_alias, 'sha256': launch.sha_file(f.root / selection_alias)}
        (f.root / controls_alias).write_bytes(launch.canonical(controls))
        runtime_before = runtime_tree(installed)
        result = self.root_selected(f, 'bash', controls_alias)
        self.assertEqual(result.returncode, 0, 'Separate-root controls/selection names were conflated: ' + result.stderr[-1600:])
        self.assertTrue(f.audit.is_file())
        verdict = json.loads(f.verdict_path().read_bytes())
        self.assertEqual(verdict['model_policy']['selection'], json.loads(selected_raw))
        self.root_record_accepted(f, installed, f.artifact_dir(), verdict['model_policy'])
        self.assertEqual(runtime_tree(installed), runtime_before)
        for kind in ('request', 'registry', 'input-policy'):
            with self.subTest(snapshot_collision=kind):
                output, controls = self.root_prepare(f, installed, 'conflict-' + kind)
                if kind in ('request', 'registry'):
                    alias = launch.HELPER
                    (f.root / alias).write_bytes((f.root / (kind + '.json')).read_bytes())
                    controls[kind] = {'path': alias, 'sha256': launch.sha_file(f.root / alias)}
                else:
                    alias = launch.TRUSTED_POLICY
                    (f.root / alias).write_bytes((f.root / 'policy.json').read_bytes())
                    request = json.loads((f.root / 'request.json').read_bytes())
                    request['policy_path'] = alias
                    (f.root / 'request.json').write_bytes(launch.canonical(request))
                    controls['request']['sha256'] = launch.sha_file(f.root / 'request.json')
                    controls['inputs'] = sorted([
                        {'path': alias, 'sha256': launch.sha_file(f.root / alias)} if ref['path'] == 'policy.json' else ref
                        for ref in controls['inputs']], key=lambda ref: ref['path'])
                (f.root / output / 'controls.json').write_bytes(launch.canonical(controls))
                result = self.root_selected(f, 'bash', output + '/controls.json')
                self.rejected(f, result, {'config-conflict'})
                self.assertEqual(runtime_tree(installed), runtime_before)

    def test_evidence_capture_reads_both_namespaces_and_keeps_budget_and_alias_guards(self):
        import inspect
        import tempfile
        transport = launch.load_module(ROOT / CALLER_DRIVER, 'namespace_capture')
        self.addCleanup(sys.modules.pop, transport.__name__, None)
        self.assertIn('runtime_root', inspect.signature(transport.EvidenceCapture).parameters,
                      'Capture lacks explicit installed-runtime namespace support')
        self.assertTrue(callable(getattr(transport.EvidenceCapture, 'read_runtime', None)),
                        'Capture lacks a distinct bounded runtime read')
        with tempfile.TemporaryDirectory(prefix='t008-namespace-capture-') as temporary:
            base = Path(temporary)
            project, runtime = base / 'project', base / 'installed'
            project.mkdir()
            runtime.mkdir()
            relative = 'same-name.txt'
            (project / relative).write_bytes(b'project evidence')
            (runtime / relative).write_bytes(b'installed source')
            def ref(root, path=relative):
                return {'path': path, 'sha256': launch.sha_file(root / path)}
            for runtime_first in (False, True):
                with self.subTest(runtime_first=runtime_first):
                    capture = transport.EvidenceCapture(project, runtime_root=runtime)
                    order = [(capture.read, project), (capture.read_runtime, runtime)]
                    if runtime_first:
                        order.reverse()
                    for reader, origin in order:
                        self.assertEqual(reader(ref(origin)), (origin / relative).read_bytes())
                    self.assertEqual(capture.remaining, transport.MAX_LAUNCH_RECORD -
                                     len((project / relative).read_bytes()) - len((runtime / relative).read_bytes()))
                    remaining = capture.remaining
                    for reader, origin in order:
                        self.assertEqual(reader(ref(origin)), (origin / relative).read_bytes())
                    self.assertEqual(capture.remaining, remaining)
                    for reader, origin in order:
                        changed = {**ref(origin), 'sha256': launch.flip(ref(origin)['sha256'])}
                        with self.assertRaises(ValueError):
                            reader(changed)
            same = transport.EvidenceCapture(project, runtime_root=project)
            self.assertEqual(same.read(ref(project)), b'project evidence')
            remaining = same.remaining
            self.assertEqual(same.read_runtime(ref(project)), b'project evidence')
            self.assertEqual(same.remaining, remaining, 'Same physical root was charged twice')
            with self.assertRaises(ValueError):
                same.read_runtime({**ref(project), 'sha256': launch.flip(ref(project)['sha256'])})
            # Real aggregate bytes, not a mocked read or bypassed budget implementation.
            for origin in (project, runtime):
                (origin / 'large.bin').write_bytes(b'x' * (transport.MAX_LAUNCH_RECORD // 2 + 1))
            for runtime_first in (False, True):
                with self.subTest(aggregate_runtime_first=runtime_first):
                    capture = transport.EvidenceCapture(project, runtime_root=runtime)
                    order = [(capture.read, project), (capture.read_runtime, runtime)]
                    if runtime_first:
                        order.reverse()
                    order[0][0](ref(order[0][1], 'large.bin'))
                    with self.assertRaises(ValueError):
                        order[1][0](ref(order[1][1], 'large.bin'))
            for runtime_side in (False, True):
                for ancestor in (False, True):
                    with self.subTest(runtime_side=runtime_side, ancestor=ancestor):
                        origin = runtime if runtime_side else project
                        target = origin / ('linked-dir' if ancestor else 'linked.txt')
                        target.symlink_to(base if ancestor else project / relative, target_is_directory=ancestor)
                        capture = transport.EvidenceCapture(project, runtime_root=runtime)
                        reader = capture.read_runtime if runtime_side else capture.read
                        name = 'linked-dir/project/' + relative if ancestor else 'linked.txt'
                        try:
                            with self.assertRaises(ValueError):
                                reader({'path': name, 'sha256': launch.sha_file(project / relative)})
                        finally:
                            target.unlink()
                capture = transport.EvidenceCapture(project, runtime_root=runtime)
                reader = capture.read_runtime if runtime_side else capture.read
                for alias in ('../same-name.txt', './same-name.txt', 'folder//file', str(project / relative)):
                    with self.subTest(runtime_side=runtime_side, path_alias=alias), self.assertRaises(ValueError):
                        reader({'path': alias, 'sha256': launch.sha_file(project / relative)})


# ---- T-008 ordinary caller: maintained spec-review-loop non-TTY fence (spec-reviewer-a only) ---------------
# Additive members for tests/model-policy-installed.tests.py; insert before the final unittest.main guard.
# Uses the existing module imports/constants/helpers and composes (never inherits) the T-007 PairedClaudeLaunch
# data fixture and the InstalledEntryTests installer/poison/oracle helpers.
# Same-root installed coverage (not an unrelated-root proof): the real bash FilesOnly installer places PACKAGE plus
# SPEC_CALLER_RUNTIME into P, project data is rebound into P, and the protected launcher/probe derive runtime=P from
# their own location. Every gate is the actual installed product (prepare, precheck, conditional resolver, canonical
# validator, preflight, launcher, probe, Node guard, model-run-record). The ONLY replacement is the external
# `claude` executable: RECORDING_CLAUDE. Evidence class: FIXTURE ONLY (verified-configuration observation, fixture
# adoption, no live Claude/backend, fixture NEEDS_WORK review record); it proves delivery/configuration, no verdict.
SPEC_CALLER_SKILL = 'plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md'
SPEC_CALLER_LAUNCHER = 'plugins/sdd-review-loop/scripts/launch-impl-review.py'
SPEC_CALLER_ROLE = 'spec-reviewer-a'
SPEC_CALLER_B_ROLE = 'spec-reviewer-b'
SPEC_CALLER_BOUNDARY = 'plugins/sdd-review-loop/references/review-context-boundary.md'
SPEC_CALLER_RUNTIME = sorted({
    SPEC_CALLER_SKILL, 'plugins/sdd-review-loop/agents/' + SPEC_CALLER_ROLE + '.md',
    'plugins/sdd-review-loop/references/spec-review-calibration.md', SPEC_CALLER_BOUNDARY,
    *('plugins/sdd-review-loop/scripts/' + name for name in (
        'launch-impl-review.py', 'validate-nontty-spec-launch.py', 'preflight-host-review.py',
        'probe-nontty-review.py', 'nontty-impl-pretool-guard.mjs', 'spec-review-precheck.sh',
        'review-contract-validate.sh', 'lib/fixed-input-source.sh')),
    *('plugins/sdd-quality-loop/scripts/' + name for name in (
        'validate-review-context-set.sh', 'review-conditional-inputs.py'))})
RECORDING_CLAUDE = 'tests/fixtures/model-policy-installed/recording-claude.py'
SPEC_CALLER_TOOLS = ('rtk', 'node', 'bash', 'jq', 'git', 'shasum', 'python3')
SPEC_LEDGER = 'reports/review-context/identity-ledger.json'
# tests/spec-review-loop.tests.sh:110-130 round-1 constructors.
SPEC_FEATURE_FILES = {
    'requirements.md': '# Requirements\n\nSpec-Review-Status: Pending\n\n## Goals\n\n'
                       '- Demonstrate the spec-review precheck fixture.\n',
    'acceptance-tests.md': '# Acceptance tests\n\n| AC-ID | Requirement | Status |\n|---|---|---|\n'
                           '| AC-001 | REQ-001 | Planned |\n',
    'investigation.md': '# Investigation\n\n- Initial repository observation.\n'}
SPEC_DELIVERY_FIELDS = {'status', 'session_id', 'prompt_sha256', 'prompt_bytes', 'transcript_sha256', 'wrapper_sha256'}
SPEC_MODEL_DELIVERY_FIELDS = {'model_launch_sha256', 'model_delivery_binding_sha256'}
# launcher claude_command help, probe help + diagnostic + collision, launcher argv recheck help, formal send.
SPEC_NATIVE_MODES = ['help', 'help', 'diagnostic', 'collision', 'help', 'formal']


def sha_text(text):
    return hashlib.sha256(text.encode('utf-8')).hexdigest()


class InstalledSpecCallerTests(unittest.TestCase):
    """Execute the maintained spec-review-loop non-TTY fence through a complete same-root installed project."""

    def fixture(self, extra_runtime=()):
        f = launch.PairedClaudeLaunch(methodName='runTest')
        self.addCleanup(f.doCleanups)
        f.setUp()
        f.helper()  # the unchanged T-007 policy oracle stays in the source-copied fixture repository f.root
        f.fixture_repo = f.root
        f.home = f.base / 'caller-home'
        (f.home / '.codex').mkdir(parents=True)
        (f.home / '.codex/config.toml').write_text('# caller native configuration canary\n')
        (f.home / '.claude').mkdir()
        (f.home / '.claude/settings.json').write_text('{"canary": "user Claude settings; never read"}\n')
        f.codex_home = tree(f.home / '.codex')
        f.claude_home = tree(f.home / '.claude')
        f.poison = f.base / 'caller-source-fallback'
        f.audit = f.base / 'recording-claude-audit.jsonl'
        for name in [name for name in f.environment if name.startswith(('ANTHROPIC_', 'CLAUDE_'))]:
            del f.environment[name]  # native carriers come only from the launcher; nothing is recorded
        f.environment.update(HOME=str(f.home), XDG_CONFIG_HOME=str(f.home / '.config'),
                             XDG_DATA_HOME=str(f.home / '.local/share'), XDG_CACHE_HOME=str(f.home / '.cache'),
                             SDD_CODEX_HOME=str(f.home / '.codex'), SDD_CURSOR_DIR=str(f.base / 'cursor-absent'),
                             SDD_VSCODE_USER_DIR=str(f.base / 'vscode-absent'), GIT_CONFIG_NOSYSTEM='1',
                             GIT_CONFIG_GLOBAL=os.devnull, GIT_TERMINAL_PROMPT='0',
                             RECORDING_CLAUDE_AUDIT=str(f.audit))
        for name in SPEC_CALLER_TOOLS:
            self.assertIsNotNone(shutil.which(name, path=f.environment['PATH']),
                                 'Required actual tool is absent (setup failure): ' + name)
        self.assertTrue((ROOT / RECORDING_CLAUDE).is_file(), 'Recording Claude fixture is absent (setup failure)')
        shim = f.base / 'shims/claude'  # replaces only the T-007 exit-97 canary for this one executable
        shutil.copyfile(ROOT / RECORDING_CLAUDE, shim)
        shim.chmod(0o755)
        declared = self.execute(f, [str(shim), '--help'], cwd=f.base)
        self.assertEqual((declared.returncode, declared.stdout), (0, launch.HELP_TEXT),
                         'Recording CLI must declare exactly the T-007 fixture help vocabulary')
        package, empty = f.base / 'spec-caller-package', f.base / 'empty-git-template'
        package.mkdir()
        empty.mkdir()
        for relative in sorted(set(PACKAGE) | set(SPEC_CALLER_RUNTIME) | set(extra_runtime)):
            source, target = ROOT / relative, package / relative
            self.assertTrue(source.is_file(), 'Admitted package input missing (setup failure): ' + relative)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy(source, target)  # bytes plus the tracked executable bit the precheck relies on
        for args in (['init', '-q', '--template=' + str(empty)], ['add', '--all'],
                     ['-c', 'user.name=Spec Caller Fixture', '-c', 'user.email=spec-caller@example.invalid',
                      '-c', 'gc.auto=0', 'commit', '-qm', 'Explicit current spec caller package']):
            result = f.run_process(['git', '-C', str(package), *args], label='spec caller package setup')
            self.assertEqual(result.returncode, 0, 'Package setup failed: ' + result.stderr[-1200:])
        project = f.base / 'installed-project'
        result = InstalledEntryTests.run_installer(f, 'bash', package, project)
        self.assertEqual(result.returncode, 0, 'Installer setup failed: ' + result.stderr[-1600:])
        for relative in sorted(set(MANAGED_RUNTIME) | set(SPEC_CALLER_RUNTIME) | set(extra_runtime)):
            self.assertTrue((project / relative).is_file(), 'Installed spec caller runtime is missing: ' + relative)
            self.assertEqual(launch.sha_file(project / relative), launch.sha_file(ROOT / relative))
        self.assertTrue(os.access(project / 'plugins/sdd-review-loop/scripts/review-contract-validate.sh', os.X_OK),
                        'Installed precheck foundation is not executable (setup failure)')
        self.assertFalse((project / 'tests').exists(), 'Test fixtures must never be installed runtime')
        InstalledEntryTests.poison_source(f, package)
        runtime = runtime_tree(project)
        # Project data rebound into the same installed root; history is seeded, the proposed reviewer is not.
        (project / 'runs').mkdir()
        (project / 'reports/review-context').mkdir(parents=True)
        run_id, session_id = 'seed-prior-run-1', 'seed-prior-session-1'  # review-context-boundary.tests.sh:72-80
        seed = {'sequence': 1, 'stage': 'spec', 'role': SPEC_CALLER_ROLE, 'run_id': run_id,
                'host_session_id': session_id, 'previous_record_sha256': '',
                'record_sha256': sha_text('1|spec|' + SPEC_CALLER_ROLE + '|' + run_id + '|' + session_id + '|')}
        (project / SPEC_LEDGER).write_text(json.dumps({'schema': 'review-identity-ledger/v1', 'records': [seed]}) + '\n')
        self.chain(project / SPEC_LEDGER)
        return f, project, runtime

    def execute(self, f, command, *, cwd, stdin=None, timeout=120):
        try:
            return launch.subprocess.run(command, cwd=cwd, env=f.environment, input=stdin, text=True,
                                         capture_output=True, timeout=timeout, check=False)
        except launch.subprocess.TimeoutExpired:
            self.fail('Bounded spec caller subprocess timed out: ' + Path(command[0]).name)

    def chain(self, ledger):
        """Records of a hash-chain-valid ledger, recomputed exactly like the canonical validator."""
        records = json.loads(ledger.read_bytes())['records']
        previous = ''
        for sequence, record in enumerate(records, 1):
            text = '|'.join((str(sequence), record['stage'], record['role'], record['run_id'],
                             record['host_session_id'], previous))
            if 'scratch_declaration_sha256' in record:
                text += '|scratch-declaration-v1|' + record['scratch_declaration_sha256']
            if 'allowed_inputs_sha256' in record:
                text += '|allowed-inputs-v1|' + record['allowed_inputs_sha256']
            self.assertEqual((record['sequence'], record['previous_record_sha256'], record['record_sha256']),
                             (sequence, previous, sha_text(text)), 'identity ledger chain is not valid')
            previous = record['record_sha256']
        return records

    def fence(self, project):
        """The installed maintained skill is the oracle; the test authors no replacement command excerpt."""
        source = (project / SPEC_CALLER_SKILL).read_text(encoding='utf-8')
        heading = '### Local Claude CLI non-TTY route (opt-in)'
        self.assertEqual(source.count(heading), 1, 'Maintained non-TTY route heading is missing or repeated')
        section = source.split(heading, 1)[1].split('\n## ', 1)[0]
        choices = [body for language, body in re.findall(r'```([^\s`]*)[^\n]*\n(.*?)\n```', section, re.S)
                   if language.lower() in ('text', 'sh', 'bash') and 'launch-impl-review.py' in body]
        self.assertEqual(len(choices), 1, 'Expected one maintained Bash/text non-TTY launcher fence')
        return choices[0]

    def case(self, f, project, runtime, label, *, request_role=SPEC_CALLER_ROLE, mutation=None,
             role=SPEC_CALLER_ROLE, shared=None, names=None):
        """Fresh feature, round-1 precheck, UUIDv4 run=session and exact invocation/v2; then the fence runs once.

        `shared` (the earlier case of the same feature/round) reuses its actual precheck and feature files and adds the
        sanitized summary; `names` = (request, observation) project names that stay immutable for that case."""
        session = str(uuid.uuid4())
        feature = shared['feature'] if shared else 'spec-caller-' + uuid.uuid4().hex[:12]
        request_name, observation_name = names or ('request.json', 'observation.json')
        f.request = f.fresh_request(request_role)
        f.request['observation_path'] = observation_name
        f.observation = f.fresh_observation()
        f.save()
        if observation_name != 'observation.json':  # the T-007 oracle keeps its legacy names beside the role-specific file
            shutil.copyfile(f.root / 'observation.json', f.root / observation_name)
        closure = sorted(f.closure())
        # Captured while this case's mutable oracle state is current; unnamed cases recompute it live as before.
        oracle = InstalledEntryTests.oracle_selection(f) if names else None
        for name in sorted({'registry.json', *closure}):
            if names and (project / name).exists():  # shared policy/registry/adoption bytes stay exactly as published
                self.assertEqual((project / name).read_bytes(), (f.root / name).read_bytes(), 'Shared input drifted: ' + name)
            else:
                shutil.copyfile(f.root / name, project / name)
        if names:
            self.assertFalse((project / request_name).exists(), 'Per-role request must be fresh and immutable')
        shutil.copyfile(f.root / 'request.json', project / request_name)
        spec_dir = project / 'specs' / feature
        round_rel = 'reports/spec-review/' + feature + '/attempt-1/round-1'
        if shared is None:
            spec_dir.mkdir(parents=True)
            for name, text in SPEC_FEATURE_FILES.items():
                (spec_dir / name).write_text(text)
            precheck = self.execute(f, [launch.BASH, str(project / 'plugins/sdd-review-loop/scripts/spec-review-precheck.sh'),
                                        feature, '1', '1'], cwd=project)
            self.assertEqual(precheck.returncode, 0,
                             'Actual round-1 precheck failed (setup): ' + precheck.stderr[-800:])
        recorded = json.loads((project / round_rel / 'precheck-result.json').read_bytes())
        self.assertEqual([recorded[key] for key in ('schema', 'feature', 'attempt', 'round', 'spec_review_status_field',
                                                    'investigation_sha256')],
                         ['spec-review-precheck/v1', feature, 1, 1, 'Pending', launch.sha_file(spec_dir / 'investigation.md')])
        resolved = self.execute(f, ['python3', '-B', str(project / 'plugins/sdd-quality-loop/scripts/review-conditional-inputs.py'),
                                    '--root', str(project), '--feature', feature, '--stage', 'spec'], cwd=project)
        self.assertEqual(resolved.returncode, 0, 'Actual conditional-input resolution failed: ' + resolved.stderr[-800:])
        conditional = json.loads(resolved.stdout)
        self.assertEqual((conditional['domain_status'], conditional['design_system_status']), ('skipped', 'not-applicable'),
                         'This slice admits only the no-domain/no-design-system branch')
        paths = ['specs/' + feature + '/' + name for name in ('requirements.md', 'acceptance-tests.md', 'investigation.md')]
        paths += ['plugins/sdd-review-loop/references/spec-review-calibration.md', round_rel + '/precheck-result.json']
        if shared:  # reviewer B sees only the sanitized counts-and-IDs summary of the same round
            paths.append(round_rel + '/integrated-summary.json')
        entries = [{'path': path, 'sha256': launch.sha_file(project / path)} for path in paths]
        entries += [entry for entry in conditional['inputs'] if entry['path'] not in paths]
        ledger = project / SPEC_LEDGER
        records = self.chain(ledger)
        self.assertFalse([r for r in records if session in (r['run_id'], r['host_session_id'])],
                         'Proposed identity must be absent before the launcher')
        transcripts = f.home / '.claude/projects'
        self.assertFalse(transcripts.is_dir() and list(transcripts.rglob(session + '.jsonl')))
        invocation = project / round_rel / (role + '-invocation-' + session + '.json')
        invocation.write_text(json.dumps({
            'schema': 'review-context-invocation/v2', 'input_mode': 'file-manifest', 'fallback_mode': 'none',
            'read_only': True, 'stage': 'spec', 'role': role, 'feature': feature, 'run_id': session,
            'host_session_id': session, 'sequence': len(records) + 1, 'identity_ledger_path': SPEC_LEDGER,
            'identity_ledger_sha256': launch.sha_file(ledger), 'previous_record_sha256': records[-1]['record_sha256'],
            'allowed_input_manifest': entries}, indent=2) + '\n')
        output_rel = 'runs/' + role + '-' + session
        # Documented placeholders only: the current four plus the managed-prepare vocabulary of the panelist snippets.
        values = {'<absolute-repository-root>': str(project), '<absolute-invocation-path>': str(invocation),
                  '<absolute-round-directory>': str(project / round_rel), '<UUID>': session,
                  '<role>': role, '<policy-request>': request_name, '<registry>': 'registry.json',
                  '<run-id>': session, '<session-id>': session, '<attempt>': '1', '<output-dir>': output_rel}
        text = self.fence(project)
        for old, new in values.items():
            text = text.replace(old, new)
        for relative in [ADAPTER, *SPEC_CALLER_RUNTIME]:
            text = re.sub(r'(?<![\w./-])' + re.escape(relative), lambda _: str(project / relative), text)
        self.assertIsNone(re.search(r'<[A-Za-z][A-Za-z0-9_-]*>', text), 'Undocumented fixture placeholder')
        launcher = str(project / SPEC_CALLER_LAUNCHER)
        lines = text.splitlines(keepends=True)
        indexes = [index for index, line in enumerate(lines) if launcher in line]
        self.assertEqual(len(indexes), 1, 'Mutation and oracle need the one actual maintained launcher invocation')
        start = end = indexes[0]
        while start and lines[start - 1].rstrip('\n').endswith('\\'):
            start -= 1
        while end + 1 < len(lines) and lines[end].rstrip('\n').endswith('\\'):
            end += 1
        if mutation == 'remove-forwarding':
            command, count = re.subn(r'--model-controls(?:-sha256)?(?:[ \t]+|=)(?:"[^"\n]*"|\x27[^\x27\n]*\x27|[^\s`\\]+)',
                                     '', ''.join(lines[start:end + 1]))
            self.assertEqual(count, 2, 'Mutation must remove exactly the two launcher control flags, keeping prepare')
            text = ''.join(lines[:start]) + command + ''.join(lines[end + 1:])
        elif mutation == 'raw-control-drift':
            text = ''.join(lines[:start] + ['printf "\\n" >> ' + shlex.quote(output_rel + '/controls.json') + '\n'] +
                           lines[start:])
        else:
            self.assertIsNone(mutation, 'Unknown deliberate fence mutation')
        script = f.base / ('spec-caller-' + label + '.sh')
        script.write_text(text + '\n')
        audit = f.audit.read_bytes() if f.audit.exists() else b''
        before = ledger.read_bytes()
        result = self.execute(f, [launch.BASH, str(script)], cwd=project, timeout=900)
        self.assertFalse(f.poison.exists(), 'Caller used the poisoned source package')
        after = runtime_tree(project)
        self.assertEqual({path: after.get(path) for path in runtime}, runtime, 'Caller changed installed runtime')
        self.assertFalse([path for path in after if path.startswith(('plugins/', 'contracts/')) and path not in runtime],
                         'Caller added files to the installed runtime')
        self.assertEqual({entry['path']: launch.sha_file(project / entry['path']) for entry in entries},
                         {entry['path']: entry['sha256'] for entry in entries}, 'Reviewed sources or status changed')
        self.assertEqual(tree(f.home / '.codex'), f.codex_home, 'Caller changed user native Codex configuration')
        self.assertEqual({path: digest for path, digest in tree(f.home / '.claude').items()
                          if not path.startswith('projects/')}, f.claude_home, 'Caller changed user Claude configuration')
        return {'session': session, 'feature': feature, 'entries': entries, 'paths': paths, 'invocation': invocation,
                'output_rel': output_rel, 'launch': project / round_rel / ('launch-' + session), 'result': result,
                'records': records, 'ledger': before, 'audit': audit, 'role': role, 'round_rel': round_rel,
                'request': request_name, 'closure': closure, 'oracle': oracle}

    def native_calls(self, f, case):
        raw = f.audit.read_bytes() if f.audit.exists() else b''
        self.assertEqual(raw[:len(case['audit'])], case['audit'], 'Native audit history was rewritten')
        return [json.loads(line) for line in raw[len(case['audit']):].decode('utf-8').splitlines()]

    def assert_delivered(self, f, project, case):
        """Route-independent complete positive: genuine probe, one launcher reservation, verified delivery."""
        session, output, result, role = case['session'], case['launch'], case['result'], case['role']
        self.assertEqual(result.returncode, 0, 'Valid maintained fence failed: ' + result.stderr[-2400:])
        delivery = json.loads((output / 'delivery.json').read_bytes())
        self.assertEqual({key: delivery.get(key) for key in SPEC_DELIVERY_FIELDS},
                         {'status': 'DELIVERY_OK', 'session_id': session,
                          'prompt_sha256': launch.sha_file(output / 'prompt.txt'),
                          'prompt_bytes': len((output / 'prompt.txt').read_bytes()),
                          'transcript_sha256': launch.sha_file(output / (session + '.jsonl')),
                          'wrapper_sha256': launch.sha_file(output / 'wrapper.json')})
        before, records = case['records'], self.chain(project / SPEC_LEDGER)
        self.assertEqual(records[:-1], before, 'Exactly one record may be appended to the prior chain')
        inputs = sha_text('\n'.join(entry['path'] + '\t' + entry['sha256'] for entry in case['entries']))
        sequence, previous = len(before) + 1, before[-1]['record_sha256']
        digest = sha_text('|'.join((str(sequence), 'spec', role, session, session, previous,
                                    'allowed-inputs-v1', inputs)))
        self.assertEqual(records[-1], {'sequence': sequence, 'stage': 'spec', 'role': role,
                                       'run_id': session, 'host_session_id': session,
                                       'previous_record_sha256': previous, 'record_sha256': digest,
                                       'allowed_inputs_sha256': inputs})
        receipt = ('REVIEW_CONTEXT_OK %s sequence=%d previous_record_sha256=%s pre_append_tip_sequence=%d '
                   'identity_unique=yes\n' % (digest, sequence, previous, sequence - 1))
        self.assertEqual({name: (output / name).read_text() for name in
                          ('preview.txt', 'preview-after.txt', 'reserved.txt', 'receipt.txt')},
                         dict.fromkeys(('preview.txt', 'preview-after.txt', 'reserved.txt', 'receipt.txt'), receipt))
        native = [json.loads(line) for line in (output / 'native.jsonl').read_text().splitlines()]
        diagnostic = native[0].get('diagnostic_session')
        self.assertEqual(native[:2], [{'diagnostic_session': diagnostic, 'reservation': 'not performed'},
                                      {'session': diagnostic, 'exit': 0, 'stderr_present': False}])
        self.assertNotEqual(diagnostic, session)
        self.assertFalse([r for r in records if diagnostic in (r['run_id'], r['host_session_id'])], 'The probe reserved')
        proof = native[-1]
        guard = project / 'plugins/sdd-review-loop/scripts/nontty-impl-pretool-guard.mjs'
        self.assertEqual({key: proof.get(key) for key in (
            'admitted_read_executed', 'outside_read_pretool_denied', 'chained_bash_pretool_denied',
            'existing_session_collision_rejected', 'control_reads_executed', 'source_invocation_read_executed',
            'source_invocation_sha256', 'admitted_paths', 'ordered_hashes_verified', 'fixed_input_record_sha256',
            'guard_sha256')},
            {'admitted_read_executed': True, 'outside_read_pretool_denied': True, 'chained_bash_pretool_denied': True,
             'existing_session_collision_rejected': True, 'control_reads_executed': True,
             'source_invocation_read_executed': True, 'source_invocation_sha256': launch.sha_file(case['invocation']),
             'admitted_paths': case['paths'], 'ordered_hashes_verified': len(case['entries']) + 5,
             'fixed_input_record_sha256': None, 'guard_sha256': launch.sha_file(guard)})
        homes = sorted((f.home / '.claude/projects').rglob('*.jsonl'))
        formal_home = [path for path in homes if path.name == session + '.jsonl']
        diagnostic_home = [path for path in homes if path.name == diagnostic + '.jsonl']
        self.assertEqual((len(formal_home), len(diagnostic_home)), (1, 1), 'Native transcripts missing or ambiguous')
        self.assertEqual(formal_home[0].read_bytes(), (output / (session + '.jsonl')).read_bytes())
        self.assertEqual(launch.sha_file(diagnostic_home[0]), proof['transcript_sha256'],
                         'Duplicate-session rejection changed the diagnostic transcript')
        calls = self.native_calls(f, case)
        self.assertEqual([call['mode'] for call in calls], SPEC_NATIVE_MODES)
        probe_call, collision, formal = calls[2], calls[3], calls[5]
        self.assertEqual((probe_call['session_id'], collision['session_id'], collision['argv'], formal['session_id']),
                         (diagnostic, diagnostic, probe_call['argv'], session))
        plugin_dir = str(project / 'plugins/sdd-review-loop')  # protected launcher and probe derive runtime=P
        for call in (probe_call, formal):
            argv = call['argv']
            self.assertEqual((argv[:3], argv[argv.index('--plugin-dir') + 1]),
                             (['-p', '--session-id', call['session_id']], plugin_dir))
        self.assertEqual(Path(formal['argv'][formal['argv'].index('--settings') + 1]), output / 'settings.json')
        self.assertEqual([(t['tool'], t['decision'], t['is_error']) for t in probe_call['tools']],
                         [('Bash', 'allow', False)] + [('Read', 'allow', False)] * len(proof['native_read_paths']) +
                         [('Bash', 'deny', True), ('Read', 'deny', True), ('StructuredOutput', 'allow', False)])
        reads = [str((project / path).resolve()) for path in
                 [case['invocation'].relative_to(project).as_posix(), SPEC_CALLER_BOUNDARY, *case['paths']]]
        self.assertEqual([(t['tool'], t['decision'], t['is_error'], t.get('path'), t.get('sha256')) for t in formal['tools']],
                         [('Bash', 'allow', False, None, None)] +
                         [('Read', 'allow', False, path, launch.sha_file(Path(path))) for path in reads] +
                         [('StructuredOutput', 'allow', False, None, None)])
        wrapper = json.loads((output / 'wrapper.json').read_bytes())
        review = wrapper['structured_output']
        self.assertEqual((wrapper['type'], wrapper['is_error'], wrapper['session_id'], json.loads(wrapper['result'])),
                         ('result', False, session, review))
        self.assertEqual({key: review[key] for key in ('schema', 'stage', 'role', 'run_id', 'host_session_id',
                                                       'allowed_input_manifest', 'verdict')},
                         {'schema': role + '/v1', 'stage': 'spec', 'role': role,
                          'run_id': session, 'host_session_id': session, 'allowed_input_manifest': case['entries'],
                          'verdict': 'NEEDS_WORK'}, 'Fixture-only delivery record, never an approval')
        return delivery, calls

    def assert_managed(self, f, project, case, calls):
        """Managed oracle: real installed prepare controls forwarded, generated native role and bound delivery."""
        session, output, role = case['session'], case['launch'], case['role']
        directory = project / case['output_rel']
        self.assertTrue((directory / 'validation.json').is_file(), 'Maintained caller omitted installed prepare')
        self.assertEqual(sorted(path.name for path in directory.iterdir()), OUTPUT_FILES)
        controls, selection, validation = [json.loads((directory / name).read_bytes()) for name in OUTPUT_FILES]

        def ref(path):
            return {'path': path, 'sha256': launch.sha_file(project / path)}
        self.assertEqual(controls, {'schema': 'model-launch-controls/v1', 'role': role, 'host': launch.HOST,
                                    'attempt': 1, 'require_actual_id': False,
                                    'selection': ref(case['output_rel'] + '/selection.json'),
                                    'request': ref(case['request']), 'registry': ref('registry.json'),
                                    'inputs': [ref(path) for path in case['closure']]})
        self.assertEqual(set(validation), launch.VALIDATION_FIELDS)
        self.assertEqual(validation['controls'], ref(case['output_rel'] + '/controls.json'))
        self.assertEqual(validation['pins'], sorted([controls['selection'], controls['request'], controls['registry'],
                                                    *controls['inputs']], key=lambda item: item['path']))
        self.assertEqual(validation['trusted'], [ref(path) for path in launch.TRUSTED_PATHS])
        self.assertEqual(validation['trusted'], [{'path': path, 'sha256': launch.sha_file(ROOT / path)}
                                                 for path in launch.TRUSTED_PATHS], 'trusted runtime is current bytes')
        self.assertEqual([validation[key] for key in ('role', 'host', 'run_id', 'session_id', 'attempt', 'require_actual_id')],
                         [role, launch.HOST, session, session, 1, False])
        self.assertEqual(validation['selection'], selection)
        self.assertEqual(selection, f.helper().bind_selection(case['oracle'] or InstalledEntryTests.oracle_selection(f),
                                                              run_id=session, session_id=session, attempt=1))
        native, effort = selection['resolved']['native_id'], selection['resolved']['effort']
        trusted = next(m for m in f.trusted_policy['models'] if m['id'] == selection['resolved']['catalog_id'])
        self.assertEqual(native, trusted['hosts'][launch.HOST], 'trusted mapping only')
        launch_path = output / 'model-launch.json'
        self.assertTrue(launch_path.is_file(), 'Launcher did not bind the forwarded model controls')
        launch_raw = launch_path.read_bytes()
        record = json.loads(launch_raw)
        self.assertEqual(set(record), launch.LAUNCH_FIELDS)
        # The forwarded pin is the validated one; a fresh unchecked rehash is caught by the raw-drift case.
        self.assertEqual([record[key] for key in ('controls', 'pins', 'trusted')],
                         [validation[key] for key in ('controls', 'pins', 'trusted')])
        self.assertEqual({key: record[key] for key in (
            'schema', 'role', 'transport_role', 'host', 'run_id', 'session_id', 'attempt', 'require_actual_id',
            'selection_sha256', 'native_model', 'effort', 'effort_control', 'effort_carrier', 'native_alignment',
            'transport', 'native_overrides', 'model_argv', 'effort_argv', 'agent_model', 'agent_effort')},
            {'schema': 'model-launch-binding/v1', 'role': role, 'transport_role': role,
             'host': launch.HOST, 'run_id': session, 'session_id': session, 'attempt': 1, 'require_actual_id': False,
             'selection_sha256': selection['selection_sha256'], 'native_model': native, 'effort': effort,
             'effort_control': selection['resolved']['effort_control'], 'effort_carrier': 'flag+frontmatter',
             'native_alignment': 'generated', 'transport': 'claude-print',
             'native_overrides': dict.fromkeys(launch.NATIVE_OVERRIDES), 'model_argv': ['--model', native],
             'effort_argv': ['--effort', effort], 'agent_model': native, 'agent_effort': effort})
        probe_call, formal = calls[2], calls[5]
        argv = formal['argv']
        self.assertEqual(record['argv'], ['rtk', 'proxy', str(f.base / 'shims/claude'), *argv],
                         'Recorded launch argv must be the actual native argv')
        self.assertEqual(record['argv_sha256'], launch.sha_bytes(launch.canonical(record['argv'])))
        self.assertEqual([argv[argv.index(flag) + 1] for flag in ('--model', '--effort', '--setting-sources', '--agent')],
                         [native, effort, '', role])
        self.assertEqual([formal[key] for key in ('model', 'effort', 'agent', 'agent_model', 'agent_effort')],
                         [native, effort, role, native, effort])
        role_text = (project / 'plugins/sdd-review-loop/agents' / (role + '.md')).read_text()
        self.assertEqual(json.loads(argv[argv.index('--agents') + 1]), {role: {
            'description': 'Repository-bound independent implementation reviewer',
            'prompt': role_text.split('---', 2)[2].strip(), 'model': native,
            'tools': ['Read', 'Bash', 'StructuredOutput'], 'disallowedTools': launch.DISALLOWED, 'effort': effort}},
            'Generated native role must carry the selection; the trusted role file is never edited')
        self.assertEqual((probe_call['model'], probe_call['effort']), ('sonnet', None),
                         'The unreserved probe stays the unselected permission diagnostic')
        delivery = json.loads((output / 'delivery.json').read_bytes())
        self.assertEqual(set(delivery), SPEC_DELIVERY_FIELDS | SPEC_MODEL_DELIVERY_FIELDS)
        binding_path = output / 'model-delivery-binding.json'
        self.assertEqual([delivery['model_launch_sha256'], delivery['model_delivery_binding_sha256']],
                         [launch.sha_bytes(launch_raw), launch.sha_file(binding_path)])

        def local(name):
            return ref((output / name).relative_to(project).as_posix())
        binding = json.loads(binding_path.read_bytes())
        self.assertEqual(binding, {'schema': 'model-delivery-binding/v1', 'launch_sha256': launch.sha_bytes(launch_raw),
                                   'transport': 'claude-print', 'selection': local('model-selection.json'),
                                   'events': local('model-events.json'), 'delivery': local('model-delivery.json'),
                                   'execution_context': local('model-execution-context.json'), 'run_id': session,
                                   'session_id': session, 'attempt': 1, 'selection_sha256': selection['selection_sha256']})
        model_delivery = {'schema': 'model-delivery/v1', 'selection_sha256': selection['selection_sha256'],
                          'run_id': session, 'session_id': session, 'turn_id': 'local-review-attempt-1',
                          'configured_id': native, 'actual_id': None, 'proof': 'unverified', 'source': 'unsupported',
                          'reroutes': [], 'status': 'accepted', 'reason': 'identity-unverified'}
        self.assertEqual([json.loads((output / name).read_bytes()) for name in ('model-selection.json', 'model-delivery.json')],
                         [selection, model_delivery], 'Delivery must bind the exact prepared selection')
        self.assert_run_record(f, project, case, selection, model_delivery)
        # shortcut: mtimes prove only non-decreasing write order on one filesystem; upgrade with a launcher event log.
        order = [output / name for name in ('model-launch.json', 'native.jsonl', 'reserved.txt', 'prompt.txt',
                                            'wrapper.json', 'delivery.json')]
        self.assertEqual([path.stat().st_mtime_ns for path in order], sorted(path.stat().st_mtime_ns for path in order),
                         'Model launch binding must precede the probe, reservation and native send')

    def assert_run_record(self, f, project, case, selection=None, model_delivery=None, slot='reviewers'):
        """The actual installed run-record consumer accepts one launch/delivery binding; omitted documents are the persisted ones."""
        output = case['launch']
        delivery = json.loads((output / 'delivery.json').read_bytes())
        binding = json.loads((output / 'model-delivery-binding.json').read_bytes())
        selection = selection or json.loads((output / 'model-selection.json').read_bytes())
        model_delivery = model_delivery or json.loads((output / 'model-delivery.json').read_bytes())
        native, effort = selection['resolved']['native_id'], selection['resolved']['effort']

        def local(name):
            return {'path': (output / name).relative_to(project).as_posix()}
        consumed = self.execute(f, [sys.executable, '-I', '-B', str(project / CALLER_DRIVER), 'model-run-record',
                                    str(project), '--launch', local('model-launch.json')['path'],
                                    '--launch-sha256', delivery['model_launch_sha256'],
                                    '--delivery-binding', local('model-delivery-binding.json')['path'],
                                    '--delivery-binding-sha256', delivery['model_delivery_binding_sha256'],
                                    '--slot', slot, '--feature', case['feature']], cwd=project,
                                stdin=json.dumps({'schema': 'sdd-run-record/v1', 'feature': case['feature'],
                                                  'model_ids': {'main': 'unknown', 'reviewers': 'unknown'}}))
        self.assertEqual(consumed.returncode, 0, 'Installed run-record consumer rejected delivery: ' + consumed.stderr[-1200:])
        run_record = json.loads(consumed.stdout)
        self.assertEqual(run_record['model_policy'], {
            'actor_slot': slot, 'transport': 'claude-print', 'launch_sha256': delivery['model_launch_sha256'],
            'delivery_binding_sha256': delivery['model_delivery_binding_sha256'], 'selection': selection,
            'delivery': model_delivery, 'events_sha256': binding['events']['sha256']})
        self.assertEqual((run_record['model_ids'][slot], run_record['effort'][slot]),
                         (native, {'effort_requested': effort, 'effort_applied': effort, 'effort_degraded_reason': None}))

    def assert_blocked(self, f, project, case):
        """Stopped before reservation and native send: no launch output, ledger and native audit unchanged."""
        self.assertFalse(case['launch'].exists(), 'A blocked caller created launch output')
        self.assertFalse([path.name for path in case['launch'].parent.iterdir() if path.name.startswith('reviewer-')],
                         'A blocked caller wrote preflight or allocation evidence')
        self.assertEqual((project / SPEC_LEDGER).read_bytes(), case['ledger'], 'A blocked caller changed the ledger')
        self.assertEqual(self.native_calls(f, case), [], 'A blocked caller reached the native CLI')
        transcripts = f.home / '.claude/projects'
        self.assertFalse(transcripts.is_dir() and list(transcripts.rglob(case['session'] + '.jsonl')))

    def positive(self):
        f, project, runtime = self.fixture()
        case = self.case(f, project, runtime, 'positive')
        _, calls = self.assert_delivered(f, project, case)
        self.assert_managed(f, project, case, calls)
        return f, project, runtime

    def test_maintained_spec_fence_prepares_forwards_and_delivers_one_reservation(self):
        self.positive()

    def test_maintained_spec_fence_without_control_forwarding_stays_legacy_and_fails_managed_oracle(self):
        f, project, runtime = self.positive()
        case = self.case(f, project, runtime, 'missing-forwarding', mutation='remove-forwarding')
        # Legacy standalone launch stays compatible: real reservation and delivery with the unselected Sonnet argv.
        delivery, calls = self.assert_delivered(f, project, case)
        self.assertTrue((project / case['output_rel'] / 'validation.json').is_file(), 'Mutation must keep real prepare')
        self.assertEqual(set(delivery), SPEC_DELIVERY_FIELDS)
        self.assertFalse((case['launch'] / 'model-launch.json').exists())
        argv = calls[5]['argv']
        self.assertEqual((argv[argv.index('--model') + 1], '--effort' in argv, '--setting-sources' in argv),
                         ('sonnet', False, False))
        with self.assertRaises(AssertionError):
            self.assert_managed(f, project, case, calls)

    def test_maintained_spec_fence_blocks_wrong_role_and_raw_control_drift_before_reservation(self):
        f, project, runtime = self.positive()
        case = self.case(f, project, runtime, 'wrong-role', request_role='spec-reviewer-b')
        self.assertEqual(case['result'].returncode, 2, 'Expected the typed prepare failure: ' + case['result'].stderr[-1600:])
        self.assertEqual(json.loads(case['result'].stderr),
                         {'schema': 'model-policy-error/v1', 'reason': 'scope-mismatch',
                          'message': 'Policy request role or host differs from the actual invocation.'},
                         'The fence must stop on the preparation error alone')
        self.assertFalse((project / case['output_rel'] / 'validation.json').exists())
        self.assert_blocked(f, project, case)
        case = self.case(f, project, runtime, 'raw-control-drift', mutation='raw-control-drift')
        self.assertEqual((case['result'].returncode, case['result'].stderr),
                         (1, 'LAUNCH_STOPPED: input-invalid: Controls bytes do not match the supplied raw SHA-256 pin.\n'))
        directory = project / case['output_rel']
        validation = json.loads((directory / 'validation.json').read_bytes())
        self.assertNotEqual(validation['controls']['sha256'], launch.sha_file(directory / 'controls.json'),
                            'Mutation must follow real prepare and drift the validated raw controls')
        self.assert_blocked(f, project, case)


    def test_maintained_spec_pair_preserves_sanitized_boundary_and_both_retrospective_bindings(self):
        b_agent = 'plugins/sdd-review-loop/agents/' + SPEC_CALLER_B_ROLE + '.md'
        b_checks = ['AMBIGUITY', 'CONTRADICTION', 'EDGE-CASE-COVERAGE', 'ASSUMPTIONS-RESOLVABLE', 'APPROVAL-BOUNDARY',
                    'DOWNSTREAM-READINESS', 'DOMAIN-CONFORMANCE']
        f, project, runtime = self.fixture(extra_runtime=(b_agent,))
        self.assertEqual(runtime.get(b_agent), launch.sha_file(ROOT / b_agent),
                         'Actual B role source must be installed before reviewer A launches')
        # Reviewer A: fresh per-role request/observation, then the existing complete positive assertions.
        a = self.case(f, project, runtime, 'pair-a', names=('request-spec-a.json', 'observation-spec-a.json'))
        _, calls_a = self.assert_delivered(f, project, a)
        self.assert_managed(f, project, a, calls_a)
        after_a = self.chain(project / SPEC_LEDGER)
        round_dir = project / a['round_rel']
        raw_a, summary_path = round_dir / 'reviewer-a.json', round_dir / 'integrated-summary.json'
        summary_rel = a['round_rel'] + '/integrated-summary.json'
        self.assertFalse(raw_a.exists() or summary_path.exists(), 'Round already holds reviewer output before A is persisted')
        wrapper_a = json.loads((a['launch'] / 'wrapper.json').read_bytes())
        review_a = wrapper_a['structured_output']
        raw_a.write_text(wrapper_a['result'] + '\n')  # the actual returned raw JSON; no invented review
        self.assertEqual(json.loads(raw_a.read_bytes()), review_a)
        counts = {result: sum(1 for check in review_a['checks'] if check['result'] == result)
                  for result in ('FAIL', 'PASS', 'SKIP')}
        summary_path.write_text(json.dumps({
            'schema': 'integrated-summary/v1', 'attempt': 1, 'round': 1, 'generated_at': launch.utc_now(),
            'reviewer_a_checks': [{key: check[key] for key in ('id', 'result', 'severity')} for check in review_a['checks']],
            'reviewer_a_fail_count': counts['FAIL'], 'reviewer_a_pass_count': counts['PASS'],
            'reviewer_a_skip_count': counts['SKIP']}, indent=2) + '\n')
        summary_text = summary_path.read_text()
        summary = json.loads(summary_text)
        self.assertEqual(sorted(summary), ['attempt', 'generated_at', 'reviewer_a_checks', 'reviewer_a_fail_count',
                                           'reviewer_a_pass_count', 'reviewer_a_skip_count', 'round', 'schema'])
        self.assertTrue(all(sorted(check) == ['id', 'result', 'severity'] for check in summary['reviewer_a_checks']))
        self.assertEqual((counts['FAIL'], counts['PASS'], counts['SKIP']), (1, 0, len(review_a['checks']) - 1),
                         'Fixture-only A output is first FAIL, remaining SKIP')
        for forbidden in (review_a['checks'][0]['finding'], a['session'], 'finding', 'allowed_input_manifest', 'sha256',
                          'run_id', 'host_session_id'):
            self.assertNotIn(forbidden, summary_text, 'The sanitized summary leaked reviewer A raw content')
        # The precheck's own jq comparisons (spec-review-precheck.sh:403-406), run by the actual jq.
        for left, right in (('[.checks[] | {id, result, severity}]', '.reviewer_a_checks'),
                            ('[.checks[] | select(.result == "FAIL")] | length', '.reviewer_a_fail_count'),
                            ('[.checks[] | select(.result == "PASS")] | length', '.reviewer_a_pass_count'),
                            ('[.checks[] | select(.result == "SKIP")] | length', '.reviewer_a_skip_count')):
            projected = [self.execute(f, ['jq', '-c', expression, str(path)], cwd=project)
                         for expression, path in ((left, raw_a), (right, summary_path))]
            self.assertEqual([item.returncode for item in projected], [0, 0])
            self.assertEqual(projected[0].stdout, projected[1].stdout, 'Summary differs from A projection: ' + right)

        def pin(case):
            """Complete persisted closure of one launch plus every request, input and policy it pinned."""
            files = {case['invocation'].relative_to(project).as_posix(), case['request'], 'registry.json',
                     *case['closure'], *case['paths']}
            return {'outputs': tree(project / case['output_rel']), 'launch': tree(case['launch']),
                    'files': {path: launch.sha_file(project / path) for path in sorted(files)}}
        a_pin = pin(a)
        sealed = {path: launch.sha_file(path) for path in (raw_a, summary_path)}
        diagnostic_a = json.loads((a['launch'] / 'native.jsonl').read_text().splitlines()[0])['diagnostic_session']
        # Reviewer B: same feature/round, actual A precheck reused, fresh UUID, ledger tip produced by A.
        b = self.case(f, project, runtime, 'pair-b', role=SPEC_CALLER_B_ROLE, request_role=SPEC_CALLER_B_ROLE, shared=a,
                      names=('request-spec-b.json', 'observation-spec-b.json'))
        self.assertEqual((b['feature'], b['round_rel'], b['records'], b['paths']),
                         (a['feature'], a['round_rel'], after_a, [*a['paths'], summary_rel]))
        self.assertEqual(len({a['session'], diagnostic_a, b['session']}), 3, 'B identity must be disjoint from A and its probe')
        _, calls_b = self.assert_delivered(f, project, b)
        self.assert_managed(f, project, b, calls_b)
        after_b = self.chain(project / SPEC_LEDGER)
        self.assertEqual((after_b[:-1], after_b[-1]['sequence'], after_b[-1]['previous_record_sha256'], after_b[-1]['role'],
                          after_b[-1]['run_id'], after_b[-1]['host_session_id']),
                         (after_a, len(after_a) + 1, after_a[-1]['record_sha256'], SPEC_CALLER_B_ROLE, b['session'],
                          b['session']), 'B must append exactly one canonical record after the A tip')
        diagnostic_b = json.loads((b['launch'] / 'native.jsonl').read_text().splitlines()[0])['diagnostic_session']
        self.assertFalse([r for r in after_b if {r['run_id'], r['host_session_id']} & {diagnostic_a, diagnostic_b}],
                         'Probe identities must stay unreserved')
        # B's schema, check order, manifest, generated policy and formal Read audit: summary in, raw A/wrapper/transcript out.
        review_b = json.loads((b['launch'] / 'wrapper.json').read_bytes())['structured_output']
        self.assertEqual((review_b['schema'], review_b['role'], [check['id'] for check in review_b['checks']]),
                         (SPEC_CALLER_B_ROLE + '/v1', SPEC_CALLER_B_ROLE, b_checks))
        manifest_b = json.loads(b['invocation'].read_bytes())['allowed_input_manifest']
        self.assertEqual((manifest_b, manifest_b[-1]), (b['entries'], {'path': summary_rel, 'sha256': launch.sha_file(summary_path)}))
        a_launch = a['launch'].relative_to(project).as_posix()
        excluded = [a['round_rel'] + '/reviewer-a.json', a_launch + '/wrapper.json', a_launch + '/' + a['session'] + '.jsonl']
        self.assertFalse(set(excluded) & {entry['path'] for entry in manifest_b})
        reads = [str((project / path).resolve()) for path in
                 [b['invocation'].relative_to(project).as_posix(), SPEC_CALLER_BOUNDARY, *b['paths']]]
        audited = [tool['path'] for tool in calls_b[5]['tools'] if tool['tool'] == 'Read']
        settings = json.loads((b['launch'] / 'settings.json').read_bytes())
        hooks = [hook['command'] for group in settings['hooks']['PreToolUse'] for hook in group['hooks']]
        self.assertEqual(len(hooks), 1)
        guard = project / 'plugins/sdd-review-loop/scripts/nontty-impl-pretool-guard.mjs'
        parts = shlex.split(hooks[0])
        self.assertEqual((parts[:4], parts[6:]), (['rtk', 'proxy', 'node', str(guard)], ['||', 'exit', '2']))
        policy_raw = Path(parts[4]).read_bytes()
        self.assertEqual(parts[5], hashlib.sha256(policy_raw).hexdigest(), 'Hook must pin the exact raw policy bytes')
        policy = json.loads(policy_raw)
        self.assertEqual((sorted(policy), policy['schema'], policy['output_tool']),
                         (['bash_commands', 'output_tool', 'read_paths', 'schema'], 'impl-nontty-pretool/v1', 'StructuredOutput'))
        self.assertEqual((policy['read_paths'], audited), (reads, reads),
                         'Generated policy and formal Read audit must be the exact B closure')
        self.assertIn(str(summary_path.resolve()), policy['read_paths'])
        for path in excluded:
            self.assertNotIn(str((project / path).resolve()), policy['read_paths'] + audited)
        self.assertFalse([path for path in policy['read_paths'] + audited if a['session'] in path])
        # Real generated B hook: summary is admitted, raw A is denied by the actual Node guard; no native send, no writes.
        ledger_bytes = (project / SPEC_LEDGER).read_bytes()

        def hook(path):
            event = json.dumps({'session_id': b['session'], 'transcript_path': str(b['launch'] / (b['session'] + '.jsonl')),
                                'cwd': str(project), 'hook_event_name': 'PreToolUse', 'tool_name': 'Read',
                                'tool_input': {'file_path': str(path)}})
            return self.execute(f, [launch.BASH, '-c', hooks[0]], cwd=project, stdin=event)
        allowed, denied = hook(summary_path), hook(raw_a)
        self.assertEqual((allowed.returncode, allowed.stdout, allowed.stderr), (0, '', ''), 'Summary Read must be admitted')
        self.assertEqual((denied.returncode, denied.stderr), (0, ''))
        self.assertEqual(json.loads(denied.stdout), {'hookSpecificOutput': {
            'hookEventName': 'PreToolUse', 'permissionDecision': 'deny',
            'permissionDecisionReason': 'Impl non-TTY tool call differs from caller-pinned inputs'}})
        self.assertEqual((len(self.native_calls(f, b)), (project / SPEC_LEDGER).read_bytes()),
                         (len(SPEC_NATIVE_MODES), ledger_bytes), 'Guard probes must not send or reserve')
        # A's complete closure is unchanged by B and both actual retrospective consumers accept their bindings.
        self.assertEqual(pin(a), a_pin, 'Reviewer B changed reviewer A persisted closure')
        self.assertEqual({path: launch.sha_file(path) for path in (raw_a, summary_path)}, sealed)
        self.assert_run_record(f, project, a)
        self.assert_run_record(f, project, b)


# ---- Maintained quality-gate non-TTY evaluator caller (FIXTURE ONLY) ---------------------------------------------------
# The same complete installed project as InstalledSpecCallerTests (its fixture/execute/chain are composed, no test method is
# inherited) with exactly six more quality files. Real: installer, prepare, canonical validator, scratch-history,
# delivery helper, preflights, probe, launcher, Node guard, model-run-record. Only the external `claude` is RECORDING_CLAUDE.
# Evidence class: FIXTURE ONLY (verified-configuration observation, fixture adoption, plaintext fixture NEEDS_WORK); it
# proves delivery/configuration, never a quality PASS, a model review, rerun tests or the actual backend identity.
QUALITY_CALLER_SKILL = 'plugins/sdd-quality-loop/skills/quality-gate/SKILL.md'
QUALITY_CALLER_CALIBRATION = 'plugins/sdd-quality-loop/references/quality-gate-calibration.md'
QUALITY_CALLER_RUBRIC = 'plugins/sdd-quality-loop/references/evaluation-rubric.md'
QUALITY_CALLER_RUNTIME = sorted({
    QUALITY_CALLER_SKILL, QUALITY_CALLER_CALIBRATION, QUALITY_CALLER_RUBRIC,
    'plugins/sdd-quality-loop/agents/evaluator.md',
    'plugins/sdd-quality-loop/scripts/preflight-evaluator-delivery.py',
    'plugins/sdd-quality-loop/scripts/validate-feature-scratch-history.py'})
QUALITY_CALLER_ROLE = 'sdd-evaluator'  # invocation/native transport role
QUALITY_CALLER_POLICY_ROLE = 'evaluator'  # model-policy role; its run-record actor slot is main
QUALITY_CALLER_TASK = 'T-001'
QUALITY_SNAPSHOTS = 'reports/review-context/scratch-reservations'
# Exactly the two forwarded launcher controls; a value may be quoted, a command substitution or a plain word.
QUALITY_FORWARDING = re.compile(r'--model-controls(?:-sha256)?(?:[ \t]+|=)'
                                r'(?:"[^"\n]*"|\x27[^\x27\n]*\x27|\$\([^)\n]*\)|[^\s`\\]+)')
QUALITY_FEATURE_FILES = {
    'requirements.md': '# Requirements\n\nFIXTURE ONLY: exercises the quality-gate caller boundary; no domain or design-system surface.\n\n'
                       '- REQ-001: The fixture task declares one harmless output.\n',
    'design.md': '# Design\n\nFIXTURE ONLY: one declared output file and nothing else.\n',
    'acceptance-tests.md': '# Acceptance tests\n\n| AC-ID | Requirement | Status |\n|---|---|---|\n| AC-001 | REQ-001 | Planned |\n',
    'tasks.md': '# Tasks\n\n## T-001 Fixture task\n\n- Task ID: T-001\n- Status: Implementation Complete\n',
    'traceability.md': '# Traceability\n\n| Requirement | Acceptance | Task |\n|---|---|---|\n| REQ-001 | AC-001 | T-001 |\n'}


class InstalledQualityCallerTests(unittest.TestCase):
    """Execute the maintained quality-gate non-TTY evaluator entry through a complete same-root installed project."""

    # Compose shared test support without inheriting and rediscovering its tests.
    _spec_helpers: Any = InstalledSpecCallerTests
    execute = _spec_helpers.execute
    chain = _spec_helpers.chain
    native_calls = _spec_helpers.native_calls

    def fixture(self):
        return self._spec_helpers.fixture(self, extra_runtime=QUALITY_CALLER_RUNTIME)

    @staticmethod
    def spans(source, token):
        """Distinct inline code spans or fences of the skill that contain `token`, in document order."""
        found = {}
        for match in re.finditer(re.escape(token), source):
            before, after = source.rfind('`', 0, match.start()), source.find('`', match.end())
            if before < 0 or after < 0:
                continue
            fence = before >= 2 and source[before - 2:before + 1] == '```'
            body = source[source.index('\n', before) + 1:after].rstrip('\n') if fence else source[before + 1:after]
            if '\n\n' not in body and len(body) < 2000:
                found[before] = body if fence else ' '.join(body.split())
        return [found[key] for key in sorted(found)]

    def entry(self, project):
        """The installed maintained skill is the oracle: its inline or fenced prepare/launcher commands, in document order."""
        source = (project / QUALITY_CALLER_SKILL).read_text(encoding='utf-8')
        launchers = [unit for unit in self.spans(source, 'launch-impl-review.py') if '--manifest-sha256' in unit]
        prepares = [unit for unit in self.spans(source, 'managed-model-entry.py') if ' prepare' in unit]
        self.assertEqual(len(launchers), 1, 'Expected one maintained quality launcher command (setup failure)')
        self.assertLessEqual(len(prepares), 1, 'Expected at most one maintained prepare command (setup failure)')
        if not prepares or prepares[0] == launchers[0]:
            return launchers[0]
        return prepares[0] + ' &&\n' + launchers[0]  # separate prose commands: a failed prepare stops the caller

    @staticmethod
    def snapshot_names(project):
        directory = project / QUALITY_SNAPSHOTS
        return {path.name for path in directory.iterdir()} if directory.is_dir() else set()

    def case(self, f, project, runtime, label, *, request_role=QUALITY_CALLER_POLICY_ROLE, mutation=None, defect=None):
        """Fresh feature with actual task/report/manifest/scratch fixtures and exact invocation/v2; the entry runs once.

        `mutation` alters the maintained command text; `defect` alters exactly one fixture fact before launch."""
        task, session, token = QUALITY_CALLER_TASK, str(uuid.uuid4()), uuid.uuid4().hex[:12]
        feature = 'quality-caller-' + token
        f.request = f.fresh_request(request_role)
        f.observation = f.fresh_observation()
        f.save()
        closure = sorted(f.closure())
        for name in sorted({'registry.json', *closure}):
            shutil.copyfile(f.root / name, project / name)
        shutil.copyfile(f.root / 'request.json', project / 'request.json')
        spec_dir = project / 'specs' / feature
        spec_dir.mkdir(parents=True)
        for name, text in QUALITY_FEATURE_FILES.items():
            (spec_dir / name).write_text(text)
        specs = ['specs/' + feature + '/' + name for name in QUALITY_FEATURE_FILES]
        artifact = 'artifacts/' + feature + '/fixture-output.txt'
        (project / artifact).parent.mkdir(parents=True)
        (project / artifact).write_text('FIXTURE ONLY: harmless declared output.\n')
        implementation_scratch = f.base / ('implementation-scratch-' + label)
        implementation_scratch.mkdir()
        implementation_run, implementation_session = 'fixture-implementation-run-' + token, 'fixture-implementation-session-' + token
        manifest_rel, report_rel = ('reports/implementation/' + feature + '/' + task + suffix
                                    for suffix in ('.input-manifest.json', '.md'))
        (project / manifest_rel).parent.mkdir(parents=True)
        (project / manifest_rel).write_text(json.dumps({
            'schema': 'task-input-manifest/v1', 'task_id': task, 'run_id': implementation_run,
            'session_id': implementation_session, 'agent_instance_id': 'fixture-implementation-agent',
            'model_tier': 'standard', 'provider': 'fixture', 'model': 'fixture-implementation',
            'estimated_cost_per_attempt_usd': '0', 'cost_estimate_source': 'FIXTURE ONLY: no cost was incurred',
            'cost_estimate_timestamp': '2026-01-01T00:00:00Z', 'isolation_mode': 'fresh-agent', 'fallback_reason': '',
            'handoff_reload_evidence_hash': '', 'allowed_inputs': [{'path': path, 'sha256': launch.sha_file(project / path)}
                                                                   for path in specs],
            'allowed_outputs': [artifact]}, indent=2) + '\n')
        report_run = implementation_run + '-other' if defect == 'report-identity' else implementation_run
        (project / report_rel).write_text('\n'.join([
            '# Implementation Report: ' + task, '', '- Task ID: ' + task, 'Run ID: ' + report_run,
            '- **Run ID**: ' + report_run, '- **Session ID**: ' + implementation_session,
            '- **Scratch Root**: ' + str(implementation_scratch), '',
            'Input manifest: `%s`, SHA-256 `%s`' % (manifest_rel, launch.sha_file(project / manifest_rel)), '',
            '## Outputs', '', '| Path | SHA-256 |', '|---|---|',
            '| `%s` | `%s` |' % (artifact, launch.sha_file(project / artifact)),
            '| `%s` | `%s` |' % (QUALITY_CALLER_RUBRIC, launch.sha_file(project / QUALITY_CALLER_RUBRIC)), '',
            '## Verification', '', 'FIXTURE ONLY: no tests were run and no review or gate has passed for this task.', '']))
        paths = [*specs, QUALITY_CALLER_CALIBRATION, QUALITY_CALLER_RUBRIC, report_rel, manifest_rel, artifact]
        entries = [{'path': path, 'sha256': launch.sha_file(project / path)} for path in paths]
        scratch = implementation_scratch / 'evaluator' if defect == 'scratch-overlap' else f.base / ('evaluator-scratch-' + label)
        for entry in entries:  # byte-for-byte projection at the admitted relative path
            (scratch / entry['path']).parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(project / entry['path'], scratch / entry['path'])
        scratch = scratch.resolve()
        self.assertEqual({entry['path']: launch.sha_file(scratch / entry['path']) for entry in entries},
                         {entry['path']: entry['sha256'] for entry in entries}, 'Scratch readback differs (setup failure)')
        if defect == 'scratch-drift':
            (scratch / QUALITY_CALLER_RUBRIC).write_bytes((scratch / QUALITY_CALLER_RUBRIC).read_bytes() + b'\nscratch drift\n')
        ledger = project / SPEC_LEDGER
        records = self.chain(ledger)
        self.assertFalse([r for r in records if session in (r['run_id'], r['host_session_id'])
                          or implementation_run in (r['run_id'], r['host_session_id'])
                          or implementation_session in (r['run_id'], r['host_session_id'])],
                         'Proposed and implementation identities must be absent before the launcher')
        transcripts = f.home / '.claude/projects'
        self.assertFalse(transcripts.is_dir() and list(transcripts.rglob(session + '.jsonl')))
        invocation = project / 'reports/quality-gate' / feature / ('evaluator-invocation-' + session + '.json')
        invocation.parent.mkdir(parents=True)
        document = {
            'schema': 'review-context-invocation/v2', 'input_mode': 'file-manifest', 'fallback_mode': 'none',
            'read_only': True, 'stage': 'quality', 'role': QUALITY_CALLER_ROLE, 'feature': feature, 'task_id': task,
            'run_id': session, 'host_session_id': session, 'sequence': len(records) + 1,
            'identity_ledger_path': SPEC_LEDGER, 'identity_ledger_sha256': launch.sha_file(ledger),
            'previous_record_sha256': records[-1]['record_sha256'], 'allowed_input_manifest': entries,
            'implementation_manifest': {'path': manifest_rel, 'sha256': launch.sha_file(project / manifest_rel)},
            'scratch_root': str(scratch)}
        invocation.write_text(json.dumps(document, indent=2) + '\n')
        pin = launch.sha_file(invocation)  # the external caller pin is taken from these frozen bytes
        if defect == 'stale-pin':
            invocation.write_text(json.dumps(document, sort_keys=True) + '\n')  # same content, different raw bytes
        output_rel = 'runs/evaluator-' + session
        values = {'<absolute-repository-root>': str(project), '<repository-root>': str(project),
                  '<absolute-invocation-path>': str(invocation), '<invocation>': str(invocation),
                  '<reports/quality-gate/launch-SESSION>': 'reports/quality-gate/launch-' + session,
                  '<caller-pin>': pin, '<UUID>': session, '<role>': QUALITY_CALLER_POLICY_ROLE,
                  '<policy-role>': QUALITY_CALLER_POLICY_ROLE, '<transport-role>': QUALITY_CALLER_ROLE,
                  '<policy-request>': 'request.json', '<registry>': 'registry.json', '<run-id>': session,
                  '<session-id>': session, '<attempt>': '1', '<output-dir>': output_rel}
        text = self.entry(project)
        for old, new in values.items():
            text = text.replace(old, new)
        for relative in [ADAPTER, *SPEC_CALLER_RUNTIME, *QUALITY_CALLER_RUNTIME]:
            text = re.sub(r'(?<![\w./-])' + re.escape(relative), lambda _: str(project / relative), text)
        self.assertIsNone(re.search(r'<[A-Za-z][^<>\s]*>', text), 'Undocumented fixture placeholder')
        launcher = str(project / SPEC_CALLER_LAUNCHER)
        lines = text.splitlines(keepends=True)
        indexes = [index for index, line in enumerate(lines) if launcher in line]
        self.assertEqual(len(indexes), 1, 'Mutation and oracle need the one actual maintained launcher invocation')
        start = end = indexes[0]
        while start and lines[start - 1].rstrip('\n').endswith('\\'):
            start -= 1
        while end + 1 < len(lines) and lines[end].rstrip('\n').endswith('\\'):
            end += 1
        if mutation == 'remove-forwarding':
            command, count = QUALITY_FORWARDING.subn('', ''.join(lines[start:end + 1]))
            self.assertEqual(count, 2, 'Mutation must remove exactly the two launcher control flags, keeping prepare')
            text = ''.join(lines[:start]) + command + ''.join(lines[end + 1:])
        elif mutation == 'raw-control-drift':
            text = ''.join(lines[:start] + ['printf "\\n" >> ' + shlex.quote(output_rel + '/controls.json') + ' &&\n'] +
                           lines[start:])
        else:
            self.assertIsNone(mutation, 'Unknown deliberate entry mutation')
        script = f.base / ('quality-caller-' + label + '.sh')
        script.write_text(text + '\n')
        audit = f.audit.read_bytes() if f.audit.exists() else b''
        before, snapshots, scratch_before = ledger.read_bytes(), self.snapshot_names(project), tree(scratch)
        result = self.execute(f, [launch.BASH, str(script)], cwd=project, timeout=900)
        self.assertFalse(f.poison.exists(), 'Caller used the poisoned source package')
        after = runtime_tree(project)
        self.assertEqual({path: after.get(path) for path in runtime}, runtime, 'Caller changed installed runtime')
        self.assertFalse([path for path in after if path.startswith(('plugins/', 'contracts/')) and path not in runtime],
                         'Caller added files to the installed runtime')
        self.assertEqual({entry['path']: launch.sha_file(project / entry['path']) for entry in entries},
                         {entry['path']: entry['sha256'] for entry in entries}, 'Reviewed sources or status changed')
        self.assertEqual(tree(scratch), scratch_before, 'Caller changed the evaluator scratch projection')
        self.assertEqual(tree(f.home / '.codex'), f.codex_home, 'Caller changed user native Codex configuration')
        self.assertEqual({path: digest for path, digest in tree(f.home / '.claude').items()
                          if not path.startswith('projects/')}, f.claude_home, 'Caller changed user Claude configuration')
        return {'session': session, 'feature': feature, 'entries': entries, 'paths': paths, 'invocation': invocation,
                'output_rel': output_rel, 'launch': project / 'reports/quality-gate' / ('launch-' + session),
                'result': result, 'records': records, 'ledger': before, 'audit': audit, 'request': 'request.json',
                'closure': closure, 'scratch': str(scratch), 'scratch_tree': scratch_before, 'snapshots': snapshots}

    def assert_delivered(self, f, project, case):
        """Route-independent complete positive: genuine probe, one launcher reservation, verified plaintext delivery."""
        session, output, result = case['session'], case['launch'], case['result']
        self.assertEqual(result.returncode, 0, 'Valid maintained quality entry failed: ' + result.stderr[-2400:])
        delivery = json.loads((output / 'delivery.json').read_bytes())
        self.assertEqual({key: delivery.get(key) for key in SPEC_DELIVERY_FIELDS},
                         {'status': 'DELIVERY_OK', 'session_id': session,
                          'prompt_sha256': launch.sha_file(output / 'prompt.txt'),
                          'prompt_bytes': len((output / 'prompt.txt').read_bytes()),
                          'transcript_sha256': launch.sha_file(output / (session + '.jsonl')),
                          'wrapper_sha256': launch.sha_file(output / 'wrapper.json')})
        before, ledger = case['records'], project / SPEC_LEDGER
        records = self.chain(ledger)
        self.assertEqual(records[:-1], before, 'Exactly one record may be appended to the prior chain')
        sequence, previous = len(before) + 1, before[-1]['record_sha256']
        binding = sha_text(case['feature'] + '\n' + case['scratch'])
        digest = sha_text('|'.join((str(sequence), 'quality', QUALITY_CALLER_ROLE, session, session, previous,
                                    'scratch-declaration-v1', binding)))
        self.assertEqual(records[-1], {'sequence': sequence, 'stage': 'quality', 'role': QUALITY_CALLER_ROLE,
                                       'run_id': session, 'host_session_id': session, 'previous_record_sha256': previous,
                                       'record_sha256': digest, 'scratch_declaration_sha256': binding})
        self.assertFalse(ledger.with_name(ledger.name + '.lock').exists(), 'Reservation lock was left behind')
        receipt = ('REVIEW_CONTEXT_OK %s sequence=%d previous_record_sha256=%s pre_append_tip_sequence=%d '
                   'identity_unique=yes\n' % (digest, sequence, previous, sequence - 1))
        summary = 'EVALUATOR_DELIVERY_OK inputs=%d; reservation=performed\n' % len(case['entries'])
        self.assertEqual({name: (output / name).read_text() for name in
                          ('preview.txt', 'preview-after.txt', 'receipt.txt', 'reserved.txt')},
                         {'preview.txt': receipt, 'preview-after.txt': receipt, 'receipt.txt': receipt,
                          'reserved.txt': receipt + summary})
        snapshots = self.snapshot_names(project)
        self.assertEqual(sorted(snapshots - case['snapshots']), [digest + '.json'],
                         'Exactly one genuine scratch-reservation snapshot must be created')
        self.assertEqual((project / QUALITY_SNAPSHOTS / (digest + '.json')).read_text(),
                         json.dumps(json.loads(case['invocation'].read_bytes()), sort_keys=True) + '\n')
        native = [json.loads(line) for line in (output / 'native.jsonl').read_text().splitlines()]
        diagnostic = native[0].get('diagnostic_session')
        self.assertEqual(native[:2], [{'diagnostic_session': diagnostic, 'reservation': 'not performed'},
                                      {'session': diagnostic, 'exit': 0, 'stderr_present': False}])
        self.assertNotEqual(diagnostic, session)
        self.assertFalse([r for r in records if diagnostic in (r['run_id'], r['host_session_id'])], 'The probe reserved')
        proof = native[-1]
        guard = project / 'plugins/sdd-review-loop/scripts/nontty-impl-pretool-guard.mjs'
        self.assertEqual({key: proof.get(key) for key in (
            'admitted_read_executed', 'outside_read_pretool_denied', 'chained_bash_pretool_denied',
            'existing_session_collision_rejected', 'control_reads_executed', 'source_invocation_read_executed',
            'source_invocation_sha256', 'admitted_paths', 'ordered_hashes_verified', 'fixed_input_record_sha256',
            'guard_sha256')},
            {'admitted_read_executed': True, 'outside_read_pretool_denied': True, 'chained_bash_pretool_denied': True,
             'existing_session_collision_rejected': True, 'control_reads_executed': True,
             'source_invocation_read_executed': True, 'source_invocation_sha256': launch.sha_file(case['invocation']),
             'admitted_paths': case['paths'], 'ordered_hashes_verified': len(case['entries']) + 5,
             'fixed_input_record_sha256': None, 'guard_sha256': launch.sha_file(guard)})
        homes = sorted((f.home / '.claude/projects').rglob('*.jsonl'))
        formal_home = [path for path in homes if path.name == session + '.jsonl']
        diagnostic_home = [path for path in homes if path.name == diagnostic + '.jsonl']
        self.assertEqual((len(formal_home), len(diagnostic_home)), (1, 1), 'Native transcripts missing or ambiguous')
        self.assertEqual(formal_home[0].read_bytes(), (output / (session + '.jsonl')).read_bytes())
        self.assertEqual(launch.sha_file(diagnostic_home[0]), proof['transcript_sha256'],
                         'Duplicate-session rejection changed the diagnostic transcript')
        calls = self.native_calls(f, case)
        self.assertEqual([call['mode'] for call in calls], SPEC_NATIVE_MODES)
        probe_call, collision, formal = calls[2], calls[3], calls[5]
        self.assertEqual((probe_call['session_id'], collision['session_id'], collision['argv'], formal['session_id']),
                         (diagnostic, diagnostic, probe_call['argv'], session))
        plugin_dir = str(project / 'plugins/sdd-review-loop')
        for call in (probe_call, formal):
            argv = call['argv']
            self.assertEqual((argv[:3], argv[argv.index('--plugin-dir') + 1], argv[argv.index('--agent') + 1],
                              argv[argv.index('--tools') + 1], '--json-schema' in argv),
                             (['-p', '--session-id', call['session_id']], plugin_dir, QUALITY_CALLER_ROLE,
                              'Read,Bash', False), 'Quality has Read/Bash and no structured-output schema')
        self.assertEqual((project / Path(formal['argv'][formal['argv'].index('--settings') + 1])).resolve(),
                         (output / 'settings.json').resolve())
        self.assertEqual([(t['tool'], t['decision'], t['is_error']) for t in probe_call['tools']],
                         [('Bash', 'allow', False)] + [('Read', 'allow', False)] * len(proof['native_read_paths']) +
                         [('Bash', 'deny', True), ('Read', 'deny', True)])
        invocation_rel = case['invocation'].relative_to(project).as_posix()
        reads = [str((project / path).resolve()) for path in [invocation_rel, SPEC_CALLER_BOUNDARY, *case['paths']]]
        self.assertEqual([(t['tool'], t['decision'], t['is_error'], t.get('path'), t.get('sha256')) for t in formal['tools']],
                         [('Bash', 'allow', False, None, None)] +
                         [('Read', 'allow', False, path, launch.sha_file(Path(path))) for path in reads],
                         'Pinned verifier first, then exactly the admitted Reads; no output tool')
        settings = json.loads((output / 'settings.json').read_bytes())
        hooks = [hook['command'] for group in settings['hooks']['PreToolUse'] for hook in group['hooks']]
        self.assertEqual(len(hooks), 1)
        parts = shlex.split(hooks[0])
        self.assertEqual((parts[:4], parts[6:]), (['rtk', 'proxy', 'node', str(guard)], ['||', 'exit', '2']))
        policy_raw = (project / parts[4]).read_bytes()
        self.assertEqual(parts[5], hashlib.sha256(policy_raw).hexdigest(), 'Hook must pin the exact raw policy bytes')
        policy = json.loads(policy_raw)
        self.assertEqual((sorted(policy), policy['schema'], policy['read_paths'], len(policy['bash_commands'])),
                         (['bash_commands', 'read_paths', 'schema'], 'impl-nontty-pretool/v1', reads, 1))
        self.assertEqual((settings['permissions']['allow'], formal['tools'][0]['command']),
                         (['Bash(' + policy['bash_commands'][0] + ')'], policy['bash_commands'][0]))
        wrapper = json.loads((output / 'wrapper.json').read_bytes())
        last = json.loads((output / (session + '.jsonl')).read_text().splitlines()[-1])
        self.assertEqual((last['type'], [block['type'] for block in last['message']['content']]), ('assistant', ['text']),
                         'The ordered transcript must end with the assistant text')
        text = last['message']['content'][0]['text']
        self.assertEqual(set(wrapper), {'type', 'subtype', 'is_error', 'session_id', 'num_turns', 'result'},
                         'Quality has no structured_output')
        self.assertEqual((wrapper['type'], wrapper['is_error'], wrapper['session_id'], wrapper['result']),
                         ('result', False, session, text))
        lines = text.splitlines()
        self.assertEqual([line for line in lines if line.startswith(('RUN_ID:', 'HOST_SESSION_ID:', 'ALLOWED_INPUT_MANIFEST:',
                                                                      'VERDICT:'))],
                         ['RUN_ID: ' + session, 'HOST_SESSION_ID: ' + session,
                          'ALLOWED_INPUT_MANIFEST: ' + invocation_rel + ' ' + launch.sha_file(case['invocation']),
                          'VERDICT: NEEDS_WORK'], 'Fixture-only delivery record, never an approval')
        self.assertEqual((lines.count('FINDINGS:'), lines.count('CHECKED:'), lines[0].startswith('FIXTURE ONLY')),
                         (1, 1, True))
        self.assertIn('no model reviewed', text)
        self.assertIn('Tests were not rerun', text)
        return delivery, calls

    def assert_managed(self, f, project, case, calls):
        """Managed oracle: real installed prepare controls forwarded, generated native evaluator and bound delivery."""
        session, output, role = case['session'], case['launch'], QUALITY_CALLER_POLICY_ROLE
        directory = project / case['output_rel']
        self.assertTrue((directory / 'validation.json').is_file(), 'Maintained caller omitted installed prepare')
        self.assertEqual(sorted(path.name for path in directory.iterdir()), OUTPUT_FILES)
        controls, selection, validation = [json.loads((directory / name).read_bytes()) for name in OUTPUT_FILES]

        def ref(path):
            return {'path': path, 'sha256': launch.sha_file(project / path)}
        self.assertEqual(controls, {'schema': 'model-launch-controls/v1', 'role': role, 'host': launch.HOST,
                                    'attempt': 1, 'require_actual_id': False,
                                    'selection': ref(case['output_rel'] + '/selection.json'),
                                    'request': ref(case['request']), 'registry': ref('registry.json'),
                                    'inputs': [ref(path) for path in case['closure']]})
        self.assertEqual(set(validation), launch.VALIDATION_FIELDS)
        self.assertEqual(validation['controls'], ref(case['output_rel'] + '/controls.json'))
        self.assertEqual(validation['pins'], sorted([controls['selection'], controls['request'], controls['registry'],
                                                    *controls['inputs']], key=lambda item: item['path']))
        self.assertEqual(validation['trusted'], [{'path': path, 'sha256': launch.sha_file(ROOT / path)}
                                                 for path in launch.TRUSTED_PATHS], 'trusted runtime is current bytes')
        self.assertEqual([validation[key] for key in ('role', 'host', 'run_id', 'session_id', 'attempt', 'require_actual_id')],
                         [role, launch.HOST, session, session, 1, False])
        self.assertEqual(validation['selection'], selection)
        self.assertEqual(selection, f.helper().bind_selection(InstalledEntryTests.oracle_selection(f),
                                                              run_id=session, session_id=session, attempt=1))
        native, effort = selection['resolved']['native_id'], selection['resolved']['effort']
        trusted = next(m for m in f.trusted_policy['models'] if m['id'] == selection['resolved']['catalog_id'])
        self.assertEqual(native, trusted['hosts'][launch.HOST], 'trusted mapping only')
        launch_path = output / 'model-launch.json'
        self.assertTrue(launch_path.is_file(), 'Launcher did not bind the forwarded model controls')
        launch_raw = launch_path.read_bytes()
        record = json.loads(launch_raw)
        self.assertEqual(set(record), launch.LAUNCH_FIELDS)
        # The forwarded pin is the validated one; a fresh unchecked rehash is caught by the raw-drift case.
        self.assertEqual([record[key] for key in ('controls', 'pins', 'trusted')],
                         [validation[key] for key in ('controls', 'pins', 'trusted')])
        self.assertEqual({key: record[key] for key in (
            'schema', 'role', 'transport_role', 'host', 'run_id', 'session_id', 'attempt', 'require_actual_id',
            'selection_sha256', 'native_model', 'effort', 'effort_control', 'effort_carrier', 'native_alignment',
            'transport', 'native_overrides', 'model_argv', 'effort_argv', 'agent_model', 'agent_effort')},
            {'schema': 'model-launch-binding/v1', 'role': role, 'transport_role': QUALITY_CALLER_ROLE,
             'host': launch.HOST, 'run_id': session, 'session_id': session, 'attempt': 1, 'require_actual_id': False,
             'selection_sha256': selection['selection_sha256'], 'native_model': native, 'effort': effort,
             'effort_control': selection['resolved']['effort_control'], 'effort_carrier': 'flag+frontmatter',
             'native_alignment': 'generated', 'transport': 'claude-print',
             'native_overrides': dict.fromkeys(launch.NATIVE_OVERRIDES), 'model_argv': ['--model', native],
             'effort_argv': ['--effort', effort], 'agent_model': native, 'agent_effort': effort})
        probe_call, formal = calls[2], calls[5]
        argv = formal['argv']
        self.assertEqual(record['argv'], ['rtk', 'proxy', str(f.base / 'shims/claude'), *argv],
                         'Recorded launch argv must be the actual native argv')
        self.assertEqual(record['argv_sha256'], launch.sha_bytes(launch.canonical(record['argv'])))
        self.assertEqual([argv[argv.index(flag) + 1] for flag in ('--model', '--effort', '--setting-sources', '--agent')],
                         [native, effort, '', QUALITY_CALLER_ROLE])
        self.assertEqual([formal[key] for key in ('model', 'effort', 'agent', 'agent_model', 'agent_effort')],
                         [native, effort, QUALITY_CALLER_ROLE, native, effort])
        role_text = (project / 'plugins/sdd-quality-loop/agents/evaluator.md').read_text()
        self.assertEqual(json.loads(argv[argv.index('--agents') + 1]), {QUALITY_CALLER_ROLE: {
            'description': 'Repository-bound independent implementation reviewer',
            'prompt': role_text.split('---', 2)[2].strip(), 'model': native,
            'tools': ['Read', 'Bash'], 'disallowedTools': launch.DISALLOWED, 'effort': effort}},
            'Generated native role must carry the selection; the trusted role file is never edited')
        self.assertEqual((probe_call['model'], probe_call['effort']), ('sonnet', None),
                         'The unreserved probe stays the unselected permission diagnostic')
        delivery = json.loads((output / 'delivery.json').read_bytes())
        self.assertEqual(set(delivery), SPEC_DELIVERY_FIELDS | SPEC_MODEL_DELIVERY_FIELDS)
        binding_path = output / 'model-delivery-binding.json'
        self.assertEqual([delivery['model_launch_sha256'], delivery['model_delivery_binding_sha256']],
                         [launch.sha_bytes(launch_raw), launch.sha_file(binding_path)])

        def local(name):
            return ref((output / name).relative_to(project).as_posix())
        binding = json.loads(binding_path.read_bytes())
        self.assertEqual(binding, {'schema': 'model-delivery-binding/v1', 'launch_sha256': launch.sha_bytes(launch_raw),
                                   'transport': 'claude-print', 'selection': local('model-selection.json'),
                                   'events': local('model-events.json'), 'delivery': local('model-delivery.json'),
                                   'execution_context': local('model-execution-context.json'), 'run_id': session,
                                   'session_id': session, 'attempt': 1, 'selection_sha256': selection['selection_sha256']})
        model_delivery = {'schema': 'model-delivery/v1', 'selection_sha256': selection['selection_sha256'],
                          'run_id': session, 'session_id': session, 'turn_id': 'local-review-attempt-1',
                          'configured_id': native, 'actual_id': None, 'proof': 'unverified', 'source': 'unsupported',
                          'reroutes': [], 'status': 'accepted', 'reason': 'identity-unverified'}
        self.assertEqual([json.loads((output / name).read_bytes()) for name in ('model-selection.json', 'model-delivery.json')],
                         [selection, model_delivery], 'Delivery must bind the exact prepared selection')
        # The evaluator's actor slot is main (transport MAIN_MODEL_ROLES), never the reviewers slot.
        self._spec_helpers.assert_run_record(self, f, project, case, selection, model_delivery, slot='main')
        # shortcut: mtimes prove only non-decreasing write order on one filesystem; upgrade with a launcher event log.
        order = [output / name for name in ('model-launch.json', 'native.jsonl', 'reserved.txt', 'prompt.txt',
                                            'wrapper.json', 'delivery.json')]
        self.assertEqual([path.stat().st_mtime_ns for path in order], sorted(path.stat().st_mtime_ns for path in order),
                         'Model launch binding must precede the probe, reservation and native send')

    def assert_blocked(self, f, project, case):
        """Stopped before reservation and native send: no launch output, ledger, snapshots, scratch and audit unchanged."""
        self.assertFalse(case['launch'].exists(), 'A blocked caller created launch output')
        self.assertEqual((project / SPEC_LEDGER).read_bytes(), case['ledger'], 'A blocked caller changed the ledger')
        self.assertEqual(self.snapshot_names(project), case['snapshots'], 'A blocked caller created a scratch reservation')
        self.assertEqual(tree(Path(case['scratch'])), case['scratch_tree'], 'A blocked caller changed scratch')
        self.assertEqual(self.native_calls(f, case), [], 'A blocked caller reached the native CLI')
        transcripts = f.home / '.claude/projects'
        self.assertFalse(transcripts.is_dir() and list(transcripts.rglob(case['session'] + '.jsonl')))

    def canonical_preview(self, f, project, case):
        """The actual canonical validator on the same invocation, without reserving."""
        return self.execute(f, [launch.BASH, str(project / 'plugins/sdd-quality-loop/scripts/validate-review-context-set.sh'),
                                str(case['invocation']), str(project)], cwd=project)

    def assert_canonical(self, f, project, case, rejection=None):
        """Without `rejection` the canonical validator still admits the invocation, so the block came from the defect alone."""
        preview = self.canonical_preview(f, project, case)
        if rejection is None:
            self.assertEqual(preview.returncode, 0, 'Canonical validator rejected the control case: ' + preview.stderr[-800:])
            self.assertRegex(preview.stdout, r'REVIEW_CONTEXT_OK [0-9a-f]{64} sequence=[1-9][0-9]* ')
        else:
            self.assertEqual((preview.returncode, preview.stdout, preview.stderr), (1, '', rejection + '\n'))
        self.assertEqual((project / SPEC_LEDGER).read_bytes(), case['ledger'], 'A canonical preview must not reserve')

    def positive(self):
        f, project, runtime = self.fixture()
        case = self.case(f, project, runtime, 'positive')
        _, calls = self.assert_delivered(f, project, case)
        self.assert_managed(f, project, case, calls)
        return f, project, runtime

    def test_maintained_quality_entry_prepares_forwards_and_delivers_one_reservation(self):
        f, project, runtime = self.positive()
        case = self.case(f, project, runtime, 'missing-forwarding', mutation='remove-forwarding')
        # Legacy standalone launch stays compatible: real reservation and delivery with the unselected Sonnet argv.
        delivery, calls = self.assert_delivered(f, project, case)
        self.assertTrue((project / case['output_rel'] / 'validation.json').is_file(), 'Mutation must keep real prepare')
        self.assertEqual(set(delivery), SPEC_DELIVERY_FIELDS)
        self.assertFalse((case['launch'] / 'model-launch.json').exists())
        argv = calls[5]['argv']
        self.assertEqual((argv[argv.index('--model') + 1], '--effort' in argv, '--setting-sources' in argv),
                         ('sonnet', False, False))
        with self.assertRaises(AssertionError):
            self.assert_managed(f, project, case, calls)

    def test_maintained_quality_entry_blocks_wrong_role_and_raw_control_drift_before_reservation(self):
        f, project, runtime = self.positive()
        case = self.case(f, project, runtime, 'wrong-role', request_role=SPEC_CALLER_ROLE)
        self.assertEqual(case['result'].returncode, 2, 'Expected the typed prepare failure: ' + case['result'].stderr[-1600:])
        self.assertEqual(json.loads(case['result'].stderr),
                         {'schema': 'model-policy-error/v1', 'reason': 'scope-mismatch',
                          'message': 'Policy request role or host differs from the actual invocation.'},
                         'The entry must stop on the preparation error alone')
        self.assertFalse((project / case['output_rel'] / 'validation.json').exists())
        self.assert_blocked(f, project, case)
        self.assert_canonical(f, project, case)
        case = self.case(f, project, runtime, 'raw-control-drift', mutation='raw-control-drift')
        self.assertEqual((case['result'].returncode, case['result'].stderr),
                         (1, 'LAUNCH_STOPPED: input-invalid: Controls bytes do not match the supplied raw SHA-256 pin.\n'))
        directory = project / case['output_rel']
        validation = json.loads((directory / 'validation.json').read_bytes())
        self.assertNotEqual(validation['controls']['sha256'], launch.sha_file(directory / 'controls.json'),
                            'Mutation must follow real prepare and drift the validated raw controls')
        self.assert_blocked(f, project, case)
        self.assert_canonical(f, project, case)

    def test_maintained_quality_entry_blocks_scratch_pin_and_identity_drift_before_reservation(self):
        f, project, runtime = self.positive()
        case = self.case(f, project, runtime, 'scratch-copy-drift', defect='scratch-drift')
        self.assertEqual((case['result'].returncode, case['result'].stderr),
                         (1, 'LAUNCH_STOPPED: evaluator delivery preflight rejected: '
                             'EVALUATOR_DELIVERY_REJECTED: fixture-hash-mismatch\n'))
        self.assert_blocked(f, project, case)
        self.assert_canonical(f, project, case)  # the canonical validator admits it; only the scratch readback differs
        case = self.case(f, project, runtime, 'scratch-overlap', defect='scratch-overlap')
        self.assertEqual((case['result'].returncode, case['result'].stdout), (1, ''))
        self.assertTrue(case['result'].stderr.startswith('LAUNCH_STOPPED: '), case['result'].stderr[-800:])
        self.assert_blocked(f, project, case)
        self.assert_canonical(f, project, case,
                              'REVIEW_CONTEXT_PATH: evaluator scratch root overlaps the implementation scratch root')
        case = self.case(f, project, runtime, 'stale-pin', defect='stale-pin')
        self.assertEqual((case['result'].returncode, case['result'].stdout, case['result'].stderr),
                         (1, '', 'LAUNCH_STOPPED: caller invocation pin mismatch\n'))
        self.assert_blocked(f, project, case)
        self.assert_canonical(f, project, case)  # only the caller's external raw pin is stale
        case = self.case(f, project, runtime, 'report-identity', defect='report-identity')
        self.assertEqual((case['result'].returncode, case['result'].stdout), (1, ''))
        self.assertTrue(case['result'].stderr.startswith('LAUNCH_STOPPED: '), case['result'].stderr[-800:])
        self.assert_blocked(f, project, case)
        self.assert_canonical(f, project, case,
                              'REVIEW_CONTEXT_IDENTITY: implementation report run/session does not match its manifest')


if __name__ == '__main__':
    unittest.main()
