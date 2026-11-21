#!/usr/bin/env node
/**
 * SDD Forge v2 Lightweight PreToolUse Soft Guard.
 *
 * Single zero-dependency Node.js ESM implementation supporting all 4 hosts:
 *   --emit exit     Claude Code / Codex CLI (allow = exit 0; deny = stderr + exit 2)
 *   --emit copilot  GitHub Copilot CLI      (JSON permissionDecision on stdout, exit 0)
 *   --emit gemini   Gemini CLI BeforeTool   (JSON decision on stdout, exit 0)
 *
 * Three crisp responsibilities only:
 *   1. Kill switch (AGENT_STOP) — always fail-closed.
 *   2. Approval guard — block net increase of 'Approval: Approved' in tasks.md.
 *   3. Soft spec guard — protect approved specs/<feature>/*.md body edits
 *      according to sdd/guardrails.yaml (warn | confirm | strict; default confirm).
 *
 * Non-file-mutating tools (Bash/shell/run_shell_command/Read/Glob/Grep) pass
 * immediately with zero shell-parsing overhead. Out-of-band spec mutations are
 * deterministically caught by check-spec-drift.mjs in sdd-gate and CI.
 */
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import {
  appendDriftEvent,
  countDomainModelApprovals,
  countPrimaryApprovals,
  extractAmendmentEntries,
  findProjectRoot,
  isFeatureApproved,
  isSafeSpecEditOnly,
  loadGuardrailsConfig,
  matchProtectedSpecPath,
  normalizeNewlines,
  toPosixPath,
} from './guardrails-lib.mjs';

const FILE_TOOLS = new Set(['edit', 'write', 'multiedit', 'write_file', 'replace', 'create']);
const PASS_THROUGH_TOOLS = new Set([
  'bash',
  'shell',
  'exec_command',
  'exec',
  'run_shell_command',
  'read',
  'view',
  'glob',
  'grep',
  'task',
]);

const KILL_MSG =
  'SDD キルスイッチ: プロジェクトルートに AGENT_STOP が存在します。人間が削除するまでツール実行を停止します。\n' +
  '[EN] SDD kill switch: AGENT_STOP exists at project root. All tool use is paused until removed by a human.';

const APPROVAL_MSG =
  "SDD ソフトガード: エージェントは tasks.md の 'Approval: Approved' を増やせません。承認は人間が直接行ってください。\n" +
  "[EN] SDD soft guard: agents cannot add 'Approval: Approved' in tasks.md. Only a human may approve tasks.";

const DOMAIN_APPROVAL_MSG =
  "SDD ソフトガード: エージェントは domain/context-map.md の 'Domain-Model-Status: Approved' を増やせません。ドメインモデルの承認は人間が直接行ってください。\n" +
  "[EN] SDD soft guard: agents cannot add 'Domain-Model-Status: Approved' in domain/context-map.md. Only a human may approve the domain model.";

function buildSpecGuardMessage(mode, relPath, feature) {
  if (mode === 'strict') {
    return (
      `SDD ガードレール (strict): 承認済み仕様 '${relPath}' の直接編集は禁止されています。仕様変更は人間が行うか、SDD_ALLOW_SPEC_EDIT=1 で明示許可してください。\n` +
      `[EN] SDD guardrails (strict): direct edits to approved spec '${relPath}' are blocked. Ask a human to edit or explicitly set SDD_ALLOW_SPEC_EDIT=1.`
    );
  }
  return (
    `SDD ソフトガード (confirm): 承認済み仕様 '${relPath}' (feature: ${feature}) の本文変更を検知しました。\n` +
    `意図しない仕様改変（ゴールポスト移動）を防ぐため一時停止しています。次のいずれかを選んでください:\n` +
    `  1. 仕様を変える必要がない場合: 仕様は変更せず実装・テスト側を修正する\n` +
    `  2. 仕様変更が必要な場合: ユーザーと合意のうえ '${relPath}' の '## Spec Amendments' に理由を追記してから反映する（または SDD_ALLOW_SPEC_EDIT=1 で明示許可）\n` +
    `[EN] SDD soft guard (confirm): detected body edit to approved spec '${relPath}'. Confirm intent with the user, record the rationale under '## Spec Amendments' before or alongside the edit (or set SDD_ALLOW_SPEC_EDIT=1).`
  );
}

