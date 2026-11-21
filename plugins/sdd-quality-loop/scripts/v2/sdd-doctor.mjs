#!/usr/bin/env node
/**
 * sdd-doctor.mjs — Read-only diagnostic CLI for SDD Forge v2 Lightweight Guardrails.
 *
 * Design principles (detect failures immediately; never auto-mutate):
 *   1. Read-only: reports NG / WARN / INFO and exact remediation; never edits files.
 *   2. Explicit Non-checks: "CLEAN" means "no findings inside the checked boundary" —
 *      never mistake CLEAN for semantic correctness of specs, design, or code.
 *   3. Regression-driven checks: each rule corresponds to a real observed failure mode
 *      (silent hook loss, skill description > 1024 chars silently dropped by hosts,
 *      shell escape control-char corruption, PS5.1 non-ASCII BOM mojibake,
 *      unbaselined approved specs, stale tasks, malformed guardrails config).
 *
 * Usage:
 *   node sdd-doctor.mjs [--root <dir>] [--stale-days <n>] [--json] [--quiet-info]
 *
 * Exit codes:
 *   0 — No NG findings (WARN / INFO may be present)
 *   1 — One or more NG findings
 */
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import {
  countPrimaryApprovals,
  findProjectRoot,
  normalizeNewlines,
  parseSimpleYaml,
  safeRealpath,
  toPosixPath,
} from './guardrails-lib.mjs';

export const NON_CHECKS = Object.freeze([
  '仕様・設計・ドメインモデルの意味的妥当性や文書間の内容矛盾',
  'テストケースの網羅性・プロダクションコードの論理バグや性能',
  'クラウド環境（AWS/Azure）や本番データベースの実状態・認証有効性',
  '外部ホスト CLI（Claude Code / Codex / Copilot / Gemini）内部の非公開挙動',
]);

const MAX_SKILL_DESCRIPTION_CHARS = 1024;
const VALID_MODES = new Set(['warn', 'confirm', 'strict']);
const VALID_PRE_IMPL = new Set(['auto', 'always', 'off']);
const VALID_RISK_TIERS = new Set(['low', 'standard', 'high']);
// ASCII control characters excluding \t (0x09), \n (0x0A), \r (0x0D)
const CONTROL_CHAR_RE = /[\x00-\x08\x0B\x0C\x0E-\x1F]/;
const NON_ASCII_RE = /[^\x00-\x7F]/;

const IGNORED_DIRS = new Set(['.git', 'node_modules', 'dist', 'build', '.next', '__pycache__', '.venv']);

function walkFiles(dir, predicate, out = []) {
  if (!fs.existsSync(dir)) return out;
  let entries;
  try {
    entries = fs.readdirSync(dir, { withFileTypes: true });
  } catch {
    return out;
  }
  for (const entry of entries) {
    if (IGNORED_DIRS.has(entry.name)) continue;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      walkFiles(full, predicate, out);
    } else if (entry.isFile() && predicate(full, entry.name)) {
      out.push(full);
    }
  }
  return out;
}

function parseFrontmatter(content) {
  const normalized = normalizeNewlines(content);
  if (!normalized.startsWith('---\n')) return null;
  const endIdx = normalized.indexOf('\n---', 4);
  if (endIdx === -1) return null;
  const raw = normalized.slice(4, endIdx);
  const fields = {};
  const lines = raw.split('\n');
  for (let i = 0; i < lines.length; i += 1) {
    const line = lines[i];
    const m = line.match(/^([A-Za-z0-9_-]+):\s*(.*)$/);
    if (!m) continue;
    const key = m[1];
    let val = m[2].trim();
    if (val === '|' || val === '>') {
      const block = [];
      while (i + 1 < lines.length && /^[ \t]+/.test(lines[i + 1])) {
        i += 1;
        block.push(lines[i].trim());
      }
      val = block.join(val === '>' ? ' ' : '\n');
    } else if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
      val = val.slice(1, -1);
    }
    fields[key] = val;
  }
  return fields;
}

function addFinding(findings, severity, category, message, relPath, action) {
  findings.push({
    severity,
    category,
    message,
    path: relPath || null,
    action,
  });
}

function checkRuntime(findings) {
  const major = Number(process.versions.node.split('.')[0]);
  if (Number.isNaN(major) || major < 20) {
    addFinding(
      findings,
      'NG',
      'runtime',
      `Node.js ${process.versions.node} は v2 推奨要件（>= 20 LTS）未満です`,
      null,
      'Node.js 20 LTS 以上へアップグレードしてください',
    );
  }
}

