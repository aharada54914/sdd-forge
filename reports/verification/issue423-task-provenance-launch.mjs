#!/usr/bin/env node
// One fresh, independent provenance reviewer per invocation. No model turn before reservation.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawn, spawnSync} from 'node:child_process';

const root = '/Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge';
const feature = 'sdd-domain-multitarget';
const attempt = 5;
const roleLetter = process.argv[2];
if (!['a', 'b'].includes(roleLetter)) throw Error('usage: node issue423-task-provenance-launch.mjs <a|b>');
const role = `task-reviewer-${roleLetter}`;
const round = `reports/task-review/${feature}/attempt-${attempt}/round-1`;
const output = path.join(root, round);
const ledgerPath = 'reports/review-context/identity-ledger.json';
const cli = '/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex';
const sha = value => crypto.createHash('sha256').update(value).digest('hex');
const read = relative => fs.readFileSync(path.join(root, relative));
const assert = (ok, message) => { if (!ok) throw Error(message); };
const hex = /^[a-f0-9]{64}$/;
const writeNew = (file, data) => fs.writeFileSync(file, JSON.stringify(data, null, 2) + '\n', {flag: 'wx', mode: 0o600});

function checkedCommand(args) {
  const result = spawnSync('rtk', ['proxy', ...args], {cwd: root, encoding: 'utf8', timeout: 60000, maxBuffer: 1024 * 1024});
  assert(!result.error && result.status === 0, `command failed/rejected (${args[0]} ${args[1]}, exit=${result.status}, error=${result.error?.code || 'none'}); no alternate executor`);
  return result.stdout.trim();
}

function inputs() {
  const precheck = JSON.parse(read(`${round}/precheck-result.json`));
  assert(precheck.feature === feature && precheck.attempt === attempt && precheck.round === 1 && precheck.tasks_sha256_form === 'normalized' && hex.test(precheck.tasks_sha256), 'wrong precheck identity/form');
  const paths = [
    'plugins/sdd-review-loop/references/reviewer-calibration.md',
    ...(roleLetter === 'a' ? [`${round}/dependency-graph.json`] : [
      'plugins/sdd-quality-loop/references/risk-classification-policy.md',
      'plugins/sdd-quality-loop/references/risk-gate-matrix.md',
      `${round}/integrated-summary.json`
    ]),
    `${round}/precheck-result.json`,
    ...['acceptance-tests.md','design.md','frontend-spec.md','infra-spec.md','requirements.md','security-spec.md','tasks.md','traceability.md','ux-spec.md'].map(name => `specs/${feature}/${name}`)
  ];
  if (roleLetter === 'b') {
    const s = JSON.parse(read(`${round}/integrated-summary.json`));
    assert(s.schema === 'integrated-summary/v1' && s.attempt === attempt && s.round === 1 && Array.isArray(s.reviewer_a_check_ids) && s.reviewer_a_check_ids.length === 14, 'invalid A summary');
    assert(['reviewer_a_fail_count','reviewer_a_pass_count','reviewer_a_skip_count'].every(k => Number.isSafeInteger(s[k]) && s[k] >= 0) && s.reviewer_a_fail_count+s.reviewer_a_pass_count+s.reviewer_a_skip_count === 14, 'invalid A counts');
    assert(Object.keys(s).sort().join(',') === ['schema','round','attempt','reviewer_a_check_ids','reviewer_a_fail_count','reviewer_a_pass_count','reviewer_a_skip_count','generated_at'].sort().join(','), 'A summary extra fields');
  }
  return paths.map(p => ({path: p, sha256: p === `specs/${feature}/tasks.md` ? (read(p), precheck.tasks_sha256) : sha(read(p))}));
}

