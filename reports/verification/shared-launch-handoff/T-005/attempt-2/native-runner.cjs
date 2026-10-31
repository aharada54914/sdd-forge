const fs = require('fs');
const cp = require('child_process');
const path = require('path');
const base = __dirname;
const prior = path.dirname(base);
const request = JSON.parse(fs.readFileSync(path.join(prior, 'native-thread-start.json')));
request.id = 3;
request.params.cwd = path.join(base, 'output');
const tmp = path.join(base, 'output/tmp');
const env = {...process.env, TMPDIR: tmp, TMP: tmp, TEMP: tmp};
for (const key of ['TMPDIR','TMP','TEMP']) request.params.config['shell_environment_policy.set.'+key] = tmp;
const probe = cp.spawnSync('python3', ['-c', 'import os,tempfile,json; print(json.dumps({"TMPDIR":os.environ["TMPDIR"],"tempfile":tempfile.gettempdir()}))'], {env, encoding:'utf8'});
if (probe.status !== 0 || JSON.parse(probe.stdout).tempfile !== tmp) throw Error('Wrong temporary directory');
fs.writeFileSync(path.join(base, 'temp-resolution.json'), probe.stdout);
fs.writeFileSync(path.join(base, 'native-thread-start.json'), JSON.stringify(request,null,2)+'\n');
const args = ['app-server'];
for (const [key,value] of Object.entries(request.params.config)) args.push('-c', key+'='+JSON.stringify(value));
const child = cp.spawn('codex', args, {env,stdio:['pipe','pipe','pipe']});
const send = value => child.stdin.write(JSON.stringify(value)+'\n');
let pending = '';
child.stdout.on('data', chunk => {
  fs.appendFileSync(path.join(base,'native-stdout.jsonl'),chunk);
  pending += chunk;
  let index;
  while ((index=pending.indexOf('\n')) >= 0) {
    const line=pending.slice(0,index); pending=pending.slice(index+1);
    let message; try {message=JSON.parse(line)} catch {continue}
    if (message.id === 1) {send({method:'initialized'});send(request)}
    if (message.id === 3 && message.result) {
      fs.writeFileSync(path.join(base,'native-thread-start-result.json'),JSON.stringify(message,null,2)+'\n');
      send({id:4,method:'mcpServerStatus/list',params:{threadId:message.result.thread.id,limit:100}});
    }
    if (message.id === 4 && message.result) {
      fs.writeFileSync(path.join(base,'effective-mcp-status.json'),JSON.stringify(message,null,2)+'\n');
      if(message.result.nextCursor!==null || message.result.data.some(x=>x.runtimeStatus!=='disabled'||Object.keys(x.tools).length)) throw Error('MCP not disabled');
      console.log('NATIVE_READY');
    }
    if (message.id === 5) console.log(JSON.stringify(message));
    if (message.method === 'turn/completed') {fs.writeFileSync(path.join(base,'turn-completed.json'),JSON.stringify(message,null,2)+'\n');console.log(JSON.stringify(message));}
  }
});
child.stderr.on('data',chunk=>fs.appendFileSync(path.join(base,'native-stderr.log'),chunk));
let sent=false;
setInterval(()=>{const p=path.join(base,'turn-start.json');if(!sent&&fs.existsSync(p)){sent=true;send(JSON.parse(fs.readFileSync(p))) }},500);
child.on('exit',code=>process.exit(code??1));
send({id:1,method:'initialize',params:{clientInfo:{name:'sdd_t005_attempt2',version:'1'},capabilities:{experimentalApi:true}}});
