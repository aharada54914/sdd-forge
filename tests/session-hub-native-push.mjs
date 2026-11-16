import {RpcPeer,sendCodex} from '../plugins/sdd-ship/session-hub/push.mjs';
import {mkdtemp,rm,writeFile} from 'node:fs/promises';import {tmpdir} from 'node:os';import {join} from 'node:path';
const directory=await mkdtemp(join(tmpdir(),'sdd-native-push-'));
const peer=new RpcPeer(process.env.SDD_CODEX_BINARY || 'codex',['app-server','--stdio','--strict-config'],{cwd:directory});let target;
try {
 await peer.request('initialize',{clientInfo:{name:'sdd_hub_native_verifier',version:'1.0.0'}});
 const seed=await peer.request('thread/start',{cwd:directory,approvalPolicy:'never',sandbox:'read-only',baseInstructions:'Isolated transport verification. Do not call tools. Reply ACK only.'});target=seed.thread.id;
 await peer.request('turn/start',{threadId:target,input:[{type:'text',text:'Seed this transport test. Reply ACK only.'}]});
 await new Promise(r=>setTimeout(r,500));
 const marker='sdd-native-'+Date.now();const receipt=await sendCodex(peer,target,marker,marker);
 let turn,item;
 for(let attempt=0;attempt<30;attempt++) {
   const observed=await peer.request('thread/read',{threadId:target,includeTurns:true});
   turn=observed.thread.turns.find(t=>t.id===receipt);
   item=turn?.items.find(i=>i.type==='userMessage'&&i.content?.some(part=>part.type==='text'&&part.text.includes(marker)));
   if(item)break;
   await new Promise(r=>setTimeout(r,500));
 }
 const value={status:item?'PASS':'FAIL',exactMessageVerified:!!item,scope:'native Codex existing-thread input delivery',threadId:target,turnId:receipt,messagePersisted:!!item,
   turnStatus:turn?.status,modelCompletionVerified:turn?.status==='completed',errorCode:turn?.error?.codexErrorInfo||null};
 await writeFile(process.env.SDD_NATIVE_PUSH_OUTPUT || '/tmp/sdd-native-push-result.json',JSON.stringify(value,null,2));console.log(JSON.stringify(value));
 if(!item)process.exitCode=1;
 await peer.request('thread/archive',{threadId:target});target=null;

} catch(error) {
 const value={status:'FAIL',scope:'native Codex existing-thread input delivery',error:'native-transport-unavailable',threadId:target||null};
 await writeFile(process.env.SDD_NATIVE_PUSH_OUTPUT || '/tmp/sdd-native-push-result.json',JSON.stringify(value,null,2));
 console.log(JSON.stringify(value));process.exitCode=1;
}finally{if(target)try{await peer.request('thread/archive',{threadId:target});}catch{}peer.close();await rm(directory,{recursive:true,force:true});}
