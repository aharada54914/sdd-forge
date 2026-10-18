"""Scoped T-012 execution + line coverage; deterministic transports, not live IAM."""
from pathlib import Path
import hashlib
import json
import runpy
import sys
import trace

ROOT = Path(__file__).resolve().parents[5]
EVIDENCE = Path(__file__).resolve().parent
SOURCES = [ROOT / 'plugins/sdd-azure-cloud/scripts' / (name + '.py')
           for name in ('azure_arm', 'azure_execution', 'azure_governed')]
tracer = trace.Trace(count=True, trace=False, ignoredirs=[sys.prefix, sys.exec_prefix])
sys.argv = [str(ROOT / 'tests/cloud-orchestration-execution.tests.py')]
code = 0
try:
    tracer.runfunc(runpy.run_path, sys.argv[0], run_name='__main__')
except SystemExit as result:
    code = int(result.code or 0)
counts = tracer.results().counts
coverage = []
for path in SOURCES:
    executable = set(trace._find_executable_linenos(str(path)))
    hit = {line for (file, line), count in counts.items() if Path(file).resolve() == path and count}
    coverage.append(dict(path=str(path.relative_to(ROOT)), sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                         executable_lines=len(executable), hit_lines=len(executable & hit),
                         missing=sorted(executable-hit), percent=round(100*len(executable & hit)/len(executable),2)))
(EVIDENCE / 'coverage.json').write_text(json.dumps(dict(classification='deterministic synthetic transports',
    exit_code=code, sources=coverage), indent=2)+'\n')
raise SystemExit(code)
