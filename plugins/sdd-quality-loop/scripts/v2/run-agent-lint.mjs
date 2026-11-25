#!/usr/bin/env node
/**
 * run-agent-lint.mjs — Layer 2/3 Deterministic Agent-Strict Lint with Built-in Waivers (ADR-0054 T-004).
 *
 * Zero external dependencies — Node.js >= 20 LTS built-in modules only.
 * Layer 1 (`sdd-soft-guard.mjs`) remains untouched; this script runs in Layer 2/3
 * (`sdd-gate` / CI) with `diff_only: true` by default and <= 3s per 100 files budget (NFR-004).
 *
 * Usage:
 *   node run-agent-lint.mjs [--root <dir>] [--files <a,b>] [--diff-only]
 *                           [--mode off|shadow|warn|strict] [--format json|markdown]
 *                           [--today YYYY-MM-DD]
 *
 * Exit codes:
 *   0 — Pass (or shadow/warn/off mode)
 *   1 — Strict mode failure (unwaived error or expired waiver)
 *   2 — Tool / argument error
 */
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  globToRegExp,
  isMainModule,
  loadGuardrailsConfig,
  normalizeRelPath,
  resolveExplicitOrAutoRoot,
} from './guardrails-lib.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const RULES_PATH = path.resolve(__dirname, '../../rules/agent-strict-rules.json');
const LINTABLE_EXT_RE = /\.(?:m?js|cjs|tsx?|mts|cts)$/i;
const IGNORED_DIRS = new Set(['.git', 'node_modules', 'dist', 'dist-test', 'build', '.next', '.worktrees']);

function loadRulesCatalog() {
  try {
    const raw = JSON.parse(fs.readFileSync(RULES_PATH, 'utf8'));
    return new Map((raw.rules || []).map((r) => [r.id, r]));
  } catch {
    return new Map();
  }
}

/**
 * Replaces string literals and comments with spaces while preserving newlines
 * and line/column positions so structural regex & brace-depth analysis never
 * triggers false positives on comments or string data.
 */
export function maskStringsAndComments(source) {
  const chars = [...source];
  const out = new Array(chars.length);
  let i = 0;
  const n = chars.length;

  while (i < n) {
    const ch = chars[i];
    const next = chars[i + 1];

    // Single-line comment
    if (ch === '/' && next === '/') {
      out[i] = ' ';
      out[i + 1] = ' ';
      i += 2;
      while (i < n && chars[i] !== '\n') {
        out[i] = ' ';
        i += 1;
      }
      continue;
    }

    // Block comment
    if (ch === '/' && next === '*') {
      out[i] = ' ';
      out[i + 1] = ' ';
      i += 2;
      while (i < n) {
        if (chars[i] === '*' && chars[i + 1] === '/') {
          out[i] = ' ';
          out[i + 1] = ' ';
          i += 2;
          break;
        }
        out[i] = chars[i] === '\n' ? '\n' : ' ';
        i += 1;
      }
      continue;
    }

    // String / template literals
    if (ch === "'" || ch === '"' || ch === '`') {
      const quote = ch;
      out[i] = quote;
      i += 1;
      while (i < n) {
        if (chars[i] === '\\' && i + 1 < n) {
          out[i] = ' ';
          out[i + 1] = chars[i + 1] === '\n' ? '\n' : ' ';
          i += 2;
          continue;
        }
        if (chars[i] === quote) {
          out[i] = quote;
          i += 1;
          break;
        }
        out[i] = chars[i] === '\n' ? '\n' : ' ';
        i += 1;
      }
      continue;
    }

    out[i] = ch;
    i += 1;
  }

  return out.join('');
}

function lineNumberAt(text, index) {
  let line = 1;
  for (let i = 0; i < index && i < text.length; i += 1) {
    if (text[i] === '\n') line += 1;
  }
  return line;
}

