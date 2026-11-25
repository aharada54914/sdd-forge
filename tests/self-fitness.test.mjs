import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { isBuiltin } from 'node:module';
import { parseSource } from '../plugins/sdd-quality-loop/rules/source-ast.mjs';
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

function literal(node) {
  return node?.kind() === 'string' ? node.text().slice(1, -1) : null;
}

function moduleSpecifiers(root) {
  const specifiers = [];
  for (const node of root.findAll({ rule: { any: ['import_statement', 'export_statement', 'call_expression'].map(kind => ({ kind })) } })) {
    if (node.kind() === 'call_expression') {
      if (['import', 'require'].includes(node.field('function')?.text())) {
        specifiers.push(literal(node.field('arguments')?.namedChildren()[0]) ?? '<dynamic>');
      }
    } else if (node.field('source')) {
      specifiers.push(literal(node.field('source')));
    }
  }
  return specifiers;
}

export function checkReadOnlyPurity(source, label = '<source>') {
  const root = parseSource(source, label);
  const violations = [];
  for (const spec of moduleSpecifiers(root)) {
    if (spec === '<dynamic>' || /^(?:node:)?(?:fs(?:\/promises)?|child_process|os|net|https?|process)$/.test(spec)) {
      violations.push(`${label}: forbidden side-effect import ${spec}`);
    }
  }
  const writeMethods = /^(?:(?:writeFile|appendFile|createWriteStream|mkdir|mkdtemp|rmdir|rm|unlink|rename|truncate|copyFile|chmod|symlink|link)(?:Sync)?|writeText)$/;
  for (const node of root.findAll({ rule: { any: [{ kind: 'member_expression' }, { kind: 'subscript_expression' }] } })) {
    const prop = node.field('property')?.text() ?? literal(node.field('index'));
    if (writeMethods.test(prop) || (['process', 'globalThis.process'].includes(node.field('object')?.text()) && ['argv', 'env'].includes(prop))) {
      violations.push(`${label}: forbidden access ${node.text()}`);
    }
  }
  for (const node of root.findAll({ rule: { kind: 'variable_declarator' } })) {
    if (node.field('value')?.text() === 'process' && node.field('name')?.kind() === 'object_pattern') {
      violations.push(`${label}: process destructuring`);
    }
  }
  return violations;
}

export function checkSoftGuardRatchet(source, maxLines = SOFT_GUARD_MAX_LINES) {
  const lineCount = source.split(/\r?\n/).length - Number(source.endsWith('\n'));
  const violations = [];
  if (lineCount > maxLines) violations.push(`sdd-soft-guard.mjs has ${lineCount} lines (limit <= ${maxLines})`);
  for (const spec of moduleSpecifiers(parseSource(source))) {
    if (!isBuiltin(spec) && !spec.startsWith('./') && !spec.startsWith('../')) {
      violations.push(`sdd-soft-guard.mjs imports external dependency ${spec}`);
    }
  }
  return { lineCount, violations };
}

