#!/usr/bin/env python3
"""T-004 acceptance coverage; synthetic local fixtures, no provider execution.

The bootstrap is an instruction consumer rather than a document-generation CLI.
Existing structural and byte suites exercise that contract; these tests exercise
its actual resolver publication boundary with the retained full-profile files.
They do not claim that an autonomous interview was executed.
"""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'plugins/sdd-quality-loop/scripts'
BOOTSTRAP = ROOT / 'plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer'
REQUIREMENTS_TEMPLATE = 'plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/requirements.template.md'
# Reviewed 24fd8033 adds only the initial Pending field; retain the old baseline.
REVIEWED_REQUIREMENTS_SHA256 = '903a725c445fac4505dfea3a3ac7aaf13b37fdb103ccffc1d1a6d1608dc940b5'
OLD_REQUIREMENTS_PREFIX = b'# Requirements: {{feature_name}}\n\n'
REVIEWED_REQUIREMENTS_PREFIX = OLD_REQUIREMENTS_PREFIX + b'Spec-Review-Status: Pending\n\n'
DOCUMENTS = ('requirements', 'acceptance-tests', 'design', 'ux-spec',
             'frontend-spec', 'infra-spec', 'security-spec')


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


helper = load('t004_block_helper', ROOT / 'tests/resolve-project-context-block-check.py')
targets = load('t004_target_fixtures', ROOT / 'tests/sdd-domain-multitarget-T-003.tests.py')


def retained(feature):
    return {name: (feature / (name + '.md')).read_bytes() for name in DOCUMENTS}