export function lintSourceCode(source, relPath, rulesMap = loadRulesCatalog()) {
  const masked = maskStringsAndComments(source);
  const findings = [];

  const pushFinding = (ruleId, line, snippet) => {
    const meta = rulesMap.get(ruleId) || {
      id: ruleId,
      severity: 'error',
      category: 'general',
      message: ruleId,
      remediation_hint: 'コードを確認して修正してください',
    };
    findings.push({
      rule: ruleId,
      severity: meta.severity,
      category: meta.category,
      path: relPath,
      line,
      message: meta.message,
      remediation_hint: meta.remediation_hint,
      snippet: String(snippet || '').trim().slice(0, 120),
    });
  };

  // 1. no-empty-catch (check against raw source so intentional comment inside catch is allowed)
  const emptyCatchRe = /\bcatch\s*(?:\([^)]*\))?\s*\{\s*\}/g;
  for (const m of source.matchAll(emptyCatchRe)) {
    const maskedSlice = masked.slice(m.index, m.index + m[0].length);
    if (/\bcatch\b/.test(maskedSlice)) {
      pushFinding('no-empty-catch', lineNumberAt(source, m.index), m[0]);
    }
  }

  // 2. no-eval-or-new-function
  const evalRe = /\b(?:eval\s*\(|new\s+Function\s*\()/g;
  for (const m of masked.matchAll(evalRe)) {
    pushFinding('no-eval-or-new-function', lineNumberAt(masked, m.index), m[0]);
  }

  // 3. no-child-process-shell-true
  const shellTrueRe = /\bshell\s*:\s*true\b/g;
  for (const m of masked.matchAll(shellTrueRe)) {
    pushFinding('no-child-process-shell-true', lineNumberAt(masked, m.index), m[0]);
  }
  const execCallRe = /\bexecSync\s*\(/g;
  for (const m of masked.matchAll(execCallRe)) {
    pushFinding('no-child-process-shell-true', lineNumberAt(masked, m.index), m[0]);
  }

  // 4. no-console-log
  const consoleLogRe = /\bconsole\.log\s*\(/g;
  for (const m of masked.matchAll(consoleLogRe)) {
    pushFinding('no-console-log', lineNumberAt(masked, m.index), m[0]);
  }

  // 5. no-deep-nesting (> 6 brace levels)
  let depth = 0;
  let reportedDeep = false;
  let lineNum = 1;
  for (let i = 0; i < masked.length; i += 1) {
    const ch = masked[i];
    if (ch === '\n') lineNum += 1;
    else if (ch === '{') {
      depth += 1;
      if (depth > 6 && !reportedDeep) {
        reportedDeep = true;
        pushFinding('no-deep-nesting', lineNum, `brace depth ${depth} > 6`);
      }
    } else if (ch === '}') {
      depth = Math.max(0, depth - 1);
    }
  }

  return findings;
}

function collectFilesRecursive(root, relDir = '', out = [], maxFiles = 2000) {
  if (out.length >= maxFiles) return out;
  const absDir = relDir ? path.join(root, ...relDir.split('/')) : root;
  let entries;
  try {
    entries = fs.readdirSync(absDir, { withFileTypes: true });
  } catch {
    return out;
  }
  for (const entry of entries) {
    if (out.length >= maxFiles) break;
    if (IGNORED_DIRS.has(entry.name)) continue;
    const childRel = relDir ? `${relDir}/${entry.name}` : entry.name;
    if (entry.isDirectory()) {
      collectFilesRecursive(root, childRel, out, maxFiles);
    } else if (entry.isFile() && LINTABLE_EXT_RE.test(entry.name)) {
      out.push(childRel);
    }
  }
  return out;
}

function listDiffFiles(root) {
  try {
    const raw = execFileSync('git', ['diff', '--name-only', '--diff-filter=ACMR', 'HEAD'], {
      cwd: root,
      encoding: 'utf8',
      shell: false,
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    return raw
      .split(/\r?\n/)
      .map((l) => normalizeRelPath(l))
      .filter((l) => l && LINTABLE_EXT_RE.test(l));
  } catch {
    return [];
  }
}

export function runAgentLint({
  projectRoot = null,
  files = null,
  diffOnly = null,
  mode = null,
  today = null,
} = {}) {
  const startedAt = performance.now();
  const root = resolveExplicitOrAutoRoot(projectRoot);
  const config = loadGuardrailsConfig(root);
  const alCfg = config.agent_lint || {};
  const effectiveMode = mode || (alCfg.enabled ? alCfg.mode : 'shadow');
  const effectiveDiffOnly = typeof diffOnly === 'boolean' ? diffOnly : Boolean(alCfg.diff_only);
  const todayStr = today || new Date().toISOString().slice(0, 10);

  if (effectiveMode === 'off') {
    return {
      schema: 'sdd-agent-lint/v1',
      mode: 'off',
      status: 'SKIPPED',
      scannedFiles: 0,
      durationMs: Math.round(performance.now() - startedAt),
      findings: [],
      waived: [],
      expiredWaivers: [],
    };
  }

  let targetRelFiles = [];
  if (Array.isArray(files) && files.length > 0) {
    targetRelFiles = files.map((f) => normalizeRelPath(f)).filter((f) => f && LINTABLE_EXT_RE.test(f));
  } else if (effectiveDiffOnly) {
    targetRelFiles = listDiffFiles(root);
  } else {
    targetRelFiles = collectFilesRecursive(root);
  }

  const rulesMap = loadRulesCatalog();
  const waivers = Array.isArray(alCfg.waivers) ? alCfg.waivers : [];
  const expiredWaivers = [];
  const activeWaivers = [];

  for (const w of waivers) {
    if (!w || typeof w !== 'object' || !w.rule || !w.path || !w.expires_on) continue;
    const exp = String(w.expires_on).trim();
    if (exp < todayStr) {
      expiredWaivers.push({
        code: 'EXPIRED_WAIVER',
        rule: String(w.rule),
        path: String(w.path),
        expires_on: exp,
        message: `Waiver (${w.rule} @ ${w.path}) の有効期限 (${exp}) が切れています (today=${todayStr})`,
        remediation_hint: '違反を修正して guardrails.yaml から waiver を削除するか、人間承認のもとで期限を更新してください',
      });
    } else {
      activeWaivers.push({
        rule: String(w.rule),
        pathRe: globToRegExp(String(w.path)),
        rawPath: String(w.path),
        expires_on: exp,
        reason: String(w.reason || ''),
      });
    }
  }

  const findings = [];
  const waived = [];
  let scannedFiles = 0;

  for (const rel of targetRelFiles) {
    const abs = path.join(root, ...rel.split('/'));
    if (!fs.existsSync(abs)) continue;
    let src;
    try {
      const st = fs.statSync(abs);
      if (!st.isFile() || st.size > 2 * 1024 * 1024) continue;
      src = fs.readFileSync(abs, 'utf8');
    } catch {
      continue;
    }
    scannedFiles += 1;
    for (const f of lintSourceCode(src, rel, rulesMap)) {
      const matchedWaiver = activeWaivers.find((w) => w.rule === f.rule && w.pathRe.test(rel));
      if (matchedWaiver) {
        waived.push({ ...f, waiver: { path: matchedWaiver.rawPath, expires_on: matchedWaiver.expires_on, reason: matchedWaiver.reason } });
      } else {
        findings.push(f);
      }
    }
  }

  const hasErrors = findings.some((f) => f.severity === 'error') || expiredWaivers.length > 0;
  const status =
    hasErrors && effectiveMode === 'strict'
      ? 'FAIL'
      : findings.length > 0 || expiredWaivers.length > 0
        ? 'WARN'
        : 'PASS';

  return {
    schema: 'sdd-agent-lint/v1',
    mode: effectiveMode,
    status,
    scannedFiles,
    durationMs: Math.round(performance.now() - startedAt),
    findings,
    waived,
    expiredWaivers,
  };
}

export function formatAgentLintMarkdown(report) {
  const lines = [
    `## Agent-Strict Lint — \`${report.status}\` (mode: \`${report.mode}\`)`,
    '',
    `- **Scanned Files**: ${report.scannedFiles} (${report.durationMs}ms)`,
    `- **Findings**: ${report.findings.length} / **Waived**: ${report.waived.length} / **Expired Waivers**: ${report.expiredWaivers.length}`,
  ];
  if (report.expiredWaivers.length > 0) {
    lines.push('', '### Expired Waivers');
    for (const ew of report.expiredWaivers) {
      lines.push(`- **${ew.rule}** (\`${ew.path}\`, expired \`${ew.expires_on}\`): ${ew.message}`);
      lines.push(`  - Hint: ${ew.remediation_hint}`);
    }
  }
  if (report.findings.length > 0) {
    lines.push('', '### Findings');
    for (const f of report.findings) {
      lines.push(`- **[${f.severity.toUpperCase()}] ${f.rule}** (\`${f.path}:L${f.line}\`): ${f.message}`);
      lines.push(`  - Hint: ${f.remediation_hint}`);
    }
  }
  return `${lines.join('\n')}\n`;
}

function parseArgs(argv) {
  const opts = {
    root: null,
    files: null,
    diffOnly: null,
    mode: null,
    format: 'json',
    today: null,
  };
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === '--root' && argv[i + 1]) opts.root = argv[++i];
    else if (a === '--files' && argv[i + 1]) opts.files = argv[++i].split(',').map((s) => s.trim()).filter(Boolean);
    else if (a === '--diff-only') opts.diffOnly = true;
    else if (a === '--all') opts.diffOnly = false;
    else if (a === '--mode' && argv[i + 1]) opts.mode = argv[++i];
    else if (a === '--format' && argv[i + 1]) opts.format = argv[++i];
    else if (a === '--today' && argv[i + 1]) opts.today = argv[++i];
  }
  return opts;
}

if (isMainModule(import.meta.url, 'run-agent-lint.mjs')) {
  const opts = parseArgs(process.argv.slice(2));
  try {
    const report = runAgentLint({
      projectRoot: opts.root || process.cwd(),
      files: opts.files,
      diffOnly: opts.diffOnly,
      mode: opts.mode,
      today: opts.today,
    });
    if (opts.format === 'markdown') {
      process.stdout.write(formatAgentLintMarkdown(report));
    } else {
      process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
    }
    process.exit(report.status === 'FAIL' ? 1 : 0);
  } catch (err) {
    process.stderr.write(`run-agent-lint error: ${err.message}\n`);
    process.exit(2);
  }
}
