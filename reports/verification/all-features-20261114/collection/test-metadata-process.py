from pathlib import Path
import json,os,subprocess,tempfile,time
base=Path('/workspace/sites/sdd-forge-status-audit');script=base/'.sites-checkout/scripts/collect-progress.py'
with tempfile.TemporaryDirectory(prefix='metadata-process-') as tmp:
 root=Path(tmp);node=root/'fake-node';pidfile=root/'pids.json'
 node.write_text('#!/usr/bin/python3\nimport json,os,subprocess,sys,time\nr=json.load(sys.stdin)\nchild=subprocess.Popen(["/bin/sleep","180"])\njson.dump({"parent":os.getpid(),"child":child.pid,"environmentKeys":list(os.environ)},open(r["server"],"w"))\ntime.sleep(180)\n');node.chmod(0o700)
 code='import importlib.util,json,signal,sys\ns=importlib.util.spec_from_file_location("collector",sys.argv[1]);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);signal.signal(signal.SIGTERM,m.interrupted)\ntry:m.read_metadata(json.load(sys.stdin))\nexcept KeyboardInterrupt:sys.exit(130)\n'
 env={**os.environ,'SDD_PUBLISHER_TOKEN':'synthetic-must-not-leak','SDD_SITES_SERVICE_TOKEN':'synthetic-service-must-not-leak','OPENAI_API_KEY':'synthetic-extra-must-not-leak'}
 proc=subprocess.Popen(['python3','-c',code,str(script)],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,env=env)
 try:
  proc.stdin.write(json.dumps({'readModel':{'node':str(node),'server':str(pidfile)},'sources':[]}));proc.stdin.close()
  until=time.monotonic()+5
  while not pidfile.exists() and time.monotonic()<until:time.sleep(.05)
  pids=json.loads(pidfile.read_text());assert not {'SDD_PUBLISHER_TOKEN','SDD_SITES_SERVICE_TOKEN','OPENAI_API_KEY'}&set(pids['environmentKeys'])
  proc.terminate();proc.wait(timeout=5);assert proc.returncode==130,proc.returncode
  for pid in [pids['parent'],pids['child']]:
   state=Path('/proc')/str(pid)/'status';assert not state.exists() or '\nState:\tZ' in state.read_text(),pid
  result={'passed':2,'checks':['real metadata child and grandchild receive no publisher/service/API secrets','SIGTERM of collector terminates owned metadata process group'],'childEnvironmentKeys':pids['environmentKeys']}
  (base/'qa/metadata-process-controls.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
 finally:
  if proc.poll() is None:proc.kill();proc.wait()
