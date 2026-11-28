#!/usr/bin/env node
/**
 * sdd-doctor.mjs — Read-only diagnostic CLI for SDD Forge v2.1+ Lightweight Guardrails.
 * Thin CLI wrapper over `v2-readonly-core.ts` (Single Source of Truth), extended
 * with Node.js 26.13+ runtime, Compile Cache, and large-repo Git config diagnostics
 * plus `--rebuild-cache` and `--warmup` support (ADR-0055).
 *
 * Usage:
 *   node sdd-doctor.mjs [--root <dir>] [--stale-days <n>] [--json] [--quiet-info]
 *   node sdd-doctor.mjs --rebuild-cache [--root <dir>] [--cache-dir <dir>] [--json]
 *   node sdd-doctor.mjs --warmup
 *
 * Exit codes:
 *   0 — No NG findings (WARN / INFO may be present)
 *   1 — One or more NG findings
 */
import fs from 'node:fs';
import path from 'node:path';
import { createFsReadonlyIo, resolveExplicitOrAutoRoot, isMainModule } from './guardrails-lib.mjs';
import { inspectCompileCache, warmupCompileCache } from './compile-cache.mjs';
import { profilePhase, recordStartup } from './runtime-profile.mjs';
import { NON_CHECKS, runDoctorCore } from './v2-readonly-core.mjs';

export { NON_CHECKS };

export const RECOMMENDED_NODE_VERSION = '26.13.0';

function parseSemver(ver) {
  const m = /^v?(\d+)\.(\d+)\.(\d+)/.exec(String(ver || '').trim());
  if (!m) return null;
  return [Number(m[1]), Number(m[2]), Number(m[3])];
}

function isVersionAtLeast(actual, required) {
  const a = parseSemver(actual);
  const r = parseSemver(required);
  if (!a || !r) return false;
  for (let i = 0; i < 3; i += 1) {
    if (a[i] > r[i]) return true;
    if (a[i] < r[i]) return false;
  }
  return true;
}

/**
 * Reads Git repository config directly from `.git/config` (handling worktree
 * `.git` pointer files) without spawning a child process, so `sdd-doctor.mjs`
 * operates cleanly under Node.js Permission Model read-only mode (`readonly.node.json`).
 */
