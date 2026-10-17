#!/usr/bin/env python3
"""Opt-in Registry contracts through real schema, discovery and CLI validators."""
import argparse
import copy
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'plugins/sdd-quality-loop/scripts'
sys.path.insert(0, str(SCRIPTS))

def load(name):
    spec = importlib.util.spec_from_file_location(name.replace('-', '_'), SCRIPTS / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

RESOLVER = load('resolve-project-context')
DISCOVERY = load('registry_discovery')
VALIDATOR = load('validate-capability-registry')
RUNTIME = 'bash'

class LiteRegistryContractTests(unittest.TestCase):
    def setUp(self):
        self.registry = json.loads((ROOT / 'contracts/capability-registry.json').read_text())
        self.schema = json.loads((ROOT / 'contracts/capability-registry.schema.json').read_text())

    def check(self, checks, reasons=None):
        doc = copy.deepcopy(self.registry)
        for cap in doc['capabilities']:
            cap['lite_policy']['required_lite_checks'] = checks
            if reasons is not None:
                cap['lite_policy']['upgrade_reasons'] = reasons
        return doc

    def cli(self, doc):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'registry.json'
            path.write_text(json.dumps(doc), encoding='utf-8')
            command = (['bash', str(SCRIPTS / 'validate-capability-registry.sh'), '--registry', str(path)]
                       if RUNTIME == 'bash' else
                       [shutil.which('pwsh'), '-NoProfile', '-File', str(SCRIPTS / 'validate-capability-registry.ps1'), '--registry', str(path)])
            return subprocess.run(command, cwd=ROOT, text=True, capture_output=True)

    def test_real_schema_accepts_opt_in_and_does_not_mutate_absent_fields(self):
        for checks in [[], ['build'], ['build', 'test', 'installer-dry-run']]:
            self.assertTrue(RESOLVER._draft7_conforms(self.check(checks), self.schema))
        original = copy.deepcopy(self.registry)
        self.assertTrue(RESOLVER._draft7_conforms(self.registry, self.schema))
        self.assertEqual(original, self.registry)
        self.assertTrue(all(cap['lite_policy'] == {'eligible': True} for cap in self.registry['capabilities']))
        self.assertEqual(self.schema['properties']['schema']['const'], 'capability-registry/v1')

    def test_real_schema_rejects_malformed_opt_in(self):
        for checks in [None, 'build', [True], [''], ['Test'], ['../test'], ['test\n'], ['test', 'test']]:
            with self.subTest(checks=checks):
                self.assertFalse(RESOLVER._draft7_conforms(self.check(checks), self.schema))
        doc = self.check(['test'])
        doc['capabilities'][0]['lite_policy']['extra'] = True
        self.assertFalse(RESOLVER._draft7_conforms(doc, self.schema))

    def test_catalog_schema_seed_and_vendor_exact(self):
        catalog = json.loads((ROOT / 'contracts/lite-check-catalog.json').read_text())
        schema = json.loads((ROOT / 'contracts/lite-check-catalog.schema.json').read_text())
        self.assertEqual(catalog, {'schema': 'lite-check-catalog/v1', 'catalog_version': 1,
                                  'checks': ['build', 'test', 'installer-dry-run']})
        self.assertTrue(RESOLVER._draft7_conforms(catalog, schema))
        for name in ['lite-check-catalog.json', 'lite-check-catalog.schema.json', 'lite-upgrade-reason-catalog.json', 'capability-registry.schema.json']:
            self.assertEqual((ROOT / 'contracts' / name).read_bytes(), (SCRIPTS.parent / 'contracts' / name).read_bytes())

    def test_catalog_malformed_shapes_fail_discovery_and_schema(self):
        valid = {'schema': 'lite-check-catalog/v1', 'catalog_version': 1, 'checks': ['test']}
        schema = json.loads((ROOT / 'contracts/lite-check-catalog.schema.json').read_text())
        variants = [None, {}, dict(valid, extra=True), dict(valid, schema='wrong'),
                    dict(valid, catalog_version=True), dict(valid, catalog_version=0),
                    dict(valid, checks=[]), dict(valid, checks='test'), dict(valid, checks=[True]),
                    dict(valid, checks=['test', 'test']), dict(valid, checks=['test\n']), dict(valid, checks=['../x'])]
        for doc in variants:
            with self.subTest(doc=doc):
                self.assertFalse(DISCOVERY.check_lite_check_catalog(doc))
                self.assertFalse(RESOLVER._draft7_conforms(doc, schema))

    def test_packaged_catalog_precedence_and_no_malformed_fallback(self):
        with tempfile.TemporaryDirectory() as tmp:
            packaged = Path(tmp) / 'packaged.json'
            canonical = Path(tmp) / 'canonical.json'
            canonical.write_text('{"schema":"lite-check-catalog/v1","catalog_version":1,"checks":["test"]}')
            with patch.object(DISCOVERY, '_packaged_path', return_value=packaged), patch.object(DISCOVERY, '_git_root_path', return_value=canonical):
                self.assertEqual(DISCOVERY.discover_artifact('lite-check-catalog.json'), canonical)
                packaged.write_bytes(canonical.read_bytes())
                self.assertEqual(DISCOVERY.discover_artifact('lite-check-catalog.json'), packaged)
                for bad in ['not json', '{"schema":"lite-check-catalog/v1"}']:
                    packaged.write_text(bad)
                    with self.assertRaises(DISCOVERY.DiscoveryError):
                        DISCOVERY.discover_artifact('lite-check-catalog.json')
                packaged.unlink()
                canonical.unlink()
                with self.assertRaises(DISCOVERY.DiscoveryError):
                    DISCOVERY.discover_artifact('lite-check-catalog.json')

    def test_cli_known_checks_pass(self):
        result = self.cli(self.check(['build', 'test', 'installer-dry-run']))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_cli_unknown_check_rejected_independently_of_reasons(self):
        result = self.cli(self.check(['not-in-catalog'], ['pii']))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('unknown-lite-check: developer-tooling: not-in-catalog', result.stdout)
        self.assertIn('unknown-lite-check: cli-library: not-in-catalog', result.stdout)
        self.assertNotIn('unknown-upgrade-reason', result.stdout)

    def test_cli_unknown_reason_rejected_independently_of_checks(self):
        result = self.cli(self.check(['test'], ['not_a_reason']))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('unknown-upgrade-reason', result.stdout)
        self.assertNotIn('unknown-lite-check', result.stdout)

    def test_cli_invalid_check_shapes_do_not_crash_or_pass(self):
        for checks in [None, 'test', [True], [{}], ['../test'], ['test\n'], ['test', 'test']]:
            with self.subTest(checks=checks):
                result = self.cli(self.check(checks))
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('unknown-lite-check', result.stdout)
                self.assertNotIn('Traceback', result.stderr)

    def test_check_j_missing_catalog_fails_closed(self):
        with patch.object(VALIDATOR, 'discover_artifact', side_effect=VALIDATOR.DiscoveryError('missing')):
            diagnostics = []
            self.assertFalse(VALIDATOR.check_j_lite_check_conformance(self.registry, diagnostics))
            self.assertIn('unknown-lite-check', diagnostics[0])

    def test_upgrade_reason_catalog_exact_version_two_tokens(self):
        expected = ['public_distribution', 'production_cloud_runtime', 'durable_workflow', 'external_identity', 'pii',
                    'public_package_registry', 'store_distribution', 'auto_update', 'code_signing', 'payments', 'multi_tenant', 'high_risk_migration']
        catalog = json.loads((ROOT / 'contracts/lite-upgrade-reason-catalog.json').read_text())
        self.assertEqual(catalog, {'schema': 'lite-upgrade-reason-catalog/v1', 'catalog_version': 2, 'reasons': expected})
        result = self.cli(self.check(['test'], expected))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_real_resolver_publishes_only_lite_artifacts_for_opted_in_fixture(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve()
            for relative in ['contracts', 'plugins/sdd-quality-loop/scripts',
                             'plugins/sdd-quality-loop/contracts', 'plugins/sdd-quality-loop/references']:
                shutil.copytree(ROOT / relative, root / relative, ignore=shutil.ignore_patterns('__pycache__'))
            shutil.copyfile(ROOT / '.gitignore', root / '.gitignore')
            registry = self.check(['build', 'installer-dry-run'])
            for relative in ['contracts', 'plugins/sdd-quality-loop/contracts']:
                (root / relative / 'capability-registry.json').write_text(json.dumps(registry))
            (root / 'project-context.yaml').write_text("""schema: sdd-project-context/v1
workflow:
  spec_profile: lite
  artifact_layout: lite-three-file
  capability_enforcement: required
components:
  - id: app
    artifact_kinds:
      - plugin_package
    paths:
      include:
        - app/**
""")
            (root / 'app').mkdir()
            (root / 'app/input.txt').write_text('before\n')
            for args in [['git', 'init', '-q'], ['git', 'add', '.'],
                         ['git', '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
                          '-c', 'commit.gpgsign=false', 'commit', '-qm', 'fixture']]:
                subprocess.run(args, cwd=root, check=True, capture_output=True)
            (root / 'app/input.txt').write_text('after\n')
            script = root / 'plugins/sdd-quality-loop/scripts/resolve-project-context'
            command = (['bash', str(script) + '.sh'] if RUNTIME == 'bash' else
                       [shutil.which('pwsh'), '-NoProfile', '-File', str(script) + '.ps1'])
            result = subprocess.run(command + ['--config', 'project-context.yaml', '--source-rev', 'HEAD',
                                              '--target-rev', 'HEAD', '--feature', 'fixture'],
                                    cwd=root, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            output = root / 'specs/fixture'
            self.assertEqual({p.name for p in output.iterdir()}, {'capability-summary.yaml', 'resolver-evidence.yaml'})
            summary = json.loads((output / 'capability-summary.yaml').read_text())
            self.assertEqual(summary['required_lite_checks'], ['build', 'installer-dry-run'])
            self.assertFalse(summary['full_upgrade_required'])
            self.assertFalse((root / 'plugins/sdd-quality-loop/scripts/generated/project-context.resolved.json').exists())

    def test_required_summary_requires_per_capability_opt_in(self):
        evaluations = [{'capability_id': cap['id'], 'matched': True} for cap in self.registry['capabilities']]
        with self.assertRaises(RESOLVER.LiteCheckSourceUndefined):
            RESOLVER._assemble_capability_summary('demo', self.registry, evaluations, 'required')
        opted = self.check(['build', 'installer-dry-run'])
        self.assertTrue(RESOLVER._draft7_conforms(opted, self.schema))
        result = RESOLVER._assemble_capability_summary('demo', opted, evaluations, 'required')
        self.assertEqual(result['required_lite_checks'], ['build', 'installer-dry-run'])
        self.assertFalse(result['full_upgrade_required'])
        empty = RESOLVER._assemble_capability_summary('demo', self.check([]), evaluations, 'required')
        self.assertEqual(empty['required_lite_checks'], [])
        zero_match = [dict(entry, matched=False) for entry in evaluations]
        unmatched = RESOLVER._assemble_capability_summary('demo', self.registry, zero_match, 'required')
        self.assertEqual(unmatched['capabilities'], [])
        self.assertEqual(unmatched['required_lite_checks'], [])
        del opted['capabilities'][1]['lite_policy']['required_lite_checks']
        with self.assertRaises(RESOLVER.LiteCheckSourceUndefined):
            RESOLVER._assemble_capability_summary('demo', opted, evaluations, 'required')
        self.assertEqual(RESOLVER._assemble_capability_summary('demo', self.registry, evaluations, 'advisory')['required_lite_checks'], [])

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--runtime', choices=['bash', 'powershell'], default='bash')
    args, rest = parser.parse_known_args()
    RUNTIME = args.runtime
    unittest.main(argv=[sys.argv[0]] + rest)
