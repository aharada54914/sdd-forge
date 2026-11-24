#!/usr/bin/env node
/**
 * factory-metrics.mjs — Software Factory telemetry aggregator & root-cause phase tracker (F-4).
 *
 * Reads `.sdd/factory-metrics.jsonl` and `.sdd/drift-events.jsonl` to measure:
 *   - Gate PASS / FAIL rate, average/p95 command duration, provisional OQ blocks, sensor findings
 *   - Human intervention count & auto-fix round count
 *   - Root-cause phase attribution (requirements | design | code | test | harness | unknown)
 *     so teams fix upstream spec/harness defects instead of only patching downstream code.
 *
 * Zero external dependencies — Node.js >= 20 LTS built-in modules only.
 *
 * Usage:
 *   node factory-metrics.mjs [--root <dir>] [--feature <slug>] [--format json|markdown]
 *   node factory-metrics.mjs record-attribution --feature <slug> --task <T-NNN>
 *        --root-cause requirements|design|code|test|harness [--note "..."] [--human-intervention] [--root <dir>]
 */
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { assertValidFeatureName, normalizeNewlines, resolveExplicitOrAutoRoot } from './guardrails-lib.mjs';

export const VALID_ROOT_CAUSES = Object.freeze(['requirements', 'design', 'code', 'test', 'harness', 'unknown']);

function readJsonl(filePath) {
  if (!fs.existsSync(filePath)) return { records: [], parseErrors: 0 };
  const lines = normalizeNewlines(fs.readFileSync(filePath, 'utf8'))
    .split('\n')
    .map((l) => l.trim())
    .filter(Boolean);
  const records = [];
  let parseErrors = 0;
  for (const line of lines) {
    try {
      records.push(JSON.parse(line));
    } catch {
      parseErrors += 1;
    }
  }
  return { records, parseErrors };
}

export function recordRootCauseAttribution({
  projectRoot = null,
  feature,
  taskId,
  rootCause,
  note = '',
  humanIntervention = false,
  autoFixRound = null,
}) {
  assertValidFeatureName(feature);
  if (!taskId || !/^T-[A-Za-z0-9._-]+$/i.test(taskId)) {
    throw new Error(`Invalid task ID: ${taskId}`);
  }
  const normalizedCause = String(rootCause || '').trim().toLowerCase();
  if (!VALID_ROOT_CAUSES.includes(normalizedCause)) {
    throw new Error(`Invalid rootCause '${rootCause}'. Must be one of: ${VALID_ROOT_CAUSES.join(', ')}`);
  }

  const root = resolveExplicitOrAutoRoot(projectRoot);
  const sddDir = path.join(root, '.sdd');
  fs.mkdirSync(sddDir, { recursive: true });
  const record = {
    schema: 'sdd-factory-attribution/v1',
    kind: 'attribution',
    timestamp: new Date().toISOString(),
    feature,
    taskId: taskId.toUpperCase(),
    rootCausePhase: normalizedCause,
    humanIntervention: Boolean(humanIntervention),
    ...(Number.isInteger(autoFixRound) ? { autoFixRound } : {}),
    note: String(note || '').trim(),
  };
  fs.appendFileSync(path.join(sddDir, 'factory-metrics.jsonl'), `${JSON.stringify(record)}\n`, 'utf8');
  return record;
}

