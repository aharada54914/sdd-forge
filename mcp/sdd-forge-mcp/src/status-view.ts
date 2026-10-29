/** Optional local, read-only status view. Uses the same guarded operations as MCP. */
import { createServer, type Server } from 'node:http';
import { randomBytes, timingSafeEqual } from 'node:crypto';
import type { SddRoot } from './root.js';
import { getNextSddCommand, getSpecStatus, getTaskState, listActiveSpecs, validateFeature } from './tools/core.js';

const PAGE = `<!doctype html><html lang="ja"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>仕様とタスクの現在地 | sdd-forge</title><style>
:root{font-family:system-ui,-apple-system,sans-serif;color:#172c38;background:#f3f6f8;line-height:1.75}*{box-sizing:border-box}body{margin:0}header{background:white;border-bottom:1px solid #dce4e9}header div,main{max-width:850px;margin:auto;padding:20px 24px}h1{font-size:clamp(26px,5vw,36px)}h2{font-size:22px}section{background:white;border:1px solid #dce4e9;border-radius:14px;padding:24px;margin:20px 0}select,button{font:inherit;min-height:48px;border:1px solid #8b9da9;border-radius:8px;padding:10px;background:white;color:#172c38}select{width:100%;margin-top:8px}button{cursor:pointer}button:focus-visible,select:focus-visible,summary:focus-visible{outline:3px solid #1269ce;outline-offset:3px}.next{background:#eef5fc;border-radius:10px;padding:20px}.muted{color:#526675}ul{padding:0;list-style:none}li{border-bottom:1px solid #e7edf1;padding:12px 0;display:flex;justify-content:space-between;gap:12px}li span:last-child{text-align:right}pre{white-space:pre-wrap;overflow-wrap:anywhere;max-height:20em;overflow:auto;background:#f3f6f8;padding:12px}summary{cursor:pointer;min-height:48px}code{overflow-wrap:anywhere}[hidden]{display:none!important}@media(max-width:540px){main,header div{padding-left:20px;padding-right:20px}section{padding:20px}}
</style></head><body><header><div><strong>sdd-forge</strong> <span class="muted">・読み取り専用</span></div></header><main><h1>仕様とタスクの現在地</h1><p>どこまで進んだか、次に何をすればよいかを確認できます。</p><p class="muted">現在のプロジェクトから取得します。更新ボタンで再取得できます。</p><label for="feature">確認する機能</label><select id="feature" disabled><option>読み込み中</option></select><p><button id="refresh" type="button">状態を更新</button></p><p id="error" role="alert"></p><section id="result" hidden><h2 id="headline"></h2><p id="reason"></p><div class="next"><strong>次にすること</strong><p id="next"></p><p><code id="command"></code></p><button id="copy" type="button">コマンドをコピー</button><p id="copy-result" role="status"></p><p class="muted">コマンドはこの画面から実行されません。</p></div></section><section id="progress" hidden><h2>工程ごとの状態</h2><p class="muted">状態未確認は、取得データだけでは実施状況が分からないことを示します。振り返りは条件に応じて実施します。</p><ul id="steps"></ul><details><summary>判断の根拠を見る</summary><pre id="raw"></pre></details></section><p class="muted">表示は読み取り専用です。タスクや承認は変更しません。</p></main><script>
const $=id=>document.getElementById(id);let requestId=0;const api=(path)=>fetch(path,{cache:'no-store'}).then(async r=>{if(!r.ok)throw Error('状態を取得できませんでした');return r.json()});
const explanations={'phase1-not-started':'要件ファイルをまだ確認できません。','spec-review':'要件のレビューが完了していません。','impl-review':'設計のレビューが完了していません。','phase2-not-started':'実装タスクをまだ確認できません。','task-review':'タスクのレビューが完了していません。','approval-gate':'承認済みのタスクがありません。','implementation':'承認済みの作業中または予定のタスクがあります。','quality-gate':'実装完了のタスクに品質確認が必要です。','done':'承認済みのタスクはすべてDoneです。','blocked':'ブロックされたタスクがあります。'};
const phases={'phase1-not-started':'仕様の準備が必要です','spec-review':'仕様レビューが必要です','impl-review':'設計レビューが必要です','phase2-not-started':'タスクの準備が必要です','task-review':'タスクレビューが必要です','approval-gate':'タスクの承認待ちです','implementation':'実装を進められます','quality-gate':'品質ゲートが必要です','done':'承認済みタスクが完了しています','blocked':'ブロッカーを確認してください'};
function row(name,value){const li=document.createElement('li');for(const text of [name,value]){const span=document.createElement('span');span.textContent=text;li.append(span)}$('steps').append(li)}
async function show(){const f=$('feature').value;if(!f)return;const id=++requestId;$('error').textContent='';$('result').hidden=true;$('progress').hidden=true;try{const data=await api('api/status?feature='+encodeURIComponent(f));if(id!==requestId)return;const n=data.next;if(!n.ok)$('error').textContent='次の工程を判断できません: '+n.error.message;const p=n.ok?n.data.phase:'cannot-determine';$('headline').textContent=phases[p]||'状態を確認してください';$('reason').textContent=explanations[p]||'MCPの返却した工程を確認してください。';$('copy').hidden=p==='done'||!n.ok;$('copy-result').textContent='';$('next').textContent=!n.ok?'判断の根拠を確認し、状態を更新してください。':p==='done'?'MCPが案内する次の工程はありません。':'表示された手順を開発環境で確認してください。';$('command').textContent=n.ok?n.data.nextCommand:'';const spec=data.spec.ok?data.spec.data.artifacts:[];const status=name=>{const x=spec.find(a=>a.name===name);return !x?'状態未確認':!x.exists?'未作成または確認不可':({Passed:'レビュー済み',Pending:'レビュー待ち'}[x.reviewStatus]||x.reviewStatus||'状態未確認')};$('steps').replaceChildren();row('要件のレビュー',status('requirements'));row('設計のレビュー',status('design'));const tasks=spec.find(a=>a.name==='tasks');row('実装タスクの準備',!tasks?'状態未確認':tasks.exists?'ファイルあり':'未作成または確認不可');row('タスクのレビュー',status('tasks'));row('タスクの承認',p==='approval-gate'?'承認待ち':'状態未確認');row('実装',p==='implementation'?'現在の工程':'状態未確認');row('品質ゲート（タスクごと）',p==='quality-gate'?'現在の工程':'状態未確認');row('完了の確認','状態未確認');row('振り返り（条件あり）','状態未確認');$('raw').textContent=JSON.stringify(data,null,2);$('result').hidden=false;$('progress').hidden=false}catch(e){if(id===requestId)$('error').textContent='状態を取得できませんでした。更新を試してください。'}}
async function start(){try{const r=await api('api/features');if(!r.ok)throw Error(r.error.message);const selected=$('feature').value;$('feature').replaceChildren();for(const item of r.data.specs){const option=document.createElement('option');option.value=item.feature;option.textContent=item.feature;$('feature').append(option)}if(r.data.specs.some(item=>item.feature===selected))$('feature').value=selected;$('feature').disabled=false;if(r.data.specs.length)await show();else $('error').textContent='表示できる機能がありません。'}catch(e){$('error').textContent='機能一覧を取得できませんでした。プロジェクトの設定を確認してください。'}}$('feature').onchange=show;$('refresh').onclick=()=>start();$('copy').onclick=async()=>{try{await navigator.clipboard.writeText($('command').textContent);$('copy-result').textContent='コピーしました。開発環境に貼り付けてください。'}catch{$('copy-result').textContent='自動コピーできません。コマンドを選択してコピーしてください。'}};start();</script></body></html>`;

