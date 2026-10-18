// Scoped acceptance evidence, not a replacement product test suite.
import { readFileSync, readdirSync, existsSync, mkdtempSync, rmSync } from 'node:fs';
import { resolve, dirname, join } from 'node:path';
import { tmpdir } from 'node:os';
import { createRequire } from 'node:module';
import { spawnSync } from 'node:child_process';
import assert from 'node:assert/strict';
const root = resolve(process.argv[2] ?? '.');
const snapshot = resolve(process.argv[3] ?? '/tmp/T008-release-01a1505e/initial');
const require = createRequire(join(root, 'mcp/sdd-forge-mcp/package.json'));
const { load } = require('js-yaml');
const read = p => readFileSync(join(root, p), 'utf8');
let failed = 0;
function check(name, body) {
  try { body(); console.log(`PASS ${name}`); }
  catch (error) { failed++; console.log(`FAIL ${name}: ${error.message}`); }
}
check('workflow YAML: only workflow-level Git environment changes; all jobs preserved', () => {
  const path = '.github/workflows/test.yml';
  const current = load(read(path));
  const original = load(readFileSync(join(snapshot, path), 'utf8'));
  const expected = { GIT_CONFIG_COUNT: '1', GIT_CONFIG_KEY_0: 'core.longpaths', GIT_CONFIG_VALUE_0: 'true' };
  assert.deepEqual(current.env, expected);
  delete current.env;
  assert.deepEqual(current, original);
  for (const job of Object.values(current.jobs)) {
    for (const env of [job.env, ...(job.steps ?? []).map(s => s.env)]) {
      assert.ok(!Object.keys(env ?? {}).some(k => k.startsWith('GIT_CONFIG_')));
    }
  }
  const fixture = mkdtempSync(join(tmpdir(), 't008-git-'));
  try {
    const env = { ...process.env, ...expected };
    let result = spawnSync('git', ['init', '-q', fixture], { env, encoding: 'utf8' });
    assert.equal(result.status, 0, result.stderr);
    result = spawnSync('git', ['-C', fixture, 'config', '--show-origin', '--get', 'core.longpaths'], { env, encoding: 'utf8' });
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stdout, /command line:\s+true/);
    console.log(`Linux nested Git config: ${result.stdout.trim()}; NOT native Windows proof`);
  } finally { rmSync(fixture, { recursive: true, force: true }); }
});
check('ticket IDs: unique numeric values; only ticket_id bytes change', () => {
  const dir = 'docs/review-tickets'; const ids = new Set(); let changed = 0;
  for (const name of readdirSync(join(root, dir)).filter(n => /\.ya?ml$/.test(n))) {
    const path = `${dir}/${name}`; const text = read(path); const id = load(text).ticket_id;
    assert.match(id, /^RT-[0-9]{8}-[0-9]{3}$/); assert.ok(!ids.has(id), `duplicate ${id}`); ids.add(id);
    if (name.startsWith('RT-20261018-CLOUD-')) {
      const old = readFileSync(join(snapshot, path), 'utf8');
      assert.equal(text.replace(/^ticket_id:.*$/m, ''), old.replace(/^ticket_id:.*$/m, ''));
      assert.notEqual(id, load(old).ticket_id); changed++;
    }
  }
  assert.equal(changed, 12); console.log(`${ids.size} unique tickets; 12 ID-only corrections`);
});
check('release runbook actual local files and heading anchors', () => {
  const path = 'docs/contributor/release-runbook.md'; const text = read(path);
  const anchors = new Set([...text.matchAll(/^#{1,6} (.+)$/gm)].map(m => m[1].toLowerCase().replace(/[^\p{L}\p{N}\p{M}_\- ]/gu, '').replace(/ /g, '-')));
  assert.ok(anchors.has('releaseyml-の-loop-gate-ジョブ'));
  let count = 0;
  for (const match of text.matchAll(/\]\(([^\s)]+)\)/g)) {
    const target = match[1]; if (/^[a-z]+:/i.test(target)) continue;
    if (target.startsWith('#')) { assert.ok(anchors.has(decodeURIComponent(target.slice(1))), target); count++; }
    else assert.ok(existsSync(resolve(root, dirname(path), decodeURIComponent(target.split('#')[0]))), target);
  }
  assert.equal(count, 2); console.log('Two actual heading references and all local file links resolve');
});
process.exitCode = failed ? 1 : 0;
