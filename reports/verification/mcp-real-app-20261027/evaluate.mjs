import {Client} from '/workspace/sdd-forge/mcp/sdd-forge-mcp/node_modules/@modelcontextprotocol/sdk/dist/esm/client/index.js';
import {StdioClientTransport} from '/workspace/sdd-forge/mcp/sdd-forge-mcp/node_modules/@modelcontextprotocol/sdk/dist/esm/client/stdio.js';
import {mkdir, writeFile, readFile} from 'node:fs/promises';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {performance} from 'node:perf_hooks';

const root='/workspace/sdd-forge';
const output='/workspace/scratch/issue-resolution-20261027/mcp-live-v3';
const sha=x=>createHash('sha256').update(x).digest('hex');
const git=(...a)=>execFileSync('git',['-C',root,...a],{maxBuffer:16*1024*1024});
await mkdir(output);
const revisions={A:git('rev-parse','origin/main').toString().trim(),B:git('rev-parse','HEAD').toString().trim()};
const servers={};
for(const [label,revision] of Object.entries(revisions)){
  const bytes=git('show',`${revision}:mcp/sdd-forge-mcp/dist/index.js`);
  servers[label]={path:`${output}/server-${label}.mjs`,sha256:sha(bytes),revision};
  await writeFile(servers[label].path,bytes);
}
const calls=[
 {name:'list_active_specs',arguments:{}},
 {name:'get_spec_status',arguments:{feature:'project-skill-observation'}},
 {name:'get_task_state',arguments:{feature:'project-skill-observation'}},
 {name:'get_next_sdd_command',arguments:{feature:'project-skill-observation'}},
 {name:'get_task_state',arguments:{feature:'sdd-forge-mcp'}},
 {name:'get_next_sdd_command',arguments:{feature:'sdd-forge-mcp'}},
];
const protocol={schema:'mcp-real-app-pilot/v1',revisions,servers,
 input_root_revision:revisions.B,input_tree:git('rev-parse','HEAD^{tree}').toString().trim(),
 initial_dirty:git('status','--porcelain').toString(),
 calls,repetitions:3,trial_timeout_seconds:90,call_timeout_seconds:25000,
 scenario:'Confirm the next allowed workflow step for project-skill-observation and whether implementation is authorized; compare with the completed sdd-forge-mcp feature.',
 success:['Same native MCP tool results across the two code revisions on the same real repository',
 'Pending spec review must not be shown as implementation approval',
 'No task/approval/source mutation; service filesystem is read-only',
 'All failed, timeout and cancelled calls retained'],
 tolerances:'Exact structured result equality; no time-based adoption threshold.',
 stop:'One mismatch or service failure prevents adoption; at most 6 sessions, 36 calls, 600 seconds total.',
 rollback:'Delete only newly created pilot output; product remains read-only.',
 configuration:{host:'Native MCP SDK client over stdio',node:process.version,os:process.platform,model:null,cost:null,
 budget:'No model calls; 6 sessions / 36 calls / 600 wall seconds. Currency not metered.'},
 human_evaluation:'pending; scripted task execution does not substitute for human operation or preference',
 baseline:'Existing MCP results with raw log presentation',candidate:'Same MCP operations plus passive decision-packet presentation; no new execution authority'};
await writeFile(`${output}/protocol.json`,JSON.stringify(protocol,null,2));
const started=performance.now(), rows=[];
for(let trial=1;trial<=3;trial++)for(const label of trial%2?['A','B']:['B','A']){
 const row={trial,label,status:'not-run',calls:[],seconds:null};
 rows.push(row);
 if(performance.now()-started>600000){row.reason='total-budget';continue;}
 const args=['--unshare-all','--new-session','--die-with-parent'];
 for(const path of ['/usr','/bin','/lib','/lib64'])args.push('--ro-bind',path,path);
 args.push('--ro-bind',process.execPath,'/native/node','--proc','/proc','--dev','/dev','--tmpfs','/tmp','--ro-bind',root,'/source',
 '--ro-bind',servers[label].path,'/server.mjs','--chdir','/source','/native/node','/server.mjs','--root','/source');
 const transport=new StdioClientTransport({command:'bwrap',args,stderr:'pipe'});
 const client=new Client({name:'real-app-readonly-pilot',version:'1.0.0'});
 let stderr='';transport.stderr.on('data',x=>{stderr+=x.toString()});
 const before=performance.now();
 const watchdog=setTimeout(()=>client.close(),90000);
 try{
  await client.connect(transport,{timeout:25000});
  row.tools=(await client.listTools()).tools.map(x=>x.name);
  for(const request of calls){
   const tick=performance.now();
   try{
    const result=await client.callTool(request,undefined,{timeout:25000});
    row.calls.push({request,result,seconds:(performance.now()-tick)/1000});
   }catch(e){row.calls.push({request,error:String(e),seconds:(performance.now()-tick)/1000});throw e;}
  }
  row.status='completed';
 }catch(e){row.status='failed';row.reason=String(e);}
 finally{clearTimeout(watchdog);await client.close();row.seconds=(performance.now()-before)/1000;row.stderr=stderr;}
 await writeFile(`${output}/observations.json`,JSON.stringify(rows,null,2));
 console.log(JSON.stringify({trial,label,status:row.status,seconds:row.seconds}));
}
const signature=r=>JSON.stringify(r.calls.map(c=>({request:c.request,result:c.result})));
const same=rows.every(r=>r.status==='completed'&&signature(r)===signature(rows[0]));
const after=git('status','--porcelain').toString();
const summary={schema:'mcp-real-app-observation/v1',sessions:rows.length,completed:rows.filter(x=>x.status==='completed').length,
 actual_calls:rows.reduce((n,r)=>n+r.calls.length,0),structured_parity:same,tracked_tree_unchanged:after===protocol.initial_dirty,
 variants:Object.fromEntries(['A','B'].map(k=>{const times=rows.filter(x=>x.label===k).map(x=>x.seconds).sort((a,b)=>a-b);return[k,{seconds:times,median_seconds:times[1]}]})),
 human_task_success:null,human_time:null,human_errors:null,human_choice:null,
 decision:'Human interaction remains required; machine parity alone does not establish UX benefit.'};
await writeFile(`${output}/summary.json`,JSON.stringify(summary,null,2));
console.log(JSON.stringify(summary));
