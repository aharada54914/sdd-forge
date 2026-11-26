#!/usr/bin/env python3
"""T-004 acceptance coverage for the shipped resolver and its reviewed consumers."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'plugins/sdd-quality-loop/scripts'
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
        self.assertEqual(hashlib.sha256(content).hexdigest(), expected)

    def test_005_007_reviewed_contracts_and_checks_unchanged(self):
        baseline = json.loads((ROOT / 'specs/sdd-domain-multitarget/verification/T-004/consumer-baseline.json').read_text())['sha256']
        retired = {f'plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/{name}.template.md'
                   for name in DOCUMENTS}
        current = baseline.keys() - retired
        self.assertTrue({'contracts/context-projection.schema.json', 'contracts/facet-manifest.schema.json',
                         'contracts/project-context.schema.json', 'plugins/sdd-quality-loop/scripts/check-contract.py'} <= current)
        for path in sorted(current):
            with self.subTest(path=path):
                self.assert_reviewed_consumer(path, (ROOT / path).read_bytes(), baseline[path])

    def test_reviewed_check_contract_rejects_changed_bytes_and_wrong_baseline(self):
        baseline = json.loads((ROOT / 'specs/sdd-domain-multitarget/verification/T-004/consumer-baseline.json').read_text())['sha256']
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

    def test_005_resolver_blocks_when_project_context_is_absent(self):
        case = next(case for case in helper.CASES if case[0] == 'disabled-legacy-invocation')
        counts = helper.Counts()
        helper.run_case('sh', case, counts)
        self.assertGreater(counts.passed, 0)
        self.assertEqual(counts.failed, 0)

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
                    shutil.copy2(ROOT / 'specs/sdd-domain-multitarget' / (name + '.md'), feature / (name + '.md'))
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
