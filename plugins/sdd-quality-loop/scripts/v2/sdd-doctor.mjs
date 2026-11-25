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
import { createFsReadonlyIo, validateGuardrailsFile, resolveExplicitOrAutoRoot, isMainModule } from './guardrails-lib.mjs';
import { NON_CHECKS, runDoctorCore } from './v2-readonly-core.mjs';

export { NON_CHECKS };

function probeCommandAvailable(bin, args = ['--version']) {
  try {
    execFileSync(bin, args, { shell: false, stdio: 'ignore', timeout: 1500 });
    return true;
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
      const hasJar = fs.statSync(jar, { throwIfNoEntry: false })?.isFile() === true;
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

const isMain = isMainModule(import.meta.url, 'sdd-doctor.mjs');
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
