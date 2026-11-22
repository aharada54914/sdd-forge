#!/usr/bin/env node
/**
 * Unified deterministic runner for SDD Core's sdd-gate (v2 Lightweight Guardrails).
 * Uses the packaged domain validator for features with v2 Concept Test evidence.
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
 *                         [--cmd "label=command"] [--changed-files "a.js,b.js"]
 *                         [--baseline <path>] [--output <json-path>]
 *                         [--skip-drift] [--skip-sensors]
 */
import { execFileSync, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { checkSpecDrift } from './check-spec-drift.mjs';
import {
  assertValidFeatureName,
  isCliEntrypoint,
  normalizeNewlines,
  normalizeRelPath,
  resolveExplicitOrAutoRoot,
  splitSpecAmendments,
} from './guardrails-lib.mjs';
import { mergeOpenQuestions, parseOpenQuestions } from './render-decision-view.mjs';

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
  const headerRe = new RegExp(`^##[ \\t]+${escaped}(?:\\b|\\s|$).*$`, 'im');
  const match = headerRe.exec(body);
  if (!match) return null;

  const rest = body.slice(match.index + match[0].length);
  const nextH2 = /^##[ \t]+\S/m.exec(rest);
  const block = nextH2 ? rest.slice(0, nextH2.index) : rest;

  const approvalMatch = block.match(/^[ \t]*Approval:[ \t]*(.+)$/m);
  const statusMatch = block.match(/^[ \t]*Status:[ \t]*(.+)$/m);
  const riskMatch = block.match(/^[ \t]*Risk:[ \t]*(.+)$/m);

  return {
    taskId: taskId.toUpperCase(),
    approval: approvalMatch ? approvalMatch[1].trim() : null,
    status: statusMatch ? statusMatch[1].trim() : null,
    risk: riskMatch ? riskMatch[1].trim().toLowerCase() : 'standard',
  };
}

function discoverChangedFiles(projectRoot, explicitFiles) {
  if (Array.isArray(explicitFiles) && explicitFiles.length > 0) {
    return [...new Set(explicitFiles.map((f) => normalizeRelPath(f)).filter(Boolean))];
  }
  const files = new Set();
  for (const args of [
    ['diff', '--name-only', 'HEAD'],
    ['ls-files', '--others', '--exclude-standard'],
  ]) {
    try {
      const out = execFileSync('git', args, {
        cwd: projectRoot,
        encoding: 'utf8',
        stdio: ['ignore', 'pipe', 'ignore'],
      });
      for (const line of out.split('\n')) {
        const rel = normalizeRelPath(line);
        if (rel) files.add(rel);
      }
    } catch {
      // ignore if not a git repo or HEAD unborn
    }
  }
  return [...files];
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

function runVerificationCommands(projectRoot, commands) {
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
  }
  return results;
}

function conceptRecordSchema(contents, filename) {
  let raw = contents;
  if (filename.endsWith('.md')) {
    const blocks = [...contents.matchAll(/^```json\r?\n([\s\S]*?)^```[ \t]*\r?$/gm)];
    if (blocks.length !== 1) return null;
    raw = blocks[0][1];
  }
  try {
    const schema = JSON.parse(raw)?.schema;
    if (schema === 'concept-test/v2') return schema;
    if (schema !== 'concept-test/v1') return null;
    // JSON.parse alone retains only the last duplicate schema key.
    let schemaKeys = 0;
    for (const match of raw.matchAll(/("(?:[^"\\]|\\.)*")\s*(:)?/g)) {
      if (match[2] && JSON.parse(match[1]) === 'schema') schemaKeys++;
    }
    return schemaKeys === 1 ? schema : null;
  } catch {
    return null;
  }
}

