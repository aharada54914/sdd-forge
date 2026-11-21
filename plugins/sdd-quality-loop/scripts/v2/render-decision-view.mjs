#!/usr/bin/env node
/**
 * render-decision-view.mjs — Human-focused Decision View generator (SDD Forge v2).
 * Zero external dependencies — Node.js >= 20 LTS built-in modules only.
 *
 * Inspired by freee's Software Factory ("AI reads the exhaustive SSoT; humans see a
 * focused Decision View of Fact / Reason / Human Question across 4 decision types"):
 *   - 事業判断 (Business Decision)
 *   - 利用者挙動 (User Behavior)
 *   - 他チーム契約 (Cross-Team Contract)
 *   - 不可逆リスク (Irreversible Risk)
 *
 * Usage:
 *   node render-decision-view.mjs --feature <feature> [--root <dir>]
 *                                 [--format markdown|html] [--output <path>]
 */
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import {
  extractSpecIdentifiers,
  findProjectRoot,
  normalizeNewlines,
  toPosixPath,
} from './guardrails-lib.mjs';

export function parseOpenQuestions(markdownText) {
  const normalized = normalizeNewlines(markdownText || '');
  const items = [];
  const lines = normalized.split('\n');
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed.startsWith('|')) continue;
    const cells = trimmed
      .slice(1, trimmed.endsWith('|') ? -1 : undefined)
      .split('|')
      .map((c) => c.trim());
    if (cells.length < 6) continue;
    if (!/^OQ-\d+$/i.test(cells[0])) continue;
    // Skip placeholder template rows
    if (/^<.*>$/.test(cells[2])) continue;
    items.push({
      id: cells[0].toUpperCase(),
      category: cells[1] || '事業判断',
      fact: cells[2] || '',
      reason: cells[3] || '',
      question: cells[4] || '',
      status: cells[5] || 'Provisional',
      impactedTasks: (cells[6] || '')
        .split(/[,\s]+/)
        .map((t) => t.trim())
        .filter((t) => /^T-\d+/i.test(t)),
    });
  }
  return items;
}

export function parseAlternativesRejected(designText) {
  const normalized = normalizeNewlines(designText || '');
  const headingMatch = /^##[ \t]+.*(?:採らなかった設計|Alternatives Rejected).*$/im.exec(normalized);
  if (!headingMatch) return [];
  const rest = normalized.slice(headingMatch.index + headingMatch[0].length);
  const nextHeading = /^##[ \t]+\S/m.exec(rest);
  const section = nextHeading ? rest.slice(0, nextHeading.index) : rest;

  const items = [];
  for (const line of section.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed.startsWith('|')) continue;
    const cells = trimmed
      .slice(1, trimmed.endsWith('|') ? -1 : undefined)
      .split('|')
      .map((c) => c.trim());
    if (cells.length < 3) continue;
    if (/^(?:候補案|Option|Alternative|-+)$/i.test(cells[0]) || /^-+$/.test(cells[0])) continue;
    if (/^<.*>$/.test(cells[0]) || /^（?該当なし）?$/.test(cells[0])) continue;
    items.push({
      option: cells[0],
      reason: cells[1],
      revisitWhen: cells[2],
    });
  }
  return items;
}

export function parseTasksSummary(tasksText) {
  const normalized = normalizeNewlines(tasksText || '');
  const tasks = [];
  const headerRe = /^##[ \t]+(T-[A-Za-z0-9._-]+)[ \t]*(.*)$/gm;
  const matches = [...normalized.matchAll(headerRe)];
  for (let i = 0; i < matches.length; i += 1) {
    const m = matches[i];
    const start = m.index + m[0].length;
    const end = i + 1 < matches.length ? matches[i + 1].index : normalized.length;
    const block = normalized.slice(start, end);
    const approval = (block.match(/^[ \t]*Approval:[ \t]*(.+)$/m) || [])[1]?.trim() || 'Draft';
    const status = (block.match(/^[ \t]*Status:[ \t]*(.+)$/m) || [])[1]?.trim() || 'Planned';
    const risk = ((block.match(/^[ \t]*Risk:[ \t]*(.+)$/m) || [])[1]?.trim() || 'standard').toLowerCase();
    const acRefs = [...new Set((block.match(/\bAC-\d+\b/gi) || []).map((id) => id.toUpperCase()))];
    tasks.push({
      id: m[1],
      title: m[2].trim(),
      approval,
      status,
      risk,
      acRefs,
      block,
    });
  }
  return tasks;
}

