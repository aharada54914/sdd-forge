#!/usr/bin/env node
/**
 * Unified deterministic runner for SDD Core's sdd-gate (v2 Lightweight Guardrails).
 * Zero external dependencies — Node.js >= 20 LTS built-in modules only.
 *
 * Runs in one invocation:
 *   1. Task precondition check (Approval: Approved, Status: Implementation Complete|Done)
 *   2. Spec Drift check (checkSpecDrift — catches silent goalpost moving)
 *   3. Placeholder scan on changed code files (tracked + untracked)
 *   4. Non-functional static sensors (SQL destructive DDL / unguarded UPDATE/DELETE,
 *      Cloud wildcard IAM / open admin ports, hardcoded secrets)
 *   5. Risk: high Provisional OQ-NNN fail-closed check
 *   6. Project verification commands (--cmd "label=command")
 *   7. Non-fatal telemetry logging to .sdd/factory-metrics.jsonl
 *
 * Usage:
 *   node run-sdd-gate.mjs --feature <feature> --task <T-NNN> [--root <dir>]
 *                         [--cmd "label=command"] [--changed-files "a.js,b.js"] [--base <git-ref>]
 *                         [--baseline <path>] [--output <json-path>]
 *                         [--skip-drift] [--skip-sensors]
 */
import { execFileSync, spawnSync } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { checkAntiTampering, checkSpecDrift } from './check-spec-drift.mjs';
import {
  assertValidFeatureName,
  createFsReadonlyIo,
  loadGuardrailsConfig,
  normalizeNewlines,
  normalizeRelPath,
  resolveExplicitOrAutoRoot,
  splitSpecAmendments,
  isMainModule,
} from './guardrails-lib.mjs';
import { checkWriteScope } from './check-traceability.mjs';
import { runRebuildDifferentialCheck } from './rebuild-differential.mjs';
export { runRebuildDifferentialCheck };
import { mergeOpenQuestions, parseOpenQuestions } from './render-decision-view.mjs';
import { runAgentLint } from './run-agent-lint.mjs';
import { runFormalGate } from './run-formal-gate.mjs';
import { runSecurityGate } from './run-security-gate.mjs';
import { acquireLock, releaseLock } from './task-lock.mjs';
import { extractScopePaths, isApprovedValue, normalizeRiskTier, taskEvidenceInputs } from './v2-readonly-core.mjs';
import { globToRegExp } from './v2-pure-lib.mjs';

