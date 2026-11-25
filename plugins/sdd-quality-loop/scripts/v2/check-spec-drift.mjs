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
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import {
  createFsReadonlyIo,
  globToRegExp,
  loadGuardrailsConfig,
  normalizeRelPath,
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

const TEST_SKIP_RE = /(?:\b(?:it|test|describe)\.skip\s*\(|\b(?:xit|xdescribe)\s*\(|@pytest\.mark\.skip\b|unittest\.skip\b|\bt\.Skip\s*\()/;
const LINT_DISABLE_RE = /sdd-lint-disable\b/i;
const TLA_TRIVIAL_INVARIANT_RE = /^[A-Za-z0-9_]+\s*==\s*TRUE\b/;

function isTestFileRelPath(relPath) {
  const lower = normalizeRelPath(relPath).toLowerCase();
  return (
    lower.startsWith('tests/') ||
    lower.startsWith('test/') ||
    lower.includes('/tests/') ||
    lower.includes('/__tests__/') ||
    /(?:\.test|\.spec|_test|\.tests)\.[a-z0-9]+$/i.test(lower)
  );
}

function loadApprovedTestRetirements(root, manifestRelPath) {
  const rel = normalizeRelPath(manifestRelPath || 'sdd/approved-test-retirements.json');
  const abs = path.join(root, ...rel.split('/'));
  const byPath = new Map();
  if (!fs.existsSync(abs)) return byPath;
  const parsed = JSON.parse(fs.readFileSync(abs, 'utf8'));
  const entries = Array.isArray(parsed?.retirements) ? parsed.retirements : [];
  for (const item of entries) {
    if (!item || typeof item.path !== 'string' || typeof item.git_blob_sha !== 'string') continue;
    const key = normalizeRelPath(item.path);
    if (!byPath.has(key)) byPath.set(key, new Set());
    byPath.get(key).add(item.git_blob_sha.trim().toLowerCase());
  }
  return byPath;
}

function getGitBlobSha(root, baseRef, relPath) {
  try {
    return execFileSync('git', ['rev-parse', `${baseRef}:${relPath}`], {
      cwd: root,
      encoding: 'utf8',
      shell: false,
      stdio: ['ignore', 'pipe', 'pipe'],
    })
      .trim()
      .toLowerCase();
  } catch {
    return null;
  }
}

/**
 * Checks `git diff <baseRef>` for verification-surface tampering (ADR-0054 REQ-010 / AC-009):
 * - Unapproved modifications to protected repository paths
 * - Test file deletions not matched by path + git_blob_sha in CODEOWNERS-protected manifest
 * - Added test skip directives, inline sdd-lint-disable comments, or TLA+ `== TRUE` weakening
 */
export function checkAntiTampering({ projectRoot, baseRef = null, config = null }) {
  const root = resolveExplicitOrAutoRoot(projectRoot);
  const effectiveConfig = config || loadGuardrailsConfig(root);
  const atCfg = effectiveConfig.anti_tampering || {};
  const effectiveBaseRef = baseRef || atCfg.base_ref || 'HEAD';
  const protectedGlobs = Array.isArray(atCfg.protected_repo_paths) ? atCfg.protected_repo_paths : [];
  const protectedRegexes = protectedGlobs.map((g) => globToRegExp(g));
  const approvedRetirements = loadApprovedTestRetirements(root, atCfg.retirements_manifest);

  const nameStatusRaw = execFileSync('git', ['diff', '--name-status', '--no-renames', effectiveBaseRef], {
    cwd: root,
    encoding: 'utf8',
    shell: false,
    stdio: ['ignore', 'pipe', 'pipe'],
  });

  const diffRaw = execFileSync('git', ['diff', '--unified=0', '--no-renames', effectiveBaseRef], {
    cwd: root,
    encoding: 'utf8',
    shell: false,
    stdio: ['ignore', 'pipe', 'pipe'],
  });

  const violations = [];
  const changedEntries = [];
  for (const line of nameStatusRaw.split(/\r?\n/)) {
    if (!line.trim()) continue;
    const [statusCode, ...rest] = line.split('\t');
    const relPath = normalizeRelPath(rest.join('\t'));
    if (!relPath) continue;
    changedEntries.push({ status: statusCode.trim(), relPath });
  }

  for (const { status, relPath } of changedEntries) {
    if (protectedRegexes.some((re) => re.test(relPath))) {
      violations.push({
        code: 'PROTECTED_PATH_MODIFIED',
        path: relPath,
        detail: `保護対象パス (${relPath}) が変更されています (${status})`,
      });
    }
    if (status === 'D' && isTestFileRelPath(relPath)) {
      const blobSha = getGitBlobSha(root, effectiveBaseRef, relPath);
      const allowedShas = approvedRetirements.get(relPath);
      const isApproved = Boolean(blobSha && allowedShas && allowedShas.has(blobSha));
      if (!isApproved) {
        violations.push({
          code: 'UNAUTHORIZED_TEST_DELETION',
          path: relPath,
          detail: `テストファイル (${relPath}) が sdd/approved-test-retirements.json の path+git_blob_sha 承認なしに削除されました (blob=${blobSha || 'unknown'})`,
        });
      }
    }
  }

  let currentFile = null;
  for (const line of diffRaw.split(/\r?\n/)) {
    if (line.startsWith('+++ b/')) {
      currentFile = normalizeRelPath(line.slice(6));
      continue;
    }
    if (line.startsWith('+++ /dev/null')) {
      currentFile = null;
      continue;
    }
    if (!currentFile || !line.startsWith('+') || line.startsWith('+++')) continue;
    const addedText = line.slice(1);
    if (isTestFileRelPath(currentFile) && TEST_SKIP_RE.test(addedText)) {
      violations.push({
        code: 'TEST_SKIP_ADDED',
        path: currentFile,
        detail: `テストの skip 指定が追加されました: ${addedText.trim()}`,
      });
    }
    if (LINT_DISABLE_RE.test(addedText)) {
      violations.push({
        code: 'LINT_DISABLE_ADDED',
        path: currentFile,
        detail: `インライン Lint 抑止コメントが追加されました（sdd/guardrails.yaml の agent_lint.waivers を使用してください）: ${addedText.trim()}`,
      });
    }
    if (currentFile.toLowerCase().endsWith('.tla') && TLA_TRIVIAL_INVARIANT_RE.test(addedText.trim())) {
      violations.push({
        code: 'FORMAL_INVARIANT_WEAKENED',
        path: currentFile,
        detail: `TLA+ 不変条件が自明な == TRUE へ弱体化されています: ${addedText.trim()}`,
      });
    }
  }

  return {
    schema: 'sdd-anti-tamper/v1',
    status: violations.length > 0 ? 'TAMPER_DETECTED' : 'CLEAN',
    baseRef: effectiveBaseRef,
    checkedFilesCount: changedEntries.length,
    violations,
  };
}

export function formatAntiTamperMarkdown(report) {
  const badge = report.status === 'CLEAN' ? '✅ CLEAN' : '🚨 TAMPER_DETECTED';
  const lines = [
    `## Anti-Tampering Check — ${badge}`,
    '',
    `- **Status**: \`${report.status}\``,
    `- **Base Ref**: \`${report.baseRef}\``,
    `- **Checked Changed Files**: ${report.checkedFilesCount}`,
  ];
  if (report.violations.length > 0) {
    lines.push('', '### Violations');
    for (const v of report.violations) {
      lines.push(`- **${v.code}** (\`${v.path}\`): ${v.detail}`);
    }
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
    antiTamper: false,
    baseRef: null,
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
    } else if (argv[i] === '--anti-tamper') {
      opts.antiTamper = true;
    } else if (argv[i] === '--base-ref' && argv[i + 1]) {
      opts.baseRef = argv[i + 1];
      i += 1;
    }
  }
  return opts;
}

function main() {
  const opts = parseArgs(process.argv.slice(2));
  if (opts.antiTamper) {
    try {
      const report = checkAntiTampering({
        projectRoot: opts.root || process.cwd(),
        baseRef: opts.baseRef,
      });
      if (opts.format === 'markdown') {
        process.stdout.write(formatAntiTamperMarkdown(report));
      } else {
        process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
      }
      process.exit(report.status === 'TAMPER_DETECTED' ? 4 : 0);
    } catch (err) {
      process.stderr.write(`check-spec-drift --anti-tamper error: ${err.message}\n`);
      process.exit(2);
    }
  }

  if (!opts.feature) {
    process.stderr.write(
      'Usage: node check-spec-drift.mjs --feature <feature> [--root <dir>] [--baseline <path>] [--format json|markdown] [--fail-on-undeclared]\n' +
        '   or: node check-spec-drift.mjs --anti-tamper [--base-ref <ref>] [--root <dir>] [--format json|markdown]\n',
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