export function readGitPerformanceConfig(root) {
  const result = {
    gitDetected: false,
    fsmonitor: null,
    untrackedCache: null,
    manyFiles: null,
  };
  try {
    const dotGit = path.join(root, '.git');
    if (!fs.existsSync(dotGit)) return result;
    let gitDir = dotGit;
    const stat = fs.statSync(dotGit);
    if (stat.isFile()) {
      const content = fs.readFileSync(dotGit, 'utf8');
      const m = /^gitdir:\s*(.+)$/m.exec(content);
      if (!m) return result;
      gitDir = path.resolve(root, m[1].trim());
    }
    // Worktrees store repo-wide config in commondir/config when present
    let configPath = path.join(gitDir, 'config');
    const commonDirFile = path.join(gitDir, 'commondir');
    if (fs.existsSync(commonDirFile)) {
      const commonRel = fs.readFileSync(commonDirFile, 'utf8').trim();
      const commonConfig = path.resolve(gitDir, commonRel, 'config');
      if (fs.existsSync(commonConfig)) configPath = commonConfig;
    }
    if (!fs.existsSync(configPath)) return result;
    result.gitDetected = true;
    const text = fs.readFileSync(configPath, 'utf8');
    let section = '';
    for (const rawLine of text.split(/\r?\n/)) {
      const line = rawLine.replace(/[#;].*$/, '').trim();
      if (!line) continue;
      const secMatch = /^\[([A-Za-z0-9_-]+)(?:\s+"[^"]*")?\]$/.exec(line);
      if (secMatch) {
        section = secMatch[1].toLowerCase();
        continue;
      }
      const kv = /^([A-Za-z0-9_-]+)\s*=\s*(.+)$/.exec(line);
      if (!kv) continue;
      const key = kv[1].toLowerCase();
      const val = kv[2].trim().toLowerCase();
      if (section === 'core' && key === 'fsmonitor') result.fsmonitor = val;
      if (section === 'core' && key === 'untrackedcache') result.untrackedCache = val;
      if (section === 'feature' && key === 'manyfiles') result.manyFiles = val;
    }
  } catch {
    // Non-fatal in read-only or restricted environments
  }
  return result;
}

export function collectRuntimeDiagnostics(root, { nodeVersion = process.versions.node, cacheDir = null } = {}) {
  const findings = [];

  if (!isVersionAtLeast(nodeVersion, RECOMMENDED_NODE_VERSION)) {
    findings.push({
      severity: 'INFO',
      category: 'runtime-node-version',
      path: null,
      message: `Node.js v${nodeVersion} detected; Node.js >= ${RECOMMENDED_NODE_VERSION} (Active LTS) is recommended for full ADR-0055 optimizations.`,
      action: `Upgrade local Node.js to >= ${RECOMMENDED_NODE_VERSION} and run: node plugins/sdd-quality-loop/scripts/v2/sdd-doctor.mjs --rebuild-cache`,
    });
  }

  const effectiveCacheDir = cacheDir || process.env.NODE_COMPILE_CACHE || path.join(root, '.sdd-compile-cache');
  const cacheInfo = inspectCompileCache(effectiveCacheDir);
  if (!cacheInfo.exists || cacheInfo.fileCount === 0) {
    findings.push({
      severity: 'INFO',
      category: 'compile-cache',
      path: path.relative(root, effectiveCacheDir) || '.sdd-compile-cache',
      message: 'Pre-generated portable Node.js Compile Cache is not populated yet for this install root.',
      action: 'Run: node plugins/sdd-quality-loop/scripts/v2/sdd-doctor.mjs --rebuild-cache',
    });
  }

  const gitPerf = readGitPerformanceConfig(root);
  if (gitPerf.gitDetected) {
    const missing = [];
    if (gitPerf.fsmonitor !== 'true') missing.push('core.fsmonitor=true');
    if (gitPerf.untrackedCache !== 'true') missing.push('core.untrackedCache=true');
    if (gitPerf.manyFiles !== 'true') missing.push('feature.manyFiles=true');
    if (missing.length > 0) {
      findings.push({
        severity: 'INFO',
        category: 'git-performance-config',
        path: '.git/config',
        message: `Large-repository Git acceleration settings not enabled: ${missing.join(', ')}.`,
        action: `Optionally enable with: git config core.fsmonitor true && git config core.untrackedCache true && git config feature.manyFiles true`,
      });
    }
  }

  return {
    findings,
    runtime: {
      nodeVersion,
      recommendedNodeVersion: RECOMMENDED_NODE_VERSION,
      nodeVersionOk: isVersionAtLeast(nodeVersion, RECOMMENDED_NODE_VERSION),
      compileCache: cacheInfo,
      gitPerformanceConfig: gitPerf,
    },
  };
}

export function runDoctor(options = {}) {
  recordStartup('sdd-doctor');
  return profilePhase('scan', 'sdd-doctor', () => {
    const root = resolveExplicitOrAutoRoot(options.root);
    const staleDays = Number.isFinite(options.staleDays) ? options.staleDays : 14;
    const nodeVersion = options.nodeVersion || process.versions.node;
    const io = createFsReadonlyIo(root);
    const report = runDoctorCore(io, {
      staleDays,
      nodeVersion,
      rootLabel: root,
      scanExtendedRepo: true,
    });
    const extra = collectRuntimeDiagnostics(root, { nodeVersion, cacheDir: options.cacheDir || null });
    report.findings.push(...extra.findings);
    report.summary.info = report.findings.filter((f) => f.severity === 'INFO').length;
    report.runtime = extra.runtime;
    return report;
  });
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
  const opts = {
    root: null,
    staleDays: 14,
    json: false,
    quietInfo: false,
    rebuildCache: false,
    cacheDir: null,
    warmup: false,
  };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--root') opts.root = argv[++i];
    else if (arg === '--stale-days') opts.staleDays = Number(argv[++i]);
    else if (arg === '--json') opts.json = true;
    else if (arg === '--quiet-info') opts.quietInfo = true;
    else if (arg === '--rebuild-cache') opts.rebuildCache = true;
    else if (arg === '--cache-dir') opts.cacheDir = argv[++i];
    else if (arg === '--warmup') opts.warmup = true;
  }
  return opts;
}

const isMain = isMainModule(import.meta.url, 'sdd-doctor.mjs');
if (isMain) {
  const opts = parseCliArgs(process.argv.slice(2));
  if (opts.warmup) {
    process.exit(0);
  }
  if (opts.rebuildCache) {
    const root = resolveExplicitOrAutoRoot(opts.root);
    const summary = warmupCompileCache({ root, cacheDir: opts.cacheDir });
    if (opts.json) {
      process.stdout.write(`${JSON.stringify(summary, null, 2)}\n`);
    } else {
      process.stdout.write(
        `sdd-doctor --rebuild-cache (${summary.nodeVersion}): ${summary.inspection.fileCount} cache files written to ${summary.cacheDir}\n`,
      );
    }
    process.exit(summary.ok ? 0 : 1);
  }
  const report = runDoctor(opts);
  if (opts.json) {
    process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
  } else {
    process.stdout.write(formatDoctorText(report, { quietInfo: opts.quietInfo }));
  }
  process.exit(report.summary.ng > 0 ? 1 : 0);
}
