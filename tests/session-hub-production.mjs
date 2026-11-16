import {writeFile} from 'node:fs/promises';import {randomBytes,randomUUID} from 'node:crypto';import {apiClient} from '../plugins/sdd-ship/session-hub/api.mjs';import {digest} from '../plugins/sdd-ship/session-hub/http.mjs';
const checks=[];
try {
// This verification writes clearly labeled test records to the configured production hub.
if(process.stdin.isTTY)throw new Error('Use a protected stdin pipe for production credentials');
let raw='';for await(const chunk of process.stdin){raw+=chunk;if(raw.length>8192)throw new Error('configuration-too-large');if(raw.includes('\n'))break;}
const config=JSON.parse(raw);const api=apiClient(config);let state=await api.read();checks.push('production-owner-read');
const unauthorized=await fetch(new URL('/api/hub',config.url),{redirect:'manual',signal:AbortSignal.timeout(15000)});if(unauthorized.ok)throw new Error('anonymous-access');checks.push('anonymous-denied-'+unauthorized.status);
const machineHeaders={Authorization:'Bearer '+config.token,'OAI-Sites-Authorization':'Bearer '+config.serviceToken};
const page=await fetch(new URL('/hub',config.url),{headers:machineHeaders,redirect:'error'});if(!page.ok||!(await page.text()).includes('既存会話へ送信'))throw new Error('production-page-missing');checks.push('production-hub-assets');
const sid='verify-'+randomUUID();const sessionToken=randomBytes(32).toString('hex');
state=await api.command(state,'register',{id:sid,label:'接続検証（テスト）',tokenHash:await digest(sessionToken)});
const worker=apiClient({...config,token:sessionToken});
state=await worker.command(await worker.read(),'ask',{id:'verify-'+randomUUID(),sessionId:sid,title:'本番接続の往復検証',expiresAt:Date.now()+300000,options:[{id:'ok',label:'接続確認'},{id:'no',label:'保留'}]});
const question=state.questions.at(-1);const requestId=randomUUID();
state=await api.command(await api.read(),'answer',{id:question.id,optionId:'ok',requestId});
const received=await worker.read();if(received.questions.at(-1).answer.requestId!==requestId)throw new Error('answer-not-delivered');
state=await worker.command(received,'receive',{id:question.id,requestId});if(state.questions.at(-1).status!=='received')throw new Error('receipt-not-persisted');checks.push('production-R2-question-answer-receipt');
let mcpStatus;try {
const rpc=await fetch(new URL('/mcp',config.url),{method:'POST',headers:{...machineHeaders,'Content-Type':'application/json'},body:JSON.stringify({jsonrpc:'2.0',id:1,method:'tools/list'}),redirect:'error'});
mcpStatus=rpc.status;
if(rpc.ok){const data=await rpc.json();if(data.result?.tools.some(t=>t.name==='sdd_hub_command'))checks.push('production-MCP-discovery');}
}catch{mcpStatus='network-error';}
const result={status:'PASS',mcpStatus,url:config.url,project:config.project,checks,questionId:question.id,sessionId:sid,scope:'production service-authenticated HTTP and real R2; browser visitor consent not verified'};
await writeFile(process.env.SDD_PRODUCTION_HUB_OUTPUT || '/tmp/sdd-production-hub-result.json',JSON.stringify(result,null,2));console.log(JSON.stringify(result));

} catch(error) {
 const result={status:'FAIL',scope:'production service-authenticated HTTP',checks,error:'verification-failed',httpStatus:error.status||null};
 await writeFile(process.env.SDD_PRODUCTION_HUB_OUTPUT || '/tmp/sdd-production-hub-result.json',JSON.stringify(result,null,2));
 console.log(JSON.stringify(result));process.exitCode=1;
}
