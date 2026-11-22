import { test } from 'node:test';
import assert from 'node:assert/strict';
import { request } from 'node:http';
import { connect } from 'node:net';
import { runInNewContext } from 'node:vm';
import type { Result } from '../src/envelope.js';
import type { NextCommandData } from '../src/next-command.js';
import { startStatusView } from '../src/status-view.js';
import { sddFeatureState, sddProjectOverview } from '../src/tools/v2.js';
import { DashboardReader } from '../src/dashboard/snapshot.js';
import { makeTempSddRoot, writeFile } from './test-helpers.js';

interface TestNode {
  id: string; value: string; textContent: string; hidden: boolean; disabled: boolean; children: TestNode[];
  onclick?: () => Promise<void>; onchange?: () => Promise<void>;
  replaceChildren(): void; append(child: TestNode): void;
}
function makeDocument() {
  const elements = new Map<string, TestNode>();
  const element = (id: string): TestNode => { const value = elements.get(id); assert.ok(value); return value; };
  const node = (id = ''): TestNode => ({
    id, value: '', textContent: '', hidden: false, disabled: false, children: [],
    replaceChildren() { this.children = []; this.value = ''; },
    append(child) { this.children.push(child); if (id === 'feature' && !this.value) this.value = child.value; },
  });
  for (const id of ['feature','error','result','progress','headline','reason','next','command','copy','copy-result','steps','raw','refresh']) elements.set(id, node(id));
  return { element, document: { getElementById: element, createElement: () => node() } };
}

/** Mount the script from the served page and follow its real HTTP reads, including refreshes. */
async function mountStatusPage(url: string) {
  const html = await (await fetch(url)).text();
  const script = html.match(/<script>([\s\S]*?)<\/script>/)?.[1];
  assert.ok(script);
  const { element, document } = makeDocument();
  await runInNewContext(script, {
    document, encodeURIComponent, AbortSignal,
    fetch: (path: string, init: RequestInit) => fetch(new URL(path, url), init),
  });
  const refresh = element('refresh').onclick;
  assert.ok(refresh);
  const next = () => (JSON.parse(element('raw').textContent) as { next: Result<NextCommandData> }).next;
  return { element, refresh, next };
}

function assertDisplayedPhase(
  view: Awaited<ReturnType<typeof mountStatusPage>>, phase: string, headline: string, reason: RegExp, command: string,
) {
  const next = view.next();
  assert.equal(next.ok, true);
  assert.equal(next.data.phase, phase);
  assert.equal(view.element('headline').textContent, headline);
  assert.match(view.element('reason').textContent, reason);
  assert.equal(view.element('command').textContent, command);
  assert.equal(view.element('copy').hidden, false);
}

test('local status view exposes fresh guarded state and rejects untrusted requests', async () => {
  const fixture=makeTempSddRoot('status-view');
  writeFile(fixture.dir,'AGENTS.md','# AGENTS\n\n## Active Spec Directories\n\n- `specs/example/`\n');
  writeFile(fixture.dir, 'specs/example/notes.md', '# Notes\n');
  const {server,url}=await startStatusView(fixture.root);
  try {
    const address=server.address();
    assert.ok(address && typeof address !== 'string');
    assert.equal(address.address,'127.0.0.1');
    const malformed = await new Promise<string>((resolve,reject)=>{
      const socket=connect(address.port,'127.0.0.1');let response='';
      socket.setEncoding('utf8');socket.setTimeout(3000,()=>socket.destroy(new Error('request timed out')));
      socket.on('connect',()=>socket.write(`GET http://[ HTTP/1.1\r\nHost: 127.0.0.1:${address.port}\r\nConnection: close\r\n\r\n`));
      socket.on('data',chunk=>{response+=chunk});socket.on('end',()=>resolve(response));socket.on('error',reject);
    });
    assert.match(malformed,/^HTTP\/1\.1 400 /);
    const page=await fetch(url);assert.equal(page.status,200);
    assert.match(page.headers.get('content-security-policy') ?? '',/frame-ancestors 'none'/);
    assert.match(await page.text(),/品質ゲート/);
    const view = await mountStatusPage(url);
    const bootstrap = '/sdd-bootstrap:bootstrap feature example';
    assertDisplayedPhase(view, 'bootstrap-not-started', '仕様の準備が必要です', /要件ファイル/, bootstrap);
    writeFile(fixture.dir, 'specs/example/requirements.md', '# Requirements\n');
    await view.refresh();
    assertDisplayedPhase(view, 'design-missing', '設計の準備が必要です', /設計ファイル/, bootstrap);
    writeFile(fixture.dir, 'specs/example/design.md', '# Design\n');
    await view.refresh();
    assertDisplayedPhase(view, 'tasks-missing', 'タスクの準備が必要です', /実装タスク/, bootstrap);
    writeFile(fixture.dir, 'specs/example/tasks.md', '# Tasks\n\n## T-001\nApproval: Draft\nStatus: Planned\nRisk: low\n');
    await view.refresh();
    assertDisplayedPhase(view, 'approval-gate', 'タスクの承認待ちです', /まだ承認/, 'human: approve tasks in tasks.md');
    assert.equal((await fetch(new URL('api/status?feature=..%2Fsecret',url))).status,400);
    assert.equal((await fetch(new URL('/wrong/api/features',url))).status,404);
    assert.equal((await fetch(url,{headers:{Origin:'https://attacker.example'}})).status,403);
    const hostileHost = await new Promise<number>((resolve,reject)=>{const req=request(url,{headers:{Host:'attacker.example'}},res=>{res.resume();resolve(res.statusCode ?? 0)});req.on('error',reject);req.end()});
    assert.equal(hostileHost,403);
    assert.equal((await fetch(url,{method:'POST'})).status,403);
  } finally { await new Promise<void>((resolve,reject)=>server.close(e=>e?reject(e):resolve()));fixture.cleanup(); }
});

