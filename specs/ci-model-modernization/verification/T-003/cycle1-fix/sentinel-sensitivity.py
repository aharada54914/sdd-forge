"""Counterfactual origin-probe fixtures only; no product workflow changes."""
from pathlib import Path
import importlib.util
import json
import tempfile
import subprocess
import os

ROOT = Path('/workspace/sdd-forge')
OUT = ROOT / 'specs/ci-model-modernization/verification/T-003/cycle1-fix'
spec = importlib.util.spec_from_file_location('fix_ci_tests', ROOT / 'tests/verification-ci.tests.py')
assert spec and spec.loader
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
rows = []
for placement, expected in [('old-after-main', 0), ('fixed-before-main', 96)]:
    fixture = m.WorkflowPlanIntegrationTests()
    try:
        fixture.setUp()
        path = fixture.root / 'tests/verification-impact.py'
        source = path.read_text()
        sentinel = '\nraise SystemExit(96)\n'
        path.write_text(source + sentinel if placement == 'old-after-main' else
                        source.replace("if __name__ == '__main__':", sentinel + "\nif __name__ == '__main__':"))
        fixture.head = fixture.commit('counterfactual ' + placement)
        body = fixture.actual_body()
        token = 'python3 -I -B "$planner" --plan'
        assert body.count(token) == 1
        body = body.replace(token, 'planner="$subject/tests/verification-impact.py"\n' + token)
        with tempfile.TemporaryDirectory(dir=fixture.temp.name) as directory:
            runtime = Path(directory)
            env = dict(os.environ, GITHUB_WORKSPACE=fixture.temp.name, RUNNER_TEMP=str(runtime),
                       GITHUB_RUN_ID='123', GITHUB_RUN_ATTEMPT='1', GITHUB_OUTPUT=str(runtime / 'output'),
                       CI_EVENT='pull_request', CI_BASE_SHA=fixture.base, CI_HEAD_SHA=fixture.head,
                       CI_TESTED_SHA=fixture.head, CI_API_HEAD_SHA=fixture.head, CI_FORCE_FULL='false')
            result = subprocess.run(['bash', '-e', '-o', 'pipefail', '-c', body], cwd=fixture.temp.name,
                                    env=env, capture_output=True, text=True, timeout=60)
            assert result.returncode == expected, result.stdout + result.stderr
            rows.append({'fixture': placement, 'forced_wrong_origin': 'subject', 'actual_exit': result.returncode,
                         'plan_created': (runtime / 'verification-plan/plan.json').exists(),
                         'stdout': result.stdout, 'stderr': result.stderr})
    finally:
        fixture.doCleanups()
(OUT / 'sentinel-sensitivity.json').write_text(json.dumps({
    'scope': 'Counterfactual wrong-dispatch fixture, not a changed product workflow or hosted result',
    'observations': rows}, indent=2) + '\n')
print('Wrong subject dispatch: old unreachable sentinel exits 0 and publishes plan; corrected sentinel exits 96 and publishes no plan.')
