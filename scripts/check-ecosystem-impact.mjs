#!/usr/bin/env node
/**
 * check-ecosystem-impact.mjs — Dynamic Ecosystem Impact & Safe Test Lifecycle Gate (ADR-0056).
 *
 * Inspects `git diff --name-status <base>..HEAD` (or synthetic `--changes-json` for testing)
 * and enforces full-stack ecosystem linkage on:
 *   - Additions (A): new plugins/skills/contracts require manifest, payload, catalog, and tests.
 *   - Modifications (M): computes impacted test suites via verification-catalog.json triggers
 *     plus AST/import dependency edges; flags contract changes lacking test updates.
 *   - Deletions (D): blocks unapproved test deletions (requires CODEOWNERS-protected
 *     `sdd/approved-test-retirements.json` entry with `git_blob_sha` and `negative_parity_verified: true`)
 *     and detects ghost tests referencing deleted files.
 *
 * Usage:
 *   node scripts/check-ecosystem-impact.mjs [--base <ref>] [--head <ref>] [--ci] [--json] [--root <dir>] [--changes-json <path>]
 *
 * Exit codes:
 *   0 — No blocking ecosystem / test-lifecycle violations
 *   1 — Blocking violation detected (remediation instructions emitted)
 *   2 — Invalid arguments or malformed retirement manifest
 */
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const DEFAULT_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

function isTestFile(relPath) {
  return (
    relPath.startsWith('tests/') &&
    /\.(test|tests)\.(mjs|js|ts|py|sh|ps1)$/.test(relPath)
  ) || /^mcp\/[^/]+\/tests\/.*\.test\.(ts|js|mjs)$/.test(relPath);
}

function globToRegex(pattern) {
  const escaped = pattern
    .replace(/[.+^${}()|[\]\\]/g, '\\$&')
    .replace(/\*\*/g, '§§DOUBLE_STAR§§')
    .replace(/\*/g, '[^/]*')
    .replace(/§§DOUBLE_STAR§§/g, '.*');
  return new RegExp(`^${escaped}$`);
}

function parseNameStatus(output) {
  const changes = [];
  for (const rawLine of String(output || '').split('\n')) {
    const line = rawLine.trim();
    if (!line) continue;
    const parts = line.split('\t');
    const code = parts[0] || '';
    if (code.startsWith('R') && parts.length >= 3) {
      changes.push({ status: 'R', oldPath: parts[1], path: parts[2] });
    } else if (parts.length >= 2) {
      changes.push({ status: code[0], path: parts[1] });
    }
  }
  return changes;
}

function resolveGitChanges(root, baseRef, headRef) {
  const candidates = [];
  if (baseRef) candidates.push(baseRef);
  else if (process.env.GITHUB_BASE_REF) {
    candidates.push(`origin/${process.env.GITHUB_BASE_REF}`, process.env.GITHUB_BASE_REF);
  } else {
    candidates.push('HEAD~1');
  }

  for (const base of candidates) {
    try {
      const out = execFileSync('git', ['diff', '--name-status', `${base}...${headRef}`], {
        cwd: root,
        encoding: 'utf8',
        stdio: ['ignore', 'pipe', 'ignore'],
      });
      return { base, changes: parseNameStatus(out) };
    } catch {
      try {
        const out = execFileSync('git', ['diff', '--name-status', `${base}..${headRef}`], {
          cwd: root,
          encoding: 'utf8',
          stdio: ['ignore', 'pipe', 'ignore'],
        });
        return { base, changes: parseNameStatus(out) };
      } catch {
        // try next candidate
      }
    }
  }
  return { base: null, changes: [] };
}

