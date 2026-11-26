import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../../', import.meta.url));
const bootstrap = 'plugins/sdd-bootstrap';
const core = bootstrap + '/skills/sdd-core-spec';
const quality = 'plugins/sdd-quality-loop/scripts';
const read = (name) => readFileSync(path.join(root, name), 'utf8');

function run(command, args, status = 0, env = process.env, input) {
  const result = spawnSync(command, args, { cwd: root, encoding: 'utf8', env, input });
  if (result.error) throw result.error;
  assert.equal(result.status, status, [command, ...args, result.stdout, result.stderr].join('\n'));
  return result;
}

function interview() {
  const route = read(bootstrap + '/skills/bootstrap/SKILL.md');
  assert.match(route, /--lite` \/ `--full`[^\n]*`--risk low` \/ `--risk high`/);
  assert.ok(route.includes('specs/<feature>/{requirements,design,tasks}.md'));
  const outputs = [...read(core + '/SKILL.md').matchAll(/^[ \t]*- `templates\/([^/`]+\.md)` → `specs\/<feature>\/([^/`]+\.md)`:/gm)]
    .map(([, template, output]) => [template, output]);
  assert.deepEqual(outputs, ['requirements.md', 'design.md', 'tasks.md'].map(name => [name, name]));
  for (const [name] of outputs) assert.ok(read(core + '/templates/' + name).length > 0);
  assert.match(read(core + '/templates/requirements.md'), /^\| OQ-001 \|.*\| Provisional \| T-001 \|$/m);
}

function humanQuestions(project) {
  assert.match(read(core + '/SKILL.md'), /(?:設計分岐|曖昧な要件)[^。\n]*推測せず[^。\n]*人間へ確認する[^。\n]*`Open Questions`/);
  const dir = path.join(project, 'specs', 'sample');
  mkdirSync(dir, { recursive: true });
  const question = '公開前に担当者の確認を必要としますか？';
  const template = read(core + '/templates/requirements.md');
  assert.match(read(bootstrap + '/skills/bootstrap/SKILL.md'), /render-decision-view\.mjs[^。\n]*人間へ提示して停止/);
  const sample = template.replace(/^\| OQ-001 \|.*$/m,
    `| OQ-001 | 事業判断 | 公開前に確認 | 誤公開を防ぐ | ${question} | Provisional | T-001 |`);
  writeFileSync(path.join(dir, 'requirements.md'), sample);
  const view = run(process.execPath, [quality + '/v2/render-decision-view.mjs', '--root', project, '--feature', 'sample']).stdout;
  assert.match(view, /^### OQ-001 .*Provisional（要判断）/m);
  assert.ok(view.includes('**人が判断する問い**: ' + question));
}

function bugfixReview(project) {
  const spec = read(core + '/SKILL.md');
  const route = read(bootstrap + '/skills/bootstrap/SKILL.md');
  const review = read('plugins/sdd-review-loop/skills/spec-check/SKILL.md');
  assert.match(spec, /^\s*- `low`: [^\n]*小規模バグ修正/m);
  assert.match(spec, /^\s*- `high`: [^\n]*認証\/認可/m);
  assert.match(route, /^\| `bugfix` \| `sdd-core-spec` → `spec-check`/m);
  assert.match(route, /`auto` かつ全タスク `Risk: low` → スキップ/);
  assert.match(route, /`Risk: high` → `dual-parallel`[^\n]*設計・セキュリティ/);
  assert.match(review, /`auto` かつ全タスク `Risk: low` \| `skipped`/);
  assert.match(review, /`Risk: high`\** \| \**`dual-parallel`\** \|[^|\n]*`spec-reviewer-a`[^|\n]*`spec-reviewer-b`/);

  // Ask the distributed read-only MCP for the next action of each Draft under auto review.
  const scenarios = [
    ['small-fix', 'low', '表示上の誤字を修正する', 'approval-gate'],
    ['auth-policy', 'high', '認可方針を変更する', 'spec-check'],
  ];
  writeFileSync(path.join(project, 'AGENTS.md'), '## Active Spec Directories\n' +
    scenarios.map(([feature]) => `- \`specs/${feature}/\``).join('\n') + '\n');
  mkdirSync(path.join(project, 'sdd'));
  writeFileSync(path.join(project, 'sdd/guardrails.yaml'), 'review:\n  pre_impl_check: auto\n');
  const messages = [{ id: 1, method: 'initialize', params: {
    protocolVersion: '2024-11-05', capabilities: {}, clientInfo: { name: 'test', version: '1' },
  } }];
  for (const [feature, risk, description] of scenarios) {
    const dir = path.join(project, 'specs', feature);
    mkdirSync(dir, { recursive: true });
    writeFileSync(path.join(dir, 'requirements.md'), `- **REQ-001**: ${description}\n- **AC-001** (REQ-001): ${description}\n`);
    writeFileSync(path.join(dir, 'design.md'), `# 設計\n${description}\n`);
    writeFileSync(path.join(dir, 'tasks.md'), `## T-001 ${description}\nApproval: Draft\nStatus: Planned\nRisk: ${risk}\n`);
    messages.push({ id: messages.length + 1, method: 'tools/call', params: { name: 'sdd_feature_state', arguments: { feature } } });
  }
  const input = messages.map(msg => JSON.stringify({ jsonrpc: '2.0', ...msg })).join('\n') + '\n';
  const output = run(process.execPath, ['mcp/sdd-forge-mcp/dist/index.js', '--root', project], 0, process.env, input).stdout;
  const responses = output.trim().split(/\r?\n/).map(line => JSON.parse(line));
  for (const [i, [feature, , , phase]] of scenarios.entries()) {
    const result = responses.find(reply => reply.id === i + 2);
    const state = JSON.parse(result.result.content[0].text);
    assert.equal(state.data?.nextAction.phase, phase, feature + ': ' + JSON.stringify(state));
  }
}

