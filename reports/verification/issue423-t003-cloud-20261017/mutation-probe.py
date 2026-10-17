"""Failure-sensitivity probe; synthetic perturbations, not historical TDD RED."""
import importlib.util
import io
from pathlib import Path
import unittest

root = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('t003_probe_suite', root / 'tests/sdd-domain-multitarget-T-003.tests.py')
suite = importlib.util.module_from_spec(spec)
spec.loader.exec_module(suite)
original = suite.resolver._assemble_facet_manifest
cases = [name for name in dir(suite.SelectedPlanTests) if name.startswith(('test_003a_', 'test_003b_', 'test_003c_design_', 'test_003d_', 'test_003e_'))]
for mutation in ('collapse-facets', 'drop-selected-gates'):
    def perturbed(*args, **kwargs):
        manifest = original(*args, **kwargs)
        if mutation == 'collapse-facets':
            manifest['required_facets'] = ['generic-target']
        else:
            manifest['resolved_gates'] = [g for g in manifest['resolved_gates'] if g['stage'] != 'implementation']
        return manifest
    suite.resolver._assemble_facet_manifest = perturbed
    result = unittest.TextTestRunner(stream=io.StringIO()).run(
        unittest.TestSuite(suite.SelectedPlanTests(name) for name in cases))
    print(mutation, 'tests:', result.testsRun, 'failures:', len(result.failures), 'errors:', len(result.errors))
    assert result.testsRun == 5 and len(result.failures) == 5 and not result.errors
suite.resolver._assemble_facet_manifest = original
print('Both deliberately incorrect Resolver projections were rejected by all five target tests.')
