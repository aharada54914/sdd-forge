import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, rm, readFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { randomBytes } from 'node:crypto';
import { startLocal } from '../plugins/sdd-ship/session-hub/local.mjs';
import { apiClient } from '../plugins/sdd-ship/session-hub/api.mjs';
import { digest } from '../plugins/sdd-ship/session-hub/http.mjs';
import { runOne } from '../plugins/sdd-ship/session-hub/runner.mjs';
import { initial, transition, publicState } from '../plugins/sdd-ship/session-hub/core.mjs';
import { embeddedHub } from '../plugins/sdd-ship/session-hub/build.mjs';
const token = () => randomBytes(32).toString('hex');
async function fixture(t) {
  const directory = await mkdtemp(join(tmpdir(),'sdd-hub-')); const ownerToken = token();
  const config = {directory,project:'project',ownerToken}; let host = await startLocal(config);
  t.after(async () => {await host.close(); await rm(directory,{recursive:true,force:true});});
  const owner = apiClient({url:host.url,token:ownerToken,project:'project'});
  const sessionToken = token(); let state = await owner.read();
  state = await owner.command(state,'register',{id:'worker',label:'実装セッション',tokenHash:await digest(sessionToken)});
  return {directory,ownerToken,owner,sessionToken,get host(){return host;},
    async restart(){await host.close(); host = await startLocal({...config,port:Number(new URL(host.url).port)});},
    worker:apiClient({url:host.url,token:sessionToken,project:'project'})};
}
const ask = {id:'question',sessionId:'worker',title:'どちらの部品を使いますか',expiresAt:Date.now()+3600000,
  options:[{id:'a',label:'強調',preview:{storyId:'hub-choice--variants',version:'1',variant:'primary'}},{id:'b',label:'標準'}]};
