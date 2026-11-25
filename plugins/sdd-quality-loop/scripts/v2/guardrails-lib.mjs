#!/usr/bin/env node
/**
 * Shared library for SDD Forge v2 Lightweight Guardrails.
 * Zero external dependencies — Node.js >= 20 LTS built-in modules only.
 *
 * Pure string/regex/YAML/hash helpers live in `./v2-pure-lib.mjs` so that
 * read-only consumers (including `sdd-forge-mcp`) never pull in filesystem
 * write APIs or `process.env` root escalation.
 */
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import {
  DEFAULT_CONFIG,
  VALID_MODES,
  VALID_PRE_IMPL,
  VALID_RISK_TIERS,
  assertValidFeatureName,
  canonicalSpecContractText,
  countDomainModelApprovals,
  countPrimaryApprovals,
  extractAmendmentEntries,
  extractAmendmentEntriesWithLines,
  extractSpecIdentifiers,
  globToRegExp,
  isSafeSpecEditOnly,
  matchProtectedSpecRelPath,
  normalizeGuardrailsConfig,
  normalizeNewlines,
  normalizeRelPath,
  parseSimpleYaml,
  sanitizeRelPath,
  sha256Text,
  splitSpecAmendments,
  toPosixPath,
} from './v2-pure-lib.mjs';

export {
  DEFAULT_CONFIG,
  VALID_MODES,
  VALID_PRE_IMPL,
  VALID_RISK_TIERS,
  assertValidFeatureName,
  canonicalSpecContractText,
  countDomainModelApprovals,
  countPrimaryApprovals,
  extractAmendmentEntries,
  extractAmendmentEntriesWithLines,
  extractSpecIdentifiers,
  globToRegExp,
  isSafeSpecEditOnly,
  matchProtectedSpecRelPath,
  normalizeGuardrailsConfig,
  normalizeNewlines,
  normalizeRelPath,
  parseSimpleYaml,
  sanitizeRelPath,
  sha256Text,
  splitSpecAmendments,
  toPosixPath,
};

const MAX_READ_BYTES = 8 * 1024 * 1024;

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

/**
 * Resolves project root for CLI scripts:
 * - If an explicit `projectRoot` is provided, honors it strictly (never overridden by
 *   `CLAUDE_PROJECT_DIR` or parent `.git` walk) so cross-repo invocations are deterministic.
 * - Otherwise falls back to `findProjectRoot(process.cwd())`.
 */
/**
 * True when the module at `importMetaUrl` is the script Node was asked to run.
 * Compares real paths: Node resolves the main module through symlinks, so a
 * plain argv[1] comparison silently skipped main() for any CLI (the soft guard
 * hook included) launched through a link (#869). `scriptFileName` is the
 * CLI's own file name.
 */
export function isMainModule(importMetaUrl, scriptFileName) {
  const entry = process.argv[1];
  if (!entry) return false;
  try {
    const real = fs.realpathSync(path.resolve(entry));
    // The file-name check keeps a CLI embedded in a bundle (where the bundle
    // is both argv[1] and import.meta.url) from running its main().
    return path.basename(real) === scriptFileName && real === fs.realpathSync(fileURLToPath(importMetaUrl));
  } catch {
    return false;
  }
}

export function resolveExplicitOrAutoRoot(projectRoot) {
  if (projectRoot) {
    return safeRealpath(projectRoot);
  }
  return findProjectRoot(process.cwd());
}

function isWithinRoot(rootReal, targetReal) {
  const rel = path.relative(rootReal, targetReal);
  return rel === '' || (!rel.startsWith('..') && !path.isAbsolute(rel));
}

/**
 * Creates a strictly root-contained read-only IO facade for local v2 CLI scripts.
 * Rejects path traversal and symlinks escaping `projectRoot`.
 */
export function createFsReadonlyIo(projectRoot) {
  const rootReal = safeRealpath(projectRoot);

  function resolveSafe(relPath) {
    const safeRel = sanitizeRelPath(relPath);
    if (!safeRel) return null;
    const abs = path.join(rootReal, ...safeRel.split('/'));
    let real;
    try {
      real = fs.realpathSync(abs);
    } catch {
      return null;
    }
    if (!isWithinRoot(rootReal, real)) {
      return null;
    }
    return real;
  }

  return {
    exists(relPath) {
      const real = resolveSafe(relPath);
      return real !== null;
    },
    existsDir(relPath) {
      const real = resolveSafe(relPath);
      if (!real) return false;
      try {
        return fs.statSync(real).isDirectory();
      } catch {
        return false;
      }
    },
    // Present but over MAX_READ_BYTES (or not a regular file): readText gives
    // null for it just as for a missing file (#834).
    existsButUnreadable(relPath) {
      return resolveSafe(relPath) !== null;
    },
    canonicalRelPath(relPath) {
      const real = resolveSafe(relPath);
      if (!real) return null;
      return path.relative(rootReal, real).split(path.sep).join('/');
    },
    readText(relPath) {
      const real = resolveSafe(relPath);
      if (!real) return null;
      try {
        const stat = fs.statSync(real);
        if (!stat.isFile() || stat.size > MAX_READ_BYTES) return null;
        return fs.readFileSync(real, 'utf8');
      } catch {
        return null;
      }
    },
    readBytes(relPath) {
      const real = resolveSafe(relPath);
      if (!real) return null;
      try {
        const stat = fs.statSync(real);
        if (!stat.isFile() || stat.size > MAX_READ_BYTES) return null;
        return fs.readFileSync(real);
      } catch {
        return null;
      }
    },
    listDir(relDir) {
      let realDir;
      if (!relDir) {
        realDir = rootReal;
      } else {
        realDir = resolveSafe(relDir);
      }
      if (!realDir) return [];
      try {
        const entries = fs.readdirSync(realDir, { withFileTypes: true });
        const out = [];
        for (const entry of entries) {
          const childAbs = path.join(realDir, entry.name);
          let childReal;
          try {
            childReal = fs.realpathSync(childAbs);
          } catch {
            continue;
          }
          if (!isWithinRoot(rootReal, childReal)) continue;
          let st;
          try {
            st = fs.statSync(childReal);
          } catch {
            continue;
          }
          out.push({
            name: entry.name,
            isFile: st.isFile(),
            isDirectory: st.isDirectory(),
          });
        }
        return out.sort((a, b) => a.name.localeCompare(b.name));
      } catch {
        return [];
      }
    },
    statMtimeMs(relPath) {
      const real = resolveSafe(relPath);
      if (!real) return null;
      try {
        const st = fs.statSync(real);
        return Number.isFinite(st.mtimeMs) ? st.mtimeMs : null;
      } catch {
        return null;
      }
    },
  };
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

  return normalizeGuardrailsConfig(parsed, sourcePath);
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
  return matchProtectedSpecRelPath(rel, config);
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
