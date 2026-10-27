import { test } from 'node:test';
import assert from 'node:assert/strict';
import { request } from 'node:http';
import { startStatusView } from '../src/status-view.js';
import { makeTempSddRoot, writeFile } from './test-helpers.js';

test('local status view exposes fresh guarded state and rejects untrusted requests', async () => {
  const fixture=makeTempSddRoot('status-view');
  writeFile(fixture.dir,'AGENTS.md','# AGENTS\n\n## Active Spec Directories\n\n- specs/example/\n');
  writeFile(fixture.dir,'specs/example/requirements.md','# Requirements\nSpec-Review-Status: Pending\n');
  writeFile(fixture.dir,'specs/example/design.md','# Design\nImpl-Review-Status: Pending\n');
  const {server,url}=await startStatusView(fixture.root);
  try {
    const page=await fetch(url);assert.equal(page.status,200);
    assert.match(page.headers.get('content-security-policy') ?? '',/frame-ancestors 'none'/);
    assert.match(await page.text(),/品質ゲート/);
    const status=new URL('api/status?feature=example',url);
    const first=await (await fetch(status)).json() as {next:{ok:boolean;data:{phase:string}}};
    assert.equal(first.next.data.phase,'spec-review');
    writeFile(fixture.dir,'specs/example/requirements.md','# Requirements\nSpec-Review-Status: Passed\n');
    const updated=await (await fetch(status)).json() as {next:{data:{phase:string}}};
    assert.notEqual(updated.next.data.phase,'spec-review');
    assert.equal((await fetch(new URL('api/status?feature=..%2Fsecret',url))).status,400);
    assert.equal((await fetch(new URL('/wrong/api/features',url))).status,404);
    assert.equal((await fetch(url,{headers:{Origin:'https://attacker.example'}})).status,403);
    const hostileHost = await new Promise<number>((resolve,reject)=>{const req=request(url,{headers:{Host:'attacker.example'}},res=>{res.resume();resolve(res.statusCode ?? 0)});req.on('error',reject);req.end()});
    assert.equal(hostileHost,403);
    assert.equal((await fetch(url,{method:'POST'})).status,403);
  } finally { await new Promise<void>((resolve,reject)=>server.close(e=>e?reject(e):resolve()));fixture.cleanup(); }
});