test('pre-approval guidance follows the feature’s recorded review and skip policy on every status surface', async () => {
  const fixture = makeTempSddRoot('status-review');
  const id = 'example';
  writeFile(fixture.dir, 'AGENTS.md', '# AGENTS\n\n## Active Spec Directories\n\n- `specs/example/`\n');
  for (const name of ['requirements', 'design']) writeFile(fixture.dir, `specs/${id}/${name}.md`, '# Specification\n');
  const task = (risk: string, approval = 'Draft') => writeFile(fixture.dir, `specs/${id}/tasks.md`,
    `# Tasks\n\n## T-001\nApproval: ${approval}\nStatus: Planned\nRisk: ${risk}\n`);
  const policy = (mode: string) => writeFile(fixture.dir, 'sdd/guardrails.yaml', `review:\n  pre_impl_check: ${mode}\n`);
  const report = (verdictLine: string) => writeFile(fixture.dir, `reports/spec-check/${id}.md`,
    `# Spec Check Report: ${id}\n\n${verdictLine}\n\n## Blockers (Must Fix Before Approval)\n`);
  task('low');
  const { server, url } = await startStatusView(fixture.root);
  try {
    const view = await mountStatusPage(url);
    const reader = new DashboardReader(fixture.root);
    async function check(phase: string, reason?: RegExp, expectedCommand?: string) {
      await view.refresh();
      const compact = view.next();
      const overview = sddProjectOverview(fixture.root);
      const feature = sddFeatureState(fixture.root, id);
      const dashboard = reader.sample().data?.features[0];
      assert.ok(compact.ok && overview.ok && feature.ok && dashboard);
      const actions = [feature.data.nextAction, overview.data.activeFeatures[0]?.nextAction];
      for (const action of actions) {
        assert.equal(action?.phase, phase);
        if (reason) assert.match(action!.rationale, reason);
      }
      assert.equal(dashboard.phase, phase);
      assert.equal(compact.data.phase, phase);
      if (reason) {
        assert.match(compact.data.rationale, reason);
        assert.match(view.element('reason').textContent, reason);
        assert.match(dashboard.warnings.join(' '), reason);
      }
      if (phase === 'spec-check') {
        assert.equal(view.element('headline').textContent, '着工前の仕様確認が必要です');
        for (const cmd of [dashboard.nextCommand, compact.data.nextCommand, ...actions.map(a => a!.command)]) {
          assert.doesNotMatch(cmd, /approve tasks|set Approval/);
          if (expectedCommand) assert.equal(cmd, expectedCommand);
        }
      }
    }
    const bootstrap = `/sdd-bootstrap:bootstrap <mode> --feature ${id} <source>`;
    const human = `human: review reports/spec-check/${id}.md`;
    writeFile(fixture.dir, 'reports/spec-check/other.md', '- **Verdict**: NEEDS_FIX\n');
    await check('approval-gate'); // low/auto
    policy('always');
    await check('spec-check', /--skip-check.*<source>/, bootstrap);
    task('high');
    policy('off');
    await check('approval-gate');
    policy('auto');
    await check('spec-check', /--skip-check.*<source>/, bootstrap);
    task('standard');
    for (const verdict of ['PASS', 'PASS_WITH_NOTES']) {
      report(`- **Verdict**: ${verdict}`);
      await check('approval-gate');
    }
    report('- **Verdict**: NEEDS_FIX');
    for (const risk of ['low', 'standard', 'high']) {
      task(risk);
      policy('off');
      await check('spec-check', /NEEDS_FIX.*Blockers.*pre_impl_check=off.*省略.*確認/, human);
      policy('auto');
      if (risk === 'low') {
        await check('spec-check', /NEEDS_FIX.*Blockers.*pre_impl_check=auto.*low.*省略.*確認/, human);
      } else {
        await check('spec-check', /NEEDS_FIX.*Blockers.*<mode>.*<source>.*再実行/, bootstrap);
      }
      policy('always');
      await check('spec-check', /NEEDS_FIX.*Blockers.*<mode>.*<source>.*再実行/, bootstrap);
    }
    task('low', 'Approved');
    await check('implementation'); // a historical result never rewinds approved work
    task('low');
    for (const incomplete of [
      '作成中。',
      '```markdown\n- **Verdict**: PASS\n```',
      '## Notes\n- **Verdict**: PASS',
      '- **Verdict**: PASS\n- **Verdict**: NEEDS_FIX',
    ]) {
      report(incomplete);
      await check('spec-check', /判定.*確認/);
    }
    report('- **Verdict**: PASS\r\n');
    await check('approval-gate');
  } finally {
    await new Promise<void>((resolve, reject) => server.close(e => e ? reject(e) : resolve()));
    fixture.cleanup();
  }
});

