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

function run(command, args, status = 0, env = process.env) {
  const result = spawnSync(command, args, { cwd: root, encoding: 'utf8', env });
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
  ['interview', interview], ['layers', layers], ['traceability', traceability],
  ['design-system', designSystem], ['tool-unavailable', () => fallback('利用不可')],
  ['auth-failed', () => fallback('認証失敗')],
]);
const name = process.argv[2];
assert.ok(checks.has(name), 'unknown bootstrap contract: ' + name);
const temp = mkdtempSync(path.join(tmpdir(), 'bootstrap-core-contract-'));
try {
  checks.get(name)(temp, process.argv[3]);
  console.log('Verified Core ' + name);
} finally {
  rmSync(temp, { recursive: true, force: true });
}
