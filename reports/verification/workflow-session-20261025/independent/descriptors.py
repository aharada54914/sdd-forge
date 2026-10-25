"""Independent real sealed/unsealed/private-FD execution evidence; no product edits."""
import importlib.util,os,json
from pathlib import Path
ROOT=Path('/workspace/sdd-forge')
spec=importlib.util.spec_from_file_location('fixture',ROOT/'tests/workflow-state-session.tests.py');fixture=importlib.util.module_from_spec(spec);spec.loader.exec_module(fixture)
case=fixture.WorkflowSession();case.setUp();snapshot=fixture.session.capture(case.registry)
rows=[]
def record(label,result):
 code,stdout,stderr,reason,cleanup=result
 rows.append(dict(case=label,exit_code=code,stdout=stdout.decode(),stderr=stderr.decode(),reason=reason,cleanup=cleanup))
try:
 snapshot.seal();fds=[fd for _,_,fd in snapshot.descriptors]
 denied=False
 try:os.write(fds[0],b'X')
 except PermissionError:denied=True
 rows.append(dict(case='sealed-input-write',denied=denied));assert denied
 private=os.memfd_create('independent-private-nonpassed',0);os.write(private,b'PRIVATE-FIXTURE-SENTINEL')
 try:
  command=['/usr/bin/bash','-c','for p in /proc/self/fd/*; do printf "%s\\n" "$p"; done']
  result=case.actual_execute(snapshot.command(case.registry,command),'/',10,4096,input_fds=fds)
  record('sealed-child-fd-inventory',result);assert result[0]==0 and result[4]
  # The private FD remains open in this parent, but is not an input FD.
  command=['/usr/bin/bash','-c','if [[ -e /proc/self/fd/'+str(private)+' ]]; then printf PRIVATE_FD_PRESENT; exit 9; fi; printf PRIVATE_FD_ABSENT']
  for fd in fds:os.lseek(fd,0,os.SEEK_SET)
  result=case.actual_execute(snapshot.command(case.registry,command),'/',10,4096,input_fds=fds)
  record('private-parent-fd-not-inherited',result);assert result[0]==0 and result[1]==b'PRIVATE_FD_ABSENT' and result[4]
  result=case.actual_execute(['/usr/bin/true'],'/',10,4096,input_fds=[private])
  record('unsealed-fd-refused',result);assert result[0]==125 and result[3]=='unsealed-input-fd' and not result[4]
 finally:os.close(private)
finally:snapshot.close();case.doCleanups()
out=Path(__file__).with_suffix('.json');out.write_text(json.dumps(rows,indent=2)+'\n');print(out);print(json.dumps(rows,indent=2))