test('indeterminate status keeps known review progress and recovers to the quality gate when the report appears', async () => {
  const fixture = makeTempSddRoot('status-view-indeterminate');
  writeFile(fixture.dir, 'AGENTS.md', '# AGENTS\n\n## Active Spec Directories\n\n- `specs/example/`\n');
  writeFile(fixture.dir, 'specs/example/requirements.md', '# Requirements\nSpec-Review-Status: Passed\n');
  writeFile(fixture.dir, 'specs/example/design.md', '# Design\n');
  writeFile(fixture.dir, 'specs/example/tasks.md', '# Tasks\n\n## T-001\nApproval: Approved\nStatus: Implementation Complete\nRisk: low\n');
  const { server, url } = await startStatusView(fixture.root);
  try {
    const view = await mountStatusPage(url);
    const next = view.next();
    assert.equal(next.ok, false);
    assert.equal(next.error.code, 'cannot-determine');
    const { element } = view;
    const rowValue = (label: string) => element('steps').children.find(row => row.children[0]?.textContent === label)?.children[1]?.textContent;
    assert.match(element('error').textContent, /次の工程を判断できません/);
    assert.equal(element('result').hidden, false);
    assert.equal(element('progress').hidden, false);
    assert.equal(element('copy').hidden, true);
    assert.equal(element('command').textContent, '');
    assert.equal(rowValue('要件のレビュー'), 'レビュー済み');
    for (const label of ['タスクのレビュー', 'タスクの承認', '品質ゲート（タスクごと）']) {
      assert.equal(rowValue(label), '状態未確認');
    }

    writeFile(fixture.dir, 'reports/implementation/example-T-001.md', '# Implementation Report\nTask ID: T-001\n');
    await view.refresh();
    assertDisplayedPhase(view, 'sdd-gate', '品質ゲートが必要です', /品質確認/, '/sdd-ship:ship specs/example/tasks.md');
    assert.equal(element('error').textContent, '');
    assert.equal(rowValue('品質ゲート（タスクごと）'), '現在の工程');
  } finally {
    await new Promise<void>((resolve, reject) => server.close(e => e ? reject(e) : resolve()));
    fixture.cleanup();
  }
});

