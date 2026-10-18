"""Record actual subtest execution (all transports synthetic, no native health claim)."""

from pathlib import Path
import importlib.util
import json
import sys
import unittest

ROOT = Path.cwd()
OUT = ROOT / "specs/cloud-orchestration/verification/T-006/attempt-3"
spec = importlib.util.spec_from_file_location(
    "verification", ROOT / "tests/cloud-orchestration-verification.tests.py"
)
assert spec and spec.loader
module = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = (
    module  # unittest module fixtures enforce the network prohibition
)
spec.loader.exec_module(module)
rows = []


class Result(unittest.TextTestResult):
    def __init__(self, stream, descriptions: bool, verbosity: int):
        super().__init__(stream, descriptions, verbosity)

    def addSubTest(self, test, subtest, err):
        super().addSubTest(test, subtest, err)
        rows.append(
            dict(
                test=test.id(),
                branch=str(subtest),
                result="PASS" if err is None else "FAIL",
            )
        )


result = unittest.TextTestRunner(verbosity=2, resultclass=Result).run(
    unittest.defaultTestLoader.loadTestsFromModule(module)
)
(OUT / "matrix-execution.json").write_text(
    json.dumps(
        dict(
            classification="synthetic native-protocol fixtures; no live cloud",
            tests_run=result.testsRun,
            failures=len(result.failures),
            errors=len(result.errors),
            subtests=rows,
        ),
        indent=2,
    )
    + "\n"
)
raise SystemExit(not result.wasSuccessful())
