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
    const address=server.address();
    assert.ok(address && typeof address !== 'string');
    assert.equal(address.address,'127.0.0.1');
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
    const elements=new Map<string, any>();
    const node=(id=''): any=>({id,value:'',textContent:'',hidden:false,disabled:false,children:[] as any[],replaceChildren(){this.children=[];this.value=''},append(child: any){this.children.push(child);if(id==='feature'&&!this.value)this.value=child.value}});
    for(const id of ['feature','error','result','progress','headline','reason','next','command','copy','copy-result','steps','raw','refresh'])elements.set(id,node(id));
    const document={getElementById:(id: string)=>elements.get(id),createElement:()=>node()};
    const fetchMock=async (path: string)=>({ok:true,json:async()=>path==='api/features'?{ok:true,data:{specs:[{feature:'example'}]}}:state});
    runInNewContext(script,{document,fetch:fetchMock,encodeURIComponent,navigator:{clipboard:{writeText:async()=>{}}}});
    await new Promise(resolve=>setImmediate(resolve));
    assert.match(elements.get('error').textContent,/次の工程を判断できません/);
    assert.equal(elements.get('result').hidden,false);assert.equal(elements.get('progress').hidden,false);
    assert.equal(elements.get('copy').hidden,true);assert.equal(elements.get('command').textContent,'');
    assert.ok(elements.get('steps').children.some((row: any)=>row.children.some((span: any)=>span.textContent==='レビュー済み')));
    assert.ok(elements.get('steps').children.some((row: any)=>row.children.some((span: any)=>span.textContent==='状態未確認')));
  } finally { await new Promise<void>((resolve,reject)=>view.server.close(e=>e?reject(e):resolve()));fixture.cleanup(); }
});
