import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, statSync, utimesSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { DashboardReader, selectPresentation } from '../src/dashboard/snapshot.js';
import { makeTempSddRoot, writeFile } from './test-helpers.js';
import { startStatusView } from '../src/status-view.js';
const tasks = (title: string, status = 'Planned') => `# Tasks\nTask-Review-Status: Pending\n\n## T-001 ${title}\nApproval: Approved\nStatus: ${status}\nRisk: low\nRelease: v1\n\nDescription\n`;
function fixture() {
  const f = makeTempSddRoot('dashboard');
  writeFile(f.dir, 'AGENTS.md', '# AGENTS\n\n## Active Spec Directories\n\n- `specs/demo/`\n');
  writeFile(f.dir, 'specs/demo/requirements.md', '# Requirements\nSpec-Review-Status: Pending\n');
  writeFile(f.dir, 'specs/demo/tasks.md', tasks('First'));
  return f;
}
test('parent presentation is independent of worker model and unknown parents fail closed', () => {
  for (const worker of ['claude','codex','gemini','unknown']) {
    void worker;
    assert.equal(selectPresentation('chatgpt'), 'sites');
    assert.equal(selectPresentation('claude'), 'artifacts');
  }
  assert.throws(() => selectPresentation('codex'), /親サービス/);
});
test('source freshness differs from content age and detects equal-size equal-mtime replacement', () => {
  const f = fixture();
  try {
    const reader = new DashboardReader(f.root);
    const first = reader.sample(new Date('2026-11-05T00:00:00Z'));
    assert.equal(first.error, null);
    assert.equal(first.data?.tasks[0]?.title, 'First');
    assert.equal(first.data?.tasks[0]?.release, 'v1');
    const second = reader.sample(new Date('2026-11-05T00:00:05Z'));
    assert.equal(second.changedAt, first.changedAt);
    assert.notEqual(second.checkedAt, first.checkedAt);
    const path = join(f.dir, 'specs/demo/tasks.md');
    const stat = statSync(path);
    writeFileSync(path, readFileSync(path, 'utf8').replace('First','Other'));
    utimesSync(path, stat.atime, stat.mtime);
    const third = reader.sample(new Date('2026-11-05T00:00:10Z'));
    assert.notEqual(third.revision, second.revision);
    assert.equal(third.data?.tasks[0]?.title, 'Other');
  } finally { f.cleanup(); }
});
test('broken source retains last-good data and recovery clears the error', () => {
  const f = fixture();
  try {
    const reader = new DashboardReader(f.root);
    const first = reader.sample();
    writeFile(f.dir, 'specs/demo/tasks.md', 'broken file');
    const failed = reader.sample(new Date(Date.now() + 1000));
    assert.ok(failed.error);
    assert.deepEqual(failed.data, first.data);
    assert.equal(failed.checkedAt, first.checkedAt);
    assert.equal(failed.lastSuccessAt, first.lastSuccessAt);
    writeFile(f.dir, 'specs/demo/tasks.md', tasks('Fixed'));
    const recovered = reader.sample(new Date(Date.now() + 2000));
    assert.equal(recovered.error, null);
    assert.equal(recovered.data?.tasks[0]?.title, 'Fixed');
  } finally { f.cleanup(); }
});
test('unstable reads and initial parse failure never produce an empty healthy snapshot', () => {
  const f = fixture();
  try {
    let n = 0;
    const reader = new DashboardReader(f.root, () => ({ data: { project:'test', features:[], tasks:[] }, digest:String(n++) }));
    assert.match(reader.sample().error ?? '', /整合性/);
    writeFile(f.dir, 'specs/demo/tasks.md', 'broken');
    const bad = new DashboardReader(f.root).sample();
    assert.equal(bad.data, null); assert.equal(bad.checkedAt, null); assert.ok(bad.error);
  } finally { f.cleanup(); }
});
test('dashboard HTTP uses guarded reads, six views, and rejects writes and wrong origins', async () => {
  const f = fixture(); const {server,url} = await startStatusView(f.root, true);
  try {
    const page = await (await fetch(url)).text();
    for (const label of ['概要','タイムライン','バックログ','ボード','一覧','リリース']) assert.ok(page.includes(label));
    const data = await (await fetch(new URL('api/dashboard',url))).json() as { data:{tasks:unknown[]} };
    assert.equal(data.data.tasks.length,1);
    assert.equal((await fetch(new URL('api/dashboard',url),{method:'PUT'})).status,403);
    assert.equal((await fetch(url,{headers:{Origin:'https://evil.example'}})).status,403);
  } finally { await new Promise<void>(r=>server.close(()=>r())); f.cleanup(); }
});

test('empty Release field does not consume the next line', () => {
  const f = fixture();
  try {
    writeFile(f.dir, 'specs/demo/tasks.md', tasks('Release').replace('Release: v1','Release:'));
    assert.equal(new DashboardReader(f.root).sample().data?.tasks[0]?.release, null);
  } finally { f.cleanup(); }
});