/** Bind only to loopback, with an unguessable session path and DNS-rebinding protection. */
export async function startStatusView(root: SddRoot): Promise<{server: Server; url: string}> {
  const token = randomBytes(32).toString('hex');
  let host = '';
  const server = createServer((req, res) => {
    const headers = { 'Cache-Control':'no-store', 'X-Content-Type-Options':'nosniff', 'Referrer-Policy':'no-referrer', 'Content-Security-Policy':"default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; connect-src 'self'; base-uri 'none'; frame-ancestors 'none'" };
    const send = (status: number, contentType: string, body: string) => {res.writeHead(status, {...headers,'Content-Type':contentType});res.end(body)};
    if (req.method !== 'GET' || req.headers.host !== host || (req.headers.origin && req.headers.origin !== `http://${host}`)) return send(403,'text/plain; charset=utf-8','Forbidden');
    let url: URL;
    try { url = new URL(req.url ?? '/', `http://${host}`); }
    catch { return send(400,'text/plain; charset=utf-8','Invalid request'); }
    const parts = url.pathname.split('/');
    const given = Buffer.from(parts[1] ?? ''); const expected = Buffer.from(token);
    if (given.length !== expected.length || !timingSafeEqual(given,expected)) return send(404,'text/plain; charset=utf-8','Not found');
    const route = parts.slice(2).join('/');
    if (route === '') return send(200,'text/html; charset=utf-8',PAGE);
    if (route === 'api/features') return send(200,'application/json; charset=utf-8',JSON.stringify(listActiveSpecs(root)));
    if (route === 'api/status') {
      const feature = url.searchParams.get('feature') ?? '';
      if (!validateFeature(feature).ok) return send(400,'application/json; charset=utf-8',JSON.stringify({error:'invalid feature'}));
      return send(200,'application/json; charset=utf-8',JSON.stringify({spec:getSpecStatus(root,feature),tasks:getTaskState(root,feature),next:getNextSddCommand(root,feature)}));
    }
    return send(404,'text/plain; charset=utf-8','Not found');
  });
  await new Promise<void>((resolve,reject)=>{server.once('error',reject);server.listen(0,'127.0.0.1',()=>{server.off('error',reject);resolve()})});
  const address=server.address(); if (!address || typeof address === 'string') throw new Error('Unable to determine status view port');
  host=`127.0.0.1:${address.port}`;
  return {server,url:`http://${host}/${token}/`};
}
