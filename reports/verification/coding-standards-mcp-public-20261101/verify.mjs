import { mkdtemp, mkdir, copyFile, writeFile, readFile, readdir, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createHash } from 'node:crypto';
import { pathToFileURL } from 'node:url';
const repo = process.cwd();
const sdk = join(repo,'mcp/ci-mcp/node_modules/@modelcontextprotocol/sdk/dist/esm/client');
const {Client}=await import(pathToFileURL(join(sdk,'index.js')));
const {StdioClientTransport}=await import(pathToFileURL(join(sdk,'stdio.js')));
const hash = data => createHash('sha256').update(data).digest('hex');
const rows=[];
const root=await mkdtemp(join(tmpdir(),'mcp-public-entry-'));
async function manifest(path, prefix='') {
 const entries=[];
 for (const e of await readdir(path,{withFileTypes:true})) {
  const rel=join(prefix,e.name), p=join(path,e.name);
  if(e.isDirectory()) entries.push(...await manifest(p,rel));
  else entries.push([rel,hash(await readFile(p))]);
 }
 return entries.sort((a,b)=>a[0].localeCompare(b[0]));
}
try {
 for(const name of ['sdd-forge-mcp','local-env-mcp','ci-mcp']) {
  const install=join(root,name), fixture=join(install,'fixture');
  await mkdir(join(install,'dist'),{recursive:true});
  await mkdir(join(fixture,'specs/demo'),{recursive:true});
  await copyFile(join(repo,'mcp',name,'dist/index.js'),join(install,'dist/index.js'));
  await copyFile(join(repo,'mcp',name,'package.json'),join(install,'package.json'));
  await writeFile(join(fixture,'AGENTS.md'),'# Project\n\n## Active Spec Directories\n\n- `specs/demo/`\n');
  await writeFile(join(fixture,'specs/demo/requirements.md'),'# Requirements\n\nSpec-Review-Status: Pending\n');
  const before=await manifest(install);
  const args=[join(install,'dist/index.js')];if(name==='sdd-forge-mcp')args.push('--root',fixture);
  const transport=new StdioClientTransport({command:process.execPath,args,cwd:install,stderr:'pipe',env:{HOME:fixture,PATH:'',CI_MCP_GITHUB_TOKEN:'',GH_READONLY_TOKEN:'',GITHUB_TOKEN:'',NODE_OPTIONS:''}});
  let stderr='';transport.stderr.on('data',b=>{stderr+=b.toString()});
  const client=new Client({name:'coding-standards-public-boundary',version:'1.0.0'});
  let pid;
  try {
   await client.connect(transport,{timeout:10000});pid=transport.pid;
   const listed=await client.listTools({}, {timeout:10000});
   const tools=listed.tools.map(t=>t.name);
   const call=name==='sdd-forge-mcp'?{name:'get_spec_status',arguments:{feature:'demo'}}:name==='local-env-mcp'?{name:'get_os_info',arguments:{}}:{name:'list_workflow_runs',arguments:{owner:'example',repo:'example',perPage:1}};
   if(!tools.includes(call.name))throw Error('required public tool absent');
   const result=await client.callTool(call,undefined,{timeout:10000});
   if(result.isError)throw Error('MCP protocol tool error');
   const envelope=JSON.parse(result.content[0].text);
   if(name==='ci-mcp') {if(envelope.ok!==false||envelope.error.code!=='auth-missing')throw Error('CI call did not stop at no-token boundary');}
   else if(envelope.ok!==true) throw Error('read-only call did not succeed');
   if(name==='sdd-forge-mcp'&&!envelope.data.artifacts.some(a=>a.exists&&a.reviewStatus==='Pending'))throw Error('fixture was not actually read');
   await client.close();
   let processGone=false;try{process.kill(pid,0)}catch(e){if(e.code==='ESRCH')processGone=true;else throw e}
   if(!processGone)throw Error('child remains after transport close');
   const after=await manifest(install);
   if(JSON.stringify(before)!==JSON.stringify(after))throw Error('read-only tool changed installed files');
   rows.push({package:name,bundle_sha256:hash(await readFile(join(install,'dist/index.js'))),tool_count:tools.length,tools,call,response:envelope,stdout:'MCP initialize/listTools/callTool framing accepted by the SDK client; no diagnostic contamination',stderr_json_lines:stderr.trim().split('\n').map(l=>JSON.parse(l)).length,standalone:true,server_node_modules:false,filesystem_unchanged:true,child_closed:true,network:'No credentials supplied; CI auth-missing short-circuits before GitHub transport. Other calls use local filesystem/OS only.'});
  } finally {await client.close();}
 }
} finally {await rm(root,{recursive:true,force:true});}
const out={schema:'coding-standards-mcp-public-entry/v1',node:process.version,platform:process.platform,boundary:'Actual standalone distribution child processes over MCP stdio; SDK initialize, tools/list and tools/call. No module-level handler substitution.',results:rows};
await writeFile(process.argv[2] ?? '/tmp/public-mcp-smoke-results.json',JSON.stringify(out,null,2)+'\n');
console.log(JSON.stringify(rows.map(({package:p,tool_count,call,response,filesystem_unchanged,child_closed})=>({package:p,tool_count,tool:call.name,result:response.ok?'ok':response.error.code,filesystem_unchanged,child_closed}))));