export function summarizeFactoryMetrics({ projectRoot = null, feature = null } = {}) {
  const root = resolveExplicitOrAutoRoot(projectRoot);
  const metricsData = readJsonl(path.join(root, '.sdd', 'factory-metrics.jsonl'));
  const driftData = readJsonl(path.join(root, '.sdd', 'drift-events.jsonl'));

  const filterByFeature = (r) => !feature || r.feature === feature;
  const metrics = metricsData.records.filter(filterByFeature);
  const driftEvents = driftData.records.filter(filterByFeature);

  const gateRuns = metrics.filter((r) => r.kind !== 'attribution' && typeof r.verdict === 'string');
  const attributions = metrics.filter((r) => r.kind === 'attribution' || typeof r.rootCausePhase === 'string');

  const passCount = gateRuns.filter((r) => r.verdict === 'PASS').length;
  const failCount = gateRuns.filter((r) => r.verdict === 'FAIL').length;
  const durations = gateRuns
    .map((r) => Number(r.commandDurationMs || 0))
    .filter((n) => Number.isFinite(n) && n >= 0)
    .sort((a, b) => a - b);
  const avgDurationMs =
    durations.length > 0 ? Math.round(durations.reduce((s, n) => s + n, 0) / durations.length) : 0;
  const p95DurationMs =
    durations.length > 0 ? durations[Math.min(durations.length - 1, Math.floor(durations.length * 0.95))] : 0;

  const rootCauseBreakdown = Object.fromEntries(VALID_ROOT_CAUSES.map((c) => [c, 0]));
  for (const r of attributions) {
    const phase = VALID_ROOT_CAUSES.includes(r.rootCausePhase) ? r.rootCausePhase : 'unknown';
    rootCauseBreakdown[phase] += 1;
  }

  // Human interventions are explicit human acts: attributions flagged
  // humanIntervention and SDD_ALLOW_SPEC_EDIT overrides. A guard deny is an
  // automatic refusal that waits for no one, so it is counted separately (#840).
  const humanInterventions =
    metrics.filter((r) => r.humanIntervention === true).length +
    driftEvents.filter((e) => e.action === 'allow_override').length;
  const guardAutoDenials = driftEvents.filter(
    (e) => e.action === 'confirm_soft_deny' || e.action === 'strict_deny',
  ).length;

  const sensorFindingsTotal = gateRuns.reduce((acc, r) => acc + Number(r.sensorFindingCount || 0), 0);
  // Only runs the Open Questions check itself stopped count as OQ blocks (#843).
  // Records predating `provisionalOqBlocking` derive it from the gate rule
  // (high risk with unresolved OQs) instead of "any FAIL with an OQ present".
  const provisionalOqBlocks = gateRuns.filter((r) => {
    if (r.verdict !== 'FAIL') return false;
    if (typeof r.provisionalOqBlocking === 'boolean') return r.provisionalOqBlocking;
    const risk = String(r.risk || '').toLowerCase();
    return (risk === 'high' || risk === 'critical') && Number(r.provisionalOqCount || 0) > 0;
  }).length;

  return {
    schema: 'sdd-factory-metrics-summary/v1',
    generatedAt: new Date().toISOString(),
    feature: feature || null,
    gateRuns: {
      total: gateRuns.length,
      pass: passCount,
      fail: failCount,
      passRate: gateRuns.length > 0 ? Number(((passCount / gateRuns.length) * 100).toFixed(1)) : 0,
      avgDurationMs,
      p95DurationMs,
      sensorFindingsTotal,
      provisionalOqBlocks,
    },
    driftEvents: {
      total: driftEvents.length,
      deny: driftEvents.filter((e) => e.action === 'strict_deny' || e.action === 'confirm_soft_deny').length,
      amendedAllow: driftEvents.filter((e) => e.action === 'confirm_amended_allow').length,
      warnAllow: driftEvents.filter((e) => e.action === 'warn_allow').length,
      override: driftEvents.filter((e) => e.action === 'allow_override').length,
    },
    humanInterventions,
    guardAutoDenials,
    rootCauseBreakdown,
    parseErrors: metricsData.parseErrors + driftData.parseErrors,
  };
}

