#!/usr/bin/env python3
"""Portable fail-closed controls boundary; this suite does not claim native Windows launch success."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import sys
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / 'plugins/sdd-implementation/scripts/model-policy.py'


class LaunchPlatformBoundary(unittest.TestCase):
    def test_missing_safe_read_primitives_reject_before_file_or_process_access(self):
        spec = importlib.util.spec_from_file_location('launch_platform_helper', HELPER)
        if spec is None or spec.loader is None:
            self.fail('model policy helper loader is unavailable')
        helper = importlib.util.module_from_spec(spec)
        sys.modules[spec.name] = helper
        spec.loader.exec_module(helper)
        command = ['launch-controls', '--controls', 'controls.json', '--controls-sha256', '0' * 64,
                   '--role', 'impl-reviewer-a', '--host', 'claude-code', '--run-id', 'run',
                   '--session-id', 'session']
        unavailable: list[tuple[str, object]] = [('O_NOFOLLOW', None), ('O_DIRECTORY', None), ('O_NONBLOCK', None),
                       ('supports_dir_fd', set()), ('supports_fd', set())]
        for name, value in unavailable:
            with self.subTest(primitive=name):
                raw = io.BytesIO()
                errors = io.TextIOWrapper(raw, encoding='utf-8')
                with mock.patch.object(helper.os, name, value, create=True), \
                        mock.patch.object(helper.os, 'open', side_effect=AssertionError('unexpected file access')) as opened, \
                        mock.patch.object(helper.subprocess, 'run') as launched, \
                        mock.patch.object(helper, 'prepare_policy') as prepared, \
                        mock.patch.object(sys, 'stderr', errors):
                    # Keep wrapped open recognized; the primitive being removed is the only
                    # controlled cause on a capable host. Existing unsupported hosts remain closed.
                    supported = set(helper.os.supports_dir_fd)
                    support_context = (contextlib.nullcontext() if name == 'supports_dir_fd' else
                                       mock.patch.object(helper.os, 'supports_dir_fd', supported | {opened}))
                    with support_context:
                        code = helper.main(command)
                opened.assert_not_called()
                prepared.assert_not_called()
                launched.assert_not_called()
                errors.flush()
                envelope = json.loads(raw.getvalue())
                self.assertEqual(code, 2)
                self.assertEqual(envelope['schema'], 'model-policy-error/v1')
                self.assertEqual(envelope['reason'], 'input-invalid')
                self.assertIn('runtime', envelope['message'].lower())
                self.assertIn('control', envelope['message'].lower())
                errors.close()

    def test_paired_sidecar_missing_primitives_reject_before_file_access(self):
        script = ROOT / 'plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py'
        spec = importlib.util.spec_from_file_location('launch_platform_transport', script)
        if spec is None or spec.loader is None:
            self.fail('paired transport loader is unavailable')
        transport = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(transport)
        unavailable: list[tuple[str, object]] = [
            ('O_NOFOLLOW', None), ('O_DIRECTORY', None), ('O_NONBLOCK', None),
            ('supports_dir_fd', set()), ('supports_fd', set())]
        for name, value in unavailable:
            with self.subTest(primitive=name), mock.patch.object(transport.os, name, value, create=True), \
                    mock.patch.object(transport.os, 'open', side_effect=ValueError('unexpected read')) as opened:
                absent_flag = name in ('O_NOFOLLOW', 'O_DIRECTORY', 'O_NONBLOCK')
                if absent_flag:
                    delattr(transport.os, name)
                try:
                    supported = set(transport.os.supports_dir_fd)
                    support_context = (contextlib.nullcontext() if name == 'supports_dir_fd' else
                                       mock.patch.object(transport.os, 'supports_dir_fd', supported | {opened}))
                    with support_context, self.assertRaises(ValueError):
                        transport.read_regular(ROOT / 'missing-sidecar.json', 1024, 'model launch sidecar')
                    opened.assert_not_called()
                finally:
                    if absent_flag:
                        # create=True patch cleanup also works on hosts originally lacking the flag.
                        setattr(transport.os, name, value)

    def test_actual_host_capability_boundary_rejects_missing_controls_without_launch(self):
        spec = importlib.util.spec_from_file_location('launch_platform_actual_helper', HELPER)
        if spec is None or spec.loader is None:
            self.fail('model policy helper loader is unavailable')
        helper = importlib.util.module_from_spec(spec)
        sys.modules[spec.name] = helper
        spec.loader.exec_module(helper)
        capable = (all(type(getattr(helper.os, name, None)) is int
                       for name in ('O_NOFOLLOW', 'O_DIRECTORY', 'O_NONBLOCK'))
                   and helper.os.open in helper.os.supports_dir_fd
                   and helper.os.listdir in helper.os.supports_fd)
        command = ['launch-controls', '--controls', 'missing-platform-boundary-controls.json',
                   '--controls-sha256', '0' * 64, '--role', 'impl-reviewer-a',
                   '--host', 'claude-code', '--run-id', 'run', '--session-id', 'session']
        raw = io.BytesIO()
        errors = io.TextIOWrapper(raw, encoding='utf-8')
        with contextlib.ExitStack() as stack:
            launched = stack.enter_context(mock.patch.object(helper.subprocess, 'run'))
            prepared = stack.enter_context(mock.patch.object(helper, 'prepare_policy'))
            stack.enter_context(mock.patch.object(sys, 'stderr', errors))
            opened = None
            if not capable:
                opened = stack.enter_context(mock.patch.object(
                    helper.os, 'open', side_effect=AssertionError('unsupported host read a control file')))
            code = helper.main(command)
            if opened is not None:
                opened.assert_not_called()
        errors.flush()
        envelope = json.loads(raw.getvalue())
        self.assertEqual(code, 2)
        self.assertEqual(envelope['schema'], 'model-policy-error/v1')
        self.assertEqual(envelope['reason'], 'input-invalid')
        self.assertIn('control', envelope['message'].lower())
        if capable:
            self.assertNotIn('runtime', envelope['message'].lower(),
                             'capable POSIX host must reach the missing-control-file rejection')
        else:
            self.assertIn('runtime', envelope['message'].lower(),
                          'actual unsupported host must reject before reading controls')
        prepared.assert_not_called()
        launched.assert_not_called()
        errors.close()


if __name__ == '__main__':
    unittest.main()
