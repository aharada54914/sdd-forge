import { choiceButton } from './components.mjs';
const $ = id => document.getElementById(id);
const node = (tag, text) => { const n = document.createElement(tag); n.textContent = text; return n; };
const labels = { open:'要回答', answered:'回答済み・受領待ち', received:'受領済み', expired:'期限切れ', queued:'実行待ち', running:'実行中', succeeded:'成功', failed:'失敗', cancelled:'取消済み', uncertain:'結果不明・確認が必要' };
let state = null, busy = false, readBusy = false, signature = '', lastSuccess = 0;
async function read() {
  if (readBusy || busy) return;
  readBusy = true;
  try {
    if (document.body.dataset.mode === 'artifacts' && typeof window.sddHubRead !== 'function') throw new Error('Artifactの読取コネクタが未接続です');
    const next = window.sddHubRead ? await window.sddHubRead() : await response(await fetch('/api/hub', { cache:'no-store' }));
    if (next?.schema !== 'sdd-session-hub/v1' || !Array.isArray(next.questions)) throw new Error('invalid-response');
    state = next; lastSuccess = Date.now(); $('login').hidden = true; render();
    $('notice').textContent = '最終確認: ' + new Date(lastSuccess).toLocaleTimeString(); $('notice').className = '';
  } catch (error) {
    $('notice').textContent = '接続できません。' + (lastSuccess ? '最後の正常データを表示中（' + new Date(lastSuccess).toLocaleTimeString() + '）' : '') + ' ' + error.message;
    $('notice').className = 'error';
    if (error.message === 'authentication-required' && location.hostname === '127.0.0.1') $('login').hidden = false;
  } finally { readBusy = false; }
}
async function response(r) { const data = await r.json(); if (!r.ok) throw new Error(data.error || 'request-failed'); return data; }
async function action(action, input) {
  if (busy || !state) return;
  busy = true;
  try {
    if (document.body.dataset.mode === 'artifacts' && typeof window.sddHubAction !== 'function') throw new Error('Artifactの操作コネクタが未接続です');
    const command = { project:state.project, expectedRevision:state.revision, action, input };
    const next = window.sddHubAction ? await window.sddHubAction(command) : await response(await fetch('/api/hub/command', { method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify(command) }));
    state = next; render(); $('notice').textContent = '保存しました';
  } catch (error) { $('notice').textContent = '保存できません: ' + error.message + '。更新して内容を確認してください。'; $('notice').className = 'error'; }
  finally { busy = false; }
}
function render() {
  const nextSignature = JSON.stringify([state, $('filter').value]);
  if (signature === nextSignature) return;
  signature = nextSignature;
  const focusId = document.activeElement?.dataset?.control;
  const questions = state.questions.filter(q => $('filter').value === 'all' || q.status === $('filter').value);
  $('questions').replaceChildren(...questions.map(q => {
    const card = node('article', ''); card.append(node('h3', q.title), node('p', (state.sessions.find(s => s.id === q.sessionId)?.label || q.sessionId) + ' · ' + labels[q.status]));
    const choices = node('div', ''); choices.className = 'actions';
    for (const option of q.options) {
      const button = choiceButton({ label:option.label, variant:option.preview?.variant, selected:q.answer?.optionId === option.id,
        disabled:q.status !== 'open', onSelect:() => action('answer', { id:q.id, optionId:option.id, requestId:crypto.randomUUID() }) });
      button.dataset.control = q.id + '-' + option.id; choices.append(button);
      if (option.preview) { const details = node('details',''); details.append(node('summary','部品の情報'),node('small',option.preview.storyId + ' / v' + option.preview.version)); choices.append(details); }
    }
    card.append(choices, node('small', '回答期限: ' + new Date(q.expiresAt).toLocaleString())); return card;
  }));
  if (!questions.length) $('questions').append(node('p', '該当する質問はありません'));
  const selected = $('session').value;
  $('session').replaceChildren(...state.sessions.map(s => { const o = node('option', s.label); o.value = s.id; return o; }));
  if (state.sessions.some(s => s.id === selected)) $('session').value = selected;
  $('sessions').replaceChildren(...state.sessions.map(s => node('li', s.label + ' · 回答取得方式（受領確認あり）')));
  $('away-state').textContent = state.away ? '有効：ワーカーが空き資源を確認して実行します' : '無効：新規着手を停止中';
  $('away').textContent = state.away ? '離席モードを無効にする' : '離席モードを有効にする'; $('away').setAttribute('aria-pressed', String(state.away));
  $('jobs').replaceChildren(...state.jobs.map(j => {
    const item = node('li', j.title + ' · ' + labels[j.status] + (j.cancelRequested ? ' · 停止要求済み' : ''));
    if (['queued','running'].includes(j.status) && !j.cancelRequested) {
      const b = node('button', '停止'); b.onclick = () => action('cancel', {id:j.id}); item.append(' ', b);
    }
    return item;
  }));
  const v = state.verification;
  $('verification').replaceChildren(node('p', v ? (v.status === 'ready' && Date.now() - v.checkedAt <= 60000 ? '検証結果: 必須項目を通過（取得時点）' : v.status === 'ready' ? '検証結果: 再確認が必要（取得から60秒経過）' : '検証結果: マージを保留') : '検証結果が未登録です'));
  if (v) $('verification').append(node('code', v.head), node('p', v.reasons.join(' / ') || '不足項目なし'), node('small', '確認時刻: ' + new Date(v.checkedAt).toLocaleString() + ' / 証跡SHA-256: ' + v.evidenceSha256));
  if (focusId) [...document.querySelectorAll('[data-control]')].find(n => n.dataset.control === focusId)?.focus({preventScroll:true});
}
$('refresh').onclick = read;
$('filter').onchange = render;
$('away').onclick = () => action('away', { enabled:!state.away });
$('enqueue').onsubmit = event => { event.preventDefault(); action('enqueue', {id:crypto.randomUUID(), sessionId:$('session').value, commandId:$('command').value, title:$('job-title').value, approved:true}); };
$('login').onsubmit = async event => {
  event.preventDefault();
  try { await response(await fetch('/api/hub/login', {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({token:$('token').value})})); $('token').value = ''; await read(); }
  catch { $('notice').textContent = '接続できません'; }
};
read(); setInterval(read, 5000);