function buildSpecWarnMessage(relPath, feature) {
  return (
    `[SDD warn] 承認済み仕様 '${relPath}' (feature: ${feature}) が編集されました。後段の check-spec-drift が差分を検証します（意図的な変更なら '## Spec Amendments' に理由を記録してください）。`
  );
}

function buildSpecAmendedConfirmMessage(relPath, feature) {
  return (
    `[SDD confirm/amended] 承認済み仕様 '${relPath}' (feature: ${feature}) の変更に '## Spec Amendments' 記録を確認したため通過しました。後段の sdd-gate で改訂理由と差分を独立検証します。`
  );
}

function hasDocumentedSpecAmendment(oldContent, newContent, projectRoot, feature, relPath) {
  if (typeof newContent !== 'string') return false;
  const newEntries = extractAmendmentEntries(newContent);
  if (newEntries.length === 0) return false;
  const oldEntries = extractAmendmentEntries(oldContent || '');
  // Case 1: New non-placeholder amendment entry added in this same edit.
  if (newEntries.length > oldEntries.length) return true;
  // Case 2: Amendment entry was appended beforehand since baseline (or before baseline existed).
  const baselinePath = path.join(projectRoot, 'specs', feature, '.spec-baseline.json');
  if (fs.existsSync(baselinePath)) {
    try {
      const baseline = JSON.parse(fs.readFileSync(baselinePath, 'utf8'));
      const fileBaselineCount = baseline?.files?.[relPath]?.amendmentCount ?? 0;
      return newEntries.length > fileBaselineCount;
    } catch {
      return false;
    }
  }
  return newEntries.length > 0;
}

function normalizePayload(rawPayload, emitMode) {
  if (!rawPayload || typeof rawPayload !== 'object' || Array.isArray(rawPayload)) {
    return null;
  }

  // Native Copilot camelCase envelope
  if (emitMode === 'copilot' && ('toolName' in rawPayload || 'toolArgs' in rawPayload)) {
    const toolName = String(rawPayload.toolName || '').toLowerCase();
    let args = rawPayload.toolArgs;
    if (typeof args === 'string' && toolName !== 'apply_patch') {
      try {
        args = JSON.parse(args);
      } catch {
        return null;
      }
    }
    const cwd = typeof rawPayload.cwd === 'string' ? rawPayload.cwd : undefined;
    if (toolName === 'apply_patch') {
      return { tool_name: 'apply_patch', tool_input: { command: String(args || '') }, cwd };
    }
    if (toolName === 'create' && args && typeof args === 'object') {
      return {
        tool_name: 'create',
        tool_input: { file_path: args.path || '', content: args.file_text ?? '' },
        cwd,
      };
    }
    return {
      tool_name: toolName,
      tool_input: args && typeof args === 'object' ? args : {},
      cwd,
    };
  }

  return rawPayload;
}

function readDiskFile(absPath) {
  try {
    return fs.readFileSync(absPath, 'utf8');
  } catch {
    return '';
  }
}

function resolveFilePath(rawPath, projectRoot, cwd) {
  if (!rawPath) return '';
  return path.isAbsolute(rawPath) ? rawPath : path.resolve(cwd || projectRoot, rawPath);
}

function computeEditedContent(oldContent, toolInput) {
  if (typeof toolInput.content === 'string') {
    return toolInput.content;
  }
  if (Array.isArray(toolInput.edits)) {
    let current = normalizeNewlines(oldContent);
    let appliedAll = true;
    for (const edit of toolInput.edits) {
      const oldStr = normalizeNewlines(edit?.old_string ?? '');
      const newStr = normalizeNewlines(edit?.new_string ?? '');
      if (oldStr && current.includes(oldStr)) {
        current = current.replace(oldStr, newStr);
      } else if (!oldStr) {
        current = `${current}${newStr}`;
      } else {
        appliedAll = false;
      }
    }
    return appliedAll ? current : null;
  }
  if (typeof toolInput.new_string === 'string') {
    const oldStr = normalizeNewlines(toolInput.old_string ?? '');
    const newStr = normalizeNewlines(toolInput.new_string);
    const current = normalizeNewlines(oldContent);
    if (oldStr && current.includes(oldStr)) {
      return current.replace(oldStr, newStr);
    }
    if (!oldStr) {
      return `${current}${newStr}`;
    }
    return null;
  }
  return null;
}

