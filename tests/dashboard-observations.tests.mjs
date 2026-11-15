import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {observe,observationView} from '../mcp/sdd-forge-mcp/src/dashboard/observations.js';
const task=(status='Planned')=>({key:'demo:T-1',feature:'demo',title:'作業',status,approval:'Approved',risk:'low',release:null,failures:[]});
const snap=(sec=0,tasks=[task()])=>({schema:'sdd-dashboard/v1',revision:'a',attemptedAt:new Date(1700000000000+sec*1000).toISOString(),checkedAt:new Date(1700000000000+sec*1000).toISOString(),error:null,data:{tasks}});
const accept=(old,next)=>({...next,_observations:observe(old,next)});
test('observation code shipped with plugin exactly matches MCP source',()=>assert.equal(readFileSync(new URL('../plugins/sdd-ship/status-site/observations.js',import.meta.url),'utf8'),readFileSync(new URL('../mcp/sdd-forge-mcp/src/dashboard/observations.js',import.meta.url),'utf8')));
test('heartbeat deduplicates events; changes, removal and continuous dwell are observed',()=>{
 const first=accept(null,snap());const heartbeat=accept(first,snap(5));
 assert.equal(heartbeat._observations.events.length,1);assert.equal(heartbeat._observations.tracking['demo:T-1'].since,first.checkedAt);
 const blocked=accept(heartbeat,snap(10,[task('Blocked')]));assert.equal(blocked._observations.events.at(-1).notify,true);assert.equal(blocked._observations.tracking['demo:T-1'].since,blocked.checkedAt);
 const removed=accept(blocked,snap(15,[]));assert.equal(removed._observations.events.at(-1).kind,'removed');assert.equal(Object.keys(removed._observations.tracking).length,0);
});
test('failure freezes dwell, recovery and long gaps reset continuity without inferred actors',()=>{
 const first=accept(null,snap());const fail=accept(first,{...snap(5),error:'broken',checkedAt:first.checkedAt});
 const twice=accept(fail,{...fail,attemptedAt:snap(10).attemptedAt});assert.equal(twice._observations.events.length,2);assert.deepEqual(twice._observations.tracking,first._observations.tracking);
 const recovered=accept(twice,snap(15));assert.equal(recovered._observations.tracking['demo:T-1'].since,recovered.checkedAt);assert.equal(recovered._observations.events.at(-1).kind,'observation-gap');
 const gap=accept(recovered,snap(100));assert.equal(gap._observations.tracking['demo:T-1'].reason,'gap');assert.equal(observationView(gap,Date.parse(gap.checkedAt)+61000).sourceStale,true);
 assert.equal('actor' in gap._observations.events[0],false);
});
test('history retains only latest 200 events and 30 days on read and write',()=>{
 let state=null;for(let i=0;i<250;i++)state=accept(state,snap(i,[task(i%2?'Blocked':'Planned')]));
 assert.equal(state._observations.events.length,200);
 assert.equal(observationView(state,Date.parse(state.checkedAt)+31*86400000).events.length,0);
 state=accept(state,snap(32*86400));assert.equal(state._observations.events.length,2);
});