export function detectDomains(combinedText) {
  const text = String(combinedText || '');
  const domains = new Set();
  if (/\b(?:PostgreSQL|MySQL|SQL Server|Azure SQL|Flyway|DACPAC|\.sqlproj|\.sql\b|migration|DDL|RLS)\b/i.test(text)) {
    domains.add('SQL');
  }
  if (/\b(?:AWS|CDK|CloudFormation|sdd-aws-cloud|CloudWatch|IAM)\b/i.test(text)) {
    domains.add('AWS');
  }
  if (/\b(?:Azure|Bicep|ARM|sdd-azure-cloud|Azure Monitor)\b/i.test(text)) {
    domains.add('Azure');
  }
  if (/\b(?:domain\/|Bounded-Context|domain-contract\.json|Aggregate|sdd-domain)\b/i.test(text)) {
    domains.add('DDD');
  }
  domains.add('Software');
  return [...domains];
}

export function buildDecisionViewData({ feature, projectRoot }) {
  const root = findProjectRoot(projectRoot);
  const featureDir = path.join(root, 'specs', feature);
  if (!fs.existsSync(featureDir)) {
    throw new Error(`Feature directory not found: specs/${feature}`);
  }

  const reqPath = path.join(featureDir, 'requirements.md');
  const designPath = path.join(featureDir, 'design.md');
  const tasksPath = path.join(featureDir, 'tasks.md');

  const reqText = fs.existsSync(reqPath) ? fs.readFileSync(reqPath, 'utf8') : '';
  const designText = fs.existsSync(designPath) ? fs.readFileSync(designPath, 'utf8') : '';
  const tasksText = fs.existsSync(tasksPath) ? fs.readFileSync(tasksPath, 'utf8') : '';

  const openQuestions = [...parseOpenQuestions(reqText), ...parseOpenQuestions(designText)];
  const alternativesRejected = parseAlternativesRejected(designText);
  const tasks = parseTasksSummary(tasksText);
  const identifiers = extractSpecIdentifiers(reqText);
  const reqIds = Object.keys(identifiers).filter((id) => id.startsWith('REQ-'));
  const acIds = Object.keys(identifiers).filter((id) => id.startsWith('AC-'));

  const domains = detectDomains(`${reqText}\n${designText}\n${tasksText}`);

  const specCheckPath = path.join(root, 'reports', 'spec-check', `${feature}.md`);
  let specCheckVerdict = 'Not Run';
  if (fs.existsSync(specCheckPath)) {
    const sc = fs.readFileSync(specCheckPath, 'utf8');
    specCheckVerdict = (sc.match(/\*\*Verdict\*\*:\s*([A-Z_]+)/) || [])[1] || 'Recorded';
  }

  const gateDir = path.join(root, 'reports', 'quality-gate');
  const gateResults = [];
  if (fs.existsSync(gateDir)) {
    for (const file of fs.readdirSync(gateDir)) {
      if (!file.startsWith(`${feature}-`) || !file.endsWith('.execution.json')) continue;
      try {
        const parsed = JSON.parse(fs.readFileSync(path.join(gateDir, file), 'utf8'));
        gateResults.push({
          taskId: parsed.taskId,
          verdict: parsed.verdict,
          specDrift: parsed.checks?.specDrift?.status || 'UNKNOWN',
          sensorsPassed: parsed.checks?.nonFunctionalSensors?.passed ?? true,
        });
      } catch {
        // ignore malformed external file
      }
    }
  }

  const highestRisk = tasks.some((t) => t.risk === 'high')
    ? 'high'
    : tasks.some((t) => t.risk === 'standard')
      ? 'standard'
      : 'low';

  const provisionalCount = openQuestions.filter((q) => /^Provisional$/i.test(q.status)).length;

  return {
    schema: 'sdd-decision-view/v1',
    generatedAt: new Date().toISOString(),
    feature,
    domains,
    highestRisk,
    specCheckVerdict,
    counts: {
      requirements: reqIds.length,
      acceptanceCriteria: acIds.length,
      tasksTotal: tasks.length,
      tasksApproved: tasks.filter((t) => /^Approved\b/i.test(t.approval)).length,
      tasksDone: tasks.filter((t) => t.status === 'Done').length,
      openQuestionsTotal: openQuestions.length,
      openQuestionsProvisional: provisionalCount,
      alternativesRejected: alternativesRejected.length,
    },
    tasks: tasks.map(({ block, ...rest }) => rest),
    openQuestions,
    alternativesRejected,
    gateResults,
    sourcePaths: {
      requirements: toPosixPath(path.relative(root, reqPath)),
      design: toPosixPath(path.relative(root, designPath)),
      tasks: toPosixPath(path.relative(root, tasksPath)),
    },
  };
}

