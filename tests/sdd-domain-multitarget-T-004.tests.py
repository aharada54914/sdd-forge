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


# T009 reviewed additive v3 dispatch. Both exact new bytes and the reconstructed
# original baseline remain bound; this is NOT a general cloud-code exception.
CHECK_CONTRACT = 'plugins/sdd-quality-loop/scripts/check-contract.py'
REVIEWED_CLOUD_SHA256 = '9bbc96658f775ed46c8d876e92803a8de46c9bf242bbc83d412776164e89e6b7'
REVIEWED_CLOUD_INSERTION = b"""    # Cloud runtime is deliberately lazy: the legacy entry remains stdlib 3.6+.
    if isinstance(contract, dict) and contract.get("schema") == "verification-contract/v3":
        if sys.version_info < (3, 10):
            return contract.get("task_id", "?"), ["cloud profile requires Python 3.10+"]
        try:
            from cloud_verification import saved_profile_plan
            with open(contract_path, "rb") as stream:
                saved_profile_plan(stream.read(), _discover_project_root(contract_path, root))
        except (ImportError, OSError, ValueError, TypeError, KeyError) as exc:
            return contract.get("task_id", "?"), ["cloud profile invalid: " + str(exc)]
        return contract.get("task_id", "?"), ["cloud profile requires fresh authenticated collection; saved evidence is not provenance"]
    if isinstance(contract, dict) and "profile" in contract:
        return contract.get("task_id", "?"), ["cloud profile requires verification-contract/v3"]

"""


REVIEWED_RESEARCH_SHA256 = '72c03a9eeb3007c266a4cf6ec5cd3766d1e57164679a66d7361151f66c3e7d2e'
REVIEWED_RESEARCH_INSERTIONS = (
    b"""def _pass_research_evidence(checks, root, failures):
    # Optional branch: old contracts do not load the newer research runtime.
    for check in checks:
        if check.get("id") != "source-evidence" or check.get("passes") is not True:
            continue
        try:
            from research_consumers import relative_file, verify_check_record
            evidence = relative_file(root, check.get("evidence"))
            verify_check_record(evidence, root, os.environ.get("SDD_RESEARCH_SNAPSHOT_ROOT"))
        except Exception:
            failures.append("check 'source-evidence' fresh original verification failed")


""",
    b"    _pass_research_evidence(checks, evidence_root, failures)\n",
)


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


helper = load('t004_block_helper', ROOT / 'tests/resolve-project-context-block-check.py')
targets = load('t004_target_fixtures', ROOT / 'tests/sdd-domain-multitarget-T-003.tests.py')


def retained(feature):
    return {name: (feature / (name + '.md')).read_bytes() for name in DOCUMENTS}


