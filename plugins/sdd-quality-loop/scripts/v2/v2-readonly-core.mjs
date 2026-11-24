#!/usr/bin/env node
/**
 * Pure Read-Only SSOT Core Engine for SDD Forge v2.1 (ADR-0052 + Software Factory).
 *
 * Strictly ZERO `node:fs`, ZERO `process.env`, ZERO `process.argv`, ZERO write APIs.
 * Every filesystem read flows through the caller-injected `io` facade:
 *   - Local CLI scripts pass `createFsReadonlyIo(root)` (root-contained fs reads).
 *   - `sdd-forge-mcp` v2 passes `createGuardedIo(root)` (path-guard allowlist/denylist/symlink/2 MiB cap).
 */
import path from 'node:path';
import {
  assertValidFeatureName,
  canonicalSpecContractText,
  countPrimaryApprovals,
  extractAmendmentEntries,
  extractSpecIdentifiers,
  globToRegExp,
  matchProtectedSpecRelPath,
  normalizeGuardrailsConfig,
  normalizeNewlines,
  normalizeRelPath,
  parseSimpleYaml,
  sanitizeRelPath,
  sha256Text,
  splitSpecAmendments,
  stripYamlComment,
  VALID_MODES,
  VALID_PRE_IMPL,
  VALID_RISK_TIERS,
} from './v2-pure-lib.mjs';

const CONFIRMED_STATUS_RE = /^(?:confirmed|resolved|closed|確定)$/i;
const PLACEHOLDER_CELL_RE = /^<[^<>]+>$/;
const SEPARATOR_CELL_RE = /^:?-+:?$/;
const MAX_SKILL_DESCRIPTION_CHARS = 1024;
const CONTROL_CHAR_RE = /[\x00-\x08\x0B\x0C\x0E-\x1F]/;
const NON_ASCII_RE = /[^\x00-\x7F]/;
const IGNORED_DIRS = new Set(['.git', 'node_modules', 'dist', 'build', '.next', '__pycache__', '.venv']);

export const NON_CHECKS = Object.freeze([
  '仕様・設計・ドメインモデルの意味的妥当性や文書間の内容矛盾',
  'テストケースの網羅性・プロダクションコードの論理バグや性能',
  'クラウド環境（AWS/Azure）や本番データベースの実状態・認証有効性',
  '外部ホスト CLI（Claude Code / Codex / Copilot / Antigravity / Gemini）内部の非公開挙動',
]);

/**
 * Canonical 8 common design review perspectives (freee Software Factory p.33-35).
 * Product-specific perspectives in `sdd/knowledge/review-perspectives.yaml` are merged on top.
 */
export const COMMON_REVIEW_PERSPECTIVES = Object.freeze([
  {
    id: 'C01',
    area: '設計方針',
    perspective: '方針整合と非自明判断の根拠',
    humanQuestion: '要件の大枠に沿っており、非自明な設計判断（採らなかった案を含む）に納得感があるか？',
    defaultDisposition: '軽く確認',
  },
  {
    id: 'C02',
    area: 'データモデル',
    perspective: '粒度・集約境界・不変条件',
    humanQuestion: 'データ構造の境界・不変条件を守る場所がドメインの責務と合っているか？',
    defaultDisposition: '採用',
  },
  {
    id: 'C03',
    area: 'API I/F',
    perspective: 'CRUD 外の契約・エラー応答・認可',
    humanQuestion: '外部契約（破壊的変更・エラーコード・認可条件）が呼び出し元と矛盾しないか？',
    defaultDisposition: '軽く確認',
  },
  {
    id: 'C04',
    area: '状態遷移',
    perspective: '異常ルート・競合・順序性',
    humanQuestion: '異常系・並列実行・再実行時の状態遷移に破綻やデッドロックがないか？',
    defaultDisposition: '採用',
  },
  {
    id: 'C05',
    area: 'システム間連携',
    perspective: '外部連携シーケンス・不可逆操作点',
    humanQuestion: '送信・確定・課金・外部書込など戻せない境界のロールバック／冪等性が担保されているか？',
    defaultDisposition: '軽く確認',
  },
  {
    id: 'C06',
    area: '業務ルール',
    perspective: 'ドメイン不変条件・境界値（ゼロ/上限/端数）',
    humanQuestion: '業務ルール・法令・境界値・過去実績の扱いが事業意図と一致しているか？',
    defaultDisposition: '採用',
  },
  {
    id: 'C07',
    area: '要求との対応',
    perspective: 'REQ↔AC↔Task 整合と先回り設計の抑止',
    humanQuestion: '全 REQ/AC が漏れなくタスクへ落ち、要件外の過剰設計が混入していないか？',
    defaultDisposition: '機械検証',
  },
  {
    id: 'C08',
    area: '非機能面',
    perspective: '権限・性能・監査・切戻し',
    humanQuestion: '認証/認可・秘密情報・性能劣化・障害時の切戻し手順が運用要件を満たすか？',
    defaultDisposition: '採用',
  },
]);

export function loadGuardrailsConfigFromIo(io) {
  let parsed = null;
  let sourcePath = null;
  try {
    const jsonRaw = io.readText('sdd/guardrails.json');
    if (jsonRaw !== null) {
      parsed = JSON.parse(jsonRaw);
      sourcePath = 'sdd/guardrails.json';
    } else {
      const yamlRaw = io.readText('sdd/guardrails.yaml');
      if (yamlRaw !== null) {
        parsed = parseSimpleYaml(yamlRaw);
        sourcePath = 'sdd/guardrails.yaml';
      }
    }
  } catch {
    parsed = null;
  }
  return normalizeGuardrailsConfig(parsed, sourcePath);
}