export function renderDecisionViewMarkdown(data) {
  const lines = [];
  lines.push(`# Decision View: ${data.feature}`);
  lines.push('');
  lines.push('> 全文を読み解く代わりに、**人が判断すべき要点（事実・理由・問い）** と **機械検証済みの領域** を分離したレビュービューです。');
  lines.push('');
  lines.push('## 1. 全体像（Overview）');
  lines.push('');
  lines.push('| 項目 | 値 |');
  lines.push('|---|---|');
  lines.push(`| Feature | \`${data.feature}\` |`);
  lines.push(`| 対象領域 (Domains) | ${data.domains.join(' / ')} |`);
  lines.push(`| 最高リスク階層 | \`${data.highestRisk}\` |`);
  lines.push(`| 要件 / 受入条件 | REQ: ${data.counts.requirements} 件 / AC: ${data.counts.acceptanceCriteria} 件 |`);
  lines.push(`| タスク進捗 | 合計 ${data.counts.tasksTotal}（Approved: ${data.counts.tasksApproved}, Done: ${data.counts.tasksDone}） |`);
  lines.push(`| 着工前 spec-check | \`${data.specCheckVerdict}\` |`);
  lines.push(`| 未確定事項 (Provisional OQ) | **${data.counts.openQuestionsProvisional} 件** / 全 ${data.counts.openQuestionsTotal} 件 |`);
  lines.push('');

  lines.push('## 2. 人が判断する問い（Open Questions / AI 仮決定）');
  lines.push('');
  if (data.openQuestions.length === 0) {
    lines.push('- 未確定の仮決定（`OQ-NNN`）はありません。');
  } else {
    for (const q of data.openQuestions) {
      const badge = /^Provisional$/i.test(q.status) ? '🟠 Provisional（要判断）' : '✅ Confirmed';
      const impacted = q.impactedTasks.length > 0 ? q.impactedTasks.join(', ') : '全体';
      lines.push(`### ${q.id} [${q.category}] — ${badge}（影響: ${impacted}）`);
      lines.push(`- **設計した事実（仮決定）**: ${q.fact}`);
      lines.push(`- **なぜそうしたか**: ${q.reason}`);
      lines.push(`- **人が判断する問い**: ${q.question}`);
      lines.push('');
    }
  }
  lines.push('');

  lines.push('## 3. 採らなかった設計（Alternatives Rejected）');
  lines.push('');
  if (data.alternativesRejected.length === 0) {
    lines.push('- 記載なし（標準構成または単一案）。');
  } else {
    lines.push('| 候補案 | 不採用理由 | 再検討条件 |');
    lines.push('|---|---|---|');
    for (const alt of data.alternativesRejected) {
      lines.push(`| ${alt.option} | ${alt.reason} | ${alt.revisitWhen} |`);
    }
  }
  lines.push('');

  lines.push('## 4. 機械確認済み vs 人間確認の分担');
  lines.push('');
  lines.push('| 観点 | 担当 | 状態・理由 |');
  lines.push('|---|---|---|');
  lines.push(`| REQ ↔ AC ↔ タスク契約整合・Spec Drift | 機械検証 | \`spec-check: ${data.specCheckVerdict}\` / \`check-spec-drift.mjs\` で自動照合（人は逸脱時のみ確認） |`);
  lines.push('| 標準 CRUD・既存規約準拠・プレースホルダー・秘密情報 | 機械検証 | `run-sdd-gate.mjs` 決定論センサーで自動検査 |');
  if (data.domains.includes('SQL')) {
    lines.push('| SQL 破壊的 DDL・権限/RLS・隔離 DB 検証 | 機械＋最重要 | `sql-develop` 契約および `run-sdd-gate.mjs` SQL センサーで保護 |');
  }
  if (data.domains.includes('AWS') || data.domains.includes('Azure')) {
    lines.push('| クラウド IaC 破壊変更・IAM 最小権限・実環境観測 | 機械＋最重要 | `sdd-{aws,azure}-cloud` 統制境界・CI OIDC 承認で保護 |');
  }
  lines.push(`| 事業判断・利用者挙動・他チーム契約・不可逆リスク | **人間確認** | 上記 \`OQ-NNN\`（未確定 ${data.counts.openQuestionsProvisional} 件）の判断に集中 |`);
  lines.push('');

  if (data.gateResults.length > 0) {
    lines.push('## 5. sdd-gate 実行状況');
    lines.push('');
    lines.push('| Task | Verdict | Spec Drift | Sensors |');
    lines.push('|---|---|---|---|');
    for (const g of data.gateResults) {
      lines.push(`| ${g.taskId} | ${g.verdict} | ${g.specDrift} | ${g.sensorsPassed ? 'PASS' : 'FAIL'} |`);
    }
    lines.push('');
  }

  return `${lines.join('\n')}\n`;
}

