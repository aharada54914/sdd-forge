#!/usr/bin/env node
/**
 * compound-pitfalls.mjs — Compound Engineering step for user projects (ADR-0056 Phase 5).
 *
 * Records a verified review finding or bugfix lesson into `sdd/pitfalls-catalog.json`.
 * When the same pitfall pattern recurs (>= 2 occurrences), marks `escalateToMechanical: true`
 * so the team promotes it from review-checklist to a mechanical lint/fitness guardrail.
 *
 * Usage:
 *   node plugins/sdd-review-loop/scripts/compound-pitfalls.mjs --root <dir> --id <PIT-ID> --language <lang> --symptom "..." --good-pattern "..." [--source "..."] [--apply] [--json]
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export function recordCompoundPitfall({
  root,
  id,
  language = 'common',
  severity = 'medium',
  symptom,
  badPattern = '',
  goodPattern,
  source = 'review',
  apply = false,
} = {}) {
  const absRoot = path.resolve(root);
  const catalogAbs = path.join(absRoot, 'sdd/pitfalls-catalog.json');
  const doc = fs.existsSync(catalogAbs)
    ? JSON.parse(fs.readFileSync(catalogAbs, 'utf8'))
    : { schema: 'sdd-pitfalls-catalog/v1', languages: ['common'], pitfalls: [] };

  const pitfalls = Array.isArray(doc.pitfalls) ? doc.pitfalls : [];
  const existing = pitfalls.find((p) => p.id === id);
  let action;
  let entry;
  if (existing) {
    existing.occurrences = Number(existing.occurrences || 1) + 1;
    existing.last_verified_at = new Date().toISOString().slice(0, 10);
    if (source) existing.source_ticket = source;
    entry = existing;
    action = 'incremented';
  } else {
    entry = {
      id,
      language,
      severity,
      symptom,
      bad_pattern: badPattern,
      good_pattern: goodPattern,
      detection_layer: 'review-checklist',
      remediation_cmd: 'node check-architecture-fitness.mjs --root .',
      source_ticket: source,
      occurrences: 1,
      last_verified_at: new Date().toISOString().slice(0, 10),
      status: 'active',
    };
    pitfalls.push(entry);
    action = 'added';
  }

  const escalateToMechanical = Number(entry.occurrences || 1) >= 2 && entry.status !== 'enforced-by-lint';
  doc.pitfalls = pitfalls;
  if (apply) {
    fs.mkdirSync(path.dirname(catalogAbs), { recursive: true });
    fs.writeFileSync(catalogAbs, `${JSON.stringify(doc, null, 2)}\n`, 'utf8');
  }
  return { action, applied: apply, entry, escalateToMechanical };
}

function parseCliArgs(argv) {
  const opts = { root: process.cwd(), apply: false, json: false };
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === '--root' && i + 1 < argv.length) opts.root = argv[++i];
    else if (a === '--id' && i + 1 < argv.length) opts.id = argv[++i];
    else if (a === '--language' && i + 1 < argv.length) opts.language = argv[++i];
    else if (a === '--severity' && i + 1 < argv.length) opts.severity = argv[++i];
    else if (a === '--symptom' && i + 1 < argv.length) opts.symptom = argv[++i];
    else if (a === '--bad-pattern' && i + 1 < argv.length) opts.badPattern = argv[++i];
    else if (a === '--good-pattern' && i + 1 < argv.length) opts.goodPattern = argv[++i];
    else if (a === '--source' && i + 1 < argv.length) opts.source = argv[++i];
    else if (a === '--apply') opts.apply = true;
    else if (a === '--json') opts.json = true;
  }
  return opts;
}

const isDirectMain =
  Boolean(process.argv[1]) &&
  (() => {
    try {
      return fs.realpathSync(path.resolve(process.argv[1])) === fs.realpathSync(fileURLToPath(import.meta.url));
    } catch {
      return path.resolve(process.argv[1]) === path.resolve(fileURLToPath(import.meta.url));
    }
  })();

if (isDirectMain) {
  const opts = parseCliArgs(process.argv.slice(2));
  if (!opts.id || !opts.symptom || !opts.goodPattern) {
    process.stderr.write('Usage: node compound-pitfalls.mjs --root <dir> --id <ID> --symptom <text> --good-pattern <text> [--apply] [--json]\n');
    process.exit(2);
  }
  const res = recordCompoundPitfall(opts);
  if (opts.json) process.stdout.write(`${JSON.stringify(res, null, 2)}\n`);
  else process.stdout.write(`compound-pitfalls: ${res.action} ${res.entry.id} (occurrences=${res.entry.occurrences}, escalate=${res.escalateToMechanical})\n`);
}
