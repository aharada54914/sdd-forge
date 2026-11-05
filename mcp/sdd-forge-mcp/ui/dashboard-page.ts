/** Self-contained HTML shared by Sites, local preview and the Artifact adapter. */
export function dashboardPage(mode: 'http' | 'artifacts' = 'http'): string {
  return `<!doctype html><html lang="ja"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>SDD Forge — 開発状況</title><style>
:root{font:14px/1.6 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;color:#172b4d;background:#fff;--line:#dfe1e6;--blue:#0052cc;--muted:#5e6c84}*{box-sizing:border-box}body{margin:0}button,input,select{font:inherit}button,a,select{touch-action:manipulation}button{cursor:pointer}button:focus-visible,a:focus-visible,input:focus-visible,select:focus-visible{outline:3px solid #2684ff;outline-offset:2px}header{height:62px;border-bottom:1px solid var(--line);display:flex;align-items:center;padding:0 28px;gap:24px}.logo{font-size:20px;font-weight:750;color:#0747a6}.readonly{color:var(--muted);font-size:12px;margin-left:auto}.shell{display:grid;grid-template-columns:230px minmax(0,1fr);min-height:calc(100vh - 62px)}aside.sidebar{padding:30px 20px;background:#f4f5f7;border-right:1px solid var(--line)}.project-icon{background:#deebff;color:var(--blue);border-radius:8px;display:inline-grid;place-items:center;width:40px;height:40px;font-weight:800;margin-bottom:12px}.eyebrow{font-size:11px;font-weight:700;letter-spacing:.1em;color:var(--muted);text-transform:uppercase}.project{font-weight:650;overflow-wrap:anywhere;margin:4px 0 24px}label{display:block;font-size:12px;color:var(--muted)}select,input{border:1px solid var(--line);border-radius:5px;padding:9px;background:white;color:#172b4d;max-width:100%}.sidebar select{width:100%;margin-top:7px}.side-note{font-size:12px;color:var(--muted);margin-top:30px}main{padding:26px 34px;min-width:0}.breadcrumb{color:var(--muted);font-size:12px}h1{font-size:27px;letter-spacing:-.025em;margin:10px 0 20px}nav{display:flex;gap:24px;border-bottom:2px solid #ebecf0;overflow-x:auto}nav a{color:var(--muted);text-decoration:none;padding:11px 1px;white-space:nowrap;border-bottom:3px solid transparent;margin-bottom:-2px}nav a[aria-current=page]{color:var(--blue);border-color:var(--blue);font-weight:650}.toolbar{display:flex;gap:12px;margin:24px 0;flex-wrap:wrap}.toolbar input{width:260px}.refresh{background:#0052cc;color:white;border:0;border-radius:5px;padding:9px 16px;margin-left:auto}.banner{border:1px solid #b3dfcc;background:#eefaf4;color:#216e4e;border-radius:5px;padding:10px 14px;margin:20px 0 0;font-size:12px}.banner[data-state=stale]{background:#fff8e6;border-color:#ffe380;color:#7f5f01}.banner[data-state=error]{background:#fff1f0;border-color:#ffbdad;color:#ae2a19}.muted{color:var(--muted)}.metrics{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:16px;margin-bottom:24px}.metric{border:1px solid var(--line);border-radius:8px;padding:20px}.metric strong{display:block;font-size:32px;line-height:1.5}.panel{border:1px solid var(--line);border-radius:8px;padding:20px;margin-bottom:20px}h2{font-size:17px;margin:0 0 16px}h3{font-size:14px;margin:0 0 12px}.board{display:grid;grid-template-columns:repeat(5,minmax(180px,1fr));gap:14px;overflow-x:auto;padding-bottom:14px}.column{background:#f4f5f7;border-radius:7px;padding:12px;min-height:280px}.column h2{font-size:12px;color:var(--muted);margin:4px 0 16px}.card{display:block;text-align:left;background:white;border:1px solid #ebecf0;border-radius:5px;padding:14px;width:100%;margin-bottom:10px;box-shadow:0 1px 2px #091e4214;color:inherit}.card:hover{border-color:#85b8ff}.card-title{display:block;margin:7px 0 12px;font-size:13px;overflow-wrap:anywhere}.key{font-size:11px;color:var(--muted)}.badge{display:inline-block;font-size:11px;font-weight:650;padding:2px 7px;border-radius:4px;background:#ebecf0;white-space:nowrap}.badge[data-status="In Progress"]{color:#0747a6;background:#deebff}.badge[data-status="Done"]{color:#216e4e;background:#dcfff1}.badge[data-status="Implementation Complete"]{color:#5e4db2;background:#eae6ff}.badge[data-status="Blocked"]{color:#ae2a19;background:#ffebe6}.table-wrap{overflow:auto}table{border-collapse:collapse;width:100%;text-align:left;font-size:13px}th{font-size:11px;color:var(--muted);font-weight:650}th,td{padding:12px 10px;border-bottom:1px solid #ebecf0}td button{border:0;background:none;color:#0052cc;text-align:left;min-height:32px}.empty{padding:40px 20px;text-align:center;color:var(--muted);border:1px dashed var(--line);border-radius:8px}.phase{display:grid;grid-template-columns:minmax(150px,1fr) minmax(180px,2fr);gap:20px;padding:12px 0;border-bottom:1px solid #ebecf0}.phase small{display:block}.track{display:flex;gap:3px;align-items:center}.segment{height:14px;flex:1;background:#ebecf0;border-radius:3px}.segment.active{background:#579dff}.segment.done{background:#4bce97}progress{width:100%;accent-color:#0052cc}dialog{position:fixed;inset:0 0 0 auto;margin:0;width:min(640px,100%);height:100%;max-height:100%;max-width:100%;border:0;border-left:1px solid var(--line);padding:28px;box-shadow:-8px 0 30px #091e4226}dialog::backdrop{background:#091e4244}dialog .close{float:right;border:0;background:#f4f5f7;border-radius:5px;padding:8px 12px}dialog h2{padding-top:20px;font-size:22px}pre{white-space:pre-wrap;overflow-wrap:anywhere;font:12px/1.8 ui-monospace,monospace;background:#f4f5f7;padding:16px;border-radius:6px}.issue-warning{color:#ae2a19;font-size:12px}footer{margin-top:28px;font-size:11px;color:var(--muted)}@media(max-width:760px){.shell{grid-template-columns:1fr}.sidebar{display:none}main{padding:20px 16px}.metrics{grid-template-columns:repeat(2,1fr)}nav{gap:20px}.toolbar input{width:100%}.refresh{margin-left:0}.phase{grid-template-columns:1fr}.mobile-feature{display:block!important}}.mobile-feature{display:none}[hidden]{display:none!important}
</style></head><body><header><span class="logo">▰ SDD Forge</span><span class="muted">プロジェクト</span><span class="readonly">読み取り専用</span></header><div class="shell"><aside class="sidebar"><div class="project-icon">SF</div><div class="eyebrow">開発プロジェクト</div><div class="project" id="project">接続待ち</div><label>開発テーマ<select id="feature"><option value="">すべての開発テーマ</option></select></label><p class="side-note">プロジェクトに登録された仕様・タスクを表示します。<br>実装が終わっても、品質確認が済むまでは完了になりません。</p></aside><main><div class="breadcrumb">プロジェクト / <span id="crumb">SDD Forge</span></div><h1 id="title">概要</h1><nav aria-label="プロジェクトのビュー" id="tabs"></nav><div class="banner" id="freshness" role="status" data-state="stale">データを確認しています…</div><div class="toolbar"><input id="search" type="search" aria-label="課題を検索" placeholder="課題キー・タイトル・本文で検索"><select id="filter" aria-label="状態で絞り込み"><option value="">すべての状態</option></select><select id="mobile-feature" class="mobile-feature" aria-label="開発テーマ"><option value="">すべての開発テーマ</option></select><button class="refresh" id="refresh">更新</button></div><div id="content" aria-live="polite"></div><footer>表示内容は記録に基づきます。実装済み・検証待ち、完了、公開済みはそれぞれ別の状態です。</footer></main></div><dialog id="detail" aria-labelledby="detail-title"><button class="close" id="close">閉じる ×</button><div id="detail-content"></div></dialog><script>
const MODE = ${JSON.stringify(mode)};
const VIEWS = { overview: "概要", timeline: "タイムライン", backlog: "バックログ", board: "ボード", list: "一覧", releases: "リリース" };
const STATES = ["Planned", "In Progress", "Blocked", "Implementation Complete", "Done"];
const LABELS = { "Planned": "予定", "In Progress": "進行中", "Blocked": "対応待ち・進行停止", "Implementation Complete": "実装済み・検証待ち", "Done": "完了（台帳上）", "Draft": "承認待ち", "Approved": "承認済み", "Rejected": "却下", "low": "低", "medium": "中", "high": "高", "critical": "最重要", "unknown": "未確認" };
// Display aliases only: canonical phases, commands and identifiers stay unchanged.
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
const FEATURE_NAMES = {
  "a9-interrupted-review-recovery": "中断したレビューの再開",
  "agent-cost-context-isolation": "AIの選定費用と作業情報の分離",
  "bootstrap-interviewer-enhancement": "要件ヒアリングと設計資料の充実",
  "ci-mcp": "自動テストの実行結果の確認",
  "claude-workflow-compatibility": "Claudeでの開発手順の互換性改善",
  "cross-model-verification": "複数のAIによる独立検証",
  "design-sync-consent": "デザイン共有時の承認",
  "design-sync-scan": "デザイン共有前の機密情報チェック",
  "design-sync-standing-consent": "デザイン共有の承認方針設定",
  "epic-136-phase1-guards": "保護対象への不正な変更の防止",
  "epic-136-phase1-rce": "承認情報を悪用したコード実行の防止",
  "epic-136-phase2-gates": "承認・品質確認ルールの統一",
  "epic-136-phase3": "自動テストと継続的検証の強化",
  "epic-136-phase4-docs": "検証の失敗時対応と運用文書の整備",
  "epic-136-phase4-mcp": "観測データの取得失敗の明確化",
  "epic-159-pillar-a": "レビュー反復回数の制御と検証",
  "epic-159-pillar-a2": "レビュー停止条件と検証範囲の補完",
  "epic-159-pillar-b": "公開前のテスト合格確認",
  "epic-159-pillar-c": "AIの能力と推論量の個別設定",
  "epic-159-pillar-d": "AIの能力情報の更新",
  "epic-189-a1-project-context": "プロジェクト設定と承認記録の整備",
  "epic-190-a2-capability-registry": "必要な開発能力・確認基準の一元管理",
  "epic-191-a3-path-ownership": "変更ファイルの担当範囲と確認漏れの検出",
  "epic-192-a4-facet-manifest": "必要な確認項目の一覧化",
  "epic-193-a5-capability-resolver": "プロジェクトに必要な確認項目の判定",
  "epic-194-a6-lite-integration": "簡易開発フローへの確認基準の適用",
  "epic-195-a7-compatibility": "既存の開発手順との互換性検証",
  "epic-196-a8-integration": "複数の実行環境での結合検証",
  "epic-197-a9-dogfood": "開発基盤の自社プロジェクトでの試用",
  "evidence-deep-verify": "完了を裏付ける証拠の詳細確認",
  "local-env-mcp": "ローカル開発環境の状態確認",
  "mcp-readonly-preflight": "観測機能の読み取り専用動作の事前確認",
  "p0-hardening": "最優先の運用上の問題の修正",
  "quality-loop-fixes": "品質確認フローの不具合修正",
  "review-cross-critique": "レビュー担当者間の相互検証",
  "risk-adaptive-layer": "リスクに応じた検証強度の調整",
  "sdd-diagnose": "不具合の原因調査と修正計画",
  "sdd-domain": "業務の構造と用語の整理",
  "sdd-domain-concept-contract": "業務概念の定義と境界の整理",
  "sdd-domain-concept-test": "新しい機能と業務概念の整合確認",
  "sdd-domain-multitarget": "開発手順の対象システム拡張",
  "sdd-forge-mcp": "開発状況を読み取る観測機能",
  "sdd-forge-refactor": "開発基盤の内部構造の整理",
  "sdd-lite": "小規模な変更向けの簡易開発",
  "second-approval-mask": "重要な変更の二重承認への対応",
  "shared-review-launch-repair": "レビュー実行環境の不具合修正",
  "uninstall-workflow": "開発基盤の削除手順の整備",
  "workflow-state-integrity": "工程・承認記録の整合性確認",
};
function featureName(id) {
  return snapshot?.data?.project === "sdd-forge" && Object.hasOwn(FEATURE_NAMES, id) ? FEATURE_NAMES[id] : id;
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
function filtered() {
  return (snapshot?.data?.tasks || []).filter((t) => (!feature || t.feature === feature) && (!filter || t.status === filter) && (!query || (featureName(t.feature) + " " + t.key + " " + t.title + " " + t.body).toLowerCase().includes(query.toLowerCase())));
}
function freshness() {
  const s = snapshot;
  const date = (value) => value ? new Date(value).toLocaleString("ja-JP") : "未確認";
  const stale = !s?.checkedAt || Date.now() - Date.parse(s.checkedAt) > 6e4;
  const error = transportError || s?.error;
  const b = $("freshness");
  b.dataset.state = error ? "error" : stale ? "stale" : "live";
  b.textContent = (error ? "取得失敗: " + error : stale ? "更新確認が停止しています" : "接続中・正本を確認済み") + " ｜ 最終確認 " + date(s?.checkedAt) + " ｜ 内容更新 " + date(s?.changedAt) + (error ? " ｜ 最後の正常取得 " + date(s?.lastSuccessAt) : "");
}
function options(node, items, selected, all, label = valueLabel) {
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
  renderDetail();
  if (!$("detail").open) $("detail").showModal();
}
function renderDetail() {
  const box = $("detail-content");
  box.replaceChildren();
  const task = snapshot?.data?.tasks.find((t) => t.key === detailKey);
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
  for (const failure of task.failures) box.append(el("p", failure, "issue-warning"));
  box.append(el("pre", task.body));
}
function card(task) {
  const b = el("button", void 0, "card");
  b.append(el("span", featureName(task.feature) + " / " + task.id, "key"), el("span", task.title, "card-title"), badge(task.status));
  if (task.failures.length) b.append(el("div", "状態・証拠に要確認事項あり", "issue-warning"));
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
    snapshot = next;
    transportError = "";
    syncFilters();
    render();
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
$("close").onclick = () => $("detail").close();
window.addEventListener("hashchange", render);
document.addEventListener("visibilitychange", () => {
  freshness();
  if (!document.hidden) refresh();
});
setInterval(freshness, 1e3);
setInterval(refresh, 5e3);
render();
refresh();
</script></body></html>`;
}