function escapeHtml(text) {
  return String(text || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

export function renderDecisionViewHtml(data) {
  const oqCards = data.openQuestions.length === 0
    ? '<p class="muted">未確定の仮決定（OQ-NNN）はありません。</p>'
    : data.openQuestions
        .map((q) => {
          const isProv = /^Provisional$/i.test(q.status);
          return `<section class="card ${isProv ? 'prov' : 'conf'}">
  <div class="card-head">
    <span class="badge">${escapeHtml(q.id)}</span>
    <span class="badge cat">${escapeHtml(q.category)}</span>
    <span class="badge ${isProv ? 'warn' : 'ok'}">${escapeHtml(q.status)}</span>
  </div>
  <div class="cols">
    <div><h4>設計した事実</h4><p>${escapeHtml(q.fact)}</p></div>
    <div><h4>なぜそうしたか</h4><p>${escapeHtml(q.reason)}</p></div>
    <div class="ask"><h4>人が判断する問い</h4><p>${escapeHtml(q.question)}</p></div>
  </div>
</section>`;
        })
        .join('\n');

  const altRows = data.alternativesRejected.length === 0
    ? '<tr><td colspan="3" class="muted">記載なし</td></tr>'
    : data.alternativesRejected
        .map(
          (a) =>
            `<tr><td>${escapeHtml(a.option)}</td><td>${escapeHtml(a.reason)}</td><td>${escapeHtml(a.revisitWhen)}</td></tr>`,
        )
        .join('\n');

  return `<!doctype html>
<html lang="ja">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width,initial-scale=1" />
<title>Decision View: ${escapeHtml(data.feature)}</title>
<style>
  body { font-family: system-ui, -apple-system, sans-serif; max-width: 1020px; margin: 24px auto; padding: 0 16px; color: #1e293b; background: #f8fafc; }
  h1 { color: #1d4ed8; margin-bottom: 4px; }
  .meta { display: flex; flex-wrap: wrap; gap: 10px; margin: 14px 0 24px; }
  .pill { background: #e0e7ff; color: #1e3a8a; padding: 4px 10px; border-radius: 999px; font-size: 13px; font-weight: 600; }
  .card { background: #fff; border: 1px solid #cbd5e1; border-radius: 10px; padding: 14px 16px; margin-bottom: 14px; }
  .card.prov { border-left: 5px solid #ea580c; }
  .card.conf { border-left: 5px solid #16a34a; }
  .card-head { display: flex; gap: 8px; margin-bottom: 10px; }
  .badge { font-size: 12px; font-weight: 700; padding: 2px 8px; border-radius: 6px; background: #e2e8f0; }
  .badge.cat { background: #dbeafe; color: #1d4ed8; }
  .badge.warn { background: #ffedd5; color: #9a3412; }
  .badge.ok { background: #dcfce7; color: #166534; }
  .cols { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 12px; }
  .cols h4 { margin: 0 0 4px; font-size: 13px; color: #475569; }
  .cols p { margin: 0; font-size: 14px; line-height: 1.5; }
  .ask { background: #fff7ed; padding: 10px; border-radius: 8px; border: 1px solid #fed7aa; }
  table { width: 100%; border-collapse: collapse; background: #fff; border-radius: 8px; overflow: hidden; }
  th, td { border: 1px solid #e2e8f0; padding: 8px 10px; text-align: left; font-size: 14px; }
  th { background: #f1f5f9; }
  .muted { color: #64748b; }
</style>
</head>
<body>
  <h1>Decision View: ${escapeHtml(data.feature)}</h1>
  <p class="muted">生成時刻: ${escapeHtml(data.generatedAt)} — 機械確認済み項目を折りたたみ、人間が判断すべき問いに絞ったビュー</p>
  <div class="meta">
    <span class="pill">Domains: ${escapeHtml(data.domains.join(' / '))}</span>
    <span class="pill">Highest Risk: ${escapeHtml(data.highestRisk)}</span>
    <span class="pill">REQ: ${data.counts.requirements} / AC: ${data.counts.acceptanceCriteria}</span>
    <span class="pill">Tasks: ${data.counts.tasksDone}/${data.counts.tasksTotal} Done</span>
    <span class="pill">Provisional OQ: ${data.counts.openQuestionsProvisional}</span>
  </div>
  <h2>人が判断する問い（Open Questions）</h2>
  ${oqCards}
  <h2>採らなかった設計（Alternatives Rejected）</h2>
  <table><thead><tr><th>候補案</th><th>不採用理由</th><th>再検討条件</th></tr></thead><tbody>${altRows}</tbody></table>
</body>
</html>
`;
}

function parseArgs(argv) {
  const opts = { feature: null, root: null, format: 'markdown', output: null };
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === '--feature' && argv[i + 1]) opts.feature = argv[++i];
    else if (a === '--root' && argv[i + 1]) opts.root = argv[++i];
    else if (a === '--format' && argv[i + 1]) opts.format = argv[++i];
    else if (a === '--output' && argv[i + 1]) opts.output = argv[++i];
  }
  return opts;
}

const isMain = process.argv[1] && pathToFileURL(path.resolve(process.argv[1])).href === import.meta.url;
if (isMain) {
  const opts = parseArgs(process.argv.slice(2));
  if (!opts.feature) {
    process.stderr.write('Usage: node render-decision-view.mjs --feature <feature> [--root <dir>] [--format markdown|html] [--output <path>]\n');
    process.exit(2);
  }
  const data = buildDecisionViewData({ feature: opts.feature, projectRoot: opts.root || process.cwd() });
  const content = opts.format === 'html' ? renderDecisionViewHtml(data) : renderDecisionViewMarkdown(data);
  if (opts.output) {
    const outPath = path.resolve(opts.output);
    fs.mkdirSync(path.dirname(outPath), { recursive: true });
    fs.writeFileSync(outPath, content, 'utf8');
  }
  process.stdout.write(content);
}