test('real HTTP question -> answer -> session receipt survives restart and rejects conflicts',async t => {
  const f = await fixture(t); let state = await f.worker.read();
  assert.equal(state.sessions.length,1); assert.equal('tokenHash' in state.sessions[0],false);
  state = await f.worker.command(state,'ask',ask);
  await assert.rejects(f.worker.command(state,'answer',{id:'question',optionId:'a',requestId:'request'}),/owner-required/);
  const ownerState = await f.owner.read();
  const answers = await Promise.allSettled(['a','b'].map(optionId => f.owner.command(ownerState,'answer',{id:'question',optionId,requestId:optionId})));
  assert.equal(answers.filter(r=>r.status==='fulfilled').length,1);
  await f.restart(); state = await f.worker.read();
  assert.equal(state.questions[0].status,'answered');
  const answer = state.questions[0].answer;
  await assert.rejects(f.worker.command(state,'receive',{id:'question',requestId:'wrong'}),/answer-mismatch/);
  state = await f.worker.command(state,'receive',{id:'question',requestId:answer.requestId});
  assert.equal(state.questions[0].status,'received');
  const stored = await readFile(join(f.directory,'hub.json'),'utf8');
  assert.equal(stored.includes(f.sessionToken),false); assert.equal(stored.includes(f.ownerToken),false);
});
test('session isolation, project binding, request bounds and cross-origin controls', async t => {
  const f = await fixture(t); let s = await f.owner.read();
  s = await f.owner.command(s,'register',{id:'other',label:'別作業',tokenHash:await digest(token())});
  await assert.rejects(f.worker.command(await f.worker.read(),'ask',{...ask,sessionId:'other'}),/session-denied/);
  await f.owner.command(s,'ask',{...ask,sessionId:'other'});
  assert.equal((await f.worker.read()).questions.length,0);
  assert.equal((await fetch(f.host.url+'/api/hub')).status,401);
  assert.equal((await fetch(f.host.url+'/api/hub',{headers:{'oai-authenticated-user-id':'fake'}})).status,401);
  const post = (body,origin) => fetch(f.host.url+'/api/hub/command',{method:'POST',headers:{authorization:'Bearer '+f.ownerToken,'Content-Type':'application/json',...(origin?{Origin:origin}:{})},body:JSON.stringify(body)});
  assert.equal((await post({project:'different',expectedRevision:s.revision,action:'away',input:{enabled:true}})).status,409);
  assert.equal((await post({},'https://evil.test')).status,403);
  assert.equal((await post({payload:'x'.repeat(33000)})).status,413);
  const login = await fetch(f.host.url+'/api/hub/login',{method:'POST',headers:{Origin:f.host.url},body:JSON.stringify({token:f.ownerToken})});
  assert.equal(login.status,200);
  const cookie = login.headers.get('set-cookie').split(';')[0];
  assert.equal((await fetch(f.host.url+'/api/hub/command',{method:'POST',headers:{Cookie:cookie},body:'{}'})).status,403);
  await assert.rejects(startLocal({directory:f.directory,project:'project',ownerToken:f.ownerToken}),/EEXIST/);
});
test('away worker executes only allowed jobs, waits for resources and honors pause', async t => {
  const f = await fixture(t); let s = await f.owner.read();
  s = await f.owner.command(s,'enqueue',{id:'job',sessionId:'worker',commandId:'verify',title:'検証',approved:true});
  const output = join(f.directory,'effect');
  const runner = {url:f.host.url,project:'project',token:f.sessionToken,sessionId:'worker',minFreeMb:0,maxLoad:100,
    commands:{verify:{argv:[process.execPath,'-e',"require('node:fs').writeFileSync(process.argv[1],'done')",output],cwd:f.directory,timeoutMs:5000}}};
  assert.equal(await runOne(runner),false);
  s = await f.owner.command(s,'away',{enabled:true});
  assert.equal(await runOne({...runner,minFreeMb:Number.MAX_SAFE_INTEGER}),false);
  assert.equal(await runOne({...runner,commands:{}}),false);
  assert.equal(await runOne(runner),true);
  assert.equal(await readFile(output,'utf8'),'done');
  assert.equal((await f.owner.read()).jobs[0].status,'succeeded');
  assert.equal(await runOne(runner),false);
});
test('worker cancellation kills running process; timeout fails without automatic replay', async t => {
  const f = await fixture(t); let s = await f.owner.read();
  s = await f.owner.command(s,'enqueue',{id:'cancel',sessionId:'worker',commandId:'long',title:'長い作業',approved:true});
  await f.owner.command(s,'away',{enabled:true});
  const config = {url:f.host.url,project:'project',token:f.sessionToken,sessionId:'worker',minFreeMb:0,maxLoad:100,
    commands:{long:{argv:[process.execPath,'-e','setTimeout(()=>{},20000)'],cwd:f.directory,timeoutMs:10000}}};
  const running = runOne(config);
  for (let i=0;i<50;i++) {s=await f.owner.read();if(s.jobs[0].status==='running')break;await new Promise(r=>setTimeout(r,20));}
  await f.owner.command(s,'cancel',{id:'cancel'}); await running;
  assert.equal((await f.owner.read()).jobs[0].status,'cancelled');
  s=await f.owner.read(); await f.owner.command(s,'enqueue',{id:'timeout',sessionId:'worker',commandId:'long',title:'期限',approved:true});
  await runOne({...config,commands:{long:{...config.commands.long,timeoutMs:100}}});
  assert.equal((await f.owner.read()).jobs[1].status,'failed');
});
test('expired questions and leases fail closed; lease recovery requires stopped worker confirmation', () => {
  let s=initial('p'); const actor={role:'owner'}; const now=1000;
  const command=(action,input,who=actor,time=now)=>{s=transition(s,{project:'p',expectedRevision:s.revision,action,input},who,time);return s;};
  command('register',{id:'w',label:'Worker',tokenHash:'a'.repeat(64)});
  command('ask',{...ask,sessionId:'w',expiresAt:2000});
  assert.throws(()=>command('answer',{id:'question',optionId:'a',requestId:'r'},actor,2001),/question-closed/);
  command('enqueue',{id:'j',sessionId:'w',commandId:'check',title:'check',approved:true}); command('away',{enabled:true});
  command('claim',{id:'j',claimId:'c',timeoutMs:100},{role:'session',sessionId:'w'});
  assert.equal(publicState(s,actor,40000).jobs[0].status,'uncertain');
  assert.throws(()=>command('resolve',{id:'j'},actor,40000),/stop-worker-first/);
  command('resolve',{id:'j',workerStopped:true},actor,40000);assert.equal(s.jobs[0].status,'uncertain');
});
test('Sites embedded worker preserves owner/session boundary and R2 conditional writes', async () => {
  const source=(await readFile(new URL('../plugins/sdd-ship/status-site/worker.mjs',import.meta.url),'utf8'))
    .replace('__DASHBOARD_PAGE__',JSON.stringify('dashboard')).replace('__OBSERVATION_CODE__',await readFile(new URL('../plugins/sdd-ship/status-site/observations.js',import.meta.url),'utf8')).replace('__HUB_CODE__',embeddedHub());
  const {default:worker}=await import('data:text/javascript;base64,'+Buffer.from(source).toString('base64'));
  let value=null,revision=0;const owner=token();
  const env={SDD_HUB_PROJECT:'p',SDD_HUB_OWNER_ID:'owner',SDD_HUB_OWNER_TOKEN:owner,SDD_PUBLISHER_TOKEN:'publisher',BUCKET:{
    async get(){return value===null?null:{etag:String(revision),json:async()=>JSON.parse(value)};},
    async put(key,next,{onlyIf}){if(onlyIf.etagMatches!==undefined&&onlyIf.etagMatches!==String(revision))return null;value=next;revision++;return {etag:String(revision)};}}};
  const req=(path,headers={},command)=>new Request('https://site.test'+path,{headers,...(command?{method:'POST',body:JSON.stringify(command)}:{})});
  assert.equal((await worker.fetch(req('/api/hub',{'X-SDD-Publisher':'publisher'}),env)).status,401);
  assert.equal((await worker.fetch(req('/hub',{'oai-authenticated-user-id':'viewer'}),env)).status,403);
  assert.equal((await worker.fetch(req('/hub',{'oai-authenticated-user-id':'owner'}),env)).status,200);
  const headers={authorization:'Bearer '+owner};
  const command={project:'p',expectedRevision:0,action:'away',input:{enabled:true}};
  assert.equal((await worker.fetch(req('/api/hub/command',headers,command),env)).status,200);
  assert.equal((await worker.fetch(req('/api/hub/command',headers,command),env)).status,409);
});
