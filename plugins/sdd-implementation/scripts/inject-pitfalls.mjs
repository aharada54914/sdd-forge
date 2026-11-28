#!/usr/bin/env node
/**
 * inject-pitfalls.mjs — Progressive Disclosure pitfall injector for implement-task (ADR-0056 Phase 5).
 *
 * Filters `sdd/pitfalls-catalog.json` (or `contracts/pitfalls-catalog.json`) to emit ONLY
 * active pitfalls relevant to the target files / languages of the current task.
 *
 * Usage:
 *   node plugins/sdd-implementation/scripts/inject-pitfalls.mjs --root <dir> [--files a.ts,b.py] [--languages ts-js,bash] [--json]
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

function inferLanguagesFromFiles(files) {
  const langs = new Set(['common']);
  for (const f of files) {
    const ext = path.extname(f).toLowerCase();
    if (['.ts', '.tsx', '.js', '.mjs', '.cjs', '.jsx'].includes(ext)) langs.add('ts-js');
    else if (ext === '.py') langs.add('python');
    else if (ext === '.sh' || ext === '.bash') langs.add('bash');
    else if (ext === '.ps1' || ext === '.psm1') langs.add('powershell');
  }
  return [...langs];
}

export function selectPitfalls({ root, files = [], languages = [] } = {}) {
  const absRoot = path.resolve(root);
  const candidates = [
    path.join(absRoot, 'sdd/pitfalls-catalog.json'),
    path.join(absRoot, 'contracts/pitfalls-catalog.json'),
  ];
  const catalogPath = candidates.find((p) => fs.existsSync(p));
  if (!catalogPath) {
    return { catalogPath: null, languages: ['common'], pitfalls: [] };
  }
  const doc = JSON.parse(fs.readFileSync(catalogPath, 'utf8'));
  const targetLangs = new Set([
    'common',
    ...languages,
    ...inferLanguagesFromFiles(files),
  ]);
  const selected = (doc.pitfalls || []).filter(
    (p) => p.status !== 'retired' && targetLangs.has(p.language),
  );
  return {
    catalogPath: path.relative(absRoot, catalogPath),
    languages: [...targetLangs].sort(),
    pitfalls: selected,
  };
}

function parseCliArgs(argv) {
  const opts = { root: process.cwd(), files: [], languages: [], json: false };
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === '--root' && i + 1 < argv.length) opts.root = argv[++i];
    else if (a === '--files' && i + 1 < argv.length) opts.files = argv[++i].split(',').map((s) => s.trim()).filter(Boolean);
    else if (a === '--languages' && i + 1 < argv.length) opts.languages = argv[++i].split(',').map((s) => s.trim()).filter(Boolean);
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
  const res = selectPitfalls(opts);
  if (opts.json) {
    process.stdout.write(`${JSON.stringify(res, null, 2)}\n`);
  } else {
    process.stdout.write(`# Relevant AI Pitfalls (${res.languages.join(', ')})\n\n`);
    for (const p of res.pitfalls) {
      process.stdout.write(`- [${p.id}][${p.severity}] ${p.symptom} -> ${p.good_pattern}\n`);
    }
  }
}
