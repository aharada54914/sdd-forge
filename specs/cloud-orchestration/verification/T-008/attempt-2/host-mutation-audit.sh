#!/usr/bin/env bash
set -euo pipefail
python3 -B - <<'PY'
import importlib.util
import json
import unittest
from pathlib import Path
path = Path('tests/host-review-preflight.tests.py')
spec = importlib.util.spec_from_file_location('host_scope_audit', path)
assert spec is not None and spec.loader is not None
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
expected = set(json.loads(Path('specs/cloud-orchestration/verification/T-008/attempt-2/prior-cloud-protection-gap.json').read_text())['added'])
expected.update(['plugins/sdd-azure-cloud/scripts/cloud.py', 'plugins/sdd-aws-cloud/scripts/cloud.py',
                 'plugins/sdd-azure-cloud/scripts/governed-setup.md', 'plugins/sdd-aws-cloud/scripts/governed-setup.md',
                 'plugins/sdd-bootstrap/scripts/cloud-routing.py'])
seen = set()
class Result(unittest.TextTestResult):
    def addSubTest(self, test, subtest, err):
        super().addSubTest(test, subtest, err)
        path = subtest.params.get('path')
        if path in expected:
            change = subtest.params['change']
            print(json.dumps({'path': path, 'mutation': change, 'result': 'PASS' if err is None else 'FAIL'}))
            if err is None:
                seen.add((path, change))
suite = unittest.TestSuite([module.ProtectedEntrypointTests('test_012d_unrelated_membership_unchanged')])
result = unittest.TextTestRunner(resultclass=Result, verbosity=2).run(suite)
assert result.wasSuccessful()
assert len(expected) == 16
assert seen == {(path, change) for path in expected for change in ('remove', 'duplicate')}
print('PASS: actual 32 cloud membership mutation bodies; matched count controls and unrelated/extra negatives in the same test')
PY
