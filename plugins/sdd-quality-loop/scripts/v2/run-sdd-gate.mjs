#!/usr/bin/env node
/**
 * Unified deterministic runner for SDD Core's sdd-gate (v2 Lightweight Guardrails).
 * Zero external dependencies — Node.js >= 20 LTS built-in modules only.
 *
 * Runs in one invocation:
 *   1. Task precondition check (Approval: Approved, Status: Implementation Complete|Done)
 *   2. Spec Drift check (checkSpecDrift — catches silent goalpost moving)
 *   3. Placeholder scan on changed code files
 *   4. Project verification commands (--cmd "label=command")
 *
 * Usage:
 *   node run-sdd-gate.mjs --feature <feature> --task <T-NNN> [--root <dir>]
 *                         [--cmd "test=node --test"] [--changed-files "a.js,b.js"]
 *                         [--baseline <path>] [--output <json-path>] [--skip-drift]
 */
import { execFileSync, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { checkSpecDrift } from './check-spec-drift.mjs';
import { findProjectRoot, normalizeNewlines, toPosixPath } from './guardrails-lib.mjs';

const PLACEHOLDER_RE =
  /\b(?:TODO|FIXME|TBD)\b|NotImplementedError|throw\s+new\s+Error\(\s*['"]Not implemented|unimplemented!\(\)/;
const MAX_OUTPUT_CHARS = 8192;

function truncateTail(text) {
  const s = String(text || '');
  if (s.length <= MAX_OUTPUT_CHARS) return s;
  return `...[truncated ${s.length - MAX_OUTPUT_CHARS} chars]...\n${s.slice(-MAX_OUTPUT_CHARS)}`;
}

export function parseTaskBlock(tasksContent, taskId) {
  const normalized = normalizeNewlines(tasksContent);
  const escaped = taskId.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const headerRe = new RegExp(`^##[ \\t]+${escaped}(?:\\b|\\s|$).*$`, 'm');
  const match = headerRe.exec(normalized);
  if (!match) return null;

  const rest = normalized.slice(match.index + match[0].length);
  const nextTask = /^##[ \t]+T-\S+/m.exec(rest);
  const block = nextTask ? rest.slice(0, nextTask.index) : rest;

  const approvalMatch = block.match(/^[ \t]*Approval:[ \t]*(.+)$/m);
  const statusMatch = block.match(/^[ \t]*Status:[ \t]*(.+)$/m);
  const riskMatch = block.match(/^[ \t]*Risk:[ \t]*(.+)$/m);

  return {
    taskId,
    approval: approvalMatch ? approvalMatch[1].trim() : null,
    status: statusMatch ? statusMatch[1].trim() : null,
    risk: riskMatch ? riskMatch[1].trim().toLowerCase() : 'standard',
  };
}

function discoverChangedFiles(projectRoot, explicitFiles) {
  if (Array.isArray(explicitFiles) && explicitFiles.length > 0) {
    return explicitFiles.map((f) => toPosixPath(f.trim())).filter(Boolean);
  }
  try {
    const out = execFileSync('git', ['diff', '--name-only', 'HEAD'], {
      cwd: projectRoot,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    });
    return out
      .split('\n')
      .map((l) => toPosixPath(l.trim()))
      .filter(Boolean);
  } catch {
    return [];
  }
}

function isPlaceholderScanTarget(relPath) {
  const p = toPosixPath(relPath).toLowerCase();
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
  outputPath = null,
}) {
  if (!feature || /[\\/]/.test(feature) || feature === '.' || feature === '..') {
    throw new Error(`Invalid feature name: ${feature}`);
  }
  if (!taskId || !/^T-[A-Za-z0-9._-]+$/.test(taskId)) {
    throw new Error(`Invalid task ID: ${taskId}`);
  }

  const root = findProjectRoot(projectRoot);
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
  const commandResults = runVerificationCommands(root, commands);
  const allCommandsPassed = commandResults.every((r) => r.passed);

  const verdict =
    taskPrecondition.passed && specDrift.passed && placeholders.passed && allCommandsPassed ? 'PASS' : 'FAIL';

  const result = {
    schema: 'sdd-gate-execution/v1',
    feature,
    taskId,
    executedAt: new Date().toISOString(),
    verdict,
    checks: {
      taskPrecondition,
      specDrift,
      placeholders,
      commands: commandResults,
    },
  };

  const resolvedOutput = outputPath
    ? path.resolve(outputPath)
    : path.join(root, 'reports', 'quality-gate', `${feature}-${taskId}.execution.json`);
  fs.mkdirSync(path.dirname(resolvedOutput), { recursive: true });
  fs.writeFileSync(resolvedOutput, `${JSON.stringify(result, null, 2)}\n`, 'utf8');

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
    }
  }
  return opts;
}

function main() {
  const opts = parseArgs(process.argv.slice(2));
  if (!opts.feature || !opts.taskId) {
    process.stderr.write(
      'Usage: node run-sdd-gate.mjs --feature <feature> --task <T-NNN> [--root <dir>] [--cmd "label=command"] [--changed-files "a.js,b.js"] [--output <path>]\n',
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
      outputPath: opts.outputPath,
    });
    process.stdout.write(`${JSON.stringify({ ...result, outputPath }, null, 2)}\n`);
    process.exit(result.verdict === 'PASS' ? 0 : 1);
  } catch (err) {
    process.stderr.write(`run-sdd-gate error: ${err.message}\n`);
    process.exit(2);
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  main();
}
