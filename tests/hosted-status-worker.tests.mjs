import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const source = readFileSync(new URL('../plugins/sdd-ship/status-site/worker.mjs',import.meta.url),'utf8').replace('__DASHBOARD_PAGE__',JSON.stringify('<html>test</html>')).replace('__OBSERVATION_CODE__',readFileSync(new URL('../plugins/sdd-ship/status-site/observations.js',import.meta.url),'utf8'));
const {default:worker, validSnapshot, validHealth} = await import('data:text/javascript;base64,'+Buffer.from(source).toString('base64'));
const snapshot = () => ({schema:'sdd-dashboard/v1',revision:'a'.repeat(64),attemptedAt:'2026-01-01T00:00:00Z',checkedAt:'2026-01-01T00:00:00Z',lastSuccessAt:'2026-01-01T00:00:00Z',changedAt:'2026-01-01T00:00:00Z',error:null,data:{project:'test',features:[],tasks:[]}});
function env() { let body=null;let etag=0;return { SDD_PUBLISHER_TOKEN:'test-only', BUCKET:{async get(){return body===null?null:{etag:String(etag),text:async()=>body,json:async()=>JSON.parse(body)}},async put(key,value,options){if(options.onlyIf.etagMatches!==undefined&&options.onlyIf.etagMatches!==String(etag))return null;body=value;etag++;return {etag:String(etag)}}} }; }
const request=(path,method='GET',body,authenticated=true)=>new Request('https://example.test'+path,{method,headers:authenticated?{'X-SDD-Publisher':'test-only'}:{},...(body?{body:JSON.stringify(body)}:{})});
test('private reads and publisher-only writes; malformed input and future timestamps rejected',async()=>{
 const e=env();assert.equal((await worker.fetch(request('/', 'GET',null,false),e)).status,401);
 const visitor=new Request('https://example.test/api/snapshot',{method:'PUT',headers:{'oai-authenticated-user-id':'viewer'},body:'{}'});
 assert.equal((await worker.fetch(visitor,e)).status,403);
 assert.equal((await worker.fetch(request('/api/snapshot','PUT',{}),e)).status,400);
 const future=snapshot();future.attemptedAt='2999-01-01T00:00:00Z';assert.equal(validSnapshot(future),false);
 assert.equal((await worker.fetch(request('/api/snapshot','PUT',snapshot()),e)).status,200);
 const actual=await (await worker.fetch(request('/api/dashboard'),e)).json();assert.equal(actual.revision,'a'.repeat(64));
 assert.equal((await worker.fetch(request('/api/snapshot','PUT',snapshot()),e)).status,409);
});
test('collector restart failure retains last-good data and source time; heartbeat keeps content age',async()=>{
 const e=env();const original=snapshot();await worker.fetch(request('/api/snapshot','PUT',original),e);
 const error={...original,data:null,revision:'',checkedAt:null,lastSuccessAt:null,changedAt:null,attemptedAt:'2026-01-01T00:01:00Z',error:'parse-failed'};
 assert.equal((await worker.fetch(request('/api/snapshot','PUT',error),e)).status,200);
 let actual=await(await worker.fetch(request('/api/dashboard'),e)).json();assert.equal(actual.error,'parse-failed');assert.deepEqual(actual.data,original.data);assert.equal(actual.checkedAt,original.checkedAt);
 const recovered={...original,attemptedAt:'2026-01-01T00:02:00Z',checkedAt:'2026-01-01T00:02:00Z',lastSuccessAt:'2026-01-01T00:02:00Z',changedAt:'2026-01-01T00:02:00Z'};
 assert.equal((await worker.fetch(request('/api/snapshot','PUT',recovered),e)).status,200);
 actual=await(await worker.fetch(request('/api/dashboard'),e)).json();assert.equal(actual.error,null);assert.equal(actual.changedAt,original.changedAt);
});
test('payload bounds, malformed task shapes, cross origin and project replacement are rejected',async()=>{
 const e=env();const bad=snapshot();bad.data.tasks=[{}];assert.equal(validSnapshot(bad),false);
 await worker.fetch(request('/api/snapshot','PUT',snapshot()),e);
 const other=snapshot();other.attemptedAt='2026-01-01T00:01:00Z';other.data.project='other';assert.equal((await worker.fetch(request('/api/snapshot','PUT',other),e)).status,409);
 const cross=new Request('https://example.test/',{headers:{'X-SDD-Publisher':'test-only',Origin:'https://evil.test'}});assert.equal((await worker.fetch(cross,e)).status,403);
 const huge=new Request('https://example.test/api/snapshot',{method:'PUT',headers:{'X-SDD-Publisher':'test-only'},body:'x'.repeat(2*1024*1024+1)});assert.equal((await worker.fetch(huge,e)).status,413);
});