class CompatibilityTests(unittest.TestCase):
    def strip_research(self, content):
        self.assertEqual(hashlib.sha256(content).hexdigest(), REVIEWED_RESEARCH_SHA256)
        for insertion in REVIEWED_RESEARCH_INSERTIONS:
            self.assertEqual(content.count(insertion), 1)
            content = content.replace(insertion, b'', 1)
        self.assertEqual(hashlib.sha256(content).hexdigest(), REVIEWED_CLOUD_SHA256)
        return content

    def test_research_extension_retains_exact_predecessor_and_rejects_mutations(self):
        content = (ROOT / CHECK_CONTRACT).read_bytes()
        self.strip_research(content)
        for insertion in REVIEWED_RESEARCH_INSERTIONS:
            for altered in (content.replace(insertion, b'', 1),
                            content.replace(insertion, insertion * 2, 1),
                            content.replace(insertion, b'', 1) + insertion):
                with self.assertRaises(AssertionError):
                    self.strip_research(altered)
        with self.assertRaises(AssertionError):
            self.strip_research(content + b'\n')

    def assert_reviewed_consumer(self, path, content, expected):
        if path == REQUIREMENTS_TEMPLATE:
            self.assertEqual(hashlib.sha256(content).hexdigest(), REVIEWED_REQUIREMENTS_SHA256)
            self.assertTrue(content.startswith(REVIEWED_REQUIREMENTS_PREFIX))
            content = OLD_REQUIREMENTS_PREFIX + content[len(REVIEWED_REQUIREMENTS_PREFIX):]
        elif path == CHECK_CONTRACT:
            content = self.strip_research(content)
            self.assertEqual(hashlib.sha256(content).hexdigest(), REVIEWED_CLOUD_SHA256)
            self.assertEqual(content.count(REVIEWED_CLOUD_INSERTION), 1)
            content = content.replace(REVIEWED_CLOUD_INSERTION, b'', 1)
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

    def test_reviewed_cloud_extension_is_exact_and_retains_original_baseline(self):
        baseline = json.loads((ROOT / 'specs/sdd-domain-multitarget/verification/T-004/consumer-baseline.json').read_text())['sha256']
        content = (ROOT / CHECK_CONTRACT).read_bytes()
        expected = baseline[CHECK_CONTRACT]
        self.assert_reviewed_consumer(CHECK_CONTRACT, content, expected)
        mutations = {
            'missing': content.replace(REVIEWED_CLOUD_INSERTION, b'', 1),
            'duplicate': content.replace(REVIEWED_CLOUD_INSERTION, REVIEWED_CLOUD_INSERTION * 2, 1),
            'moved': content.replace(REVIEWED_CLOUD_INSERTION, b'', 1) + REVIEWED_CLOUD_INSERTION,
            'version': content.replace(b'verification-contract/v3', b'verification-contract/v4', 1),
            'legacy-body': content.replace(b'BASELINE_IDS = {', b'BASELINE_IDS = set() # {', 1),
            'trailing': content + b'\n',
        }
        for label, changed in mutations.items():
            with self.subTest(mutation=label), self.assertRaises(AssertionError):
                self.assert_reviewed_consumer(CHECK_CONTRACT, changed, expected)
        with self.assertRaises(AssertionError):
            self.assert_reviewed_consumer(CHECK_CONTRACT, content, REVIEWED_CLOUD_SHA256)
        reconstructed = self.strip_research(content).replace(REVIEWED_CLOUD_INSERTION, b'', 1)
        self.assertEqual(hashlib.sha256(reconstructed).hexdigest(), expected)

    def test_reviewed_cloud_extension_preserves_actual_absent_and_v2_legacy(self):
        # Run baseline and current CLI with only the original stdlib dependency.
        # Missing cloud modules is deliberate: legacy must not import them.
        content = (ROOT / CHECK_CONTRACT).read_bytes()
        original = self.strip_research(content).replace(REVIEWED_CLOUD_INSERTION, b'', 1)
        with tempfile.TemporaryDirectory(prefix='t004-legacy-extension-') as folder:
            work = Path(folder).resolve()
            for name, code in (('original.py', original), ('reviewed.py', content)):
                (work / name).write_bytes(code)
            shutil.copy2(SCRIPTS / 'validate_path.py', work / 'validate_path.py')
            (work / 'evidence.log').write_text('Synthetic legacy check evidence\n')
            ids = ('lint', 'typecheck', 'unit-tests', 'build', 'placeholder-scan', 'task-state-check')
            for schema in (None, 'verification-contract/v2'):
                for variant in ('matched', 'missing-check', 'false-check', 'bad-evidence', 'duplicate-check'):
                    with self.subTest(schema=schema, variant=variant):
                        contract: dict = dict(task_id='T-004', checks=[dict(id=cid, required=True, passes=True, evidence='evidence.log') for cid in ids])
                        if schema is not None:
                            contract['schema'] = schema
                        if variant == 'missing-check':
                            contract['checks'].pop()
                        elif variant == 'false-check':
                            contract['checks'][0]['passes'] = False
                        elif variant == 'bad-evidence':
                            contract['checks'][0]['evidence'] = '../outside.log'
                        elif variant == 'duplicate-check':
                            contract['checks'].append(contract['checks'][0].copy())
                        path = work / 'contract.json'
                        path.write_text(json.dumps(contract))
                        results = [subprocess.run([sys.executable, '-I', '-B', str(work / name), str(path), str(work)],
                                                 capture_output=True, text=True, timeout=15)
                                   for name in ('original.py', 'reviewed.py')]
                        self.assertEqual(results[0].returncode, 0 if variant == 'matched' else 1, results[0].stdout + results[0].stderr)
                        self.assertEqual((results[0].returncode, results[0].stdout, results[0].stderr),
                                         (results[1].returncode, results[1].stdout, results[1].stderr))

    def test_additive_override_contract_preserves_existing_context_boundaries(self):
        resolver = load('t004_resolver', SCRIPTS / 'resolve-project-context.py')
        context: dict = {"schema": "sdd-project-context/v1", "workflow": {
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
