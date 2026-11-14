import http from 'node:http';
import assert from 'node:assert/strict';
import {webcrypto} from 'node:crypto';
import {writeFileSync} from 'node:fs';
const {default:worker}=await import(process.env.SDD_SITE_WORKER_MODULE || '../.sites-checkout/worker/index.js');
globalThis.crypto ??= webcrypto;
const objects=new Map();let sequence=0;
const BUCKET={async get(key){const o=objects.get(key);return o?{etag:o.etag,text:async()=>o.body,json:async()=>JSON.parse(o.body)}:null},async put(key,body,opts={}){const old=objects.get(key),cond=opts.onlyIf;if(cond?.etagMatches&&old?.etag!==cond.etagMatches)return null;if(cond?.etagDoesNotMatch==='*'&&old)return null;const o={body,etag:String(++sequence)};objects.set(key,o);return o}};
const env={BUCKET,SDD_PUBLISHER_TOKEN:'local-test-only'};
const base='http://127.0.0.1:8790';
const stamp=()=>new Date().toISOString();
const task=(id,status,approval='Approved')=>({key:'qa/'+id,id,feature:'lite',title:id==='T-001'?'lite UI試験':'検証 '+id,body:'検証用の本文 <img src=x onerror=alert(1)>',status,approval,risk:'low',source:'specs/lite/tasks.md',release:id==='T-001'?'検証版':null,failures:[]});
let snapshot={schema:'sdd-dashboard/v1',attemptedAt:stamp(),checkedAt:stamp(),lastSuccessAt:stamp(),changedAt:stamp(),revision:'a'.repeat(64),error:null,data:{project:'Sitesローカル機能試験（本番データではない）',features:[{id:'lite',displayName:'lite UI',phase:'done',nextCommand:'',warnings:[]},{id:'full',displayName:'full',phase:'spec-review',nextCommand:'spec-review',warnings:['#726 により仕様レビュー入口で停止']},{id:'sqlite',displayName:'SQLite',phase:'spec-review',nextCommand:'spec-review',warnings:['#726 により仕様レビュー入口で停止']}],tasks:[task('T-001','Done'),task('T-002','Planned','Draft'),task('T-003','Blocked'),task('T-004','Implementation Complete'),task('T-005','In Progress')]}};
// Normalize timestamps so no later field exceeds attemptedAt.
snapshot.checkedAt=snapshot.lastSuccessAt=snapshot.changedAt=snapshot.attemptedAt;
const call=(path,method='GET',body,headers={})=>worker.fetch(new Request(base+path,{method,headers:{...(body?{'content-type':'application/json'}:{}),...headers},...(body?{body:JSON.stringify(body)}:{})}),env);
const pub={'X-SDD-Publisher':'local-test-only'}; const viewer={'oai-authenticated-user-id':'local-test-viewer'};
const checks=[];
async function check(name,fn){await fn();checks.push(name)}
await check('anonymous read denied',async()=>assert.equal((await call('/api/dashboard')).status,401));
await check('viewer write denied',async()=>assert.equal((await call('/api/snapshot','PUT',snapshot,viewer)).status,403));
await check('wrong publisher denied',async()=>assert.equal((await call('/api/snapshot','PUT',snapshot,{'X-SDD-Publisher':'wrong'})).status,401));
await check('snapshot publish/read roundtrip',async()=>{assert.equal((await call('/api/snapshot','PUT',snapshot,pub)).status,200);assert.deepEqual((await (await call('/api/dashboard','GET',null,viewer)).json()).data,snapshot.data)});
await check('older snapshot rejected',async()=>assert.equal((await call('/api/snapshot','PUT',snapshot,pub)).status,409));
await check('cross-origin rejected',async()=>assert.equal((await call('/api/dashboard','GET',null,{...viewer,origin:'https://example.invalid'})).status,403));
await check('invalid schema rejected',async()=>assert.equal((await call('/api/snapshot','PUT',{schema:'wrong'},pub)).status,400));
await check('project mismatch rejected',async()=>{const s=structuredClone(snapshot);s.attemptedAt=new Date(Date.now()+1000).toISOString();s.data.project='other';assert.equal((await call('/api/snapshot','PUT',s,pub)).status,409)});
const health={schema:'sdd-monitor/v1',observedAt:stamp(),state:'running',publisherVersion:'a'.repeat(12),collectorVersion:'b'.repeat(12),lastPublishAt:snapshot.attemptedAt,lastSourceAt:snapshot.attemptedAt,consecutiveFailures:0,collectorRestarts:0,collectionMs:1,lastError:null};
await check('health publish/read',async()=>{assert.equal((await call('/api/health','PUT',health,pub)).status,200);assert.equal((await (await call('/api/health','GET',null,viewer)).json()).state,'running')});
await check('history derives task observations',async()=>{const v=await (await call('/api/observations','GET',null,viewer)).json();assert.equal(v.events.length,5);assert.equal(v.sourceStale,false)});
writeFileSync(new URL('backend-results.json',import.meta.url),JSON.stringify({scope:'exact published source, local in-memory R2 test double',passed:checks},null,2));
let fail=false;
http.createServer(async(req,res)=>{try{
 const chunks=[];for await(const c of req)chunks.push(c);const body=Buffer.concat(chunks);
 if(req.url==='/__qa/update'&&req.method==='POST'){
  const change=JSON.parse(body);snapshot=structuredClone(snapshot);snapshot.attemptedAt=stamp();snapshot.checkedAt=snapshot.lastSuccessAt=snapshot.attemptedAt;snapshot.revision=(snapshot.revision[0]==='a'?'b':'a').repeat(64);
  if(change.title)snapshot.data.tasks[0].title=change.title;
  if(change.stale)snapshot.checkedAt=snapshot.lastSuccessAt=snapshot.changedAt=new Date(Date.now()-120000).toISOString();
  if(change.error)snapshot={...snapshot,data:null,error:'source read failed',checkedAt:null,lastSuccessAt:null,changedAt:null};
  const r=await call('/api/snapshot','PUT',snapshot,pub);res.writeHead(r.status,{'content-type':'application/json'});res.end(await r.text());return;
 }
 if(req.url==='/__qa/network'&&req.method==='POST'){fail=JSON.parse(body).fail;res.end('{}');return}
 if(fail&&req.url==='/api/dashboard'){res.writeHead(503);res.end('{}');return}
 const r=await worker.fetch(new Request(base+req.url,{method:req.method,headers:{...req.headers,...viewer},...(body.length?{body}: {})}),env);res.writeHead(r.status,Object.fromEntries(r.headers));res.end(Buffer.from(await r.arrayBuffer()));
}catch(e){res.writeHead(500);res.end(String(e))}}).listen(8790,'127.0.0.1',()=>console.log('QA server ready; backend checks '+checks.length));
