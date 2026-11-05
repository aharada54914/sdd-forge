import { createHash } from "node:crypto";

/** Self-contained HTML shared by Sites, local preview and the Artifact adapter. */
export function dashboardPage(mode: 'http' | 'artifacts' = 'http'): string {
  const page = `<!doctype html><html lang="ja"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>SDD Forge — 開発状況</title><style>
:root{font:16px/1.7 -apple-system,BlinkMacSystemFont,"Segoe UI","Noto Sans JP",sans-serif;color:#172b4d;background:#fff;--line:#767676;--blue:#0031d8;--muted:#505f79;--space-1:8px;--space-2:16px;--space-3:24px;--space-4:32px;--radius-control:8px;--radius-panel:12px;--success:#216e4e;--warning:#705400;--error:#ae2a19}
*{box-sizing:border-box}body{margin:0}button,input,select{font:inherit}button,a,select{touch-action:manipulation}button{cursor:pointer}button,a,input,select,summary{scroll-margin:16px}button:focus-visible,a:focus-visible,input:focus-visible,select:focus-visible,summary:focus-visible{outline:4px solid #000;outline-offset:3px;box-shadow:0 0 0 3px #ffd43d}button{min-height:44px}a,summary{min-height:44px}summary{cursor:pointer;padding:8px 0}a{display:inline-flex;align-items:center}header{min-height:72px;border-bottom:1px solid #dfe1e6;display:flex;align-items:center;padding:16px 24px;gap:24px;flex-wrap:wrap}.logo{font-size:24px;font-weight:700;color:#0747a6}.readonly{color:var(--muted);font-size:14px;margin-left:auto}.shell{display:grid;grid-template-columns:minmax(240px,280px) minmax(0,1fr);min-height:calc(100vh - 72px)}aside.sidebar{padding:32px 24px;background:#f4f5f7;border-right:1px solid #dfe1e6}.project-icon{background:#deebff;color:var(--blue);border-radius:8px;display:inline-grid;place-items:center;width:48px;height:48px;font-weight:700;margin-bottom:16px}.eyebrow{font-size:14px;font-weight:700;color:var(--muted)}.project{font-weight:700;overflow-wrap:anywhere;margin:8px 0 24px}label{display:block;font-size:16px;color:var(--muted)}select,input{border:1px solid var(--line);border-radius:var(--radius-control);padding:8px;min-height:44px;background:white;color:#172b4d;max-width:100%}.sidebar select{width:100%;margin-top:8px}.side-note{font-size:14px;color:var(--muted);margin-top:32px}main{padding:24px 32px;min-width:0}.breadcrumb{color:var(--muted);font-size:14px;overflow-wrap:anywhere}h1{font-size:32px;margin:8px 0 24px}nav{display:flex;gap:24px;border-bottom:2px solid #dfe1e6;flex-wrap:wrap}nav a{color:var(--muted);text-decoration:none;padding:8px 0;border-bottom:3px solid transparent}nav a[aria-current=page]{color:var(--blue);border-color:var(--blue);font-weight:700}.toolbar{display:flex;gap:16px;margin:24px 0;flex-wrap:wrap;align-items:end}.toolbar input{width:100%}.toolbar label{flex:1;min-width:min(240px,100%)}.refresh,.pause{background:var(--blue);color:white;border:1px solid var(--blue);border-radius:var(--radius-control);padding:8px 16px}.pause{background:white;color:var(--blue)}.banner{border:1px solid #216e4e;background:#eefaf4;color:var(--success);border-radius:8px;padding:16px;margin-top:24px;font-size:16px;overflow-wrap:anywhere}.banner[data-state=stale],.banner[data-state=paused]{background:#fff8e6;border-color:#705400;color:var(--warning)}.banner[data-state=error]{background:#fff1f0;border-color:#ae2a19;color:var(--error)}.muted{color:var(--muted)}.metrics{display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:24px;margin-bottom:24px}.metric{border:1px solid var(--line);border-radius:12px;padding:16px;background:white;color:inherit;text-align:left}.metric strong{display:block;font-size:32px;line-height:1.5}.panel{border:1px solid #dfe1e6;border-radius:12px;padding:24px;margin-bottom:24px}h2{font-size:24px;margin:0 0 16px}h3{font-size:20px;margin:0 0 16px}.board{display:grid;grid-template-columns:repeat(5,minmax(240px,1fr));gap:32px;overflow-x:auto;padding:8px 8px 16px}.column{background:#f4f5f7;border-radius:12px;padding:16px;min-height:160px}.column h2{font-size:16px;color:var(--muted);margin:0 0 16px}.card{display:block;text-align:left;background:white;border:1px solid var(--line);border-radius:8px;padding:16px;width:100%;margin-bottom:16px;color:inherit}.card:hover{border-color:var(--blue)}.card-title{display:block;margin:8px 0 16px;font-size:16px;overflow-wrap:anywhere}.key{font-size:14px;color:var(--muted);overflow-wrap:anywhere}.badge{display:inline-block;font-size:14px;font-weight:700;padding:4px 8px;border-radius:8px;background:#ebecf0;overflow-wrap:anywhere}.badge[data-status="In Progress"]{color:#0747a6;background:#deebff}.badge[data-status="Done"]{color:#216e4e;background:#dcfff1}.badge[data-status="Implementation Complete"]{color:#5e4db2;background:#eae6ff}.badge[data-status="Blocked"]{color:#ae2a19;background:#ffebe6}.table-wrap{overflow:auto}table{border-collapse:collapse;width:100%;text-align:left;font-size:16px}th{font-size:16px;color:var(--muted);font-weight:700}th,td{padding:16px;border-bottom:1px solid #dfe1e6}td button{border:0;background:none;color:var(--blue);text-align:left;text-decoration:underline;min-height:44px;min-width:44px}.empty{padding:32px 24px;text-align:center;color:var(--muted);border:1px dashed var(--line);border-radius:12px}.phase{display:grid;grid-template-columns:minmax(160px,1fr) minmax(240px,2fr);gap:32px;padding:16px 0;border-bottom:1px solid #dfe1e6;overflow-wrap:anywhere}.phase small{display:block;font-size:14px}.track{display:flex;gap:4px;align-items:center}.segment{height:16px;flex:1;background:#ebecf0;border-radius:4px}.segment.active{background:#0052cc}.segment.done{background:#216e4e}progress{width:100%;accent-color:#0031d8}dialog{position:fixed;inset:0 0 0 auto;margin:0;width:min(720px,100%);height:100%;max-height:100%;max-width:100%;border:0;border-left:1px solid var(--line);padding:24px;box-shadow:-8px 0 32px #091e4240}dialog::backdrop{background:#091e4266}dialog .close{float:right;border:1px solid var(--line);background:#f4f5f7;border-radius:8px;padding:8px 16px}dialog h2{padding-top:24px;font-size:24px}pre{white-space:pre-wrap;overflow-wrap:anywhere;font:14px/1.8 ui-monospace,monospace;background:#f4f5f7;padding:16px;border-radius:8px}.issue-warning{color:var(--error);font-size:14px}footer{margin-top:32px;font-size:14px;color:var(--muted)}.skip{position:absolute;left:16px;top:-100px;background:white;z-index:10;padding:8px}.skip:focus{top:8px}.sr-only{position:absolute;width:1px;height:1px;overflow:hidden;clip-path:inset(50%)}.monitor{font-size:14px;overflow-wrap:anywhere}.mobile-feature{display:none}[hidden]{display:none!important}@media(max-width:1100px){.shell{grid-template-columns:1fr}.sidebar{display:none}main{padding:24px 16px}.mobile-feature{display:block}.phase{grid-template-columns:1fr;gap:16px}.board{grid-template-columns:1fr;overflow:visible;padding:0}.column{min-height:0}.toolbar{align-items:stretch}.toolbar>*{max-width:100%}header{gap:16px;padding:16px}.metrics{grid-template-columns:repeat(auto-fit,minmax(128px,1fr))}.panel{padding:16px}h1{font-size:28px}}
</style></head><body><a class="skip" href="#main">本文へ移動</a><header><span class="logo">▰ SDD Forge</span><span class="muted">プロジェクト</span><span class="readonly">読み取り専用</span></header><div class="shell"><aside class="sidebar"><div class="project-icon">SF</div><div class="eyebrow">開発プロジェクト</div><div class="project" id="project">接続待ち</div><label>開発テーマ<select id="feature"><option value="">すべての開発テーマ</option></select></label><p class="side-note">プロジェクトに登録された仕様・タスクを表示します。<br>実装が終わっても、品質確認が済むまでは完了になりません。</p></aside><main id="main" tabindex="-1"><div class="breadcrumb">プロジェクト / <span id="crumb">SDD Forge</span></div><h1 id="title" tabindex="-1">概要</h1><nav aria-label="プロジェクトのビュー" id="tabs"></nav><div class="banner" id="freshness" data-state="stale">データを確認しています…</div><div id="announcer" class="sr-only" role="status" aria-live="polite" aria-atomic="true"></div><div class="toolbar"><label>課題を検索<input id="search" type="search" aria-label="課題を検索" placeholder="課題キー・タイトル・本文で検索"></label><select id="filter" aria-label="状態で絞り込み"><option value="">すべての状態</option></select><select id="mobile-feature" class="mobile-feature" aria-label="開発テーマ"><option value="">すべての開発テーマ</option></select><button class="pause" id="pause" aria-pressed="false">表示更新を一時停止</button><button class="refresh" id="refresh">今すぐ更新</button></div><div id="content" aria-live="polite"></div><details id="activity" class="panel"><summary id="activity-summary">通知・変更履歴</summary><p id="activity-state" role="status">履歴を確認しています</p><p>観測できた変化を記録します。実際の操作時刻・操作した人は推測しません。直近30日・最大200件です。</p><button id="acknowledge" class="pause">表示中の通知を確認済みにする</button><ol id="activity-events"></ol></details><details class="monitor"><summary>観測基盤の稼働状況</summary><p id="monitor-status">稼働情報を確認しています</p></details><footer>表示内容は記録に基づきます。実装済み・検証待ち、完了、公開済みはそれぞれ別の状態です。</footer></main></div><dialog id="detail" aria-labelledby="detail-title"><button class="close" id="close">閉じる ×</button><div id="detail-content"></div></dialog><script>
const PAGE_VERSION = "__SDD_PAGE_VERSION__";
const MODE = ${JSON.stringify(mode)};
const VIEWS = { overview: "概要", timeline: "タイムライン", backlog: "バックログ", board: "ボード", list: "一覧", releases: "リリース" };
const STATES = ["Planned", "In Progress", "Blocked", "Implementation Complete", "Done"];
const LABELS = { "Planned": "予定", "In Progress": "進行中", "Blocked": "対応待ち・進行停止", "Implementation Complete": "実装済み・検証待ち", "Done": "完了（台帳上）", "Draft": "承認待ち", "Approved": "承認済み", "Rejected": "却下", "low": "低", "medium": "中", "high": "高", "critical": "最重要", "unknown": "未確認" };
// Display aliases only: canonical phases, commands and identifiers stay unchanged.
const HEALTH_LABELS = {starting:"起動中",running:"稼働中", "collection-failed":"収集停止・再起動待ち", "source-failed":"正本の読み取り失敗", "auth-failed":"認証失敗・設定確認が必要", "data-rejected":"送信データの確認が必要",conflict:"更新の競合", "http-failed":"送信先の応答異常", "transport-failed":"通信障害・再試行中"};
const PHASES = {
  "phase1-not-started": ["要件・設計の作成前", "実現したい内容と設計を整理します"],
  "spec-review": ["要件の確認", "要件の抜け・矛盾を確認します"],
  "impl-review": ["設計・実装方針の確認", "実現方法と設計の妥当性を確認します"],
  "phase2-not-started": ["作業計画の作成前", "仕様を実行可能なタスクに分けます"],
  "task-review": ["作業計画の確認", "作業範囲・順序・確認方法を確認します"],
  "approval-gate": ["管理者の承認待ち", "担当者が内容を確認し、着手するタスクを承認してください"],
  "implementation": ["開発・実装", "承認済みのタスクを進めます"],
  "quality-gate": ["品質・完了条件の確認", "テスト結果と証拠を確認し、完了を判定します"],
  "blocked": ["問題の解消待ち", "進行を妨げている問題の解消が必要です"],
  "done": ["対象作業の完了", "承認済みタスクは台帳上すべて完了しています"],
  "cannot-determine": ["状況の確認が必要", "記録の不足や不整合を確認してください"],
  "unknown": ["状況の確認が必要", "工程を判断できません。記録を確認してください"]
};
function featureName(id) {
  return snapshot?.data?.features.find(f => f.id === id)?.displayName || id;
}
function valueLabel(value) {
  if (Object.hasOwn(LABELS, value)) return LABELS[value];
  return value.replace(/^Approved(?=\\s|$)/, "承認済み");
}
const $ = (id) => document.getElementById(id);
const el = (tag, text, cls) => {
  const n = document.createElement(tag);
  if (text !== void 0) n.textContent = text;
  if (cls) n.className = cls;
  return n;
};
let latest = null, paused = false, attention = "", detailSignature = "", announcedState = "", health = null, healthError = "", lastContact = null;
let observations = null, observationError = "", activitySignature = "";
let acknowledged = new Set();
const ackKey = "sdd-notifications:" + location.pathname;
try { const saved = JSON.parse(localStorage.getItem(ackKey) || "[]"); if (Array.isArray(saved)) acknowledged = new Set(saved.filter(x => typeof x === "string").slice(-200)); } catch {}
let snapshot = null, transportError = "", inFlight = false, detailKey = null;
const prefsKey = "sdd-dashboard:" + location.pathname;
let prefs = {};
try {
  const saved = JSON.parse(localStorage.getItem(prefsKey) || "{}");
  prefs = saved && typeof saved === "object" && !Array.isArray(saved) ? saved : {};
} catch {
}
let feature = typeof prefs.feature === "string" ? prefs.feature : "", filter = typeof prefs.filter === "string" ? prefs.filter : "", query = typeof prefs.query === "string" ? prefs.query : "";
$("search").value = query;
function save() {
  try {
    localStorage.setItem(prefsKey, JSON.stringify({ feature, filter, query }));
  } catch {
  }
}
function view() {
  const v = location.hash.slice(1);
  return Object.hasOwn(VIEWS, v) ? v : "overview";
}
function badge(status) {
  const b = el("span", LABELS[status] || status, "badge");
  b.dataset.status = status;
  return b;
}
function needs(t, kind) {
  return kind === "approval" ? t.approval === "Draft" : kind === "blocked" ? t.status === "Blocked" : kind === "quality" ? t.status === "Implementation Complete" : kind === "inconsistent" ? t.failures.length > 0 : true;
}
function filtered() {
  return (snapshot?.data?.tasks || []).filter((t) => (!feature || t.feature === feature) && (!filter || t.status === filter) && needs(t, attention) && (!query || (featureName(t.feature) + " " + t.key + " " + t.title + " " + t.body).toLowerCase().includes(query.toLowerCase())));
}
function freshness() {
  const s = snapshot;
  const date = (value) => value ? new Date(value).toLocaleString("ja-JP") : "未確認";
  const stale = !s?.checkedAt || Date.now() - Date.parse(s.checkedAt) > 6e4;
  const error = transportError || latest?.error;
  const state = error ? "error" : paused ? "paused" : stale ? "stale" : "live";
  const headline = error ? "× 取得失敗: " + error : paused ? "Ⅱ 表示更新を一時停止中" : stale ? "! 更新確認が停止しています" : "✓ 正本の取得は正常です";
  const b = $("freshness");
  b.dataset.state = state;
  b.textContent = headline + " ｜ 表示データの確認時刻 " + date(s?.checkedAt) + " ｜ 内容更新 " + date(s?.changedAt) + " ｜ 表示先との通信 " + (transportError ? "失敗" : lastContact ? "接続済み" : "未確認") + (error ? " ｜ 最後の正常取得 " + date(s?.lastSuccessAt) : "");
  if (announcedState !== state) { $("announcer").textContent = headline; announcedState = state; }
  const healthStale = !health?.observedAt || Date.now() - Date.parse(health.observedAt) > 60000;
  $("monitor-status").textContent = "画面版: " + PAGE_VERSION + " ｜ " + (health ? "収集版: " + health.collectorVersion + " ｜ 送信版: " + health.publisherVersion + " ｜ 監督: " + (healthStale ? "更新停止・要確認" : HEALTH_LABELS[health.state] || "状態を確認できません") + " ｜ 最終送信成功: " + date(health.lastPublishAt) + " ｜ 連続失敗: " + health.consecutiveFailures + " ｜ 収集時間: " + health.collectionMs + "ms ｜ 収集再起動: " + health.collectorRestarts + (healthError ? " ｜ " + healthError : "") : healthError || "稼働情報は未取得です");
}
function options(node, items, selected, all, label = valueLabel) {
  if (node.dataset.options === JSON.stringify([items, all])) { node.value = selected; return; }
  node.dataset.options = JSON.stringify([items, all]);
  node.replaceChildren();
  const first = el("option", all);
  first.value = "";
  node.append(first);
  for (const item of items) {
    const o = el("option", label(item));
    o.value = item;
    node.append(o);
  }
  node.value = selected;
}
function syncFilters() {
  const features = (snapshot?.data?.features || []).map((f) => f.id);
  if (feature && !features.includes(feature)) feature = "";
  const states = [...new Set((snapshot?.data?.tasks || []).filter((t) => !feature || t.feature === feature).map((t) => t.status))];
  if (filter && !states.includes(filter)) filter = "";
  options($("feature"), features, feature, "すべての開発テーマ", featureName);
  options($("mobile-feature"), features, feature, "すべての開発テーマ", featureName);
  options($("filter"), states, filter, "すべての状態");
  save();
}
function openDetail(key) {
  detailKey = key;
  detailSignature = "";
  renderDetail();
  if (!$("detail").open) $("detail").showModal();
}
function renderDetail() {
  const box = $("detail-content");
  const task = snapshot?.data?.tasks.find((t) => t.key === detailKey);
  const tracking = observations?.snapshotRevision === snapshot?.revision ? observations?.tracking?.[detailKey] : null;
  const signature = JSON.stringify([task,tracking]);
  if (detailSignature === signature) return;
  detailSignature = signature;
  const oldScroll = $("detail").scrollTop;
  box.replaceChildren();
  if (!task) {
    const title = el("h2", "課題が見つかりません");
    title.id = "detail-title";
    box.append(title);
    return;
  }
  box.append(el("div", task.key, "key"));
  const title = el("h2", task.title);
  title.id = "detail-title";
  box.append(title, badge(task.status), el("p", "承認: " + valueLabel(task.approval) + " / リスク: " + valueLabel(task.risk)), el("p", "正本: " + task.source, "muted"));
  if (tracking) box.append(el("p", "この状態を連続観測: " + Math.max(0,Math.floor((Date.parse(tracking.lastObservedAt)-Date.parse(tracking.since))/60000)) + "分（" + new Date(tracking.since).toLocaleString("ja-JP") + "から最終確認まで）。観測中断時は計測を再開します。", "muted"));
  for (const failure of task.failures) box.append(el("p", failure, "issue-warning"));
  box.append(el("pre", task.body));
  $("detail").scrollTop = oldScroll;
}
function card(task) {
  const b = el("button", void 0, "card");
  b.append(el("span", featureName(task.feature) + " / " + task.id, "key"), el("span", task.title, "card-title"), badge(task.status));
  if (task.failures.length) b.append(el("div", "状態・証拠に要確認事項あり", "issue-warning"));
  b.dataset.focusKey = task.key;
  b.onclick = () => openDetail(task.key);
  return b;
}
function list(tasks) {
  const wrap = el("div", void 0, "table-wrap");
  const table = el("table");
  const head = el("tr");
  for (const label of ["課題", "概要", "状態", "承認", "リスク"]) head.append(el("th", label));
  const thead = el("thead");
  thead.append(head);
  table.append(thead);
  const body = el("tbody");
  for (const t of tasks) {
    const row = el("tr");
    const key = el("td");
    const link = el("button", t.id);
    link.dataset.focusKey = t.key;
    link.onclick = () => openDetail(t.key);
    key.append(link);
    row.append(key, el("td", t.title));
    const state = el("td");
    state.append(badge(t.status));
    row.append(state, el("td", valueLabel(t.approval)), el("td", valueLabel(t.risk)));
    body.append(row);
  }
  table.append(body);
  wrap.append(table);
  return wrap;
}
function render() {
  const v = view();
  $("title").textContent = VIEWS[v];
  for (const a of $("tabs").children) a.setAttribute("aria-current", a.hash === "#" + v ? "page" : "false");
  const c = $("content");
  const activeKey = (document.activeElement?.dataset.focusKey || document.activeElement?.closest("details")?.dataset.focusKey);
  const opened = new Set([...c.querySelectorAll("details[open]")].map(n => n.dataset.feature));
  const scroll = {x:window.scrollX,y:window.scrollY,board:c.querySelector(".board")?.scrollLeft || 0};
  c.replaceChildren();
  freshness();
  if (!snapshot?.data) {
    c.append(el("div", "まだデータを取得できていません。接続と収集プロセスを確認してください。", "empty"));
    return;
  }
  const data = snapshot.data;
  const tasks = filtered();
  $("project").textContent = data.project;
  $("crumb").textContent = data.project;
  if (v === "overview") {
    const actionPanel = el("section", undefined, "panel");
    actionPanel.append(el("h2", "管理者の対応が必要な課題"));
    const actions = el("div", undefined, "metrics");
    const candidates = data.tasks.filter(t => !feature || t.feature === feature);
    for (const [kind, label] of [["approval","承認待ち"],["blocked","進行停止"],["quality","品質確認待ち"],["inconsistent","記録の不整合"]]) {
      const action = el("button", label + " · " + candidates.filter(t => needs(t,kind)).length, "metric");
      action.dataset.focusKey = "action:" + kind;
      action.onclick = () => { attention = kind; query = ""; filter = ""; $("search").value = ""; syncFilters(); location.hash = "list"; render(); };
      actions.append(action);
    }
    actionPanel.append(actions); c.append(actionPanel);
    const metrics = el("div", void 0, "metrics");
    for (const [label, count] of [["課題", tasks.length], ["承認待ち", tasks.filter((t) => t.approval === "Draft").length], ["対応待ち・進行停止", tasks.filter((t) => t.status === "Blocked").length], ["完了（台帳上）", tasks.filter((t) => t.status === "Done").length]]) {
      const m = el("div", void 0, "metric");
      m.append(el("span", label, "muted"), el("strong", String(count)));
      metrics.append(m);
    }
    c.append(metrics);
    const p = el("section", void 0, "panel");
    p.append(el("h2", "開発テーマごとの進捗と次の対応"));
    for (const f of data.features.filter((f2) => !feature || f2.id === feature)) {
      const r = el("div", void 0, "phase");
      const name = el("div", featureName(f.id));
      name.title = f.id;
      r.append(name);
      const phase = Object.hasOwn(PHASES, f.phase) ? PHASES[f.phase] : ["状況の確認が必要", "未対応の工程です。担当者に確認してください"];
      const next = el("div", phase[0]);
      next.append(el("small", phase[1], "muted"));
      const technical = el("details");
      technical.dataset.feature = f.id;
      technical.open = opened.has(f.id);
      technical.dataset.focusKey = "details:" + f.id;
      technical.append(el("summary", "技術情報（担当者向け）"), el("pre", "識別子: " + f.id + "\\n工程: " + f.phase + "\\n操作: " + (f.nextCommand || "未確認")));
      next.append(technical);
      for (const w of f.warnings) next.append(el("small", w, "issue-warning"));
      r.append(next);
      p.append(r);
    }
    c.append(p);
  } else if (v === "board") {
    const board = el("div", void 0, "board");
    for (const state of [...STATES, ...new Set(tasks.map((t) => t.status).filter((s) => !STATES.includes(s)))]) {
      const column = el("section", void 0, "column");
      const items = tasks.filter((t) => t.status === state);
      column.append(el("h2", (LABELS[state] || state) + " · " + items.length));
      for (const t of items) column.append(card(t));
      board.append(column);
    }
    c.append(board);
  } else if (v === "list") c.append(tasks.length ? list(tasks) : el("div", "条件に一致する課題はありません。", "empty"));
  else if (v === "backlog") {
    for (const [label, predicate] of [["承認待ち", (t) => t.approval === "Draft"], ["予定", (t) => t.approval !== "Draft" && t.status === "Planned"], ["進行中・要対応", (t) => t.approval !== "Draft" && !["Planned", "Done"].includes(t.status)]]) {
      const p = el("section", void 0, "panel");
      const items = tasks.filter(predicate);
      p.append(el("h2", label + " · " + items.length));
      p.append(items.length ? list(items) : el("p", "該当する課題はありません。", "muted"));
      c.append(p);
    }
  } else if (v === "timeline") {
    c.append(el("p", "日付軸を使わず、予定 → 進行中 → 実装済み・検証待ち → 完了（台帳上） の段階を表示します。", "muted"));
    for (const t of tasks) {
      const r = el("div", void 0, "phase");
      const b = el("button", t.id + " " + t.title, "card");
      b.dataset.focusKey = t.key;
      b.onclick = () => openDetail(t.key);
      r.append(b);
      const right = el("div");
      right.append(badge(t.status));
      const track = el("div", void 0, "track");
      const steps = ["Planned", "In Progress", "Implementation Complete", "Done"];
      const current = steps.indexOf(t.status);
      steps.forEach((step, i) => {
        const s = el("span", void 0, "segment" + (i <= current ? t.status === "Done" ? " done" : " active" : ""));
        s.title = LABELS[step];
        track.append(s);
      });
      right.append(track);
      r.append(right);
      c.append(r);
    }
    if (!tasks.length) c.append(el("p", "表示する課題はありません。", "empty"));
  } else if (v === "releases") {
    const groups = [...new Set(tasks.map((t) => t.release).filter(Boolean))];
    if (!groups.length) c.append(el("div", "リリース予定は未登録です。タスクにリリース予定が登録されると表示されます。", "empty"));
    for (const name of groups) {
      const items = tasks.filter((t) => t.release === name);
      const done = items.filter((t) => t.status === "Done").length;
      const p = el("section", void 0, "panel");
      p.append(el("h2", name), el("p", done + " / " + items.length + " 件完了（台帳上）・公開状況は未確認", "muted"));
      const bar = el("progress");
      bar.max = items.length;
      bar.value = done;
      bar.setAttribute("aria-label", name + "のタスク進捗");
      p.append(bar, list(items));
      c.append(p);
    }
    const unassigned = tasks.filter((t) => !t.release).length;
    c.append(el("p", "リリース未割り当て: " + unassigned + "件", "muted"));
  }
  if (attention) {
    const clear = el("button", "対応事項の絞り込みを解除", "pause");
    clear.dataset.focusKey = "clear-attention";
    clear.onclick = () => { attention = ""; render(); };
    c.prepend(clear);
  }
  if (activeKey) {
    const target = [...c.querySelectorAll("[data-focus-key]")].find(n => n.dataset.focusKey === activeKey);
    if (target) (target.tagName === "DETAILS" ? target.querySelector("summary") : target).focus({preventScroll:true});
    else $("title").focus({preventScroll:true});
  }
  if (c.querySelector(".board")) c.querySelector(".board").scrollLeft = scroll.board;
  window.scrollTo(scroll.x,scroll.y);
  if ($("detail").open) renderDetail();
}
function validSnapshot(s) {
  if (!s || s.schema !== "sdd-dashboard/v1" || typeof s.revision !== "string" || !Number.isFinite(Date.parse(s.attemptedAt)) || Date.parse(s.attemptedAt) > Date.now() + 3e4 || !(s.error === null || typeof s.error === "string")) return false;
  for (const k of ["checkedAt", "changedAt", "lastSuccessAt"]) if (s[k] !== null && (!Number.isFinite(Date.parse(s[k])) || Date.parse(s[k]) > Date.parse(s.attemptedAt))) return false;
  if (s.data === null) return typeof s.error === "string" && s.checkedAt === null;
  if (!s.checkedAt || !s.lastSuccessAt || !s.changedAt || typeof s.data?.project !== "string" || !Array.isArray(s.data.features) || !Array.isArray(s.data.tasks)) return false;
  if (s.data.features.length > 1e3 || s.data.tasks.length > 1e4) return false;
  return s.data.features.every((f) => f && ["id", "phase", "nextCommand"].every((k) => typeof f[k] === "string") && Array.isArray(f.warnings) && f.warnings.every((w) => typeof w === "string")) && s.data.tasks.every((t) => t && ["key", "id", "feature", "title", "body", "status", "approval", "risk", "source"].every((k) => typeof t[k] === "string") && (t.release === null || typeof t.release === "string") && Array.isArray(t.failures) && t.failures.every((f) => typeof f === "string"));
}
async function readArtifact() {
  let timer;
  try {
    return await Promise.race([window.sddDashboardRead(), new Promise((_, reject) => {
      timer = setTimeout(() => reject(Error("コネクタの応答がタイムアウトしました")), 15e3);
    })]);
  } finally {
    clearTimeout(timer);
  }
}
async function refresh() {
  if (inFlight) return;
  inFlight = true;
  $("refresh").disabled = true;
  try {
    let next;
    if (MODE === "artifacts") {
      if (typeof window.sddDashboardRead !== "function") throw Error("Artifactsの読取コネクタが未接続です");
      next = await readArtifact();
    } else {
      const response = await fetch("api/dashboard", { cache: "no-store", signal: AbortSignal.timeout(15e3) });
      if (!response.ok) throw Error("HTTP " + response.status);
      next = await response.json();
    }
    if (!validSnapshot(next)) throw Error("表示データの形式が不正です");
    if (snapshot && Date.parse(next.attemptedAt) < Date.parse(snapshot.attemptedAt)) return;
    latest = next;
    lastContact = new Date().toISOString();
    transportError = "";
    if (!paused) {
      const changed = !snapshot || snapshot.revision !== next.revision || Boolean(snapshot.data) !== Boolean(next.data);
      snapshot = next;
      if (changed) { syncFilters(); render(); }
    }
    await readObservations();
    freshness();
  } catch (e) {
    transportError = e.message || "接続できません";
    freshness();
    if (!snapshot) render();
  } finally {
    inFlight = false;
    $("refresh").disabled = false;
  }
}
for (const [id, title] of Object.entries(VIEWS)) {
  const a = el("a", title);
  a.href = "#" + id;
  $("tabs").append(a);
}
$("search").oninput = () => {
  query = $("search").value;
  save();
  render();
};
$("filter").onchange = () => {
  filter = $("filter").value;
  save();
  render();
};
for (const id of ["feature", "mobile-feature"]) $(id).onchange = () => {
  feature = $(id).value;
  syncFilters();
  render();
};
$("refresh").onclick = refresh;
$("pause").onclick = () => {
  paused = !paused;
  $("pause").setAttribute("aria-pressed",String(paused));
  if (paused) $("acknowledge").disabled = true;
  $("pause").textContent = paused ? "表示更新を再開" : "表示更新を一時停止";
  if (!paused && latest) { snapshot = latest; syncFilters(); render(); renderActivity(); }
  freshness();
};
const EVENT_LABELS = {"first-observed":"観測を開始","added":"課題を追加確認","changed":"変更を確認","removed":"課題の削除を確認","source-failed":"正本の読み込み失敗","source-recovered":"正本の読み込み復旧","observation-gap":"観測中断後に再開"};
const FIELD_LABELS = {status:"状態",approval:"承認",risk:"リスク",release:"リリース",validation:"検証エラー件数",source:"正本",continuity:"観測"};
function validObservations(o) {
  return o?.schema === "sdd-observations/v1" && typeof o.snapshotRevision === "string" && (o.observedAt === null || Number.isFinite(Date.parse(o.observedAt))) && typeof o.sourceError === "boolean" && typeof o.sourceStale === "boolean" && Array.isArray(o.events) && o.events.length <= 200 && o.tracking && typeof o.tracking === "object" && o.events.every(e => e && typeof e.id === "string" && Object.hasOwn(EVENT_LABELS,e.kind) && Object.hasOwn(FIELD_LABELS,e.field) && Number.isFinite(Date.parse(e.observedAt)) && typeof e.title === "string" && typeof e.notify === "boolean" && [e.before,e.after].every(v => v === null || typeof v === "string" || typeof v === "number")) && Object.values(o.tracking).every(t => t && Number.isFinite(Date.parse(t.since)) && Number.isFinite(Date.parse(t.lastObservedAt)) && Date.parse(t.lastObservedAt) >= Date.parse(t.since));
}
function renderActivity() {
  if (paused) return;
  const ready = observations && observations.observedAt && observations.snapshotRevision === snapshot?.revision;
  $("activity-state").textContent = observationError || (!ready ? "現在の表示に対応する履歴を確認しています" : observations.sourceError ? "正本の読み込み失敗中。経過時間の計測は停止しています。" : (observations.sourceStale || !snapshot?.checkedAt || Date.now()-Date.parse(snapshot.checkedAt)>60000) ? "最終確認が古くなっています。未観測の変化は分かりません。" : "最終観測: " + new Date(observations.observedAt).toLocaleString("ja-JP"));
  $("activity-events").hidden = !ready || !!observationError;
  if (!ready || observationError) { $("acknowledge").disabled = true; return; }
  const events = observations.events;
  const unread = events.filter(e => e.notify && !acknowledged.has(e.id));
  $("activity-summary").textContent = "通知・変更履歴（未確認 " + unread.length + "件）";
  $("acknowledge").disabled = !unread.length;
  const signature = JSON.stringify([events,[...acknowledged]]);
  if (activitySignature !== signature) {
    activitySignature = signature;
    $("activity-events").replaceChildren();
    for (const event of [...events].reverse()) {
      const label = v => v === null ? "なし" : ({ok:"正常",failed:"失敗",unknown:"不明",resumed:"再開"}[v] || valueLabel(String(v)));
      const li = el("li", (event.notify && !acknowledged.has(event.id) ? "未確認・" : "") + new Date(event.observedAt).toLocaleString("ja-JP") + " — " + EVENT_LABELS[event.kind] + " / " + FIELD_LABELS[event.field] + ": " + label(event.before) + " → " + label(event.after) + (event.title ? " / " + event.title : ""));
      if (event.key && snapshot.data?.tasks.some(t => t.key === event.key)) { const button = el("button","課題の詳細"); button.onclick = () => openDetail(event.key); li.append(button); }
      $("activity-events").append(li);
    }
    if (!events.length) $("activity-events").append(el("li","この保持期間の変更記録はありません。"));
  }
  if ($("detail").open) renderDetail();
}
async function readObservations() {
  try {
    let o;
    if (MODE === "artifacts") {
      if (typeof window.sddDashboardObservations !== "function") throw Error("このArtifacts接続は履歴を提供していません");
      let timer; try { o = await Promise.race([window.sddDashboardObservations(),new Promise((_,reject) => {timer=setTimeout(() => reject(Error("履歴の取得がタイムアウトしました")),10000)})]); } finally {clearTimeout(timer);}
    } else {
      const r = await fetch("api/observations",{cache:"no-store",signal:AbortSignal.timeout(10000)});
      if (!r.ok) throw Error("変更履歴を取得できません");
      o = await r.json();
    }
    if (!validObservations(o)) throw Error("変更履歴の形式が不正です");
    observations = o; observationError = "";
  } catch (e) { observationError = e.message || "変更履歴を取得できません"; }
  renderActivity();
}
$("acknowledge").onclick = () => {
  if (paused || observationError || observations?.snapshotRevision !== snapshot?.revision) return;
  for (const e of observations?.events || []) if (e.notify) acknowledged.add(e.id);
  acknowledged = new Set([...acknowledged].slice(-200));
  try {localStorage.setItem(ackKey,JSON.stringify([...acknowledged]));} catch {}
  renderActivity();
};
async function readHealth() {
  if (MODE !== "http") { healthError = "この接続方式では収集プロセスの稼働情報を提供していません"; return; }
  try {
    const r = await fetch("api/health", {cache:"no-store",signal:AbortSignal.timeout(10000)});
    if (!r.ok) throw Error("稼働情報は未提供または取得できません");
    const h = await r.json();
    if (h.schema !== "sdd-monitor/v1" || !Number.isFinite(Date.parse(h.observedAt)) || Date.parse(h.observedAt) > Date.now()+30000 || !Object.hasOwn(HEALTH_LABELS,h.state) || !["collectorVersion","publisherVersion"].every(k => typeof h[k] === "string" && /^[a-f0-9]{12}$/.test(h[k])) || !["consecutiveFailures","collectorRestarts","collectionMs"].every(k => Number.isSafeInteger(h[k]) && h[k]>=0)) throw Error("稼働情報の形式が不正です");
    health = h; healthError = "";
  } catch { healthError = "稼働情報は未提供または取得できません"; }
  freshness();
}
setInterval(readHealth,15000);
readHealth();
$("close").onclick = () => $("detail").close();
$("detail").addEventListener("close", () => {
  // A source update may have replaced the button that originally opened the dialog.
  const trigger = [...$("content").querySelectorAll("[data-focus-key]")].find(n => n.dataset.focusKey === detailKey);
  (trigger || $("title")).focus({preventScroll:true});
});
window.addEventListener("hashchange", render);
document.addEventListener("visibilitychange", () => {
  freshness();
  if (!document.hidden) refresh();
});
setInterval(() => {freshness();renderActivity();}, 1e3);
setInterval(refresh, 5e3);
render();
refresh();
</script></body></html>`;
  return page.replace("__SDD_PAGE_VERSION__", createHash("sha256").update(page).digest("hex").slice(0, 12));
}
