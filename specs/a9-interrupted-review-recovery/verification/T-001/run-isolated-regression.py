from pathlib import Path
import json,shutil,subprocess,tempfile,os,hashlib,sys
root=Path.cwd();evidence=root/'specs/a9-interrupted-review-recovery/verification/T-001'
with tempfile.TemporaryDirectory(prefix='regression-',dir=evidence) as tmp:
 fixture=Path(tmp)
 for plugin in ('sdd-review-loop','sdd-quality-loop'):
  shutil.copytree(root/'plugins'/plugin,fixture/'plugins'/plugin)
 shutil.copytree(root/'contracts',fixture/'contracts')
 (fixture/'tests').mkdir();shutil.copy2(root/'tests/spec-review-loop.tests.sh',fixture/'tests/spec-review-loop.tests.sh')
 shutil.copy2(root/'tests/spec-review-interrupted-recovery.tests.sh',fixture/'tests/spec-review-interrupted-recovery.tests.sh')
 (fixture/'specs').mkdir();(fixture/'reports').mkdir()
 registry=json.loads((root/'specs/workflow-state-registry.json').read_text());registry['entries']=[]
 (fixture/'specs/workflow-state-registry.json').write_text(json.dumps(registry)+'\n')
 child_failure='--child-failure' in sys.argv
 if child_failure:(fixture/'tests/spec-review-interrupted-recovery.tests.sh').write_text('#!/usr/bin/env bash\necho synthetic-child-failure >&2\nexit 7\n')
 label='regression-parent-child-failure' if child_failure else 'regression-spec-loop-isolated'
 before=hashlib.sha256((fixture/'specs/workflow-state-registry.json').read_bytes()).hexdigest()
 command=['bash','tests/spec-review-loop.tests.sh']
 with open(evidence/(label+'.log'),'w') as output:
  result=subprocess.run(command,cwd=fixture,stdout=output,stderr=subprocess.STDOUT)
 after=hashlib.sha256((fixture/'specs/workflow-state-registry.json').read_bytes()).hexdigest()
 receipt={'command':command,'exit_code':result.returncode,'fixture':'fresh disposable public plugin copies + existing parent suite with approved delegated child + synthetic empty registry','registry_restored':before==after,'suite_sha256':hashlib.sha256((fixture/'tests/spec-review-loop.tests.sh').read_bytes()).hexdigest(),'child_sha256':hashlib.sha256((fixture/'tests/spec-review-interrupted-recovery.tests.sh').read_bytes()).hexdigest(),'expected_exit_code':7 if child_failure else 0}
 (evidence/(label+'.json')).write_text(json.dumps(receipt,indent=2)+'\n')
 receipt['expected_exit_code']=7 if child_failure else 0
 print(json.dumps(receipt));raise SystemExit(0 if result.returncode==receipt['expected_exit_code'] and before==after else 1)
