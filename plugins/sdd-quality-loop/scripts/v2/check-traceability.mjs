#!/usr/bin/env node
/**
 * check-traceability.mjs — Cross-domain traceability, Code/Test verification,
 * parallel execution batch planner, & incremental follow-up analyzer.
 * Zero external dependencies — Node.js >= 20 LTS built-in modules only.
 *
 * Exit codes:
 *   0 — Complete (or non-strict)
 *   1 — Traceability gaps / blocker cycles found (when --strict)
 *   2 — Usage / runtime / file error
 */
import path from 'node:path';
import { createFsReadonlyIo, resolveExplicitOrAutoRoot, isMainModule } from './guardrails-lib.mjs';
import { analyzeTraceabilityCore, scopeMatchesFile } from './v2-readonly-core.mjs';

export { scopeMatchesFile };

export function analyzeTraceability({ feature, projectRoot, changedIds = [], changedFiles = [] }) {
  const root = resolveExplicitOrAutoRoot(projectRoot);
  const io = createFsReadonlyIo(root);
  return analyzeTraceabilityCore(io, {
    feature,
    changedIds,
    changedFiles,
    checkCodeAndTests: true,
  });
}

function escapeMdCell(text) {
  return String(text || '').replace(/\|/g, '\\|').replace(/\r?\n/g, ' ');
}

export function formatTraceabilityMarkdown(report, { includeBatches = false } = {}) {
  const lines = [];
  lines.push(`# Traceability Matrix: ${report.feature}`);
  lines.push('');
  lines.push(`- **Status**: ${report.complete ? '✅ COMPLETE' : '❌ GAPS_FOUND'}`);
  if (report.gaps.orphanReqs.length > 0) {
    lines.push(`- **Orphan REQs (no AC)**: ${report.gaps.orphanReqs.join(', ')}`);
  }
  if (report.gaps.unassignedAcs.length > 0) {
    lines.push(`- **Unassigned ACs (no Task)**: ${report.gaps.unassignedAcs.join(', ')}`);
  }
  if (report.gaps.unlinkedAcs.length > 0) {
    lines.push(`- **Unlinked ACs (no REQ)**: ${report.gaps.unlinkedAcs.join(', ')}`);
  }
  if (report.gaps.brokenReqRefs.length > 0) {
    lines.push(`- **Broken REQ Refs**: ${report.gaps.brokenReqRefs.map((r) => `${r.ac}->${r.missingReq}`).join(', ')}`);
  }
  if (report.gaps.brokenAcRefs.length > 0) {
    lines.push(`- **Broken AC Refs**: ${report.gaps.brokenAcRefs.map((r) => `${r.task}->${r.missingAc}`).join(', ')}`);
  }
  lines.push('');
  lines.push('| AC | REQ | Tasks | Code / Test Scope |');
  lines.push('|---|---|---|---|');
  const covMap = new Map((report.acCodeTestCoverage || []).map((c) => [c.ac, c]));
  for (const ac of report.acceptanceCriteria) {
    const cov = covMap.get(ac.id);
    const scopeSummary = cov
      ? `code:${cov.codePaths.length} / test:${cov.testPaths.length}`
      : '—';
    lines.push(
      `| ${escapeMdCell(ac.id)} | ${escapeMdCell(ac.reqs.join(', ') || '—')} | ${escapeMdCell(ac.tasks.join(', ') || '⚠️ UNASSIGNED')} | ${escapeMdCell(scopeSummary)} |`,
    );
  }
  lines.push('');
  lines.push('| Task | Risk | Domains | Blockers | Scope |');
  lines.push('|---|---|---|---|---|');
  for (const t of report.tasks) {
    lines.push(
      `| ${escapeMdCell(t.id)} | ${escapeMdCell(t.risk)} | ${escapeMdCell(t.domains.join(', '))} | ${escapeMdCell(t.blockers.join(', ') || 'None')} | ${escapeMdCell(t.scopePaths.join(', ') || '—')} |`,
    );
  }
  if (includeBatches && report.executionPlan) {
    lines.push('');
    lines.push('## Parallel Execution Plan');
    report.executionPlan.batches.forEach((wave, idx) => {
      lines.push(`- **Wave ${idx + 1}**: ${wave.join(', ')}`);
    });
    if (report.executionPlan.scopeConflicts.length > 0) {
      lines.push('- **Scope Conflicts (serialized automatically)**:');
      for (const c of report.executionPlan.scopeConflicts) {
        lines.push(`  - ${c.tasks.join(' vs ')}: ${c.overlaps.join(', ')}`);
      }
    }
    for (const u of report.executionPlan.unknownBlockers || []) {
      lines.push(`- **Unknown Blocker**: ${u.task} depends on ${u.blocker}, which is not a task in this file`);
    }
    if ((report.executionPlan.invalidBlockerTasks || []).length > 0) {
      lines.push(`- **Not Scheduled (invalid Blockers or downstream)**: ${report.executionPlan.invalidBlockerTasks.join(', ')}`);
    }
    if (report.executionPlan.cyclicTasks.length > 0) {
      lines.push(`- **Blocker Cycle Detected**: ${report.executionPlan.cyclicTasks.join(', ')}`);
    }
  }
  if (report.impact.changedIds.length > 0 || report.impact.changedFiles.length > 0) {
    lines.push('');
    lines.push('## Incremental Follow-up Impact');
    lines.push(`- **Impacted Tasks (re-run)**: ${report.impact.impactedTasks.join(', ') || 'None'}`);
    if (report.impact.transitiveImpactedTasks.length > 0) {
      lines.push(
        `  - Direct: ${report.impact.directImpactedTasks.join(', ') || 'None'} | Transitive (via Blockers): ${report.impact.transitiveImpactedTasks.join(', ')}`,
      );
    }
    lines.push(`- **Reusable Tasks (skip)**: ${report.impact.reusableTasks.join(', ') || 'None'}`);
  }
  return `${lines.join('\n')}\n`;
}

