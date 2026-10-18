"""Real scoped unittest execution under stdlib trace (line, not branch coverage)."""
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import trace
import unittest

ROOT = Path(__file__).resolve().parents[5]
EVIDENCE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT/'plugins/sdd-quality-loop/scripts'))
suite=unittest.TestSuite()
for family in ('contracts','execution'):
    spec=importlib.util.spec_from_file_location(f'cloud_{family}_tests',ROOT/f'tests/cloud-orchestration-{family}.tests.py')
    assert spec and spec.loader
    module=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    suite.addTests(unittest.defaultTestLoader.loadTestsFromModule(module))
tracer=trace.Trace(count=True, trace=False)
result=tracer.runfunc(unittest.TextTestRunner(verbosity=2).run,suite)
coverage={}
for name in ('cloud_contracts','cloud_authorization'):
    path=ROOT/f'plugins/sdd-quality-loop/scripts/{name}.py'
    executable=set(trace._find_executable_linenos(str(path)))
    executed={line for (filename,line),count in tracer.results().counts.items() if filename==str(path) and count}
    # Definitions loaded before tracing are not counted as test-executed lines.
    coverage[str(path.relative_to(ROOT))]=dict(sha256=hashlib.sha256(path.read_bytes()).hexdigest(),executable_lines=len(executable),executed_lines=len(executable & executed),percent=round(100*len(executable & executed)/len(executable),2),unexecuted_lines=sorted(executable-executed))
(EVIDENCE/'coverage.json').write_text(json.dumps(dict(tests_run=result.testsRun,failures=len(result.failures),errors=len(result.errors),coverage=coverage,limit='stdlib trace line coverage only; definitions imported before trace are unexecuted; no branch or live-cloud coverage claim'),indent=2)+'\n')
raise SystemExit(0 if result.wasSuccessful() else 1)
