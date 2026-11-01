#!/usr/bin/env python3
"""Public contract diagnostics for malformed JSON and evidence paths."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'plugins/sdd-quality-loop/scripts'
SPEC = importlib.util.spec_from_file_location('validate_path', SCRIPTS / 'validate_path.py')
PATHS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PATHS)


class InputBoundaryTests(unittest.TestCase):
    @unittest.skipUnless(os.name == 'posix', 'POSIX executable fixture')
    def test_failed_git_status_does_not_create_a_snapshot_fingerprint(self):
        spec = importlib.util.spec_from_file_location('component_paths', SCRIPTS / 'resolve-component-paths.py')
        resolver = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(resolver)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            git = root / 'git'
            git.write_text('#!/bin/sh\ncase "$3" in\nrev-parse) printf "known-head\\n";;\nstatus) printf "status failed\\n" >&2; exit 7;;\nesac\n', encoding='utf-8')
            git.chmod(0o700)
            from unittest.mock import patch
            with patch.dict(os.environ, PATH=directory + os.pathsep + os.environ.get('PATH', '')):
                with self.assertRaisesRegex(resolver.GitDiffError, 'status failed'):
                    resolver._capture_fingerprint(directory)

    @unittest.skipUnless(os.name == 'posix', 'POSIX executable fixture')
    def test_git_timeout_reaps_direct_child_and_fails_closed(self):
        from unittest.mock import patch
        spec = importlib.util.spec_from_file_location('component_deadline', SCRIPTS / 'resolve-component-paths.py')
        resolver = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(resolver)
        actual_run = subprocess.run

        def shortened_deadline(*args, **kwargs):
            self.assertEqual(kwargs['timeout'], 30)
            kwargs['timeout'] = 0.1
            return actual_run(*args, **kwargs)

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            git = root / 'git'
            git.write_text('#!/bin/sh\nprintf "%s" "$$" > "$2/git-child.pid"\nexec sleep 10\n', encoding='utf-8')
            git.chmod(0o700)
            with patch.dict(os.environ, PATH=directory + os.pathsep + os.environ.get('PATH', '')):
                with patch.object(resolver.subprocess, 'run', side_effect=shortened_deadline):
                    with self.assertRaisesRegex(resolver.GitDiffError, 'deadline'):
                        resolver._run_git(directory, ['rev-parse', 'HEAD'])
            pid = int((root / 'git-child.pid').read_text(encoding='utf-8'))
            with self.assertRaises(ProcessLookupError):
                os.kill(pid, 0)

    def test_facet_semantics_preserve_schema_diagnostics_for_unhashable_ids(self):
        cases = ({'resolved_gates': [{'id': []}]},
                 {'required_facets': ['ui'], 'conditional_facets': [{'facet': {}}]},
                 {'conditional_facets': [{'facet': []}]})
        with tempfile.TemporaryDirectory() as directory:
            manifest = Path(directory) / 'manifest.json'
            for value in cases:
                with self.subTest(value=value):
                    manifest.write_text(json.dumps(value), encoding='utf-8')
                    result = subprocess.run([sys.executable, str(SCRIPTS / 'validate-facet-manifest.py'),
                                             '--manifest', str(manifest)], capture_output=True,
                                            text=True, encoding='utf-8', timeout=10, check=False)
                    self.assertEqual(result.returncode, 1)
                    self.assertIn('facet-manifest: schema-invalid:', result.stdout)
                    self.assertNotIn('Traceback', result.stderr)

    def test_contract_invalid_shapes_have_failure_diagnostics(self):
        cases = [[], None, 1, {'schema': 1}, {'checks': [{'id': []}]},
                 {'checks': [{'id': 'lint', 'waiver_reason': 1}]},
                 {'required_workflow': 'tdd', 'checks': [{'id': 'unit-tests',
                  'required': True, 'red_evidence': 2}]}]
        with tempfile.TemporaryDirectory() as directory:
            contract = Path(directory) / 'contract.json'
            for value in cases:
                with self.subTest(value=value):
                    contract.write_text(json.dumps(value), encoding='utf-8')
                    result = subprocess.run([sys.executable, str(SCRIPTS / 'check-contract.py'),
                                             str(contract), directory], capture_output=True,
                                            text=True, encoding='utf-8', timeout=10, check=False)
                    self.assertEqual(result.returncode, 1)
                    self.assertIn('Verification contract FAILED', result.stdout)
                    self.assertNotIn('Traceback', result.stderr)
            contract.write_bytes(b'\xff')
            result = subprocess.run([sys.executable, str(SCRIPTS / 'check-contract.py'),
                                     str(contract), directory], capture_output=True,
                                    text=True, encoding='utf-8', timeout=10, check=False)
            self.assertEqual(result.returncode, 1)
            self.assertIn('JSON parse error', result.stdout)
            self.assertNotIn('Traceback', result.stderr)

    @unittest.skipUnless(os.name == 'posix' and os.geteuid() != 0,
                         'real permission boundary requires an unprivileged POSIX process')
    def test_unreadable_stop_marker_parent_denies(self):
        guard = SCRIPTS / 'sdd-hook-guard.py'
        payload = json.dumps({'tool_name': 'Read', 'tool_input': {'file_path': 'readme.md'}})
        with tempfile.TemporaryDirectory() as directory:
            closed = Path(directory) / 'closed'
            closed.mkdir(mode=0)
            try:
                environment = dict(os.environ, CLAUDE_PROJECT_DIR=str(closed))
                result = subprocess.run([sys.executable, str(guard), '--emit', 'copilot'],
                                        input=payload, capture_output=True, text=True,
                                        encoding='utf-8', env=environment, timeout=10, check=False)
                self.assertEqual(result.returncode, 0)
                decision = json.loads(result.stdout)
                self.assertEqual(decision['permissionDecision'], 'deny')
                self.assertIn('unable to inspect AGENT_STOP', decision['permissionDecisionReason'])
            finally:
                closed.chmod(0o700)
            for marker in (None, 'directory', 'file'):
                stop = closed / 'AGENT_STOP'
                if marker == 'directory':
                    stop.mkdir()
                elif marker == 'file':
                    stop.rmdir()
                    stop.write_text('stop', encoding='utf-8')
                result = subprocess.run([sys.executable, str(guard), '--emit', 'copilot'],
                                        input=payload, capture_output=True, text=True,
                                        encoding='utf-8', env=environment, timeout=10, check=False)
                self.assertEqual(json.loads(result.stdout)['permissionDecision'],
                                 'deny' if marker == 'file' else 'allow')

    def test_launcher_preserves_utf8_under_ascii_locale(self):
        source = ROOT / 'plugins/sdd-review-loop/scripts/launch-impl-review.py'
        program = """import importlib.util, pathlib, sys