function needsConceptCheck(root, feature) {
  const prefix = `specs/${feature}/concept-test`;
  const receipt = prefix + '.decision.json';
  const paths = [receipt, prefix + '.json', prefix + '.md'];
  for (const rel of paths) {
    const file = path.join(root, rel);
    const stat = fs.lstatSync(file, { throwIfNoEntry: false });
    if (stat && (rel === receipt || !stat.isFile()
        || conceptRecordSchema(fs.readFileSync(file, 'utf8'), rel) !== 'concept-test/v1')) return true;
  }

  // A tracked receipt or proposal still applies after deletion or restoration
  // of an old version. Scope the lookup to this feature in this checkout.
  let repo = root;
  while (!fs.existsSync(path.join(repo, '.git'))) {
    const parent = path.dirname(repo);
    if (parent === repo) return false;
    repo = parent;
  }
  const marker = path.join(repo, '.git');
  if (fs.statSync(marker).isDirectory() && !fs.existsSync(path.join(marker, 'HEAD'))
      && fs.readdirSync(marker).length === 0) return false;
  const env = Object.fromEntries(Object.entries(process.env).filter(([key]) => !key.startsWith('GIT_')));
  const git = (...args) => execFileSync('git', ['--no-replace-objects', '--literal-pathspecs', '-C', root, ...args], {
    encoding: 'utf8', env, stdio: ['ignore', 'pipe', 'pipe'], maxBuffer: 16 * 1024 * 1024,
  });
  const blobs = new Map();
  const remember = (filename, ...oids) => {
    for (const oid of oids) if (!/^0+$/.test(oid)) blobs.set(oid + path.extname(filename), { filename, oid });
  };
  let index;
  try {
    index = git('ls-files', '--stage', '-z', '--', ...paths);
  } catch (err) {
    // Git is optional for SDD Core. Live v2 evidence was checked above.
    if (err.code === 'ENOENT') return null;
    throw err;
  }
  for (const entry of index.split('\0').filter(Boolean)) {
    const [meta, filename] = entry.split('\t');
    if (filename.endsWith('/concept-test.decision.json')) return true;
    remember(filename, meta.split(' ')[1]);
  }
  const indexedBlobs = new Set(blobs.keys());
  let history = '';
  try {
    history = git('log', '--raw', '--format=', '--full-history', '-m', '--no-renames',
      '--no-abbrev', '-z', 'HEAD', '--', ...paths);
  } catch (err) {
    // In a new repository there is a valid index but HEAD has no commit.
    // Other history errors block the gate, including missing objects.
    if (err.status !== 128) throw err;
    const branch = git('symbolic-ref', '--quiet', 'HEAD').trim();
    try { git('show-ref', '--verify', '--quiet', branch); }
    catch (refError) { if (refError.status === 1) history = null; else throw refError; }
    if (history !== null) throw err;
  }
  const changes = (history || '').split('\0');
  for (let i = 0; i + 1 < changes.length; i += 2) {
    const filename = changes[i + 1];
    if (filename.endsWith('/concept-test.decision.json')) return true;
    const [, , before, after] = changes[i].trim().split(' ');
    remember(filename, before, after);
  }
  for (const [key, { filename, oid }] of blobs) {
    const schema = conceptRecordSchema(git('cat-file', 'blob', oid), filename);
    // Ambiguous current/indexed evidence needs validation. A historical
    // narrative draft alone does not establish that this feature adopted v2.
    if (schema === 'concept-test/v2' || (schema === null && indexedBlobs.has(key))) return true;
  }
  return false;
}

function checkConceptTest(root, feature) {
  try {
    const required = needsConceptCheck(root, feature);
    if (required === null) return { passed: true, status: 'NOT_APPLICABLE', history: 'GIT_UNAVAILABLE' };
    if (!required) return { passed: true, status: 'NOT_APPLICABLE' };
    const win = process.platform === 'win32';
    const script = fileURLToPath(new URL(`../../../sdd-domain/scripts/validate-concept-test.${win ? 'ps1' : 'sh'}`, import.meta.url));
    const args = [...(win ? ['-NoProfile', '-File'] : []), script, '--root', root, '--feature', feature, '--require-v2'];
    const result = spawnSync(win ? 'pwsh' : 'sh', args, { cwd: root, encoding: 'utf8' });
    const status = result.stdout?.trim();
    if (result.status === 0 && status === 'CONTINUE') return { passed: true, status };
    if ((result.status === 2 && status === 'DEFER') || (result.status === 3 && status === 'REJECT')) return { passed: false, status };
    return { passed: false, status: 'BLOCK', error: truncateTail(result.error?.message || result.stderr || 'Invalid concept-test result').trim() };
  } catch (err) {
    return { passed: false, status: 'BLOCK', error: truncateTail(err.message) };
  }
}

