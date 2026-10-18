"""Run real admission unittest cases with stdlib line tracing; no cloud requests."""

import importlib.util
from pathlib import Path
import sys
import trace
import unittest

root = Path(__file__).resolve().parents[4]
spec = importlib.util.spec_from_file_location(
    "admission_tests", root / "tests/cloud-orchestration-execution.tests.py"
)
assert spec is not None and spec.loader is not None
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
suite = unittest.defaultTestLoader.loadTestsFromModule(module)
tracer = trace.Trace(count=True, trace=False, ignoredirs=[sys.base_prefix, sys.prefix])
result = tracer.runfunc(unittest.TextTestRunner(verbosity=2).run, suite)
tracer.results().write_results(show_missing=True, summary=True, coverdir=sys.argv[1])
raise SystemExit(0 if result.wasSuccessful() and result.testsRun == 22 else 1)
