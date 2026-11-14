from pathlib import Path
import datetime,hashlib,importlib.util,json,os,subprocess,tempfile,time,urllib.request
from playwright.sync_api import sync_playwright,expect
base=Path('/workspace/sites/sdd-forge-status-audit');script=base/'.sites-checkout/scripts/collect-progress.py'
spec=importlib.util.spec_from_file_location('collector',script);mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
workspace=Path('/workspace/.tools/sdd-forge-dev/verification-workspace')
sources=[{'id':'lite','label':'Lite actual','root':str(workspace/'lite-task-board-fixed')},{'id':'full','label':'Full actual','root':str(workspace/'full-task-board-fixed')},{'id':'sqlite','label':'SQLite actual','root':str(workspace/'sqlite-task-board-fixed')}]
originals={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for s in sources for p in (Path(s['root'])/'specs').glob('*/tasks.md')}
checks=[];observed=[]
source_hashes={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in [script,script.with_name('read-workflow-metadata.mjs'),base/'.sites-checkout/worker/index.js']}
def fetch(path):
 with urllib.request.urlopen('http://127.0.0.1:8792'+path,timeout=5) as r:return json.load(r)
def await_state(predicate,timeout=12):
 end=time.monotonic()+timeout
 while time.monotonic()<end:
  state=fetch('/api/dashboard')
  if predicate(state):observed.append({'attemptedAt':state['attemptedAt'],'revision':state['revision'],'error':state['error']});return state
  time.sleep(.1)
 raise AssertionError('state not observed')
