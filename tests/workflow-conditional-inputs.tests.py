#!/usr/bin/env python3
"""Persisted conditional manifests exercise both real workflow validators."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
class WorkflowFixture:
    feature = 'conditional-workflow-fixture'
    parent_directory = 'fixtures'

    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix='workflow-conditional-')
        cls.addClassCleanup(cls.temp.cleanup)
        fixture_parent = Path(cls.temp.name) / cls.parent_directory
        fixture_parent.mkdir()
        script = r'''
set -euo pipefail
source "$1/tests/lib/loop-driver.sh"
loop_fixture_init greenfield "$2"
printf '\nBounded-Context: sales\n' >> "$LOOP_FIXTURE_ROOT/specs/$LOOP_FIXTURE_FEATURE/requirements.md"
mkdir -p "$LOOP_FIXTURE_ROOT/docs/adr"
printf '# Fixture decision\n' > "$LOOP_FIXTURE_ROOT/docs/adr/0001-fixture.md"
printf '\nDecision: `docs/adr/0001-fixture.md`\n' >> "$LOOP_FIXTURE_ROOT/specs/$LOOP_FIXTURE_FEATURE/design.md"
drive_review_round spec 1 1 PASS none
_loop_set_status_field "$LOOP_FIXTURE_ROOT/specs/$LOOP_FIXTURE_FEATURE/requirements.md" Spec-Review-Status Passed
# The generic driver does not add actual ADRs to its reservation manifest.
eval "$(declare -f _loop_impl_manifest_a | sed '1s/_loop_impl_manifest_a/_base_impl_manifest_a/')"
eval "$(declare -f _loop_impl_manifest_b | sed '1s/_loop_impl_manifest_b/_base_impl_manifest_b/')"
_loop_impl_manifest_a() { _base_impl_manifest_a "$@" | jq --slurpfile p "$1/precheck-result.json" '. + $p[0].adr_inputs'; }
_loop_impl_manifest_b() { _base_impl_manifest_b "$@" | jq --slurpfile p "$1/precheck-result.json" '. + $p[0].adr_inputs'; }
drive_review_round impl 1 1 PASS none
_loop_set_status_field "$LOOP_FIXTURE_ROOT/specs/$LOOP_FIXTURE_FEATURE/design.md" Impl-Review-Status Passed
_loop_task_fixture_prepare "$LOOP_FIXTURE_FEATURE"
printf '\nFIXTURE_ROOT=%s\n' "$LOOP_FIXTURE_ROOT"
'''
        result = subprocess.run(['bash', '-c', script, 'fixture', str(ROOT), cls.feature],
                                env=dict(os.environ, TMPDIR=str(fixture_parent)),
                                text=True, capture_output=True)
        if result.returncode:
            raise RuntimeError(result.stdout + result.stderr)
        cls.root = Path(result.stdout.split('FIXTURE_ROOT=')[-1].strip())
        cls.runtimes = [('bash', '.sh')]
        if shutil.which('pwsh'):
            cls.runtimes.append(('pwsh', '.ps1'))
        else:
            raise unittest.SkipTest('pwsh required for runtime parity')
        copied = subprocess.run(['pwsh', '-NoProfile', '-Command',
                                 '. (Join-Path $env:WORKFLOW_TEST_REPO "tests/lib/loop-driver.ps1"); '
                                 'Copy-LoopFixtureScripts $env:WORKFLOW_TEST_FIXTURE'],
                                env=dict(os.environ, WORKFLOW_TEST_REPO=str(ROOT),
                                         WORKFLOW_TEST_FIXTURE=str(cls.root)), text=True, capture_output=True)
        if copied.returncode:
            raise RuntimeError(copied.stdout + copied.stderr)
        shutil.copy2(ROOT / 'plugins/sdd-quality-loop/scripts/check-risk.sh',
                     cls.root / 'plugins/sdd-quality-loop/scripts/check-risk.sh')
        cls.put('domain/context-map.md', 'Domain-Model-Status: Approved\n')
        cls.put('domain/domain-contract.json', json.dumps({
            'schema': 'domain-contract/v1',
            'meta': {'version': '1.0.0', 'status': 'Approved', 'generated_from': ['domain/context-map.md']},
            'contexts': [{'name': 'sales', 'description': '', 'terms': [], 'aggregates': [{
                'name': 'Order', 'root_entity': 'Order', 'invariants': ['valid'],
                'transaction_boundary': 'order', 'card': 'domain/aggregates/Order.md'}]}]}))
        cls.put('domain/aggregates/Order.md', '# Order\n')
        cls.put('domain/aggregates/Other.md', '# Unselected\n')
        for name, value in [('design-tokens.json', '{}'), ('design-system.md', '# Rules'), ('ui-patterns.md', '# Patterns')]:
            cls.put('design-system/' + name, value)
        cls.domain = ['domain/context-map.md', 'domain/domain-contract.json']
        cls.impl = cls.domain + ['domain/aggregates/Order.md', 'design-system/design-tokens.json',
                                 'design-system/design-system.md', 'design-system/ui-patterns.md']
        cls.documents = {}
        for stage in ('spec', 'impl'):
            directory = cls.root / f'reports/{stage}-review/{cls.feature}/attempt-1/round-1'
            for name in ('reviewer-a.json', 'reviewer-b.json', f'{stage}-review-contract.json'):
                path = directory / name
                cls.documents[path] = path.read_bytes()

    @classmethod
    def put(cls, relative, content):
        path = cls.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding='utf-8')

    def manifests(self, spec_inputs, impl_inputs, relocated=False):
        for path, original in self.documents.items():
            document = json.loads(original)
            items = document.get('reviewers', [document])
            stage = 'spec' if '/spec-review/' in str(path) else 'impl'
            for item in items:
                entries = item['allowed_input_manifest']
                def relative(value):
                    return value.removeprefix(str(self.root) + '/')
                entries[:] = [entry for entry in entries if not relative(entry['path']).startswith(('domain/', 'design-system/'))]
                for name in spec_inputs if stage == 'spec' else impl_inputs:
                    entries.append({'path': '/historical/checkout/' + name if relocated else name,
                                    'sha256': hashlib.sha256((self.root / name).read_bytes()).hexdigest()})
            path.write_text(json.dumps(document), encoding='utf-8')

    def check(self, accepted):
        for runtime, suffix in self.runtimes:
            with self.subTest(runtime=runtime):
                command = [runtime]
                if runtime == 'pwsh':
                    command += ['-NoProfile', '-File']
                command += [str(ROOT / ('plugins/sdd-quality-loop/scripts/check-workflow-state' + suffix)),
                            '--registry', str(self.root / 'specs/workflow-state-registry.json'), '--feature', self.feature]
                result = subprocess.run(command, text=True, capture_output=True)
                output = result.stdout + result.stderr
                if accepted:
                    self.assertEqual(result.returncode, 0, output)
                else:
                    self.assertNotEqual(result.returncode, 0, output)
                    self.assertRegex(output, r'(provenance|manifest|hash)', output)

    def precheck(self, stage, accepted):
        """Open a real new round, restoring the disposable fixture afterwards."""
        stage_reports = self.root / f'reports/{stage}-review/{self.feature}'
        design = self.root / f'specs/{self.feature}/design.md'
        tasks = self.root / f'specs/{self.feature}/tasks.md'
        original_design = design.read_bytes()
        for runtime, suffix in self.runtimes:
            with self.subTest(stage=stage, runtime=runtime), tempfile.TemporaryDirectory() as backup:
                saved = Path(backup) / 'reports'
                if stage_reports.exists():
                    shutil.move(str(stage_reports), str(saved))
                try:
                    if stage == 'impl':
                        # Model the earlier lifecycle, before task drafting.
                        tasks.rename(Path(backup) / 'tasks.md')
                        design.write_bytes(original_design.replace(b'Impl-Review-Status: Passed', b'Impl-Review-Status: Pending'))
                    command = [runtime]
                    if runtime == 'pwsh':
                        command += ['-NoProfile', '-File']
                    command += [str(self.root / f'plugins/sdd-review-loop/scripts/{stage}-review-precheck{suffix}'),
                                self.feature, '1', '1']
                    result = subprocess.run(command, cwd=self.root, text=True, capture_output=True)
                    output = result.stdout + result.stderr
                    if accepted:
                        self.assertEqual(result.returncode, 0, output)
                        self.assertTrue((stage_reports / 'attempt-1/round-1/precheck-result.json').is_file(), output)
                    else:
                        self.assertNotEqual(result.returncode, 0, output)
                        self.assertRegex(output, r'(provenance|manifest|hash)', output)
                finally:
                    if stage_reports.exists():
                        shutil.rmtree(stage_reports)
                    if saved.exists():
                        shutil.move(str(saved), str(stage_reports))
                    if (Path(backup) / 'tasks.md').exists():
                        (Path(backup) / 'tasks.md').rename(tasks)
                    design.write_bytes(original_design)


class WorkflowInputs(WorkflowFixture, unittest.TestCase):
    def test_selected_domain_aggregate_ds_and_adr(self):
        self.manifests(self.domain, self.impl)
        self.check(True)

    def test_real_impl_and_task_prechecks(self):
        self.manifests(self.domain, self.impl)
        self.precheck('impl', True)
        self.precheck('task', True)

    def test_legacy_without_conditional_entries(self):
        self.manifests([], [])
        # Old contracts must not acquire a dependency on the new resolver.
        schema = self.root / 'contracts/domain-contract.v1.schema.json'
        saved = schema.with_suffix('.saved')
        schema.rename(saved)
        try:
            self.check(True)
        finally:
            saved.rename(schema)

    def test_relocated_conditional_paths(self):
        self.manifests(self.domain, self.impl, relocated=True)
        self.check(True)

    def test_spec_cannot_admit_design_system(self):
        self.manifests(self.domain + ['design-system/design-system.md'], self.impl)
        self.check(False)
        self.precheck('impl', False)

    def test_impl_cannot_admit_unselected_aggregate(self):
        self.manifests(self.domain, self.impl + ['domain/aggregates/Other.md'])
        self.check(False)
        self.precheck('task', False)

    def test_conditional_hash_tamper(self):
        self.manifests(self.domain, self.impl)
        path = self.root / 'domain/aggregates/Order.md'
        original = path.read_bytes()
        try:
            path.write_bytes(original + b'changed\n')
            self.check(False)
            self.precheck('task', False)
        finally:
            path.write_bytes(original)


class LegacyLocationFixture(WorkflowFixture):
    def test_no_conditional_dependency_from_location_names(self):
        self.manifests([], [])
        # Only canonical relative domain/design-system inputs may activate the
        # resolver, never the feature name or an ancestor of the checkout.
        dependencies = [self.root / 'plugins/sdd-quality-loop/scripts/review-conditional-inputs.py']
        dependencies += [self.root / f'contracts/domain-contract.{version}.schema.json'
                         for version in ('v1', 'v2')]
        with tempfile.TemporaryDirectory() as backup:
            for index, path in enumerate(dependencies):
                path.rename(Path(backup) / str(index))
            try:
                self.check(True)
                self.precheck('impl', True)
                self.precheck('task', True)
            finally:
                for index, path in enumerate(dependencies):
                    (Path(backup) / str(index)).rename(path)


class DomainFeatureInputs(LegacyLocationFixture, unittest.TestCase):
    feature = 'domain'


class DesignSystemParentInputs(LegacyLocationFixture, unittest.TestCase):
    parent_directory = 'design-system'


if __name__ == '__main__':
    unittest.main()
