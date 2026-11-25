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
import {
  createFsReadonlyIo,
  loadGuardrailsConfig,
  resolveExplicitOrAutoRoot,
  toPosixPath,
  isMainModule,
} from './guardrails-lib.mjs';
import { checkSpecDriftCore } from './v2-readonly-core.mjs';

export function checkSpecDrift({ feature, projectRoot, baselinePath }) {
  const root = resolveExplicitOrAutoRoot(projectRoot);
  const baseIo = createFsReadonlyIo(root);
  const config = loadGuardrailsConfig(root);

  let io = baseIo;
  let baselineRelPath = null;
  if (baselinePath) {
    const resolvedBaselineAbs = path.resolve(baselinePath);
    const rel = path.relative(root, resolvedBaselineAbs);
    if (!rel.startsWith('..') && !path.isAbsolute(rel)) {
      baselineRelPath = toPosixPath(rel);
    } else {
      // Explicit external CLI --baseline path: wrap readText for that single file only.
      const sentinel = `specs/${feature}/.spec-baseline.json`;
      baselineRelPath = sentinel;
      io = {
        ...baseIo,
        readText(relPath) {
          if (relPath === sentinel) {
            return fs.existsSync(resolvedBaselineAbs)
              ? fs.readFileSync(resolvedBaselineAbs, 'utf8')
              : null;
          }
          return baseIo.readText(relPath);
        },
      };
    }
  }

  return checkSpecDriftCore(io, { feature, baselineRelPath, config });
}

export function formatDriftMarkdown(report) {
  const badge =
    report.status === 'CLEAN'
      ? '✅ CLEAN'
      : report.status === 'AMENDED'
        ? '📝 AMENDED (Reviewable)'
        : report.status === 'UNVERIFIABLE'
          ? '❔ UNVERIFIABLE'
          : '⚠️ UNDECLARED_DRIFT';

  const lines = [
    `## Spec Drift Check: \`${report.feature}\` — ${badge}`,
    '',
    `- **Status**: \`${report.status}\``,
    `- **Baseline**: ${report.baselineRecordedAt || 'unknown'} (HEAD: \`${report.baselineGitHead || 'n/a'}\`)`,
  ];

  if (report.status === 'CLEAN') {
    lines.push('- 承認済み仕様ファイルに実質的な変更はありません（`tasks.md` の `Status:` / `Approval:` 更新のみ許容）。');
    if ((report.newlyApprovedTasks || []).length > 0) {
      // Shown even when CLEAN: the reviewer confirms a human made each approval
      // (the soft guard does not see shell edits).
      lines.push(`- **Approved since the baseline — confirm a human approved each**: ${report.newlyApprovedTasks.join(', ')}`);
    }
    return `${lines.join('\n')}\n`;
  }

  if (report.changedFiles.length > 0) {
    lines.push(`- **Changed files**: ${report.changedFiles.map((f) => `\`${f}\``).join(', ')}`);
  }
  if ((report.changedIdsWithoutAmendment || []).length > 0) {
    lines.push(
      `- **Changed IDs with no amendment entry mentioning them**: ${report.changedIdsWithoutAmendment.join(', ')}` +
        '（AMENDED は理由の件数増加だけを機械判定する。個々の差分と理由の対応は独立レビュー G2 が判断する）',
    );
  }
  if ((report.unreadableFiles || []).length > 0) {
    lines.push(`- **Unreadable (present but over the read limit or blocked; not checked)**: ${report.unreadableFiles.map((f) => `\`${f}\``).join(', ')}`);
  }
  if ((report.revokedApprovals || []).length > 0) {
    lines.push(`- **Approval revoked since the baseline**: ${report.revokedApprovals.join(', ')}`);
  }
  if ((report.newlyApprovedTasks || []).length > 0) {
    lines.push(`- Newly approved since the baseline (not drift): ${report.newlyApprovedTasks.join(', ')}`);
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
  } else if (report.status === 'UNVERIFIABLE') {
    lines.push(
      '',
      '> **Action Required**: 一部の仕様ファイルを読めなかったため差分を判定していません（削除ではありません）。読取上限の大きいローカル CLI（`check-spec-drift.mjs`）で確認するか、ファイルを分割してください。',
    );
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
    if (opts.failOnUndeclared && (report.status === 'UNDECLARED_DRIFT' || report.status === 'UNVERIFIABLE')) {
      process.exit(1);
    }
    process.exit(0);
  } catch (err) {
    process.stderr.write(`check-spec-drift error: ${err.message}\n`);
    process.exit(2);
  }
}

if (isMainModule(import.meta.url, 'check-spec-drift.mjs')) {
  main();
}
