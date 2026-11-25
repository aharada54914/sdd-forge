import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { createRequire, SourceMap } from 'node:module';
import { test } from 'node:test';
import { runAgentLint } from '../plugins/sdd-quality-loop/scripts/v2/run-agent-lint.mjs';

const { buildSync } = createRequire(new URL('../mcp/sdd-forge-mcp/package.json', import.meta.url))('./node_modules/esbuild');

test('an independently rebuilt bundle preserves only the documented source catch', t => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'lint-bundle-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const pkg = path.join(root, 'mcp/sdd-forge-mcp');
  const src = path.join(pkg, 'src/index.ts');
  const bundle = path.join(pkg, 'dist/index.js');
  fs.mkdirSync(path.dirname(src), { recursive: true });
  fs.writeFileSync(src, [
    'export function documented(f: () => void) {',
    '  try { f() } catch { /* Optional diagnostics may be absent. */ }',
    '}',
    'export function bare(f: () => void) {',
    '  try { f() } catch {}',
    '}',
    '',
  ].join('\n'));
  buildSync({ absWorkingDir: pkg, entryPoints: ['src/index.ts'], bundle: true,
    platform: 'node', format: 'esm', outfile: 'dist/index.js' });
  const git = (...args) => execFileSync('git', args, { cwd: root });
  git('init', '-q');
  git('-c', 'user.name=Test', '-c', 'user.email=test@example.org', 'commit', '--allow-empty', '-qm', 'base');
  const baseRef = git('rev-parse', 'HEAD').toString().trim();
  git('add', '.');
  git('-c', 'user.name=Test', '-c', 'user.email=test@example.org', 'commit', '-qm', 'build');
  const rel = 'mcp/sdd-forge-mcp/dist/index.js';
  const reportedCatches = () => runAgentLint({ projectRoot: root, diffOnly: true, baseRef, mode: 'strict' })
    .findings.filter(f => f.path === rel && f.rule === 'no-empty-catch').map(f => f.line);
  const generated = fs.readFileSync(bundle, 'utf8');
  const lines = generated.split('\n').flatMap((s, i) => s.includes('catch {') ? [i + 1] : []);
  assert.equal(lines.length, 2);
  assert.deepEqual(reportedCatches(), [lines[1]]);
  fs.appendFileSync(bundle, '// manual edit\n');
  assert.deepEqual(reportedCatches(), lines);
  fs.writeFileSync(bundle, generated);
  const original = fs.readFileSync(src, 'utf8');
  fs.writeFileSync(src, original.replace('Optional diagnostics may be absent.', 'Changed since the commit.'));
  assert.deepEqual(reportedCatches(), lines);
  fs.rmSync(src);
  assert.deepEqual(reportedCatches(), lines);
});

test('an input map pointing to a different documented catch cannot clear a finding', t => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'lint-mapped-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const pkg = path.join(root, 'mcp/sdd-forge-mcp');
  const src = path.join(pkg, 'src');
  fs.mkdirSync(src, { recursive: true });
  fs.writeFileSync(path.join(src, 'index.ts'), "export { run } from './input.js'\n");
  const lines = ['export function run(f) {', '  try {', '    f();',
    '  } catch {', '  }', '}', ''];
  const source = lines.map((s, i) => i === 3 ? s + ' /* Intentional cleanup. */' : s).join('\n');
  fs.writeFileSync(path.join(src, 'original.ts'), source);
  const inputMap = { version: 3, sources: ['original.ts'], sourcesContent: [source],
    names: [], mappings: 'AAAA;AACA;AACA;EACE;AACF;AACA' };
  const uri = Buffer.from(JSON.stringify(inputMap)).toString('base64');
  fs.writeFileSync(path.join(src, 'input.js'), lines.join('\n') +
    '//# sourceMappingURL=data:application/json;base64,' + uri + '\n');
  const options = { absWorkingDir: pkg, entryPoints: ['src/index.ts'], bundle: true,
    platform: 'node', format: 'esm', outfile: 'dist/index.js', sourcemap: 'external' };
  buildSync(options);
  const dist = path.join(pkg, 'dist/index.js');
  const generated = fs.readFileSync(dist, 'utf8').split('\n');
  const row = generated.findIndex(s => s.includes('catch {'));
  const map = new SourceMap(JSON.parse(fs.readFileSync(dist + '.map', 'utf8')));
  const entry = map.findEntry(row, generated[row].indexOf('catch'));
  assert.equal(entry.originalSource, '../src/original.ts');
  assert.equal(entry.originalLine, 3);
  assert.equal(entry.originalColumn, 2);
  const git = (...args) => execFileSync('git', args, { cwd: root });
  git('init', '-q');
  git('-c', 'user.name=Test', '-c', 'user.email=test@example.org', 'commit', '--allow-empty', '-qm', 'base');
  const baseRef = git('rev-parse', 'HEAD').toString().trim();
  git('add', '.');
  git('-c', 'user.name=Test', '-c', 'user.email=test@example.org', 'commit', '-qm', 'build');
  const result = runAgentLint({ projectRoot: root, diffOnly: true, baseRef, mode: 'shadow' });
  assert.ok(result.findings.some(f => f.path === 'mcp/sdd-forge-mcp/dist/index.js' &&
    f.rule === 'no-empty-catch' && f.line === row + 1));
});
