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
  formal_verification: {
    enabled: false,
    mode: 'shadow',
    checker: {
      adapter: 'tlc',
      adapter_options: {
        tlc: {},
        apalache: {},
        lean4: {},
      },
    },
    trigger_tiers: ['high'],
  },
  agent_lint: {
    enabled: false,
    mode: 'shadow',
    diff_only: true,
    waivers: [],
  },
  security_audit: {
    enabled: false,
    mode: 'shadow',
    enabled_adapters: ['builtin-secret-pattern', 'builtin-slopsquatting'],
  },
  anti_tampering: {
    enabled: true,
    mode: 'strict',
    base_ref: 'HEAD',
    retirements_manifest: 'sdd/approved-test-retirements.json',
    protected_repo_paths: [
      'sdd/guardrails.yaml',
      'sdd/approved-test-retirements.json',
      '.github/workflows/**',
      'CODEOWNERS',
    ],
  },
});

export const VALID_MODES = new Set(['warn', 'confirm', 'strict']);
export const VALID_PRE_IMPL = new Set(['auto', 'always', 'off']);
export const VALID_RISK_TIERS = new Set(['low', 'standard', 'high']);
export const VALID_FORMAL_ADAPTERS = new Set(['tlc', 'apalache', 'lean4', 'none']);
export const VALID_SECURITY_ADAPTERS = new Set([
  'builtin-secret-pattern',
  'builtin-slopsquatting',
  'semgrep',
  'gitleaks',
  'trufflehog',
  'codeql',
  'socket',
]);
export const VALID_GATE_MODES = new Set(['off', 'shadow', 'warn', 'strict']);
export const VALID_ANTI_TAMPER_MODES = new Set(['off', 'warn', 'strict']);

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
  if (trimmed === '[]') return [];
  if (trimmed === '{}') return {};
  if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
    const inner = trimmed.slice(1, -1).trim();
    if (!inner) return [];
    return inner.split(',').map((item) => parseYamlScalar(item));
  }
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
 * Minimal deterministic parser for nested YAML config files
 * (maps, scalars, scalar lists, and lists of maps).
 */
export function parseSimpleYaml(text) {
  const rawLines = normalizeNewlines(text).split('\n');
  const tokens = [];
  for (const rawLine of rawLines) {
    const cleaned = stripYamlComment(rawLine).replace(/\s+$/, '');
    if (!cleaned.trim()) continue;
    const indent = cleaned.length - cleaned.trimStart().length;
    tokens.push({ indent, content: cleaned.trim() });
  }

  function parseBlock(startIdx, minIndent) {
    if (startIdx >= tokens.length) return { value: {}, nextIdx: startIdx };
    const first = tokens[startIdx];
    if (first.content.startsWith('- ') || first.content === '-') {
      const list = [];
      let i = startIdx;
      while (i < tokens.length && tokens[i].indent === first.indent && (tokens[i].content.startsWith('- ') || tokens[i].content === '-')) {
        const afterDash = tokens[i].content === '-' ? '' : tokens[i].content.slice(2).trim();
        const itemIndent = tokens[i].indent;
        i += 1;
        if (!afterDash) {
          if (i < tokens.length && tokens[i].indent > itemIndent) {
            const sub = parseBlock(i, tokens[i].indent);
            list.push(sub.value);
            i = sub.nextIdx;
          } else {
            list.push(null);
          }
          continue;
        }
        const colonIdx = afterDash.indexOf(':');
        const looksLikeMapEntry =
          colonIdx > 0 &&
          !afterDash.startsWith('"') &&
          !afterDash.startsWith("'") &&
          (colonIdx === afterDash.length - 1 || afterDash[colonIdx + 1] === ' ');
        if (looksLikeMapEntry) {
          const obj = {};
          const k = afterDash.slice(0, colonIdx).trim();
          const rest = afterDash.slice(colonIdx + 1).trim();
          if (rest === '') {
            if (i < tokens.length && tokens[i].indent > itemIndent) {
              const sub = parseBlock(i, tokens[i].indent);
              obj[k] = sub.value;
              i = sub.nextIdx;
            } else {
              obj[k] = {};
            }
          } else {
            obj[k] = parseYamlScalar(rest);
          }
          while (i < tokens.length && tokens[i].indent > itemIndent) {
            const propLine = tokens[i].content;
            if (propLine.startsWith('- ')) break;
            const cIdx = propLine.indexOf(':');
            if (cIdx === -1) {
              i += 1;
              continue;
            }
            const pk = propLine.slice(0, cIdx).trim();
            const prest = propLine.slice(cIdx + 1).trim();
            const pIndent = tokens[i].indent;
            i += 1;
            if (prest === '') {
              if (i < tokens.length && tokens[i].indent > pIndent) {
                const sub = parseBlock(i, tokens[i].indent);
                obj[pk] = sub.value;
                i = sub.nextIdx;
              } else {
                obj[pk] = [];
              }
            } else {
              obj[pk] = parseYamlScalar(prest);
            }
          }
          list.push(obj);
        } else {
          list.push(parseYamlScalar(afterDash));
        }
      }
      return { value: list, nextIdx: i };
    }

    const map = {};
    let i = startIdx;
    while (i < tokens.length && tokens[i].indent >= minIndent) {
      if (tokens[i].indent > minIndent) {
        i += 1;
        continue;
      }
      const line = tokens[i].content;
      if (line.startsWith('- ')) break;
      const idx = line.indexOf(':');
      if (idx === -1) {
        i += 1;
        continue;
      }
      const key = line.slice(0, idx).trim();
      const rest = line.slice(idx + 1).trim();
      const keyIndent = tokens[i].indent;
      i += 1;
      if (rest === '') {
        if (i < tokens.length && tokens[i].indent > keyIndent) {
          const sub = parseBlock(i, tokens[i].indent);
          map[key] = sub.value;
          i = sub.nextIdx;
        } else {
          map[key] = {};
        }
      } else {
        map[key] = parseYamlScalar(rest);
      }
    }
    return { value: map, nextIdx: i };
  }

  if (tokens.length === 0) return {};
  return parseBlock(0, tokens[0].indent).value;
}