spec = importlib.util.spec_from_file_location('launch', sys.argv[1])
launch = importlib.util.module_from_spec(spec)
spec.loader.exec_module(launch)
root = pathlib.Path(sys.argv[2])
command = [sys.executable, '-c',
           "import sys;sys.stdout.buffer.write(bytes.fromhex('e697a5e69cace8aa9e'))"]
launch.run(root, command, root / 'output')
assert (root / 'output').read_bytes() == bytes.fromhex('e697a5e69cace8aa9e')
"""
        with tempfile.TemporaryDirectory() as directory:
            environment = dict(os.environ, LC_ALL='C', PYTHONUTF8='0', PYTHONCOERCECLOCALE='0')
            result = subprocess.run([sys.executable, '-c', program, str(source), directory],
                                    env=environment, capture_output=True, timeout=10, check=False)
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_registry_rejects_invalid_shapes_before_checks_or_generation(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            registry = root / 'contracts/capability-registry.json'
            registry.parent.mkdir()
            cases = ({'gates': [{'id': []}]}, {'gates': None},
                     {'capabilities': [{'id': 'c', 'gate_ids': 'oops'}]},
                     {'capabilities': [{'id': 'c', 'gate_ids': [[]]}]})
            for value in cases:
                with self.subTest(value=value):
                    value['schema'] = 'capability-registry/v1'
                    registry.write_text(json.dumps(value), encoding='utf-8')
                    for script, arguments in (
                            ('validate-capability-registry.py', ['--registry', str(registry)]),
                            ('generate-gate-capabilities.py', [])):
                        result = subprocess.run([sys.executable, str(SCRIPTS / script),
                                                 '--repo-root', str(root), *arguments],
                                                capture_output=True, timeout=10, check=False)
                        self.assertEqual(result.returncode, 1, (script, result.stdout, result.stderr))
                        self.assertNotIn(b'Traceback', result.stderr)
                        self.assertFalse((root / 'plugins').exists())

    def test_paths_do_not_coerce_external_values(self):
        with tempfile.TemporaryDirectory() as directory:
            for name in ('123', '日本語 "quoted"\n.txt'):
                (Path(directory) / name).write_text('evidence', encoding='utf-8')
                failures = []
                self.assertTrue(PATHS.validate_evidence_path('evidence', name, directory, failures))
                self.assertEqual(failures, [])
            for value in (123, [], {}, False, '', 'x\0y', '../outside'):
                with self.subTest(value=value):
                    failures = []
                    self.assertFalse(PATHS.validate_evidence_path('evidence', value, directory, failures))
                    self.assertTrue(failures)


if __name__ == '__main__':
    unittest.main()
