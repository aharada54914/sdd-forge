// Uses the repository's real MCP stdio API; no workflow rules are duplicated.
import {createRequire} from 'node:module';
import {dirname, resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
if (process.env.SDD_PUBLISHER_TOKEN || process.env.SDD_SITES_SERVICE_TOKEN || process.env.SDD_COLLECTOR_TOKEN) {
  throw new Error('publisher secrets must not enter metadata child');
}
let raw='';for await(const chunk of process.stdin)raw+=chunk;
const request=JSON.parse(raw);
const require=createRequire(resolve(dirname(request.server),'../package.json'));
const {Client}=await import(pathToFileURL(require.resolve('@modelcontextprotocol/sdk/client/index.js')).href);
const {StdioClientTransport}=await import(pathToFileURL(require.resolve('@modelcontextprotocol/sdk/client/stdio.js')).href);
const sources=[];
for(const source of request.sources){
 const transport=new StdioClientTransport({command:process.execPath,args:[request.server,'--root',source.root],stderr:'pipe',env:{PATH:process.env.PATH||'/usr/bin:/bin',LANG:'C.UTF-8',TZ:'UTC'}});
 const client=new Client({name:'sdd-sites-readonly-collector',version:'1.0.0'});
 const call=async(name,args={})=>{
  const result=await client.callTool({name,arguments:args});
  const block=result.content?.find(item=>item.type==='text');if(!block)throw Error('missing MCP envelope');
  return JSON.parse(block.text);
 };
 try{
  await client.connect(transport);
  const active=await call('list_active_specs');if(!active.ok)throw Error('active-spec registry unavailable');
  const features=[];
  for(const spec of active.data.specs){
   const [next,tasks]=await Promise.all([call('get_next_sdd_command',{feature:spec.feature}),call('get_task_state',{feature:spec.feature})]);
   features.push({feature:spec.feature,next,tasks});
  }
  sources.push({id:source.id,features});
 }finally{await client.close();}
}
console.log(JSON.stringify({schema:'sdd-sites-workflow-metadata/v1',sources}));