function checkKillSwitch(root, findings) {
  const stopPath = path.join(root, 'AGENT_STOP');
  if (fs.existsSync(stopPath)) {
    addFinding(
      findings,
      'WARN',
      'kill-switch',
      'AGENT_STOP が存在するため、全ホストのツール実行が停止状態です',
      'AGENT_STOP',
      '作業を再開する場合は安全を確認したうえで AGENT_STOP を削除してください',
    );
  }
}

function checkConfig(root, findings) {
  const jsonPath = path.join(root, 'sdd', 'guardrails.json');
  const yamlPath = path.join(root, 'sdd', 'guardrails.yaml');

  let parsed = null;
  let rel = null;

  if (fs.existsSync(jsonPath)) {
    rel = 'sdd/guardrails.json';
    try {
      parsed = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
    } catch (err) {
      addFinding(
        findings,
        'NG',
        'config',
        `JSON 構文エラー: ${err.message}`,
        rel,
        'sdd/guardrails.json の構文を contracts/guardrails.schema.json に沿って修正してください',
      );
      return;
    }
  } else if (fs.existsSync(yamlPath)) {
    rel = 'sdd/guardrails.yaml';
    try {
      const raw = fs.readFileSync(yamlPath, 'utf8');
      parsed = parseSimpleYaml(raw);
      if (!parsed || Object.keys(parsed).length === 0) {
        addFinding(
          findings,
          'NG',
          'config',
          'sdd/guardrails.yaml が空または解析不能です',
          rel,
          'sdd/guardrails.example.yaml を参考に有効な設定を記述してください',
        );
        return;
      }
    } catch (err) {
      addFinding(
        findings,
        'NG',
        'config',
        `YAML 読込エラー: ${err.message}`,
        rel,
        'sdd/guardrails.yaml の文字コードと構文を確認してください',
      );
      return;
    }
  } else {
    addFinding(
      findings,
      'INFO',
      'config',
      'sdd/guardrails.yaml 未配置（既定値 spec_guard.mode=confirm で動作中）',
      'sdd/guardrails.yaml',
      '必要に応じて sdd/guardrails.example.yaml をコピーして調整してください',
    );
    return;
  }

  if (parsed.schema && parsed.schema !== 'sdd-guardrails/v1') {
    addFinding(
      findings,
      'NG',
      'config',
      `未対応の schema 値: ${parsed.schema}`,
      rel,
      'schema を "sdd-guardrails/v1" に修正してください',
    );
  }
  const mode = parsed?.spec_guard?.mode;
  if (mode !== undefined && !VALID_MODES.has(mode)) {
    addFinding(
      findings,
      'NG',
      'config',
      `不正な spec_guard.mode: ${mode}`,
      rel,
      'warn | confirm | strict のいずれかを指定してください',
    );
  }
  const preImpl = parsed?.review?.pre_impl_check;
  if (preImpl !== undefined && !VALID_PRE_IMPL.has(preImpl)) {
    addFinding(
      findings,
      'NG',
      'config',
      `不正な review.pre_impl_check: ${preImpl}`,
      rel,
      'auto | always | off のいずれかを指定してください',
    );
  }
  const tier = parsed?.risk_defaults?.default_tier;
  if (tier !== undefined && !VALID_RISK_TIERS.has(tier)) {
    addFinding(
      findings,
      'NG',
      'config',
      `不正な risk_defaults.default_tier: ${tier}`,
      rel,
      'low | standard | high のいずれかを指定してください',
    );
  }
}