test('a late feature refresh cannot overwrite the newest selection', async () => {
  const fixture = makeTempSddRoot('status-view-race');
  const view = await startStatusView(fixture.root);
  try {
    const html = await (await fetch(view.url)).text();
    const script = html.match(/<script>([\s\S]*?)<\/script>/)?.[1]; assert.ok(script);
    const { element, document } = makeDocument();
    const pending: Array<(value: { ok: boolean; json: () => Promise<unknown> }) => void> = [];
    const fetchMock = (path: string, init: { signal: AbortSignal }) => {
      assert.ok(init.signal instanceof AbortSignal);
      assert.equal(path, 'api/features');
      return new Promise(resolve => pending.push(resolve));
    };
    runInNewContext(script, { document, fetch: fetchMock, encodeURIComponent, AbortSignal });
    const refresh = element('refresh').onclick; assert.ok(refresh);
    const newest = refresh();
    assert.equal(pending.length, 2);
    const first = pending.shift(); const second = pending.shift(); assert.ok(first); assert.ok(second);
    second({ ok: true, json: async () => ({ ok: true, data: { specs: [] } }) });
    await newest;
    first({ ok: true, json: async () => ({ ok: true, data: { specs: [{ feature: 'obsolete' }] } }) });
    await new Promise(resolve => setImmediate(resolve));
    assert.equal(element('feature').children.length, 0);
    assert.equal(element('error').textContent, '表示できる機能がありません。');
  } finally {
    await new Promise<void>((resolve, reject) => view.server.close(error => error ? reject(error) : resolve()));
    fixture.cleanup();
  }
});

test('local status page explains the recorded Concept Test stop and refreshes after revalidation', async () => {
  const fixture = makeTempSddRoot('status-concept-stop');
  const { dir } = fixture;
  writeFile(dir, 'AGENTS.md', '# AGENTS\n\n## Active Spec Directories\n- `specs/example/`\n');
  for (const name of ['requirements', 'design']) writeFile(dir, `specs/example/${name}.md`, '# Spec\n');
  writeFile(dir, 'specs/example/tasks.md', '# Tasks\n\n## T-001\nApproval: Approved\nStatus: Implementation Complete\nRisk: low\n');
  writeFile(dir, 'reports/implementation/example/T-001.md', '# Implementation report\nTask ID: T-001\n');
  const path = 'reports/quality-gate/example-T-001.execution.json';
  function record(status: string, error?: string) {
    const passed = status === 'CONTINUE';
    writeFile(dir, path, JSON.stringify({
      schema: 'sdd-gate-execution/v1', feature: 'example', taskId: 'T-001', verdict: passed ? 'PASS' : 'FAIL',
      checks: { conceptTest: { passed, status, error } },
    }));
  }
  record('BLOCK', 'validate-concept-test: VALIDATE_CONCEPT_TEST_RUNTIME_UNAVAILABLE: private-host-path');
  const { server, url } = await startStatusView(fixture.root);
  try {
    const view = await mountStatusPage(url);
    assertDisplayedPhase(view, 'blocked', 'ブロッカーを確認してください', /検証器と依存ファイル/, 'human: restore the installed Concept Test runtime for example');
    assert.doesNotMatch(view.element('reason').textContent, /private-host-path|--confirm/);
    for (const error of [
      'sh: /private-host-path/sdd-domain/scripts/validate-concept-test.sh: No such file or directory',
      'sh: 0: cannot open /private-host-path/sdd-domain/scripts/validate-concept-test.sh: No such file',
      "The argument 'C:\\private-host-path\\scripts\\validate-concept-test.ps1' is not recognized as the name of a script file.",
    ]) {
      record('BLOCK', error);
      await view.refresh();
      assert.match(view.element('command').textContent, /restore the installed Concept Test runtime/);
      assert.match(view.element('reason').textContent, /配布.*復旧/);
      assert.doesNotMatch(view.element('reason').textContent, /private-host-path|--confirm/);
    }
    record('BLOCK', 'sh: /private-host-path/specs/example/concept-test.md: No such file or directory');
    await view.refresh();
    assert.doesNotMatch(view.element('command').textContent, /restore the installed Concept Test runtime/);
    record('BLOCK', 'concept-test: BLOCK: run --confirm in a separate human-operated terminal');
    await view.refresh();
    assert.match(view.element('reason').textContent, /本人.*--confirm/);
    record('CONTINUE');
    await view.refresh();
    assert.equal(view.element('headline').textContent, '品質ゲートが必要です');
    assert.doesNotMatch(view.element('reason').textContent, /--confirm/);
  } finally {
    await new Promise<void>((resolve, reject) => server.close(error => error ? reject(error) : resolve()));
    fixture.cleanup();
  }
});