/**
 * Parse Codex / Copilot apply_patch text into per-file mutation descriptors.
 */
function parsePatchSections(patchText) {
  const sections = [];
  let current = null;
  for (const line of normalizeNewlines(patchText).split('\n')) {
    const header = line.match(/^\*\*\* (Update File|Add File|Delete File|Move to): (.+)$/);
    if (header) {
      current = { kind: header[1], filePath: header[2].trim(), lines: [] };
      sections.push(current);
    } else if (current && line !== '*** End Patch' && line !== '*** Begin Patch') {
      current.lines.push(line);
    }
  }
  return sections;
}

function applyPatchSectionToContent(oldContent, section) {
  if (section.kind === 'Delete File') return '';
  if (section.kind === 'Add File') {
    return section.lines
      .filter((l) => l.startsWith('+'))
      .map((l) => l.slice(1))
      .join('\n');
  }

  // Group into hunks delimited by @@
  const hunks = [];
  let currentHunk = null;
  for (const line of section.lines) {
    if (line.startsWith('@@')) {
      currentHunk = [];
      hunks.push(currentHunk);
    } else if (line.startsWith(' ') || line.startsWith('+') || line.startsWith('-')) {
      if (!currentHunk) {
        currentHunk = [];
        hunks.push(currentHunk);
      }
      currentHunk.push(line);
    }
  }

  let result = normalizeNewlines(oldContent);
  for (const hunk of hunks) {
    const beforeBlock = hunk
      .filter((l) => l.startsWith(' ') || l.startsWith('-'))
      .map((l) => l.slice(1))
      .join('\n');
    const afterBlock = hunk
      .filter((l) => l.startsWith(' ') || l.startsWith('+'))
      .map((l) => l.slice(1))
      .join('\n');
    if (beforeBlock && result.includes(beforeBlock)) {
      result = result.replace(beforeBlock, afterBlock);
    } else if (!beforeBlock) {
      result = result ? `${result}\n${afterBlock}` : afterBlock;
    } else {
      return null;
    }
  }
  return result;
}