function profileHandoff() {
  assert.match(read(bootstrap + '/skills/bootstrap/SKILL.md'), /`design-system\/` 存在時のみ `design-sync-loop` を委譲/);
  assert.match(read(core + '/SKILL.md'), /`design-system\/` が存在する場合も既存規約へ整合/);
  const loop = read(bootstrap + '/skills/design-sync-loop/SKILL.md');
  assert.match(loop, /UI 対象かつ `design-system\/` 運用時のみ/);
  assert.match(loop, /resolve-design-sync\.py[^\n]*`skip` と `manual` は送信しない/);
  assert.match(loop, /`audit` がある場合は[^。\n]*`Design-Source` に/);
  for (const operation of ['pull', 'upload']) {
    for (const profile of ['none', 'custom']) {
      const request = { schema: 'design-sync-request/v1', ui_app: true, ds_profile: profile, operation,
        capability_resolved: true, provider_available: true, egress_permitted: true, setting: 'standing',
        feature: 'sample', session: 'local', destination: 'sample-design', records: [] };
      const decision = JSON.parse(run('python3', [bootstrap + '/scripts/resolve-design-sync.py'],
        0, process.env, JSON.stringify(request)).stdout);
      assert.equal(decision.action, profile === 'none' ? 'skip' : 'proceed', profile + ': ' + operation);
      if (profile === 'custom' && operation === 'upload') assert.equal(decision.audit?.decision, 'granted');
      else assert.equal(decision.audit, null, profile + ': ' + operation);
    }
  }
}