function checkHooks(root, findings) {
  const candidates = [
    'plugins/sdd-quality-loop/hooks/claude-hooks.json',
    'plugins/sdd-quality-loop/hooks/hooks.json',
    'plugins/sdd-quality-loop/hooks/copilot-hooks.json',
    'plugins/sdd-quality-loop/gemini/hooks/hooks.json',
    '.claude/settings.json',
    '.codex/hooks.json',
    '.gemini/settings.json',
  ];

  const ghHooksDir = path.join(root, '.github', 'hooks');
  if (fs.existsSync(ghHooksDir)) {
    for (const file of walkFiles(ghHooksDir, (_full, name) => name.endsWith('.json'))) {
      candidates.push(toPosixPath(path.relative(root, file)));
    }
  }

  let checkedCount = 0;
  for (const rel of candidates) {
    const abs = path.join(root, rel);
    if (!fs.existsSync(abs)) continue;
    checkedCount += 1;
    let raw;
    try {
      raw = fs.readFileSync(abs, 'utf8');
      JSON.parse(raw);
    } catch (err) {
      addFinding(
        findings,
        'NG',
        'hooks',
        `フック設定の JSON 構文エラー: ${err.message}`,
        rel,
        'JSON 構文を修正し、ホストのフック読込がサイレント失敗しない状態にしてください',
      );
      continue;
    }
    if (/sdd-hook-guard/i.test(raw)) {
      addFinding(
        findings,
        'WARN',
        'hooks',
        '廃止済みの v1 ハードロック（sdd-hook-guard）参照が残存しています',
        rel,
        'install.sh / install.ps1 を再実行して v2/sdd-soft-guard.mjs へ切り替えてください',
      );
    }
  }

  // If this is the plugin repo (or has installed plugins/), verify v2 soft guard exists.
  const pluginGuard = path.join(root, 'plugins/sdd-quality-loop/scripts/v2/sdd-soft-guard.mjs');
  if (fs.existsSync(path.join(root, 'plugins/sdd-quality-loop')) && !fs.existsSync(pluginGuard)) {
    addFinding(
      findings,
      'NG',
      'hooks',
      'v2 ソフトガード本体（sdd-soft-guard.mjs）が見つかりません',
      'plugins/sdd-quality-loop/scripts/v2/sdd-soft-guard.mjs',
      'sdd-forge を再インストールしてください',
    );
  }

  if (checkedCount === 0) {
    addFinding(
      findings,
      'INFO',
      'hooks',
      'プロジェクト配下にローカルフック設定は検出されませんでした（ユーザーホーム側設定を利用中の可能性）',
      null,
      'フック動作を確認する場合はホスト設定（~/.claude / ~/.codex / ~/.gemini 等）を確認してください',
    );
  }
}

function checkSkills(root, findings) {
  const skillRoots = [path.join(root, 'plugins'), path.join(root, 'sdd', 'skills')];
  const skillFiles = [];
  for (const dir of skillRoots) {
    walkFiles(dir, (full, name) => {
      if (name !== 'SKILL.md') return false;
      const posix = toPosixPath(path.relative(root, full));
      return !posix.includes('/human-copy') && !posix.includes('/references/');
    }, skillFiles);
  }

  for (const abs of skillFiles) {
    const rel = toPosixPath(path.relative(root, abs));
    const content = fs.readFileSync(abs, 'utf8');
    const fm = parseFrontmatter(content);
    if (!fm || !fm.name || !fm.description) {
      addFinding(
        findings,
        'NG',
        'skills',
        'SKILL.md の YAML フロントマター（name / description）が欠落または不正です',
        rel,
        '先頭に --- で囲んだ name と description を記載してください',
      );
      continue;
    }
    if (fm.description.length > MAX_SKILL_DESCRIPTION_CHARS) {
      addFinding(
        findings,
        'NG',
        'skills',
        `description が ${fm.description.length} 文字あり上限（${MAX_SKILL_DESCRIPTION_CHARS} 文字）を超過（ホスト側で警告なく無視される恐れ）`,
        rel,
        `description を ${MAX_SKILL_DESCRIPTION_CHARS} 文字以内へ要約してください`,
      );
    }
  }
}

function checkEncodingAndControlChars(root, findings) {
  const textTargets = [
    ...walkFiles(path.join(root, 'specs'), (_full, name) => /\.(md|json|ya?ml)$/i.test(name)),
    ...walkFiles(path.join(root, 'sdd'), (_full, name) => /\.(md|json|ya?ml)$/i.test(name)),
  ];

  for (const abs of textTargets) {
    const rel = toPosixPath(path.relative(root, abs));
    const raw = fs.readFileSync(abs, 'utf8');
    const match = CONTROL_CHAR_RE.exec(raw);
    if (match) {
      const codeHex = `0x${match[0].charCodeAt(0).toString(16).padStart(2, '0')}`;
      addFinding(
        findings,
        'NG',
        'encoding',
        `不正な ASCII 制御文字（${codeHex}）が混入しています（シェルエスケープ破損の恐れ）`,
        rel,
        '該当ファイルの破損箇所をファイル編集ツールで修復してください',
      );
    }
  }

  // PowerShell 5.1 non-ASCII without UTF-8 BOM check (only inside sdd/ and root/scripts/plugins .ps1)
  const psTargets = [
    ...walkFiles(path.join(root, 'sdd'), (_full, name) => name.endsWith('.ps1')),
    ...walkFiles(path.join(root, 'scripts'), (_full, name) => name.endsWith('.ps1')),
  ];
  for (const abs of psTargets) {
    const rel = toPosixPath(path.relative(root, abs));
    const buf = fs.readFileSync(abs);
    const hasBom = buf.length >= 3 && buf[0] === 0xef && buf[1] === 0xbb && buf[2] === 0xbf;
    if (!hasBom && NON_ASCII_RE.test(buf.toString('utf8'))) {
      addFinding(
        findings,
        'WARN',
        'encoding',
        '非 ASCII 文字を含む PowerShell スクリプトに UTF-8 BOM がありません（Windows PS 5.1 文字化けリスク）',
        rel,
        'UTF-8 BOM 付きで保存するか ASCII のみで記述してください',
      );
    }
  }
}

