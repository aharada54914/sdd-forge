#!/usr/bin/env node
/**
 * sdd-doctor.mjs — Read-only diagnostic CLI for SDD Forge v2.1 Lightweight Guardrails.
 * Thin CLI wrapper over `v2-readonly-core.mjs` (Single Source of Truth).
 *
 * Usage:
 *   node sdd-doctor.mjs [--root <dir>] [--stale-days <n>] [--json] [--quiet-info]
 *
 * Exit codes:
 *   0 — No NG findings (WARN / INFO may be present)
 *   1 — One or more NG findings
 */
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { inspectCompileCache, warmCompileCache } from './compile-cache.mjs';
import { createFsReadonlyIo, validateGuardrailsFile, resolveExplicitOrAutoRoot, isMainModule } from './guardrails-lib.mjs';
import { recordStartup } from './runtime-profile.mjs';
import { NON_CHECKS, runDoctorCore } from './v2-readonly-core.mjs';

export { NON_CHECKS };

function compareSemver(version, minMajor, minMinor, minPatch) {
  const m = String(version || '').trim().match(/^v?(\d+)\.(\d+)\.(\d+)/);
  if (!m) return -1;
  const [maj, min, pat] = [Number(m[1]), Number(m[2]), Number(m[3])];
  if (maj !== minMajor) return maj - minMajor;
  if (min !== minMinor) return min - minMinor;
  return pat - minPatch;
}

function readGitConfigSetting(root, key) {
  try {
    return execFileSync('git', ['-C', root, 'config', '--get', key], {
      shell: false,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
      timeout: 1500,
    }).trim();
  } catch {
    return null;
  }
}

export function runtimeEnvironmentFindings(root, { nodeVersion = process.versions.node, installRoot = null } = {}) {
  const findings = [];
  const meetsNode26 = compareSemver(nodeVersion, 26, 13, 0) >= 0;
  findings.push({
    severity: 'INFO',
    category: 'runtime',
    message: meetsNode26
      ? `Node.js ${nodeVersion} meets the unified Node.js 26.13.0+ Active LTS baseline.`
      : `Node.js ${nodeVersion} detected (recommended unified baseline: >= 26.13.0 Active LTS).`,
    path: null,
    action: meetsNode26 ? '追加対応なし' : 'Node.js 26.13.0 以上への更新を推奨します。',
  });

  const pluginRoot = installRoot || path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../..');
  const cacheDir = process.env.NODE_COMPILE_CACHE || path.join(pluginRoot, '.sdd-compile-cache');
  const cacheState = inspectCompileCache(cacheDir);
  findings.push({
    severity: 'INFO',
    category: 'runtime',
    message: cacheState.exists && cacheState.fileCount > 0
      ? `Compile Cache ready (${cacheState.fileCount} file(s), portable=${cacheState.portableEnv}, readonly=${cacheState.readonlyEnv}).`
      : `Compile Cache not populated yet at ${cacheDir}.`,
    path: cacheState.exists ? '.sdd-compile-cache' : null,
    action: cacheState.exists && cacheState.fileCount > 0
      ? 'Node.js 更新時は sdd-doctor.mjs --rebuild-cache で再生成できます。'
      : 'node sdd-doctor.mjs --rebuild-cache で事前生成キャッシュを作成できます。',
  });

  if (fs.existsSync(path.join(root, '.git'))) {
    const recommendedGit = ['core.fsmonitor', 'core.untrackedCache', 'feature.manyFiles'];
    const unset = [];
    for (const key of recommendedGit) {
      const value = readGitConfigSetting(root, key);
      if (value !== 'true' && value !== '1') unset.push(key);
    }
    findings.push({
      severity: 'INFO',
      category: 'git-config',
      message: unset.length === 0
        ? 'Large-repo Git performance settings enabled (core.fsmonitor, core.untrackedCache, feature.manyFiles).'
        : `Optional Git performance settings not enabled: ${unset.join(', ')}.`,
      path: '.git/config',
      action: unset.length === 0
        ? '追加対応なし'
        : '大規模リポジトリでは git config core.fsmonitor true / core.untrackedCache true / feature.manyFiles true を推奨します。',
    });
  }
  return findings;
}

function probeCommandAvailable(bin, args = ['--version']) {
  try {
    execFileSync(bin, args, { shell: false, stdio: 'ignore', timeout: 1500 });
    return true;
  } catch {
    return false;
  }
}

function isReadableJar(file) {
  try {
    fs.accessSync(file, fs.constants.R_OK);
    return fs.statSync(file).isFile();
  } catch {
    return false;
  }
}