class Server {
  constructor() {
    this.child = spawn('rtk', ['proxy', cli, 'app-server', '--listen', 'stdio://'], {cwd: root, stdio: ['pipe','pipe','ignore']});
    this.pending = new Map(); this.events = []; this.waiters = []; this.next = 1; this.buffer = ''; this.malformed = 0;
    this.child.stdout.on('data', c => this.consume(c));
    this.child.on('error', e => this.abort(`app-server spawn error (${e.code || 'unknown'})`));
    this.child.on('exit', (c,s) => this.abort(`app-server exited (code=${c},signal=${s})`));
  }
  abort(message) {
    if (this.closed) return; this.closed = true;
    for (const p of this.pending.values()) p.reject(Error(message)); this.pending.clear();
    for (const w of this.waiters) w.reject(Error(message)); this.waiters = [];
  }
  consume(chunk) {
    this.buffer += chunk;
    let end;
    while ((end = this.buffer.indexOf('\n')) >= 0) {
      const line = this.buffer.slice(0,end); this.buffer = this.buffer.slice(end+1);
      let value; try { value = JSON.parse(line); } catch { this.malformed++; continue; }
      if (value.id === undefined) { const waiter = this.waiters.shift(); waiter ? waiter.resolve(value) : this.events.push(value); continue; }
      const p = this.pending.get(value.id); if (!p) continue; this.pending.delete(value.id);
      value.error ? p.reject(Error(`app-server ${p.method} error code=${value.error.code}; malformed=${this.malformed}`)) : p.resolve(value.result);
    }
  }
  send(method, params) {
    assert(!this.closed, 'app-server closed'); const id = this.next++;
    return new Promise((resolve,reject) => {
      const timer = setTimeout(() => {this.pending.delete(id); reject(Error(`${method} timed out`));},30000);
      this.pending.set(id,{method,resolve:v=>{clearTimeout(timer);resolve(v);},reject:e=>{clearTimeout(timer);reject(e);}});
      this.child.stdin.write(JSON.stringify({id,method,params})+'\n');
    });
  }
  notify(method) {this.child.stdin.write(JSON.stringify({method})+'\n');}
  event() {
    if (this.events.length) return Promise.resolve(this.events.shift());
    assert(!this.closed,'app-server closed');
    return new Promise((resolve,reject) => {
      const w = {resolve:v=>{clearTimeout(timer);resolve(v);},reject:e=>{clearTimeout(timer);reject(e);}};
      const timer = setTimeout(()=>{this.waiters=this.waiters.filter(x=>x!==w);reject(Error(`turn notification timed out; malformed=${this.malformed}`));},20*60*1000);
      this.waiters.push(w);
    });
  }
  close(){this.abort('closed by launcher');this.child.stdin.end();this.child.kill();}
}

function receipt(line, manifest) {
  const m = /^REVIEW_CONTEXT_OK ([0-9a-f]{64}) sequence=(\d+) previous_record_sha256=([0-9a-f]{64}|-) pre_append_tip_sequence=(\d+) identity_unique=yes$/.exec(line);
  assert(m,'incomplete validator receipt');
  assert(m[1] === sha(`${manifest.sequence}|${manifest.stage}|${manifest.role}|${manifest.run_id}|${manifest.host_session_id}|${manifest.previous_record_sha256}`),'receipt identity/hash mismatch');
  assert(Number(m[2])===manifest.sequence && m[3]===manifest.previous_record_sha256 && Number(m[4])===manifest.sequence-1,'receipt chain mismatch');
  return {record_sha256:m[1],sequence:manifest.sequence,previous_record_sha256:m[3],identity_unique:true};
}