export function runSddGate({
  feature,
  taskId,
  projectRoot,
  commands = [],
  changedFiles = null,
  baselinePath = null,
  skipDrift = false,
  skipSensors = false,
  outputPath = null,
  rootCausePhase = null,
}) {
  assertValidFeatureName(feature);
  if (!taskId || !/^T-[A-Za-z0-9._-]+$/i.test(taskId)) {
    throw new Error(`Invalid task ID: ${taskId}`);
  }

  const root = resolveExplicitOrAutoRoot(projectRoot);
  const tasksPath = path.join(root, 'specs', feature, 'tasks.md');
  if (!fs.existsSync(tasksPath)) {
    throw new Error(`Tasks file not found: specs/${feature}/tasks.md`);
  }

  const taskState = parseTaskBlock(fs.readFileSync(tasksPath, 'utf8'), taskId);
  if (!taskState) {
    throw new Error(`Task ${taskId} not found in specs/${feature}/tasks.md`);
  }

  const taskCheckErrors = [];
  if (!taskState.approval || !/^Approved\b/.test(taskState.approval)) {
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

  let specDrift = { skipped: true, passed: true, status: 'SKIPPED' };
  if (!skipDrift) {
    try {
      const report = checkSpecDrift({ feature, projectRoot: root, baselinePath });
      specDrift = {
        skipped: false,
        passed: report.status !== 'UNDECLARED_DRIFT',
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
  }

  const resolvedChanged = discoverChangedFiles(root, changedFiles);
  const placeholders = scanPlaceholders(root, resolvedChanged);
  const nonFunctionalSensors = skipSensors
    ? { skipped: true, passed: true, findings: [] }
    : { skipped: false, ...scanNonFunctionalSensors(root, resolvedChanged) };
  const openQuestions = checkOpenQuestionsGate(root, feature, taskState);
  const conceptTest = checkConceptTest(root, feature);
  const commandResults = conceptTest.passed ? runVerificationCommands(root, commands) : [];
  const allCommandsPassed = commandResults.every((r) => r.passed);

  const verdict =
    taskPrecondition.passed &&
    specDrift.passed &&
    placeholders.passed &&
    nonFunctionalSensors.passed &&
    openQuestions.passed &&
    conceptTest.passed &&
    allCommandsPassed
      ? 'PASS'
      : 'FAIL';

  const result = {
    schema: 'sdd-gate-execution/v1',
    feature,
    taskId: taskState.taskId,
    executedAt: new Date().toISOString(),
    verdict,
    checks: {
      taskPrecondition,
      specDrift,
      placeholders,
      nonFunctionalSensors,
      openQuestions,
      conceptTest,
      commands: commandResults,
    },
  };

  const resolvedOutput = outputPath
    ? path.resolve(outputPath)
    : path.join(root, 'reports', 'quality-gate', `${feature}-${taskState.taskId}.execution.json`);
  fs.mkdirSync(path.dirname(resolvedOutput), { recursive: true });
  fs.writeFileSync(resolvedOutput, `${JSON.stringify(result, null, 2)}\n`, 'utf8');

  appendFactoryMetric(root, {
    timestamp: result.executedAt,
    feature,
    taskId: taskState.taskId,
    risk: taskState.risk,
    verdict,
    specDriftStatus: specDrift.status,
    driftSkipped: Boolean(skipDrift),
    sensorsSkipped: Boolean(skipSensors),
    provisionalOqCount: openQuestions.provisionalCount,
    sensorFindingCount: nonFunctionalSensors.findings.length,
    advisoryFindingCount: (nonFunctionalSensors.advisoryFindings || []).length,
    ...(rootCausePhase ? { rootCausePhase } : {}),
    commandDurationMs: commandResults.reduce((acc, c) => acc + c.durationMs, 0),
  });

  return { result, outputPath: resolvedOutput };
}

function parseArgs(argv) {
  const opts = {
    feature: null,
    taskId: null,
    root: null,
    commands: [],
    changedFiles: null,
    baselinePath: null,
    outputPath: null,
    skipDrift: false,
    skipSensors: false,
    rootCausePhase: null,
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
      'Usage: node run-sdd-gate.mjs --feature <feature> --task <T-NNN> [--root <dir>] [--cmd "label=command"] [--changed-files "a.js,b.js"] [--output <path>] [--skip-drift] [--skip-sensors]\n',
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
      baselinePath: opts.baselinePath,
      skipDrift: opts.skipDrift,
      skipSensors: opts.skipSensors,
      outputPath: opts.outputPath,
      rootCausePhase: opts.rootCausePhase,
    });
    process.stdout.write(`${JSON.stringify({ ...result, outputPath }, null, 2)}\n`);
    process.exit(result.verdict === 'PASS' ? 0 : 1);
  } catch (err) {
    process.stderr.write(`run-sdd-gate error: ${err.message}\n`);
    process.exit(2);
  }
}

if (isCliEntrypoint(import.meta.url)) {
  main();
}