function checkSpecsAndTasks(root, staleDays, findings) {
  const specsDir = path.join(root, 'specs');
  if (!fs.existsSync(specsDir)) return;

  let entries;
  try {
    entries = fs.readdirSync(specsDir, { withFileTypes: true });
  } catch {
    return;
  }

  const nowMs = Date.now();
  const staleMs = staleDays * 24 * 60 * 60 * 1000;

  for (const entry of entries) {
    if (!entry.isDirectory()) continue;
    const featureDir = path.join(specsDir, entry.name);
    const tasksPath = path.join(featureDir, 'tasks.md');
    if (!fs.existsSync(tasksPath)) continue;

    const relTasks = toPosixPath(path.relative(root, tasksPath));
    const content = fs.readFileSync(tasksPath, 'utf8');
    const approvedCount = countPrimaryApprovals(content);
    const hasActiveTask = /^[ \t]*Status:[ \t]*(?:Planned|In Progress|Implementation Complete|Blocked)\b/im.test(content);
    const baselinePath = path.join(featureDir, '.spec-baseline.json');

    if (approvedCount > 0 && hasActiveTask && !fs.existsSync(baselinePath)) {
      addFinding(
        findings,
        'WARN',
        'specs',
        `進行中・未完了の承認済みタスクが ${approvedCount} 件ありますが .spec-baseline.json が未作成です（Spec Drift 検知が未武装）`,
        relTasks,
        `record-spec-baseline.mjs --feature ${entry.name} を実行してください`,
      );
    }

    if (/^[ \t]*Status:[ \t]*In Progress\b/im.test(content)) {
      const stat = fs.statSync(tasksPath);
      const ageDays = Math.floor((nowMs - stat.mtimeMs) / (24 * 60 * 60 * 1000));
      if (nowMs - stat.mtimeMs > staleMs) {
        addFinding(
          findings,
          'WARN',
          'specs',
          `Status: In Progress のタスクが ${ageDays} 日以上未更新です（しきい値: ${staleDays} 日）`,
          relTasks,
          '作業を継続するか、完了・中止状態へ tasks.md を更新してください',
        );
      }
    }
  }
}

function checkDriftEvents(root, findings) {
  const logPath = path.join(root, '.sdd', 'drift-events.jsonl');
  if (!fs.existsSync(logPath)) return;
  const lines = normalizeNewlines(fs.readFileSync(logPath, 'utf8'))
    .split('\n')
    .filter((l) => l.trim().length > 0);
  if (lines.length === 0) return;

  let denyCount = 0;
  let warnCount = 0;
  let parseErrors = 0;
  for (const line of lines) {
    try {
      const ev = JSON.parse(line);
      const action = typeof ev.action === 'string' ? ev.action : '';
      const decision = typeof ev.decision === 'string' ? ev.decision : '';
      if (action === 'strict_deny' || action === 'confirm_soft_deny' || decision === 'deny') {
        denyCount += 1;
      } else if (
        action === 'warn_allow' ||
        action === 'confirm_amended_allow' ||
        action === 'allow_override' ||
        decision === 'warn' ||
        decision === 'confirm'
      ) {
        warnCount += 1;
      }
    } catch {
      parseErrors += 1;
    }
  }

  if (parseErrors > 0) {
    addFinding(
      findings,
      'WARN',
      'events',
      `.sdd/drift-events.jsonl に破損行が ${parseErrors} 件あります`,
      '.sdd/drift-events.jsonl',
      '破損行を確認してください',
    );
  }
  addFinding(
    findings,
    'INFO',
    'events',
    `ガードイベント累計 ${lines.length} 件（deny=${denyCount}, warn/confirm=${warnCount}）`,
    '.sdd/drift-events.jsonl',
    'workflow-retrospective 実行時の事実ベース集計に利用できます',
  );
}

