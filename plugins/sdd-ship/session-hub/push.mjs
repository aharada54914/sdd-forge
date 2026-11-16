/** Official host transports. A host acknowledgement is not a model completion or a workflow approval. */
import { spawn } from 'node:child_process';
import { createInterface } from 'node:readline';
import { randomUUID, createHash } from 'node:crypto';
import { resolve, isAbsolute } from 'node:path';
import { pathToFileURL } from 'node:url';
import { apiClient } from './api.mjs';
import { destination } from './destinations.mjs';
import { id } from './core.mjs';
export class DeliveryError extends Error {
  constructor(code, uncertain = false) { super(code); this.uncertain = uncertain; }
}
export class RpcPeer {
  constructor(binary, args, options = {}) {
    this.process = spawn(binary,args,{...options,stdio:['pipe','pipe','ignore'],shell:false});
    this.pending = new Map(); this.number = 0; this.closed = false;
    this.lines = createInterface({input:this.process.stdout});
    this.lines.on('line',line => {
      if (Buffer.byteLength(line)>8*1024*1024) { this.close(); return; }
      let message; try {message=JSON.parse(line);} catch {this.close();return;}
      if (message.method && message.id !== undefined) {
        // Native host keeps ownership of approvals; the delivery bridge cannot grant them.
        this.process.stdin.write(JSON.stringify({id:message.id,error:{code:-32000,message:'Interactive host approval required'}})+'\n'); return;
      }
      const waiting = this.pending.get(message.id);
      if (!waiting) return;
      this.pending.delete(message.id);clearTimeout(waiting.timer);
      if (message.error) waiting.reject(new DeliveryError('host-request-rejected',['turn/start','turn/steer'].includes(waiting.method)));
      else {
        if(waiting.method==='initialize'){this.initialized=true;this.process.stdin.write(JSON.stringify({method:'initialized'})+'\n');}
        waiting.resolve(message.result);
      }
    });
    this.process.once('error',() => this.close()); this.process.once('exit',() => this.close());
    this.process.stdin.on('error',() => this.close());
  }
  request(method,params) {
    if (this.closed) return Promise.reject(new DeliveryError('host-unavailable'));
    const number = ++this.number;
    return new Promise((resolve,reject) => {
      const timer=setTimeout(() => {this.pending.delete(number);reject(new DeliveryError('host-timeout',true));},15000);
      this.pending.set(number,{resolve,reject,timer,method});
      this.process.stdin.write(JSON.stringify({id:number,method,params})+'\n');
    });
  }
  close() {
    if (this.closed) return; this.closed=true;this.lines.close();this.process.kill();
    for (const {reject,timer} of this.pending.values()) {clearTimeout(timer);reject(new DeliveryError('host-unavailable',true));}
    this.pending.clear();
  }
}
function messageUuid(messageId) {
  const hex=createHash('sha256').update('sdd-hub:'+messageId).digest('hex');
  return hex.slice(0,8)+'-'+hex.slice(8,12)+'-4'+hex.slice(13,16)+'-8'+hex.slice(17,20)+'-'+hex.slice(20,32);
}
export async function sendCodex(peer,target,message,messageId) {
  destination('codex',target);
  if(!peer.initialized) await peer.request('initialize',{clientInfo:{name:'sdd_session_hub',version:'1.0.0'}});
  const read=await peer.request('thread/read',{threadId:target,includeTurns:true});
  if (read?.thread?.id !== target) throw new DeliveryError('destination-mismatch');
  const active=read.thread.turns?.findLast(turn => turn.status === 'inProgress');
  if (read.thread.status?.type === 'active' && !active) throw new DeliveryError('host-active-state-unknown');
  const input=[{type:'text',text:message,text_elements:[]}];
  const clientUserMessageId=messageUuid(messageId);
  if (active) {
    const response=await peer.request('turn/steer',{threadId:target,expectedTurnId:active.id,input,clientUserMessageId});
    if (response?.turnId !== active.id) throw new DeliveryError('invalid-host-receipt',true);
    return response.turnId;
  }
  const resumed=await peer.request('thread/resume',{threadId:target});
  if (resumed?.thread?.id !== target) throw new DeliveryError('destination-mismatch');
  const response=await peer.request('turn/start',{threadId:target,input,clientUserMessageId});
  if (typeof response?.turn?.id !== 'string') throw new DeliveryError('invalid-host-receipt',true);
  return response.turn.id;
}
function invoke(binary,args,input,timeoutMs=30000) {
  return new Promise((resolve,reject) => {
    const child=spawn(binary,args,{stdio:['pipe','pipe','pipe'],shell:false});
    let output='',diagnostic='',size=0; const timer=setTimeout(()=>{child.kill('SIGKILL');reject(new DeliveryError('host-timeout',true));},timeoutMs);
    const collect=kind=>chunk=>{size+=chunk.length;if(size>65536){child.kill('SIGKILL');return;}if(kind==='stdout')output+=chunk;else diagnostic+=chunk;};
    child.stdout.on('data',collect('stdout'));child.stderr.on('data',collect('stderr'));
    child.once('error',()=>{clearTimeout(timer);reject(new DeliveryError('host-unavailable'));});
    child.once('exit',code=>{clearTimeout(timer);resolve({code,output,diagnostic,oversized:size>65536});});
    child.stdin.on('error',()=>{});child.stdin.end(input);
  });
}
export async function sendClaude(binary,target,message) {
  target=destination('claude-cloud',target);
  const auth=await invoke(binary,['auth','status','--json'],'');
  let status;try{status=JSON.parse(auth.output);}catch{throw new DeliveryError('claude-login-required');}
  if (auth.code !== 0 || !status.loggedIn || status.authMethod === 'api_key' || status.apiProvider !== 'firstParty') throw new DeliveryError('claude-login-required');
  const result=await invoke(binary,['-p','--cloud',target],message);
  if (result.oversized) throw new DeliveryError('invalid-host-receipt',true);
  if (result.code !== 0 || /^(Error:|.*failed to send message)/im.test(result.output+'\n'+result.diagnostic)) throw new DeliveryError('claude-send-rejected',true);
  if (!result.output.trim()) throw new DeliveryError('missing-host-receipt',true);
  // CLI exits after queue acceptance; retain only the target, never provider output with private content.
  return target;
}
export async function deliverOne(config) {
  id(config.sessionId);
  const target=destination(config.transport,config.destination);
  if (!target || !isAbsolute(config.binary)) throw new DeliveryError('invalid-push-config');
  const api=apiClient(config);let state=await api.read();
  const own=state.sessions.find(s=>s.id===config.sessionId);
  if (!own || own.transport!==config.transport || own.destination!==target) throw new DeliveryError('destination-mismatch');
  const message=(state.messages || []).find(m=>m.sessionId===config.sessionId&&m.status==='queued');
  if (!message) return false;
  if (message.transport!==config.transport||message.destination!==target) throw new DeliveryError('destination-mismatch');
  const claimId=randomUUID();
  try{await api.command(state,'dispatch',{id:message.id,claimId});}catch(e){if(e.status===409)return false;throw e;}
  let receipt, failure;
  try {
    const text='[SDD message '+message.id+']\n'+message.text;
    if (config.transport==='codex') {
      const args=['app-server','proxy',...(config.socket?['--sock',config.socket]:[])];
      if(config.socket&&!isAbsolute(config.socket))throw new DeliveryError('invalid-socket');
      const peer=new RpcPeer(config.binary,args);
      try{receipt=await sendCodex(peer,target,text,message.id);}finally{peer.close();}
    }else receipt=await sendClaude(config.binary,target,text);
  }catch(e){failure=e instanceof DeliveryError?e:new DeliveryError('delivery-uncertain',true);}
  for(let attempt=0;attempt<3;attempt++) {
    state=await api.read();
    try {await api.command(state,'delivery',{id:message.id,claimId,status:failure?(failure.uncertain?'uncertain':'failed'):'accepted',...(failure?{error:failure.message}:{receipt})});break;}
    catch(e){if(e.status!==409||attempt===2)throw e;}
  }
  return true;
}
if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href) {
  try {
    let raw='';for await(const chunk of process.stdin){raw+=chunk;if(raw.length>8192)throw new DeliveryError('config-too-large');}
    const config=JSON.parse(raw);let stopping=false;
    for(const signal of ['SIGINT','SIGTERM'])process.once(signal,()=>{stopping=true;});
    do {await deliverOne(config);if(!config.once&&!stopping)await new Promise(yes=>setTimeout(yes,1000));}while(!config.once&&!stopping);
  }catch{process.stderr.write('Push bridge stopped; inspect delivery state and native host connection.\n');process.exitCode=1;}
}
