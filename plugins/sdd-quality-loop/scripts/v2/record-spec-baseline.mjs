#!/usr/bin/env node
/**
 * Record a lightweight, external-key-free specification baseline snapshot
 * into specs/<feature>/.spec-baseline.json.
 *
 * Usage:
 *   node record-spec-baseline.mjs --feature <feature> [--root <dir>] [--output <path>] [--rerecord]
 *
 * Idempotent: when the baseline already exists it is left untouched and the
 * status is EXISTING, so re-entering ship never erases undeclared drift
 * (#819). Pass --rerecord only for an agreed, deliberate re-baseline.
 */
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import {
  canonicalSpecContractText,
  extractAmendmentEntries,
  extractSpecIdentifiers,
  loadGuardrailsConfig,
  matchProtectedSpecPath,
  resolveExplicitOrAutoRoot,
  sha256Text,
  isMainModule,
} from './guardrails-lib.mjs';
import { taskApprovalBaseline } from './v2-readonly-core.mjs';

function getGitHead(projectRoot) {
  try {
    return execFileSync('git', ['rev-parse', 'HEAD'], {
      cwd: projectRoot,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
  } catch {
    return null;
  }
}

export function buildSpecBaseline({ feature, projectRoot }) {
  if (!feature || /[\\/]/.test(feature) || feature === '.' || feature === '..') {
    throw new Error(`Invalid feature name: ${feature}`);
  }
  const root = resolveExplicitOrAutoRoot(projectRoot);
  const featureDir = path.join(root, 'specs', feature);
  if (!fs.existsSync(featureDir) || !fs.statSync(featureDir).isDirectory()) {
    throw new Error(`Feature directory not found: specs/${feature}`);
  }

  const config = loadGuardrailsConfig(root);
  const entries = fs.readdirSync(featureDir, { withFileTypes: true });
  const files = {};
  const allIdentifiers = {};
  let amendmentCount = 0;

  for (const entry of entries.sort((a, b) => a.name.localeCompare(b.name))) {
    if (!entry.isFile() || entry.name.startsWith('.')) continue;
    const fullPath = path.join(featureDir, entry.name);
    const matched = matchProtectedSpecPath(fullPath, root, config, root);
    if (!matched) continue;

    const rawText = fs.readFileSync(fullPath, 'utf8');
    const contractText = canonicalSpecContractText(rawText, entry.name);
    const identifiers = extractSpecIdentifiers(rawText);
    const amendments = extractAmendmentEntries(rawText);
    amendmentCount += amendments.length;

    files[matched.relPath] = {
      fileName: entry.name,
      rawSha256: sha256Text(rawText),
      contractSha256: sha256Text(contractText),
      identifiers,
      amendmentCount: amendments.length,
      ...(taskApprovalBaseline(rawText, entry.name) || {}),
    };

    for (const [id, info] of Object.entries(identifiers)) {
      allIdentifiers[id] = {
        file: matched.relPath,
        ...info,
      };
    }
  }

  if (Object.keys(files).length === 0) {
    throw new Error(`No protected specification files found under specs/${feature}`);
  }

  return {
    schema: 'sdd-spec-baseline/v1',
    feature,
    recordedAt: new Date().toISOString(),
    gitHead: getGitHead(root),
    amendmentCount,
    files,
    identifiers: allIdentifiers,
  };
}

export function writeSpecBaseline({ feature, projectRoot, outputPath, rerecord = false }) {
  const root = resolveExplicitOrAutoRoot(projectRoot);
  const target = outputPath
    ? path.resolve(outputPath)
    : path.join(root, 'specs', feature, '.spec-baseline.json');
  if (!rerecord && fs.existsSync(target)) {
    let existing;
    try {
      existing = JSON.parse(fs.readFileSync(target, 'utf8'));
    } catch (err) {
      throw new Error(`existing baseline ${target} is not valid JSON (${err.message}); re-record it with --rerecord`);
    }
    if (
      !existing ||
      typeof existing !== 'object' ||
      Array.isArray(existing) ||
      existing.schema !== 'sdd-spec-baseline/v1' ||
      !existing.files ||
      typeof existing.files !== 'object'
    ) {
      throw new Error(`existing baseline ${target} is not an sdd-spec-baseline/v1 document; re-record it with --rerecord`);
    }
    return { status: 'EXISTING', baseline: existing, outputPath: target };
  }
  const baseline = buildSpecBaseline({ feature, projectRoot: root });
  fs.writeFileSync(target, `${JSON.stringify(baseline, null, 2)}\n`, 'utf8');
  return { status: 'RECORDED', baseline, outputPath: target };
}

function parseArgs(argv) {
  const opts = { feature: null, root: null, output: null, rerecord: false };
  for (let i = 0; i < argv.length; i += 1) {
    if (argv[i] === '--feature' && argv[i + 1]) {
      opts.feature = argv[i + 1];
      i += 1;
    } else if (argv[i] === '--root' && argv[i + 1]) {
      opts.root = argv[i + 1];
      i += 1;
    } else if (argv[i] === '--rerecord') {
      opts.rerecord = true;
    } else if (argv[i] === '--output' && argv[i + 1]) {
      opts.output = argv[i + 1];
      i += 1;
    }
  }
  return opts;
}

function main() {
  const opts = parseArgs(process.argv.slice(2));
  if (!opts.feature) {
    process.stderr.write('Usage: node record-spec-baseline.mjs --feature <feature> [--root <dir>] [--output <path>] [--rerecord]\n');
    process.exit(2);
  }
  try {
    const { status, baseline, outputPath } = writeSpecBaseline({
      feature: opts.feature,
      projectRoot: opts.root,
      outputPath: opts.output,
      rerecord: opts.rerecord,
    });
    process.stdout.write(
      JSON.stringify(
        {
          status,
          feature: baseline.feature,
          outputPath,
          trackedFiles: Object.keys(baseline.files || {}),
          identifierCount: Object.keys(baseline.identifiers || {}).length,
          gitHead: baseline.gitHead,
        },
        null,
        2,
      ) + '\n',
    );
  } catch (err) {
    process.stderr.write(`record-spec-baseline error: ${err.message}\n`);
    process.exit(1);
  }
}

if (isMainModule(import.meta.url, 'record-spec-baseline.mjs')) {
  main();
}
