import { test } from 'node:test';
import assert from 'node:assert/strict';
import { request } from 'node:http';
import { connect } from 'node:net';
import { startStatusView } from '../src/status-view.js';
import { makeTempSddRoot, writeFile } from './test-helpers.js';

interface TestNode {
  id: string; value: string; textContent: string; hidden: boolean; disabled: boolean; children: TestNode[];
  onclick?: () => Promise<void>; onchange?: () => Promise<void>;
  replaceChildren(): void; append(child: TestNode): void;
}
function makeDocument() {
  const elements = new Map<string, TestNode>();
  const element = (id: string): TestNode => { const value = elements.get(id); assert.ok(value); return value; };
  const node = (id = ''): TestNode => ({
    id, value: '', textContent: '', hidden: false, disabled: false, children: [],
    replaceChildren() { this.children = []; this.value = ''; },
    append(child) { this.children.push(child); if (id === 'feature' && !this.value) this.value = child.value; },
  });
  for (const id of ['feature','error','result','progress','headline','reason','next','command','copy','copy-result','steps','raw','refresh']) elements.set(id, node(id));
  return { element, document: { getElementById: element, createElement: () => node() } };
}

test('local status view exposes fresh guarded state and rejects untrusted requests', async () => {
  const fixture=makeTempSddRoot('status-view');
  writeFile(fixture.dir,'AGENTS.md','# AGENTS\n\n## Active Spec Directories\n\n- specs/example/\n');
  writeFile(fixture.dir,'specs/example/requirements.md','# Requirements\nSpec-Review-Status: Pending\n');
  writeFile(fixture.dir,'specs/example/design.md','# Design\nImpl-Review-Status: Pending\n');
  const {server,url}=await startStatusView(fixture.root);
  try {
    const address=server.address();
    assert.ok(address && typeof address !== 'string');
    assert.equal(address.address,'127.0.0.1');
    const malformed = await new Promise<string>((resolve,reject)=>{
      const socket=connect(address.port,'127.0.0.1');let response='';
      socket.setEncoding('utf8');socket.setTimeout(3000,()=>socket.destroy(new Error('request timed out')));
      socket.on('connect',()=>socket.write(`GET http://[ HTTP/1.1\r\nHost: 127.0.0.1:${address.port}\r\nConnection: close\r\n\r\n`));
      socket.on('data',chunk=>{response+=chunk});socket.on('end',()=>resolve(response));socket.on('error',reject);
    });
    assert.match(malformed,/^HTTP\/1\.1 400 /);
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

test('indeterminate next step still shows known spec status and unknown later phases', async () => {
  const { runInNewContext } = await import('node:vm');
  const fixture=makeTempSddRoot('status-view-indeterminate');
  writeFile(fixture.dir,'specs/example/requirements.md','# Requirements\nSpec-Review-Status: Passed\n');
  const view=await startStatusView(fixture.root);
  try {
    const html=await (await fetch(view.url)).text();
    const script=html.match(/<script>([\s\S]*?)<\/script>/)?.[1];assert.ok(script);
    const state=await (await fetch(new URL('api/status?feature=example',view.url))).json() as {next:{ok:boolean}};
    assert.equal(state.next.ok,false);
    const { element, document } = makeDocument();
    const fetchMock=async (path: string)=>({ok:true,json:async()=>path==='api/features'?{ok:true,data:{specs:[{feature:'example'}]}}:state});
    runInNewContext(script,{document,fetch:fetchMock,encodeURIComponent,AbortSignal,navigator:{clipboard:{writeText:async()=>{}}}});
    await new Promise(resolve=>setImmediate(resolve));
    assert.match(element('error').textContent,/次の工程を判断できません/);
    assert.equal(element('result').hidden,false);assert.equal(element('progress').hidden,false);
    assert.equal(element('copy').hidden,true);assert.equal(element('command').textContent,'');
    assert.ok(element('steps').children.some(row=>row.children.some(span=>span.textContent==='レビュー済み')));
    assert.ok(element('steps').children.some(row=>row.children.some(span=>span.textContent==='状態未確認')));
    for(const label of ['タスクのレビュー','タスクの承認','品質ゲート（タスクごと）']) assert.ok(element('steps').children.some(row=>row.children.some(span=>span.textContent===label)));
  } finally { await new Promise<void>((resolve,reject)=>view.server.close(e=>e?reject(e):resolve()));fixture.cleanup(); }
});

 test('a late feature refresh cannot overwrite the newest selection', async () => {
  const { runInNewContext } = await import('node:vm');
  const fixture = makeTempSddRoot('status-view-race');
  const view = await startStatusView(fixture.root);
  try {
    const html = await (await fetch(view.url)).text();
    const script = html.match(/<script>([\s\S]*?)<\/script>/)?.[1]; assert.ok(script);
    const { element, document } = makeDocument();
    const pending: Array<(value: { ok: boolean; json: () => Promise<unknown> }) => void> = [];
    const fetchMock = (path: string, init: { signal: AbortSignal }) => {
      assert.ok(init.signal instanceof AbortSignal);
      assert.equal(path, 'api/features');
      return new Promise(resolve => pending.push(resolve));
    };
    runInNewContext(script, { document, fetch: fetchMock, encodeURIComponent, AbortSignal });
    const refresh = element('refresh').onclick; assert.ok(refresh);
    const newest = refresh();
    assert.equal(pending.length, 2);
    const first = pending.shift(); const second = pending.shift(); assert.ok(first); assert.ok(second);
    second({ ok: true, json: async () => ({ ok: true, data: { specs: [] } }) });
    await newest;
    first({ ok: true, json: async () => ({ ok: true, data: { specs: [{ feature: 'obsolete' }] } }) });
    await new Promise(resolve => setImmediate(resolve));
    assert.equal(element('feature').children.length, 0);
    assert.equal(element('error').textContent, '表示できる機能がありません。');
  } finally {
    await new Promise<void>((resolve, reject) => view.server.close(error => error ? reject(error) : resolve()));
    fixture.cleanup();
  }
});
