from pathlib import Path
import hashlib,json,os,socket,subprocess,tempfile,time,uuid
root=Path(__file__).resolve().parents[1]
cfg=json.loads((root/'db/runtime.json').read_text())
assert cfg['isolation']=='per-check-network-namespace-loopback'
assert cfg['listen_addresses']=='127.0.0.1' and cfg['unix_socket_directories']==''
bin=Path(cfg['bin']); run_id=str(uuid.uuid4()); check_dir=root/'reports/db-check';check_dir.mkdir(parents=True,exist_ok=True)
(root/'.run-temp').mkdir(exist_ok=True)
env={k:v for k,v in os.environ.items() if not k.startswith('PG')}
observations=[];error=None;cleaned=False;started=False
proof={'run_id':run_id,'isolation':cfg['isolation'],'source_query_sha256':hashlib.sha256((root/'db/queries/orders.sql').read_bytes()).hexdigest(),'psql_sha256':hashlib.sha256((bin/'psql').read_bytes()).hexdigest(),'namespace':os.readlink('/proc/self/ns/net')}
def invoke(args,**kwargs):
 r=subprocess.run([str(a) for a in args],capture_output=True,text=True,env=env,timeout=(10 if Path(args[0]).name=='psql' else 45),**kwargs)
 if r.returncode:raise AssertionError(r.stderr or r.stdout)
 return r.stdout
with tempfile.TemporaryDirectory(prefix='owned-pg-',dir=root/'.run-temp') as temp:
 temp=Path(temp);data=temp/'data'; log=temp/'server.log'
 with socket.socket() as reservation:
  reservation.bind(('127.0.0.1',0));port=reservation.getsockname()[1]
 proof.update(data_directory=str(data),port=port,psql_client_timeout_seconds=10)
 try:
  invoke([bin/'initdb','-D',data,'--auth=trust','--no-locale','--encoding=UTF8','--username='+cfg['owner']])
  invoke([bin/'pg_ctl','-D',data,'-l',log,'-w','-t','30','-o',f'-c listen_addresses=127.0.0.1 -c unix_socket_directories= -p {port}','start']);started=True
  pid=int((data/'postmaster.pid').read_text().splitlines()[0]);proof['owned_pid']=pid
  base=[bin/'psql','-X','-q','-A','-t','-F','|','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-p',str(port)]
  def owner(statement,database='postgres'):
   return invoke(base+['-U',cfg['owner'],'-d',database],input=statement)
  owner('CREATE DATABASE sql_behavior_fixture; CREATE ROLE fixture_reader LOGIN;')
  owner((root/'db/schema.sql').read_text()+(root/'db/fixture.sql').read_text()+'GRANT SELECT ON public.orders TO fixture_reader;',cfg['database'])
  assert owner('SHOW data_directory;',cfg['database']).strip()==str(data)
  assert owner('SHOW unix_socket_directories;',cfg['database']).strip()==''
  env['PGOPTIONS']='-c default_transaction_read_only=on -c statement_timeout=5000 -c lock_timeout=1000'
  app=base+['-U',cfg['reader'],'-d',cfg['database']]
  def sql(text):return invoke(app+['-c',text]).strip().splitlines()
  def query(value):
   n=int(value)
   return invoke(app+['-v',f'minimum={n}','-f',root/'db/queries/orders.sql']).strip().splitlines()
  expected=['1|0|zero','2|100|注文','3|100|same','4|500|large']
  assert sql('SHOW server_version')==['18.6']
  assert sql('SHOW statement_timeout')==['5s']
  assert sql('SHOW lock_timeout')==['1s']
  assert sql('SHOW listen_addresses')==['127.0.0.1']
  assert sql('SELECT current_database(), current_user')==[cfg['database']+'|'+cfg['reader']]
  assert sql("SELECT has_table_privilege(current_user,'public.orders','SELECT'), has_table_privilege(current_user,'public.orders','INSERT'), has_table_privilege(current_user,'public.orders','UPDATE'), has_table_privilege(current_user,'public.orders','DELETE')")==['t|f|f|f']
  before=sql('SELECT id,amount_cents,label FROM public.orders ORDER BY id');assert before==expected
  cases=[(100,['4|500|large','2|100|注文','3|100|same']),(0,['4|500|large','2|100|注文','3|100|same','1|0|zero']),(501,[]),(-1,['4|500|large','2|100|注文','3|100|same','1|0|zero'])]
  for minimum,want in cases:
   got=query(minimum);observations.append({'minimum':minimum,'expected':want,'observed':got})
   assert got==want,f'inclusive minimum={minimum}: expected {want!r}, observed {got!r}'
   print(f'PASS minimum={minimum} rows={len(got)} values={got!r}')
  try:query('100; SELECT 1')
  except ValueError:print('PASS non-integer input rejected before SQL')
  else:raise AssertionError('non-integer accepted')
  assert sql('SELECT id,amount_cents,label FROM public.orders ORDER BY id')==before
  assert sql("SELECT column_name||':'||data_type||':'||is_nullable FROM information_schema.columns WHERE table_schema='public' AND table_name='orders' ORDER BY ordinal_position")==['id:integer:NO','amount_cents:integer:NO','label:text:NO']
  print('PASS owned isolated PostgreSQL 18.6 target; reader permissions; unchanged rows/schema')
 except Exception as exc:error=str(exc)
 finally:
  if started:
   try:
    assert int((data/'postmaster.pid').read_text().splitlines()[0])==pid
    invoke([bin/'pg_ctl','-D',data,'-w','-t','15','-m','fast','stop'])
    cleaned=not(data/'postmaster.pid').exists()
   except Exception as exc:error=(error or '')+'; cleanup: '+str(exc)
  else:cleaned=not(data/'postmaster.pid').exists()
  proof.update(checks=observations,error=error,cleanup=cleaned,result='PASS' if error is None and cleaned else 'FAIL')
  (check_dir/(run_id+'.json')).write_text(json.dumps(proof,indent=2,ensure_ascii=False)+'\n')
print('DB check',proof['result'],'cleanup',cleaned,'run',run_id)
if error or not cleaned:raise SystemExit(error or 'cleanup incomplete')
