from pathlib import Path
import importlib.util,json,sys,unittest
root=Path('/workspace/sdd-forge'); output=Path(__file__).parent
spec=importlib.util.spec_from_file_location('t008_spec_root_actual',root/'tests/model-policy-installed.tests.py');assert spec and spec.loader
module=importlib.util.module_from_spec(spec);sys.modules[spec.name]=module;spec.loader.exec_module(module)
class Result(unittest.TextTestResult):
 def __init__(self,*args,**kwargs):super().__init__(*args,**kwargs);self.subtests_run=0;self.subtests_passed=0
 def addSubTest(self,test,subtest,error):
  self.subtests_run+=1
  if error is None:self.subtests_passed+=1
  super().addSubTest(test,subtest,error)
suite=unittest.TestSuite([unittest.defaultTestLoader.loadTestsFromTestCase(module.InstalledSpecCallerTests),unittest.defaultTestLoader.loadTestsFromTestCase(module.InstalledQualityCallerTests)]);assert suite.countTestCases()==7
result=unittest.TextTestRunner(verbosity=2,resultclass=Result).run(suite)
(output/'focused-result.json').write_text(json.dumps({'tests_run':result.testsRun,'subtests_run':result.subtests_run,'subtests_passed':result.subtests_passed,'failures':len(result.failures),'errors':len(result.errors),'skips':len(result.skipped),'successful':result.wasSuccessful()},indent=2)+'\n')
raise SystemExit(0 if result.wasSuccessful() else 1)