function configuredAdapterFindings(root, config, probeCommand = probeCommandAvailable) {
  const findings = [];
  function add(adapter, availability, detail) {
    findings.push({ severity: 'INFO', category: 'adapters', adapter, availability,
      message: `${adapter}: ${availability} (${detail})`, path: null,
      action: availability === 'unavailable' ? '設定した検証ツールの導入先を確認してください' : '追加対応なし' });
  }
  const formal = config.formal_verification;
  if (formal.enabled && formal.mode !== 'off') {
    const adapter = formal.checker.adapter;
    if (adapter === 'lean4' || adapter === 'none') {
      add(adapter, adapter === 'lean4' ? 'reserved' : 'disabled', 'formal_verification.checker.adapter');
    } else {
      const jarName = adapter === 'tlc' ? 'tla2tools.jar' : 'apalache.jar';
      const envJar = adapter === 'tlc' ? process.env.TLA2TOOLS_JAR : process.env.APALACHE_JAR;
      const jar = path.resolve(root, formal.checker.adapter_options[adapter]?.jar || envJar || jarName);
      const hasJar = isReadableJar(jar);
      const hasJava = probeCommand('java', ['-version']);
      add(adapter, hasJava && hasJar ? 'available' : 'unavailable', `java=${hasJava}, ${jarName}=${hasJar}`);
    }
  }
  const security = config.security_audit;
  if (security.enabled && security.mode !== 'off') {
    for (const adapter of new Set(security.enabled_adapters)) {
      if (adapter.startsWith('builtin-')) {
        add(adapter, 'available', 'built-in');
      } else {
        const args = ['gitleaks', 'codeql'].includes(adapter) ? ['version'] : ['--version'];
        add(adapter, probeCommand(adapter, args) ? 'available' : 'unavailable', args.join(' '));
      }
    }
  }
  return findings;
}

// Compatibility for callers that request the original environment inventory.
export function probeExternalAdapters() {
  return {
    java: probeCommandAvailable('java', ['-version']),
    semgrep: probeCommandAvailable('semgrep', ['--version']),
    gitleaks: probeCommandAvailable('gitleaks', ['version']),
  };
}

export function runDoctor(options = {}) {
  const root = resolveExplicitOrAutoRoot(options.root);
  const staleDays = Number.isFinite(options.staleDays) ? options.staleDays : 14;
  const io = createFsReadonlyIo(root);
  const report = runDoctorCore(io, {
    staleDays,
    nodeVersion: process.versions.node,
    rootLabel: root,
    scanExtendedRepo: true,
  });

  if (options.probeAdapters !== false) {
    const settings = validateGuardrailsFile(root);
    if (settings.ok) {
      const findings = configuredAdapterFindings(root, settings.config, options.probeCommand);
      report.findings.push(...findings);
      report.summary.info += findings.length;
    }
  }

  if (options.probeRuntime !== false) {
    const runtimeFindings = runtimeEnvironmentFindings(root, {
      nodeVersion: options.nodeVersion || process.versions.node,
      installRoot: options.installRoot || null,
    });
    report.findings.push(...runtimeFindings);
    report.summary.info += runtimeFindings.length;
  }

  recordStartup('sdd-doctor', { status: report.status });
  return report;
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
    warmup: false,
    rebuildCache: false,
    cacheDir: null,
  };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--root') opts.root = argv[++i];
    else if (arg === '--stale-days') opts.staleDays = Number(argv[++i]);
    else if (arg === '--json') opts.json = true;
    else if (arg === '--quiet-info') opts.quietInfo = true;
    else if (arg === '--warmup') opts.warmup = true;
    else if (arg === '--rebuild-cache') opts.rebuildCache = true;
    else if (arg === '--cache-dir') opts.cacheDir = argv[++i];
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
    const installRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../..');
    const result = warmCompileCache({ installRoot, cacheDir: opts.cacheDir });
    if (opts.json) {
      process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
    } else {
      process.stdout.write(
        `Rebuilt Compile Cache at ${result.cacheDir} (${result.fileCount} files; warmed=${result.warmed.length}, failed=${result.failed.length})\n`,
      );
    }
    process.exit(result.ok ? 0 : 1);
  }
  const report = runDoctor(opts);
  if (opts.json) {
    process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
  } else {
    process.stdout.write(formatDoctorText(report, { quietInfo: opts.quietInfo }));
  }
  process.exit(report.summary.ng > 0 ? 1 : 0);
}