export function formatFactoryMetricsMarkdown(summary) {
  const lines = [
    `# Software Factory Metrics${summary.feature ? `: ${summary.feature}` : ''}`,
    '',
    '| Metric | Value |',
    '|---|---|',
    `| Gate Runs (PASS / FAIL) | ${summary.gateRuns.total} (${summary.gateRuns.pass} / ${summary.gateRuns.fail}, ${summary.gateRuns.passRate}%) |`,
    `| Command Duration (avg / p95) | ${summary.gateRuns.avgDurationMs} ms / ${summary.gateRuns.p95DurationMs} ms |`,
    `| Sensor Findings Total | ${summary.gateRuns.sensorFindingsTotal} |`,
    `| Provisional OQ Blocks | ${summary.gateRuns.provisionalOqBlocks} |`,
    `| Guard Events (deny / amended / warn) | ${summary.driftEvents.total} (${summary.driftEvents.deny} / ${summary.driftEvents.amendedAllow} / ${summary.driftEvents.warnAllow}) |`,
    `| Recorded Human Interventions (explicit attributions + spec-edit overrides) | ${summary.humanInterventions} |`,
    `| Guard Auto-Denials (no human involved) | ${summary.guardAutoDenials} |`,
    '',
    '## Root-Cause Phase Attribution（誤りの原因工程）',
    '',
    '| Phase | Count |',
    '|---|---|',
  ];
  for (const [phase, count] of Object.entries(summary.rootCauseBreakdown)) {
    lines.push(`| ${phase} | ${count} |`);
  }
  return `${lines.join('\n')}\n`;
}

function parseArgs(argv) {
  const isRecord = argv[0] === 'record-attribution';
  const start = isRecord ? 1 : 0;
  const opts = {
    cmd: isRecord ? 'record-attribution' : 'summary',
    root: null,
    feature: null,
    taskId: null,
    rootCause: null,
    note: '',
    humanIntervention: false,
    autoFixRound: null,
    format: 'json',
  };
  for (let i = start; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === '--root' && argv[i + 1]) opts.root = argv[++i];
    else if (a === '--feature' && argv[i + 1]) opts.feature = argv[++i];
    else if (a === '--task' && argv[i + 1]) opts.taskId = argv[++i];
    else if (a === '--root-cause' && argv[i + 1]) opts.rootCause = argv[++i];
    else if (a === '--note' && argv[i + 1]) opts.note = argv[++i];
    else if (a === '--human-intervention') opts.humanIntervention = true;
    else if (a === '--auto-fix-round' && argv[i + 1]) opts.autoFixRound = Number(argv[++i]);
    else if (a === '--format' && argv[i + 1]) opts.format = argv[++i];
  }
  return opts;
}

const isMain =
  process.argv[1] &&
  path.basename(process.argv[1]) === 'factory-metrics.mjs' &&
  pathToFileURL(path.resolve(process.argv[1])).href === import.meta.url;

if (isMain) {
  const opts = parseArgs(process.argv.slice(2));
  try {
    if (opts.cmd === 'record-attribution') {
      if (!opts.feature || !opts.taskId || !opts.rootCause) {
        process.stderr.write(
          'Usage: node factory-metrics.mjs record-attribution --feature <slug> --task <T-NNN> --root-cause <requirements|design|code|test|harness|unknown> [--note "..."] [--human-intervention] [--root <dir>]\n',
        );
        process.exit(2);
      }
      const rec = recordRootCauseAttribution({
        projectRoot: opts.root,
        feature: opts.feature,
        taskId: opts.taskId,
        rootCause: opts.rootCause,
        note: opts.note,
        humanIntervention: opts.humanIntervention,
        autoFixRound: opts.autoFixRound,
      });
      process.stdout.write(`${JSON.stringify(rec, null, 2)}\n`);
      process.exit(0);
    }
    const summary = summarizeFactoryMetrics({ projectRoot: opts.root, feature: opts.feature });
    process.stdout.write(
      opts.format === 'markdown' ? formatFactoryMetricsMarkdown(summary) : `${JSON.stringify(summary, null, 2)}\n`,
    );
    process.exit(0);
  } catch (err) {
    process.stderr.write(`factory-metrics error: ${err.message}\n`);
    process.exit(2);
  }
}