function checkHostParity(read) {
  const violations = [];
  const hosts = [
    ['.claude-plugin/plugin.json', 'hooks/claude-hooks.json'],
    ['.codex-plugin/plugin.json', 'hooks/codex-hooks.json'],
    ['.plugin/plugin.json', 'hooks/copilot-hooks.json'],
    ['.antigravity-plugin/plugin.json', 'hooks.json'],
    ['gemini/gemini-extension.json', 'gemini/hooks/hooks.json'],
  ];
  const version = read(hosts[0][0]).version;
  for (const [manifestPath, hookPath] of hosts) {
    const manifest = read(manifestPath);
    if (manifest.name !== 'sdd-quality-loop' || manifest.version !== version) violations.push(manifestPath);
    if (hookPath.startsWith('hooks/') && manifest.hooks?.replace(/^\.\//, '') !== hookPath) violations.push(manifestPath);
    const hooks = read(hookPath);
    let commands;
    let protocol;
    if (hookPath.includes('copilot')) {
      const hook = hooks.hooks.preToolUse?.[0];
      if (hook?.type !== 'command') violations.push(hookPath);
      commands = [hook?.bash, hook?.powershell];
      protocol = 'copilot';
    } else {
      const groups = hookPath === 'hooks.json' ? hooks['sdd-soft-guard']?.PreToolUse
        : hookPath.startsWith('gemini/') ? hooks.hooks?.BeforeTool : hooks.hooks?.PreToolUse;
      const hook = groups?.[0]?.hooks?.[0];
      if (groups?.[0]?.matcher !== '*' || hook?.type !== 'command') violations.push(hookPath);
      commands = [[hook?.command, ...(hook?.args ?? [])].join(' ')];
      if (hookPath.includes('codex')) commands.push(hook?.command_windows);
      protocol = hookPath === 'hooks.json' ? 'antigravity' : hookPath.includes('gemini') ? 'gemini' : 'exit';
    }
    for (const command of commands) {
      const normalized = (command ?? '').replaceAll("','", ' ').replaceAll("'", '');
      if (!/\bnode\s/.test(normalized) || !normalized.includes('sdd-soft-guard.mjs') || !new RegExp(`--emit\\s+${protocol}(?=[\\s")\\],;]|$)`).test(normalized)) {
        violations.push(hookPath);
      }
    }
  }
  return violations;
}

function hasPinnedReleaseLine(readme) {
  const lines = readme.split(/\r\n|[\n\r\v\f\x1c-\x1e\u0085\u2028\u2029]/u, 5);
  return lines.some(line => /^v\p{Nd}+\.\p{Nd}+\.\p{Nd}+ — /u.test(line));
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

  it('parses side-effect syntax independent of quotes, comments and strings', () => {
    for (const code of ["import 'node:fs';", "export * from 'child_process';",
      "function f(io) { io.writeText('out', 'data'); }", "export const p = process['env'];"]) {
      assert.ok(checkReadOnlyPurity(code).length, code);
    }
    assert.deepEqual(checkReadOnlyPurity('const help = "Examples use process.env and fs.writeFile";'), []);
  });

  it('detects a new external dependency imported for its side effect', () => {
    assert.ok(checkSoftGuardRatchet("import 'fixture-dependency';").violations.length);
  });

  it('detects a host manifest pointing to the wrong hook or a hook changing output protocol', () => {
    const read = rel => JSON.parse(fs.readFileSync(path.join(REPO_ROOT, 'plugins/sdd-quality-loop', rel), 'utf8'));
    assert.deepEqual(checkHostParity(read), []);
    for (const target of ['.codex-plugin/plugin.json', 'gemini/hooks/hooks.json', 'hooks/copilot-hooks.json']) {
      const mutate = rel => {
        const data = read(rel);
        if (rel === target) {
          if (target.includes('plugin.json')) data.hooks = './hooks/claude-hooks.json';
          else if (target.startsWith('gemini')) data.hooks.BeforeTool[0].hooks[0].command += '-wrong';
          else data.hooks.preToolUse[0].powershell = 'echo sdd-soft-guard.mjs';
        }
        return data;
      };
      assert.ok(checkHostParity(mutate).length, target);
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
    const catalog = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, 'tests/verification-catalog.json'), 'utf8'));
    const registered = new Set(catalog.suites.map(s => s.path));
    for (const [profile, paths] of Object.entries(catalog.profiles)) {
      assert.deepEqual(paths.filter(p => !registered.has(p)), [], profile);
    }
    assert.deepEqual(ghosts, [], `Found ${ghosts.length} ghost catalog entries: ${ghosts.slice(0, 5).join(', ')}`);
  });

  it('checks the pinned README release line within the first five lines', () => {
    assert.ok(hasPinnedReleaseLine(fs.readFileSync(path.join(REPO_ROOT, 'README.md'), 'utf8')));
  });

  it('matches the legacy doc-diagrams release-line verdict on the same controls', t => {
    const fixture = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-release-line-'));
    t.after(() => fs.rmSync(fixture, { recursive: true, force: true }));
    const legacySuite = path.join(REPO_ROOT, 'tests/doc-diagrams.tests.py');
    const boundary = '# Project\n\nDescription\n\n';
    const release = 'v1.2.3 — Release\n';
    for (const [label, readme, expected] of [
      ['line five', boundary + release, true],
      ['line six', boundary + '\n' + release, false],
      ['missing version component', boundary + 'v1.2 — Release\n', false],
      ['wrong separator', boundary + 'v1.2.3 - Release\n', false],
    ]) {
      const readmePath = path.join(fixture, 'README.md');
      fs.writeFileSync(readmePath, readme);
      const python = process.platform === 'win32' ? 'python' : 'python3';
      const legacy = spawnSync(python, [legacySuite, '--root', fixture, '--no-selftest'], { encoding: 'utf8' });
      assert.ifError(legacy.error);
      assert.equal(legacy.status, expected ? 0 : 1, `${label}: ${legacy.stderr}`);
      if (!expected) assert.match(legacy.stderr, /README\.md: the release line/);
      assert.equal(hasPinnedReleaseLine(fs.readFileSync(readmePath, 'utf8')), expected, label);
    }
  });
});
