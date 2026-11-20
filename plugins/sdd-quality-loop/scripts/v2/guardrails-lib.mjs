#!/usr/bin/env node
/**
 * Shared library for SDD Forge v2 Lightweight Guardrails.
 * Zero external dependencies — Node.js >= 20 LTS built-in modules only.
 */
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

export const DEFAULT_CONFIG = Object.freeze({
  schema: 'sdd-guardrails/v1',
  spec_guard: {
    mode: 'confirm',
    protected_globs: [
      'specs/*/requirements.md',
      'specs/*/design.md',
      'specs/*/acceptance-tests.md',
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
});

const VALID_MODES = new Set(['warn', 'confirm', 'strict']);
const VALID_PRE_IMPL = new Set(['auto', 'always', 'off']);
const VALID_RISK_TIERS = new Set(['low', 'standard', 'high']);

const APPROVAL_LINE_RE = /(?:^|\n)[ \t]*Approval:[ \t]*Approved\b/g;
const SECOND_APPROVAL_RE = /(?:^|\n)[ \t]*Second Approval:[ \t]*Approved\b/g;
const STATUS_LINE_RE = /^[ \t]*Status:[ \t]*.*$/gm;
const AMENDMENT_HEADING_RE = /^(#{2,3})[ \t]+Spec Amendments[ \t]*$/im;
const IDENTIFIER_LINE_RE =
  /^[ \t]*(?:[-*+]|\d+\.)?[ \t]*(?:\*\*)?((?:REQ|AC)-\d+)(?:[ \t]*[（(][^）)\n]+[）)])?(?:\*\*)?[ \t]*[:：][^\n]*$/gm;
const PLACEHOLDER_AMENDMENT_RE = /^(?:[-*+]\s*)?(?:none|n\/a|\(none\)|（なし）|なし|（初期版のため変更なし）|\(initial\s+version[^)]*\))$/i;

export function normalizeNewlines(text) {
  return typeof text === 'string' ? text.replace(/\r\n/g, '\n').replace(/\r/g, '\n') : '';
}

export function sha256Text(text) {
  return crypto.createHash('sha256').update(normalizeNewlines(text), 'utf8').digest('hex');
}

export function toPosixPath(filePath) {
  return String(filePath || '').replace(/\\/g, '/');
}

export function safeRealpath(targetPath) {
  try {
    return fs.realpathSync(targetPath);
  } catch {
    return path.resolve(targetPath);
  }
}

export function findGitRoot(startDir) {
  let current = path.resolve(startDir || process.cwd());
  for (let i = 0; i < 25; i += 1) {
    if (fs.existsSync(path.join(current, '.git'))) {
      return current;
    }
    const parent = path.dirname(current);
    if (parent === current) break;
    current = parent;
  }
  return null;
}

export function findProjectRoot(startDir) {
  const envRoot = process.env.CLAUDE_PROJECT_DIR || process.env.SDD_PROJECT_ROOT;
  if (envRoot && fs.existsSync(envRoot)) {
    return safeRealpath(envRoot);
  }
  const gitRoot = findGitRoot(startDir || process.cwd());
  if (gitRoot) return safeRealpath(gitRoot);
  return safeRealpath(startDir || process.cwd());
}

function stripYamlComment(line) {
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

export function loadGuardrailsConfig(projectRoot) {
  const root = safeRealpath(projectRoot || findProjectRoot());
  const jsonPath = path.join(root, 'sdd', 'guardrails.json');
  const yamlPath = path.join(root, 'sdd', 'guardrails.yaml');

  let parsed = null;
  let sourcePath = null;
  try {
    if (fs.existsSync(jsonPath)) {
      parsed = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
      sourcePath = jsonPath;
    } else if (fs.existsSync(yamlPath)) {
      parsed = parseSimpleYaml(fs.readFileSync(yamlPath, 'utf8'));
      sourcePath = yamlPath;
    }
  } catch {
    parsed = null;
  }

  const sg = parsed && typeof parsed.spec_guard === 'object' && parsed.spec_guard ? parsed.spec_guard : {};
  const rv = parsed && typeof parsed.review === 'object' && parsed.review ? parsed.review : {};
  const rd = parsed && typeof parsed.risk_defaults === 'object' && parsed.risk_defaults ? parsed.risk_defaults : {};

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

export function toProjectRelativePath(filePath, projectRoot, cwd) {
  if (!filePath) return null;
  const root = safeRealpath(projectRoot);
  const abs = path.isAbsolute(filePath)
    ? filePath
    : path.resolve(cwd || root, filePath);

  let resolvedAbs = abs;
  if (fs.existsSync(abs)) {
    resolvedAbs = safeRealpath(abs);
  } else {
    const parent = path.dirname(abs);
    if (fs.existsSync(parent)) {
      resolvedAbs = path.join(safeRealpath(parent), path.basename(abs));
    }
  }

  const rel = path.relative(root, resolvedAbs);
  if (rel.startsWith('..') || path.isAbsolute(rel)) {
    return null;
  }
  return toPosixPath(rel);
}

export function matchProtectedSpecPath(filePath, projectRoot, config, cwd) {
  const rel = toProjectRelativePath(filePath, projectRoot, cwd);
  if (!rel) return null;

  const globs = (config && config.spec_guard && config.spec_guard.protected_globs) || DEFAULT_CONFIG.spec_guard.protected_globs;
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
  const normalized = normalizeNewlines(text);
  const primary = (normalized.match(APPROVAL_LINE_RE) || []).length;
  const second = (normalized.match(SECOND_APPROVAL_RE) || []).length;
  return Math.max(0, primary - second);
}

export function isFeatureApproved(projectRoot, feature) {
  if (!feature) return false;
  const featureDir = path.join(projectRoot, 'specs', feature);
  const baselinePath = path.join(featureDir, '.spec-baseline.json');
  if (fs.existsSync(baselinePath)) {
    return true;
  }
  const tasksPath = path.join(featureDir, 'tasks.md');
  if (fs.existsSync(tasksPath)) {
    try {
      const content = fs.readFileSync(tasksPath, 'utf8');
      return countPrimaryApprovals(content) > 0;
    } catch {
      return false;
    }
  }
  return false;
}

/**
 * Split a Markdown document into { beforeAmendments, amendmentsBody, afterAmendments, hasHeading }.
 */
export function splitSpecAmendments(text) {
  const normalized = normalizeNewlines(text);
  const match = AMENDMENT_HEADING_RE.exec(normalized);
  if (!match) {
    return {
      beforeAmendments: normalized,
      amendmentsBody: '',
      afterAmendments: '',
      hasHeading: false,
    };
  }

  const headingLevel = match[1].length;
  const headingStart = match.index;
  const afterHeadingStart = headingStart + match[0].length;
  const rest = normalized.slice(afterHeadingStart);

  const nextHeadingRe = new RegExp(`^#{1,${headingLevel}}[ \\t]+\\S`, 'm');
  const nextMatch = nextHeadingRe.exec(rest);

  if (!nextMatch) {
    return {
      beforeAmendments: normalized.slice(0, headingStart).trimEnd(),
      amendmentsBody: rest.trim(),
      afterAmendments: '',
      hasHeading: true,
    };
  }

  return {
    beforeAmendments: normalized.slice(0, headingStart).trimEnd(),
    amendmentsBody: rest.slice(0, nextMatch.index).trim(),
    afterAmendments: rest.slice(nextMatch.index).trimStart(),
    hasHeading: true,
  };
}

export function extractAmendmentEntries(text) {
  const { hasHeading, amendmentsBody } = splitSpecAmendments(text);
  if (!hasHeading || !amendmentsBody) return [];

  const entries = [];
  for (const line of amendmentsBody.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed) continue;
    if (PLACEHOLDER_AMENDMENT_RE.test(trimmed)) continue;
    entries.push(trimmed);
  }
  return entries;
}

/**
 * Produce the canonical contract text used to detect substantive spec mutations.
 * - Always removes the Spec Amendments section so recording an amendment never counts as body drift.
 * - For tasks.md, also strips Status: lines so normal task lifecycle updates remain CLEAN.
 */
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

export function appendDriftEvent(projectRoot, event) {
  try {
    const sddDir = path.join(projectRoot, '.sdd');
    fs.mkdirSync(sddDir, { recursive: true });
    const record = {
      timestamp: new Date().toISOString(),
      ...event,
    };
    fs.appendFileSync(path.join(sddDir, 'drift-events.jsonl'), `${JSON.stringify(record)}\n`, 'utf8');
  } catch {
    // Non-fatal: advisory logging must never crash the hook.
  }
}
