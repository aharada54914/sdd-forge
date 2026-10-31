const fs = require('fs'), path = require('path'), cp = require('child_process');
const base = __dirname;
const original = JSON.parse(fs.readFileSync(path.join(base, 'native-thread-start.json')));
const threadId = JSON.parse(fs.readFileSync(path.join(base, 'native-thread-start-result.json'))).result.thread.id;
const save = (name, value) => fs.writeFileSync(path.join(base, name), JSON.stringify(value, null, 2)+'\n', {flag:'wx'});
if (fs.existsSync(path.join(base, 'resume-start.json'))) throw Error('resume already started; inspect existing run');
const args = ['app-server'];
for (const [key,value] of Object.entries(original.params.config)) args.push('-c', key+'='+JSON.stringify(value));
const child = cp.spawn('/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex', args, {env:{...process.env,TMPDIR:path.join(base,'output/tmp'),TMP:path.join(base,'output/tmp'),TEMP:path.join(base,'output/tmp')},stdio:['pipe','pipe','pipe']});
const send = value => child.stdin.write(JSON.stringify(value)+'\n');
const params = {...original.params, threadId};
delete params.ephemeral;
const request = {id:3,method:'thread/resume',params};
save('resume-start.json', request);
let pending = '';
child.stdout.on('data',chunk=>{
  fs.appendFileSync(path.join(base,'resume-stdout.jsonl'),chunk);pending+=chunk;
  let i;
  while((i=pending.indexOf('\n'))>=0){
    const line=pending.slice(0,i);pending=pending.slice(i+1);
    let m;try{m=JSON.parse(line)}catch{continue}
    if(m.error){save('resume-error.json',m);child.stdin.end();console.error(JSON.stringify(m));continue;}
    if(m.id===1){send({method:'initialized'});send(request);}
    if(m.id===3){
      save('resume-result.json',m);
      if(m.result?.thread?.id!==threadId)throw Error('resumed identity mismatch');
      send({id:4,method:'mcpServerStatus/list',params:{threadId,limit:100}});
    }
    if(m.id===4){
      save('resume-mcp-status.json',m);
      if(!m.result||m.result.nextCursor!==null||m.result.data.some(x=>x.runtimeStatus!=='disabled'||Object.keys(x.tools).length))throw Error('MCP not disabled');
      const turn={id:5,method:'turn/start',params:{threadId,effort:'high',input:[{type:'text',text:'Continue the same admitted T-003 implementation with all original scope, output-only, identity, permissions and evidence restrictions unchanged. The missing path was a spelling/location error, not missing admission: the admitted validator is plugins/sdd-implementation/scripts/validate-implementation-report.sh (not plugins/sdd-quality-loop/scripts/validate-implementation-report.sh). It exists in output/work and the pinned manifest. Read this admitted validator, finish the implementation report with actual executed evidence, validate it, and create output/delivery-index.json. Preserve the original failed command as a diagnostic. Do not rerun expensive successful tests unless changed bytes require it. Do not change task state, reserve, review, commit or access outside admitted inputs/output. Mark Windows, installed-host activation, independent review, quality gate, CI and merge as NOT RUN. Complete the existing delivery; do not create a new implementation identity.'}]}};
      save('resume-turn-start.json',turn);send(turn);console.log('T003_RESUMED '+threadId);
    }
    if(m.method==='turn/completed'){save('resume-completed.json',m);console.log(JSON.stringify(m));child.stdin.end();}
  }
});
child.stderr.on('data',chunk=>fs.appendFileSync(path.join(base,'resume-stderr.log'),chunk));
child.on('exit',code=>process.exit(code??1));
send({id:1,method:'initialize',params:{clientInfo:{name:'sdd_t003_delivery_resume',version:'1'},capabilities:{experimentalApi:true}}});