export function stripFencedCodeBlocks(text) {
  const lines = normalizeNewlines(text || '').split('\n');
  const out = [];
  let inFence = false;
  let fenceChar = '';
  for (const line of lines) {
    const m = line.match(/^[ \t]*(`{3,}|~{3,})/);
    if (m) {
      if (!inFence) {
        inFence = true;
        fenceChar = m[1][0];
      } else if (m[1][0] === fenceChar) {
        inFence = false;
        fenceChar = '';
      }
      continue;
    }
    if (!inFence) out.push(line);
  }
  return out.join('\n');
}

export function splitMarkdownTableRow(line) {
  let trimmed = String(line || '').trim();
  if (!trimmed.startsWith('|')) return null;
  if (trimmed.startsWith('|')) trimmed = trimmed.slice(1);
  if (trimmed.endsWith('|') && !trimmed.endsWith('\\|')) trimmed = trimmed.slice(0, -1);

  const cells = [];
  let current = '';
  let inBacktick = false;
  for (let i = 0; i < trimmed.length; i += 1) {
    const ch = trimmed[i];
    if (ch === '\\' && trimmed[i + 1] === '|' && !inBacktick) {
      current += '|';
      i += 1;
      continue;
    }
    if (ch === '`') {
      inBacktick = !inBacktick;
      current += ch;
      continue;
    }
    if (ch === '|' && !inBacktick) {
      cells.push(current.trim());
      current = '';
      continue;
    }
    current += ch;
  }
  cells.push(current.trim());
  return cells;
}

function unwrapMarkdownInline(text) {
  return String(text || '')
    .trim()
    .replace(/^[`*_]+|[`*_]+$/g, '')
    .trim();
}

export function isOpenQuestionConfirmed(status) {
  const clean = unwrapMarkdownInline(status);
  return CONFIRMED_STATUS_RE.test(clean);
}

/**
 * Parses OQ-NNN rows while preserving original 1-based line numbers (F-3).
 */
export function parseOpenQuestions(markdownText, sourceFile = null) {
  const normalized = normalizeNewlines(markdownText || '');
  const lines = normalized.split('\n');
  const items = [];
  let inFence = false;
  let fenceChar = '';
  let inAmendments = false;
  let amendmentLevel = 0;

  for (let i = 0; i < lines.length; i += 1) {
    const line = lines[i];
    const fenceMatch = line.match(/^[ \t]*(`{3,}|~{3,})/);
    if (fenceMatch) {
      if (!inFence) {
        inFence = true;
        fenceChar = fenceMatch[1][0];
      } else if (fenceMatch[1][0] === fenceChar) {
        inFence = false;
        fenceChar = '';
      }
      continue;
    }
    if (inFence) continue;

    const amendMatch = line.match(/^(#{2,3})[ \t]+Spec Amendments[ \t]*$/i);
    if (amendMatch) {
      inAmendments = true;
      amendmentLevel = amendMatch[1].length;
      continue;
    }
    if (inAmendments) {
      const nextHeading = line.match(/^(#{1,3})[ \t]+\S/);
      if (nextHeading && nextHeading[1].length <= amendmentLevel) {
        inAmendments = false;
      } else {
        continue;
      }
    }

    const cells = splitMarkdownTableRow(line);
    if (!cells || cells.length < 6) continue;
    const rawId = unwrapMarkdownInline(cells[0]);
    if (!/^OQ-\d+$/i.test(rawId)) continue;
    if (PLACEHOLDER_CELL_RE.test(cells[2])) continue;

    const status = unwrapMarkdownInline(cells[5]) || 'Provisional';
    const rawImpacted = cells[6] || '';
    const impactedMatches = rawImpacted.match(/\bT-[A-Za-z0-9._-]+\b/gi) || [];
    const impactedTasks = [...new Set(impactedMatches.map((t) => t.toUpperCase()))];
    const lineNumber = i + 1;

    items.push({
      id: rawId.toUpperCase(),
      category: unwrapMarkdownInline(cells[1]) || '事業判断',
      fact: cells[2] || '',
      reason: cells[3] || '',
      question: cells[4] || '',
      status,
      confirmed: isOpenQuestionConfirmed(status),
      impactedTasks,
      sourceFile,
      sourceLine: lineNumber,
      sourceRef: sourceFile ? `${sourceFile}:L${lineNumber}` : null,
    });
  }
  return items;
}

export function mergeOpenQuestions(...lists) {
  const byId = new Map();
  for (const list of lists) {
    for (const q of list || []) {
      const existing = byId.get(q.id);
      if (!existing) {
        byId.set(q.id, { ...q, impactedTasks: [...q.impactedTasks] });
      } else {
        const confirmed = existing.confirmed && q.confirmed;
        const impactedTasks = [...new Set([...existing.impactedTasks, ...q.impactedTasks])];
        byId.set(q.id, {
          ...existing,
          status: confirmed ? existing.status : (existing.confirmed ? q.status : existing.status),
          confirmed,
          impactedTasks,
        });
      }
    }
  }
  return [...byId.values()];
}

export function parseAlternativesRejected(designText, sourceFile = null) {
  const normalized = normalizeNewlines(designText || '');
  const lines = normalized.split('\n');
  const items = [];
  let inFence = false;
  let fenceChar = '';
  let inSection = false;

  for (let i = 0; i < lines.length; i += 1) {
    const line = lines[i];
    const fenceMatch = line.match(/^[ \t]*(`{3,}|~{3,})/);
    if (fenceMatch) {
      if (!inFence) {
        inFence = true;
        fenceChar = fenceMatch[1][0];
      } else if (fenceMatch[1][0] === fenceChar) {
        inFence = false;
        fenceChar = '';
      }
      continue;
    }
    if (inFence) continue;

    if (/^##[ \t]+.*(?:採らなかった設計|Alternatives Rejected).*$/i.test(line)) {
      inSection = true;
      continue;
    }
    if (inSection && /^##[ \t]+\S/.test(line)) {
      break;
    }
    if (!inSection) continue;

    const cells = splitMarkdownTableRow(line);
    if (!cells || cells.length < 3) continue;
    const first = unwrapMarkdownInline(cells[0]);
    if (/^(?:候補案|Option|Alternative)$/i.test(first) || SEPARATOR_CELL_RE.test(first)) continue;
    if (PLACEHOLDER_CELL_RE.test(first) || /^（?該当なし）?$/.test(first)) continue;
    const lineNumber = i + 1;
    items.push({
      option: cells[0],
      reason: cells[1],
      revisitWhen: cells[2],
      sourceFile,
      sourceLine: lineNumber,
      sourceRef: sourceFile ? `${sourceFile}:L${lineNumber}` : null,
    });
  }
  return items;
}

function extractTaskBlockers(taskBlock) {
  const blockersMatch = /^###[ \t]+Blockers[ \t]*$/im.exec(taskBlock);
  if (!blockersMatch) return [];
  const rest = taskBlock.slice(blockersMatch.index + blockersMatch[0].length);
  const nextSub = /^###[ \t]+\S/m.exec(rest);
  const section = nextSub ? rest.slice(0, nextSub.index) : rest;
  const ids = section.match(/\bT-[A-Za-z0-9._-]+\b/gi) || [];
  return [...new Set(ids.map((id) => id.toUpperCase()))];
}

const BARE_BLOCKER_LINE_RE = /^T-[A-Za-z0-9]+(?:[_-][A-Za-z0-9]+)*(?:\s*[,、]\s*T-[A-Za-z0-9]+(?:[_-][A-Za-z0-9]+)*)*$/i;

/**
 * Blocker IDs the author declared as dependencies: a line (optionally a list
 * item) holding only task IDs separated by commas. IDs inside prose, ranges
 * (T-002..T-005), file names (T-001.md) and placeholders are mentions, not
 * declarations, and are never checked for existence or self-reference (#817).
 */
function extractDeclaredBlockers(taskBlock) {
  const blockersMatch = /^###[ \t]+Blockers[ \t]*$/im.exec(taskBlock);
  if (!blockersMatch) return [];
  const rest = taskBlock.slice(blockersMatch.index + blockersMatch[0].length);
  const nextSub = /^###[ \t]+\S/m.exec(rest);
  const section = (nextSub ? rest.slice(0, nextSub.index) : rest).replace(/<!--[\s\S]*?-->/g, '');
  const ids = [];
  for (const raw of section.split('\n')) {
    const line = raw.trim().replace(/^[-*+][ \t]+/, '').trim();
    if (!BARE_BLOCKER_LINE_RE.test(line)) continue;
    for (const id of line.split(/\s*[,、]\s*/)) {
      if (/^T-(?:X+|N+)$/i.test(id)) continue; // template placeholder, not a task
      ids.push(id.toUpperCase());
    }
  }
  return [...new Set(ids)];
}

export function extractScopePaths(taskBlock) {
  const scopeMatch = /^###[ \t]+Scope[ \t]*$/im.exec(taskBlock);
  if (!scopeMatch) return [];
  const rest = taskBlock.slice(scopeMatch.index + scopeMatch[0].length);
  const nextSub = /^###[ \t]+\S/m.exec(rest);
  const section = nextSub ? rest.slice(0, nextSub.index) : rest;
  const paths = [];
  for (const line of section.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed.startsWith('-')) continue;
    const backtickMatches = [...trimmed.matchAll(/`([^`]+)`/g)].map((m) => m[1]);
    const tokens = backtickMatches.length > 0 ? backtickMatches : bareScopeTokens(trimmed.replace(/^-\s*/, ''));
    for (const token of tokens) paths.push(...expandScopeToken(token));
  }
  return [...new Set(paths)];
}

const SCOPE_PLACEHOLDER_RE = /^(?:none|n\/a|tbd|todo|-+|<[^<>]+>)$/i;
const SCOPE_PATH_CHARS_RE = /^[A-Za-z0-9._\-/*?{},[\]@+~]+$/;

// A bare Scope bullet names a path either as its only word, or as words that
// look like file paths inside prose ("src/a.ts を更新", "a.ts / b.ts"): a file
// extension, a trailing slash, a glob or a brace list. Notes in parentheses
// are dropped. Prose with no path names nothing, so the task's Scope is
// unknown (#816).
function bareScopeTokens(text) {
  const words = stripScopeNote(text).split(/\s+/).filter(Boolean).map(stripScopeNote);
  if (words.length === 1) {
    return SCOPE_PATH_CHARS_RE.test(words[0]) && !SCOPE_PLACEHOLDER_RE.test(words[0]) ? words : [];
  }
  return words.filter(
    (w) => SCOPE_PATH_CHARS_RE.test(w) && /\.[A-Za-z0-9]+$|\/$|[*?]|\{[^{}]*,[^{}]*\}/.test(w),
  );
}

// "src/a.ts(note)", "src/a.ts （note）", "src/a.ts:" and an unclosed note that
// continues on the next line all name src/a.ts.
function stripScopeNote(token) {
  return String(token)
    .replace(/\([^()]*\)|（[^（）]*）/g, ' ')
    .replace(/[(（].*$/, '')
    .trim()
    .replace(/[:,;、。]+$/, '');
}

// One level of brace alternatives per group: "src/{a,b}.ts" -> src/a.ts, src/b.ts.
function expandScopeToken(token) {
  const cleaned = stripScopeNote(String(token).trim());
  if (!cleaned || SCOPE_PLACEHOLDER_RE.test(cleaned)) return [];
  const brace = /\{([^{}]*,[^{}]*)\}/.exec(cleaned);
  if (!brace) {
    const normalized = normalizeRelPath(cleaned);
    return normalized ? [normalized] : [];
  }
  const head = cleaned.slice(0, brace.index);
  const tail = cleaned.slice(brace.index + brace[0].length);
  return brace[1].split(',').flatMap((alt) => expandScopeToken(`${head}${alt}${tail}`));
}

// The real location of a Scope entry, so two spellings of one file (a
// symlinked directory, ./, ..) compare equal. The deepest existing ancestor
// is resolved, so files that do not exist yet are covered too. Without
// io.canonicalRelPath (other hosts), the written path is used.
function canonicalScopeEntry(io, entry) {
  if (!io || typeof io.canonicalRelPath !== 'function') return entry;
  const parts = entry.split('/');
  const firstWild = parts.findIndex((p) => /[*?]/.test(p));
  const staticLen = firstWild === -1 ? parts.length : firstWild;
  for (let n = staticLen; n > 0; n -= 1) {
    const real = io.canonicalRelPath(parts.slice(0, n).join('/'));
    if (real !== null && real !== undefined) {
      return [real, ...parts.slice(n)].filter((p) => p !== '').join('/') || entry;
    }
  }
  return entry;
}

export function normalizeRiskTier(raw, fallback = 'standard') {
  const value = String(raw || '').trim().toLowerCase();
  if (value === 'high' || value === 'critical') return 'high';
  if (value === 'standard' || value === 'medium') return 'standard';
  if (value === 'low') return 'low';
  return fallback;
}

export function parseTasksSummary(tasksText) {
  const { beforeAmendments, afterAmendments } = splitSpecAmendments(tasksText || '');
  const body = stripFencedCodeBlocks(afterAmendments ? `${beforeAmendments}\n\n${afterAmendments}` : beforeAmendments);
  const tasks = [];
  const h2Re = /^##[ \t]+(.+)$/gm;
  const headings = [...body.matchAll(h2Re)];

  for (let i = 0; i < headings.length; i += 1) {
    const h = headings[i];
    const titleLine = h[1].trim();
    const taskMatch = titleLine.match(/^(T-[A-Za-z0-9._-]+)(?:[ \t]+(.*))?$/);
    if (!taskMatch) continue;

    const start = h.index + h[0].length;
    const end = i + 1 < headings.length ? headings[i + 1].index : body.length;
    const block = body.slice(start, end);

    const approval = (block.match(/^[ \t]*Approval:[ \t]*(.+)$/m) || [])[1]?.trim() || 'Draft';
    const status = (block.match(/^[ \t]*Status:[ \t]*(.+)$/m) || [])[1]?.trim() || 'Planned';
    const risk = normalizeRiskTier((block.match(/^[ \t]*Risk:[ \t]*(.+)$/m) || [])[1], 'standard');
    const acRefs = [...new Set((block.match(/\bAC-\d+\b/gi) || []).map((id) => id.toUpperCase()))];
    const taskId = taskMatch[1].toUpperCase();
    const blockers = extractTaskBlockers(block).filter((b) => b !== taskId);
    const declaredBlockers = extractDeclaredBlockers(block);
    const selfBlocked = declaredBlockers.includes(taskId);

    tasks.push({
      selfBlocked,
      declaredBlockers: declaredBlockers.filter((b) => b !== taskId),
      id: taskId,
      title: (taskMatch[2] || '').trim(),
      approval,
      status,
      risk,
      acRefs,
      blockers,
      block,
    });
  }
  return tasks;
}

export function detectDomains(combinedText) {
  const text = String(combinedText || '');
  const domains = new Set();

  if (
    /(?:\.sqlproj\b|\.sql\b|\b(?:PostgreSQL|MySQL|SQL Server|Azure SQL|Flyway|DACPAC|DDL|RLS)\b|\bdb\/migrations?\b|\bschema\s+migration\b)/i.test(
      text,
    )
  ) {
    domains.add('SQL');
  }
  if (
    /(?:\b(?:AWS|CDK|CloudFormation|sdd-aws-cloud|CloudWatch|Lambda|DynamoDB|RDS|Aurora)\b|\bS3\s+bucket\b|\bAWS\s+IAM\b|\binfra\/aws\b)/i.test(
      text,
    )
  ) {
    domains.add('AWS');
  }
  if (
    /(?:\b(?:Azure|Bicep|sdd-azure-cloud|Azure Monitor|AKS|App Service|Key Vault)\b|\bARM\s+template\b|\binfra\/azure\b)/i.test(
      text,
    )
  ) {
    domains.add('Azure');
  }
  if (/(?:\bTerraform\b|\.tf\b)/i.test(text) && !domains.has('AWS') && !domains.has('Azure')) {
    domains.add('Cloud');
  }
  if (
    /(?:(?:^|[\s`'"(])domain\/|\b(?:Bounded-Context|domain-contract\.json|sdd-domain|Aggregate\s+Root)\b|集約(?:の|を|境界))/i.test(
      text,
    )
  ) {
    domains.add('DDD');
  }
  if (
    domains.size === 0 ||
    /(?:\b(?:src\/|app\/|lib\/|api\/|components\/|UI|API|CLI|SDK|Node\.js|TypeScript|JavaScript|Python|Go|Rust|Java|React|Next\.js)\b|アプリ|フロントエンド|バックエンド)/i.test(
      text,
    )
  ) {
    domains.add('Software');
  }
  return [...domains];
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