function findForbiddenKeys(obj, prefix, forbiddenNames, out = []) {
  if (!obj || typeof obj !== 'object') return out;
  if (Array.isArray(obj)) {
    obj.forEach((item, idx) => findForbiddenKeys(item, `${prefix}[${idx}]`, forbiddenNames, out));
    return out;
  }
  for (const [k, v] of Object.entries(obj)) {
    const keyPath = prefix ? `${prefix}.${k}` : k;
    if (forbiddenNames.has(k.toLowerCase())) {
      out.push(keyPath);
    }
    if (v && typeof v === 'object') {
      findForbiddenKeys(v, keyPath, forbiddenNames, out);
    }
  }
  return out;
}

/**
 * Validates optional ADR-0054 v2.2 guardrails extensions (REQ-009, REQ-012).
 * Rejects arbitrary `command` keys in `security_audit` / `formal_verification`
 * and rejects any formal or security adapter outside the fixed allowlists.
 */
export function validateGuardrailsExtensions(parsed) {
  const errors = [];
  if (!parsed || typeof parsed !== 'object') return errors;

  const forbiddenNames = new Set(['command', 'shell', 'exec', 'cmd']);

  if (parsed.formal_verification && typeof parsed.formal_verification === 'object') {
    const fv = parsed.formal_verification;
    for (const kp of findForbiddenKeys(fv, 'formal_verification', forbiddenNames)) {
      errors.push({
        code: 'FORBIDDEN_COMMAND_KEY',
        path: kp,
        message: `任意コマンド実行キー (${kp}) は禁止されています（固定アダプタアローリストのみ許可）`,
        action: `${kp} を削除し、formal_verification.checker.adapter に tlc | apalache | lean4 | none を指定してください`,
      });
    }
    if (fv.mode !== undefined && !VALID_GATE_MODES.has(fv.mode)) {
      errors.push({
        code: 'INVALID_GATE_MODE',
        path: 'formal_verification.mode',
        message: `不正な formal_verification.mode: ${fv.mode}`,
        action: 'off | shadow | warn | strict のいずれかを指定してください',
      });
    }
    const adapter = fv.checker && typeof fv.checker === 'object' ? fv.checker.adapter : fv.adapter;
    if (adapter !== undefined && !VALID_FORMAL_ADAPTERS.has(String(adapter))) {
      errors.push({
        code: 'UNALLOWED_FORMAL_ADAPTER',
        path: 'formal_verification.checker.adapter',
        message: `未許可の形式検証アダプタ: ${adapter}`,
        action: `許可されたアダプタ (${[...VALID_FORMAL_ADAPTERS].join(' | ')}) のいずれかを指定してください`,
      });
    }
  }

  if (parsed.agent_lint && typeof parsed.agent_lint === 'object') {
    const al = parsed.agent_lint;
    if (al.mode !== undefined && !VALID_GATE_MODES.has(al.mode)) {
      errors.push({
        code: 'INVALID_GATE_MODE',
        path: 'agent_lint.mode',
        message: `不正な agent_lint.mode: ${al.mode}`,
        action: 'off | shadow | warn | strict のいずれかを指定してください',
      });
    }
    if (Array.isArray(al.waivers)) {
      al.waivers.forEach((w, idx) => {
        if (!w || typeof w !== 'object' || !w.rule || !w.path || !/^\d{4}-\d{2}-\d{2}$/.test(String(w.expires_on || ''))) {
          errors.push({
            code: 'INVALID_WAIVER_ENTRY',
            path: `agent_lint.waivers[${idx}]`,
            message: `agent_lint.waivers[${idx}] に必須項目 (rule, path, expires_on: YYYY-MM-DD) が不足しています`,
            action: 'rule, path, reason, expires_on (YYYY-MM-DD) を明記してください',
          });
        }
      });
    }
  }

  if (parsed.security_audit && typeof parsed.security_audit === 'object') {
    const sa = parsed.security_audit;
    for (const kp of findForbiddenKeys(sa, 'security_audit', forbiddenNames)) {
      errors.push({
        code: 'FORBIDDEN_COMMAND_KEY',
        path: kp,
        message: `security_audit 内の任意コマンド実行キー (${kp}) は禁止されています`,
        action: `${kp} を削除し、security_audit.enabled_adapters に許可アダプタ ID のみ指定してください`,
      });
    }
    if (sa.mode !== undefined && !VALID_GATE_MODES.has(sa.mode)) {
      errors.push({
        code: 'INVALID_GATE_MODE',
        path: 'security_audit.mode',
        message: `不正な security_audit.mode: ${sa.mode}`,
        action: 'off | shadow | warn | strict のいずれかを指定してください',
      });
    }
    if (sa.enabled_adapters !== undefined) {
      if (!Array.isArray(sa.enabled_adapters)) {
        errors.push({
          code: 'INVALID_SECURITY_ADAPTERS',
          path: 'security_audit.enabled_adapters',
          message: 'security_audit.enabled_adapters は配列で指定してください',
          action: `許可アダプタ (${[...VALID_SECURITY_ADAPTERS].join(', ')}) の配列を指定してください`,
        });
      } else {
        for (const adapter of sa.enabled_adapters) {
          if (!VALID_SECURITY_ADAPTERS.has(String(adapter))) {
            errors.push({
              code: 'UNALLOWED_SECURITY_ADAPTER',
              path: 'security_audit.enabled_adapters',
              message: `未許可のセキュリティアダプタ: ${adapter}`,
              action: `許可されたアダプタ (${[...VALID_SECURITY_ADAPTERS].join(', ')}) のみ指定してください`,
            });
          }
        }
      }
    }
  }

  if (parsed.anti_tampering && typeof parsed.anti_tampering === 'object') {
    const at = parsed.anti_tampering;
    if (at.mode !== undefined && !VALID_ANTI_TAMPER_MODES.has(at.mode)) {
      errors.push({
        code: 'INVALID_ANTI_TAMPER_MODE',
        path: 'anti_tampering.mode',
        message: `不正な anti_tampering.mode: ${at.mode}`,
        action: 'off | warn | strict のいずれかを指定してください',
      });
    }
  }

  return errors;
}

