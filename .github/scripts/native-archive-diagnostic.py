"""Bounded native tar Unicode probe; no network, credentials, or repository edits."""
import io,json,os,pathlib,shutil,subprocess,tarfile,tempfile
NAMES=['日本語.txt', '日本語'*12+'.txt'];PAYLOAD=b'tracked UTF-8 payload\n'
with tempfile.TemporaryDirectory(prefix='sdd-native-tar-') as raw:
 root=pathlib.Path(raw);src=root/'source';src.mkdir()
 def git(*args):return subprocess.run(['git','-C',str(src),*args],check=True,capture_output=True).stdout
 git('init','-q');git('config','core.autocrlf','false')
 for n in NAMES:(src/n).write_bytes(PAYLOAD)
 git('add','.');tree=git('write-tree').decode().strip();git('archive','--format=tar.gz','--prefix=top/','--output='+str(root/'git.tar.gz'),tree)
 with tarfile.open(root/'pax.tar.gz','w:gz') as t:
  for n in NAMES:
   info=tarfile.TarInfo('top/'+n);info.size=len(PAYLOAD);t.addfile(info,io.BytesIO(PAYLOAD))
 print(json.dumps({'platform':os.name,'tar_executable':shutil.which('tar'),'tar_version':subprocess.run(['tar','--version'],capture_output=True,text=True,errors='replace').stdout},ensure_ascii=True),flush=True)
 for kind in ['git','pax']:
  with tarfile.open(root/(kind+'.tar.gz')) as t:print(json.dumps({'kind':kind,'headers':[{'name':m.name,'pax':m.pax_headers} for m in t]},ensure_ascii=True),flush=True)
  for label,opts in [('default',[]),('utf8',['--options','hdrcharset=UTF-8'])]:
   dest=root/(kind+'-'+label);dest.mkdir();cmd=['tar',*opts,'-xzf',str(root/(kind+'.tar.gz')),'-C',str(dest)];p=subprocess.run(cmd,capture_output=True,text=True,errors='replace')
   print(json.dumps({'kind':kind,'mode':label,'exit':p.returncode,'stdout':p.stdout,'stderr':p.stderr,'files':[x.relative_to(dest).as_posix() for x in dest.rglob('*') if x.is_file()],'expected':{n:(dest/'top'/n).is_file() and (dest/'top'/n).read_bytes()==PAYLOAD for n in NAMES}},ensure_ascii=True),flush=True)
