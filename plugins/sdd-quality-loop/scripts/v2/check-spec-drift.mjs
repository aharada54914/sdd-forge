#!/usr/bin/env node
/**
 * Check approved specification files against specs/<feature>/.spec-baseline.json.
 * Detects silent goalpost moving (deleted/modified REQ/AC items or spec body edits
 * without a newly declared rationale under '## Spec Amendments').
 *
 * Usage:
 *   node check-spec-drift.mjs --feature <feature> [--root <dir>] [--baseline <path>]
 *                             [--format json|markdown] [--fail-on-undeclared]
 */
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import {
  canonicalSpecContractText,
  extractAmendmentEntries,
  extractSpecIdentifiers,
  findProjectRoot,
  loadGuardrailsConfig,
  matchProtectedSpecPath,
  sha256Text,
} from './guardrails-lib.mjs';

export function checkSpecDrift({ feature, projectRoot, baselinePath }) {
  if (!feature || /[\\/]/.test(feature) || feature === '.' || feature === '..') {
    throw new Error(`Invalid feature name: ${feature}`);
  }
  const root = findProjectRoot(projectRoot);
  const resolvedBaselinePath = baselinePath
    ? path.resolve(baselinePath)
    : path.join(root, 'specs', feature, '.spec-baseline.json');

  if (!fs.existsSync(resolvedBaselinePath)) {
    throw new Error(`Baseline file not found: ${resolvedBaselinePath}`);
  }

  const baseline = JSON.parse(fs.readFileSync(resolvedBaselinePath, 'utf8'));
  const config = loadGuardrailsConfig(root);
  const featureDir = path.join(root, 'specs', feature);

  const changedFiles = [];
  const deletedFiles = [];
  const addedFiles = [];
  const removedIdentifiers = [];
  const modifiedIdentifiers = [];
  const addedIdentifiers = [];
  const allCurrentAmendments = [];

  // 1. Inspect every baseline-tracked file (per-file comparison prevents cross-file ID clobbering)
  for (const [relPath, baseInfo] of Object.entries(baseline.files || {})) {
    const absPath = path.join(root, relPath);
    const baseIds = baseInfo.identifiers || {};
    if (!fs.existsSync(absPath)) {
      deletedFiles.push(relPath);
      for (const [id, info] of Object.entries(baseIds)) {
        removedIdentifiers.push({ id, file: relPath, before: info.line });
      }
      continue;
    }
    const rawText = fs.readFileSync(absPath, 'utf8');
    const contractHash = sha256Text(canonicalSpecContractText(rawText, baseInfo.fileName));
    if (contractHash !== baseInfo.contractSha256) {
      changedFiles.push(relPath);
    }

    const curIds = extractSpecIdentifiers(rawText);
    for (const [id, baseIdInfo] of Object.entries(baseIds)) {
      const cur = curIds[id];
      if (!cur) {
        removedIdentifiers.push({ id, file: relPath, before: baseIdInfo.line });
      } else if (cur.hash !== baseIdInfo.hash) {
        modifiedIdentifiers.push({ id, file: relPath, before: baseIdInfo.line, after: cur.line });
      }
    }
    for (const [id, cur] of Object.entries(curIds)) {
      if (!baseIds[id]) {
        addedIdentifiers.push({ id, file: relPath, after: cur.line });
      }
    }

    const amendments = extractAmendmentEntries(rawText);
    for (const entry of amendments) {
      allCurrentAmendments.push({ file: relPath, text: entry });
    }
  }

  // 2. Detect newly added protected spec files after baseline capture
  if (fs.existsSync(featureDir)) {
    for (const entry of fs.readdirSync(featureDir, { withFileTypes: true })) {
      if (!entry.isFile() || entry.name.startsWith('.')) continue;
      const fullPath = path.join(featureDir, entry.name);
      const matched = matchProtectedSpecPath(fullPath, root, config, root);
      if (!matched || baseline.files[matched.relPath]) continue;
      addedFiles.push(matched.relPath);
      const rawText = fs.readFileSync(fullPath, 'utf8');
      for (const [id, info] of Object.entries(extractSpecIdentifiers(rawText))) {
        addedIdentifiers.push({ id, file: matched.relPath, after: info.line });
      }
      for (const item of extractAmendmentEntries(rawText)) {
        allCurrentAmendments.push({ file: matched.relPath, text: item });
      }
    }
  }

  const hasDrift =
    changedFiles.length > 0 ||
    deletedFiles.length > 0 ||
    addedFiles.length > 0 ||
    removedIdentifiers.length > 0 ||
    modifiedIdentifiers.length > 0;

  const baselineAmendmentCount = Number(baseline.amendmentCount || 0);
  const hasNewDeclaredAmendment = allCurrentAmendments.length > baselineAmendmentCount;

  let status = 'CLEAN';
  if (hasDrift) {
    status = hasNewDeclaredAmendment ? 'AMENDED' : 'UNDECLARED_DRIFT';
  }

  return {
    schema: 'sdd-spec-drift/v1',
    feature,
    status,
    baselineRecordedAt: baseline.recordedAt || null,
    baselineGitHead: baseline.gitHead || null,
    changedFiles,
    deletedFiles,
    addedFiles,
    removedIdentifiers,
    modifiedIdentifiers,
    addedIdentifiers,
    amendments: allCurrentAmendments,
    baselineAmendmentCount,
  };
}

