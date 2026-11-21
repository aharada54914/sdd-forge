import { createHash } from 'node:crypto';
import { rmSync } from 'node:fs';
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, statSync, utimesSync, writeFileSync, symlinkSync } from 'node:fs';
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

test('project-owned display names affect revision and malformed metadata retains last-good', () => {
  const f=fixture();
  try {
    const reader=new DashboardReader(f.root);const initial=reader.sample();
    assert.equal(initial.data?.features[0]?.displayName,undefined);
    writeFile(f.dir,'dashboard-labels.json',JSON.stringify({schema:'sdd-dashboard-labels/v1',features:{demo:'経費申請の改善'}}));
    const renamed=reader.sample();assert.equal(renamed.data?.features[0]?.displayName,'経費申請の改善');assert.notEqual(renamed.revision,initial.revision);
    writeFile(f.dir,'dashboard-labels.json','{"schema":"sdd-dashboard-labels/v1","features":{"demo":""}}');
    const bad=reader.sample();assert.ok(bad.error);assert.deepEqual(bad.data,renamed.data);assert.equal(bad.checkedAt,renamed.checkedAt);
  } finally {f.cleanup();}
});


test('display metadata cannot alias a denied root secret', () => {
  const f=fixture();
  try {
    writeFile(f.dir,'.env','PRIVATE_SENTINEL');
    symlinkSync(join(f.dir,'.env'),join(f.dir,'dashboard-labels.json'));
    const result=new DashboardReader(f.root).sample();assert.ok(result.error);assert.equal(result.data,null);assert.ok(!JSON.stringify(result).includes('PRIVATE_SENTINEL'));
  } finally {f.cleanup();}
});

test('SDD Core dashboard routes preserve evidence validation across refreshes', () => {
  const f = fixture();
  try {
    writeFile(f.dir, 'AGENTS.md', '# Project\n## Active Spec Directories\n- `specs/demo/`\n');
    writeFile(f.dir, 'specs/demo/design.md', '# Design\n');
    const reader = new DashboardReader(f.root);
    const planned = reader.sample();
    assert.equal(planned.error, null);
    assert.equal(planned.data?.features[0]?.nextCommand, '/sdd-ship:ship specs/demo/tasks.md');
    writeFile(f.dir, 'reports/implementation/T-001.md', 'Task ID: T-001\n');
    writeFile(f.dir, 'specs/demo/tasks.md', tasks('First', 'Implementation Complete'));
    const implemented = reader.sample();
    assert.equal(implemented.error, null);
    assert.equal(implemented.data?.features[0]?.phase, 'sdd-gate');
    assert.equal(implemented.data?.features[0]?.nextCommand, '/sdd-ship:ship specs/demo/tasks.md');
    writeFile(f.dir, 'reports/quality-gate/T-001.md', 'Task ID: T-001\nVERDICT: PASS\n');
    writeFile(f.dir, 'specs/demo/tasks.md', tasks('First', 'Done'));
    const done = reader.sample();
    assert.equal(done.error, null);
    assert.equal(done.data?.features[0]?.phase, 'done');
    writeFile(f.dir, 'reports/quality-gate/T-001.md', 'Task ID: T-001\nVERDICT: FAIL\n');
    const invalid = reader.sample();
    assert.notEqual(invalid.data?.features[0]?.phase, 'done');
    assert.ok(invalid.data?.features[0]?.warnings.length);
  } finally { f.cleanup(); }
});

function decisionFile(f: ReturnType<typeof fixture>) {
  return {schema:'sdd-decisions/v1',decisions:[{
    id:'Q-001',title:'Save placement',problem:'Save is hidden',status:'pending',
    basis:[{path:'requirements.md',sha256:createHash('sha256').update(readFileSync(join(f.dir,'specs/demo/requirements.md'))).digest('hex')}],
    options:['A','B'].map(id=>({id,title:id,benefit:'Visible',drawback:'Space',impact:'Form',diagram:{kind:'screen',steps:['Title','Fields','Save']}})),
    recommended:'A',reason:'Reachable',selected:null,resolution:null
  }]};
}
test('decisions exist before tasks; basis drift, regeneration and removal change the projection', () => {
  const f=fixture();
  try {
    rmSync(join(f.dir,'specs/demo/tasks.md'));
    const reader=new DashboardReader(f.root); const base=reader.sample();
    const file=decisionFile(f); writeFile(f.dir,'specs/demo/decisions.json',JSON.stringify(file));
    const first=reader.sample(); assert.equal(first.error,null); assert.equal(first.data?.decisionSets?.[0]?.stale,false); assert.notEqual(first.revision,base.revision);
    writeFile(f.dir,'specs/demo/requirements.md','# Changed requirements');
    const drift=reader.sample(); assert.equal(drift.data?.decisionSets?.[0]?.stale,true); assert.notEqual(drift.revision,first.revision);
    writeFile(f.dir,'specs/demo/decisions.json',JSON.stringify(decisionFile(f)));
    assert.equal(reader.sample().data?.decisionSets?.[0]?.stale,false);
    rmSync(join(f.dir,'specs/demo/decisions.json')); assert.equal(reader.sample().data?.decisionSets,undefined);
  } finally { f.cleanup(); }
});
test('invalid decisions retain last-good; duplicate choices, foreign paths and unreviewed resolutions reject', () => {
  const f=fixture();
  try {
    const reader=new DashboardReader(f.root), file=decisionFile(f);
    writeFile(f.dir,'specs/demo/decisions.json',JSON.stringify(file)); const good=reader.sample();
    for(const change of [
      (v: ReturnType<typeof decisionFile>)=>v.decisions[0].options.push(v.decisions[0].options[0]),
      (v: ReturnType<typeof decisionFile>)=>v.decisions[0].basis[0].path='../other/requirements.md',
      (v: ReturnType<typeof decisionFile>)=>v.decisions[0].status='decided',
      (v: ReturnType<typeof decisionFile>)=>v.decisions[0].recommended='Z',
      (v: ReturnType<typeof decisionFile>)=>Object.assign(v.decisions[0],{secret:'must not be projected'}),
      (v: ReturnType<typeof decisionFile>)=>v.decisions[0].options[0].diagram.steps=[],
      (v: ReturnType<typeof decisionFile>)=>Object.assign(v.decisions[0].basis[0],{sha256:['a'.repeat(64)]}),
    ]) {
      const bad=structuredClone(file);change(bad);writeFile(f.dir,'specs/demo/decisions.json',JSON.stringify(bad));
      const failed=reader.sample();assert.ok(failed.error);assert.deepEqual(failed.data,good.data);assert.equal(failed.checkedAt,good.checkedAt);
    }
    rmSync(join(f.dir,'specs/demo/decisions.json'));writeFile(f.dir,'.env','PRIVATE_DECISION_SENTINEL');
    symlinkSync(join(f.dir,'.env'),join(f.dir,'specs/demo/decisions.json'));
    const failed=reader.sample();assert.ok(failed.error);assert.ok(!JSON.stringify(failed).includes('PRIVATE_DECISION_SENTINEL'));
  } finally { f.cleanup(); }
});
