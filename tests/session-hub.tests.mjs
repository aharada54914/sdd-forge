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
    .replace('__DECISION_CODE__',await readFile(new URL('../plugins/sdd-ship/status-site/decisions.js',import.meta.url),'utf8')).replace('__DASHBOARD_PAGE__',JSON.stringify('dashboard')).replace('__OBSERVATION_CODE__',await readFile(new URL('../plugins/sdd-ship/status-site/observations.js',import.meta.url),'utf8')).replace('__HUB_CODE__',embeddedHub());
  const {default:worker}=await import('data:text/javascript;base64,'+Buffer.from(source).toString('base64'));
  let value=null,revision=0;const owner=token();
  const env={SDD_HUB_PROJECT:'p',SDD_HUB_OWNER_ID:'owner',SDD_HUB_OWNER_TOKEN:owner,SDD_PUBLISHER_TOKEN:'publisher',BUCKET:{
    async get(){return value===null?null:{etag:String(revision),json:async()=>JSON.parse(value)};},
    async put(key,next,{onlyIf}){if(onlyIf.etagMatches!==undefined&&onlyIf.etagMatches!==String(revision))return null;value=next;revision++;return {etag:String(revision)};}}};
  const req=(path,headers={},command)=>new Request('https://site.test'+path,{headers,...(command?{method:'POST',body:JSON.stringify(command)}:{})});
  assert.equal((await worker.fetch(req('/api/hub',{'X-SDD-Publisher':'publisher'}),env)).status,401);
  assert.equal((await worker.fetch(req('/hub',{'oai-authenticated-user-id':'viewer'}),env)).status,403);
  assert.equal((await worker.fetch(req('/hub',{'oai-authenticated-user-id':'owner'}),env)).status,200);
  const emailEnv={...env,SDD_HUB_OWNER_ID:null,SDD_HUB_OWNER_EMAIL:'owner@example.test'};
  assert.equal((await worker.fetch(req('/hub',{'oai-authenticated-user-id':'signed','oai-authenticated-user-email':'owner@example.test'}),emailEnv)).status,200);
  assert.equal((await worker.fetch(req('/hub',{'oai-authenticated-user-id':'signed','oai-authenticated-user-email':'other@example.test'}),emailEnv)).status,403);
  assert.equal((await worker.fetch(req('/hub',{'oai-authenticated-user-email':'owner@example.test'}),emailEnv)).status,403);
  const headers={authorization:'Bearer '+owner};
  const command={project:'p',expectedRevision:0,action:'away',input:{enabled:true}};
  assert.equal((await worker.fetch(req('/api/hub/command',headers,command),env)).status,200);
  assert.equal((await worker.fetch(req('/api/hub/command',headers,command),env)).status,409);
  const rpc = (method,params,auth=headers) => worker.fetch(req('/mcp',auth,{jsonrpc:'2.0',id:1,method,params}),env);
  assert.equal((await rpc('tools/list',{},{})).status,401);
  const initialized = await (await rpc('initialize',{protocolVersion:'2025-06-18'})).json();
  assert.equal(initialized.result.protocolVersion,'2025-06-18');
  const listed = await (await rpc('tools/list')).json();
  assert.equal(listed.result.tools[0].name,'sdd_hub_read');
  const read = await (await rpc('tools/call',{name:'sdd_hub_read'})).json();
  assert.equal(JSON.parse(read.result.content[0].text).away,true);
  const native = {'oai-authenticated-user-id':'owner'};
  const written = await (await rpc('tools/call',{name:'sdd_hub_command',arguments:{command:{...command,expectedRevision:1,input:{enabled:false}}}},native)).json();
  assert.equal(written.result.isError,false);
  assert.equal(JSON.parse(written.result.content[0].text).away,false);

});

