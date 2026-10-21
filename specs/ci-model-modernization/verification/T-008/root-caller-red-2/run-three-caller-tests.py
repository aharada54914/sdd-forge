from pathlib import Path
import importlib.util,json,sys,unittest
r=Path('/workspace/sdd-forge');o=Path(__file__).parent;p=r/'tests/model-policy-installed.tests.py';s=importlib.util.spec_from_file_location('t008_root_caller_checks',p);assert s and s.loader;m=importlib.util.module_from_spec(s);sys.modules[s.name]=m;s.loader.exec_module(m)
class Result(unittest.TextTestResult):
 def __init__(self,*a,**kw):super().__init__(*a,**kw);self.subtests_run=0;self.subtests_passed=0
 def addSubTest(self,test,subtest,err):
  self.subtests_run+=1
  if err is None:self.subtests_passed+=1
  super().addSubTest(test,subtest,err)
all_tests=unittest.defaultTestLoader.loadTestsFromModule(m);assert all_tests.countTestCases()==27,all_tests.countTestCases();suite=unittest.defaultTestLoader.loadTestsFromTestCase(m.InstalledPanelistCallerTests);assert suite.countTestCases()==3,suite.countTestCases();v=unittest.TextTestRunner(verbosity=2,resultclass=Result).run(suite);(o/'unittest-result.json').write_text(json.dumps({'tests_run':v.testsRun,'subtests_run':v.subtests_run,'subtests_passed':v.subtests_passed,'failures':len(v.failures),'errors':len(v.errors),'skips':len(v.skipped),'successful':v.wasSuccessful(),'discovery_count':all_tests.countTestCases()},indent=2)+'\n');raise SystemExit(0 if v.wasSuccessful() else 1)