function evaluateSingleMutation({ filePath, oldContent, newContent, fallbackOldSnippet, fallbackNewSnippet, projectRoot, config, cwd, env }) {
  const normalizedTarget = toPosixPath(filePath);
  const isTasksMd = normalizedTarget.toLowerCase().endsWith('tasks.md');
  const isDomainContextMap = normalizedTarget.toLowerCase().endsWith('domain/context-map.md');

  // Check 2: Approval guard (never allow net increase of Approval: Approved in tasks.md)
  if (isTasksMd) {
    const beforeCount = newContent !== null ? countPrimaryApprovals(oldContent) : countPrimaryApprovals(fallbackOldSnippet);
    const afterCount = newContent !== null ? countPrimaryApprovals(newContent) : countPrimaryApprovals(fallbackNewSnippet);
    if (afterCount > beforeCount) {
      return { decision: 'deny', reason: APPROVAL_MSG, warning: null };
    }
  }

  // Check 2b: DDD domain-model approval guard (human-only Domain-Model-Status: Approved)
  if (isDomainContextMap) {
    const beforeCount =
      newContent !== null ? countDomainModelApprovals(oldContent) : countDomainModelApprovals(fallbackOldSnippet);
    const afterCount =
      newContent !== null ? countDomainModelApprovals(newContent) : countDomainModelApprovals(fallbackNewSnippet);
    if (afterCount > beforeCount) {
      return { decision: 'deny', reason: DOMAIN_APPROVAL_MSG, warning: null };
    }
  }

  // Check 3: Soft spec guard on approved features
  const specMatch = matchProtectedSpecPath(filePath, projectRoot, config, cwd);
  if (!specMatch || !specMatch.feature || !isFeatureApproved(projectRoot, specMatch.feature)) {
    return { decision: 'allow', reason: null, warning: null };
  }

  const allowAmendments = config.spec_guard.allow_amendment_section;
  const safeEdit =
    newContent !== null
      ? isSafeSpecEditOnly(oldContent, newContent, specMatch.fileName, allowAmendments)
      : isSafeSpecEditOnly(fallbackOldSnippet, fallbackNewSnippet, specMatch.fileName, allowAmendments);

  if (safeEdit) {
    return { decision: 'allow', reason: null, warning: null };
  }

  const mode = config.spec_guard.mode;
  const explicitOverride = env.SDD_ALLOW_SPEC_EDIT === '1' || env.SDD_ALLOW_SPEC_EDIT === 'true';

  if (explicitOverride) {
    appendDriftEvent(projectRoot, {
      action: 'allow_override',
      mode,
      feature: specMatch.feature,
      file: specMatch.relPath,
    });
    return { decision: 'allow', reason: null, warning: null };
  }

  if (mode === 'warn') {
    const warning = buildSpecWarnMessage(specMatch.relPath, specMatch.feature);
    appendDriftEvent(projectRoot, {
      action: 'warn_allow',
      mode,
      feature: specMatch.feature,
      file: specMatch.relPath,
    });
    return { decision: 'allow', reason: null, warning };
  }

  if (
    mode === 'confirm' &&
    allowAmendments &&
    hasDocumentedSpecAmendment(oldContent, newContent, projectRoot, specMatch.feature, specMatch.relPath)
  ) {
    const warning = buildSpecAmendedConfirmMessage(specMatch.relPath, specMatch.feature);
    appendDriftEvent(projectRoot, {
      action: 'confirm_amended_allow',
      mode,
      feature: specMatch.feature,
      file: specMatch.relPath,
    });
    return { decision: 'allow', reason: null, warning };
  }

  appendDriftEvent(projectRoot, {
    action: mode === 'strict' ? 'strict_deny' : 'confirm_soft_deny',
    mode,
    feature: specMatch.feature,
    file: specMatch.relPath,
  });
  return {
    decision: 'deny',
    reason: buildSpecGuardMessage(mode, specMatch.relPath, specMatch.feature),
    warning: null,
  };
}

export function evaluateHookPayload(rawPayload, options = {}) {
  const emitMode = options.emitMode || 'exit';
  const env = options.env || process.env;
  const cwd = options.cwd || rawPayload?.cwd || rawPayload?.tool_input?.cwd || process.cwd();
  const projectRoot = options.projectRoot || findProjectRoot(cwd);

  // Check 1: Kill switch (AGENT_STOP) — always fail-closed before payload parsing.
  if (fs.existsSync(path.join(projectRoot, 'AGENT_STOP')) || fs.existsSync(path.join(cwd, 'AGENT_STOP'))) {
    return { decision: 'deny', reason: KILL_MSG, warning: null };
  }

  const payload = normalizePayload(rawPayload, emitMode);
  if (!payload || typeof payload.tool_name !== 'string') {
    return { decision: 'allow', reason: null, warning: null };
  }

  const toolName = payload.tool_name.toLowerCase();
  const toolInput = payload.tool_input && typeof payload.tool_input === 'object' ? payload.tool_input : {};
  const effectiveCwd = payload.cwd || cwd;

  // Fast path: non-file-mutating tools pass immediately without shell parsing.
  if (PASS_THROUGH_TOOLS.has(toolName)) {
    return { decision: 'allow', reason: null, warning: null };
  }

  const config = loadGuardrailsConfig(projectRoot);

  // apply_patch handling (Codex / Copilot)
  if (toolName === 'apply_patch') {
    const patchText = String(toolInput.command || '');
    const sections = parsePatchSections(patchText);
    let combinedWarning = null;
    for (const section of sections) {
      const absPath = resolveFilePath(section.filePath, projectRoot, effectiveCwd);
      const oldContent = readDiskFile(absPath);
      const newContent = applyPatchSectionToContent(oldContent, section);
      const fallbackOld = section.lines
        .filter((l) => l.startsWith('-'))
        .map((l) => l.slice(1))
        .join('\n');
      const fallbackNew = section.lines
        .filter((l) => l.startsWith('+'))
        .map((l) => l.slice(1))
        .join('\n');
      const res = evaluateSingleMutation({
        filePath: absPath,
        oldContent,
        newContent,
        fallbackOldSnippet: fallbackOld,
        fallbackNewSnippet: fallbackNew,
        projectRoot,
        config,
        cwd: effectiveCwd,
        env,
      });
      if (res.decision === 'deny') return res;
      if (res.warning) combinedWarning = combinedWarning ? `${combinedWarning}\n${res.warning}` : res.warning;
    }
    return { decision: 'allow', reason: null, warning: combinedWarning };
  }

  // Direct file tools (Claude Edit/Write/MultiEdit, Copilot create, Gemini write_file/replace)
  if (FILE_TOOLS.has(toolName)) {
    const rawPath = toolInput.file_path || toolInput.path || '';
    if (!rawPath) return { decision: 'allow', reason: null, warning: null };
    const absPath = resolveFilePath(rawPath, projectRoot, effectiveCwd);
    const oldContent = readDiskFile(absPath);
    const newContent = computeEditedContent(oldContent, toolInput);
    const fallbackOld = Array.isArray(toolInput.edits)
      ? toolInput.edits.map((e) => e?.old_string || '').join('\n')
      : String(toolInput.old_string || '');
    const fallbackNew = Array.isArray(toolInput.edits)
      ? toolInput.edits.map((e) => e?.new_string || '').join('\n')
      : String(toolInput.new_string ?? toolInput.content ?? '');

    return evaluateSingleMutation({
      filePath: absPath,
      oldContent,
      newContent,
      fallbackOldSnippet: fallbackOld,
      fallbackNewSnippet: fallbackNew,
      projectRoot,
      config,
      cwd: effectiveCwd,
      env,
    });
  }

  return { decision: 'allow', reason: null, warning: null };
}

