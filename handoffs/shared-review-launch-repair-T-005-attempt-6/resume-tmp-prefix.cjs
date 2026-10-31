const fs = require('fs');
const cp = require('child_process');
const path = require('path');
const base = __dirname;
if (process.argv.length > 3 || (process.argv[2] && process.argv[2] !== '--resume-task')) throw Error('unsupported argument');
const resumeTask = process.argv[2] === '--resume-task';
const request = JSON.parse(fs.readFileSync(path.join(base, 'native-thread-start.json')));
request.method = 'thread/resume';
request.params.threadId = '01a11dad-e8e2-7e30-b591-b1d3909325e4';
delete request.params.ephemeral;
const tmp = path.join(base, 'output/tmp');
const prefix = path.join(tmp, 'zsh');
request.params.config['shell_environment_policy.set.TMPPREFIX'] = prefix;
const env = {...process.env, TMPDIR:tmp, TMP:tmp, TEMP:tmp, TMPPREFIX:prefix};
const args = ['app-server'];
for (const [key,value] of Object.entries(request.params.config)) args.push('-c', key+'='+JSON.stringify(value));
const log = path.join(base, 'tmp-prefix-resume-'+Date.now());
fs.writeFileSync(log+'.request.json', JSON.stringify(request,null,2)+'\n', {flag:'wx'});
const child = cp.spawn('/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex',args,{env,stdio:['pipe','pipe','pipe']});
const send = value => child.stdin.write(JSON.stringify(value)+'\n');
let pending = '';
child.on('error', error=>{console.error(error);process.exitCode=1;});
child.stderr.on('data',chunk=>fs.appendFileSync(log+'.stderr.log',chunk));
child.stdout.on('data',chunk=>{
  fs.appendFileSync(log+'.jsonl',chunk);
  pending += chunk;
  let end;
  while ((end=pending.indexOf('\n'))>=0) {
    const line=pending.slice(0,end);pending=pending.slice(end+1);
    let m;try{m=JSON.parse(line);}catch{continue;}
    if(m.error){console.error(JSON.stringify(m));child.kill();process.exitCode=1;return;}
    if(m.id===1){send({method:'initialized'});send(request);}
    if(m.id===3){
      const r=m.result;
      console.log(JSON.stringify({cwd:r.cwd,sandbox:r.sandbox,approvalPolicy:r.approvalPolicy,model:r.model}));
      if(r.cwd!==path.join(base,'output') || r.approvalPolicy!=='never' || r.sandbox?.type!=='workspaceWrite' || r.sandbox.networkAccess!==false || !r.sandbox.excludeSlashTmp || !r.sandbox.excludeTmpdirEnvVar || r.sandbox.writableRoots.length) {child.kill();throw Error('sandbox mismatch');}
      send({id:4,method:'mcpServerStatus/list',params:{threadId:request.params.threadId,limit:100}});
    }
    if(m.id===4){
      if(m.result.nextCursor!==null || m.result.data.some(x=>x.runtimeStatus!=='disabled'||Object.keys(x.tools).length)){child.kill();throw Error('MCP not disabled');}
      const text='Launch-preparation repair only: parent has set TMPPREFIX='+prefix+' in child and shell environment policy, without expanding sandbox permissions. Keep original refusal as evidence. In the same zsh executor, login=false, first run the read-only builtin typeset -p TMPPREFIX TMPDIR TMP TEMP. Then run rtk proxy python3 with a here-document that only prints TMP_PREFIX_HEREDOC_OK. Do not edit files, run tests, use other executors, or resume task work yet. Stop on any refusal. Report exact command results; this is not a formal review or test verdict.';
      const turn = resumeTask ? JSON.parse(fs.readFileSync(path.join(base, 'turn-start.json'))) : {id:5,method:'turn/start',params:{threadId:request.params.threadId,input:[{type:'text',text,text_elements:[]}]}};
      if (turn.params.threadId !== request.params.threadId) throw Error('task thread mismatch');
      if (resumeTask) turn.params.input.push({type:'text',text:'Resume the original admitted task now. The same-thread TMPPREFIX diagnostic succeeded with TMP_PREFIX_HEREDOC_OK. TMPPREFIX now points to output/tmp/zsh; all sandbox bounds remain unchanged. Preserve the original refusal and diagnostic as history, not test proof. No production edits; perform the original bounded verification and report.',text_elements:[]});
      send(turn);
    }
    if(m.method==='item/completed' && ['commandExecution','agentMessage'].includes(m.params?.item?.type))console.log(JSON.stringify(m.params.item));
    if(m.method==='turn/completed'){console.log(JSON.stringify(m));child.stdin.end();child.kill();}
  }
});
child.on('exit',()=>{});
send({id:1,method:'initialize',params:{clientInfo:{name:'sdd_t005_tmp_prefix_repair',version:'1'},capabilities:{experimentalApi:true}}});