function globStaticDir(glob) {
  const parts = glob.split('/');
  const staticParts = [];
  for (const part of parts) {
    if (/[*?]/.test(part)) break;
    staticParts.push(part);
  }
  return staticParts.join('/');
}

function scopeEntriesOverlap(a, b) {
  const na = normalizeRelPath(a);
  const nb = normalizeRelPath(b);
  if (!na || !nb) return false;
  if (na === nb) return true;
  const aWild = /[*?]/.test(na);
  const bWild = /[*?]/.test(nb);
  if (!aWild && !bWild) {
    return na.startsWith(`${nb}/`) || nb.startsWith(`${na}/`);
  }
  if (scopeMatchesFile(na, nb) || scopeMatchesFile(nb, na)) {
    return true;
  }
  if (aWild && bWild) {
    const dirA = globStaticDir(na);
    const dirB = globStaticDir(nb);
    if (dirA === dirB) return true;
    if (dirA && dirB && (dirA.startsWith(`${dirB}/`) || dirB.startsWith(`${dirA}/`))) return true;
    if ((!dirA && na.includes('**')) || (!dirB && nb.includes('**'))) return true;
  }
  return false;
}

function isTestPath(relPath) {
  const lower = normalizeRelPath(relPath).toLowerCase();
  return (
    lower.startsWith('tests/') ||
    lower.startsWith('test/') ||
    lower.includes('/tests/') ||
    lower.includes('/__tests__/') ||
    /(?:\.test|\.spec|_test|\.tests)\.[a-z0-9]+$/i.test(lower)
  );
}

const APPROVAL_FIELD_RE = /^[ \t]*Approval:[ \t]*.*$/gm;

/**
 * Baseline fields that let a later human approval of another task leave
 * tasks.md unchanged for Spec Drift (#818): a contract hash with every
 * `Approval:` value normalized, and each task's approval at recording time so
 * a revoked approval is still reported. Returns null for other files.
 */
export function taskApprovalBaseline(rawText, fileName) {
  if (String(fileName || '').toLowerCase() !== 'tasks.md') return null;
  const contract = canonicalSpecContractText(rawText, fileName).replace(APPROVAL_FIELD_RE, 'Approval: <NORMALIZED>');
  const taskApprovals = {};
  for (const t of parseTasksSummary(rawText)) taskApprovals[t.id] = t.approval;
  return { approvalContractSha256: sha256Text(contract), taskApprovals };
}

const isApproved = (value) => /^Approved\b/.test(String(value || ''));

/**
 * Pure read-only Spec Drift check (C-1 / C-2 safe: validates every baseline.files key).
 */
export function checkSpecDriftCore(io, { feature, baselineRelPath = null, config = null }) {
  assertValidFeatureName(feature);
  const resolvedBaselineRel = sanitizeRelPath(baselineRelPath || `specs/${feature}/.spec-baseline.json`);
  if (!resolvedBaselineRel) {
    throw new Error('Invalid baseline path.');
  }

  const rawBaseline = io.readText(resolvedBaselineRel);
  if (rawBaseline === null) {
    throw new Error(`Baseline file not found: ${resolvedBaselineRel}`);
  }

  const baseline = JSON.parse(rawBaseline);
  if (!baseline || typeof baseline !== 'object' || Array.isArray(baseline)) {
    throw new Error(`Invalid baseline JSON structure in ${resolvedBaselineRel}`);
  }
  const effectiveConfig = config || loadGuardrailsConfigFromIo(io);
  const featureDirRel = `specs/${feature}`;

  const changedFiles = [];
  const deletedFiles = [];
  const addedFiles = [];
  const removedIdentifiers = [];
  const modifiedIdentifiers = [];
  const addedIdentifiers = [];
  const allCurrentAmendments = [];
  const revokedApprovals = [];
  const newlyApprovedTasks = [];

  for (const [rawRelPath, baseInfo] of Object.entries(baseline.files || {})) {
    const safeRel = sanitizeRelPath(rawRelPath);
    if (!safeRel || !safeRel.startsWith(`specs/${feature}/`)) {
      throw new Error(`Unsafe baseline file entry outside specs/${feature}/: ${rawRelPath}`);
    }
    const baseIds = (baseInfo && typeof baseInfo === 'object' ? baseInfo.identifiers : null) || {};
    const rawText = io.readText(safeRel);
    if (rawText === null) {
      deletedFiles.push(safeRel);
      for (const [id, info] of Object.entries(baseIds)) {
        removedIdentifiers.push({ id, file: safeRel, before: info?.line || '' });
      }
      continue;
    }

    const fileName = (baseInfo && baseInfo.fileName) || path.posix.basename(safeRel);
    // Baselines recorded before #818 carry no approval fields and keep the
    // older comparison, where any Approval: edit changes the file.
    const approvalView = typeof baseInfo?.approvalContractSha256 === 'string' ? taskApprovalBaseline(rawText, fileName) : null;
    if (approvalView) {
      if (approvalView.approvalContractSha256 !== baseInfo.approvalContractSha256) {
        changedFiles.push(safeRel);
      }
      for (const [id, was] of Object.entries(baseInfo.taskApprovals || {})) {
        if (!(id in approvalView.taskApprovals)) continue; // a removed task already changes the contract hash
        const now = approvalView.taskApprovals[id];
        if (isApproved(was) && !isApproved(now)) revokedApprovals.push(id);
        else if (!isApproved(was) && isApproved(now)) newlyApprovedTasks.push(id);
      }
    } else if (sha256Text(canonicalSpecContractText(rawText, fileName)) !== baseInfo?.contractSha256) {
      changedFiles.push(safeRel);
    }

    const curIds = extractSpecIdentifiers(rawText);
    for (const [id, baseIdInfo] of Object.entries(baseIds)) {
      const cur = curIds[id];
      if (!cur) {
        removedIdentifiers.push({ id, file: safeRel, before: baseIdInfo?.line || '' });
      } else if (cur.hash !== baseIdInfo?.hash) {
        modifiedIdentifiers.push({ id, file: safeRel, before: baseIdInfo?.line || '', after: cur.line });
      }
    }
    for (const [id, cur] of Object.entries(curIds)) {
      if (!baseIds[id]) {
        addedIdentifiers.push({ id, file: safeRel, after: cur.line });
      }
    }

    for (const entry of extractAmendmentEntries(rawText)) {
      allCurrentAmendments.push({ file: safeRel, text: entry });
    }
  }

  for (const entry of io.listDir(featureDirRel)) {
    if (!entry.isFile || entry.name.startsWith('.')) continue;
    const relFile = `${featureDirRel}/${entry.name}`;
    const matched = matchProtectedSpecRelPath(relFile, effectiveConfig);
    if (!matched || (baseline.files && baseline.files[matched.relPath])) continue;
    const rawText = io.readText(matched.relPath);
    if (rawText === null) continue;
    addedFiles.push(matched.relPath);
    for (const [id, info] of Object.entries(extractSpecIdentifiers(rawText))) {
      addedIdentifiers.push({ id, file: matched.relPath, after: info.line });
    }
    for (const item of extractAmendmentEntries(rawText)) {
      allCurrentAmendments.push({ file: matched.relPath, text: item });
    }
  }

  const hasDrift =
    changedFiles.length > 0 ||
    deletedFiles.length > 0 ||
    addedFiles.length > 0 ||
    removedIdentifiers.length > 0 ||
    modifiedIdentifiers.length > 0 ||
    revokedApprovals.length > 0;

  const baselineAmendmentCount = Number(baseline.amendmentCount || 0);
  const hasNewDeclaredAmendment = allCurrentAmendments.length > baselineAmendmentCount;

  let status = 'CLEAN';
  if (hasDrift) {
    status = hasNewDeclaredAmendment ? 'AMENDED' : 'UNDECLARED_DRIFT';
  }

  // AMENDED is a count comparison only. Name each changed REQ/AC ID that no
  // amendment entry mentions, so an unexplained change cannot read as approved;
  // judging whether each reason is adequate stays with the independent G2 (#820).
  const changedIds = [...new Set([...removedIdentifiers, ...modifiedIdentifiers, ...addedIdentifiers].map((x) => x.id))].sort();
  // Entries are append-only per file: only those beyond that file's baseline
  // count (every entry of a file added since) explain a change.
  const seenPerFile = new Map();
  const newAmendments = allCurrentAmendments.filter((a) => {
    const index = seenPerFile.get(a.file) || 0;
    seenPerFile.set(a.file, index + 1);
    const recorded = baseline.files && baseline.files[a.file];
    return index >= Number((recorded && recorded.amendmentCount) || 0);
  });
  const changedIdsWithoutAmendment = changedIds.filter((id) => {
    const re = new RegExp(`(^|[^A-Za-z0-9-])${id.replace(/[-]/g, '\\-')}([^0-9]|$)`, 'i');
    return !newAmendments.some((a) => re.test(a.text));
  });

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
    changedIdsWithoutAmendment,
    revokedApprovals,
    newlyApprovedTasks,
  };
}