with tempfile.TemporaryDirectory(prefix='sdd-collector-qa-') as tmp:
 root=Path(tmp);probe=root/'probe/specs/collector-probe/tasks.md';probe.parent.mkdir(parents=True)
 text='# Explicit disposable collector fixture\n\n## T-901 Collector probe\nApproval: Draft\nStatus: Planned\n'
 probe.write_text(text);(root/'probe/AGENTS.md').write_text('# Disposable QA source\n\n## Active Spec Directories\n- `specs/collector-probe/`\n');config={'project':'Bounded local integration: three actual workspaces plus explicit disposable probe','sources':sources+[{'id':'probe','root':str(root/'probe'),'label':'Disposable probe'}]}
 if os.environ.get('COLLECTOR_QA_MCP')=='1':
  config['readModel']={'node':'/workspace/.tools/sdd-forge-dev/verification-tools/node-v26.13.0-linux-x64/bin/node','server':'/workspace/sdd-forge/mcp/sdd-forge-mcp/dist/index.js'}
 if config.get('readModel'):source_hashes[config['readModel']['server']]=hashlib.sha256(Path(config['readModel']['server']).read_bytes()).hexdigest()
 cfg=root/'config.json';cfg.write_text(json.dumps(config));data,rev=mod.collect(config);assert len(data['tasks'])==10 and len({t['key'] for t in data['tasks']})==10;checks.append('real three workspaces collect nine Done tasks without ID collisions plus explicit probe')
 env={**os.environ,'SDD_PUBLISHER_TOKEN':'bounded-local-collector-test-token-12345'};env.pop('SDD_SITES_SERVICE_TOKEN',None)
 log=open(root/'publisher.log','w');proc=subprocess.Popen(['python3',str(script),'--config',str(cfg),'--endpoint','http://127.0.0.1:8792','--cycles','90','--interval','.5'],env=env,stdout=log,stderr=log)
 try:
  await_state(lambda s:bool(s.get('data')) and len(s['data']['tasks'])==10)
  with sync_playwright() as pw:
   browser=pw.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox']);page=browser.new_page(viewport={'width':1440,'height':1000});errors=[];page.on('pageerror',lambda e:errors.append(str(e)));page.goto('http://127.0.0.1:8792')
   page.locator('#tabs').get_by_role('link',name='一覧',exact=True).click();expect(page.locator('tbody tr')).to_have_count(10)
   probe.write_text(text.replace('Planned','In Progress'));await_state(lambda s:any(t['id']=='T-901' and t['status']=='In Progress' for t in s['data']['tasks']))
   expect(page.locator('tbody tr').filter(has_text='Collector probe').locator('[data-status]')).to_have_attribute('data-status','In Progress',timeout=10000);checks.append('filesystem write automatically published and observed by existing five-second UI poll without refresh')
   page.screenshot(path=str(base/'qa/collector-live-update.png'),full_page=True)
   (root/'probe').rename(root/'probe-unavailable');await_state(lambda s:s['error']=='source-collection-failed' and len(s['data']['tasks'])==10);expect(page.locator('#freshness')).to_have_attribute('data-state','error',timeout=10000);checks.append('source disappearance publishes failure while retaining last-good content in browser')
   (root/'probe-unavailable').rename(root/'probe');await_state(lambda s:s['error'] is None);expect(page.locator('#freshness')).to_have_attribute('data-state','live',timeout=10000);checks.append('source recovery automatically restores fresh state')
   if config.get('readModel'):
    probe.rename(probe.with_suffix('.unavailable'));state=await_state(lambda s:s['error'] is None and len(s['data']['tasks'])==9);assert any(f['id']=='probe/collector-probe' for f in state['data']['features']);probe.with_suffix('.unavailable').rename(probe);await_state(lambda s:len(s['data']['tasks'])==10);checks.append('MCP registered taskless feature retained without fabricated task or removal')
   page.set_viewport_size({'width':390,'height':844});assert page.evaluate('document.documentElement.scrollWidth <= innerWidth');page.screenshot(path=str(base/'qa/collector-mobile.png'),full_page=True);assert not errors;browser.close();checks.append('mobile no overflow and no JavaScript errors')
  events=fetch('/api/observations')['events'];assert any(e['kind']=='changed' and e['key'].endswith('/T-901') for e in events);assert any(e['kind']=='source-failed' for e in events);assert any(e['kind']=='source-recovered' for e in events);checks.append('derived history contains actual source change, failure and recovery')
  health=fetch('/api/health');assert health['state']=='running' and health['consecutiveFailures']==0;checks.append('automatic publisher health reports running after recovery')
  before=fetch('/api/dashboard')['attemptedAt'];proc.terminate();proc.wait(timeout=5);time.sleep(1);assert fetch('/api/dashboard')['attemptedAt']==before;checks.append('bounded process shutdown stops publication; no daemon falsely claimed')
  with sync_playwright() as pw:
   browser=pw.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox']);page=browser.new_page();page.goto('http://127.0.0.1:8792');expect(page.locator('#freshness')).to_have_attribute('data-state','stale',timeout=70000);browser.close()
  checks.append('actual stopped collector becomes visibly stale after real source-age threshold')
  old=fetch('/api/dashboard');restarted=subprocess.run(['python3',str(script),'--config',str(cfg),'--endpoint','http://127.0.0.1:8792','--cycles','2','--interval','.2'],env=env,capture_output=True,text=True);assert restarted.returncode==0,restarted.stdout
  after=fetch('/api/dashboard');assert after['revision']==old['revision'] and after['changedAt']==old['changedAt'] and after['checkedAt']>old['checkedAt'];before=after['attemptedAt'];checks.append('publisher restart retains unchanged content age and advances source observation')
  badcfg={**config,'project':'different'};cfg.write_text(json.dumps(badcfg));bad=subprocess.run(['python3',str(script),'--config',str(cfg),'--endpoint','http://127.0.0.1:8792'],env=env,capture_output=True,text=True);assert bad.returncode==1;assert fetch('/api/dashboard')['attemptedAt']==before;assert env['SDD_PUBLISHER_TOKEN'] not in bad.stdout+bad.stderr;checks.append('project mismatch refused before writing and credential never logged')
 finally:
  if proc.poll() is None:proc.terminate();proc.wait(timeout=5)
  log.close()
 for file,digest in originals.items():assert hashlib.sha256(Path(file).read_bytes()).hexdigest()==digest
 checks.append('original lite/full/SQLite task files unchanged')
 for source,digest in source_hashes.items():assert hashlib.sha256(Path(source).read_bytes()).hexdigest()==digest,'source changed during test: '+source
 result={'observedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'scope':'Actual three source workspaces plus an explicitly disposable mutation probe; real HTTP loop, exact site Worker with local in-memory R2, Chromium UI. Not production authentication or persistence proof.','checks':checks,'observations':observed,'originalTaskHashes':originals,'publisherCredential':'synthetic loopback-only test token, not production','workerSha256':hashlib.sha256((base/'.sites-checkout/worker/index.js').read_bytes()).hexdigest(),'collectorSha256':hashlib.sha256(script.read_bytes()).hexdigest(),'adapterSha256':hashlib.sha256(script.with_name('read-workflow-metadata.mjs').read_bytes()).hexdigest(),'sourceHashes':source_hashes,'metadataMode':'real MCP stdio' if config.get('readModel') else 'filesystem-only (phase explicitly unknown)'}
 (base/('qa/collector-mcp-results.json' if config.get('readModel') else 'qa/collector-results.json')).write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(json.dumps({'passed':len(checks),'checks':checks},ensure_ascii=False))