const PLACEHOLDER_RE =
  /\b(?:TODO|FIXME|TBD)\b|NotImplementedError|throw\s+new\s+Error\(\s*['"]Not implemented|unimplemented!\(\)/;
const MAX_OUTPUT_CHARS = 8192;

const SECRET_SENSOR_RULES = [
  { id: 'SECRET_AWS_KEY', re: /\bAKIA[0-9A-Z]{16}\b/, msg: 'Hardcoded AWS Access Key ID detected' },
  { id: 'SECRET_PRIVATE_KEY', re: /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/, msg: 'Private key material detected' },
  { id: 'SECRET_AZURE_KEY', re: /AccountKey=[A-Za-z0-9+/=]{20,}/, msg: 'Hardcoded Azure Storage AccountKey detected' },
];

const SQL_DESTRUCTIVE_RE = /\b(?:DROP\s+(?:TABLE|DATABASE|SCHEMA|COLUMN)|TRUNCATE\s+(?:TABLE\s+)?[A-Za-z0-9_."`[\]]+)\b/i;

const CLOUD_WILDCARD_IAM_RE =
  /(?:["']?Action["']?|actions|dataActions)\s*[:=]\s*(?:['"]\*['"]|\[[^\]]*['"]\*['"][^\]]*\]|\r?\n[ \t]*-[ \t]*['"]?\*['"]?(?:[ \t]*$|\r?\n))/m;

const PUBLIC_CIDR_RE =
  /(?:0\.0\.0\.0\/0|::\/0|Peer\.anyIpv[46]\(\)|sourceAddressPrefix\s*[:=]\s*['"]\*['"])/i;

const ADMIN_PORT_RE =
  /(?:(?:from_?port|to_?port|port|Port\.tcp|destinationPortRange|destinationPortRanges|portRange)\s*[:=(]\s*['"\[]?(?:22|3389)\b|\b(?:ssh|rdp|port)\b[^0-9\n]{0,12}(?:22|3389)\b)/i;

function truncateTail(text) {
  const s = String(text || '');
  if (s.length <= MAX_OUTPUT_CHARS) return s;
  return `...[truncated ${s.length - MAX_OUTPUT_CHARS} chars]...\n${s.slice(-MAX_OUTPUT_CHARS)}`;
}

export function parseTaskBlock(tasksContent, taskId) {
  const { beforeAmendments, afterAmendments } = splitSpecAmendments(tasksContent || '');
  const body = afterAmendments ? `${beforeAmendments}\n\n${afterAmendments}` : beforeAmendments;
  const escaped = taskId.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  // Accept both legacy H2 task headings and the current H3 `### T-NNN:` plan
  // format. Keep the identifier boundary strict (`T-001` must not match
  // `T-001.1`) and stop at the next task heading, not merely the next H2.
  const headerRe = new RegExp(`^#{2,3}[ \\t]+${escaped}(?![A-Za-z0-9_.-])(?:[:][^\\r\\n]*|[ \\t][^\\r\\n]*)?$`, 'im');
  const match = headerRe.exec(body);
  if (!match) return null;

  const rest = body.slice(match.index + match[0].length);
  const nextSection = /^(?:##[ \t]+\S|###[ \t]+T-[0-9]{3}\b)/im.exec(rest);
  const block = nextSection ? rest.slice(0, nextSection.index) : rest;

  const field = (name) => block.match(new RegExp(`^[ \\t]*(?:-\\s*)?(?:\\*\\*)?${name}:(?:\\*\\*)?[ \\t]*(.+?)(?:\\*\\*)?[ \\t]*$`, 'im'));
  const value = (match) => match ? match[1].trim().replace(/^[`*_]+|[`*_]+$/g, '') : null;
  const approvalMatch = field('Approval');
  const statusMatch = field('Status');
  const riskMatch = field('Risk');
  const scopeMatch = field('Scope');
  const scopePaths = scopeMatch
    ? extractScopePaths(`### Scope\n- ${scopeMatch[1].replace(/\*\*$/, '').replace(/（[^）]*）|\([^)]*\)/g, '').trim()}\n### EndScope`)
    : extractScopePaths(block);

  return {
    taskId: taskId.toUpperCase(),
    approval: value(approvalMatch),
    status: value(statusMatch),
    // Same tiering as the planner and MCP: legacy `critical` is `high` (#824).
    risk: normalizeRiskTier(value(riskMatch) || '', 'standard'),
    scopePaths,
  };
}

export function discoverChangedFiles(projectRoot, explicitFiles, { baseRef = null } = {}) {
  if (Array.isArray(explicitFiles) && explicitFiles.length > 0) {
    return [...new Set(explicitFiles.map((f) => normalizeRelPath(f)).filter(Boolean))];
  }
  // Default: uncommitted changes against HEAD. --base <ref> widens it to every
  // change since that commit, for a task that committed part of its work
  // before the gate ran (#826). History is never widened implicitly.
  let diffBase = 'HEAD';
  if (baseRef !== null) {
    if (!/^[A-Za-z0-9._/~^@{}][A-Za-z0-9._/~^@{}-]*$/.test(String(baseRef))) {
      throw new Error(`Invalid --base ref: ${baseRef}`);
    }
    try {
      diffBase = execFileSync('git', ['rev-parse', '--verify', '--quiet', `${baseRef}^{commit}`], {
        cwd: projectRoot,
        encoding: 'utf8',
        stdio: ['ignore', 'pipe', 'ignore'],
      }).trim();
    } catch {
      throw new Error(`--base ref does not name a commit: ${baseRef}`);
    }
  }
  const files = new Set();
  // -z + core.quotePath=false: non-ASCII names arrive verbatim instead of as
  // C-quoted strings the scanner cannot open (#822). --relative: paths are
  // relative to projectRoot even when it is a subdirectory of the Git root,
  // and changes outside the project are excluded (#828).
  for (const args of [
    ['-c', 'core.quotePath=false', 'diff', '--name-only', '-z', '--relative', diffBase],
    ['-c', 'core.quotePath=false', 'ls-files', '-z', '--others', '--exclude-standard'],
  ]) {
    try {
      const out = execFileSync('git', args, {
        cwd: projectRoot,
        encoding: 'utf8',
        stdio: ['ignore', 'pipe', 'ignore'],
      });
      for (const entry of out.split('\0')) {
        const rel = normalizeRelPath(entry);
        if (rel) files.add(rel);
      }
    } catch {
      // ignore if not a git repo or HEAD unborn
    }
  }
  return [...files];
}

/**
 * A Scope entry is a file, a directory (`src/` or `src`) or a glob. A plain
 * bullet may carry prose after the path (`- src/a.js — note`), so its first
 * whitespace-separated token is matched as well.
 */
function isInTaskScope(relPath, scopePaths) {
  return scopePaths.some((raw) =>
    [...new Set([raw, raw.split(/\s+/)[0]])].some((entry) => {
      const dir = entry.replace(/\/+$/, '');
      return relPath === dir || relPath.startsWith(`${dir}/`) || globToRegExp(entry).test(relPath);
    }),
  );
}

function isPlaceholderScanTarget(relPath) {
  const p = normalizeRelPath(relPath).toLowerCase();
  if (p.startsWith('specs/') || p.startsWith('docs/') || p.startsWith('reports/') || p.startsWith('tests/')) {
    return false;
  }
  if (p.endsWith('.md') || p.endsWith('.json') || p.endsWith('.txt') || p.endsWith('.lock')) {
    return false;
  }
  return true;
}

function scanPlaceholders(projectRoot, changedFiles) {
  const findings = [];
  for (const rel of changedFiles) {
    if (!isPlaceholderScanTarget(rel)) continue;
    const abs = path.join(projectRoot, rel);
    if (!fs.existsSync(abs) || !fs.statSync(abs).isFile()) continue;
    const lines = normalizeNewlines(fs.readFileSync(abs, 'utf8')).split('\n');
    for (let i = 0; i < lines.length; i += 1) {
      if (PLACEHOLDER_RE.test(lines[i])) {
        findings.push({ file: rel, line: i + 1, text: lines[i].trim().slice(0, 160) });
      }
    }
  }
  return {
    passed: findings.length === 0,
    scannedFiles: changedFiles.filter(isPlaceholderScanTarget),
    findings,
  };
}

/**
 * Strip SQL comments (-- and /* ... *\/) while preserving newlines for exact line numbers
 * and recording which lines carry an explicit `sdd-allow-destructive` comment marker.
 */
function preprocessSql(raw) {
  const text = normalizeNewlines(raw);
  const allowLines = new Set();
  let cleaned = '';
  let line = 1;
  let i = 0;
  let inSingle = false;

  while (i < text.length) {
    const ch = text[i];
    const next = text[i + 1];

    if (inSingle) {
      cleaned += ch === '\n' ? '\n' : ' ';
      if (ch === '\n') line += 1;
      if (ch === "'" && next === "'") {
        cleaned += ' ';
        i += 2;
        continue;
      }
      if (ch === "'") inSingle = false;
      i += 1;
      continue;
    }

    if (ch === "'") {
      inSingle = true;
      cleaned += "'";
      i += 1;
      continue;
    }

    if (ch === '-' && next === '-') {
      const start = i;
      while (i < text.length && text[i] !== '\n') i += 1;
      const comment = text.slice(start, i);
      if (/sdd-allow-destructive/i.test(comment)) allowLines.add(line);
      continue;
    }

    if (ch === '/' && next === '*') {
      const startLine = line;
      const start = i;
      i += 2;
      while (i < text.length && !(text[i] === '*' && text[i + 1] === '/')) {
        if (text[i] === '\n') {
          cleaned += '\n';
          line += 1;
        }
        i += 1;
      }
      if (i < text.length) i += 2;
      const comment = text.slice(start, i);
      if (/sdd-allow-destructive/i.test(comment)) {
        for (let ln = startLine; ln <= line; ln += 1) allowLines.add(ln);
      }
      cleaned += ' ';
      continue;
    }

    if (ch === '\n') line += 1;
    cleaned += ch;
    i += 1;
  }

  return { cleaned, allowLines };
}

function scanSqlStatements(rel, raw, findings) {
  const { cleaned, allowLines } = preprocessSql(raw);
  const statements = [];
  let startIdx = 0;
  let currentLine = 1;
  let stmtStartLine = 1;

  for (let i = 0; i <= cleaned.length; i += 1) {
    const ch = cleaned[i];
    if (i === cleaned.length || ch === ';') {
      const chunk = cleaned.slice(startIdx, i);
      const leadingNewlines = (chunk.match(/^\s*/)[0].match(/\n/g) || []).length;
      const trimmed = chunk.trim();
      if (trimmed) {
        statements.push({ text: trimmed, line: stmtStartLine + leadingNewlines });
      }
      startIdx = i + 1;
      stmtStartLine = currentLine;
    } else if (ch === '\n') {
      currentLine += 1;
    }
  }

  for (const stmt of statements) {
    if (SQL_DESTRUCTIVE_RE.test(stmt.text)) {
      const allowedHere = allowLines.has(stmt.line) || allowLines.has(stmt.line - 1);
      if (!allowedHere) {
        findings.push({
          rule: 'SQL_DESTRUCTIVE_DDL',
          domain: 'SQL',
          file: rel,
          line: stmt.line,
          message: 'Destructive SQL DDL detected without per-statement marker (-- sdd-allow-destructive on same or preceding line)',
        });
      }
    }
    if (/^(?:DELETE\s+FROM\s+\S+|UPDATE\s+\S+[\s\S]*?\bSET\b)/i.test(stmt.text) && !/\bWHERE\b/i.test(stmt.text)) {
      findings.push({
        rule: 'SQL_UNGUARDED_DELETE_OR_UPDATE',
        domain: 'SQL',
        file: rel,
        line: stmt.line,
        message: 'DELETE/UPDATE statement without WHERE clause detected',
      });
    }
    if (/\bSELECT\s+\*\s+FROM\b/i.test(stmt.text)) {
      findings.push({
        rule: 'SQL_SELECT_STAR',
        severity: 'advisory',
        domain: 'SQL',
        file: rel,
        line: stmt.line,
        message: 'SELECT * detected; prefer explicit column lists for query stability and performance',
      });
    }
  }
}

function stripIacComments(raw) {
  const text = normalizeNewlines(raw);
  let out = '';
  let i = 0;
  let inSingle = false;
  let inDouble = false;

  while (i < text.length) {
    const ch = text[i];
    const next = text[i + 1];
    if (inSingle) {
      out += ch;
      if (ch === '\\' && next) {
        out += next;
        i += 2;
        continue;
      }
      if (ch === "'") inSingle = false;
      i += 1;
      continue;
    }
    if (inDouble) {
      out += ch;
      if (ch === '\\' && next) {
        out += next;
        i += 2;
        continue;
      }
      if (ch === '"') inDouble = false;
      i += 1;
      continue;
    }
    if (ch === "'") {
      inSingle = true;
      out += ch;
      i += 1;
      continue;
    }
    if (ch === '"') {
      inDouble = true;
      out += ch;
      i += 1;
      continue;
    }
    if (ch === '/' && next === '*') {
      i += 2;
      while (i < text.length && !(text[i] === '*' && text[i + 1] === '/')) {
        if (text[i] === '\n') out += '\n';
        i += 1;
      }
      if (i < text.length) i += 2;
      continue;
    }
    if ((ch === '/' && next === '/') || ch === '#') {
      while (i < text.length && text[i] !== '\n') i += 1;
      continue;
    }
    out += ch;
    i += 1;
  }
  return out;
}

function scanCloudIac(rel, raw, findings) {
  const stripped = stripIacComments(raw);
  const lines = stripped.split('\n');

  // 1. Multiline wildcard IAM detection
  const iamMatch = CLOUD_WILDCARD_IAM_RE.exec(stripped);
  if (iamMatch) {
    const lineNum = stripped.slice(0, iamMatch.index).split('\n').length;
    findings.push({
      rule: 'CLOUD_WILDCARD_IAM',
      domain: 'Cloud',
      file: rel,
      line: lineNum,
      message: 'Overly permissive wildcard IAM action (*) detected',
    });
  }

  // 2. Multiline block/window open admin port (22 / 3389) detection (excluding egress blocks)
  const reportedLines = new Set();
  for (let i = 0; i < lines.length; i += 1) {
    if (!PUBLIC_CIDR_RE.test(lines[i])) continue;
    const winStart = Math.max(0, i - 8);
    const winEnd = Math.min(lines.length, i + 9);
    const windowText = lines.slice(winStart, winEnd).join('\n');
    if (/\begress\b/i.test(windowText) && !/\bingress\b/i.test(windowText)) continue;
    if (ADMIN_PORT_RE.test(windowText)) {
      const lineNum = i + 1;
      if (!reportedLines.has(lineNum)) {
        reportedLines.add(lineNum);
        findings.push({
          rule: 'CLOUD_OPEN_ADMIN_PORT',
          domain: 'Cloud',
          file: rel,
          line: lineNum,
          message: 'Public exposure (0.0.0.0/0, ::/0, or *) on admin port (22/3389) detected',
        });
      }
    }
  }
}

function scanNonFunctionalSensors(projectRoot, changedFiles) {
  const findings = [];
  for (const rel of changedFiles) {
    const lower = normalizeRelPath(rel).toLowerCase();
    if (lower.startsWith('tests/') || lower.startsWith('specs/') || lower.startsWith('docs/') || lower.startsWith('reports/')) {
      continue;
    }
    const abs = path.join(projectRoot, rel);
    if (!fs.existsSync(abs) || !fs.statSync(abs).isFile()) continue;
    const raw = normalizeNewlines(fs.readFileSync(abs, 'utf8'));
    const lines = raw.split('\n');

    for (let i = 0; i < lines.length; i += 1) {
      for (const rule of SECRET_SENSOR_RULES) {
        if (rule.re.test(lines[i])) {
          findings.push({ rule: rule.id, domain: 'Security', file: rel, line: i + 1, message: rule.msg });
        }
      }
    }

    if (lower.endsWith('.sql')) {
      scanSqlStatements(rel, raw, findings);
    }

    const isIac =
      lower.endsWith('.bicep') ||
      lower.endsWith('.tf') ||
      ((lower.includes('infra/') || lower.includes('iac/') || lower.includes('cdk/') || lower.includes('cloudformation')) &&
        /\.(?:ts|js|py|ya?ml|json)$/.test(lower));
    if (isIac) {
      scanCloudIac(rel, raw, findings);
    }
  }
  const blockingFindings = findings.filter((f) => f.severity !== 'advisory');
  const advisoryFindings = findings.filter((f) => f.severity === 'advisory');
  return {
    passed: blockingFindings.length === 0,
    findings: blockingFindings,
    advisoryFindings,
  };
}

const BLOCKING_TICKET_SEVERITIES = new Set(['critical', 'major']);
// review-ticket-rules.md: status is open | resolved | rejected; only open blocks.
const NON_BLOCKING_TICKET_STATUSES = new Set(['resolved', 'rejected']);

function ticketScalar(raw) {
  // Drop a trailing YAML comment, then surrounding quotes.
  const value = String(raw).replace(/\s+#.*$/, '').trim();
  const quoted = /^(['"])(.*)\1$/.exec(value);
  return (quoted ? quoted[2] : value).trim();
}

/**
 * Reads the flat fields the ticket template defines: top-level `ticket_id`,
 * `status`, `severity`, and `feature` / `task` only from the lines directly
 * under the top-level `target:` key, so text inside other blocks (e.g. a
 * `problem: |` body) can never be mistaken for the target.
 */
function parseFlowMapping(body, into) {
  for (const pair of body.split(',')) {
    const kv = /^\s*(['"]?)([A-Za-z_][\w-]*)\1\s*:(.*)$/.exec(pair);
    if (kv && !(kv[2] in into)) into[kv[2]] = ticketScalar(kv[3]);
  }
}

function parseTicket(text) {
  const fields = {};
  const target = {};
  let inTarget = false;
  const lines = text.split('\n');
  for (let i = 0; i < lines.length; i += 1) {
    const line = lines[i];
    const top = /^([A-Za-z_][\w-]*):(.*)$/.exec(line);
    if (top) {
      inTarget = top[1] === 'target';
      if (!inTarget) {
        fields[top[1]] = ticketScalar(top[2]);
        continue;
      }
      // Flow style: target: {feature: x, task: T-001}, possibly split over
      // lines and followed by a comment (which may itself contain braces).
      const open = top[2].indexOf('{');
      if (open !== -1 && top[2].slice(0, open).trim() === '') {
        let body = top[2].slice(open + 1);
        while (!body.includes('}') && i + 1 < lines.length) body += ` ${lines[++i]}`;
        parseFlowMapping(body.slice(0, body.indexOf('}')), target);
        inTarget = false;
      }
      continue;
    }
    if (!inTarget) continue;
    const nested = /^[ \t]+([A-Za-z_][\w-]*):(.*)$/.exec(line);
    if (nested && !(nested[1] in target)) target[nested[1]] = ticketScalar(nested[2]);
  }
  return { fields, target };
}

/**
 * Open critical/major review tickets targeting exactly this feature and task
 * block the gate (#823). Resolved or rejected tickets, minor findings and
 * tickets for other tasks or features do not. A ticket without a status
 * counts as open. Unreadable entries (e.g. dangling links) are skipped.
 */
function checkReviewTickets(projectRoot, feature, taskState) {
  const dir = path.join(projectRoot, 'docs', 'review-tickets');
  const blocking = [];
  if (fs.existsSync(dir)) {
    for (const name of fs.readdirSync(dir).sort()) {
      if (!/\.ya?ml$/i.test(name)) continue;
      let text;
      try {
        const abs = path.join(dir, name);
        if (!fs.statSync(abs).isFile()) continue;
        text = normalizeNewlines(fs.readFileSync(abs, 'utf8')).replace(/^\uFEFF/, '');
      } catch {
        continue;
      }
      const { fields, target } = parseTicket(text);
      const status = (fields.status || 'open').toLowerCase();
      const severity = (fields.severity || '').toLowerCase();
      if (NON_BLOCKING_TICKET_STATUSES.has(status) || !BLOCKING_TICKET_SEVERITIES.has(severity)) continue;
      if (target.feature !== feature || String(target.task || '').toUpperCase() !== taskState.taskId) continue;
      blocking.push({ ticketId: fields.ticket_id || name.replace(/\.ya?ml$/i, ''), severity, status });
    }
  }
  return { passed: blocking.length === 0, blocking };
}

function checkOpenQuestionsGate(projectRoot, feature, taskState) {
  const featureDir = path.join(projectRoot, 'specs', feature);
  const reqPath = path.join(featureDir, 'requirements.md');
  const designPath = path.join(featureDir, 'design.md');
  const allOqs = mergeOpenQuestions(
    fs.existsSync(reqPath) ? parseOpenQuestions(fs.readFileSync(reqPath, 'utf8')) : [],
    fs.existsSync(designPath) ? parseOpenQuestions(fs.readFileSync(designPath, 'utf8')) : [],
  );
  const targetTask = taskState.taskId.toUpperCase();
  const provisional = allOqs.filter((q) => {
    if (q.confirmed) return false;
    return q.impactedTasks.length === 0 || q.impactedTasks.includes(targetTask);
  });
  const blocking = taskState.risk === 'high' && provisional.length > 0;
  return {
    passed: !blocking,
    blocking,
    provisionalCount: provisional.length,
    provisionalIds: provisional.map((q) => q.id),
  };
}

function appendFactoryMetric(projectRoot, record) {
  try {
    const dir = path.join(projectRoot, '.sdd');
    fs.mkdirSync(dir, { recursive: true });
    fs.appendFileSync(path.join(dir, 'factory-metrics.jsonl'), `${JSON.stringify(record)}\n`, 'utf8');
  } catch {
    // Non-fatal telemetry logging
  }
}

function runVerificationCommands(projectRoot, commands, failFast) {
  const results = [];
  for (const { label, command } of commands) {
    const start = Date.now();
    const res = spawnSync(command, {
      cwd: projectRoot,
      shell: true,
      encoding: 'utf8',
      timeout: 300000,
    });
    const durationMs = Date.now() - start;
    const exitCode = typeof res.status === 'number' ? res.status : 1;
    results.push({
      label,
      command,
      exitCode,
      durationMs,
      passed: exitCode === 0 && !res.error,
      error: res.error ? res.error.message : null,
      stdout: truncateTail(res.stdout),
      stderr: truncateTail(res.stderr),
    });
    if (failFast && (exitCode !== 0 || res.error)) break;
  }
  return results;
}

export function runSddGate({
  feature,
  taskId,
  projectRoot,
  commands = [],
  changedFiles = null,
  baseRef = null,
  baselinePath = null,
  skipDrift = false,
  skipSensors = false,
  outputPath = null,
  rootCausePhase = null,
  mode = 'standard',
  role = null,
  baselineCmd = null,
  candidateCmd = null,
  nfrBudgetPath = null,
  lockOwner = null,
  enableAntiTamper = false,
  enableAgentLint = false,
  enableSecurityGate = false,
  formalTla = null,
  formalCfg = null,
  formalTrace = null,
  formalRound = 0,
  failFast = false,
}) {
  assertValidFeatureName(feature);
  if (!['standard', 'rebuild'].includes(mode)) throw new Error('Unsupported gate mode');
  if (!taskId || !/^T-[A-Za-z0-9._-]+$/i.test(taskId)) {
    throw new Error(`Invalid task ID: ${taskId}`);
  }

  const root = resolveExplicitOrAutoRoot(projectRoot);
  const config = loadGuardrailsConfig(root);
  const tasksPath = path.join(root, 'specs', feature, 'tasks.md');
  if (!fs.existsSync(tasksPath)) {
    throw new Error(`Tasks file not found: specs/${feature}/tasks.md`);
  }

  const taskState = parseTaskBlock(fs.readFileSync(tasksPath, 'utf8'), taskId);
  if (!taskState) {
    throw new Error(`Task ${taskId} not found in specs/${feature}/tasks.md`);
  }

  // Optional fail-closed lock acquisition (NFR-005: task-lock.mjs exit 1 stays untouched)
  let lockCheck = { checked: false, passed: true, acquired: null };
  let acquiredLockForRelease = false;
  if (lockOwner) {
    const lockRes = acquireLock({ feature, taskId: taskState.taskId, owner: lockOwner, projectRoot: root });
    lockCheck = { checked: true, passed: Boolean(lockRes.acquired), ...lockRes };
    acquiredLockForRelease = Boolean(lockRes.acquired && !lockRes.reentrant);
  }

  try {
    const taskCheckErrors = [];
    if (!isApprovedValue(taskState.approval)) {
      taskCheckErrors.push(`Task ${taskId} is not Approved (found: ${taskState.approval || 'missing'})`);
    }
    if (taskState.status !== 'Implementation Complete' && taskState.status !== 'Done') {
      taskCheckErrors.push(
        `Task ${taskId} must be 'Implementation Complete' or 'Done' (found: ${taskState.status || 'missing'})`,
      );
    }
    const taskPrecondition = {
      passed: taskCheckErrors.length === 0,
      ...taskState,
      errors: taskCheckErrors,
    };

    let failFastStoppedAt = null;
    if (!lockCheck.passed) {
      failFastStoppedAt = 'lockCheck';
    } else if (failFast && !taskPrecondition.passed) {
      failFastStoppedAt = 'taskPrecondition';
    }

    let specDrift = { skipped: true, passed: true, status: 'SKIPPED' };
    if (!skipDrift && !failFastStoppedAt) {
      try {
        const report = checkSpecDrift({ feature, projectRoot: root, baselinePath });
        specDrift = {
          skipped: false,
          passed: report.status !== 'UNDECLARED_DRIFT' && report.status !== 'UNVERIFIABLE',
          ...report,
        };
      } catch (err) {
        specDrift = {
          skipped: false,
          passed: false,
          status: 'BASELINE_ERROR',
          error: err.message,
        };
      }
      if (failFast && !specDrift.passed) failFastStoppedAt = 'specDrift';
    }

    let antiTamper = { skipped: true, passed: true, status: 'SKIPPED' };
    if (enableAntiTamper && !failFastStoppedAt) {
      try {
        const atReport = checkAntiTampering({ projectRoot: root, baseRef, feature });
        antiTamper = { skipped: false, passed: atReport.status === 'CLEAN', ...atReport };
      } catch (err) {
        antiTamper = { skipped: false, passed: false, status: 'TOOL_ERROR', error: err.message };
      }
      if (failFast && !antiTamper.passed) failFastStoppedAt = 'antiTamper';
    }

    let writeScope = { skipped: true, passed: true };
    if (role !== null && !failFastStoppedAt) {
      try {
        writeScope = { skipped: false, ...checkWriteScope({ projectRoot: root, role, baseRef }) };
      } catch (err) {
        writeScope = { skipped: false, passed: false, role, error: err.message };
      }
      if (failFast && !writeScope.passed) failFastStoppedAt = 'writeScope';
    }
    const resolvedChanged = failFastStoppedAt ? [] : discoverChangedFiles(root, changedFiles, { baseRef });

    let agentLint = { skipped: true, passed: true, status: 'SKIPPED' };
    if ((enableAgentLint || config.agent_lint?.enabled) && !failFastStoppedAt) {
      const lintReport = runAgentLint({
        projectRoot: root,
        files: resolvedChanged,
        baseRef,
        diffOnly: config.agent_lint.diff_only && (!Array.isArray(changedFiles) || baseRef !== null ||
          spawnSync('git', ['rev-parse', '--verify', 'HEAD'], { cwd: root, stdio: 'ignore' }).status === 0),
        mode: enableAgentLint ? 'strict' : config.agent_lint?.mode,
      });
      agentLint = { skipped: false, passed: lintReport.status !== 'FAIL', ...lintReport };
      if (failFast && !agentLint.passed) failFastStoppedAt = 'agentLint';
    }

    let securityGate = { skipped: true, passed: true, status: 'SKIPPED' };
    if ((enableSecurityGate || config.security_audit?.enabled) && !failFastStoppedAt) {
      const secReport = runSecurityGate({
        projectRoot: root,
        files: resolvedChanged.length > 0 ? resolvedChanged : null,
        mode: enableSecurityGate ? 'strict' : config.security_audit?.mode,
      });
      securityGate = { skipped: false, passed: secReport.exitCode === 0, ...secReport };
      if (failFast && !securityGate.passed) failFastStoppedAt = 'securityGate';
    }

    let formalGate = { skipped: true, passed: true, status: 'SKIPPED' };
    if (formalTla && !failFastStoppedAt) {
      const fReport = runFormalGate({
        projectRoot: root,
        tlaPath: formalTla,
        cfgPath: formalCfg,
        tracePath: formalTrace,
        round: formalRound,
        risk: taskState.risk,
        feature,
        baseRef,
        adapter: config.formal_verification?.checker?.adapter || 'none',
        mode: config.formal_verification?.enabled ? config.formal_verification.mode : 'shadow',
      });
      formalGate = { skipped: false, passed: fReport.exitCode === 0, ...fReport };
      if (failFast && !formalGate.passed) failFastStoppedAt = 'formalGate';
    }

    const placeholders = failFastStoppedAt
      ? { passed: true, skipped: true, scannedFiles: [], findings: [] }
      : scanPlaceholders(root, resolvedChanged);
    if (failFast && !placeholders.passed) failFastStoppedAt = 'placeholders';
    const nonFunctionalSensors =
      skipSensors || failFastStoppedAt
        ? { skipped: true, passed: true, findings: [] }
        : { skipped: false, ...scanNonFunctionalSensors(root, resolvedChanged) };
    if (failFast && !nonFunctionalSensors.passed) failFastStoppedAt = 'nonFunctionalSensors';
    const openQuestions = failFastStoppedAt
      ? { passed: true, blocking: false, provisionalCount: 0, provisionalIds: [] }
      : checkOpenQuestionsGate(root, feature, taskState);
    if (failFast && !openQuestions.passed) failFastStoppedAt = 'openQuestions';
    const reviewTickets = failFastStoppedAt
      ? { passed: true, blocking: [] }
      : checkReviewTickets(root, feature, taskState);
    if (failFast && !reviewTickets.passed) failFastStoppedAt = 'reviewTickets';

    const taskScope = taskState.scopePaths;
    const inScope = (rel) => taskScope.length === 0 || isInTaskScope(rel, taskScope);
    for (const finding of [...placeholders.findings, ...(nonFunctionalSensors.findings || [])]) {
      if (finding && typeof finding.file === 'string') finding.inTaskScope = inScope(finding.file);
    }
    const scope = {
      mode: Array.isArray(changedFiles) && changedFiles.length > 0 ? 'explicit' : baseRef ? 'base' : 'uncommitted',
      ...(baseRef ? { baseRef } : {}),
      taskScope,
      outOfScopeFiles: resolvedChanged.filter((rel) => !inScope(rel)),
    };
    const commandResults = failFastStoppedAt ? [] : runVerificationCommands(root, commands, failFast);
    const allCommandsPassed = commandResults.every((r) => r.passed);

    if (failFast && !allCommandsPassed) failFastStoppedAt = 'commands';

    let rebuildDifferential = { skipped: true, passed: true };
    if (mode === 'rebuild' && !failFastStoppedAt) {
      rebuildDifferential = {
        skipped: false,
        ...runRebuildDifferentialCheck({
          projectRoot: root,
          baseRef,
          baselineCmd,
          candidateCmd,
          nfrBudgetPath,
        }),
      };
    }

    const verdict =
      !failFastStoppedAt &&
      lockCheck.passed &&
      taskPrecondition.passed &&
      specDrift.passed &&
      antiTamper.passed &&
      writeScope.passed &&
      agentLint.passed &&
      securityGate.passed &&
      formalGate.passed &&
      placeholders.passed &&
      nonFunctionalSensors.passed &&
      openQuestions.passed &&
      reviewTickets.passed &&
      allCommandsPassed &&
      rebuildDifferential.passed
        ? 'PASS'
        : 'FAIL';

    const coverage = {
      commandsRun: commandResults.length,
      specDriftChecked: !specDrift.skipped,
      sensorsChecked: !nonFunctionalSensors.skipped,
    };
    coverage.complete = coverage.commandsRun > 0 && coverage.specDriftChecked && coverage.sensorsChecked;
    const warnings = [];
    if (coverage.commandsRun === 0 && mode !== 'rebuild') {
      warnings.push('NO_VERIFICATION_COMMANDS: no --cmd was run; this PASS does not cover tests, build or lint.');
    }
    if (!coverage.specDriftChecked) warnings.push('SPEC_DRIFT_SKIPPED: --skip-drift was set.');
    if ((specDrift.newlyApprovedTasks || []).includes(taskState.taskId)) {
      warnings.push(
        `APPROVED_AFTER_BASELINE: ${taskState.taskId} became Approved after the spec baseline was recorded; confirm a human approved it.`,
      );
    }
    if (!coverage.sensorsChecked) warnings.push('SENSORS_SKIPPED: --skip-sensors was set.');
    if (scope.outOfScopeFiles.length > 0) {
      warnings.push(
        `OUT_OF_SCOPE_CHANGES: ${scope.outOfScopeFiles.length} changed file(s) outside this task's Scope were scanned; ` +
          'in a shared working tree pass the task\'s own files with --changed-files.',
      );
    }

    const result = {
      schema: 'sdd-gate-execution/v1',
      runId: crypto.randomUUID(),
      feature,
      taskId: taskState.taskId,
      mode,
      ...(failFastStoppedAt ? { failFastStoppedAt } : {}),
      executedAt: new Date().toISOString(),
      verdict,
      specInputs: taskEvidenceInputs(createFsReadonlyIo(root), { feature, taskId: taskState.taskId }),
      coverage,
      scope,
      warnings,
      checks: {
        lockCheck,
        taskPrecondition,
        specDrift,
        antiTamper,
        writeScope,
        agentLint,
        securityGate,
        formalGate,
        placeholders,
        nonFunctionalSensors,
        openQuestions,
        reviewTickets,
        commands: commandResults,
        rebuildDifferential,
      },
    };

    const resolvedOutput = outputPath
      ? path.resolve(outputPath)
      : path.join(root, 'reports', 'quality-gate', `${feature}-${taskState.taskId}.execution.json`);
    fs.mkdirSync(path.dirname(resolvedOutput), { recursive: true });
    fs.writeFileSync(resolvedOutput, `${JSON.stringify(result, null, 2)}\n`, 'utf8');

    appendFactoryMetric(root, {
      runId: result.runId,
      timestamp: result.executedAt,
      feature,
      taskId: taskState.taskId,
      risk: taskState.risk,
      verdict,
      specDriftStatus: specDrift.status,
      driftSkipped: Boolean(skipDrift),
      sensorsSkipped: Boolean(skipSensors),
      provisionalOqCount: openQuestions.provisionalCount,
      provisionalOqBlocking: Boolean(openQuestions.blocking),
      sensorFindingCount: nonFunctionalSensors.findings.length,
      placeholderFindingCount: placeholders.findings.length,
      failedCommandCount: commandResults.filter((c) => !c.passed).length,
      commandsRun: commandResults.length,
      advisoryFindingCount: (nonFunctionalSensors.advisoryFindings || []).length,
      ...(rootCausePhase ? { rootCausePhase } : {}),
      commandDurationMs: commandResults.reduce((acc, c) => acc + c.durationMs, 0),
    });

    return { result, outputPath: resolvedOutput };
  } finally {
    if (acquiredLockForRelease && lockOwner) {
      try {
        releaseLock({ feature, taskId: taskState.taskId, owner: lockOwner, projectRoot: root });
      } catch {
        // non-fatal release
      }
    }
  }
}

function parseArgs(argv) {
  const opts = {
    feature: null,
    taskId: null,
    root: null,
    commands: [],
    changedFiles: null,
    baseRef: null,
    baselinePath: null,
    outputPath: null,
    skipDrift: false,
    skipSensors: false,
    rootCausePhase: null,
    mode: 'standard',
    baselineCmd: null,
    candidateCmd: null,
    nfrBudgetPath: null,
    lockOwner: null,
    enableAntiTamper: false,
    enableAgentLint: false,
    enableSecurityGate: false,
    formalTla: null,
    formalCfg: null,
    failFast: false,
  };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--feature' && argv[i + 1]) {
      opts.feature = argv[++i];
    } else if (arg === '--task' && argv[i + 1]) {
      opts.taskId = argv[++i];
    } else if (arg === '--root' && argv[i + 1]) {
      opts.root = argv[++i];
    } else if (arg === '--baseline' && argv[i + 1]) {
      opts.baselinePath = argv[++i];
    } else if (arg === '--output' && argv[i + 1]) {
      opts.outputPath = argv[++i];
    } else if (arg === '--root-cause' && argv[i + 1]) {
      opts.rootCausePhase = argv[++i];
    } else if (arg === '--changed-files' && argv[i + 1]) {
      opts.changedFiles = argv[++i].split(',').map((s) => s.trim()).filter(Boolean);
    } else if (arg === '--base' && argv[i + 1]) {
      opts.baseRef = argv[++i];
    } else if (arg === '--role') {
      opts.role = argv[++i] || '';
    } else if (arg === '--mode' && argv[i + 1]) {
      opts.mode = argv[++i];
    } else if (arg === '--baseline-cmd' && argv[i + 1]) {
      opts.baselineCmd = argv[++i];
    } else if (arg === '--candidate-cmd' && argv[i + 1]) {
      opts.candidateCmd = argv[++i];
    } else if (arg === '--nfr-budget' && argv[i + 1]) {
      opts.nfrBudgetPath = argv[++i];
    } else if (arg === '--lock-owner' && argv[i + 1]) {
      opts.lockOwner = argv[++i];
    } else if (arg === '--anti-tamper') {
      opts.enableAntiTamper = true;
    } else if (arg === '--agent-lint') {
      opts.enableAgentLint = true;
    } else if (arg === '--security-gate') {
      opts.enableSecurityGate = true;
    } else if (arg === '--formal-tla' && argv[i + 1]) {
      opts.formalTla = argv[++i];
    } else if (arg === '--formal-trace' && argv[i + 1]) {
      opts.formalTrace = argv[++i];
    } else if (arg === '--formal-round' && argv[i + 1]) {
      opts.formalRound = Number(argv[++i]);
    } else if (arg === '--formal-cfg' && argv[i + 1]) {
      opts.formalCfg = argv[++i];
    } else if (arg === '--fail-fast') {
      opts.failFast = true;
    } else if (arg === '--cmd' && argv[i + 1]) {
      const raw = argv[++i];
      const eq = raw.indexOf('=');
      if (eq > 0) {
        opts.commands.push({ label: raw.slice(0, eq).trim(), command: raw.slice(eq + 1).trim() });
      } else {
        opts.commands.push({ label: `cmd-${opts.commands.length + 1}`, command: raw.trim() });
      }
    } else if (arg === '--skip-drift') {
      opts.skipDrift = true;
    } else if (arg === '--skip-sensors') {
      opts.skipSensors = true;
    }
  }
  return opts;
}

function main() {
  const opts = parseArgs(process.argv.slice(2));
  if (!opts.feature || !opts.taskId) {
    process.stderr.write(
      'Usage: node run-sdd-gate.mjs --feature <feature> --task <T-NNN> [--root <dir>] [--cmd "label=command"] [--changed-files "a.js,b.js"] [--base <git-ref>] [--role implementer] [--mode standard|rebuild] [--baseline-cmd <cmd> --candidate-cmd <cmd>] [--nfr-budget <path>] [--lock-owner <id>] [--anti-tamper] [--agent-lint] [--security-gate] [--formal-tla <path> --formal-cfg <path> --formal-trace <path> --formal-round <n>] [--fail-fast] [--output <path>] [--skip-drift] [--skip-sensors]\n',
    );
    process.exit(2);
  }
  try {
    const { result, outputPath } = runSddGate({
      feature: opts.feature,
      taskId: opts.taskId,
      projectRoot: opts.root || process.cwd(),
      commands: opts.commands,
      changedFiles: opts.changedFiles,
      baseRef: opts.baseRef,
      baselinePath: opts.baselinePath,
      skipDrift: opts.skipDrift,
      skipSensors: opts.skipSensors,
      outputPath: opts.outputPath,
      rootCausePhase: opts.rootCausePhase,
      mode: opts.mode,
      role: opts.role,
      baselineCmd: opts.baselineCmd,
      candidateCmd: opts.candidateCmd,
      nfrBudgetPath: opts.nfrBudgetPath,
      lockOwner: opts.lockOwner,
      enableAntiTamper: opts.enableAntiTamper,
      enableAgentLint: opts.enableAgentLint,
      enableSecurityGate: opts.enableSecurityGate,
      formalTla: opts.formalTla,
      formalCfg: opts.formalCfg,
      formalTrace: opts.formalTrace,
      formalRound: opts.formalRound,
      failFast: opts.failFast,
    });
    process.stdout.write(`${JSON.stringify({ ...result, outputPath }, null, 2)}\n`);
    for (const warning of result.warnings) process.stderr.write(`run-sdd-gate warning: ${warning}\n`);
    process.exit(result.verdict === 'PASS' ? 0 : 1);
  } catch (err) {
    process.stderr.write(`run-sdd-gate error: ${err.message}\n`);
    process.exit(2);
  }
}

if (isMainModule(import.meta.url, 'run-sdd-gate.mjs')) {
  main();
}
