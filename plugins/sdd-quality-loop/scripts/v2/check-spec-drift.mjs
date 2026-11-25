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
  DEFAULT_CONFIG,
  assertValidFeatureName,
  createFsReadonlyIo,
  normalizeGuardrailsConfig,
  parseSimpleYaml,
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

const TEST_SKIP_RE = /(?:\b(?:it|test|describe)\.skip\s*\(|\b(?:xit|xdescribe)\s*\(|@pytest\.mark\.skip\b|unittest\.skip\b|\bt\.Skip\s*\()/g;
const JS_TOKEN = /\/\/[^\n]*|\/\*[\s\S]*?\*\/|"(?:\\[\s\S]|[^"\\])*"|'(?:\\[\s\S]|[^'\\])*'|`(?:\\[\s\S]|[^`\\])*`|[\w$]+|[^\s]/g;
const TEST_FUNCTIONS = new Set(['it', 'test', 'describe', 'suite']);
const DISABLED_SKIP_VALUES = new Set(['false', "''", '""', '``', 'null', 'undefined', '0']);

// Remove documentation and literals before counting executable language-specific markers.
const PYTHON_NON_CODE = /#[^\n]*|"""(?:\\[\s\S]|(?!""")[^\\])*"""|'''(?:\\[\s\S]|(?!''')[^\\])*'''|"(?:\\[\s\S]|[^"\\])*"|'(?:\\[\s\S]|[^'\\])*'/g;
const GO_NON_CODE = /\/\/[^\n]*|\/\*[\s\S]*?\*\/|`[^`]*`|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'/g;
const PYTHON_SKIP = /@pytest\.mark\.skip(?:if)?\b|\b(?:unittest\.skip(?:If|Unless)?|pytest\.skip|self\.skipTest)\s*\(/g;
const GO_SKIP = /\bt\.Skip(?:f|Now)?\s*\(/g;

// The first parameter of an inline node:test callback receives its TestContext.
// Its name is chosen by the caller; an unrelated object's skip method is ordinary code.
function callbackContext(tokens, offset) {
  let i = offset;
  if (tokens[i] === 'async') i++;
  const functionExpression = tokens[i] === 'function';
  if (functionExpression) {
    i++;
    if (tokens[i] !== '(') i++; // named function expression
  }
  const grouped = tokens[i] === '(';
  if (grouped) i++;
  const name = tokens[i];
  if (!/^[A-Za-z_$][\w$]*$/.test(name || '')) return null;
  if (functionExpression) return grouped ? name : null;
  const end = grouped ? tokens.indexOf(')', i + 1) + 1 : i + 1;
  return end > 0 && tokens[end] === '=' && tokens[end + 1] === '>' ? name : null;
}

function countTestSkips(file, source) {
  if (/\.pyw?$/i.test(file)) return Array.from(source.replace(PYTHON_NON_CODE, ' ').matchAll(PYTHON_SKIP)).length;
  if (/\.go$/i.test(file)) return Array.from(source.replace(GO_NON_CODE, ' ').matchAll(GO_SKIP)).length;
  if (!/\.[cm]?[jt]sx?$/i.test(file)) return Array.from(source.matchAll(TEST_SKIP_RE)).length;
  // Keep strings intact and ignore comments so that a label, example or callback
  // object does not become a skip option. Only inspect direct test arguments.
  const tokens = (source.match(JS_TOKEN) || []).filter(token => !token.startsWith('//') && !token.startsWith('/*'));
  const stack = [];
  let count = 0;
  for (let i = 0; i < tokens.length; i++) {
    const token = tokens[i];
    const previous = tokens[i - 1];
    const parent = stack.at(-1);
    if (parent?.testCall && (previous === '(' || previous === ',')) {
      const context = callbackContext(tokens, i);
      if (context) parent.context = context;
    }
    if (token === '(') {
      const receiver = tokens[i - 3];
      const method = previous === 'skip' && tokens[i - 2] === '.' &&
        (TEST_FUNCTIONS.has(receiver) || stack.some(frame => frame.context && frame.context === receiver));
      const skipped = method || previous === 'xit' || previous === 'xdescribe';
      if (skipped) count++;
      stack.push({ testCall: !skipped && TEST_FUNCTIONS.has(previous) });
    } else if (token === '{' || token === '[') {
      const options = token === '{' && parent?.testCall && (previous === '(' || previous === ',');
      stack.push({ options });
    } else if (token === '}' || token === ']' || token === ')') {
      stack.pop();
    } else if (parent?.options && (previous === '{' || previous === ',') && /^(?:skip|"skip"|'skip')$/.test(token)) {
      // Computed conditions may activate a skip. Only a complete falsy literal
      // unconditionally leaves the test enabled.
      const next = tokens[i + 1];
      if (next === ':') {
        const valueEnds = tokens[i + 3] === ',' || tokens[i + 3] === '}';
        if (!valueEnds || !DISABLED_SKIP_VALUES.has(tokens[i + 2])) count++;
      } else if (token === 'skip' && (next === ',' || next === '}')) {
        count++;
      }
    }
  }
  return count;
}

const LINT_DISABLE_RE = /sdd-lint-disable\b/i;

// Match the directive at the start of a comment line. Quoted examples and
// explanations can contain the same spelling without suppressing a check.
const DIRECTIVE_START = /^\s*(?:\/\/|\/\*+|\*|#)?\s*sdd-lint-disable\b/i;
const HASH_NON_CODE = /#[^\n]*|"(?:\\[\s\S]|[^"\\])*"|'(?:\\[\s\S]|[^'\\])*'/g;
const JS_NON_CODE = /\/\/[^\n]*|\/\*[\s\S]*?(?:\*\/|$)|"(?:\\[\s\S]|[^"\\])*"|'(?:\\[\s\S]|[^'\\])*'|`(?:\\[\s\S]|[^`\\])*`/g;

function shellDelimiter(word) {
  // A delimiter undergoes quote removal without variable expansion.
  return word.replace(/'([^']*)'|"((?:\\[\s\S]|[^"\\])*)"|\\([\s\S])/g, (_, single, double, escaped) => {
    if (single !== undefined) return single;
    if (double !== undefined) return double.replace(/\\([$"`\\])/g, '$1');
    return escaped;
  });
}

function hereDocumentEnd(source, cursor, { delimiter, stripTabs, quoted }) {
  let logicalLine = '';
  while (cursor < source.length) {
    const newline = source.indexOf('\n', cursor);
    const end = newline < 0 ? source.length : newline;
    logicalLine += source.slice(cursor, end);
    cursor = newline < 0 ? end : end + 1;
    if (!quoted && newline >= 0 && /(?:^|[^\\])(?:\\\\)*\\$/.test(logicalLine)) {
      logicalLine = logicalLine.slice(0, -1);
      continue;
    }
    if ((stripTabs ? logicalLine.replace(/^\t+/, '') : logicalLine) === delimiter) return cursor;
    logicalLine = '';
  }
  // Uncertain boundaries must leave later comments visible to the checker.
  return null;
}

// Keep shell words intact so quoted operators and a # within a word are literal.
// Here-documents start after the command's unescaped newline, in redirect order.
function* shellComments(source) {
  const tokens = /\\\n|[ \t]+|#[^\n]*|<<<|<<-?|\(\(|[()]|\n|(?<word>(?:'[^']*'|"(?:\\[\s\S]|[^"\\])*"|\\[\s\S]|[^ \t\n;|&()<>'"\\])+)|./g;
  const pending = [];
  let redirect = '';
  let arithmeticDepth = 0;
  for (let match; (match = tokens.exec(source));) {
    const token = match[0];
    if (token === '\\\n' || /^[ \t]/.test(token)) continue;
    if (token === '\n') {
      for (const document of pending) {
        const end = hereDocumentEnd(source, tokens.lastIndex, document);
        if (end === null) break;
        tokens.lastIndex = end;
      }
      pending.length = 0;
    } else if (token.startsWith('#')) {
      yield match;
    } else if (redirect && match.groups.word) {
      const word = token.replace(/\\\n/g, '');
      pending.push({ delimiter: shellDelimiter(word), stripTabs: redirect === '<<-', quoted: /['"\\]/.test(word) });
    } else if (token === '((') {
      arithmeticDepth += 2;
    } else if (arithmeticDepth && token === '(') {
      arithmeticDepth++;
    } else if (arithmeticDepth && token === ')') {
      arithmeticDepth--;
    }
    redirect = !arithmeticDepth && (token === '<<' || token === '<<-') ? token : '';
  }
}

const SOURCE_TOKENS = new Map();
for (const [extensions, tokens] of [
  ['js mjs cjs jsx ts mts cts tsx', JS_NON_CODE],
  ['go c h cc cpp hpp cs java kt kts rs swift scala', GO_NON_CODE],
  ['py pyw', PYTHON_NON_CODE],
  ['rb pl ps1', HASH_NON_CODE],
  ['sh bash zsh', shellComments],
]) {
  for (const ext of extensions.split(' ')) SOURCE_TOKENS.set('.' + ext, tokens);
}

function addedLintDirectives(root, revision, file, status, source, tokens) {
  if (!LINT_DISABLE_RE.test(source)) return [];
  // Reading the entire post-image preserves comment and string context across
  // diff hunk boundaries. Only comment lines added by this change are reported.
  const added = [];
  if (status === 'A') added.push([1, Infinity]);
  else {
    const patch = gitText(root, ['--literal-pathspecs', 'diff', '--no-color', '--no-ext-diff', '--no-textconv', '--unified=0', revision, '--', file]);
    for (const hunk of patch.matchAll(/^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@/gm)) {
      const first = Number(hunk[1]);
      added.push([first, first + Number(hunk[2] ?? 1) - 1]);
    }
  }
  const directives = [];
  let line = 1;
  let offset = 0;
  const matches = typeof tokens === 'function' ? tokens(source) : source.matchAll(tokens);
  for (const token of matches) {
    line += source.slice(offset, token.index).split('\n').length - 1;
    const lines = token[0].split('\n');
    if (/^(?:#|\/\/|\/\*)/.test(token[0])) {
      for (const [i, text] of lines.entries()) {
        if (DIRECTIVE_START.test(text) && added.some(([start, end]) => start <= line + i && line + i <= end)) {
          directives.push(text.trim());
        }
      }
    }
    offset = token.index + token[0].length;
    line += lines.length - 1;
  }
  return directives;
}

const TLA_DECLARATION = /^(?:={4,}|-{4,}|(?:LOCAL\s+)?\w+(?:\s*\([^)]*\))?[ \t]*==|(?:ASSUME|ASSUMPTION|AXIOM|CONSTANTS?|VARIABLES?|INSTANCE|THEOREM|LEMMA|RECURSIVE)\b)/;

function unconditionalTrueDefinitions(source) {
  const names = new Set();
  // Strings are tokens, including when they contain comment delimiters. Preserve
  // physical lines across nested block comments so declarations remain anchored.
  let commentDepth = 0;
  const lines = source.split(/\r?\n/).map(line => {
    let code = '';
    for (let i = 0; i < line.length;) {
      const pair = line.slice(i, i + 2);
      if (pair === '(*') { commentDepth++; code += ' '; i += 2; }
      else if (commentDepth && pair === '*)') { commentDepth--; i += 2; }
      else if (commentDepth) i++;
      else if (pair === '\\*') break;
      else if (line[i] === '"') {
        const quoted = /^"(?:\\.|[^"\\])*"/.exec(line.slice(i));
        code += '""';
        i += quoted ? quoted[0].length : line.length - i;
      } else code += line[i++];
    }
    return code.trim();
  }).filter(Boolean);
  for (let i = 0; i < lines.length; i++) {
    const definition = /^(?:LOCAL\s+)?(\w+)\s*==\s*(TRUE)?$/.exec(lines[i]);
    if (!definition) continue;
    let end = i + 1;
    if (!definition[2]) {
      if (lines[end] !== 'TRUE') continue;
      end++;
    }
    if (end === lines.length || TLA_DECLARATION.test(lines[end])) names.add(definition[1]);
  }
  return names;
}

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

function gitText(root, args, options = {}) {
  return execFileSync('git', args, { cwd: root, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], ...options });
}

function committedText(root, revision, file) {
  const entry = gitText(root, ['--literal-pathspecs', 'ls-tree', '-lz', revision, '--', file]);
  const blob = /^100(?:644|755) blob ([a-f0-9]+)\s+(\d+)\t/.exec(entry);
  if (!blob) return null;
  return gitText(root, ['cat-file', 'blob', blob[1]], { maxBuffer: Math.max(1, Number(blob[2])) });
}

function committedPolicy(root, revision) {
  const json = committedText(root, revision, 'sdd/guardrails.json');
  const yaml = json === null && committedText(root, revision, 'sdd/guardrails.yaml');
  return normalizeGuardrailsConfig(json !== null ? JSON.parse(json) : yaml ? parseSimpleYaml(yaml) : {}).anti_tampering;
}

function loadApprovedTestRetirements(root, revision) {
  const byPath = new Map();
  const text = committedText(root, revision, DEFAULT_CONFIG.anti_tampering.retirements_manifest);
  if (text === null) return byPath;
  const manifest = JSON.parse(text);
  if (manifest.schema !== 'sdd-approved-test-retirements/v1' || !Array.isArray(manifest.retirements)) return byPath;
  for (const item of manifest.retirements) {
    if (!item || typeof item.path !== 'string' || !/^(?:[a-f0-9]{40}|[a-f0-9]{64})$/.test(item.git_blob_sha)) continue;
    if (![item.reason, item.approved_by].every(value => typeof value === 'string' && value.trim())) continue;
    if (!byPath.has(item.path)) byPath.set(item.path, new Set());
    byPath.get(item.path).add(item.git_blob_sha);
  }
  return byPath;
}

function recordTamperingQuestion(root, feature, revision, violations) {
  assertValidFeatureName(feature);
  let directory = root;
  for (const part of ['reports', 'verification', feature, 'anti-tampering']) {
    directory = path.join(directory, part);
    fs.mkdirSync(directory, { recursive: true });
    if (fs.lstatSync(directory).isSymbolicLink()) throw new Error('Unsafe escalation directory');
  }
  // Publish a complete question atomically. Concurrent retries reuse the same evidence.
  const facts = violations.map(({ code, path }) => ({ code, path }));
  const tempDir = fs.mkdtempSync(path.join(directory, '.pending-'));
  const candidate = path.join(tempDir, 'question.json');
  try {
    for (let number = 1; ; number++) {
      const id = 'OQ-' + String(number).padStart(3, '0');
      const filename = path.join(directory, id + '.json');
      const ref = { id, path: toPosixPath(path.relative(root, filename)) };
      const issue = { id, status: 'Provisional', feature, baseCommit: revision, violations: facts };
      fs.writeFileSync(candidate, JSON.stringify(issue, null, 2) + '\n');
      try {
        fs.linkSync(candidate, filename);
        return ref;
      } catch (err) {
        if (err.code !== 'EEXIST') throw err;
      }
      if (!fs.lstatSync(filename).isFile()) continue;
      const text = fs.readFileSync(filename, 'utf8');
      let existing;
      try {
        existing = JSON.parse(text);
      } catch (err) {
        if (err instanceof SyntaxError) continue;
        throw err;
      }
      if (existing?.id === id && existing.feature === feature && existing.baseCommit === revision &&
          ['Provisional', 'Confirmed'].includes(existing.status) &&
          JSON.stringify(existing.violations) === JSON.stringify(facts)) return ref;
    }
  } finally {
    fs.rmSync(tempDir, { recursive: true, force: true });
  }
}

function getGitBlobSha(root, baseRef, relPath) {
  try {
    return execFileSync('git', ['rev-parse', `${baseRef}:./${relPath}`], {
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

/** Compare a trusted revision and the worktree, including new protected files. */
export function readProtectedDiff(root, baseRef, additionalGlobs = []) {
  const effectiveBaseRef = baseRef || committedPolicy(root, 'HEAD').base_ref;
  const revision = gitText(root, ['rev-parse', '--verify', '--end-of-options', effectiveBaseRef + '^{commit}']).trim();
  const policy = committedPolicy(root, revision);
  const protectedGlobs = new Set([...DEFAULT_CONFIG.anti_tampering.protected_repo_paths,
    'sdd/guardrails.json', '.github/CODEOWNERS', 'docs/CODEOWNERS', ...policy.protected_repo_paths]);
  const protectedRegexes = Array.from(protectedGlobs, glob => globToRegExp(glob));
  const nameStatusRaw = gitText(root, ['diff', '--name-status', '-z', '--no-renames', '--relative', revision, '--']);

  const changedEntries = [];
  const fields = nameStatusRaw.split('\0');
  for (let i = 0; i + 1 < fields.length; i += 2) {
    changedEntries.push({ status: fields[i], relPath: fields[i + 1] });
  }
  const untracked = gitText(root, ['ls-files', '--others', '--exclude-standard', '-z', '--', ...protectedGlobs, ...additionalGlobs]);
  for (const relPath of untracked.split('\0').filter(Boolean)) {
    changedEntries.push({ status: 'A', relPath });
  }

  return { effectiveBaseRef, revision, protectedRegexes, changedEntries };
}

/**
 * Checks `git diff <baseRef>` for verification-surface tampering (ADR-0054 REQ-010 / AC-009):
 * - Unapproved modifications to protected repository paths
 * - Test file deletions not matched by path + git_blob_sha in CODEOWNERS-protected manifest
 * - Added test skip directives, inline sdd-lint-disable comments, or TLA+ `== TRUE` weakening
 */
export function checkAntiTampering({ projectRoot, baseRef = null, feature = 'repository' }) {
  const root = resolveExplicitOrAutoRoot(projectRoot);
  const testGlobs = ['tests/**', 'test/**', '**/tests/**', '**/__tests__/**', '*.test.*', '*.spec.*', '*_test.*', '*.tests.*'];
  const sourceGlobs = Array.from(SOURCE_TOKENS.keys(), ext => ':(icase,glob)**/*' + ext);
  const { effectiveBaseRef, revision, protectedRegexes, changedEntries } = readProtectedDiff(root, baseRef, [...testGlobs, '*.tla', ...sourceGlobs]);
  const approvedRetirements = loadApprovedTestRetirements(root, revision);
  const violations = [];

  for (const { status, relPath } of changedEntries) {
    if (protectedRegexes.some((re) => re.test(relPath))) {
      violations.push({
        code: 'PROTECTED_PATH_MODIFIED',
        path: relPath,
        detail: `保護対象パス (${relPath}) が変更されています (${status})`,
      });
    }
    if (status === 'D' && isTestFileRelPath(relPath)) {
      const blobSha = getGitBlobSha(root, revision, relPath);
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

  for (const { status, relPath: currentFile } of changedEntries) {
    if (status === 'D') continue;
    const isTest = isTestFileRelPath(currentFile);
    const isTla = currentFile.toLowerCase().endsWith('.tla');
    const absolute = path.join(root, currentFile);
    const sourceTokens = SOURCE_TOKENS.get(path.extname(currentFile).toLowerCase());
    if ((!isTest && !isTla && !sourceTokens) || !fs.lstatSync(absolute).isFile()) continue;
    const after = fs.readFileSync(absolute, 'utf8');
    if (isTest || isTla) {
      const before = status === 'A' ? '' : committedText(root, revision, currentFile) || '';
      if (isTest) {
        const previousCount = countTestSkips(currentFile, before);
        const currentCount = countTestSkips(currentFile, after);
        if (currentCount > previousCount) {
          violations.push({ code: 'TEST_SKIP_ADDED', path: currentFile,
            detail: `テストの skip 指定が ${previousCount} 件から ${currentCount} 件に増えました` });
        }
      }
      if (isTla) {
        const previous = unconditionalTrueDefinitions(before);
        for (const name of unconditionalTrueDefinitions(after)) {
          if (!previous.has(name)) violations.push({ code: 'FORMAL_INVARIANT_WEAKENED', path: currentFile,
            detail: `TLA+ 不変条件が自明な == TRUE へ弱体化されています: ${name}` });
        }
      }
    }
    if (sourceTokens) {
      for (const directive of addedLintDirectives(root, revision, currentFile, status, after, sourceTokens)) {
        violations.push({
          code: 'LINT_DISABLE_ADDED', path: currentFile,
          detail: `インライン Lint 抑止コメントが追加されました（sdd/guardrails.yaml の agent_lint.waivers を使用してください）: ${directive}`,
        });
      }
    }
  }

  return {
    schema: 'sdd-anti-tamper/v1',
    status: violations.length > 0 ? 'TAMPER_DETECTED' : 'CLEAN',
    baseRef: effectiveBaseRef,
    checkedFilesCount: changedEntries.length,
    ...(violations.length && { openQuestion: recordTamperingQuestion(root, feature, revision, violations) }),
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
    lines.push('', `- **Open question**: ${report.openQuestion.id} (\`${report.openQuestion.path}\`)`, '', '### Violations');
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
        feature: opts.feature || 'repository',
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
