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
 *                         [--cmd "label=command"] [--changed-files "a.js,b.js"]
 *                         [--baseline <path>] [--output <json-path>]
 *                         [--skip-drift] [--skip-sensors]
 */
import { execFileSync, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { checkSpecDrift } from './check-spec-drift.mjs';
import {
  assertValidFeatureName,
  normalizeNewlines,
  normalizeRelPath,
  resolveExplicitOrAutoRoot,
  splitSpecAmendments,
} from './guardrails-lib.mjs';
import { mergeOpenQuestions, parseOpenQuestions } from './render-decision-view.mjs';
import { normalizeRiskTier } from './v2-readonly-core.mjs';

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
  // The ID must end at whitespace or end of line, exactly like the planner and
  // MCP (parseTasksSummary): `T-001` must never match `## T-001.1` (#821).
  const headerRe = new RegExp(`^##[ \\t]+${escaped}(?:[ \\t].*)?$`, 'im');
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
    // Same tiering as the planner and MCP: legacy `critical` is `high` (#824).
    risk: normalizeRiskTier(riskMatch ? riskMatch[1] : '', 'standard'),
  };
}

export function discoverChangedFiles(projectRoot, explicitFiles) {
  if (Array.isArray(explicitFiles) && explicitFiles.length > 0) {
    return [...new Set(explicitFiles.map((f) => normalizeRelPath(f)).filter(Boolean))];
  }
  const files = new Set();
  // -z + core.quotePath=false: non-ASCII names arrive verbatim instead of as
  // C-quoted strings the scanner cannot open (#822). --relative: paths are
  // relative to projectRoot even when it is a subdirectory of the Git root,
  // and changes outside the project are excluded (#828).
  for (const args of [
    ['-c', 'core.quotePath=false', 'diff', '--name-only', '-z', '--relative', 'HEAD'],
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
  const commandResults = runVerificationCommands(root, commands);
  const allCommandsPassed = commandResults.every((r) => r.passed);

  const verdict =
    taskPrecondition.passed &&
    specDrift.passed &&
    placeholders.passed &&
    nonFunctionalSensors.passed &&
    openQuestions.passed &&
    allCommandsPassed
      ? 'PASS'
      : 'FAIL';

  // What this run actually verified (#825). A mechanical PASS with zero
  // verification commands or skipped drift/sensor checks is not Done evidence;
  // consumers must read `coverage.complete` before treating PASS as such.
  const coverage = {
    commandsRun: commandResults.length,
    specDriftChecked: !specDrift.skipped,
    sensorsChecked: !nonFunctionalSensors.skipped,
  };
  coverage.complete = coverage.commandsRun > 0 && coverage.specDriftChecked && coverage.sensorsChecked;
  const warnings = [];
  if (coverage.commandsRun === 0) {
    warnings.push('NO_VERIFICATION_COMMANDS: no --cmd was run; this PASS does not cover tests, build or lint.');
  }
  if (!coverage.specDriftChecked) warnings.push('SPEC_DRIFT_SKIPPED: --skip-drift was set.');
  if (!coverage.sensorsChecked) warnings.push('SENSORS_SKIPPED: --skip-sensors was set.');

  const result = {
    schema: 'sdd-gate-execution/v1',
    feature,
    taskId: taskState.taskId,
    executedAt: new Date().toISOString(),
    verdict,
    coverage,
    warnings,
    checks: {
      taskPrecondition,
      specDrift,
      placeholders,
      nonFunctionalSensors,
      openQuestions,
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
    provisionalOqBlocking: Boolean(openQuestions.blocking),
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
    for (const warning of result.warnings) process.stderr.write(`run-sdd-gate warning: ${warning}\n`);
    process.exit(result.verdict === 'PASS' ? 0 : 1);
  } catch (err) {
    process.stderr.write(`run-sdd-gate error: ${err.message}\n`);
    process.exit(2);
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  main();
}