function parseArgs(argv) {
  let emit = 'exit';
  let projectRoot = null;
  for (let i = 0; i < argv.length; i += 1) {
    if (argv[i] === '--emit' && argv[i + 1]) {
      emit = argv[i + 1];
      i += 1;
    } else if (argv[i].startsWith('--emit=')) {
      emit = argv[i].slice('--emit='.length);
    } else if (argv[i] === '--root' && argv[i + 1]) {
      projectRoot = argv[i + 1];
      i += 1;
    }
  }
  return {
    emit: emit === 'copilot' || emit === 'gemini' ? emit : 'exit',
    projectRoot,
  };
}

function emitDecision(result, emitMode) {
  if (emitMode === 'copilot') {
    const out = { permissionDecision: result.decision };
    if (result.decision === 'deny' && result.reason) {
      out.permissionDecisionReason = result.reason;
    }
    process.stdout.write(JSON.stringify(out));
    process.exit(0);
  }
  if (emitMode === 'gemini') {
    const out = { decision: result.decision };
    if (result.decision === 'deny' && result.reason) {
      out.reason = result.reason;
    }
    process.stdout.write(JSON.stringify(out));
    process.exit(0);
  }
  if (result.decision === 'deny') {
    if (result.reason) process.stderr.write(`${result.reason}\n`);
    process.exit(2);
  }
  if (result.warning) {
    process.stderr.write(`${result.warning}\n`);
  }
  process.exit(0);
}

async function readStdin() {
  if (typeof process.env.PAYLOAD === 'string') return process.env.PAYLOAD;
  if (process.stdin.isTTY) return '';
  let data = '';
  for await (const chunk of process.stdin) {
    data += chunk;
  }
  return data;
}

async function main() {
  const { emit, projectRoot } = parseArgs(process.argv.slice(2));
  const raw = await readStdin();

  let parsed = {};
  if (raw.trim()) {
    try {
      parsed = JSON.parse(raw);
    } catch {
      // Malformed JSON: still run kill switch check, otherwise soft-allow rather than bricking DX.
      parsed = {};
    }
  }

  const result = evaluateHookPayload(parsed, {
    emitMode: emit,
    projectRoot: projectRoot || undefined,
  });
  emitDecision(result, emit);
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  main();
}