test('direct messages and answers are claimed once, scoped to the registered destination', async t => {
  const {sendCodex,deliverOne}=await import('../plugins/sdd-ship/session-hub/push.mjs');
  const {writeFile,chmod}=await import('node:fs/promises');
  const f=await fixture(t);const thread='11111111-2222-4333-8444-555555555555';
  let state=await f.owner.read();
  await assert.rejects(f.owner.command(state,'register',{id:'worker',label:'bad',tokenHash:await digest(f.sessionToken),transport:'codex',destination:'https://chatgpt.com/c/foo'}),/unsupported-conversation/);
  state=await f.owner.command(state,'register',{id:'worker',label:'Codex',tokenHash:await digest(f.sessionToken),transport:'codex',destination:thread});
  await assert.rejects(f.worker.command(await f.worker.read(),'message',{id:'not-owner',sessionId:'worker',text:'test'}),/owner-required/);
  state=await f.owner.command(state,'message',{id:'push-message',sessionId:'worker',text:'Continue this existing conversation.'});
  await assert.rejects(f.owner.command(state,'register',{id:'worker',label:'Moved',tokenHash:await digest(f.sessionToken),transport:'codex',destination:'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee'}),/pending-deliveries/);
  assert.equal((await f.owner.command(state,'message',{id:'push-message',sessionId:'worker',text:'Continue this existing conversation.'})).messages.length,1);
  const executable=join(f.directory,'codex-fixture');const log=join(f.directory,'rpc.jsonl');
  await writeFile(executable,'#!'+process.execPath+'\n'+`
import {createInterface} from 'node:readline';import {appendFileSync} from 'node:fs';
createInterface({input:process.stdin}).on('line',line=>{const r=JSON.parse(line);if(r.id===undefined)return;appendFileSync(${JSON.stringify(log)},line+'\\n');let result={};
if(r.method==='thread/read'||r.method==='thread/resume')result={thread:{id:${JSON.stringify(thread)},turns:[]}};
if(r.method==='turn/start')result={turn:{id:'native-turn'}};
console.log(JSON.stringify({id:r.id,result}));});
`);await chmod(executable,0o700);
  const cfg={url:f.host.url,project:'project',token:f.sessionToken,sessionId:'worker',transport:'codex',destination:thread,binary:executable};
  const results=await Promise.all([deliverOne(cfg),deliverOne(cfg)]);assert.equal(results.filter(Boolean).length,1);
  state=await f.owner.read();assert.equal(state.messages[0].status,'accepted');assert.equal(state.messages[0].receipt,'native-turn');
  const calls=(await readFile(log,'utf8')).trim().split('\n').map(JSON.parse);
  assert.equal(calls.filter(r=>r.method==='turn/start').length,1);
  assert.equal(calls.find(r=>r.method==='turn/start').params.threadId,thread);
  assert.equal(calls.some(r=>r.method==='thread/start'),false);
  state=await f.worker.command(await f.worker.read(),'ask',ask);
  await f.owner.command(state,'answer',{id:'question',optionId:'a',requestId:'answer-push'});
  state=await f.worker.read();assert.equal(state.questions[0].status,'answered');assert.equal(state.messages[1].destination,thread);
  assert.equal(state.messages[1].requestId,'answer-push');
  assert.equal(await deliverOne(cfg),true);
  state=await f.owner.read();assert.equal(state.messages[1].status,'accepted');assert.equal(state.questions[0].status,'answered');
  const methods=[];
  const peer={request:async(method,params)=>{methods.push(method);if(method==='thread/read')return {thread:{id:thread,turns:[{id:'active',status:'inProgress'}]}};if(method==='turn/steer'){assert.equal(params.expectedTurnId,'active');return {turnId:'active'};}return {};}};
  assert.equal(await sendCodex(peer,thread,'steer','message-id'),'active');assert.equal(methods.includes('turn/start'),false);
});

test('Claude cloud adapter requires account sign-in and passes text on stdin to the exact existing session', async t => {
  const {sendClaude}=await import('../plugins/sdd-ship/session-hub/push.mjs');
  const {writeFile,chmod}=await import('node:fs/promises');const f=await fixture(t);
  const executable=join(f.directory,'claude-fixture');const received=join(f.directory,'message.json');
  const script=method=>'#!'+process.execPath+'\n'+`
import {writeFileSync} from 'node:fs';
if(process.argv[2]==='auth')console.log(JSON.stringify({loggedIn:true,authMethod:${JSON.stringify(method)},apiProvider:'firstParty'}));
else {let raw='';for await(const b of process.stdin)raw+=b;writeFileSync(${JSON.stringify(received)},JSON.stringify({args:process.argv.slice(2),text:raw}));console.log('Message queued');}
`;
  await writeFile(executable,script('api_key'));await chmod(executable,0o700);
  await assert.rejects(sendClaude(executable,'session_existing','hello'),/claude-login-required/);
  await assert.rejects(readFile(received),/ENOENT/);
  await writeFile(executable,script('oauth'));await chmod(executable,0o700);
  assert.equal(await sendClaude(executable,'https://claude.ai/code/session_existing','private message'),'session_existing');
  const observed=JSON.parse(await readFile(received,'utf8'));assert.deepEqual(observed.args,['-p','--cloud','session_existing']);assert.equal(observed.text,'private message');
  await assert.rejects(sendClaude(executable,'https://attacker.test/session_x','hello'),/unsupported-conversation/);
});