export function normalizeGuardrailsConfig(parsed, sourcePath = null) {
  const sg = parsed && typeof parsed.spec_guard === 'object' && parsed.spec_guard ? parsed.spec_guard : {};
  const rv = parsed && typeof parsed.review === 'object' && parsed.review ? parsed.review : {};
  const rd = parsed && typeof parsed.risk_defaults === 'object' && parsed.risk_defaults ? parsed.risk_defaults : {};
  const lm = parsed && typeof parsed.limits === 'object' && parsed.limits ? parsed.limits : {};
  const fv = parsed && typeof parsed.formal_verification === 'object' && parsed.formal_verification ? parsed.formal_verification : {};
  const al = parsed && typeof parsed.agent_lint === 'object' && parsed.agent_lint ? parsed.agent_lint : {};
  const sa = parsed && typeof parsed.security_audit === 'object' && parsed.security_audit ? parsed.security_audit : {};
  const at = parsed && typeof parsed.anti_tampering === 'object' && parsed.anti_tampering ? parsed.anti_tampering : {};

  const maxAutoFix =
    typeof lm.max_auto_fix_rounds === 'number' &&
    Number.isInteger(lm.max_auto_fix_rounds) &&
    lm.max_auto_fix_rounds >= 0 &&
    lm.max_auto_fix_rounds <= 10
      ? lm.max_auto_fix_rounds
      : DEFAULT_CONFIG.limits.max_auto_fix_rounds;

  const fvChecker = fv.checker && typeof fv.checker === 'object' ? fv.checker : {};
  const fvAdapter = VALID_FORMAL_ADAPTERS.has(fvChecker.adapter)
    ? fvChecker.adapter
    : VALID_FORMAL_ADAPTERS.has(fv.adapter)
      ? fv.adapter
      : DEFAULT_CONFIG.formal_verification.checker.adapter;
  const fvAdapterOpts = fvChecker.adapter_options && typeof fvChecker.adapter_options === 'object' ? fvChecker.adapter_options : {};

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
    formal_verification: {
      enabled: typeof fv.enabled === 'boolean' ? fv.enabled : DEFAULT_CONFIG.formal_verification.enabled,
      mode: VALID_GATE_MODES.has(fv.mode) ? fv.mode : DEFAULT_CONFIG.formal_verification.mode,
      checker: {
        adapter: fvAdapter,
        adapter_options: {
          tlc: fvAdapterOpts.tlc && typeof fvAdapterOpts.tlc === 'object' ? { ...fvAdapterOpts.tlc } : {},
          apalache: fvAdapterOpts.apalache && typeof fvAdapterOpts.apalache === 'object' ? { ...fvAdapterOpts.apalache } : {},
          lean4: fvAdapterOpts.lean4 && typeof fvAdapterOpts.lean4 === 'object' ? { ...fvAdapterOpts.lean4 } : {},
        },
      },
      trigger_tiers:
        Array.isArray(fv.trigger_tiers) && fv.trigger_tiers.length > 0
          ? fv.trigger_tiers.map((t) => String(t))
          : [...DEFAULT_CONFIG.formal_verification.trigger_tiers],
    },
    agent_lint: {
      enabled: typeof al.enabled === 'boolean' ? al.enabled : DEFAULT_CONFIG.agent_lint.enabled,
      mode: VALID_GATE_MODES.has(al.mode) ? al.mode : DEFAULT_CONFIG.agent_lint.mode,
      diff_only: typeof al.diff_only === 'boolean' ? al.diff_only : DEFAULT_CONFIG.agent_lint.diff_only,
      waivers: Array.isArray(al.waivers) ? al.waivers.filter((w) => w && typeof w === 'object') : [],
    },
    security_audit: {
      enabled: typeof sa.enabled === 'boolean' ? sa.enabled : DEFAULT_CONFIG.security_audit.enabled,
      mode: VALID_GATE_MODES.has(sa.mode) ? sa.mode : DEFAULT_CONFIG.security_audit.mode,
      enabled_adapters:
        Array.isArray(sa.enabled_adapters) && sa.enabled_adapters.length > 0
          ? sa.enabled_adapters.map((a) => String(a)).filter((a) => VALID_SECURITY_ADAPTERS.has(a))
          : [...DEFAULT_CONFIG.security_audit.enabled_adapters],
    },
    anti_tampering: {
      enabled: typeof at.enabled === 'boolean' ? at.enabled : DEFAULT_CONFIG.anti_tampering.enabled,
      mode: VALID_ANTI_TAMPER_MODES.has(at.mode) ? at.mode : DEFAULT_CONFIG.anti_tampering.mode,
      base_ref: typeof at.base_ref === 'string' && at.base_ref.trim() ? at.base_ref.trim() : DEFAULT_CONFIG.anti_tampering.base_ref,
      retirements_manifest:
        typeof at.retirements_manifest === 'string' && at.retirements_manifest.trim()
          ? at.retirements_manifest.trim()
          : DEFAULT_CONFIG.anti_tampering.retirements_manifest,
      protected_repo_paths:
        Array.isArray(at.protected_repo_paths) && at.protected_repo_paths.length > 0
          ? at.protected_repo_paths.map((p) => String(p))
          : [...DEFAULT_CONFIG.anti_tampering.protected_repo_paths],
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
