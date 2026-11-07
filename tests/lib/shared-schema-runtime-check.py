#!/usr/bin/env python3
"""Contract tests for the shipped schema adapter, without ambient dependencies."""
import copy
import hashlib
import importlib
import importlib.util
import json
import pathlib
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile
from unittest.mock import patch

ROOT = pathlib.Path(__file__).resolve().parents[2]
SCRIPTS = ROOT / 'plugins/sdd-quality-loop/scripts'
sys.path.insert(0, str(SCRIPTS))
sdd_schema = importlib.import_module("sdd_schema")


class SharedSchemaRuntimeTests(unittest.TestCase):
    def diagnostics(self, value, schema):
        result = []
        sdd_schema._validate(value, schema, schema, '', result)
        return result

    def test_constraints_previously_ignored(self):
        for schema, value in [({'maxLength': 1}, 'ab'), ({'maximum': 1}, 2),
                              ({'allOf': [{'minimum': 3}]}, 2),
                              ({'contains': {'const': 3}}, [1, 2]),
                              ({'maxProperties': 1}, {'a': 1, 'b': 2}),
                              ({'dependencies': {'a': ['b']}}, {'a': 1}),
                              ({'anyOf': [{'const': 1}, {'const': 2}]}, 3)]:
            with self.subTest(schema=schema):
                self.assertTrue(self.diagnostics(value, schema))

    def test_multiple_errors_and_rfc6901_keys(self):
        schema = {'properties': {'a.b/~': {'const': 1}, 'x': {'const': 2}}}
        self.assertEqual([p for p, _ in self.diagnostics({'a.b/~': 0, 'x': 0}, schema)],
                         ['/a.b~1~0', '/x'])

    def test_schema_and_instance_not_mutated(self):
        schema = {'properties': {'a': {'default': 1}, 'b': {'pattern': '^b$'}}}
        before = copy.deepcopy(schema)
        value = {}
        self.assertFalse(self.diagnostics(value, schema))
        self.assertEqual(schema, before)
        self.assertEqual(value, {})

    def test_local_refs_and_no_network_or_file_resolution(self):
        schema = {'definitions': {'x': {'const': 1}}, '$ref': '#/definitions/x'}
        self.assertFalse(self.diagnostics(1, schema))
        with patch('urllib.request.urlopen', side_effect=AssertionError('network access')):
            for ref in ('https://example.invalid/schema', 'file:///etc/passwd', 'custom:secret', 'other.json'):
                with self.subTest(ref=ref), self.assertRaises(ValueError):
                    self.diagnostics({}, {'$ref': ref})
        self.assertFalse(self.diagnostics({'$ref': 'https://example.invalid'},
                                          {'const': {'$ref': 'https://example.invalid'}}))

    def test_malformed_schema_and_wrong_draft_rejected(self):
        for schema in ({'minLength': -1}, {'required': 'x'}, {'type': 'typo'}, {'maxLenght': 1},
                       {'$schema': 'https://json-schema.org/draft/2020-12/schema'}):
            with self.subTest(schema=schema), self.assertRaises(ValueError):
                self.diagnostics({}, schema)

    def test_pattern_dollar_and_trailing_newline(self):
        self.assertFalse(self.diagnostics('$', {'pattern': '^[$]$'}))
        self.assertTrue(self.diagnostics('x\n', {'pattern': '^x$'}))
        self.assertFalse(self.diagnostics('x', {'pattern': '^x$'}))

    def test_shared_callable(self):
        for name in ('facet-manifest', 'capability-summary', 'context-projection'):
            spec = importlib.util.spec_from_file_location(name, SCRIPTS / f'validate-{name}.py')
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            self.assertIs(module._validate, sdd_schema._validate)

    def test_vendor_integrity_and_lock(self):
        vendor = SCRIPTS / '_schema_vendor'
        manifest = json.loads((vendor / 'manifest.json').read_text())
        lock = (vendor / 'requirements.txt').read_text()
        self.assertIn(manifest['sha256'], lock)
        self.assertEqual(lock.split()[0], 'fastjsonschema==' + manifest['wheel'].split('-')[1])
        wheel = vendor / manifest['wheel']
        self.assertEqual(hashlib.sha256(wheel.read_bytes()).hexdigest(), manifest['sha256'])
        with zipfile.ZipFile(wheel) as archive:
            for name, digest in manifest['files'].items():
                raw = (vendor / name).read_bytes() if name.startswith('LICENSE') else archive.read(name)
                self.assertEqual(hashlib.sha256(raw).hexdigest(), digest, name)

    def test_installed_cli_without_site_packages_from_unrelated_cwd(self):
        with tempfile.TemporaryDirectory() as temporary:
            installed = pathlib.Path(temporary) / 'plugin'
            shutil.copytree(SCRIPTS, installed / 'scripts', ignore=shutil.ignore_patterns('__pycache__'))
            shutil.copytree(SCRIPTS.parent / 'contracts', installed / 'contracts')
            fixture = ROOT / 'tests/fixtures/facet-manifest/schema/valid-base.json'
            result = subprocess.run([sys.executable, '-I', '-S', '-c',
                "import runpy,sys;sys.argv=sys.argv[1:];runpy.run_path(sys.argv[0],run_name='__main__')",
                str(installed / 'scripts/validate-facet-manifest.py'), '--manifest', str(fixture)],
                cwd=temporary, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(result.stdout, '')


if __name__ == '__main__':
    unittest.main()
