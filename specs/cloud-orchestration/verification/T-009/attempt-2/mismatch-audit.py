"""Execute current mismatch bodies and log subtest identities, not historical Red."""
from __future__ import annotations

import importlib.util
from pathlib import Path
import sys
import unittest
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from unittest.runner import _TextTestStream
    ResultBase = unittest.TextTestResult[_TextTestStream]
else:
    ResultBase = unittest.TextTestResult

ROOT = Path(__file__).resolve().parents[5]


class AuditResult(ResultBase):
    def addSubTest(self, test, subtest, err):
        super().addSubTest(test, subtest, err)
        self.stream.writeln(('MISMATCH_CASE_OK ' if err is None else 'MISMATCH_CASE_FAILED ') + str(subtest))


def main() -> None:
    spec = importlib.util.spec_from_file_location('t009_mismatch_audit', ROOT / 'tests/cloud-orchestration-verification.tests.py')
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    suite = unittest.defaultTestLoader.loadTestsFromNames([
        'ProtectedProfileCases', 'ProfileDispatchIntegration', 'ProfileSavedConsumers',
        'ProfilePreviewProvenance', 'ProfileGuardSensitivity', 'ProfileCompletionCases',
        'ProfileAwsReadbackCases'], module)
    result = unittest.TextTestRunner(resultclass=AuditResult, verbosity=2).run(suite)
    sys.exit(0 if result.wasSuccessful() else 1)


if __name__ == '__main__':
    main()