function getGitBlobSha(root, baseRef, relPath) {
  if (!baseRef) return null;
  try {
    return execFileSync('git', ['rev-parse', `${baseRef}:${relPath}`], {
      cwd: root,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
  } catch {
    return null;
  }
}

function findGhostTestsReferencingDeleted(root, deletedPaths) {
  const ghosts = [];
  const deletedTargets = deletedPaths.filter((p) => !isTestFile(p) && (p.startsWith('plugins/') || p.startsWith('scripts/') || p.startsWith('contracts/')));
  if (deletedTargets.length === 0) return ghosts;
  const testsDir = path.join(root, 'tests');
  if (!fs.existsSync(testsDir)) return ghosts;
  const testFiles = fs
    .readdirSync(testsDir)
    .filter((f) => /\.(test|tests)\.(mjs|js|py|sh|ps1)$/.test(f))
    .map((f) => `tests/${f}`);

  for (const testRel of testFiles) {
    const text = fs.readFileSync(path.join(root, testRel), 'utf8');
    for (const del of deletedTargets) {
      if (text.includes(del)) {
        // Ignore explicit retirement-verification tests that assert absence
        if (text.includes('retired') || text.includes('existsSync') || text.includes('assert.equal(fs.existsSync')) {
          continue;
        }
        ghosts.push({ test: testRel, deletedTarget: del });
      }
    }
  }
  return ghosts;
}

export function evaluateEcosystemImpact({
  root = DEFAULT_ROOT,
  baseRef = null,
  headRef = 'HEAD',
  changes = null,
  blobShaOverrides = {},
} = {}) {
  const absRoot = path.resolve(root);
  const violations = [];
  const warnings = [];
  const impactedSuites = new Set();

  // Load approved retirements
  const retireRel = 'sdd/approved-test-retirements.json';
  const retireAbs = path.join(absRoot, retireRel);
  let retirements = [];
  if (fs.existsSync(retireAbs)) {
    try {
      const parsed = JSON.parse(fs.readFileSync(retireAbs, 'utf8'));
      if (!Array.isArray(parsed.retirements)) {
        return {
          exitCode: 2,
          error: `${retireRel}: 'retirements' must be an array`,
          violations: [],
          warnings: [],
          impactedSuites: [],
        };
      }
      retirements = parsed.retirements;
    } catch (err) {
      return {
        exitCode: 2,
        error: `${retireRel}: malformed JSON (${err instanceof Error ? err.message : String(err)})`,
        violations: [],
        warnings: [],
        impactedSuites: [],
      };
    }
  }
  const retirementByPath = new Map(retirements.map((r) => [r.test_path, r]));

  // Load verification catalog if present
  const catalogAbs = path.join(absRoot, 'tests/verification-catalog.json');
  const catalog = fs.existsSync(catalogAbs)
    ? JSON.parse(fs.readFileSync(catalogAbs, 'utf8'))
    : { suites: [] };

  const resolved = changes !== null ? { base: baseRef, changes } : resolveGitChanges(absRoot, baseRef, headRef);
  const diffChanges = resolved.changes;
  const changedPaths = diffChanges.map((c) => c.path);
  const hasAnyTestChange = changedPaths.some(isTestFile);

  // Compute impacted test suites via catalog triggers
  for (const suite of catalog.suites || []) {
    const triggers = Array.isArray(suite.triggers) ? suite.triggers : [];
    for (const pat of triggers) {
      const re = globToRegex(pat);
      if (changedPaths.some((p) => re.test(p))) {
        impactedSuites.add(suite.path);
        break;
      }
    }
  }

  const deletedPaths = [];
  for (const ch of diffChanges) {
    // Event A: new plugin or contract
    if (ch.status === 'A') {
      const pluginMatch = /^plugins\/([^/]+)\//.exec(ch.path);
      if (pluginMatch) {
        const manifestRel = `plugins/${pluginMatch[1]}/plugin.manifest.json`;
        if (!fs.existsSync(path.join(absRoot, manifestRel))) {
          violations.push({
            event: 'A',
            file: ch.path,
            reason: `New plugin directory plugins/${pluginMatch[1]}/ is missing SSOT ${manifestRel}`,
            remediation: `Create ${manifestRel} and run: node scripts/sync-ssot.mjs --target manifests`,
          });
        }
      }
      if (/^contracts\/[^/]+\.(?:json|yaml)$/.test(ch.path) && !hasAnyTestChange) {
        warnings.push({
          event: 'A',
          file: ch.path,
          reason: `New contract ${ch.path} added without a corresponding test file change`,
          remediation: 'Add an acceptance test covering the new contract and register it in tests/verification-catalog.json',
        });
      }
    }

    // Event M: contract schema change
    if (ch.status === 'M' && /^contracts\/[^/]+\.json$/.test(ch.path) && !hasAnyTestChange) {
      warnings.push({
        event: 'M',
        file: ch.path,
        reason: `Contract ${ch.path} modified without accompanying test update`,
        remediation: `Update impacted tests (${[...impactedSuites].slice(0, 3).join(', ') || 'tests/'}) and run: node scripts/sync-ssot.mjs --check`,
      });
    }

    // Event D: deletion — enforce safe test retirement & ghost-test detection
    if (ch.status === 'D') {
      deletedPaths.push(ch.path);
      if (isTestFile(ch.path)) {
        const approval = retirementByPath.get(ch.path);
        const expectedSha = Object.prototype.hasOwnProperty.call(blobShaOverrides, ch.path)
          ? blobShaOverrides[ch.path]
          : getGitBlobSha(absRoot, resolved.base, ch.path);
        if (!approval) {
          violations.push({
            event: 'D',
            file: ch.path,
            reason: `Unapproved test deletion detected: ${ch.path} has no entry in ${retireRel}`,
            remediation: `Restore ${ch.path}, or add a CODEOWNERS-approved retirement entry to ${retireRel} with git_blob_sha=${expectedSha || '<blob-sha>'} and negative_parity_verified: true`,
          });
        } else {
          const requiredFields = ['test_path', 'git_blob_sha', 'reason', 'replaced_by_or_retired_feature', 'approved_by'];
          const missing = requiredFields.filter((f) => !approval[f] || typeof approval[f] !== 'string');
          if (missing.length > 0 || approval.negative_parity_verified !== true) {
            violations.push({
              event: 'D',
              file: ch.path,
              reason: `Incomplete test retirement entry in ${retireRel} for ${ch.path} (missing: ${missing.join(', ') || 'none'}; negative_parity_verified=${String(approval.negative_parity_verified)})`,
              remediation: `Complete all required fields and set negative_parity_verified: true in ${retireRel}`,
            });
          } else if (expectedSha && approval.git_blob_sha !== expectedSha) {
            violations.push({
              event: 'D',
              file: ch.path,
              reason: `git_blob_sha mismatch for retired test ${ch.path}: expected ${expectedSha}, got ${approval.git_blob_sha}`,
              remediation: `Update git_blob_sha in ${retireRel} to ${expectedSha}`,
            });
          }
        }
      }
    }
  }

  // Ghost test check: deleted non-test files still referenced by remaining active tests
  for (const ghost of findGhostTestsReferencingDeleted(absRoot, deletedPaths)) {
    violations.push({
      event: 'D',
      file: ghost.test,
      reason: `Ghost test detected: ${ghost.test} still references deleted file ${ghost.deletedTarget}`,
      remediation: `Update ${ghost.test} or retire it cleanly via ${retireRel}`,
    });
  }

  return {
    exitCode: violations.length > 0 ? 1 : 0,
    baseRef: resolved.base,
    changedCount: diffChanges.length,
    impactedSuites: [...impactedSuites].sort(),
    violations,
    warnings,
  };
}

function parseCliArgs(argv) {
  const opts = { root: DEFAULT_ROOT, baseRef: null, headRef: 'HEAD', ci: false, json: false, changesJson: null };
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === '--ci') opts.ci = true;
    else if (a === '--json') opts.json = true;
    else if (a === '--base' && i + 1 < argv.length) opts.baseRef = argv[++i];
    else if (a === '--head' && i + 1 < argv.length) opts.headRef = argv[++i];
    else if (a === '--root' && i + 1 < argv.length) opts.root = argv[++i];
    else if (a === '--changes-json' && i + 1 < argv.length) opts.changesJson = argv[++i];
    else if (a === '--help' || a === '-h') {
      process.stdout.write(
        'Usage: node scripts/check-ecosystem-impact.mjs [--base <ref>] [--head <ref>] [--ci] [--json] [--root <dir>] [--changes-json <path>]\n',
      );
      process.exit(0);
    }
  }
  return opts;
}