function installedCoreDocument(installRoot, name) {
  const file = name + '.md';
  const relative = core + '/templates/' + file;
  const document = readFileSync(path.join(installRoot, relative), 'utf8');
  assert.equal(document, read(relative), 'installed template differs from source: ' + file);
  const skill = readFileSync(path.join(installRoot, core, 'SKILL.md'), 'utf8');
  assert.ok(skill.split(/\r?\n/).some(line => line.trim() ===
    '- `templates/' + file + '` → `specs/<feature>/' + file + '`:'), 'missing Core output route: ' + file);
  assert.match(document, /^## Spec Amendments\s*$/m);
  if (name === 'requirements') {
    const lines = document.split(/\r?\n/);
    for (const id of ['001', '002']) {
      assert.ok(lines.some(line => line.startsWith('- **REQ-' + id + '**:')));
      assert.ok(lines.some(line => line.startsWith('- **AC-' + id + '** (REQ-' + id + '):')));
    }
  } else if (name === 'design') {
    const renderer = path.join(installRoot, bootstrap, 'scripts/render-design-template.mjs');
    assert.ok(skill.includes('`node <sdd-bootstrap>/scripts/render-design-template.mjs --risk '));
    const rendered = run(process.execPath, [renderer, '--risk', 'high']).stdout;
    assert.match(rendered, /^## データ \/ インターフェース契約$/m);
    assert.match(rendered, /^## 影響範囲・リスク考慮\r?\n\s*- [^\n]*セキュリティ・移行・ロールバック/m);
    assert.match(rendered, /^## テスト方針\r?\n\s*- [^\n]*AC-NNN/m);
  } else {
    assert.match(document, /^## T-001 [^\n]+\r?\nApproval: Draft\r?\nStatus: Planned\r?\nRisk: standard$/m);
    assert.match(document, /^### Scope$/m);
    assert.match(document, /^### Done When\r?\n- [^\n]*AC-001[^\n]*AC-002/m);
    assert.match(document, /^### Blockers\r?\n- None$/m);
  }
}

function layers() {
  const script = bootstrap + '/scripts/render-design-template.mjs';
  for (const risk of ['low', 'standard', 'high']) {
    const design = run(process.execPath, [script, '--risk', risk]).stdout;
    assert.match(design, /^## データ \/ インターフェース契約$/m);
    assert.match(design, /^## 影響範囲・リスク考慮\r?\n\s*- [^\n]*`Risk: high`[^\n]*セキュリティ・移行・ロールバック/m);
    assert.match(design, /^## テスト方針\r?\n\s*- [^\n]*`AC-NNN`/m);
    assert.equal(design.includes('## 問題設定の再検証'), risk !== 'low');
  }
  assert.match(run(process.execPath, [script, '--risk', 'medium'], 2).stderr, /risk must be low, standard or high/);
  const tasks = read(core + '/templates/tasks.md');
  assert.match(tasks, /^Risk: standard\s*$/m);
  assert.match(tasks, /^### Done When\r?\n- .*AC-001/m);
}

function traceability(project) {
  const dir = path.join(project, 'specs', 'sample');
  mkdirSync(dir, { recursive: true });
  const reqs = '- **REQ-001**: preserve the design record\n- **AC-001** (REQ-001): record exists\n';
  const tasks = '## T-001 Record design\nApproval: Draft\nStatus: Planned\nRisk: standard\n### Done When\n- AC-001\n';
  function check(requirements, task, exit) {
    writeFileSync(path.join(dir, 'requirements.md'), requirements);
    writeFileSync(path.join(dir, 'tasks.md'), task);
    const result = run(process.execPath, [quality + '/v2/check-traceability.mjs', '--root', project, '--feature', 'sample', '--strict'], exit);
    return JSON.parse(result.stdout);
  }
  assert.equal(check(reqs, tasks, 0).complete, true);
  const reqGap = check(reqs.replace('(REQ-001)', '(REQ-999)'), tasks, 1).gaps;
  assert.deepEqual(reqGap.brokenReqRefs, [{ ac: 'AC-001', missingReq: 'REQ-999' }]);
  const taskGap = check(reqs, tasks.replace('AC-001', 'AC-999'), 1).gaps;
  assert.deepEqual(taskGap.brokenAcRefs, [{ task: 'T-001', missingAc: 'AC-999' }]);
}

function fallback(reason) {
  const skill = read(bootstrap + '/skills/design-sync-loop/SKILL.md');
  const section = skill.split(/^## /m).find(part => /^(?:\d+\.\s*)?Capability Detection\b/.test(part));
  assert.ok(section, 'missing capability detection section');
  const rule = section.split(/\r?\n/).find(line => line.includes(reason) && line.includes('manual workflow used'));
  assert.ok(rule, 'missing manual fallback for ' + reason);
  for (const value of ['specs/<feature>/design.md', 'Design-Source', 'references/claude-design-workflow.md']) {
    assert.ok(rule.includes(value), 'missing fallback contract ' + value);
  }
}

function designConsent(test) {
  const skill = read(bootstrap + '/skills/design-sync-loop/SKILL.md');
  const loop = skill.split(/^## /m).find(section => /^(?:\d+\.\s*)?Mockup & Egress Consent Loop\b/.test(section));
  assert.ok(loop, 'missing mockup and egress consent loop');
  const [intro, ...steps] = loop.split(/^\d+\. (?=\*\*)/m);
  const resolution = steps.find(step => step.startsWith('**Resolve Egress Consent**'));
  assert.ok(resolution, 'missing consent resolution step');
  const setting = test === 'off' ? 'off' : 'per-feature';
  const rule = resolution.split(/\r?\n/).find(line => line.trimStart().startsWith('- `' + setting + '`:'));
  assert.ok(rule, 'missing consent policy for ' + setting);
  switch (test) {
    case 'initial':
      assert.match(rule, /当該 `\(feature, session\)` で未同意なら、[^。]*送信内容・送信先[^。]*外部保持リスク・適用範囲を明示説明して人間の明示同意を得てから `push`/);
      break;
    case 'prompt':
      assert.match(intro, /結果が `prompt` なら同意の回答を加えて再実行する/);
      assert.match(rule, /で未同意なら、[^。]*人間の明示同意を得てから `push`/);
      break;
    case 'off':
      assert.match(rule, /アップロードせず手動フォールバック（`Egress-Consent: not-permitted`, `Ds-Upload-Consent-Setting: off`/);
      break;
    case 'decline':
      assert.match(rule, /拒否時はアップロードせず手動フォールバック/);
      break;
  }
}

function designSystem(project, powershell) {
  const skill = read(bootstrap + '/skills/design-sync-loop/SKILL.md');
  assert.match(skill, /Figma DTCG JSON[^\n]*ローカルファイル[^\n]*design-tokens\.json/);
  assert.match(skill, /Generate Mockups[^\n]*トークン準拠/);
  const directory = path.join(project, 'design-system');
  mkdirSync(directory);
  const template = read(bootstrap + '/skills/design-sync-loop/templates/design-tokens.template.json');
  const tokens = path.join(directory, 'design-tokens.json');
  const env = { ...process.env, SDD_DESIGN_SYSTEM_ENFORCE: 'error' };
  const command = powershell || 'sh';
  const args = powershell
    ? ['-NoProfile', '-File', quality + '/check-design-system.ps1', '-ProjectRoot', project]
    : [quality + '/check-design-system.sh', project];
  writeFileSync(tokens, template);
  run(command, args, 0, env);
  for (const group of ['color', 'typography', 'spacing']) {
    const malformed = JSON.parse(template);
    delete malformed[group];
    writeFileSync(tokens, JSON.stringify(malformed));
    const result = run(command, args, 1, env);
    assert.ok((result.stdout + result.stderr).includes('token group ' + group + ' missing'));
  }
}

const checks = new Map([
  ['interview', interview], ['TEST-006', humanQuestions], ['TEST-017', bugfixReview], ['TEST-019', profileHandoff],
  ...['requirements', 'design', 'tasks'].map(doc => ['TEST-007-' + doc, (_, installRoot) => installedCoreDocument(installRoot, doc)]),
  ['layers', layers], ['traceability', traceability],
  ['design-system', designSystem], ['tool-unavailable', () => fallback('利用不可')],
  ['auth-failed', () => fallback('認証失敗')],
  ...['initial', 'prompt', 'off', 'decline'].map(test => ['consent-' + test, () => designConsent(test)]),
]);
const name = process.argv[2];
assert.ok(checks.has(name), 'unknown bootstrap contract: ' + name);
const temp = mkdtempSync(path.join(tmpdir(), 'bootstrap-core-contract-'));
try {
  checks.get(name)(temp, process.argv[3]);
  process.stdout.write(`Verified Core ${name}\n`);
} finally {
  rmSync(temp, { recursive: true, force: true });
}
