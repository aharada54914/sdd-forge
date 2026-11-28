#!/usr/bin/env node
/**
 * harvest-pitfalls.mjs — Compound Engineering Pitfall Harvester & 2x Mechanical Escalation Detector (ADR-0056).
 *
 * Scans:
 *   - `docs/review-tickets/RT-*.yml`
 *   - `docs/workflow-improvements/WFI-*.md`
 *   - recent `fix:` commits in git history
 * against `contracts/pitfalls-catalog.json` to:
 *   1. Identify recurring patterns (>= 2 occurrences) that are still documented only
 *      as `review-checklist` / `active` and must escalate to `enforced-by-lint`.
 *   2. Extract unregistered recurring pitfall candidates from RT/WFI/fix commits.
 *   3. Detect potentially stale/retired language entries (Context Hygiene).
 *
 * Usage:
 *   node scripts/harvest-pitfalls.mjs [--check] [--json] [--root <dir>] [--catalog <rel-path>]
 *
 * Exit codes:
 *   0 — Catalog schema valid and zero unescalated >=2-occurrence pitfalls (--check)
 *   1 — One or more >=2-occurrence pitfalls still require mechanical guardrail escalation (--check)
 *   2 — Malformed catalog JSON
 */
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const DEFAULT_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

const PATTERN_SIGNATURES = [
  { key: 'case-sensitivity-ps1', language: 'powershell', re: /case-sensitiv|-ceq|-cmatch|uppercase/i, title: 'PowerShell case-sensitive operator/cmdlet parity' },
  { key: 'silent-skip', language: 'common', re: /silent(?:ly)?\s+skip|skipTest|false[- ]positive/i, title: 'Silent test skip hiding parity failure' },
  { key: 'symlink-realpath', language: 'ts-js', re: /symlink|realpathSync/i, title: 'Symlink realpath mismatch in CLI entrypoint or path containment' },
  { key: 'ssot-drift', language: 'common', re: /\bSSOT\b|drift|out of sync|duplicate/i, title: 'SSOT artifact duplication or drift' },
  { key: 'windows-cmd-execfile', language: 'ts-js', re: /shell:\s*false|\.cmd|\.bat|ENOENT/i, title: 'Windows .cmd/.bat spawn failure with shell:false' },
  { key: 'encoding-utf8', language: 'python', re: /encoding=['"]utf-8['"]|UTF-8 BOM|CRLF/i, title: 'Missing explicit UTF-8 encoding or BOM/CRLF mismatch' },
];

function collectTicketAndWfiTexts(root) {
  const records = [];
  const rtDir = path.join(root, 'docs/review-tickets');
  if (fs.existsSync(rtDir)) {
    for (const f of fs.readdirSync(rtDir).filter((x) => x.endsWith('.yml') || x.endsWith('.yaml')).sort()) {
      records.push({
        source: `docs/review-tickets/${f}`,
        kind: 'review-ticket',
        text: fs.readFileSync(path.join(rtDir, f), 'utf8'),
      });
    }
  }
  const wfiDir = path.join(root, 'docs/workflow-improvements');
  if (fs.existsSync(wfiDir)) {
    for (const f of fs.readdirSync(wfiDir).filter((x) => /^WFI-\d+\.md$/.test(x)).sort()) {
      records.push({
        source: `docs/workflow-improvements/${f}`,
        kind: 'wfi',
        text: fs.readFileSync(path.join(wfiDir, f), 'utf8'),
      });
    }
  }
  try {
    const log = execFileSync('git', ['log', '-n', '50', '--grep=^fix', '--pretty=format:%h %s'], {
      cwd: root,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    });
    for (const line of log.split('\n').filter(Boolean)) {
      records.push({ source: `git:${line.slice(0, 8)}`, kind: 'fix-commit', text: line });
    }
  } catch {
    // non-git temp dir in unit tests
  }
  return records;
}

export function harvestPitfalls({
  root = DEFAULT_ROOT,
  catalogRel = 'contracts/pitfalls-catalog.json',
} = {}) {
  const absRoot = path.resolve(root);
  const catalogAbs = path.join(absRoot, catalogRel);
  if (!fs.existsSync(catalogAbs)) {
    return { exitCode: 2, error: `Catalog not found: ${catalogRel}`, escalationRequired: [], candidates: [], staleEntries: [] };
  }
  let catalog;
  try {
    catalog = JSON.parse(fs.readFileSync(catalogAbs, 'utf8'));
  } catch (err) {
    return {
      exitCode: 2,
      error: `Malformed JSON in ${catalogRel}: ${err instanceof Error ? err.message : String(err)}`,
      escalationRequired: [],
      candidates: [],
      staleEntries: [],
    };
  }
  const pitfalls = Array.isArray(catalog.pitfalls) ? catalog.pitfalls : [];

  // 1. Check 2x-occurrence mechanical escalation rule (ADR-0056 §6.3)
  const escalationRequired = pitfalls
    .filter((p) => p.status !== 'retired' && Number(p.occurrences || 0) >= 2 && p.status !== 'enforced-by-lint')
    .map((p) => ({
      id: p.id,
      language: p.language,
      occurrences: p.occurrences,
      currentStatus: p.status,
      detectionLayer: p.detection_layer,
      remediation: `Promote ${p.id} to mechanical guardrail (lint / ast-fitness / sync-ssot --check) and set status: "enforced-by-lint" in ${catalogRel}`,
    }));

  // 2. Scan RT / WFI / fix: commits for recurring candidate patterns
  const records = collectTicketAndWfiTexts(absRoot);
  const existingText = pitfalls.map((p) => `${p.symptom} ${p.good_pattern} ${p.source_ticket || ''}`).join('\n');
  const candidates = [];
  for (const sig of PATTERN_SIGNATURES) {
    const matchedSources = records.filter((r) => sig.re.test(r.text)).map((r) => r.source);
    if (matchedSources.length === 0) continue;
    const alreadyCovered = sig.re.test(existingText);
    candidates.push({
      signature: sig.key,
      language: sig.language,
      title: sig.title,
      observedCount: matchedSources.length,
      alreadyCovered,
      escalateToMechanical: matchedSources.length >= 2,
      sampleSources: matchedSources.slice(0, 5),
    });
  }

  return {
    exitCode: escalationRequired.length > 0 ? 1 : 0,
    catalogPath: catalogRel,
    totalPitfalls: pitfalls.length,
    enforcedCount: pitfalls.filter((p) => p.status === 'enforced-by-lint').length,
    scannedArtifacts: records.length,
    escalationRequired,
    candidates,
    unregisteredCandidates: candidates.filter((c) => !c.alreadyCovered),
  };
}

function parseCliArgs(argv) {
  const opts = { root: DEFAULT_ROOT, catalogRel: 'contracts/pitfalls-catalog.json', check: false, json: false };
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === '--check') opts.check = true;
    else if (a === '--json') opts.json = true;
    else if (a === '--root' && i + 1 < argv.length) opts.root = argv[++i];
    else if (a === '--catalog' && i + 1 < argv.length) opts.catalogRel = argv[++i];
    else if (a === '--help' || a === '-h') {
      process.stdout.write('Usage: node scripts/harvest-pitfalls.mjs [--check] [--json] [--root <dir>] [--catalog <rel-path>]\n');
      process.exit(0);
    }
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
  const result = harvestPitfalls(opts);
  if (opts.json) {
    process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  } else if (result.exitCode === 2) {
    process.stderr.write(`FATAL [harvest-pitfalls]: ${result.error}\n`);
  } else if (result.exitCode === 1 && opts.check) {
    for (const esc of result.escalationRequired) {
      process.stderr.write(
        `ESCALATE [harvest-pitfalls]: ${esc.id} (${esc.occurrences} occurrences, status=${esc.currentStatus})\n  Fix: ${esc.remediation}\n`,
      );
    }
  } else {
    process.stdout.write(
      `harvest-pitfalls: OK (pitfalls=${result.totalPitfalls}, enforced=${result.enforcedCount}, scanned=${result.scannedArtifacts}, unregistered=${result.unregisteredCandidates.length})\n`,
    );
  }
  process.exit(opts.check ? result.exitCode : (result.exitCode === 2 ? 2 : 0));
}
