#!/usr/bin/env node
/**
 * check-traceability.mjs — Cross-domain traceability & incremental follow-up analyzer.
 * Zero external dependencies — Node.js >= 20 LTS built-in modules only.
 *
 * Verifies:
 *   1. Every REQ-NNN in requirements.md is linked to at least one AC-NNN.
 *   2. Every AC-NNN links to a valid REQ-NNN and is assigned to at least one T-NNN.
 *   3. No task references undefined AC-NNN IDs.
 *   4. Maps each T-NNN to its touched domains, Scope paths, and ### Blockers.
 *   5. Incremental follow-up impact analysis (--changed-ids / --changed-files) with
 *      cycle-safe transitive ### Blockers propagation.
 *
 * Exit codes:
 *   0 — Complete (or non-strict)
 *   1 — Traceability gaps found (when --strict)
 *   2 — Usage / runtime / file error
 */
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import {
  assertValidFeatureName,
  extractSpecIdentifiers,
  findProjectRoot,
  globToRegExp,
  normalizeNewlines,
  normalizeRelPath,
} from './guardrails-lib.mjs';
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
    const backtickMatches = [...trimmed.matchAll(/`([^`]+)`/g)]
      .map((m) => normalizeRelPath(m[1]))
      .filter(Boolean);
    if (backtickMatches.length > 0) {
      paths.push(...backtickMatches);
    } else {
      const bare = normalizeRelPath(trimmed.replace(/^-\s*/, ''));
      if (bare && !/^<[^<>]+>$/.test(bare)) paths.push(bare);
    }
  }
  return [...new Set(paths)];
}

export function scopeMatchesFile(scopeEntry, changedFile) {
  const sp = normalizeRelPath(scopeEntry);
  const cf = normalizeRelPath(changedFile);
  if (!sp || !cf) return false;
  if (/[*?]/.test(sp)) {
    return globToRegExp(sp).test(cf);
  }
  return cf === sp || cf.startsWith(`${sp}/`);
}

export function analyzeTraceability({ feature, projectRoot, changedIds = [], changedFiles = [] }) {
  assertValidFeatureName(feature);
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
  const reqSet = new Set(reqIds);
  const acSet = new Set(acIds);

  const acToReqs = {};
  const reqToAcs = Object.fromEntries(reqIds.map((r) => [r, []]));
  const unlinkedAcs = [];
  const brokenReqRefs = [];

  for (const ac of acIds) {
    const line = idMap[ac]?.line || '';
    const linkedReqs = [...new Set((line.match(/\bREQ-\d+\b/gi) || []).map((r) => r.toUpperCase()))];
    acToReqs[ac] = linkedReqs;
    if (linkedReqs.length === 0) {
      unlinkedAcs.push(ac);
    }
    for (const r of linkedReqs) {
      if (reqSet.has(r)) {
        reqToAcs[r].push(ac);
      } else {
        brokenReqRefs.push({ ac, missingReq: r });
      }
    }
  }

  const rawTasks = parseTasksSummary(tasksText);
  const acToTasks = Object.fromEntries(acIds.map((a) => [a, []]));
  const brokenAcRefs = [];

  const tasks = rawTasks.map((t) => {
    const scopePaths = extractScopePaths(t.block);
    const domains = detectDomains(`${t.title}\n${t.block}`);
    for (const ac of t.acRefs) {
      if (acSet.has(ac)) {
        acToTasks[ac].push(t.id);
      } else {
        brokenAcRefs.push({ task: t.id, missingAc: ac });
      }
    }
    return {
      id: t.id,
      title: t.title,
      risk: t.risk,
      approval: t.approval,
      status: t.status,
      acRefs: t.acRefs,
      blockers: t.blockers,
      scopePaths,
      domains,
    };
  });

  const orphanReqs = reqIds.filter((r) => reqToAcs[r].length === 0);
  const unassignedAcs = acIds.filter((a) => acToTasks[a].length === 0);

  // Build reverse dependency graph (blocker -> downstream dependents)
  const dependentsByBlocker = new Map();
  for (const t of tasks) {
    for (const blocker of t.blockers) {
      if (!dependentsByBlocker.has(blocker)) dependentsByBlocker.set(blocker, []);
      dependentsByBlocker.get(blocker).push(t.id);
    }
  }

  // Incremental follow-up impact calculation
  const normalizedChangedIds = new Set(changedIds.map((id) => String(id).trim().toUpperCase()).filter(Boolean));
  const normalizedChangedFiles = changedFiles.map((f) => normalizeRelPath(f)).filter(Boolean);

  for (const id of [...normalizedChangedIds]) {
    if (id.startsWith('REQ-') && reqToAcs[id]) {
      for (const ac of reqToAcs[id]) normalizedChangedIds.add(ac);
    }
  }

  const directImpacted = new Set();
  for (const t of tasks) {
    if (normalizedChangedIds.has(t.id)) {
      directImpacted.add(t.id);
    }
    if (t.acRefs.some((ac) => normalizedChangedIds.has(ac))) {
      directImpacted.add(t.id);
    }
    if (
      normalizedChangedFiles.length > 0 &&
      t.scopePaths.some((sp) => normalizedChangedFiles.some((cf) => scopeMatchesFile(sp, cf)))
    ) {
      directImpacted.add(t.id);
    }
  }

  // Cycle-safe BFS transitive closure along ### Blockers edges
  const impactedSet = new Set(directImpacted);
  const transitiveImpacted = new Set();
  const queue = [...directImpacted];
  while (queue.length > 0) {
    const current = queue.shift();
    for (const dep of dependentsByBlocker.get(current) || []) {
      if (!impactedSet.has(dep)) {
        impactedSet.add(dep);
        transitiveImpacted.add(dep);
        queue.push(dep);
      }
    }
  }

  const taskOrder = tasks.map((t) => t.id);
  const impactedTasks = taskOrder.filter((id) => impactedSet.has(id));
  const reusableTasks = taskOrder.filter((id) => !impactedSet.has(id));

  const complete =
    reqIds.length > 0 &&
    acIds.length > 0 &&
    orphanReqs.length === 0 &&
    unassignedAcs.length === 0 &&
    unlinkedAcs.length === 0 &&
    brokenReqRefs.length === 0 &&
    brokenAcRefs.length === 0;

  return {
    schema: 'sdd-traceability/v1',
    feature,
    complete,
    requirements: reqIds.map((r) => ({ id: r, acs: reqToAcs[r] })),
    acceptanceCriteria: acIds.map((a) => ({ id: a, reqs: acToReqs[a], tasks: acToTasks[a] })),
    tasks,
    gaps: {
      orphanReqs,
      unassignedAcs,
      unlinkedAcs,
      brokenReqRefs,
      brokenAcRefs,
    },
    impact: {
      changedIds: [...normalizedChangedIds],
      changedFiles: normalizedChangedFiles,
      directImpactedTasks: taskOrder.filter((id) => directImpacted.has(id)),
      transitiveImpactedTasks: taskOrder.filter((id) => transitiveImpacted.has(id)),
      impactedTasks,
      reusableTasks,
    },
  };
}

function escapeMdCell(text) {
  return String(text || '').replace(/\|/g, '\\|').replace(/\r?\n/g, ' ');
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
  lines.push('| AC | REQ | Tasks |');
  lines.push('|---|---|---|');
  for (const ac of report.acceptanceCriteria) {
    lines.push(`| ${escapeMdCell(ac.id)} | ${escapeMdCell(ac.reqs.join(', ') || '—')} | ${escapeMdCell(ac.tasks.join(', ') || '⚠️ UNASSIGNED')} |`);
  }
  lines.push('');
  lines.push('| Task | Risk | Domains | Blockers | Scope |');
  lines.push('|---|---|---|---|---|');
  for (const t of report.tasks) {
    lines.push(
      `| ${escapeMdCell(t.id)} | ${escapeMdCell(t.risk)} | ${escapeMdCell(t.domains.join(', '))} | ${escapeMdCell(t.blockers.join(', ') || 'None')} | ${escapeMdCell(t.scopePaths.join(', ') || '—')} |`,
    );
  }
  if (report.impact.changedIds.length > 0 || report.impact.changedFiles.length > 0) {
    lines.push('');
    lines.push('## Incremental Follow-up Impact');
    lines.push(`- **Impacted Tasks (re-run)**: ${report.impact.impactedTasks.join(', ') || 'None'}`);
    if (report.impact.transitiveImpactedTasks.length > 0) {
      lines.push(`  - Direct: ${report.impact.directImpactedTasks.join(', ') || 'None'} | Transitive (via Blockers): ${report.impact.transitiveImpactedTasks.join(', ')}`);
    }
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
    else if (a === '--changed-ids' && argv[i + 1]) opts.changedIds.push(...argv[++i].split(',').filter(Boolean));
    else if (a === '--changed-files' && argv[i + 1]) opts.changedFiles.push(...argv[++i].split(',').filter(Boolean));
    else if (a === '--format' && argv[i + 1]) opts.format = argv[++i];
    else if (a === '--strict') opts.strict = true;
  }
  return opts;
}

const isMain =
  process.argv[1] &&
  path.basename(process.argv[1]) === 'check-traceability.mjs' &&
  pathToFileURL(path.resolve(process.argv[1])).href === import.meta.url;
if (isMain) {
  const opts = parseArgs(process.argv.slice(2));
  if (!opts.feature || (opts.format !== 'json' && opts.format !== 'markdown')) {
    process.stderr.write(
      'Usage: node check-traceability.mjs --feature <feature> [--root <dir>] [--changed-ids REQ-001] [--changed-files path] [--format json|markdown] [--strict]\n',
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
      opts.format === 'markdown' ? formatTraceabilityMarkdown(report) : `${JSON.stringify(report, null, 2)}\n`,
    );
    process.exit(opts.strict && !report.complete ? 1 : 0);
  } catch (err) {
    process.stderr.write(`check-traceability error: ${err.message}\n`);
    process.exit(2);
  }
}
