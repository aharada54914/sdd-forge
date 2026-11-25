#!/usr/bin/env node
/**
 * run-agent-lint.mjs — Layer 2/3 Deterministic Agent-Strict Lint with Built-in Waivers (ADR-0054 T-004).
 *
 * Install the optional AST parser with npm ci --prefix plugins/sdd-quality-loop/rules.
 * Layer 1 (`sdd-soft-guard.mjs`) remains untouched; this script runs in Layer 2/3
 * (`sdd-gate` / CI) with `diff_only: true` by default and <= 3s per 100 files budget (NFR-004).
 *
 * Usage:
 *   node run-agent-lint.mjs [--root <dir>] [--files <a,b>] [--diff-only] [--base-ref <commit>]
 *                           [--mode off|shadow|warn|strict] [--format json|markdown]
 *                           [--today YYYY-MM-DD]
 *
 * Exit codes:
 *   0 — Pass (or shadow/warn/off mode)
 *   1 — Strict mode failure (unwaived error or expired waiver)
 *   2 — Tool / argument error
 */
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

import { analyzeSource, readImports } from '../../rules/agent-lint-ast.mjs';
import { changedHunks, LINTABLE } from '../../rules/lint-diff.mjs';
import { dependencyCycles, projectFile } from '../../rules/local-module-graph.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const RULES_PATH = path.resolve(__dirname, '../../rules/agent-strict-rules.json');

const IGNORED_DIRS = new Set(['.git', 'node_modules', 'dist', 'dist-test', 'build', '.next', '.worktrees']);

function loadRulesCatalog() {
  const raw = JSON.parse(fs.readFileSync(RULES_PATH, 'utf8'));
  return new Map(raw.rules.map(rule => [rule.id, rule]));
}

function describeFinding({ rule, line, snippet }, rel, rulesMap) {
  const { severity, category, message, remediation_hint } = rulesMap.get(rule);
  return { rule, severity, category, path: rel, line, message, remediation_hint, snippet };
}

export function lintSourceCode(source, relPath, rulesMap = loadRulesCatalog()) {
  return analyzeSource(source, relPath).findings.map(finding => describeFinding(finding, relPath, rulesMap));
}

function collectFilesRecursive(root, relDir = '', out = []) {
  const absDir = relDir ? path.join(root, ...relDir.split('/')) : root;
  let entries;
  try {
    entries = fs.readdirSync(absDir, { withFileTypes: true });
  } catch {
    return out;
  }
  for (const entry of entries) {
    if (IGNORED_DIRS.has(entry.name)) continue;
    const childRel = relDir ? `${relDir}/${entry.name}` : entry.name;
    if (entry.isDirectory()) {
      collectFilesRecursive(root, childRel, out);
    } else if (entry.isFile() && LINTABLE.test(entry.name)) {
      out.push(childRel);
    }
  }
  return out;
}

export function runAgentLint({
  projectRoot = null,
  files = null,
  diffOnly = null,
  baseRef = null,
  mode = null,
  today = null,
} = {}) {
  const startedAt = performance.now();
  const root = fs.realpathSync(resolveExplicitOrAutoRoot(projectRoot));
  const config = loadGuardrailsConfig(root);
  const alCfg = config.agent_lint || {};
  const effectiveMode = mode || (alCfg.enabled ? alCfg.mode : 'off');
  if (!['off', 'shadow', 'warn', 'strict'].includes(effectiveMode)) throw new Error('Invalid Agent Lint mode');
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

  // --files alone intentionally checks complete files (an editor/fixture use).
  // --files plus --diff-only restricts findings to the intersection.
  const explicit = Array.isArray(files) ? [...new Set(files.map(normalizeRelPath).filter(p => LINTABLE.test(p)))] : null;
  const useDiff = effectiveDiffOnly && (!explicit || diffOnly === true || baseRef);
  const hunks = useDiff ? changedHunks(root, baseRef || 'HEAD') : null;
  const targetRelFiles = explicit ?? (hunks ? [...hunks.keys()] : collectFilesRecursive(root));
  const inScope = (rel, { line, endLine }) => !hunks ||
    hunks.get(rel)?.some(([start, end]) => start <= endLine && line <= end);

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
  const cache = new Map();
  const cycleSeeds = [];
  let scannedFiles = 0;
  function analyze(rel) {
    if (!cache.has(rel)) {
      const file = projectFile(root, rel);
      if (!file) throw new Error(`Cannot inspect project file: ${rel}`);
      const reportTool = !explicit && rel.endsWith('.mjs') &&
        (rel.startsWith('tests/') || rel.startsWith('reports/verification/'));
      cache.set(rel, analyzeSource(fs.readFileSync(file, 'utf8'), rel, {
        maxDepth: alCfg.max_abstraction_depth,
        allowJsonReportOutput: reportTool,
      }));
    }
    return cache.get(rel);
  }
  function add(rel, raw) {
    const f = describeFinding(raw, rel, rulesMap);
    const waiver = activeWaivers.find(w => w.rule === f.rule && w.pathRe.test(rel));
    if (waiver) {
      waived.push({ ...f, waiver: { path: waiver.rawPath, expires_on: waiver.expires_on, reason: waiver.reason } });
    } else {
      findings.push(f);
    }
  }
  for (const rel of targetRelFiles) {
    if (hunks && !hunks.has(rel)) continue;
    const file = analyze(rel);
    scannedFiles += 1;
    for (const finding of file.findings) if (inScope(rel, finding)) add(rel, finding);
    if (file.imports.some(edge => inScope(rel, edge))) cycleSeeds.push(rel);
  }
  const importsFor = rel => cache.get(rel)?.imports ?? readImports(fs.readFileSync(projectFile(root, rel), 'utf8'), rel);
  for (const finding of dependencyCycles(root, cycleSeeds, importsFor, inScope)) add(finding.path, finding);

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
    else if (a === '--base-ref' && argv[i + 1]) opts.baseRef = argv[++i];
    else if (a === '--diff-only') opts.diffOnly = true;
    else if (a === '--all') opts.diffOnly = false;
    else if (a === '--mode' && argv[i + 1]) opts.mode = argv[++i];
    else if (a === '--format' && ['json', 'markdown'].includes(argv[i + 1])) opts.format = argv[++i];
    else if (a === '--today' && argv[i + 1]) opts.today = argv[++i];
    else throw new Error(`Unknown or incomplete option: ${a}`);
  }
  return opts;
}

if (isMainModule(import.meta.url, 'run-agent-lint.mjs')) {
  try {
    const opts = parseArgs(process.argv.slice(2));
    const report = runAgentLint({
      projectRoot: opts.root || process.cwd(),
      files: opts.files,
      diffOnly: opts.diffOnly,
      baseRef: opts.baseRef,
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