async function run() {
  const lock = path.join(output,`reviewer-${roleLetter}-native-launch.lock`);
  writeNew(lock,{pid:process.pid,startedAt:new Date().toISOString(),role});
  const entries = fs.readdirSync(output);
  assert(!entries.some(n=>n===`reviewer-${roleLetter}.json`||n.startsWith(`reserved-${roleLetter}-`)||n.startsWith(`native-turn-${roleLetter}-`)),'reviewer output or reservation already exists');
  assert(!fs.readdirSync(path.join(root,'reports/review-context')).some(n=>n.startsWith(`${feature}-task-a${attempt}r1-${roleLetter}-`)&&n.endsWith('-invocation.json')),'invocation exists; duplicate forbidden');
  checkedCommand(['bash','plugins/sdd-review-loop/scripts/task-review-precheck.sh',feature,String(attempt),'1','--verify-inputs']);
  const allowed = inputs();
  const roleText = read(`plugins/sdd-review-loop/agents/${role}.md`).toString().replace(/^---\n[\s\S]*?\n---\n/,'').replace(/^<!-- x-sdd-effort: [^\n]* -->\n/,'');
  assert(roleText.includes('REVIEW_CONTEXT_OK') && roleText.includes(roleLetter==='a'?'Structural Coverage Reviewer':'Quality and Risk Reviewer'),'invalid role instructions');
  const server = new Server();
  try {
    await server.send('initialize',{clientInfo:{name:'issue423-task-provenance',version:'1'},capabilities:{experimentalApi:true}}); server.notify('initialized');
    const start = await server.send('thread/start',{cwd:root,sandbox:'read-only',approvalPolicy:'never',ephemeral:true,model:'gpt-5.6-sol',allowProviderModelFallback:false});
    const id = start?.thread?.id;
    assert(typeof id==='string'&&id.length>0,'missing host thread ID');
    const reread = await server.send('thread/read',{threadId:id,includeTurns:false});
    assert(start.thread.sessionId===id && start.thread.status?.type==='idle' && start.thread.preview==='' && start.thread.parentThreadId==null && start.thread.forkedFromId==null && start.thread.ephemeral===true && start.thread.cwd===root,'thread is not empty root');
    assert(start.sandbox?.type==='readOnly' && start.sandbox.networkAccess===false && start.approvalPolicy==='never' && start.thread.model==='gpt-5.6-sol','host model/sandbox mismatch');
    assert(reread?.thread?.id===id && reread.thread.status?.type==='idle' && server.malformed===0,'thread changed before reserve');
    const ledgerBytes=read(ledgerPath), ledger=JSON.parse(ledgerBytes), tip=ledger.records?.at(-1);
    assert(ledger.schema==='review-identity-ledger/v1'&&Number.isSafeInteger(tip?.sequence)&&hex.test(tip.record_sha256),'bad ledger');
    const manifest={schema:'review-context-invocation/v2',stage:'task',feature,role,run_id:id,host_session_id:id,input_mode:'file-manifest',fallback_mode:'none',read_only:true,identity_ledger_path:ledgerPath,identity_ledger_sha256:sha(ledgerBytes),previous_record_sha256:tip.record_sha256,sequence:tip.sequence+1,allowed_input_manifest:allowed};
    const manifestFile=path.join(root,'reports/review-context',`${feature}-task-a${attempt}r1-${roleLetter}-${id}-invocation.json`);
    writeNew(manifestFile,manifest);
    const line=checkedCommand(['bash','plugins/sdd-quality-loop/scripts/validate-review-context-set.sh',manifestFile,root,'--reserve']);
    const proof=receipt(line,manifest);
    writeNew(path.join(output,`reserved-${roleLetter}-${id}.json`),{host_thread_id:id,host_session_id:id,role,manifest_path:manifestFile,validator_receipt:proof,turn_started:false});
    const prompt=`${roleText}\n\nInvocation: stage=task, feature=${feature}, attempt=${attempt}, round=1, role=${role}. Manifest: ${manifestFile}. The caller ran the original validator with --reserve and verified this complete response:\n${line}\n\nUse ONLY allowed_input_manifest. This is an independent post-implementation provenance re-review. ${roleLetter==='b'?'integrated-summary.json contains reviewer A IDs/counts only; never read reviewer-a.json or any peer raw output. ':''}For specs/${feature}/tasks.md ONLY, tasks_sha256_form=normalized: compare the manifest digest via original precheck/validator normalized form, NOT raw SHA-256. It changes Task-Review-Status to Pending, Approval to Draft, Status to Planned, and deletes Second Approval lines. Other inputs use raw SHA-256. A raw-versus-normalized difference is not a mismatch. Reject any applicable digest mismatch before substantive review. Emit only canonical role JSON. Do not read previous reviewer outputs or identity ledger.`;
    let turn,complete; const messages=new Map();
    try {
      turn=await server.send('turn/start',{threadId:id,input:[{type:'text',text:prompt}],model:'gpt-5.6-sol',effort:'high'});
      assert(typeof turn?.turn?.id==='string','turn/start returned no turn ID');
      process.stdout.write(JSON.stringify({status:'FIRST_TURN_STARTED',host_thread_id:id,turn_id:turn.turn.id,manifest:manifestFile})+'\n');
      while(!complete) {
        const e=await server.event();
        if(!['item/completed','turn/completed'].includes(e.method))continue;
        assert(e.params?.threadId===id && (e.params.turnId??e.params.turn?.id)===turn.turn.id,'event crossed thread/turn boundary');
        if(e.method==='item/completed') {if(e.params.item?.type==='agentMessage'&&typeof e.params.item.text==='string')messages.set(e.params.item.id,e.params.item.text);}
        else {for(const x of e.params.turn?.items||[])if(x?.type==='agentMessage'&&typeof x.text==='string')messages.set(x.id,x.text);complete=e.params;}
      }
      writeNew(path.join(output,`native-turn-${roleLetter}-${id}.json`),{threadId:id,turnId:turn.turn.id,status:complete.turn.status,agentMessages:[...messages].map(([itemId,text])=>({itemId,text})),completedTurn:complete.turn,malformed_stdout_lines:server.malformed});
      assert(complete.turn.status==='completed'&&messages.size>0&&server.malformed===0,'turn completed without verified output');
      process.stdout.write(JSON.stringify({status:'TURN_COMPLETED',host_thread_id:id,turn_id:turn.turn.id,native_turn:`${round}/native-turn-${roleLetter}-${id}.json`})+'\n');
    } catch(e) {
      writeNew(path.join(output,`native-turn-aborted-${roleLetter}-${id}.json`),{threadId:id,turnId:turn?.turn?.id??null,status:'ABORTED_OR_UNVERIFIED',reason:e.message,agentMessages:[...messages].map(([itemId,text])=>({itemId,text})),malformed_stdout_lines:server.malformed});
      throw e;
    }
  } finally {server.close();}
}

run().catch(e=>{process.stderr.write(`STOP: ${e.message}\n`);process.exitCode=1;});
