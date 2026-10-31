const fs = require('fs'), path = require('path'), cp = require('child_process'), crypto = require('crypto');
const base = __dirname, root = path.resolve(base, '../..');
const output = path.join(base, 'output'), snapshot = path.join(base, 'snapshot');
const hash = b => crypto.createHash('sha256').update(b).digest('hex');
const save = (name, value) => fs.writeFileSync(path.join(base, name), JSON.stringify(value, null, 2)+'\n', {flag:'wx'});
if (fs.existsSync(path.join(base, 'native-thread-start-result.json'))) throw Error('native identity already exists; do not relaunch');
fs.mkdirSync(path.join(output, 'tmp'), {recursive:true});
const request = JSON.parse(fs.readFileSync(path.join(root, 'handoffs/shared-review-launch-repair-T-002-attempt-4/native-thread-start.json')));
request.params.cwd = output;
for (const key of ['TMPDIR','TMP','TEMP','TMPPREFIX']) request.params.config['shell_environment_policy.set.'+key] = path.join(output, 'tmp', key==='TMPPREFIX'?'zsh':'');
save('native-thread-start.json', request);
const args = ['app-server'];
for (const [key,value] of Object.entries(request.params.config)) args.push('-c', key+'='+JSON.stringify(value));
const child = cp.spawn('/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex', args, {env:{...process.env,TMPDIR:path.join(output,'tmp'),TMP:path.join(output,'tmp'),TEMP:path.join(output,'tmp')},stdio:['pipe','pipe','pipe']});
const send = value => child.stdin.write(JSON.stringify(value)+'\n');
let pending = '', session;
function prepare() {
  const prior = JSON.parse(fs.readFileSync(path.join(root,'handoffs/shared-review-launch-repair-T-002-attempt-4/manifest.json')));
  const pinned = JSON.parse(fs.readFileSync(path.join(base,'before-byte-inventory.json')));
  const paths = pinned.entries.map(e=>e.path);
  for (const e of pinned.entries) {
    const full=path.join(root,e.path), st=fs.lstatSync(full);
    if(!st.isFile() || fs.realpathSync(full)!==full || hash(fs.readFileSync(full))!==e.sha256 || (st.mode&0o777)!==e.mode) throw Error('source changed since preparation: '+e.path);
  }
  paths.push(path.relative(root,path.join(base,'registry-topology.json')));
  paths.push(path.relative(root,path.join(base,'before-byte-inventory.json')));
  const entries=[...new Set(paths)].sort().map(p=>{const full=path.join(root,p),st=fs.lstatSync(full);if(!st.isFile()||fs.realpathSync(full)!==full)throw Error('unsafe source '+p);return {path:p,sha256:hash(fs.readFileSync(full)),mode:st.mode&0o777}});
  save('source-modes.json',{entries});
  const manifest={...prior,task_id:'T-003',run_id:'T-003-'+session,session_id:session,agent_instance_id:session,allowed_inputs:entries.map(({path,sha256})=>({path,sha256})),allowed_outputs:[path.relative(root,output)+'/']};
  const modePath=path.relative(root,path.join(base,'source-modes.json'));
  manifest.allowed_inputs.push({path:modePath,sha256:hash(fs.readFileSync(path.join(base,'source-modes.json')))});
  save('manifest.json',manifest);
  const commands=[['bash','plugins/sdd-implementation/scripts/prepare-task-snapshot.sh','--manifest',path.join(base,'manifest.json'),'--repo-root',root,'--snapshot-root',snapshot],['bash','plugins/sdd-implementation/scripts/validate-task-input-manifest.sh','--manifest',path.join(base,'manifest.json'),'--snapshot-root',snapshot,'--expected-task','T-003']];
  const results=commands.map(command=>{const r=cp.spawnSync('rtk',['proxy',...command],{cwd:root,encoding:'utf8'});if(r.status!==0)throw Error(r.stdout+r.stderr);return {command:['rtk','proxy',...command],exit:r.status,stdout:r.stdout,stderr:r.stderr}});
  save('admission-results.json',results);
  const prompt=`Use the admitted implement-task skill for Approved shared-review-launch-repair T-003. Fresh native implementation context. Session and agent identity ${session}; Run ID T-003-${session}; Task Attempt Count 2; model gpt-6-astra high. Manifest ${path.join(base,'manifest.json')} SHA256 ${hash(fs.readFileSync(path.join(base,'manifest.json')))}; immutable snapshot ${snapshot}; sole output root ${output}. Caller executed snapshot builder and manifest validator: TASK_INPUT_OK.
Read only manifest and explicit snapshot inputs; no owner reads, memories, history, network, agents, ledger, Git or status operations. Verify every input hash before substantive reads. Read admitted AGENTS, implement-task and three references/template, task/spec Must Read and contracts. Create output/work using only enumerated source inputs, verify source-modes and restore authorized modes. Recreate exactly registry-topology directories under work; then run admitted scripts/check-sdd-structure.sh on work for this feature. No recursive source copying or source discovery. All scratch and temporary files stay in output/tmp. Native cwd output, shell login=false, all shell commands through rtk proxy.
Implement only T-003 REQ-006/AC-006. Preserve existing eight candidate registrations and unrelated bytes. Allowed candidate changes: tests/host-review-preflight.tests.py and, only if needed within already-approved six-entrypoint scope, guard-invariants.json, generate-guard-invariants.py and its four generated modules. Never modify runtime guard implementations, six entrypoints, CI/run-all, spec/status, or unrelated files. New implementation report and exact evidence belong under output/work/reports/implementation/shared-review-launch-repair/T-003.md and output/work/specs/shared-review-launch-repair/verification/T-003/. Status transitions, independent review and formal quality gate belong to parent.
Before implementation persist high-risk preflight field/counterpart/failing-mismatch table. Add TEST-011a-f six-path write-denial/read-allowance across Python, Node, PowerShell and Bash dispatcher; TEST-012a canonical-only, 012b generator-only, 012c each stale projection, 012d unchanged unrelated membership; TEST-013 actual workflow transport-registration removal in disposable copy. Use real admitted .github/workflows/test.yml. Generator --check does not inspect CI registration; regression must actually reject that omission. No new dependency. Existing host suite regressions remain. Exercise available runtimes; unavailable/native Windows checks are explicit NOT RUN, never implied PASS.
Existing registration precedes this task. Capture intact baseline, then clearly labeled isolated mutation RED and restored-byte GREEN plus rollback before/mutated/restored hashes. Do not misrepresent post-hoc mutation as original production RED or extend RT-20261009-001's T001-only exception. Preserve original eight additions and all unrelated invariant keys. Tests must distinguish missing entrypoints from broken unrelated fixture setup. Run focused suite, generator --check and admitted guard-parity regression; record exact command/cwd/exit/full stdout+stderr. No live reviewer or ledger writes.
Produce complete implementation-report/v2 with bare Run ID and Task Attempt Count, native identity, absolute output Scratch Root, actual spec_revision/input/source/test/output hashes, TEST mapping, mismatch results and explicit limitations. Declare every intended delivered source/evidence file in Outputs, excluding report self-hash. Validate via admitted validate-implementation-report.sh. Create output/delivery-index.json with exact delivered paths/hashes and before/after source hashes. Native execution of fixture guards is not installed-host activation or native Windows evidence. Independent diff review, formal quality, CI, merge remain NOT RUN. If any input is missing or a protected operation refused, stop and report exact path; do not change executor or read outside admission. You implement, not evaluate.`;
  const turn={id:5,method:'turn/start',params:{threadId:session,input:[{type:'text',text:prompt}],effort:'high'}};
  save('turn-start.json',turn);send(turn);console.log('T003_NATIVE_LAUNCHED '+session);
}
child.stdout.on('data',chunk=>{fs.appendFileSync(path.join(base,'native-stdout.jsonl'),chunk);pending+=chunk;let i;while((i=pending.indexOf('\n'))>=0){const line=pending.slice(0,i);pending=pending.slice(i+1);let m;try{m=JSON.parse(line)}catch{continue}if(m.id===1){send({method:'initialized'});send(request)}if(m.id===3){if(!m.result)throw Error(JSON.stringify(m));session=m.result.thread.id;save('native-thread-start-result.json',m);send({id:4,method:'mcpServerStatus/list',params:{threadId:session,limit:100}})}if(m.id===4){save('effective-mcp-status.json',m);if(!m.result||m.result.nextCursor!==null||m.result.data.some(x=>x.runtimeStatus!=='disabled'||Object.keys(x.tools).length))throw Error('MCP not disabled');prepare()}if(m.id===5&&m.error)throw Error(JSON.stringify(m));if(m.method==='turn/completed'){save('turn-completed.json',m);console.log(JSON.stringify(m));child.stdin.end();}}});
child.stderr.on('data',chunk=>fs.appendFileSync(path.join(base,'native-stderr.log'),chunk));
child.on('exit',code=>process.exit(code??1));
send({id:1,method:'initialize',params:{clientInfo:{name:'sdd_t003_admission',version:'1'},capabilities:{experimentalApi:true}}});
