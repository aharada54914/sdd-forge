#!/usr/bin/env node
/**
 * check-traceability.mjs — Cross-domain traceability & incremental follow-up analyzer.
 * Zero external dependencies — Node.js >= 20 LTS built-in modules only.
 *
 * Verifies:
 *   1. Every REQ-NNN in requirements.md is linked to at least one AC-NNN.
 *   2. Every AC-NNN in requirements.md is assigned to at least one T-NNN in tasks.md.
 *   3. Maps each T-NNN to its touched domains (Software / SQL / AWS / Azure / DDD) and Scope paths.
 *   4. Supports incremental follow-up impact analysis (--changed-ids REQ-002,AC-003 or --changed-files a.sql,b.ts)
 *      to compute the minimal set of impacted tasks vs reusable unaffected tasks.
 *
 * Usage:
 *   node check-traceability.mjs --feature <feature> [--root <dir>]
 *                               [--changed-ids REQ-001,AC-002] [--changed-files path/a,path/b]
 *                               [--format json|markdown] [--strict]
 */
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { extractSpecIdentifiers, findProjectRoot, normalizeNewlines, toPosixPath } from './guardrails-lib.mjs';
import { detectDomains, parseTasksSummary } from './render-decision-view.mjs';

function extractScopePaths(taskBlock) {
  const scopeMatch = /^###[ \t]+Scope[ \t]*$/im.exec(taskBlock);
  if (!scopeMatch) return [];
  const rest = taskBlock.slice(scopeMatch.index + scopeMatch[0].length);
  const nextSub = /^###[ \t]+\S/m.exec(rest);
  const section = nextSub ? rest.slice(0, nextSub.index) : rest;
  const paths = [];
  for (const line of section.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed.startsWith('-')) continue;
    const backtickMatches = [...trimmed.matchAll(/`([^`]+)`/g)].map((m) => toPosixPath(m[1].trim()));
    if (backtickMatches.length > 0) {
      paths.push(...backtickMatches);
    } else {
      const bare = trimmed.replace(/^-\s*/, '').trim();
      if (bare && !/^<.*>$/.test(bare)) paths.push(toPosixPath(bare));
    }
  }
  return [...new Set(paths)];
}

export function analyzeTraceability({ feature, projectRoot, changedIds = [], changedFiles = [] }) {
  const root = findProjectRoot(projectRoot);
  const featureDir = path.join(root, 'specs', feature);
  const reqPath = path.join(featureDir, 'requirements.md');
  const tasksPath = path.join(featureDir, 'tasks.md');

  if (!fs.existsSync(reqPath) || !fs.existsSync(tasksPath)) {
    throw new Error(`Missing requirements.md or tasks.md under specs/${feature}`);
  }

  const reqText = normalizeNewlines(fs.readFileSync(reqPath, 'utf8'));
  const tasksText = normalizeNewlines(fs.readFileSync(tasksPath, 'utf8'));
  const idMap = extractSpecIdentifiers(reqText);

  const reqIds = Object.keys(idMap).filter((id) => id.startsWith('REQ-')).sort();
  const acIds = Object.keys(idMap).filter((id) => id.startsWith('AC-')).sort();

  // Map AC -> linked REQ IDs (from AC definition line e.g. "- **AC-001** (REQ-001): ...")
  const acToReqs = {};
  const reqToAcs = Object.fromEntries(reqIds.map((r) => [r, []]));
  for (const ac of acIds) {
    const line = idMap[ac]?.line || '';
    const linkedReqs = [...new Set((line.match(/\bREQ-\d+\b/gi) || []).map((r) => r.toUpperCase()))];
    acToReqs[ac] = linkedReqs;
    for (const r of linkedReqs) {
      if (reqToAcs[r]) reqToAcs[r].push(ac);
    }
  }

  const rawTasks = parseTasksSummary(tasksText);
  const acToTasks = Object.fromEntries(acIds.map((a) => [a, []]));
  const tasks = rawTasks.map((t) => {
    const scopePaths = extractScopePaths(t.block);
    const domains = detectDomains(`${t.title}\n${t.block}`);
    for (const ac of t.acRefs) {
      if (acToTasks[ac]) acToTasks[ac].push(t.id);
    }
    return {
      id: t.id,
      title: t.title,
      risk: t.risk,
      approval: t.approval,
      status: t.status,
      acRefs: t.acRefs,
      scopePaths,
      domains,
    };
  });

  const orphanReqs = reqIds.filter((r) => reqToAcs[r].length === 0);
  const unassignedAcs = acIds.filter((a) => acToTasks[a].length === 0);

  // Incremental follow-up impact calculation
  const normalizedChangedIds = new Set(changedIds.map((id) => id.trim().toUpperCase()).filter(Boolean));
  const normalizedChangedFiles = changedFiles.map((f) => toPosixPath(f.trim())).filter(Boolean);

  // Expand changed REQ-* into their child AC-* IDs
  for (const id of [...normalizedChangedIds]) {
    if (id.startsWith('REQ-') && reqToAcs[id]) {
      for (const ac of reqToAcs[id]) normalizedChangedIds.add(ac);
    }
  }

  const impactedTasks = new Set();
  for (const t of tasks) {
    if (normalizedChangedIds.has(t.id.toUpperCase())) {
      impactedTasks.add(t.id);
    }
    if (t.acRefs.some((ac) => normalizedChangedIds.has(ac))) {
      impactedTasks.add(t.id);
    }
    if (
      normalizedChangedFiles.length > 0 &&
      t.scopePaths.some((sp) =>
        normalizedChangedFiles.some((cf) => cf === sp || cf.startsWith(sp.replace(/\/\*.*$/, '')) || sp.includes(cf)),
      )
    ) {
      impactedTasks.add(t.id);
    }
  }

  const reusableTasks = tasks.filter((t) => !impactedTasks.has(t.id)).map((t) => t.id);

  return {
    schema: 'sdd-traceability/v1',
    feature,
    complete: orphanReqs.length === 0 && unassignedAcs.length === 0,
    requirements: reqIds.map((r) => ({ id: r, acs: reqToAcs[r] })),
    acceptanceCriteria: acIds.map((a) => ({ id: a, reqs: acToReqs[a], tasks: acToTasks[a] })),
    tasks,
    gaps: {
      orphanReqs,
      unassignedAcs,
    },
    impact: {
      changedIds: [...normalizedChangedIds],
      changedFiles: normalizedChangedFiles,
      impactedTasks: [...impactedTasks],
      reusableTasks,
    },
  };
}

export function formatTraceabilityMarkdown(report) {
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
  lines.push('');
  lines.push('| AC | REQ | Tasks |');
  lines.push('|---|---|---|');
  for (const ac of report.acceptanceCriteria) {
    lines.push(`| ${ac.id} | ${ac.reqs.join(', ') || '—'} | ${ac.tasks.join(', ') || '⚠️ UNASSIGNED'} |`);
  }
  lines.push('');
  lines.push('| Task | Risk | Domains | Scope |');
  lines.push('|---|---|---|---|');
  for (const t of report.tasks) {
    lines.push(`| ${t.id} | ${t.risk} | ${t.domains.join(', ')} | ${t.scopePaths.join(', ') || '—'} |`);
  }
  if (report.impact.changedIds.length > 0 || report.impact.changedFiles.length > 0) {
    lines.push('');
    lines.push('## Incremental Follow-up Impact');
    lines.push(`- **Impacted Tasks (re-run)**: ${report.impact.impactedTasks.join(', ') || 'None'}`);
    lines.push(`- **Reusable Tasks (skip)**: ${report.impact.reusableTasks.join(', ') || 'None'}`);
  }
  return `${lines.join('\n')}\n`;
}

function parseArgs(argv) {
  const opts = { feature: null, root: null, changedIds: [], changedFiles: [], format: 'json', strict: false };
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === '--feature' && argv[i + 1]) opts.feature = argv[++i];
    else if (a === '--root' && argv[i + 1]) opts.root = argv[++i];
    else if (a === '--changed-ids' && argv[i + 1]) opts.changedIds = argv[++i].split(',').filter(Boolean);
    else if (a === '--changed-files' && argv[i + 1]) opts.changedFiles = argv[++i].split(',').filter(Boolean);
    else if (a === '--format' && argv[i + 1]) opts.format = argv[++i];
    else if (a === '--strict') opts.strict = true;
  }
  return opts;
}

const isMain = process.argv[1] && pathToFileURL(path.resolve(process.argv[1])).href === import.meta.url;
if (isMain) {
  const opts = parseArgs(process.argv.slice(2));
  if (!opts.feature) {
    process.stderr.write('Usage: node check-traceability.mjs --feature <feature> [--root <dir>] [--changed-ids REQ-001] [--changed-files path] [--format json|markdown] [--strict]\n');
    process.exit(2);
  }
  const report = analyzeTraceability({
    feature: opts.feature,
    projectRoot: opts.root || process.cwd(),
    changedIds: opts.changedIds,
    changedFiles: opts.changedFiles,
  });
  process.stdout.write(
    opts.format === 'markdown' ? formatTraceabilityMarkdown(report) : `${JSON.stringify(report, null, 2)}\n`,
  );
  process.exit(opts.strict && !report.complete ? 1 : 0);
}