/**
 * Computes dependency-ordered parallel execution batches and Scope conflict warnings (F-2).
 */
export function computeExecutionPlan(tasks) {
  const byId = new Map(tasks.map((t) => [t.id, t]));
  const remaining = new Set(tasks.map((t) => t.id));
  const completed = new Set();
  const batches = [];
  const scopeConflicts = [];

  // Compute transitive blocker sets so transitively serialized chains (T-001 -> T-002 -> T-003)
  // are not flagged as parallel scope conflicts (NEW-M3).
  const ancestorsOf = new Map();
  function getAncestors(taskId) {
    if (ancestorsOf.has(taskId)) return ancestorsOf.get(taskId);
    const visited = new Set();
    const stack = [...(byId.get(taskId)?.blockers || [])];
    while (stack.length > 0) {
      const cur = stack.pop();
      if (!cur || visited.has(cur) || cur === taskId) continue;
      visited.add(cur);
      const node = byId.get(cur);
      if (node) {
        for (const dep of node.blockers || []) {
          if (!visited.has(dep)) stack.push(dep);
        }
      }
    }
    ancestorsOf.set(taskId, visited);
    return visited;
  }

  for (let i = 0; i < tasks.length; i += 1) {
    for (let j = i + 1; j < tasks.length; j += 1) {
      const a = tasks[i];
      const b = tasks[j];
      const aBlocksB = getAncestors(b.id).has(a.id);
      const bBlocksA = getAncestors(a.id).has(b.id);
      if (aBlocksB || bBlocksA) continue;
      const overlaps = [];
      for (const sa of a.planScopes || a.scopePaths || []) {
        for (const sb of b.planScopes || b.scopePaths || []) {
          if (scopeEntriesOverlap(sa, sb)) {
            overlaps.push(`${sa} <-> ${sb}`);
          }
        }
      }
      if (overlaps.length > 0) {
        scopeConflicts.push({ tasks: [a.id, b.id], overlaps: [...new Set(overlaps)] });
      }
    }
  }

  // A Blocker naming no task in this file, or the task itself, can never be
  // satisfied: such tasks and everything downstream stay out of the waves and
  // are reported apart from real cycles (#817).
  // Only bare declared IDs are checked; prose mentions keep the old meaning
  // (a known ID is an edge, an unknown token is ignored).
  const unknownBlockers = [];
  for (const t of tasks) {
    for (const b of t.declaredBlockers || []) {
      if (!byId.has(b)) unknownBlockers.push({ task: t.id, blocker: b });
    }
  }
  const invalid = new Set([...unknownBlockers.map((u) => u.task), ...tasks.filter((t) => t.selfBlocked).map((t) => t.id)]);
  let grew = true;
  while (grew) {
    grew = false;
    for (const t of tasks) {
      if (!invalid.has(t.id) && (t.blockers || []).some((b) => invalid.has(b))) {
        invalid.add(t.id);
        grew = true;
      }
    }
  }
  for (const id of invalid) remaining.delete(id);

  let guard = 0;
  while (remaining.size > 0 && guard < tasks.length + 2) {
    guard += 1;
    const ready = tasks
      .filter((t) => remaining.has(t.id))
      .filter((t) => t.blockers.every((b) => !byId.has(b) || completed.has(b)));
    if (ready.length === 0) {
      break;
    }
    const wave = [];
    const waveScopes = [];
    for (const candidate of ready) {
      const candScopes = candidate.planScopes || candidate.scopePaths || [];
      // A task with no known Scope may touch anything, so it runs alone.
      if (candScopes.length === 0) {
        if (wave.length > 0) continue;
        wave.push(candidate.id);
        break;
      }
      const conflicts = waveScopes.some((existing) =>
        candScopes.some((cs) => scopeEntriesOverlap(existing, cs)),
      );
      if (!conflicts) {
        wave.push(candidate.id);
        waveScopes.push(...candScopes);
      }
    }
    if (wave.length === 0) {
      wave.push(ready[0].id);
    }
    batches.push(wave);
    for (const id of wave) {
      remaining.delete(id);
      completed.add(id);
    }
  }

  // Tasks on a dependency cycle (over known edges), found on the whole graph
  // so a cycle stays visible even when it also touches an invalid task.
  const onCycle = new Set();
  for (const t of tasks) {
    const seen = new Set();
    const stack = [...(t.blockers || []).filter((b) => byId.has(b))];
    while (stack.length > 0) {
      const cur = stack.pop();
      if (cur === t.id) {
        onCycle.add(t.id);
        break;
      }
      if (seen.has(cur)) continue;
      seen.add(cur);
      for (const b of byId.get(cur)?.blockers || []) if (byId.has(b)) stack.push(b);
    }
  }
  const cyclicTasks = [...new Set([...remaining, ...tasks.map((t) => t.id).filter((id) => onCycle.has(id))])];
  const invalidBlockerTasks = [...new Set(tasks.filter((t) => invalid.has(t.id)).map((t) => t.id))];
  return { batches, scopeConflicts, cyclicTasks, unknownBlockers, invalidBlockerTasks };
}

/**
 * Pure read-only Traceability + Incremental Follow-up + Code/Test & Parallel Batch analyzer (F-2, F-5).
 */
export function analyzeTraceabilityCore(
  io,
  { feature, changedIds = [], changedFiles = [], checkCodeAndTests = true },
) {
  assertValidFeatureName(feature);
  const reqRel = `specs/${feature}/requirements.md`;
  const tasksRel = `specs/${feature}/tasks.md`;

  const reqRaw = io.readText(reqRel);
  const tasksRaw = io.readText(tasksRel);
  if (reqRaw === null || tasksRaw === null) {
    throw new Error(`Missing requirements.md or tasks.md under specs/${feature}`);
  }

  const reqText = normalizeNewlines(reqRaw);
  const tasksText = normalizeNewlines(tasksRaw);
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

    const codePaths = [];
    const testPaths = [];
    const missingScopePaths = [];
    if (checkCodeAndTests) {
      for (const sp of scopePaths) {
        if (/[*?]/.test(sp)) {
          if (isTestPath(sp)) testPaths.push(sp);
          else codePaths.push(sp);
          continue;
        }
        const safe = sanitizeRelPath(sp);
        const exists = safe ? io.exists(safe) : false;
        if (isTestPath(sp)) testPaths.push(sp);
        else codePaths.push(sp);
        if (!exists && (t.status === 'Implementation Complete' || t.status === 'Done')) {
          missingScopePaths.push(sp);
        }
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
      selfBlocked: Boolean(t.selfBlocked),
      declaredBlockers: t.declaredBlockers || [],
      scopePaths,
      planScopes: [...new Set(scopePaths.map((sp) => canonicalScopeEntry(io, sp)))],
      domains,
      codePaths,
      testPaths,
      missingScopePaths,
    };
  });

  const orphanReqs = reqIds.filter((r) => reqToAcs[r].length === 0);
  const unassignedAcs = acIds.filter((a) => acToTasks[a].length === 0);

  const dependentsByBlocker = new Map();
  for (const t of tasks) {
    for (const blocker of t.blockers) {
      if (!dependentsByBlocker.has(blocker)) dependentsByBlocker.set(blocker, []);
      dependentsByBlocker.get(blocker).push(t.id);
    }
  }

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
  const executionPlan = computeExecutionPlan(tasks);

  const acCodeTestCoverage = acIds.map((ac) => {
    const linked = tasks.filter((t) => t.acRefs.includes(ac));
    const code = [...new Set(linked.flatMap((t) => t.codePaths))];
    const tests = [...new Set(linked.flatMap((t) => t.testPaths))];
    return {
      ac,
      tasks: linked.map((t) => t.id),
      hasCodeScope: code.length > 0,
      hasTestScope: tests.length > 0,
      codePaths: code,
      testPaths: tests,
    };
  });

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
    executionPlan,
    acCodeTestCoverage,
  };
}

/**
 * Loads optional product-specific review perspectives from `sdd/knowledge/review-perspectives.{json,yaml}` (F-1).
 */