class CompatibilityTests(unittest.TestCase):
    def assert_reviewed_consumer(self, path, content, expected):
        if path == 'plugins/sdd-quality-loop/scripts/check-contract.py':
            publication = load('research_publication', ROOT / 'tests/lib/research-consumer-publication.py')
            publication.checked_paths(ROOT)
            fixture = json.loads((ROOT / 'tests/fixtures/research-consumer-current-publication.json').read_text())
            entry = next(e for e in fixture['successors'] if e['live'] == path)
            self.assertEqual(expected, entry['staged_sha256'])
            self.assertEqual(hashlib.sha256(content).hexdigest(), entry['live_sha256'])
            return
        if path == REQUIREMENTS_TEMPLATE:
            self.assertEqual(hashlib.sha256(content).hexdigest(), REVIEWED_REQUIREMENTS_SHA256)
            self.assertTrue(content.startswith(REVIEWED_REQUIREMENTS_PREFIX))
            content = OLD_REQUIREMENTS_PREFIX + content[len(REVIEWED_REQUIREMENTS_PREFIX):]
        self.assertEqual(hashlib.sha256(content).hexdigest(), expected)

    def test_005_007_reviewed_contracts_templates_and_checks_unchanged(self):
        baseline = json.loads((ROOT / 'specs/sdd-domain-multitarget/verification/T-004/consumer-baseline.json').read_text())
        self.assertTrue(baseline['sha256'])
        for path, expected in baseline['sha256'].items():
            with self.subTest(path=path):
                self.assert_reviewed_consumer(path, (ROOT / path).read_bytes(), expected)

    def test_reviewed_pending_status_requires_exact_change_and_original_baseline(self):
        baseline = json.loads((ROOT / 'specs/sdd-domain-multitarget/verification/T-004/consumer-baseline.json').read_text())['sha256']
        content = (ROOT / REQUIREMENTS_TEMPLATE).read_bytes()
        expected = baseline[REQUIREMENTS_TEMPLATE]
        self.assert_reviewed_consumer(REQUIREMENTS_TEMPLATE, content, expected)
        status = b'Spec-Review-Status: Pending\n\n'
        mutations = {
            'missing': content.replace(status, b'', 1),
            'passed': content.replace(b'Spec-Review-Status: Pending', b'Spec-Review-Status: Passed', 1),
            'unknown': content.replace(b'Spec-Review-Status:', b'Unknown-Review-Status:', 1),
            'duplicate': content.replace(status, status + status, 1),
            'moved': content.replace(status, b'', 1) + b'\n' + status,
            'body': content.replace(b'{{overview}}', b'Changed overview', 1),
        }
        for label, changed in mutations.items():
            with self.subTest(mutation=label), self.assertRaises(AssertionError):
                self.assert_reviewed_consumer(REQUIREMENTS_TEMPLATE, changed, expected)
        with self.assertRaises(AssertionError):
            self.assert_reviewed_consumer(REQUIREMENTS_TEMPLATE, content, REVIEWED_REQUIREMENTS_SHA256)
        unrelated = 'plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/design.template.md'
        with self.assertRaises(AssertionError):
            self.assert_reviewed_consumer(unrelated, (ROOT / unrelated).read_bytes() + b'changed', baseline[unrelated])
        consumer = 'plugins/sdd-quality-loop/scripts/check-contract.py'
        with self.assertRaises(AssertionError):
            self.assert_reviewed_consumer(consumer, (ROOT / consumer).read_bytes() + b'changed', baseline[consumer])
        with self.assertRaises(AssertionError):
            self.assert_reviewed_consumer(consumer, (ROOT / consumer).read_bytes(), '0' * 64)

    def test_additive_override_contract_preserves_existing_context_boundaries(self):
        resolver = load('t004_resolver', SCRIPTS / 'resolve-project-context.py')
        context = {"schema": "sdd-project-context/v1", "workflow": {
            "spec_profile": "full", "artifact_layout": "legacy-seven-layer",
            "capability_enforcement": "advisory"}, "components": [{
            "id": "app", "paths": {"include": ["app/**"]}}],
            "shared_paths": [{"pattern": ".github/**", "classification": "cross-cutting"}]}
        input_schema = json.loads((ROOT / 'contracts/project-context.schema.json').read_text())
        output_schema = json.loads((ROOT / 'contracts/context-projection.schema.json').read_text())
        def check_both(document, expected):
            self.assertEqual(resolver._draft7_conforms(document, input_schema), expected)
            projection = resolver._projection(document, "sha256:" + "a" * 64)
            self.assertEqual(resolver._draft7_conforms(projection, output_schema), expected)
        check_both(context, True)
        for record, scope, characteristic in [
            (context['components'][0], 'app/ci', 'credential_bearing'),
            (context['shared_paths'][0], '.github/**', 'release_write')]:
            record['characteristic_overrides'] = [{"scope": scope,
                "characteristic": characteristic, "value": True, "rationale": "Scoped runtime responsibility."}]
        check_both(context, True)
        self.assertTrue(resolver._project_context_valid(context, ROOT))
        for owner in ('components', 'shared_paths'):
            for field, value in [('characteristic', 'unknown'), ('value', 'true'), ('extra', True)]:
                with self.subTest(owner=owner, field=field):
                    changed = copy.deepcopy(context)
                    changed[owner][0]['characteristic_overrides'][0][field] = value
                    check_both(changed, False)
            changed = copy.deepcopy(context)
            changed[owner][0]['unexpected'] = True
            check_both(changed, False)
        for field in ('spec_profile', 'artifact_layout', 'capability_enforcement'):
            changed = copy.deepcopy(context)
            changed['workflow'][field] = 'unknown'
            check_both(changed, False)
        changed = copy.deepcopy(context)
        changed['shared_paths'][0]['pattern'] = ''
        self.assertFalse(resolver._draft7_conforms(changed, input_schema))

    def test_005_full_profile_output_contract_and_no_context_compatibility(self):
        text = (BOOTSTRAP / 'SKILL.md').read_text()
        section = text.split('## Required Outputs\n', 1)[1].split('Phase 2 outputs', 1)[0]
        paths = re.findall(r'^- `specs/<feature>/([^`]+\.md)`$', section, re.M)
        self.assertEqual(set(paths), {name + '.md' for name in DOCUMENTS})
        self.assertEqual(len(paths), 7)
        self.assertIn('MUST NOT overwrite an existing layer file', text)
        phase = text.split('### Capability Interview Phase', 1)[1].split('### Full-Profile Layer Interview', 1)[0]
        self.assertIn('do not spawn a resolver', phase)
        self.assertIn('event-identical', phase)
        # Execute the shipped no-context output/copy comparison. This is the
        # existing compatibility consumer, not a test-local fallback resolver.
        result = subprocess.run(['bash', str(ROOT / 'tests/compatibility-byte-identical.tests.sh')],
                                capture_output=True, text=True, cwd=ROOT)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('25 passed, 0 failed', result.stdout)

    def test_006_shipped_structural_consumer_rejects_missing_or_rewritten_layer(self):
        corpus = ROOT / 'tests/fixtures/structural-fixture-corpus/f1-full.json'
        original = corpus.read_bytes()
        fixture = json.loads(original)
        driver = ROOT / 'tests/structural-compatibility-live-refresh.tests.sh'
        with tempfile.TemporaryDirectory(prefix='t004-structure-') as folder:
            candidate = Path(folder) / 'candidate.json'
            def validate(document):
                candidate.write_text(json.dumps(document))
                return subprocess.run(['bash', str(driver), '--state', 'F1',
                    '--fixture', str(candidate), '--dry-run'], capture_output=True, text=True)
            result = validate(fixture)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            for name in DOCUMENTS:
                with self.subTest(layer=name):
                    omitted = dict(fixture, artifacts=[row for row in fixture['artifacts']
                        if row['path'] != name + '.md'])
                    result = validate(omitted)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn('required output paths/count differ', result.stderr)
                    rewritten = json.loads(original)
                    next(row for row in rewritten['artifacts'] if row['path'] == name + '.md')['content'] = '# Changed structure\n'
                    result = validate(rewritten)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn('structural mismatch', result.stderr)
        self.assertEqual(corpus.read_bytes(), original)

    def test_006_valid_hybrid_all_targets_retains_seven_bytes_and_separate_manifest(self):
        for target in targets.TARGETS:
            with self.subTest(target=target), tempfile.TemporaryDirectory(prefix='t004-hybrid-') as folder:
                repo = Path(folder).resolve()
                subprocess.run(['git', 'init', '-q', str(repo)], check=True, capture_output=True)
                scripts = helper.install_scripts(repo)
                for suffix in ('py', 'sh', 'ps1'):
                    shutil.copy2(SCRIPTS / ('resolve-project-context.' + suffix), scripts)
                helper.install_t003_dependencies(repo, scripts, None)
                registry, _, _ = targets.target_fixture(target)
                for gate in registry['gates']:
                    gate['implementation_ref'] = gate['id'] + '.py'
                    (repo / gate['implementation_ref']).write_text('pass\n')
                (repo / 'contracts/capability-registry.json').write_text(json.dumps(registry))
                (repo / 'project-context.yaml').write_text(f'''schema: sdd-project-context/v1
workflow:
  spec_profile: full
  artifact_layout: facet-hybrid
  capability_enforcement: advisory
components:
  - id: comp-a
    paths:
      include:
        - comp-a/**
    artifact_kinds:
      - {target}
shared_paths: []
''')
                feature, _ = helper.plant_sentinels(repo, scripts)
                for name in DOCUMENTS:
                    shutil.copy2(BOOTSTRAP / 'templates' / (name + '.template.md'), feature / (name + '.md'))
                before = retained(feature)
                base = helper.git_commit_all(repo, 'synthetic hybrid baseline')
                (repo / 'comp-a').mkdir()
                (repo / 'comp-a/file.txt').write_text('synthetic change\n')
                head = helper.git_commit_all(repo, 'synthetic component change')
                argv = helper.t003_resolver_argv('sh', scripts, base, head)
                result = subprocess.run(argv, cwd=repo, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual(retained(feature), before)
                manifest, error = helper.read_evidence(feature / 'facet-manifest.yaml')
                self.assertFalse(error)
                self.assertEqual(manifest['schema'], 'sdd-facet-manifest/v1')
                self.assertEqual(manifest['capabilities'], [target])
                self.assertEqual(set(manifest['required_facets']), set(targets.TARGET_PROFILES[target][0]))
                projection = json.loads((scripts / 'generated/project-context.resolved.json').read_text())
                self.assertEqual(projection['workflow']['artifact_layout'], 'facet-hybrid')
                self.assertEqual(projection['workflow']['spec_profile'], 'full')
                first_manifest = (feature / 'facet-manifest.yaml').read_bytes()
                # Repeated resolution must not rewrite the legacy docs or vary selection.
                result = subprocess.run(argv, cwd=repo, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual(retained(feature), before)
                self.assertEqual((feature / 'facet-manifest.yaml').read_bytes(), first_manifest)
                for state in ('malformed', 'invalid'):
                    (repo / 'project-context.yaml').write_text('{' if state == 'malformed' else 'schema: invalid-context/v0\n')
                    result = subprocess.run(argv, cwd=repo, capture_output=True, text=True)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn('capability-resolver:', result.stderr)
                    self.assertEqual(retained(feature), before)
                    self.assertEqual((feature / 'facet-manifest.yaml').read_bytes(), first_manifest)

    def test_005_stale_snapshot_blocks_without_partial_publication(self):
        # Existing fault-injection helper mutates one snapshot dependency during
        # execution, requires canonical BLOCK diagnostic, exact resolver evidence,
        # and byte-identical live preimages. This tests drift rather than just age.
        counts = helper.Counts()
        helper.run_t004_case('sh', 'snapshot-generation-mismatch', counts)
        self.assertGreater(counts.passed, 0)
        self.assertEqual(counts.failed, 0)


if __name__ == '__main__':
    unittest.main(verbosity=2)