test('dedicated snapshot contract and MCP envelope projection stay identical', () => {
 const standalone=JSON.parse(readFileSync(new URL('../contracts/sdd-dashboard.v1.schema.json',import.meta.url),'utf8'));
 const envelope=JSON.parse(readFileSync(new URL('../contracts/sdd-forge-mcp-tools.v1.schema.json',import.meta.url),'utf8'));
 for(const field of ['$schema','$id','title']) delete standalone[field];
 assert.deepEqual(envelope.$defs.dashboardSnapshotData.properties.snapshot,standalone);
});

test('health publication is private, ordered and separate from task data', async () => {
 const rows=new Map();const e={SDD_PUBLISHER_TOKEN:'test-only',BUCKET:{async get(k){const v=rows.get(k);return v?{etag:'1',json:async()=>JSON.parse(v),text:async()=>v}:null},async put(k,v){rows.set(k,v);return {etag:'1'}}}};
 const h={schema:'sdd-monitor/v1',observedAt:'2026-01-01T00:00:00Z',state:'running',publisherVersion:'a'.repeat(12),collectorVersion:'b'.repeat(12),lastPublishAt:null,lastSourceAt:null,consecutiveFailures:0,collectorRestarts:0,collectionMs:123};h.lastError=null;
 assert.equal(validHealth(h),true);assert.equal(validHealth({...h,state:'unknown'}),false);assert.equal(validHealth({...h,collectionMs:-1}),false);
 assert.equal((await worker.fetch(request('/api/health','GET',null,false),e)).status,401);
 assert.equal((await worker.fetch(request('/api/health'),e)).status,503);
 assert.equal((await worker.fetch(request('/api/health','PUT',h),e)).status,200);
 assert.equal((await worker.fetch(request('/api/health','PUT',h),e)).status,409);
 assert.deepEqual(await(await worker.fetch(request('/api/health'),e)).json(),h);
 assert.equal((await(await worker.fetch(request('/api/dashboard'),e)).json()).data,null);
 const visitor=new Request('https://example.test/api/health',{method:'PUT',headers:{'oai-authenticated-user-id':'viewer'},body:JSON.stringify(h)});
 assert.equal((await worker.fetch(visitor,e)).status,403);
});

test('observations share snapshot CAS, remain private and cannot be supplied by publishers',async()=>{
 const e=env();const now=new Date().toISOString();const s={...snapshot(),attemptedAt:now,checkedAt:now,lastSuccessAt:now,changedAt:now};
 s.data.features=[{id:'demo',phase:'blocked',nextCommand:'',warnings:[]}];
 s.data.tasks=[{key:'demo:T-1',id:'T-1',feature:'demo',title:'Observed',body:'',source:'specs/demo/tasks.md',status:'Blocked',approval:'Approved',risk:'low',release:null,failures:[]}];
 assert.equal((await worker.fetch(request('/api/snapshot','PUT',{...s,_observations:{}}),e)).status,400);
 assert.equal((await worker.fetch(request('/api/snapshot','PUT',s),e)).status,200);
 const observations=await(await worker.fetch(request('/api/observations'),e)).json();assert.equal(observations.events.length,1);assert.equal(observations.events[0].notify,true);
 assert.equal((await worker.fetch(request('/api/observations','GET',null,false),e)).status,401);
 assert.equal((await worker.fetch(request('/api/snapshot','PUT',s),e)).status,409);
 assert.deepEqual((await(await worker.fetch(request('/api/observations'),e)).json()).events,observations.events);
 assert.equal('_observations' in await(await worker.fetch(request('/api/dashboard'),e)).json(),false);
});
