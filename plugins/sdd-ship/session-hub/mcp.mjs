import { hubRequest, readBody, hubHeaders } from './http.mjs';
/** Site-hosted tools use the same authorization, revision checks and durable store as the UI. */
export async function mcpRequest(request, options) {
  const endpoint = new URL('/api/hub',request.url);
  const authorized = await hubRequest(new Request(endpoint,{headers:request.headers}),options);
  if (!authorized.ok) return authorized;
  const reply = value => Response.json(value,{headers:hubHeaders});
  if (request.method !== 'POST') return new Response(null,{status:405,headers:{...hubHeaders,Allow:'POST'}});
  let rpc;
  try { rpc = await readBody(request); } catch { return reply({jsonrpc:'2.0',id:null,error:{code:-32700,message:'Invalid JSON'}}); }
  if (rpc?.jsonrpc === '2.0' && rpc.method === 'notifications/initialized' && rpc.id === undefined) return new Response(null,{status:202,headers:hubHeaders});
  if (!rpc || rpc.jsonrpc !== '2.0' || !(typeof rpc.id === 'string' || Number.isSafeInteger(rpc.id))) return reply({jsonrpc:'2.0',id:null,error:{code:-32600,message:'Invalid request'}});
  const result = value => reply({jsonrpc:'2.0',id:rpc.id,result:value});
  if (rpc.method === 'initialize') return result({protocolVersion:['2025-03-26','2025-06-18','2026-07-28'].includes(rpc.params?.protocolVersion) ? rpc.params.protocolVersion : '2025-06-18',capabilities:{tools:{}},serverInfo:{name:'sdd-session-hub',version:'1.0.0'}});
  if (rpc.method === 'server/discover') return result({supportedVersions:['2026-07-28'],capabilities:{tools:{}}});
  if (rpc.method === 'tools/list') return result({tools:[
    {name:'sdd_hub_read',description:'Read the authorized shared question hub; includes revision and receipt states.',inputSchema:{type:'object',additionalProperties:false,properties:{}}},
    {name:'sdd_hub_command',description:'Perform an explicitly requested question, receipt or queue action. Never approves canonical tasks or merges PRs.',inputSchema:{type:'object',required:['command'],additionalProperties:false,properties:{command:{type:'object',required:['project','expectedRevision','action','input'],additionalProperties:false,properties:{project:{type:'string'},expectedRevision:{type:'integer',minimum:0},action:{type:'string',enum:['message','resolve-delivery','dispatch','delivery','register','ask','answer','receive','away','enqueue','claim','finish','cancel','resolve','verification']},input:{type:'object'}}}}}}
  ]});
  if (rpc.method !== 'tools/call') return reply({jsonrpc:'2.0',id:rpc.id,error:{code:-32601,message:'Method not found'}});
  if (rpc.params?.name === 'sdd_hub_read') return result({content:[{type:'text',text:await authorized.text()}]});
  if (rpc.params?.name !== 'sdd_hub_command' || !rpc.params.arguments?.command) return result({isError:true,content:[{type:'text',text:'Unknown tool or missing command'}]});
  const headers = new Headers(request.headers); headers.set('Origin',endpoint.origin); headers.set('Content-Type','application/json'); headers.delete('Content-Length');
  const next = await hubRequest(new Request(new URL('/api/hub/command',endpoint),{method:'POST',headers,body:JSON.stringify(rpc.params.arguments.command)}),options);
  return result({isError:!next.ok,content:[{type:'text',text:await next.text()}]});
}