export function formatDriftMarkdown(report) {
  const badge =
    report.status === 'CLEAN'
      ? '✅ CLEAN'
      : report.status === 'AMENDED'
        ? '📝 AMENDED (Reviewable)'
        : '⚠️ UNDECLARED_DRIFT';

  const lines = [
    `## Spec Drift Check: \`${report.feature}\` — ${badge}`,
    '',
    `- **Status**: \`${report.status}\``,
    `- **Baseline**: ${report.baselineRecordedAt || 'unknown'} (HEAD: \`${report.baselineGitHead || 'n/a'}\`)`,
  ];

  if (report.status === 'CLEAN') {
    lines.push('- 承認済み仕様ファイルに実質的な変更はありません（`tasks.md` の `Status:` 更新のみ許容）。');
    return `${lines.join('\n')}\n`;
  }

  if (report.changedFiles.length > 0) {
    lines.push(`- **Changed files**: ${report.changedFiles.map((f) => `\`${f}\``).join(', ')}`);
  }
  if (report.deletedFiles.length > 0) {
    lines.push(`- **Deleted files**: ${report.deletedFiles.map((f) => `\`${f}\``).join(', ')}`);
  }
  if (report.addedFiles.length > 0) {
    lines.push(`- **Added files**: ${report.addedFiles.map((f) => `\`${f}\``).join(', ')}`);
  }

  if (report.removedIdentifiers.length > 0) {
    lines.push('', '### Removed REQ / AC Identifiers');
    for (const item of report.removedIdentifiers) {
      lines.push(`- **${item.id}** (\`${item.file}\`): ~~${item.before}~~`);
    }
  }
  if (report.modifiedIdentifiers.length > 0) {
    lines.push('', '### Modified REQ / AC Identifiers');
    for (const item of report.modifiedIdentifiers) {
      lines.push(`- **${item.id}** (\`${item.file}\`)`);
      lines.push(`  - Before: ${item.before}`);
      lines.push(`  - After: ${item.after}`);
    }
  }
  if (report.addedIdentifiers.length > 0) {
    lines.push('', '### Added REQ / AC Identifiers');
    for (const item of report.addedIdentifiers) {
      lines.push(`- **${item.id}** (\`${item.file}\`): ${item.after}`);
    }
  }

  if (report.amendments.length > 0) {
    lines.push('', '### Declared Spec Amendments');
    for (const a of report.amendments) {
      lines.push(`- (\`${a.file}\`) ${a.text}`);
    }
  } else if (report.status === 'UNDECLARED_DRIFT') {
    lines.push(
      '',
      '> **Action Required**: 仕様変更の理由が `## Spec Amendments` に記録されていません。意図しない改変なら元に戻し、意図的な仕様変更であればユーザー合意のうえ `## Spec Amendments` に理由を追記してください。',
    );
  }

  return `${lines.join('\n')}\n`;
}

function parseArgs(argv) {
  const opts = {
    feature: null,
    root: null,
    baseline: null,
    format: 'json',
    failOnUndeclared: false,
  };
  for (let i = 0; i < argv.length; i += 1) {
    if (argv[i] === '--feature' && argv[i + 1]) {
      opts.feature = argv[i + 1];
      i += 1;
    } else if (argv[i] === '--root' && argv[i + 1]) {
      opts.root = argv[i + 1];
      i += 1;
    } else if (argv[i] === '--baseline' && argv[i + 1]) {
      opts.baseline = argv[i + 1];
      i += 1;
    } else if (argv[i] === '--format' && argv[i + 1]) {
      opts.format = argv[i + 1];
      i += 1;
    } else if (argv[i] === '--fail-on-undeclared') {
      opts.failOnUndeclared = true;
    }
  }
  return opts;
}

function main() {
  const opts = parseArgs(process.argv.slice(2));
  if (!opts.feature) {
    process.stderr.write(
      'Usage: node check-spec-drift.mjs --feature <feature> [--root <dir>] [--baseline <path>] [--format json|markdown] [--fail-on-undeclared]\n',
    );
    process.exit(2);
  }

  try {
    const report = checkSpecDrift({
      feature: opts.feature,
      projectRoot: opts.root || process.cwd(),
      baselinePath: opts.baseline,
    });
    if (opts.format === 'markdown') {
      process.stdout.write(formatDriftMarkdown(report));
    } else {
      process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
    }
    if (opts.failOnUndeclared && report.status === 'UNDECLARED_DRIFT') {
      process.exit(1);
    }
    process.exit(0);
  } catch (err) {
    process.stderr.write(`check-spec-drift error: ${err.message}\n`);
    process.exit(2);
  }
}

if (
  process.argv[1] &&
  path.basename(process.argv[1]) === 'check-spec-drift.mjs' &&
  import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href
) {
  main();
}
