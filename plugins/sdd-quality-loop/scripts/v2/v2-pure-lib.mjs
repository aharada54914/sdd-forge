#!/usr/bin/env node
/**
 * Pure, side-effect-free helpers for SDD Forge v2 Lightweight Guardrails.
 *
 * Strictly zero filesystem, zero process.env, zero child_process imports.
 * Shared as Single Source of Truth by both local v2 CLI scripts and
 * read-only `sdd-forge-mcp` v2 (ADR-0052).
 */
import crypto from 'node:crypto';
import path from 'node:path';

export const DEFAULT_CONFIG = Object.freeze({
  schema: 'sdd-guardrails/v1',
  spec_guard: {
    mode: 'confirm',
    protected_globs: [
      'specs/*/requirements.md',
      'specs/*/design.md',
      'specs/*/tasks.md',
    ],
    allow_amendment_section: true,
  },
  review: {
    pre_impl_check: 'auto',
    independent_gate: true,
  },
  risk_defaults: {
    default_tier: 'standard',
    high_risk_paths: ['**/auth/**', '**/billing/**', '**/migrations/**'],
  },
  limits: {
    max_auto_fix_rounds: 2,
  },
});

export const VALID_MODES = new Set(['warn', 'confirm', 'strict']);
export const VALID_PRE_IMPL = new Set(['auto', 'always', 'off']);
export const VALID_RISK_TIERS = new Set(['low', 'standard', 'high']);

const APPROVAL_LINE_RE = /(?:^|\n)[ \t]*Approval:[ \t]*Approved\b/g;
const DOMAIN_MODEL_APPROVAL_RE = /(?:^|\n)[ \t]*Domain-Model-Status:[ \t]*Approved\b/g;
const STATUS_LINE_RE = /^[ \t]*Status:[ \t]*.*$/gm;
const AMENDMENT_HEADING_RE = /^(#{2,3})[ \t]+Spec Amendments[ \t]*$/im;
const IDENTIFIER_LINE_RE =
  /^[ \t]*(?:[-*+]|\d+\.)?[ \t]*(?:\*\*)?((?:REQ|AC)-\d+)(?:\*\*)?(?:[ \t]*[（(][^）)\n]+[）)])?(?:\*\*)?[ \t]*[:：][^\n]*$/gm;
const PLACEHOLDER_AMENDMENT_RE =
  /^(?:[-*+]\s*)?(?:none(?:\s+yet)?\.?|n\/a|\(none\)|no\s+changes?(?:\s+yet)?\.?|（なし）|なし|（初期版のため変更なし）|初期版[。．.・\s]*変更なし[。．.]?|初期版（変更なし）|\(initial\s+version[^)]*\))$/i;

export function normalizeNewlines(text) {
  return typeof text === 'string' ? text.replace(/\r\n/g, '\n').replace(/\r/g, '\n') : '';
}

export function sha256Text(text) {
  return crypto.createHash('sha256').update(normalizeNewlines(text), 'utf8').digest('hex');
}

export function toPosixPath(filePath) {
  return String(filePath || '').replace(/\\/g, '/');
}