function checkKnowledgeIndexes(root, findings) {
  const MAX_INDEX_CHARS = 3000;
  const knowledgeRoot = path.join(root, 'sdd', 'knowledge');
  const indexFiles = walkFiles(knowledgeRoot, (_full, name) => name.toUpperCase() === 'INDEX.MD');
  for (const abs of indexFiles) {
    let raw;
    try {
      if (!fs.statSync(abs).isFile()) continue;
      raw = fs.readFileSync(abs, 'utf8');
    } catch {
      continue;
    }
    const len = normalizeNewlines(raw).length;
    if (len > MAX_INDEX_CHARS) {
      const rel = toPosixPath(path.relative(root, abs));
      addFinding(
        findings,
        'WARN',
        'knowledge',
        `ナレッジ索引が ${len} 文字あり目安上限（${MAX_INDEX_CHARS} 文字）を超過しています（コンテキスト圧迫リスク）`,
        rel,
        '詳細は個別ファイルへ分割し、INDEX は 3,000 字以内のリンク集に保ってください',
      );
    }
  }
}

export function runDoctor(options = {}) {
  const root = safeRealpath(options.root || findProjectRoot());
  const staleDays = Number.isFinite(options.staleDays) ? options.staleDays : 14;
  const findings = [];

  checkRuntime(findings);
  checkKillSwitch(root, findings);
  checkConfig(root, findings);
  checkHooks(root, findings);
  checkSkills(root, findings);
  checkEncodingAndControlChars(root, findings);
  checkSpecsAndTasks(root, staleDays, findings);
  checkKnowledgeIndexes(root, findings);
  checkDriftEvents(root, findings);

  const summary = {
    ng: findings.filter((f) => f.severity === 'NG').length,
    warn: findings.filter((f) => f.severity === 'WARN').length,
    info: findings.filter((f) => f.severity === 'INFO').length,
  };

  return {
    schema: 'sdd-doctor/v1',
    checked_at: new Date().toISOString(),
    root,
    status: summary.ng > 0 ? 'NG' : summary.warn > 0 ? 'WARN' : 'CLEAN',
    summary,
    non_checks: [...NON_CHECKS],
    findings,
  };
}

export function formatDoctorText(report, { quietInfo = false } = {}) {
  const lines = [];
  lines.push(
    `sdd-doctor (${report.checked_at}) — ${report.status} (NG: ${report.summary.ng} / WARN: ${report.summary.warn} / INFO: ${report.summary.info})`,
  );
  lines.push('Boundary: CLEAN は以下の検査境界内で異常なしを意味し、それ以上を保証しません。');
  lines.push('Non-checks（検査しないもの）:');
  for (const item of report.non_checks) {
    lines.push(`  - ${item}`);
  }
  lines.push('');

  const visible = quietInfo ? report.findings.filter((f) => f.severity !== 'INFO') : report.findings;
  if (visible.length === 0) {
    lines.push('No findings inside the checked boundary.');
  } else {
    for (const f of visible) {
      const loc = f.path ? ` (${f.path})` : '';
      lines.push(`${f.severity.padEnd(4)} [${f.category}] ${f.message}${loc}`);
      lines.push(`     -> ${f.action}`);
    }
  }
  return `${lines.join('\n')}\n`;
}

function parseCliArgs(argv) {
  const opts = { root: null, staleDays: 14, json: false, quietInfo: false };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--root') opts.root = argv[++i];
    else if (arg === '--stale-days') opts.staleDays = Number(argv[++i]);
    else if (arg === '--json') opts.json = true;
    else if (arg === '--quiet-info') opts.quietInfo = true;
  }
  return opts;
}

const isMain =
  process.argv[1] &&
  path.basename(process.argv[1]) === 'sdd-doctor.mjs' &&
  pathToFileURL(path.resolve(process.argv[1])).href === import.meta.url;
if (isMain) {
  const opts = parseCliArgs(process.argv.slice(2));
  const report = runDoctor(opts);
  if (opts.json) {
    process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
  } else {
    process.stdout.write(formatDoctorText(report, { quietInfo: opts.quietInfo }));
  }
  process.exit(report.summary.ng > 0 ? 1 : 0);
}
