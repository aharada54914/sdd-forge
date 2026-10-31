// Reuses T003's app-server identity -> manifest -> snapshot -> admission -> turn protocol.
'use strict';
const fs = require('fs'), path = require('path'), cp = require('child_process'), crypto = require('crypto');
const base = __dirname, root = path.resolve(base, '../..');
const output = path.join(base, 'output'), snapshot = path.join(base, 'snapshot');
const hash = b => crypto.createHash('sha256').update(b).digest('hex');
const save = (name, value) => fs.writeFileSync(path.join(base, name), JSON.stringify(value, null, 2)+'\n', {flag:'wx'});
const sourcePaths = fs.readFileSync(path.join(base, 'inputs.txt'), 'utf8').trim().split('\n');
function entry(p) {
  if(path.isAbsolute(p) || p.split('/').some(x=>!x || x==='.' || x==='..')) throw Error('unsafe input '+p);
  const full=path.join(root,p), st=fs.lstatSync(full);
  if(!st.isFile() || fs.realpathSync(full)!==full) throw Error('noncanonical input '+p);
  return {path:p,sha256:hash(fs.readFileSync(full)),mode:st.mode&0o777};
}
function run(command, cwd=root) {
  const r=cp.spawnSync('rtk',['proxy',...command],{cwd,encoding:'utf8',env:{...process.env,TMPDIR:path.join(output,'tmp'),TMP:path.join(output,'tmp'),TEMP:path.join(output,'tmp')}});
  if(r.status!==0) throw Error(JSON.stringify({command,exit:r.status,stdout:r.stdout,stderr:r.stderr}));
  return {command:['rtk','proxy',...command],cwd,exit:r.status,stdout:r.stdout,stderr:r.stderr};
}
if(new Set(sourcePaths).size!==sourcePaths.length) throw Error('duplicate inputs');
sourcePaths.forEach(entry);
if(process.argv[2]==='--check') { console.log('T004 explicit inputs: '+sourcePaths.length+' regular canonical files; no launch'); process.exit(0); }
if(process.argv[2] && process.argv[2]!=='--cache') throw Error('usage: node prepare-native.cjs [--check|--cache]');
if(fs.existsSync(path.join(base,'native-thread-start-result.json'))) throw Error('native identity exists; never relaunch');
fs.mkdirSync(path.join(output,'tmp'),{recursive:true});
if(process.argv[2]==='--cache') {
  // Populate only task-local cache; native work starts separately without node_modules.
  const dep=path.join(output,'dependency-cache');
  fs.mkdirSync(dep,{recursive:true});
  for(const name of ['package.json','package-lock.json']) fs.copyFileSync(path.join(root,'mcp/ci-mcp',name),path.join(dep,name),fs.constants.COPYFILE_EXCL);
  save('dependency-cache-preparation.json',run(['npm','ci','--prefix',dep,'--ignore-scripts','--cache',path.join(output,'npm-cache')]));
  console.log('T004 task-local npm cache prepared; no native launch'); process.exit(0);
}
if(!fs.existsSync(path.join(base,'dependency-cache-preparation.json'))) throw Error('run --cache before native launch; no owner node_modules fallback');
const priorBase=path.join(root,'handoffs/shared-review-launch-repair-T-002-attempt-4');
const request=JSON.parse(fs.readFileSync(path.join(priorBase,'native-thread-start.json')));
request.params.cwd=output;
for(const key of ['TMPDIR','TMP','TEMP','TMPPREFIX']) request.params.config['shell_environment_policy.set.'+key]=path.join(output,'tmp',key==='TMPPREFIX'?'zsh':'');
save('native-thread-start.json',request);
const before=sourcePaths.map(entry);
const git=run(['git','rev-parse','HEAD']);
if(git.stdout.trim()!=='9ce19abe90df0cb83e385f96855e4843318a8807') throw Error('unexpected HEAD');
save('before-byte-inventory.json',{schema:'t004-preparation-inputs/v1',head:git.stdout.trim(),entries:before});
// Explicit topology already recorded by T003; no recursive repository discovery.
const topology=JSON.parse(fs.readFileSync(path.join(root,'handoffs/shared-review-launch-repair-T-003-attempt-2/registry-topology.json')));
for(const p of topology.directories) if(path.isAbsolute(p)||p.split('/').some(x=>!x||x==='.'||x==='..')||!fs.statSync(path.join(root,p)).isDirectory()) throw Error('invalid topology '+p);
save('registry-topology.json',topology);
const args=['app-server'];
for(const [key,value] of Object.entries(request.params.config)) args.push('-c',key+'='+JSON.stringify(value));
const child=cp.spawn('/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex',args,{env:{...process.env,TMPDIR:path.join(output,'tmp'),TMP:path.join(output,'tmp'),TEMP:path.join(output,'tmp')},stdio:['pipe','pipe','pipe']});
const send=value=>child.stdin.write(JSON.stringify(value)+'\n');
let pending='',session;
function prepare() {
  for(const e of before) if(JSON.stringify(entry(e.path))!==JSON.stringify(e)) throw Error('source changed since preparation: '+e.path);
  const paths=[...sourcePaths,...['inputs.txt','native-instructions.md','before-byte-inventory.json','registry-topology.json'].map(p=>path.relative(root,path.join(base,p)))];
  const entries=paths.sort().map(entry);
  save('source-modes.json',{entries});
  const prior=JSON.parse(fs.readFileSync(path.join(priorBase,'manifest.json')));
  const manifest={...prior,task_id:'T-004',run_id:'T-004-'+session,session_id:session,agent_instance_id:session,allowed_inputs:entries.map(({path,sha256})=>({path,sha256})),allowed_outputs:[path.relative(root,output)+'/']};
  const mode=entry(path.relative(root,path.join(base,'source-modes.json')));
  manifest.allowed_inputs.push({path:mode.path,sha256:mode.sha256});
  save('manifest.json',manifest);
  const admission=[run(['bash','plugins/sdd-implementation/scripts/prepare-task-snapshot.sh','--manifest',path.join(base,'manifest.json'),'--repo-root',root,'--snapshot-root',snapshot]),run(['bash','plugins/sdd-implementation/scripts/validate-task-input-manifest.sh','--manifest',path.join(base,'manifest.json'),'--snapshot-root',snapshot,'--expected-task','T-004'])];
  save('admission-results.json',admission);
  const instructionPath=path.join(snapshot,path.relative(root,path.join(base,'native-instructions.md')));
  const prompt=`Fresh native implementation context. Session and agent identity ${session}; Run ID T-004-${session}; Task Attempt Count 1. Manifest ${path.join(base,'manifest.json')} SHA256 ${hash(fs.readFileSync(path.join(base,'manifest.json')))}; immutable snapshot ${snapshot}; sole output root ${output}. Snapshot builder and manifest validator succeeded: TASK_INPUT_OK. Read and obey the manifest-admitted instructions ${instructionPath}. Start by verifying all admitted hashes, then read the governing instructions. Do not read launcher history or owner files. Scoped npm cache is ${path.join(output,'npm-cache')}.`;
  const turn={id:5,method:'turn/start',params:{threadId:session,input:[{type:'text',text:prompt}],effort:'high'}};
  save('turn-start.json',turn); send(turn); console.log('T004_NATIVE_LAUNCHED '+session);
}
child.stdout.on('data',chunk=>{
  fs.appendFileSync(path.join(base,'native-stdout.jsonl'),chunk);pending+=chunk;
  let i;while((i=pending.indexOf('\n'))>=0){
    const line=pending.slice(0,i);pending=pending.slice(i+1);let m;try{m=JSON.parse(line)}catch{continue}
    if(m.id===1){if(m.error)throw Error(JSON.stringify(m));send({method:'initialized'});send(request)}
    if(m.id===3){if(!m.result)throw Error(JSON.stringify(m));session=m.result.thread.id;if(typeof session!=='string'||!session)throw Error('missing native identity');save('native-thread-start-result.json',m);send({id:4,method:'mcpServerStatus/list',params:{threadId:session,limit:100}})}
    if(m.id===4){save('effective-mcp-status.json',m);if(!m.result||m.result.nextCursor!==null||m.result.data.some(x=>x.runtimeStatus!=='disabled'||Object.keys(x.tools).length))throw Error('MCP not disabled');prepare()}
    if(m.id===5&&m.error)throw Error(JSON.stringify(m));
    if(m.method==='turn/completed'){save('turn-completed.json',m);console.log(JSON.stringify(m));child.stdin.end()}
  }
});
child.stderr.on('data',chunk=>fs.appendFileSync(path.join(base,'native-stderr.log'),chunk));
child.on('exit',code=>process.exit(code??1));
send({id:1,method:'initialize',params:{clientInfo:{name:'sdd_t004_admission',version:'1'},capabilities:{experimentalApi:true}}});