export function loadProductReviewPerspectives(io) {
  const jsonRaw = io.readText('sdd/knowledge/review-perspectives.json');
  if (jsonRaw !== null) {
    try {
      const parsed = JSON.parse(jsonRaw);
      if (Array.isArray(parsed?.perspectives)) {
        return parsed.perspectives
          .filter((p) => p && typeof p.id === 'string' && typeof p.perspective === 'string')
          .map((p) => ({
            id: String(p.id),
            area: String(p.area || 'プロダクト特有'),
            perspective: String(p.perspective),
            humanQuestion: String(p.humanQuestion || p.question || ''),
            defaultDisposition: String(p.disposition || p.defaultDisposition || '採用'),
            reason: typeof p.reason === 'string' ? p.reason : '',
            domains: Array.isArray(p.domains) ? p.domains.map(String) : [],
          }));
      }
    } catch {
      // ignore malformed optional file
    }
  }

  const yamlRaw = io.readText('sdd/knowledge/review-perspectives.yaml');
  if (yamlRaw !== null) {
    const lines = normalizeNewlines(yamlRaw).split('\n');
    const items = [];
    let current = null;
    for (const rawLine of lines) {
      const line = stripYamlComment(rawLine);
      if (!line.trim()) continue;
      const itemStart = line.match(/^[ \t]*-[ \t]+([A-Za-z0-9_]+):[ \t]*(.*)$/);
      if (itemStart) {
        if (current && current.id && current.perspective) items.push(current);
        current = {
          id: '',
          area: 'プロダクト特有',
          perspective: '',
          humanQuestion: '',
          defaultDisposition: '採用',
          reason: '',
          domains: [],
        };
        const k = itemStart[1];
        const v = itemStart[2].trim().replace(/^["']|["']$/g, '');
        current[k === 'question' ? 'humanQuestion' : k === 'disposition' ? 'defaultDisposition' : k] = v;
        continue;
      }
      const propMatch = line.match(/^[ \t]+([A-Za-z0-9_]+):[ \t]*(.*)$/);
      if (propMatch && current) {
        const k = propMatch[1];
        const v = propMatch[2].trim().replace(/^["']|["']$/g, '');
        if (k === 'domains') {
          current.domains = v
            .replace(/^\[|\]$/g, '')
            .split(',')
            .map((s) => s.trim().replace(/^["']|["']$/g, ''))
            .filter(Boolean);
        } else {
          current[k === 'question' ? 'humanQuestion' : k === 'disposition' ? 'defaultDisposition' : k] = v;
        }
      }
    }
    if (current && current.id && current.perspective) items.push(current);
    return items;
  }

  return [];
}

/**
 * Builds per-feature review perspective adoption matrix (freee Software Factory p.33-35, F-1).
 */
export function buildReviewPerspectiveMatrix({
  domains,
  highestRisk,
  specCheckVerdict,
  openQuestions,
  alternativesRejected,
  productPerspectives = [],
}) {
  const hasSql = domains.includes('SQL');
  const hasCloud = domains.includes('AWS') || domains.includes('Azure') || domains.includes('Cloud');
  const hasDdd = domains.includes('DDD');
  const provisionalCount = openQuestions.filter((q) => !q.confirmed).length;

  const matrix = COMMON_REVIEW_PERSPECTIVES.map((p) => {
    let disposition = p.defaultDisposition;
    let reason = '';

    if (p.id === 'C01') {
      disposition = alternativesRejected.length > 0 ? '採用' : '軽く確認';
      reason =
        alternativesRejected.length > 0
          ? `採らなかった設計が ${alternativesRejected.length} 件記録されており判断根拠の確認が必要。`
          : '標準構成。spec-check で既存設計との整合を確認済み。';
    } else if (p.id === 'C02') {
      disposition = hasSql || hasDdd || highestRisk === 'high' ? '最重要' : '軽く確認';
      reason =
        hasSql || hasDdd
          ? `${domains.join('/')} 領域を含みデータ境界・不変条件の影響が大きい。`
          : 'データモデル変更の影響が限定的。';
    } else if (p.id === 'C03') {
      disposition = highestRisk === 'high' ? '採用' : '軽く確認';
      reason =
        highestRisk === 'high'
          ? 'Risk: high のため破壊的契約変更・認可条件の確認が必要。'
          : '既存ルール通りのインターフェース設計。';
    } else if (p.id === 'C04') {
      disposition = highestRisk === 'high' ? '採用' : '軽く確認';
      reason =
        highestRisk === 'high'
          ? '異常ルート・並列競合の妥当性確認を推奨。'
          : '状態遷移が単純で単体テストで検証可能。';
    } else if (p.id === 'C05') {
      disposition = hasCloud || openQuestions.some((q) => q.category.includes('他チーム')) ? '最重要' : '低優先';
      reason =
        hasCloud || openQuestions.some((q) => q.category.includes('他チーム'))
          ? 'クラウド外部連携または他チーム契約の未確定論点を含む。'
          : '単一サービス内で完結し不可逆な外部連携なし。';
    } else if (p.id === 'C06') {
      disposition = provisionalCount > 0 ? '最重要' : '採用';
      reason =
        provisionalCount > 0
          ? `未確定事項（OQ-NNN）が ${provisionalCount} 件あり、事業判断・業務例外の確認が必要。`
          : '業務ルール・境界値は AC とテスト方針に落とし込み済み。';
    } else if (p.id === 'C07') {
      disposition = '機械検証';
      reason = `check-traceability.mjs / check-spec-drift.mjs / spec-check (${specCheckVerdict}) で自動照合済み。人は逸脱時のみ確認。`;
    } else if (p.id === 'C08') {
      disposition = hasSql || hasCloud || highestRisk === 'high' ? '最重要' : '機械検証';
      reason =
        hasSql || hasCloud || highestRisk === 'high'
          ? 'SQL/Cloud/高リスク領域を含むため、機械センサー＋人間の切戻し確認を併用。'
          : 'run-sdd-gate.mjs の決定論センサー（Secret/Placeholder/lint/test）で自動検証。';
    }

    return {
      id: p.id,
      area: p.area,
      perspective: p.perspective,
      humanQuestion: p.humanQuestion,
      disposition,
      reason,
      source: 'common',
    };
  });

  for (const pp of productPerspectives) {
    const domainMatch =
      !pp.domains || pp.domains.length === 0 || pp.domains.some((d) => domains.includes(d));
    matrix.push({
      id: pp.id,
      area: pp.area || 'プロダクト特有',
      perspective: pp.perspective,
      humanQuestion: pp.humanQuestion,
      disposition: domainMatch ? pp.defaultDisposition || '採用' : '低優先',
      reason:
        pp.reason ||
        (domainMatch
          ? 'sdd/knowledge/review-perspectives に登録されたプロダクト固有観点。'
          : `対象領域（${pp.domains.join('/')}）外のため今回は低優先。`),
      source: 'product',
    });
  }

  return matrix;
}

export function buildDecisionViewDataCore(io, { feature, config = null }) {
  assertValidFeatureName(feature);
  const featureDirRel = `specs/${feature}`;
  const reqRel = `${featureDirRel}/requirements.md`;
  const designRel = `${featureDirRel}/design.md`;
  const tasksRel = `${featureDirRel}/tasks.md`;

  const reqRaw = io.readText(reqRel);
  const designRaw = io.readText(designRel);
  const tasksRaw = io.readText(tasksRel);

  const dirEntries = io.listDir(featureDirRel);
  const featureDirExists =
    typeof io.existsDir === 'function' ? io.existsDir(featureDirRel) : dirEntries.length > 0;
  if (reqRaw === null && designRaw === null && tasksRaw === null && !featureDirExists) {
    throw new Error(`Feature directory not found: specs/${feature}`);
  }

  const reqText = reqRaw || '';
  const designText = designRaw || '';
  const tasksText = tasksRaw || '';

  const openQuestions = mergeOpenQuestions(
    parseOpenQuestions(reqText, reqRel),
    parseOpenQuestions(designText, designRel),
  );
  const alternativesRejected = parseAlternativesRejected(designText, designRel);
  const tasks = parseTasksSummary(tasksText);
  const identifiers = extractSpecIdentifiers(reqText);
  const reqIds = Object.keys(identifiers).filter((id) => id.startsWith('REQ-'));
  const acIds = Object.keys(identifiers).filter((id) => id.startsWith('AC-'));
  const domains = detectDomains(`${reqText}\n${designText}\n${tasksText}`);

  const specCheckRel = `reports/spec-check/${feature}.md`;
  let specCheckVerdict = 'Not Run';
  const specCheckRaw = io.readText(specCheckRel);
  if (specCheckRaw !== null) {
    specCheckVerdict = (specCheckRaw.match(/\*\*Verdict\*\*:\s*([A-Z_]+)/) || [])[1] || 'Recorded';
  }

  const gateResults = [];
  for (const entry of io.listDir('reports/quality-gate')) {
    if (!entry.isFile || !entry.name.startsWith(`${feature}-`) || !entry.name.endsWith('.execution.json')) {
      continue;
    }
    const raw = io.readText(`reports/quality-gate/${entry.name}`);
    if (raw === null) continue;
    try {
      const parsed = JSON.parse(raw);
      if (parsed.feature !== feature) continue;
      gateResults.push({
        taskId: parsed.taskId,
        verdict: parsed.verdict,
        specDrift: parsed.checks?.specDrift?.status || 'UNKNOWN',
        sensorsPassed: parsed.checks?.nonFunctionalSensors?.passed ?? true,
      });
    } catch {
      // ignore malformed external file
    }
  }
  gateResults.sort((a, b) => String(a.taskId).localeCompare(String(b.taskId)));

  const effectiveConfig = config || loadGuardrailsConfigFromIo(io);
  const defaultRisk = effectiveConfig?.risk_defaults?.default_tier || 'standard';
  const highestRisk =
    tasks.length === 0
      ? defaultRisk
      : tasks.some((t) => t.risk === 'high')
        ? 'high'
        : tasks.some((t) => t.risk === 'standard')
          ? 'standard'
          : 'low';

  const provisionalCount = openQuestions.filter((q) => !q.confirmed).length;
  const productPerspectives = loadProductReviewPerspectives(io);
  const reviewPerspectives = buildReviewPerspectiveMatrix({
    domains,
    highestRisk,
    specCheckVerdict,
    openQuestions,
    alternativesRejected,
    productPerspectives,
  });

  // Traceability link summary (F-3)
  let traceabilityLinks = [];
  if (reqRaw !== null && tasksRaw !== null) {
    try {
      const trace = analyzeTraceabilityCore(io, { feature, checkCodeAndTests: false });
      traceabilityLinks = trace.acceptanceCriteria.map((ac) => ({
        ac: ac.id,
        reqs: ac.reqs,
        tasks: ac.tasks,
      }));
    } catch {
      traceabilityLinks = [];
    }
  }

  return {
    schema: 'sdd-decision-view/v1',
    generatedAt: new Date().toISOString(),
    feature,
    domains,
    highestRisk,
    specCheckVerdict,
    counts: {
      requirements: reqIds.length,
      acceptanceCriteria: acIds.length,
      tasksTotal: tasks.length,
      tasksApproved: tasks.filter((t) => /^Approved\b/i.test(t.approval)).length,
      tasksDone: tasks.filter((t) => t.status === 'Done').length,
      openQuestionsTotal: openQuestions.length,
      openQuestionsProvisional: provisionalCount,
      alternativesRejected: alternativesRejected.length,
    },
    tasks: tasks.map(({ block, ...rest }) => rest),
    openQuestions,
    alternativesRejected,
    reviewPerspectives,
    traceabilityLinks,
    gateResults,
    sourcePaths: {
      requirements: reqRel,
      design: designRel,
      tasks: tasksRel,
    },
  };
}

function escapeMdCell(text) {
  return String(text || '').replace(/\|/g, '\\|').replace(/\r?\n/g, ' ');
}

export function renderDecisionViewMarkdown(data) {
  const lines = [];
  lines.push(`# Decision View: ${data.feature}`);
  lines.push('');
  lines.push('> 全文を読み解く代わりに、**人が判断すべき要点（事実・理由・問い）** と **機械検証済みの領域** を分離したレビュービューです。');
  lines.push('');
  lines.push('## 1. 全体像（Overview）');
  lines.push('');
  lines.push('| 項目 | 値 |');
  lines.push('|---|---|');
  lines.push(`| Feature | \`${escapeMdCell(data.feature)}\` |`);
  lines.push(`| 対象領域 (Domains) | ${escapeMdCell(data.domains.join(' / '))} |`);
  lines.push(`| 最高リスク階層 | \`${escapeMdCell(data.highestRisk)}\` |`);
  lines.push(`| 要件 / 受入条件 | REQ: ${data.counts.requirements} 件 / AC: ${data.counts.acceptanceCriteria} 件 |`);
  lines.push(`| タスク進捗 | 合計 ${data.counts.tasksTotal}（Approved: ${data.counts.tasksApproved}, Done: ${data.counts.tasksDone}） |`);
  lines.push(`| 着工前 spec-check | \`${escapeMdCell(data.specCheckVerdict)}\` |`);
  lines.push(`| 未確定事項 (Provisional OQ) | **${data.counts.openQuestionsProvisional} 件** / 全 ${data.counts.openQuestionsTotal} 件 |`);
  lines.push(`| 元の仕様 (SSoT) | \`${escapeMdCell(data.sourcePaths?.requirements || '')}\` / \`${escapeMdCell(data.sourcePaths?.design || '')}\` / \`${escapeMdCell(data.sourcePaths?.tasks || '')}\` |`);
  lines.push('');

  if (Array.isArray(data.traceabilityLinks) && data.traceabilityLinks.length > 0) {
    lines.push('### 要件 ⇔ AC ⇔ タスクのつながり（ID トレース）');
    lines.push('');
    lines.push('| AC | REQ | Tasks |');
    lines.push('|---|---|---|');
    for (const link of data.traceabilityLinks) {
      lines.push(
        `| ${escapeMdCell(link.ac)} | ${escapeMdCell(link.reqs.join(', ') || '—')} | ${escapeMdCell(link.tasks.join(', ') || '⚠️ UNASSIGNED')} |`,
      );
    }
    lines.push('');
  }

  lines.push('## 2. 人が判断する問い（Open Questions / AI 仮決定）');
  lines.push('');
  if (data.openQuestions.length === 0) {
    lines.push('- 未確定の仮決定（`OQ-NNN`）はありません。');
  } else {
    for (const q of data.openQuestions) {
      const badge = q.confirmed ? '✅ Confirmed' : `🟠 ${q.status}（要判断）`;
      const impacted = q.impactedTasks.length > 0 ? q.impactedTasks.join(', ') : '全体';
      const ref = q.sourceRef ? ` / 出典: \`${q.sourceRef}\`` : '';
      lines.push(`### ${q.id} [${q.category}] — ${badge}（影響: ${impacted}${ref}）`);
      lines.push(`- **設計した事実（仮決定）**: ${q.fact}`);
      lines.push(`- **なぜそうしたか**: ${q.reason}`);
      lines.push(`- **人が判断する問い**: ${q.question}`);
      lines.push('');
    }
  }
  lines.push('');

  lines.push('## 3. 採らなかった設計（Alternatives Rejected）');
  lines.push('');
  if (data.alternativesRejected.length === 0) {
    lines.push('- 記載なし（標準構成または単一案）。');
  } else {
    lines.push('| 候補案 | 不採用理由 | 再検討条件 | 元の箇所 |');
    lines.push('|---|---|---|---|');
    for (const alt of data.alternativesRejected) {
      lines.push(
        `| ${escapeMdCell(alt.option)} | ${escapeMdCell(alt.reason)} | ${escapeMdCell(alt.revisitWhen)} | ${escapeMdCell(alt.sourceRef || '—')} |`,
      );
    }
  }
  lines.push('');

  lines.push('## 4. レビュー観点と今回の採否・理由（共通 8 観点 × プロダクト特有観点）');
  lines.push('');
  lines.push('| ID | 領域 | レビュー観点 | 今回 | 今回の理由 |');
  lines.push('|---|---|---|---|---|');
  for (const p of data.reviewPerspectives || []) {
    lines.push(
      `| ${escapeMdCell(p.id)} | ${escapeMdCell(p.area)} | ${escapeMdCell(p.perspective)} | **${escapeMdCell(p.disposition)}** | ${escapeMdCell(p.reason)} |`,
    );
  }
  lines.push('');

  if (data.gateResults.length > 0) {
    lines.push('## 5. sdd-gate 実行状況');
    lines.push('');
    lines.push('| Task | Verdict | Spec Drift | Sensors |');
    lines.push('|---|---|---|---|');
    for (const g of data.gateResults) {
      lines.push(`| ${escapeMdCell(g.taskId)} | ${escapeMdCell(g.verdict)} | ${escapeMdCell(g.specDrift)} | ${g.sensorsPassed ? 'PASS' : 'FAIL'} |`);
    }
    lines.push('');
  }

  return `${lines.join('\n')}\n`;
}

function escapeHtml(text) {
  return String(text || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function dispositionClass(disposition) {
  if (disposition === '最重要') return 'crit';
  if (disposition === '採用') return 'adopt';
  if (disposition === '機械検証') return 'mech';
  if (disposition === '軽く確認') return 'light';
  return 'low';
}

export function renderDecisionViewHtml(data) {
  const oqCards =
    data.openQuestions.length === 0
      ? '<p class="muted">未確定の仮決定（OQ-NNN）はありません。</p>'
      : data.openQuestions
          .map((q) => {
            const isProv = !q.confirmed;
            const impacted = q.impactedTasks.length > 0 ? q.impactedTasks.join(', ') : '全体';
            const srcBadge = q.sourceRef ? `<span class="badge">${escapeHtml(q.sourceRef)}</span>` : '';
            return `<section class="card ${isProv ? 'prov' : 'conf'}">
  <div class="card-head">
    <span class="badge">${escapeHtml(q.id)}</span>
    <span class="badge cat">${escapeHtml(q.category)}</span>
    <span class="badge ${isProv ? 'warn' : 'ok'}">${escapeHtml(q.status)}</span>
    <span class="badge">影響: ${escapeHtml(impacted)}</span>
    ${srcBadge}
  </div>
  <div class="cols">
    <div><h4>設計した事実</h4><p>${escapeHtml(q.fact)}</p></div>
    <div><h4>なぜそうしたか</h4><p>${escapeHtml(q.reason)}</p></div>
    <div class="ask"><h4>人が判断する問い</h4><p>${escapeHtml(q.question)}</p></div>
  </div>
</section>`;
          })
          .join('\n');

  const altRows =
    data.alternativesRejected.length === 0
      ? '<tr><td colspan="4" class="muted">記載なし</td></tr>'
      : data.alternativesRejected
          .map(
            (a) =>
              `<tr><td>${escapeHtml(a.option)}</td><td>${escapeHtml(a.reason)}</td><td>${escapeHtml(a.revisitWhen)}</td><td><code>${escapeHtml(a.sourceRef || '—')}</code></td></tr>`,
          )
          .join('\n');

  const perspectiveRows = (data.reviewPerspectives || [])
    .map(
      (p) =>
        `<tr><td><code>${escapeHtml(p.id)}</code></td><td>${escapeHtml(p.area)}</td><td>${escapeHtml(p.perspective)}</td><td><span class="disp ${dispositionClass(p.disposition)}">${escapeHtml(p.disposition)}</span></td><td>${escapeHtml(p.reason)}</td></tr>`,
    )
    .join('\n');

  const traceSection =
    !Array.isArray(data.traceabilityLinks) || data.traceabilityLinks.length === 0
      ? ''
      : `<h2>要件 ⇔ AC ⇔ タスクのつながり</h2>
  <table><thead><tr><th>AC</th><th>REQ</th><th>Tasks</th></tr></thead><tbody>${data.traceabilityLinks
    .map(
      (l) =>
        `<tr><td><code>${escapeHtml(l.ac)}</code></td><td>${escapeHtml(l.reqs.join(', ') || '—')}</td><td>${escapeHtml(l.tasks.join(', ') || 'UNASSIGNED')}</td></tr>`,
    )
    .join('\n')}</tbody></table>`;

  const gateSection =
    data.gateResults.length === 0
      ? ''
      : `<h2>sdd-gate 実行状況</h2>
  <table><thead><tr><th>Task</th><th>Verdict</th><th>Spec Drift</th><th>Sensors</th></tr></thead><tbody>${data.gateResults
    .map(
      (g) =>
        `<tr><td>${escapeHtml(g.taskId)}</td><td>${escapeHtml(g.verdict)}</td><td>${escapeHtml(g.specDrift)}</td><td>${g.sensorsPassed ? 'PASS' : 'FAIL'}</td></tr>`,
    )
    .join('\n')}</tbody></table>`;

  return `<!doctype html>
<html lang="ja">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width,initial-scale=1" />
<title>Decision View: ${escapeHtml(data.feature)}</title>
<style>
  body { font-family: system-ui, -apple-system, sans-serif; max-width: 1080px; margin: 24px auto; padding: 0 16px; color: #1e293b; background: #f8fafc; }
  h1 { color: #1d4ed8; margin-bottom: 4px; }
  .meta { display: flex; flex-wrap: wrap; gap: 10px; margin: 14px 0 24px; }
  .pill { background: #e0e7ff; color: #1e3a8a; padding: 4px 10px; border-radius: 999px; font-size: 13px; font-weight: 600; }
  .card { background: #fff; border: 1px solid #cbd5e1; border-radius: 10px; padding: 14px 16px; margin-bottom: 14px; }
  .card.prov { border-left: 5px solid #ea580c; }
  .card.conf { border-left: 5px solid #16a34a; }
  .card-head { display: flex; flex-wrap: wrap; gap: 8px; margin-bottom: 10px; }
  .badge { font-size: 12px; font-weight: 700; padding: 2px 8px; border-radius: 6px; background: #e2e8f0; }
  .badge.cat { background: #dbeafe; color: #1d4ed8; }
  .badge.warn { background: #ffedd5; color: #9a3412; }
  .badge.ok { background: #dcfce7; color: #166534; }
  .disp { font-size: 12px; font-weight: 700; padding: 2px 8px; border-radius: 6px; white-space: nowrap; }
  .disp.crit { background: #fee2e2; color: #991b1b; }
  .disp.adopt { background: #dbeafe; color: #1e40af; }
  .disp.mech { background: #e0e7ff; color: #3730a3; }
  .disp.light { background: #fef3c7; color: #92400e; }
  .disp.low { background: #f1f5f9; color: #64748b; }
  .cols { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 12px; }
  .cols h4 { margin: 0 0 4px; font-size: 13px; color: #475569; }
  .cols p { margin: 0; font-size: 14px; line-height: 1.5; }
  .ask { background: #fff7ed; padding: 10px; border-radius: 8px; border: 1px solid #fed7aa; }
  table { width: 100%; border-collapse: collapse; background: #fff; border-radius: 8px; overflow: hidden; margin-bottom: 20px; }
  th, td { border: 1px solid #e2e8f0; padding: 8px 10px; text-align: left; font-size: 14px; vertical-align: top; }
  th { background: #f1f5f9; }
  .muted { color: #64748b; }
  code { font-size: 12px; background: #f1f5f9; padding: 1px 4px; border-radius: 4px; }
</style>
</head>
<body>
  <h1>Decision View: ${escapeHtml(data.feature)}</h1>
  <p class="muted">生成時刻: ${escapeHtml(data.generatedAt)} — 機械確認済み項目と人間が判断すべき問いを分離したビュー</p>
  <div class="meta">
    <span class="pill">Domains: ${escapeHtml(data.domains.join(' / '))}</span>
    <span class="pill">Highest Risk: ${escapeHtml(data.highestRisk)}</span>
    <span class="pill">spec-check: ${escapeHtml(data.specCheckVerdict)}</span>
    <span class="pill">REQ: ${data.counts.requirements} / AC: ${data.counts.acceptanceCriteria}</span>
    <span class="pill">Tasks: ${data.counts.tasksDone}/${data.counts.tasksTotal} Done</span>
    <span class="pill">Provisional OQ: ${data.counts.openQuestionsProvisional}</span>
  </div>
  <h2>人が判断する問い（Open Questions）</h2>
  ${oqCards}
  <h2>レビュー観点と今回の採否・理由</h2>
  <table><thead><tr><th>ID</th><th>領域</th><th>レビュー観点</th><th>今回</th><th>今回の理由</th></tr></thead><tbody>${perspectiveRows}</tbody></table>
  <h2>採らなかった設計（Alternatives Rejected）</h2>
  <table><thead><tr><th>候補案</th><th>不採用理由</th><th>再検討条件</th><th>元の箇所</th></tr></thead><tbody>${altRows}</tbody></table>
  ${traceSection}
  ${gateSection}
</body>
</html>
`;
}

function walkIoFiles(io, relDir, predicate, out = [], depth = 0, state = { count: 0, maxEntries: 5000 }) {
  if (depth > 12 || state.count >= state.maxEntries) return out;
  const entries = io.listDir(relDir);
  for (const entry of entries) {
    if (state.count >= state.maxEntries) break;
    if (IGNORED_DIRS.has(entry.name)) continue;
    state.count += 1;
    const childRel = relDir ? `${relDir}/${entry.name}` : entry.name;
    if (entry.isDirectory) {
      // Guard against simple in-tree symlink directory cycles (e.g. a/b/a/b)
      const segments = childRel.split('/');
      const repeated = segments.filter((s) => s === entry.name).length;
      if (repeated > 2) continue;
      walkIoFiles(io, childRel, predicate, out, depth + 1, state);
    } else if (entry.isFile && predicate(childRel, entry.name)) {
      out.push(childRel);
    }
  }
  return out;
}

function parseFrontmatter(content) {
  const normalized = normalizeNewlines(content);
  if (!normalized.startsWith('---\n')) return null;
  const endIdx = normalized.indexOf('\n---', 4);
  if (endIdx === -1) return null;
  const raw = normalized.slice(4, endIdx);
  const fields = {};
  const lines = raw.split('\n');
  for (let i = 0; i < lines.length; i += 1) {
    const line = lines[i];
    const m = line.match(/^([A-Za-z0-9_-]+):\s*(.*)$/);
    if (!m) continue;
    const key = m[1];
    let val = m[2].trim();
    if (val === '|' || val === '>') {
      const block = [];
      while (i + 1 < lines.length && /^[ \t]+/.test(lines[i + 1])) {
        i += 1;
        block.push(lines[i].trim());
      }
      val = block.join(val === '>' ? ' ' : '\n');
    } else if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
      val = val.slice(1, -1);
    }
    fields[key] = val;
  }
  return fields;
}

function addFinding(findings, severity, category, message, relPath, action) {
  findings.push({
    severity,
    category,
    message,
    path: relPath || null,
    action,
  });
}

/**
 * Pure read-only sdd-doctor core usable by both CLI (`sdd-doctor.mjs`) and MCP (`v2.ts`).
 */
export function runDoctorCore(
  io,
  {
    staleDays = 14,
    nodeVersion = process.versions.node,
    rootLabel = null,
    scanExtendedRepo = true,
  } = {},
) {
  const findings = [];

  // 1. Runtime
  const major = Number(String(nodeVersion || '').split('.')[0]);
  if (Number.isNaN(major) || major < 20) {
    addFinding(
      findings,
      'NG',
      'runtime',
      `Node.js ${nodeVersion} は v2 推奨要件（>= 20 LTS）未満です`,
      null,
      'Node.js 20 LTS 以上へアップグレードしてください',
    );
  }

  // 2. Kill switch
  if (io.exists('AGENT_STOP')) {
    addFinding(
      findings,
      'WARN',
      'kill-switch',
      'AGENT_STOP が存在するため、全ホストのツール実行が停止状態です',
      'AGENT_STOP',
      '作業を再開する場合は安全を確認したうえで AGENT_STOP を削除してください',
    );
  }

  // 3. Guardrails config
  const jsonRaw = io.readText('sdd/guardrails.json');
  const yamlRaw = jsonRaw === null ? io.readText('sdd/guardrails.yaml') : null;
  let parsed = null;
  let configRel = null;
  if (jsonRaw !== null) {
    configRel = 'sdd/guardrails.json';
    try {
      parsed = JSON.parse(jsonRaw);
    } catch (err) {
      addFinding(
        findings,
        'NG',
        'config',
        `JSON 構文エラー: ${err instanceof Error ? err.message : String(err)}`,
        configRel,
        'sdd/guardrails.json の構文を contracts/guardrails.schema.json に沿って修正してください',
      );
    }
  } else if (yamlRaw !== null) {
    configRel = 'sdd/guardrails.yaml';
    try {
      parsed = parseSimpleYaml(yamlRaw);
      if (!parsed || Object.keys(parsed).length === 0) {
        addFinding(
          findings,
          'NG',
          'config',
          'sdd/guardrails.yaml が空または解析不能です',
          configRel,
          'sdd/guardrails.example.yaml を参考に有効な設定を記述してください',
        );
        parsed = null;
      }
    } catch (err) {
      addFinding(
        findings,
        'NG',
        'config',
        `YAML 読込エラー: ${err instanceof Error ? err.message : String(err)}`,
        configRel,
        'sdd/guardrails.yaml の文字コードと構文を確認してください',
      );
      parsed = null;
    }
  } else {
    addFinding(
      findings,
      'INFO',
      'config',
      'sdd/guardrails.yaml 未配置（既定値 spec_guard.mode=confirm で動作中）',
      'sdd/guardrails.yaml',
      '必要に応じて sdd/guardrails.example.yaml をコピーして調整してください',
    );
  }

  if (parsed && configRel) {
    if (parsed.schema && parsed.schema !== 'sdd-guardrails/v1') {
      addFinding(findings, 'NG', 'config', `未対応の schema 値: ${parsed.schema}`, configRel, 'schema を "sdd-guardrails/v1" に修正してください');
    }
    const mode = parsed?.spec_guard?.mode;
    if (mode !== undefined && !VALID_MODES.has(mode)) {
      addFinding(findings, 'NG', 'config', `不正な spec_guard.mode: ${mode}`, configRel, 'warn | confirm | strict のいずれかを指定してください');
    }
    const preImpl = parsed?.review?.pre_impl_check;
    if (preImpl !== undefined && !VALID_PRE_IMPL.has(preImpl)) {
      addFinding(findings, 'NG', 'config', `不正な review.pre_impl_check: ${preImpl}`, configRel, 'auto | always | off のいずれかを指定してください');
    }
    const tier = parsed?.risk_defaults?.default_tier;
    if (tier !== undefined && !VALID_RISK_TIERS.has(tier)) {
      addFinding(findings, 'NG', 'config', `不正な risk_defaults.default_tier: ${tier}`, configRel, 'low | standard | high のいずれかを指定してください');
    }
    const maxRounds = parsed?.limits?.max_auto_fix_rounds;
    if (maxRounds !== undefined && (!Number.isInteger(maxRounds) || maxRounds < 0 || maxRounds > 10)) {
      addFinding(findings, 'NG', 'config', `不正な limits.max_auto_fix_rounds: ${maxRounds}`, configRel, '0〜10 の整数を指定してください');
    }
  }

  // 4. Hooks & Skills (CLI full repo mode only; MCP stays strictly inside allowlist)
  if (scanExtendedRepo) {
    const hookCandidates = [
      'plugins/sdd-quality-loop/hooks/claude-hooks.json',
      'plugins/sdd-quality-loop/hooks/codex-hooks.json',
      'plugins/sdd-quality-loop/hooks/copilot-hooks.json',
      'plugins/sdd-quality-loop/hooks.json',
      'plugins/sdd-quality-loop/gemini/hooks/hooks.json',
      'plugins/sdd-implementation/hooks.json',
      '.claude/settings.json',
      '.codex/hooks.json',
      '.gemini/settings.json',
      '.agents/hooks.json',
      ...walkIoFiles(io, '.github/hooks', (_rel, name) => name.endsWith('.json')),
    ];
    let checkedHooks = 0;
    for (const rel of hookCandidates) {
      const raw = io.readText(rel);
      if (raw === null) continue;
      checkedHooks += 1;
      try {
        JSON.parse(raw);
      } catch (err) {
        addFinding(
          findings,
          'NG',
          'hooks',
          `フック設定の JSON 構文エラー: ${err instanceof Error ? err.message : String(err)}`,
          rel,
          'JSON 構文を修正し、ホストのフック読込がサイレント失敗しない状態にしてください',
        );
        continue;
      }
      if (/sdd-hook-guard/i.test(raw)) {
        addFinding(
          findings,
          'WARN',
          'hooks',
          '廃止済みの v1 ハードロック（sdd-hook-guard）参照が残存しています',
          rel,
          'install.sh / install.ps1 を再実行して v2/sdd-soft-guard.mjs へ切り替えてください',
        );
      }
    }
    if (
      io.listDir('plugins/sdd-quality-loop').length > 0 &&
      !io.exists('plugins/sdd-quality-loop/scripts/v2/sdd-soft-guard.mjs')
    ) {
      addFinding(
        findings,
        'NG',
        'hooks',
        'v2 ソフトガード本体（sdd-soft-guard.mjs）が見つかりません',
        'plugins/sdd-quality-loop/scripts/v2/sdd-soft-guard.mjs',
        'sdd-forge を再インストールしてください',
      );
    }
    if (checkedHooks === 0) {
      addFinding(
        findings,
        'INFO',
        'hooks',
        'プロジェクト配下にローカルフック設定は検出されませんでした（ユーザーホーム側設定を利用中の可能性）',
        null,
        'フック動作を確認する場合はホスト設定（~/.claude / ~/.codex / ~/.gemini/config 等）を確認してください',
      );
    }

    const skillFiles = [
      ...walkIoFiles(io, 'plugins', (rel, name) => name === 'SKILL.md' && !rel.includes('/human-copy') && !rel.includes('/references/')),
      ...walkIoFiles(io, 'sdd/skills', (rel, name) => name === 'SKILL.md' && !rel.includes('/human-copy') && !rel.includes('/references/')),
    ];
    for (const rel of skillFiles) {
      const content = io.readText(rel);
      if (content === null) continue;
      const fm = parseFrontmatter(content);
      if (!fm || !fm.name || !fm.description) {
        addFinding(
          findings,
          'NG',
          'skills',
          'SKILL.md の YAML フロントマター（name / description）が欠落または不正です',
          rel,
          '先頭に --- で囲んだ name と description を記載してください',
        );
        continue;
      }
      if (fm.description.length > MAX_SKILL_DESCRIPTION_CHARS) {
        addFinding(
          findings,
          'NG',
          'skills',
          `description が ${fm.description.length} 文字あり上限（${MAX_SKILL_DESCRIPTION_CHARS} 文字）を超過（ホスト側で警告なく無視される恐れ）`,
          rel,
          `description を ${MAX_SKILL_DESCRIPTION_CHARS} 文字以内へ要約してください`,
        );
      }
    }
  }

  // 5. Encoding & control chars in specs/ (and sdd/ in extended mode)
  const textTargets = [
    ...walkIoFiles(io, 'specs', (_rel, name) => /\.(md|json|ya?ml)$/i.test(name)),
    ...(scanExtendedRepo
      ? walkIoFiles(io, 'sdd', (_rel, name) => /\.(md|json|ya?ml)$/i.test(name))
      : walkIoFiles(io, 'sdd/knowledge', (_rel, name) => /\.(md|json|ya?ml)$/i.test(name))),
  ];
  for (const rel of textTargets) {
    const raw = io.readText(rel);
    if (raw === null) continue;
    const match = CONTROL_CHAR_RE.exec(raw);
    if (match) {
      const codeHex = `0x${match[0].charCodeAt(0).toString(16).padStart(2, '0')}`;
      addFinding(
        findings,
        'NG',
        'encoding',
        `不正な ASCII 制御文字（${codeHex}）が混入しています（シェルエスケープ破損の恐れ）`,
        rel,
        '該当ファイルの破損箇所をファイル編集ツールで修復してください',
      );
    }
  }

  if (scanExtendedRepo && typeof io.readBytes === 'function') {
    const psTargets = [
      ...walkIoFiles(io, 'sdd', (_rel, name) => name.endsWith('.ps1')),
      ...walkIoFiles(io, 'scripts', (_rel, name) => name.endsWith('.ps1')),
    ];
    for (const rel of psTargets) {
      const buf = io.readBytes(rel);
      if (!buf) continue;
      const hasBom = buf.length >= 3 && buf[0] === 0xef && buf[1] === 0xbb && buf[2] === 0xbf;
      const decoded = Buffer.from(buf).toString('utf8');
      if (!hasBom && NON_ASCII_RE.test(decoded)) {
        addFinding(
          findings,
          'WARN',
          'encoding',
          '非 ASCII 文字を含む PowerShell スクリプトに UTF-8 BOM がありません（Windows PS 5.1 文字化けリスク）',
          rel,
          'UTF-8 BOM 付きで保存するか ASCII のみで記述してください',
        );
      }
    }
  }

  // 6. Specs & Tasks (baselines + stale In Progress)
  const nowMs = Date.now();
  const staleMs = staleDays * 24 * 60 * 60 * 1000;
  for (const entry of io.listDir('specs')) {
    if (!entry.isDirectory) continue;
    const relTasks = `specs/${entry.name}/tasks.md`;
    const content = io.readText(relTasks);
    if (content === null) continue;

    const approvedCount = countPrimaryApprovals(content);
    const hasActiveTask = /^[ \t]*Status:[ \t]*(?:Planned|In Progress|Implementation Complete|Blocked)\b/im.test(content);
    const baselineRel = `specs/${entry.name}/.spec-baseline.json`;

    if (approvedCount > 0 && hasActiveTask && !io.exists(baselineRel)) {
      addFinding(
        findings,
        'WARN',
        'specs',
        `進行中・未完了の承認済みタスクが ${approvedCount} 件ありますが .spec-baseline.json が未作成です（Spec Drift 検知が未武装）`,
        relTasks,
        `record-spec-baseline.mjs --feature ${entry.name} を実行してください`,
      );
    }

    if (/^[ \t]*Status:[ \t]*In Progress\b/im.test(content)) {
      const mtimeMs = io.statMtimeMs(relTasks);
      if (mtimeMs !== null && nowMs - mtimeMs > staleMs) {
        const ageDays = Math.floor((nowMs - mtimeMs) / (24 * 60 * 60 * 1000));
        addFinding(
          findings,
          'WARN',
          'specs',
          `Status: In Progress のタスクが ${ageDays} 日以上未更新です（しきい値: ${staleDays} 日）`,
          relTasks,
          '作業を継続するか、完了・中止状態へ tasks.md を更新してください',
        );
      }
    }
  }

  // 7. Knowledge INDEX (<= 3,000 chars)
  const MAX_INDEX_CHARS = 3000;
  const indexFiles = walkIoFiles(io, 'sdd/knowledge', (_rel, name) => name.toUpperCase() === 'INDEX.MD');
  for (const rel of indexFiles) {
    const raw = io.readText(rel);
    if (raw === null) continue;
    const len = normalizeNewlines(raw).length;
    if (len > MAX_INDEX_CHARS) {
      addFinding(
        findings,
        'WARN',
        'knowledge',
        `ナレッジ索引が ${len} 文字あり目安上限（${MAX_INDEX_CHARS} 文字）を超過しています（コンテキスト圧迫リスク）`,
        rel,
        '詳細は個別ファイルへ分割し、INDEX は 3,000 字以内のリンク集に保ってください',
      );
    }
  }

  // 8. Drift events
  const driftRaw = io.readText('.sdd/drift-events.jsonl');
  if (driftRaw !== null) {
    const lines = normalizeNewlines(driftRaw)
      .split('\n')
      .filter((l) => l.trim().length > 0);
    if (lines.length > 0) {
      let denyCount = 0;
      let warnCount = 0;
      let parseErrors = 0;
      for (const line of lines) {
        try {
          const ev = JSON.parse(line);
          const action = typeof ev.action === 'string' ? ev.action : '';
          const decision = typeof ev.decision === 'string' ? ev.decision : '';
          if (action === 'strict_deny' || action === 'confirm_soft_deny' || decision === 'deny') {
            denyCount += 1;
          } else if (
            action === 'warn_allow' ||
            action === 'confirm_amended_allow' ||
            action === 'allow_override' ||
            decision === 'warn' ||
            decision === 'confirm'
          ) {
            warnCount += 1;
          }
        } catch {
          parseErrors += 1;
        }
      }
      if (parseErrors > 0) {
        addFinding(
          findings,
          'WARN',
          'events',
          `.sdd/drift-events.jsonl に破損行が ${parseErrors} 件あります`,
          '.sdd/drift-events.jsonl',
          '破損行を確認してください',
        );
      }
      addFinding(
        findings,
        'INFO',
        'events',
        `ガードイベント累計 ${lines.length} 件（deny=${denyCount}, warn/confirm=${warnCount}）`,
        '.sdd/drift-events.jsonl',
        'workflow-retrospective 実行時の事実ベース集計に利用できます',
      );
    }
  }

  const summary = {
    ng: findings.filter((f) => f.severity === 'NG').length,
    warn: findings.filter((f) => f.severity === 'WARN').length,
    info: findings.filter((f) => f.severity === 'INFO').length,
  };

  const result = {
    schema: 'sdd-doctor/v1',
    checked_at: new Date().toISOString(),
    status: summary.ng > 0 ? 'NG' : summary.warn > 0 ? 'WARN' : 'CLEAN',
    summary,
    non_checks: [...NON_CHECKS],
    findings,
  };
  if (rootLabel !== null) {
    result.root = rootLabel;
  }
  return result;
}