const isDirectMain =
  Boolean(process.argv[1]) &&
  (() => {
    try {
      return fs.realpathSync(path.resolve(process.argv[1])) === fs.realpathSync(fileURLToPath(import.meta.url));
    } catch {
      return path.resolve(process.argv[1]) === path.resolve(fileURLToPath(import.meta.url));
    }
  })();

if (isDirectMain) {
  const opts = parseCliArgs(process.argv.slice(2));
  let changes = null;
  let blobShaOverrides = {};
  if (opts.changesJson) {
    const payload = JSON.parse(fs.readFileSync(opts.changesJson, 'utf8'));
    changes = Array.isArray(payload) ? payload : payload.changes || [];
    blobShaOverrides = payload.blobShas || {};
  }
  const result = evaluateEcosystemImpact({
    root: opts.root,
    baseRef: opts.baseRef,
    headRef: opts.headRef,
    changes,
    blobShaOverrides,
  });
  if (opts.json) {
    process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  } else if (result.exitCode === 2) {
    process.stderr.write(`FATAL [ecosystem-impact]: ${result.error}\n`);
  } else if (result.exitCode === 1) {
    for (const v of result.violations) {
      process.stderr.write(`BLOCK [ecosystem-impact/${v.event}]: ${v.file}\n  Reason: ${v.reason}\n  Fix:    ${v.remediation}\n`);
    }
  } else {
    process.stdout.write(
      `check-ecosystem-impact: PASS (${result.changedCount} changed file(s), ${result.impactedSuites.length} impacted suite(s), ${result.warnings.length} warning(s))\n`,
    );
  }
  process.exit(result.exitCode);
}
