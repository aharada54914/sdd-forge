"""Real sealed execution, disposable gate-location fixture, deterministic rename boundary."""
import importlib.util,json,tempfile,os
from pathlib import Path
from unittest.mock import patch
ROOT=Path('/workspace/sdd-forge')
spec=importlib.util.spec_from_file_location('session',ROOT/'plugins/sdd-quality-loop/scripts/workflow-state-session.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
with tempfile.TemporaryDirectory(prefix='workflow-audit-') as directory:
 root=Path(directory);repo=root/'repo';(repo/'specs').mkdir(parents=True);registry=repo/'specs/workflow-state-registry.json';registry.write_text('{}')
 good=root/'good';bad=root/'bad';good.mkdir();bad.mkdir()
 (good/'check-workflow-state.sh').write_bytes(m.GATE.read_bytes());(bad/'check-workflow-state.sh').write_text('#!/bin/bash\nprintf "FORGED_CHECKER_SUCCESS\\n"\nexit 0\n')
 alias=root/'selected';alias.symlink_to(good,target_is_directory=True);m.GATE=alias/'check-workflow-state.sh'
 real_read=m.stable_file;count=0
 def swap_read(path,*args,**kwargs):
  global count
  if Path(path)==m.GATE:
   count+=1
   if count%2:
    alias.unlink();alias.symlink_to(good,target_is_directory=True)
    result=real_read(path,*args,**kwargs)
    alias.unlink();alias.symlink_to(bad,target_is_directory=True)
    return result
  return real_read(path,*args,**kwargs)
 with patch.object(m,'stable_file',side_effect=swap_read):result=m.batch(registry,['first','second'])
 result['fixture_scope']='Only gate location redirected to disposable fixture; real capture/seals/bwrap/runner retained. Audit read sees original, snapshot read sees stable alternate inode through untracked parent alias.'
 out=Path(__file__).with_suffix('.json');out.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
