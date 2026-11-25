import { execFileSync, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { readProtectedDiff } from './check-spec-drift.mjs';

const SAMPLE_COUNT = 20;
const DEFAULT_RATIO = 1.10;
const PROTECTED_INPUTS = ['contracts/**', 'tests/golden/**', 'nfr-budget.json', '**/nfr-budget.json'];

function git(root, args) {
  return execFileSync('git', ['-c', `core.hooksPath=${os.devNull}`, ...args], {
    cwd: root, stdio: ['ignore', 'pipe', 'pipe'], encoding: 'utf8',
  }).trimEnd();
}

function immutableChanges(projectRoot, baseRef, budgetFile) {
  const { revision, changedEntries } = readProtectedDiff(projectRoot, baseRef, [...PROTECTED_INPUTS, budgetFile]);
  const paths = changedEntries.map(entry => entry.relPath).filter(rel =>
    rel.startsWith('contracts/') || rel.startsWith('tests/golden/') ||
    path.posix.basename(rel) === 'nfr-budget.json' || rel === budgetFile);
  return { revision, paths: [...new Set(paths)].sort() };
}

function readBudget(checkout, rel, explicit) {
  const file = path.resolve(checkout, rel);
  if (!explicit && !fs.existsSync(file)) return {};
  if (fs.realpathSync(file) !== file || !fs.statSync(file).isFile()) throw new Error('Invalid rebuilt NFR budget file');
  const budget = JSON.parse(fs.readFileSync(file, 'utf8'));
  if (!budget || typeof budget !== 'object' || Array.isArray(budget)) throw new Error('Invalid NFR budget');
  for (const key of ['max_duration_ms', 'max_regression_ratio']) {
    if (key in budget && !(Number.isFinite(budget[key]) && budget[key] > 0)) throw new Error(`Invalid NFR budget: ${key}`);
  }
  return budget;
}

function measure(cmd, cwd, deadline) {
  const start = performance.now();
  if (start >= deadline) throw new Error('Rebuild sampling exceeded its five-minute budget');
  const res = spawnSync(cmd, { cwd, shell: true, timeout: Math.ceil(Math.min(120000, deadline - start)) });
  return { durationMs: performance.now() - start, stdout: res.stdout, stderr: res.stderr,
    exitCode: res.status ?? 1, ok: !res.error && res.status === 0 };
}

function summarize(durations, exitCode) {
  const sorted = [...durations].sort((a, b) => a - b);
  const p95Ms = sorted[Math.ceil(sorted.length * 0.95) - 1];
  return { exitCode, durationMs: p95Ms, p95Ms, samples: sorted.length };
}

function compareCommands(baselineCmd, candidateCmd, baselineRoot, projectRoot, budget) {
  const deadline = performance.now() + 300000;
  const baselineTimes = [];
  const candidateTimes = [];
  let oldRun, newRun, differentialMatched;
  for (let index = 0; index < SAMPLE_COUNT; index++) {
    // Alternate order so a systematically warmer second run does not favor one side.
    if (index % 2 === 0) oldRun = measure(baselineCmd, baselineRoot, deadline);
    newRun = measure(candidateCmd, projectRoot, deadline);
    if (index % 2 !== 0) oldRun = measure(baselineCmd, baselineRoot, deadline);
    baselineTimes.push(oldRun.durationMs);
    candidateTimes.push(newRun.durationMs);
    differentialMatched = oldRun.ok && newRun.ok && oldRun.stdout.equals(newRun.stdout) && oldRun.stderr.equals(newRun.stderr);
    if (!differentialMatched) break;
  }
  const baseline = summarize(baselineTimes, oldRun.exitCode);
  const candidate = summarize(candidateTimes, newRun.exitCode);
  const nfrViolations = [];
  const ratio = budget.max_regression_ratio ?? DEFAULT_RATIO;
  if (candidate.samples === SAMPLE_COUNT) {
    if (candidate.p95Ms > baseline.p95Ms * ratio) nfrViolations.push(`Candidate p95 exceeds ${ratio}x baseline`);
    if (candidate.p95Ms > (budget.max_duration_ms ?? Infinity)) nfrViolations.push('Candidate p95 exceeds max_duration_ms');
  }
  const nfrPassed = candidate.samples === SAMPLE_COUNT && nfrViolations.length === 0;
  return { baseline, candidate, differentialMatched, nfrPassed, nfrViolations, passed: differentialMatched && nfrPassed };
}

/** Run the old command at the actual Git revision and the new command in the candidate tree. */
export function runRebuildDifferentialCheck({ projectRoot, baseRef = 'HEAD', baselineCmd, candidateCmd, nfrBudgetPath = null }) {
  const failure = { passed: false, differentialMatched: false, nfrPassed: false, immutablePaths: [] };
  if (!baselineCmd || !candidateCmd) return { ...failure, error: 'rebuild mode requires both --baseline-cmd and --candidate-cmd' };
  try {
    const budgetPath = path.resolve(projectRoot, nfrBudgetPath || 'nfr-budget.json');
    const canonicalParent = fs.realpathSync(path.dirname(budgetPath));
    const rel = path.relative(fs.realpathSync(projectRoot), path.join(canonicalParent, path.basename(budgetPath))).split(path.sep).join('/');
    if (!rel || rel === '..' || rel.startsWith('../') || path.isAbsolute(rel)) throw new Error('NFR budget must be inside the project');
    const before = immutableChanges(projectRoot, baseRef || 'HEAD', rel);
    if (before.paths.length) return { ...failure, immutablePaths: before.paths };
    const prefix = git(projectRoot, ['rev-parse', '--show-prefix']);
    const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-rebuild-'));
    const checkout = path.join(fs.realpathSync(temp), 'baseline');
    try {
      git(projectRoot, ['worktree', 'add', '--quiet', '--detach', checkout, before.revision]);
      try {
        const baselineRoot = path.join(checkout, prefix);
        const budget = readBudget(baselineRoot, rel, nfrBudgetPath !== null);
        const report = compareCommands(baselineCmd, candidateCmd, baselineRoot, projectRoot, budget);
        const after = immutableChanges(projectRoot, before.revision, rel);
        return { ...report, immutablePaths: after.paths, passed: report.passed && after.paths.length === 0 };
      } finally {
        git(projectRoot, ['worktree', 'remove', '--force', checkout]);
      }
    } finally {
      fs.rmSync(temp, { recursive: true, force: true });
    }
  } catch (err) {
    return { ...failure, error: err.message };
  }
}
