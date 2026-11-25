import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';
import { classifyCatalog } from './verification-catalog-status.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..');

const PURE_READONLY_TARGETS = [
  'plugins/sdd-quality-loop/scripts/v2/v2-pure-lib.mjs',
  'plugins/sdd-quality-loop/scripts/v2/v2-readonly-core.mjs',
];

const SOFT_GUARD_PATH = 'plugins/sdd-quality-loop/scripts/v2/sdd-soft-guard.mjs';
const SOFT_GUARD_MAX_LINES = 700;

const FOUR_CLI_HOOKS = [
  'plugins/sdd-quality-loop/hooks/claude-hooks.json',
  'plugins/sdd-quality-loop/hooks/codex-hooks.json',
  'plugins/sdd-quality-loop/hooks/copilot-hooks.json',
  'plugins/sdd-quality-loop/gemini/hooks/hooks.json',
];

function stripJsComments(source) {
  return source
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .replace(/(^|[^:\\])\/\/[^\n]*/g, '$1');
}

export function checkReadOnlyPurity(source, label = '<source>') {
  const code = stripJsComments(source);
  const violations = [];
  const forbiddenImportRe = /(?:import\s+[\s\S]*?from\s+|import\s*\(\s*|require\s*\(\s*)['"](?:node:)?(fs|fs\/promises|child_process|os|net|http|https)['"]/g;
  for (const m of code.matchAll(forbiddenImportRe)) {
    violations.push(`${label}: forbidden side-effect import "${m[1]}"`);
  }
  if (/\bprocess\.env\b/.test(code)) {
    violations.push(`${label}: forbidden process.env access`);
  }
  if (/\bprocess\.argv\b/.test(code)) {
    violations.push(`${label}: forbidden process.argv access`);
  }
  return violations;
}

export function checkSoftGuardRatchet(source, maxLines = SOFT_GUARD_MAX_LINES) {
  const lines = source.split(/\r?\n/);
  const violations = [];
  if (lines.length > maxLines) {
    violations.push(`sdd-soft-guard.mjs has ${lines.length} lines (limit <= ${maxLines})`);
  }
  const code = stripJsComments(source);
  const importRe = /(?:import\s+[\s\S]*?from\s+|import\s*\(\s*)['"]([^'"]+)['"]/g;
  for (const m of code.matchAll(importRe)) {
    const spec = m[1];
    if (!spec.startsWith('node:') && !spec.startsWith('./') && !spec.startsWith('../')) {
      violations.push(`sdd-soft-guard.mjs imports non-builtin external package "${spec}"`);
    }
  }
  return { lineCount: lines.length, violations };
}

describe('ADR-0054 T-003 (SELF-AC-003): sdd-forge Self-Fitness Functions', () => {
  it('1. Pure Read-Only architecture: v2-pure-lib.mjs & v2-readonly-core.mjs have zero fs/child_process/env/argv imports (with negative fixture)', () => {
    for (const rel of PURE_READONLY_TARGETS) {
      const src = fs.readFileSync(path.join(REPO_ROOT, rel), 'utf8');
      const violations = checkReadOnlyPurity(src, rel);
      assert.deepEqual(violations, [], `Purity violations in ${rel}: ${violations.join('; ')}`);
    }

    // Negative test: injecting a forbidden fs import must fail the fitness check
    const taintedFixture = ['import fs from ', "'node:", "fs';\nexport const x = process.env.SECRET;\n"].join('');
    const negViolations = checkReadOnlyPurity(taintedFixture, 'fixture.mjs');
    assert.ok(negViolations.length >= 2, `Expected purity check to fail on negative fixture, got: ${JSON.stringify(negViolations)}`);
  });

  it('2. sdd-soft-guard.mjs non-growth ratchet (<= 700 lines, zero external deps, < 200ms latency) with negative fixture', () => {
    const abs = path.join(REPO_ROOT, SOFT_GUARD_PATH);
    const src = fs.readFileSync(abs, 'utf8');
    const result = checkSoftGuardRatchet(src, SOFT_GUARD_MAX_LINES);
    assert.deepEqual(result.violations, [], result.violations.join('; '));
    assert.ok(result.lineCount <= SOFT_GUARD_MAX_LINES, `Expected <= ${SOFT_GUARD_MAX_LINES} lines, got ${result.lineCount}`);

    // Latency check: warm single invocation on benign Read tool payload must stay under 200ms
    const payload = JSON.stringify({ tool_name: 'Read', tool_input: { file_path: 'README.md' } });
    // Warm-up once to avoid cold OS cache jitter
    spawnSync(process.execPath, [abs, '--emit', 'claude'], { input: payload, encoding: 'utf8', cwd: REPO_ROOT });
    const t0 = performance.now();
    const res = spawnSync(process.execPath, [abs, '--emit', 'claude'], { input: payload, encoding: 'utf8', cwd: REPO_ROOT });
    const elapsedMs = performance.now() - t0;
    assert.equal(res.status, 0, res.stderr);
    assert.ok(elapsedMs < 200, `sdd-soft-guard.mjs invocation took ${elapsedMs.toFixed(1)}ms (budget < 200ms)`);

    // Negative fixture: > 700 lines must fail
    const bloated = `${'const a = 1;\n'.repeat(SOFT_GUARD_MAX_LINES + 5)}`;
    const neg = checkSoftGuardRatchet(bloated, SOFT_GUARD_MAX_LINES);
    assert.ok(neg.violations.length > 0, 'Expected ratchet check to fail when exceeding line cap');
  });

  it('3. 4-CLI hook parity: Claude / Codex / Copilot / Antigravity(Gemini) hook manifests are valid JSON referencing sdd-soft-guard.mjs', () => {
    for (const rel of FOUR_CLI_HOOKS) {
      const abs = path.join(REPO_ROOT, rel);
      assert.ok(fs.existsSync(abs), `Missing CLI hook manifest: ${rel}`);
      const raw = fs.readFileSync(abs, 'utf8');
      assert.doesNotThrow(() => JSON.parse(raw), `Invalid JSON in ${rel}`);
      assert.match(raw, /sdd-soft-guard\.mjs/, `${rel} must invoke sdd-soft-guard.mjs`);
    }
  });

  it('4. Doc-Gardening: AGENTS.md Active Spec Directories matches specs/*/ on disk', () => {
    const agentsText = fs.readFileSync(path.join(REPO_ROOT, 'AGENTS.md'), 'utf8');
    const sectionMatch = /## Active Spec Directories([\s\S]*?)\n## /.exec(agentsText);
    assert.ok(sectionMatch, 'AGENTS.md must contain ## Active Spec Directories section');
    const listed = [...sectionMatch[1].matchAll(/`specs\/([^/`]+)\/`/g)].map((m) => m[1]).sort();
    const onDisk = fs
      .readdirSync(path.join(REPO_ROOT, 'specs'), { withFileTypes: true })
      .filter((e) => e.isDirectory() && !e.name.startsWith('.'))
      .map((e) => e.name)
      .sort();

    const missingInAgents = onDisk.filter((d) => !listed.includes(d));
    const missingOnDisk = listed.filter((d) => !onDisk.includes(d));
    assert.deepEqual(missingInAgents, [], `Spec dirs missing from AGENTS.md: ${missingInAgents.join(', ')}`);
    assert.deepEqual(missingOnDisk, [], `AGENTS.md lists non-existent spec dirs: ${missingOnDisk.join(', ')}`);
  });

  it('5. Verification Catalog hygiene (SELF-AC-006): zero file-missing ghost suites in tests/verification-catalog.json', () => {
    const { suites } = classifyCatalog(REPO_ROOT);
    const ghosts = suites.filter((s) => s.state === 'file-missing').map((s) => s.path);
    assert.deepEqual(ghosts, [], `Found ${ghosts.length} ghost catalog entries: ${ghosts.slice(0, 5).join(', ')}`);
  });
});