function parseArgs(argv) {
  const opts = {
    feature: null,
    root: null,
    changedIds: [],
    changedFiles: [],
    format: 'json',
    strict: false,
    planBatches: false,
  };
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === '--feature' && argv[i + 1]) opts.feature = argv[++i];
    else if (a === '--root' && argv[i + 1]) opts.root = argv[++i];
    else if (a === '--changed-ids' && argv[i + 1]) opts.changedIds.push(...argv[++i].split(',').filter(Boolean));
    else if (a === '--changed-files' && argv[i + 1]) opts.changedFiles.push(...argv[++i].split(',').filter(Boolean));
    else if (a === '--format' && argv[i + 1]) opts.format = argv[++i];
    else if (a === '--strict') opts.strict = true;
    else if (a === '--plan-batches') opts.planBatches = true;
  }
  return opts;
}

const isMain = isMainModule(import.meta.url);
if (isMain) {
  const opts = parseArgs(process.argv.slice(2));
  if (!opts.feature || (opts.format !== 'json' && opts.format !== 'markdown')) {
    process.stderr.write(
      'Usage: node check-traceability.mjs --feature <feature> [--root <dir>] [--changed-ids REQ-001] [--changed-files path] [--format json|markdown] [--plan-batches] [--strict]\n',
    );
    process.exit(2);
  }
  try {
    const report = analyzeTraceability({
      feature: opts.feature,
      projectRoot: opts.root || process.cwd(),
      changedIds: opts.changedIds,
      changedFiles: opts.changedFiles,
    });
    process.stdout.write(
      opts.format === 'markdown'
        ? formatTraceabilityMarkdown(report, { includeBatches: opts.planBatches })
        : `${JSON.stringify(report, null, 2)}\n`,
    );
    const hasCycle = (report.executionPlan?.cyclicTasks?.length || 0) > 0;
    const hasInvalidBlockers = (report.executionPlan?.invalidBlockerTasks?.length || 0) > 0;
    process.exit(opts.strict && (!report.complete || hasCycle || hasInvalidBlockers) ? 1 : 0);
  } catch (err) {
    process.stderr.write(`check-traceability error: ${err.message}\n`);
    process.exit(2);
  }
}