export function normalizeRelPath(filePath) {
  return toPosixPath(filePath).trim().replace(/^\.\//, '').replace(/\/+$/, '');
}

/**
 * Validates that a root-relative path contains no traversal, absolute prefix,
 * backslash, or NUL byte. Returns normalized POSIX path or null if unsafe.
 */
export function sanitizeRelPath(relPath) {
  if (typeof relPath !== 'string' || relPath.length === 0 || relPath.includes('\0')) {
    return null;
  }
  if (relPath.includes('\\') || path.isAbsolute(relPath) || relPath.startsWith('/')) {
    return null;
  }
  const normalized = relPath.replace(/^\.\//, '').replace(/\/+$/, '');
  if (!normalized) return null;
  const segments = normalized.split('/');
  if (segments.some((s) => s === '' || s === '.' || s === '..')) {
    return null;
  }
  return normalized;
}

export function assertValidFeatureName(feature) {
  if (
    typeof feature !== 'string' ||
    !feature ||
    /[\\/\0]/.test(feature) ||
    feature === '.' ||
    feature === '..'
  ) {
    throw new Error(`Invalid feature name: ${feature}`);
  }
}

export function stripYamlComment(line) {
  let inSingle = false;
  let inDouble = false;
  for (let i = 0; i < line.length; i += 1) {
    const ch = line[i];
    if (ch === "'" && !inDouble) {
      inSingle = !inSingle;
    } else if (ch === '"' && !inSingle && line[i - 1] !== '\\') {
      inDouble = !inDouble;
    } else if (ch === '#' && !inSingle && !inDouble) {
      if (i === 0 || /\s/.test(line[i - 1])) {
        return line.slice(0, i);
      }
    }
  }
  return line;
}

function parseYamlScalar(raw) {
  const trimmed = raw.trim();
  if (trimmed === 'true') return true;
  if (trimmed === 'false') return false;
  if (trimmed === 'null' || trimmed === '~') return null;
  if (/^-?\d+(?:\.\d+)?$/.test(trimmed)) return Number(trimmed);
  if (
    (trimmed.startsWith('"') && trimmed.endsWith('"')) ||
    (trimmed.startsWith("'") && trimmed.endsWith("'"))
  ) {
    return trimmed.slice(1, -1);
  }
  return trimmed;
}

/**
 * Minimal deterministic parser for 2-level YAML config files (maps, scalars, string lists).
 */
export function parseSimpleYaml(text) {
  const root = {};
  const lines = normalizeNewlines(text).split('\n');
  let currentSection = null;
  let currentListKey = null;

  for (const rawLine of lines) {
    const cleaned = stripYamlComment(rawLine).replace(/\s+$/, '');
    if (!cleaned.trim()) continue;

    const indent = cleaned.length - cleaned.trimStart().length;
    const content = cleaned.trim();

    if (indent === 0) {
      currentListKey = null;
      const idx = content.indexOf(':');
      if (idx === -1) continue;
      const key = content.slice(0, idx).trim();
      const rest = content.slice(idx + 1).trim();
      if (rest === '') {
        root[key] = {};
        currentSection = key;
      } else {
        root[key] = parseYamlScalar(rest);
        currentSection = null;
      }
      continue;
    }

    if (content.startsWith('- ')) {
      const value = parseYamlScalar(content.slice(2));
      if (currentSection && currentListKey) {
        if (!Array.isArray(root[currentSection][currentListKey])) {
          root[currentSection][currentListKey] = [];
        }
        root[currentSection][currentListKey].push(value);
      }
      continue;
    }

    const idx = content.indexOf(':');
    if (idx === -1 || !currentSection) continue;
    const key = content.slice(0, idx).trim();
    const rest = content.slice(idx + 1).trim();
    if (rest === '') {
      root[currentSection][key] = [];
      currentListKey = key;
    } else {
      root[currentSection][key] = parseYamlScalar(rest);
      currentListKey = null;
    }
  }

  return root;
}

export function normalizeGuardrailsConfig(parsed, sourcePath = null) {
  const sg = parsed && typeof parsed.spec_guard === 'object' && parsed.spec_guard ? parsed.spec_guard : {};
  const rv = parsed && typeof parsed.review === 'object' && parsed.review ? parsed.review : {};
  const rd = parsed && typeof parsed.risk_defaults === 'object' && parsed.risk_defaults ? parsed.risk_defaults : {};
  const lm = parsed && typeof parsed.limits === 'object' && parsed.limits ? parsed.limits : {};

  const maxAutoFix =
    typeof lm.max_auto_fix_rounds === 'number' &&
    Number.isInteger(lm.max_auto_fix_rounds) &&
    lm.max_auto_fix_rounds >= 0 &&
    lm.max_auto_fix_rounds <= 10
      ? lm.max_auto_fix_rounds
      : DEFAULT_CONFIG.limits.max_auto_fix_rounds;

  return {
    schema: 'sdd-guardrails/v1',
    sourcePath,
    spec_guard: {
      mode: VALID_MODES.has(sg.mode) ? sg.mode : DEFAULT_CONFIG.spec_guard.mode,
      protected_globs:
        Array.isArray(sg.protected_globs) && sg.protected_globs.length > 0
          ? sg.protected_globs.map((g) => String(g))
          : [...DEFAULT_CONFIG.spec_guard.protected_globs],
      allow_amendment_section:
        typeof sg.allow_amendment_section === 'boolean'
          ? sg.allow_amendment_section
          : DEFAULT_CONFIG.spec_guard.allow_amendment_section,
    },
    review: {
      pre_impl_check: VALID_PRE_IMPL.has(rv.pre_impl_check) ? rv.pre_impl_check : DEFAULT_CONFIG.review.pre_impl_check,
      independent_gate:
        typeof rv.independent_gate === 'boolean' ? rv.independent_gate : DEFAULT_CONFIG.review.independent_gate,
    },
    risk_defaults: {
      default_tier: VALID_RISK_TIERS.has(rd.default_tier) ? rd.default_tier : DEFAULT_CONFIG.risk_defaults.default_tier,
      high_risk_paths:
        Array.isArray(rd.high_risk_paths) && rd.high_risk_paths.length > 0
          ? rd.high_risk_paths.map((p) => String(p))
          : [...DEFAULT_CONFIG.risk_defaults.high_risk_paths],
    },
    limits: {
      max_auto_fix_rounds: maxAutoFix,
    },
  };
}

export function globToRegExp(glob) {
  const posix = toPosixPath(glob).replace(/^\.\//, '');
  let out = '^';
  for (let i = 0; i < posix.length; i += 1) {
    const ch = posix[i];
    if (ch === '*') {
      if (posix[i + 1] === '*') {
        if (posix[i + 2] === '/') {
          out += '(?:.*/)?';
          i += 2;
        } else {
          out += '.*';
          i += 1;
        }
      } else {
        out += '[^/]*';
      }
    } else if (ch === '?') {
      out += '[^/]';
    } else if (/[.+^${}()|[\]\\]/.test(ch)) {
      out += `\\${ch}`;
    } else {
      out += ch;
    }
  }
  out += '$';
  return new RegExp(out, 'i');
}

export function matchProtectedSpecRelPath(relPath, config) {
  const rel = sanitizeRelPath(relPath);
  if (!rel) return null;
  const globs =
    (config && config.spec_guard && config.spec_guard.protected_globs) ||
    DEFAULT_CONFIG.spec_guard.protected_globs;
  const matched = globs.some((pattern) => globToRegExp(pattern).test(rel));
  if (!matched) return null;

  const featureMatch = rel.match(/^specs\/([^/]+)\/(.+)$/i);
  return {
    relPath: rel,
    feature: featureMatch ? featureMatch[1] : null,
    fileName: path.posix.basename(rel).toLowerCase(),
  };
}

export function countPrimaryApprovals(text) {
  if (!text) return 0;
  // APPROVAL_LINE_RE is anchored to the line start, so legacy
  // `Second Approval: Approved` lines are already excluded. Subtracting them
  // again undercounted primary approvals and let a paired insertion of both
  // lines net to zero in the soft guard (#833).
  return (normalizeNewlines(text).match(APPROVAL_LINE_RE) || []).length;
}

export function countDomainModelApprovals(text) {
  if (!text) return 0;
  return (normalizeNewlines(text).match(DOMAIN_MODEL_APPROVAL_RE) || []).length;
}

function parseSpecAmendmentsSection(text) {
  const normalized = normalizeNewlines(text);
  const match = AMENDMENT_HEADING_RE.exec(normalized);
  if (!match) {
    return {
      beforeAmendments: normalized,
      amendmentsBody: '',
      amendmentsRawBody: '',
      amendmentsHeadingLine: null,
      afterAmendments: '',
      hasHeading: false,
    };
  }

  const headingLevel = match[1].length;
  const headingStart = match.index;
  const headingLine = normalized.slice(0, headingStart).split('\n').length;
  const afterHeadingStart = headingStart + match[0].length;
  const rest = normalized.slice(afterHeadingStart);

  const nextHeadingRe = new RegExp(`^#{1,${headingLevel}}[ \\t]+\\S`, 'm');
  const nextMatch = nextHeadingRe.exec(rest);

  if (!nextMatch) {
    return {
      beforeAmendments: normalized.slice(0, headingStart).trimEnd(),
      amendmentsBody: rest.trim(),
      amendmentsRawBody: rest,
      amendmentsHeadingLine: headingLine,
      afterAmendments: '',
      hasHeading: true,
    };
  }

  const rawBody = rest.slice(0, nextMatch.index);
  return {
    beforeAmendments: normalized.slice(0, headingStart).trimEnd(),
    amendmentsBody: rawBody.trim(),
    amendmentsRawBody: rawBody,
    amendmentsHeadingLine: headingLine,
    afterAmendments: rest.slice(nextMatch.index).trimStart(),
    hasHeading: true,
  };
}

export function splitSpecAmendments(text) {
  const { beforeAmendments, amendmentsBody, afterAmendments, hasHeading } = parseSpecAmendmentsSection(text);
  return {
    beforeAmendments,
    amendmentsBody,
    afterAmendments,
    hasHeading,
  };
}

export function extractAmendmentEntriesWithLines(text, sourceFile = null) {
  const { hasHeading, amendmentsBody, amendmentsRawBody, amendmentsHeadingLine } = parseSpecAmendmentsSection(text);
  if (!hasHeading || !amendmentsBody) return [];

  const entries = [];
  const rawLines = amendmentsRawBody.split('\n');
  for (let i = 0; i < rawLines.length; i += 1) {
    const trimmed = rawLines[i].trim();
    if (!trimmed) continue;
    if (PLACEHOLDER_AMENDMENT_RE.test(trimmed)) continue;
    const lineNumber = amendmentsHeadingLine + i;
    entries.push({
      text: trimmed,
      sourceFile,
      sourceLine: lineNumber,
      sourceRef: sourceFile ? `${sourceFile}:L${lineNumber}` : null,
    });
  }
  return entries;
}

export function extractAmendmentEntries(text) {
  return extractAmendmentEntriesWithLines(text).map((entry) => entry.text);
}

/**
 * The one approval grammar every consumer uses (#830): exactly `Approved`,
 * optionally followed by one parenthesized note (`Approved (2026-11-01 owner)`).
 * Case variants and trailing words are not approvals.
 */
export function isApprovedValue(value) {
  return /^Approved(?:[ \t]*\([^()\n]*\))?$/.test(String(value ?? '').trim());
}

export function canonicalSpecContractText(text, fileName) {
  const { beforeAmendments, afterAmendments } = splitSpecAmendments(text);
  let combined = afterAmendments ? `${beforeAmendments}\n\n${afterAmendments}` : beforeAmendments;
  if (String(fileName || '').toLowerCase() === 'tasks.md') {
    combined = combined.replace(STATUS_LINE_RE, 'Status: <NORMALIZED>');
  }
  return combined.trim();
}

export function isSafeSpecEditOnly(oldContent, newContent, fileName, allowAmendmentSection = true) {
  const lower = String(fileName || '').toLowerCase();
  if (allowAmendmentSection) {
    return canonicalSpecContractText(oldContent, lower) === canonicalSpecContractText(newContent, lower);
  }
  if (lower === 'tasks.md') {
    const oldNorm = normalizeNewlines(oldContent).replace(STATUS_LINE_RE, 'Status: <NORMALIZED>').trim();
    const newNorm = normalizeNewlines(newContent).replace(STATUS_LINE_RE, 'Status: <NORMALIZED>').trim();
    return oldNorm === newNorm;
  }
  return normalizeNewlines(oldContent).trim() === normalizeNewlines(newContent).trim();
}

export function extractSpecIdentifiers(text) {
  const { beforeAmendments, afterAmendments } = splitSpecAmendments(text);
  const body = afterAmendments ? `${beforeAmendments}\n\n${afterAmendments}` : beforeAmendments;
  const map = {};
  IDENTIFIER_LINE_RE.lastIndex = 0;
  let m;
  while ((m = IDENTIFIER_LINE_RE.exec(body)) !== null) {
    const id = m[1].toUpperCase();
    const normalizedLine = m[0].trim().replace(/\s+/g, ' ');
    if (!(id in map)) {
      map[id] = {
        line: normalizedLine,
        hash: sha256Text(normalizedLine),
      };
    }
  }
  return map;
}
