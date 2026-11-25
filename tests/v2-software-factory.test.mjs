import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { after, describe, it, mock } from 'node:test';
import { fileURLToPath } from 'node:url';
import {
  analyzeTraceability,
  formatTraceabilityMarkdown,
  scopeMatchesFile,
} from '../plugins/sdd-quality-loop/scripts/v2/check-traceability.mjs';
import { writeSpecBaseline } from '../plugins/sdd-quality-loop/scripts/v2/record-spec-baseline.mjs';
import {
  buildDecisionViewData,
  detectDomains,
  parseAlternativesRejected,
  parseOpenQuestions,
  renderDecisionViewHtml,
  renderDecisionViewMarkdown,
} from '../plugins/sdd-quality-loop/scripts/v2/render-decision-view.mjs';
import { runSddGate } from '../plugins/sdd-quality-loop/scripts/v2/run-sdd-gate.mjs';
import { runDoctor } from '../plugins/sdd-quality-loop/scripts/v2/sdd-doctor.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..');
const TRACE_CLI = path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/check-traceability.mjs');
const VIEW_CLI = path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/render-decision-view.mjs');
const GATE_CLI = path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/run-sdd-gate.mjs');

const tempDirs = [];

function trackTempDir(prefix) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), prefix));
  tempDirs.push(dir);
  return dir;
}

after(() => {
  for (const dir of tempDirs) {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

function createMultiDomainFixture() {
  const dir = trackTempDir('sdd-factory-test-');
  fs.mkdirSync(path.join(dir, 'specs', 'billing-sync'), { recursive: true });
  fs.mkdirSync(path.join(dir, 'db', 'migrations'), { recursive: true });
  fs.mkdirSync(path.join(dir, 'infra', 'aws'), { recursive: true });
  fs.mkdirSync(path.join(dir, 'src'), { recursive: true });

  fs.writeFileSync(
    path.join(dir, 'specs', 'billing-sync', 'requirements.md'),
    `# 要件: billing-sync

## 要件（Requirements）
- **REQ-001**: 注文確定時に請求レコードを作成する
- **REQ-002**: PostgreSQL スキーマ移行を無停止で適用する
- **REQ-003**: AWS CDK で CloudWatch アラームを配備する

## 受入条件（Acceptance Criteria）
- **AC-001** (REQ-001): Given 注文確定, When API 実行, Then 請求レコードが作成される
- **AC-002** (REQ-002): Given 隔離 PostgreSQL, When Flyway 適用, Then 旧アプリ互換を維持する
- **AC-003** (REQ-003): Given AWS CDK synth, When validate 実行, Then 必須監視アラームが定義される

## Open Questions（未確定事項・AI 仮決定）
| ID | 分類 | 設計した事実・AI 仮決定 | なぜそうしたか | 人が判断する問い | 状態 | 影響タスク |
|---|---|---|---|---|---|---|
| OQ-001 | 不可逆リスク | 旧列 legacy_total は別タスクまで保持する | expand-contract で無停止切替するため | 旧列の削除時期を次スプリント以降にしてよいか？ | Provisional | T-002 |

## Spec Amendments
- （初期版のため変更なし）
`,
    'utf8',
  );

  fs.writeFileSync(
    path.join(dir, 'specs', 'billing-sync', 'design.md'),
    `# 設計: billing-sync

## 方針
Software API + PostgreSQL Flyway + AWS CDK の 3 領域を独立タスクで構築する。

## 採らなかった設計（Alternatives Rejected）
| 候補案 | 不採用理由 | 再検討条件 |
| :--- | :---: | ---: |
| 単一トランザクションで即 DROP COLUMN | 旧アプリ稼働中にエラーが発生するため | メンテ停止が許容される場合 |

## Spec Amendments
- （初期版のため変更なし）
`,
    'utf8',
  );

  fs.writeFileSync(
    path.join(dir, 'specs', 'billing-sync', 'tasks.md'),
    `# タスク: billing-sync

## T-001 請求 API 実装
Approval: Approved
Status: Implementation Complete
Risk: standard

### Scope
- \`src/billing.js\`

### Done When
- AC-001 の単体テストが通過すること

### Blockers
- None

## T-002 PostgreSQL expand マイグレーション
Approval: Approved
Status: Implementation Complete
Risk: high

### Scope
- \`db/migrations/V*.sql\`

### Done When
- AC-002 の隔離 PostgreSQL 検証が通過すること

### Blockers
- None

## T-003 AWS CDK 監視スタック追加
Approval: Approved
Status: Planned
Risk: high

### Scope
- \`infra/aws/billing-alarm.ts\`

### Done When
- AC-003 の AWS CDK validate が通過すること

### Blockers
- T-001

## Spec Amendments
- 2026-11-21: AC-999 や PostgreSQL のメモは最終タスク T-003 に漏れてはならない
`,
    'utf8',
  );

  fs.writeFileSync(path.join(dir, 'src', 'billing.js'), 'export function createInvoice(id) { return { id, cents: 100 }; }\n', 'utf8');
  fs.writeFileSync(path.join(dir, 'db', 'migrations', 'V002__add_amount_cents.sql'), 'ALTER TABLE invoices ADD COLUMN amount_cents BIGINT;\n', 'utf8');
  fs.writeFileSync(path.join(dir, 'infra', 'aws', 'billing-alarm.ts'), 'export const alarmConfig = { actions: ["cloudwatch:PutMetricAlarm"] };\n', 'utf8');

  writeSpecBaseline({ feature: 'billing-sync', projectRoot: dir });
  return dir;
}

describe('Software Factory v2.x (SQL + AWS + Azure + Software SDLC)', () => {
  it('Phase A-1: sql-develop skill, policy, and contract template align cleanly with SDD Core v2', () => {
    const skill = fs.readFileSync(
      path.join(REPO_ROOT, 'plugins/sdd-implementation/skills/sql-develop/SKILL.md'),
      'utf8',
    );
    const policy = fs.readFileSync(
      path.join(REPO_ROOT, 'plugins/sdd-implementation/skills/sql-develop/references/sql-development-policy.md'),
      'utf8',
    );
    const contractTpl = fs.readFileSync(
      path.join(REPO_ROOT, 'plugins/sdd-implementation/skills/sql-develop/templates/sql-development-contract.md'),
      'utf8',
    );
    assert.match(skill, /Risk: low \| standard \| high/);
    assert.match(skill, /OQ-NNN/);
    assert.doesNotMatch(skill, /lite-spec|interviewer|handshake|--lite/);
    assert.match(policy, /run-sdd-gate\.mjs/);
    assert.doesNotMatch(policy, /lite-gate|quality-gate|evidence-bundle/);
    assert.match(contractTpl, /影響とリスク階層/);
    assert.doesNotMatch(contractTpl, /Lite候補|Fullの理由/);
  });

  it('Phase A-2 & A-3: render-decision-view.mjs skips GFM aligned separators, isolates feature gates, and escapes HTML/MD', () => {
    const dir = createMultiDomainFixture();
    // Create a gate report for another feature sharing prefix "billing" vs "billing-sync"
    fs.mkdirSync(path.join(dir, 'specs', 'billing'), { recursive: true });
    fs.writeFileSync(path.join(dir, 'specs', 'billing', 'requirements.md'), '# Billing\n', 'utf8');
    fs.writeFileSync(path.join(dir, 'specs', 'billing', 'tasks.md'), '# Tasks\n', 'utf8');
    fs.mkdirSync(path.join(dir, 'reports', 'quality-gate'), { recursive: true });
    fs.writeFileSync(
      path.join(dir, 'reports', 'quality-gate', 'billing-sync-T-001.execution.json'),
      JSON.stringify({ feature: 'billing-sync', taskId: 'T-001', verdict: 'PASS', checks: {} }),
      'utf8',
    );

    const siblingData = buildDecisionViewData({ feature: 'billing', projectRoot: dir });
    assert.equal(siblingData.gateResults.length, 0, 'prefix collision must not pull billing-sync gate into billing');

    const data = buildDecisionViewData({ feature: 'billing-sync', projectRoot: dir });
    assert.deepEqual(new Set(data.domains), new Set(['Software', 'SQL', 'AWS']));
    assert.equal(data.highestRisk, 'high');
    assert.equal(data.counts.openQuestionsProvisional, 1);
    // GFM separator row `| :--- | :---: | ---: |` must NOT be parsed as an alternative
    assert.equal(data.counts.alternativesRejected, 1);
    assert.equal(data.alternativesRejected[0].option, '単一トランザクションで即 DROP COLUMN');

    // Domain detection must not false-positive on AWS Graviton ARM or React migration
    assert.deepEqual(detectDomains('Deploy Node.js API on AWS Graviton ARM Lambda'), ['AWS', 'Software']);
    assert.deepEqual(detectDomains('React migration for UI components'), ['Software']);
    assert.ok(detectDomains('Edit `domain/` context map').includes('DDD'));

    const md = renderDecisionViewMarkdown(data);
    assert.match(md, /OQ-001 \[不可逆リスク\]/);
    assert.match(md, /設計した事実（仮決定）/);
    assert.match(md, /人が判断する問い/);

    const html = renderDecisionViewHtml(data);
    assert.match(html, /<!doctype html>/i);
    assert.match(html, /spec-check:/);
    assert.match(html, /sdd-gate 実行状況/);

    // Path traversal must fail with exit code 2 on CLI
    const badRes = spawnSync(process.execPath, [VIEW_CLI, '--feature', '../evil', '--root', dir], { encoding: 'utf8' });
    assert.equal(badRes.status, 2);
  });

  it('Phase A-3 (fail-closed OQ): handles escaped pipes, bold/backtick IDs, JP commas, and non-Confirmed statuses', () => {
    const oqs = parseOpenQuestions(`
## Open Questions
| ID | 分類 | 設計した事実・AI 仮決定 | なぜそうしたか | 人が判断する問い | 状態 | 影響タスク |
|---|---|---|---|---|---|---|
| **OQ-001** | 不可逆リスク | A \\| B (<old> -> <new>) | 理由 | 問い1 | \`Provisional\` | T-001、\`t-002\` |
| \`OQ-002\` | 事業判断 | 仮決定2 | 理由2 | 問い2 | 未確定 | T-SQL-01/T-003 |
| OQ-003 | 事業判断 | 確定済み | 理由3 | 問い3 | Confirmed | T-002 |
\`\`\`markdown
| OQ-999 | 事業判断 | コード例は無視 | 理由 | 問い | Provisional | T-002 |
\`\`\`
`);
    assert.equal(oqs.length, 3);
    assert.equal(oqs[0].id, 'OQ-001');
    assert.equal(oqs[0].fact, 'A | B (<old> -> <new>)');
    assert.equal(oqs[0].confirmed, false);
    assert.deepEqual(oqs[0].impactedTasks, ['T-001', 'T-002']);

    assert.equal(oqs[1].id, 'OQ-002');
    assert.equal(oqs[1].confirmed, false);
    assert.deepEqual(oqs[1].impactedTasks, ['T-SQL-01', 'T-003']);

    assert.equal(oqs[2].confirmed, true);

    // End-to-end Risk: high gate blocks on non-canonical unresolved status + JP comma, passes once Confirmed
    const dir = createMultiDomainFixture();
    const reqPath = path.join(dir, 'specs', 'billing-sync', 'requirements.md');
    fs.writeFileSync(
      reqPath,
      fs
        .readFileSync(reqPath, 'utf8')
        .replace('| OQ-001 | 不可逆リスク | 旧列 legacy_total は別タスクまで保持する | expand-contract で無停止切替するため | 旧列の削除時期を次スプリント以降にしてよいか？ | Provisional | T-002 |',
          '| **OQ-001** | 不可逆リスク | A \\| B | expand-contract | 許容するか？ | 未確定 | T-001、`t-002` |')
        .replace('- （初期版のため変更なし）', '- 2026-11-21: OQ 書式テスト'),
      'utf8',
    );

    // #824: legacy `Risk: critical` blocks exactly like `high`; `standard` does not.
    const tasksPath = path.join(dir, 'specs', 'billing-sync', 'tasks.md');
    const originalTasks = fs.readFileSync(tasksPath, 'utf8');
    const t002Risk = '## T-002 PostgreSQL expand マイグレーション\nApproval: Approved\nStatus: Implementation Complete\nRisk: high';
    assert.ok(originalTasks.includes(t002Risk));
    for (const [risk, expectPassed] of [['critical', false], ['Critical', false], ['standard', true]]) {
      fs.writeFileSync(tasksPath, originalTasks.replace(t002Risk, t002Risk.replace('Risk: high', `Risk: ${risk}`)), 'utf8');
      const res = runSddGate({
        feature: 'billing-sync',
        taskId: 'T-002',
        projectRoot: dir,
        changedFiles: ['db/migrations/V002__add_amount_cents.sql'],
        commands: [{ label: 'ok', command: 'node -e "process.exit(0)"' }],
        skipDrift: true,
      });
      assert.equal(res.result.checks.openQuestions.passed, expectPassed, `Risk: ${risk}`);
    }
    fs.writeFileSync(tasksPath, originalTasks, 'utf8');

    const blocked = runSddGate({
      feature: 'billing-sync',
      taskId: 'T-002',
      projectRoot: dir,
      changedFiles: ['db/migrations/V002__add_amount_cents.sql'],
      commands: [{ label: 'ok', command: 'node -e "process.exit(0)"' }],
    });
    assert.equal(blocked.result.verdict, 'FAIL');
    assert.equal(blocked.result.checks.openQuestions.passed, false);
    assert.deepEqual(blocked.result.checks.openQuestions.provisionalIds, ['OQ-001']);

    // Confirm OQ-001 -> T-002 PASSES and records telemetry including skip flags
    fs.writeFileSync(
      reqPath,
      fs.readFileSync(reqPath, 'utf8').replace('| 未確定 |', '| Confirmed |'),
      'utf8',
    );
    const passed = runSddGate({
      feature: 'billing-sync',
      taskId: 'T-002',
      projectRoot: dir,
      changedFiles: ['db/migrations/V002__add_amount_cents.sql'],
      commands: [{ label: 'ok', command: 'node -e "process.exit(0)"' }],
    });
    assert.equal(passed.result.verdict, 'PASS');
    const metrics = fs
      .readFileSync(path.join(dir, '.sdd', 'factory-metrics.jsonl'), 'utf8')
      .trim()
      .split('\n')
      .map((l) => JSON.parse(l));
    assert.equal(metrics.at(-1).sensorsSkipped, false);
    assert.equal(metrics.at(-1).driftSkipped, false);
  });

  it('Phase B-1: check-traceability.mjs propagates transitive Blockers, ignores Spec Amendments, and matches Scopes accurately', () => {
    const dir = createMultiDomainFixture();

    // Spec Amendments note mentioning AC-999 & PostgreSQL must NOT leak into T-003!
    const baseReport = analyzeTraceability({ feature: 'billing-sync', projectRoot: dir, changedIds: ['REQ-001'] });
    assert.equal(baseReport.complete, true);
    assert.deepEqual(baseReport.gaps.brokenAcRefs, []);
    const t3 = baseReport.tasks.find((t) => t.id === 'T-003');
    assert.equal(t3.acRefs.includes('AC-999'), false);
    assert.equal(t3.domains.includes('SQL'), false);

    // Transitive Blockers propagation: REQ-001 -> T-001 (direct) -> T-003 (transitive via Blockers: T-001)!
    assert.deepEqual(baseReport.impact.directImpactedTasks, ['T-001']);
    assert.deepEqual(baseReport.impact.transitiveImpactedTasks, ['T-003']);
    assert.deepEqual(baseReport.impact.impactedTasks, ['T-001', 'T-003']);
    assert.deepEqual(baseReport.impact.reusableTasks, ['T-002']);

    // Scope glob & boundary accuracy (no substring false positives!)
    assert.equal(scopeMatchesFile('db/migrations/V*.sql', './db/migrations/V002__add_amount_cents.sql'), true);
    assert.equal(scopeMatchesFile('src/bill/*', 'src/billing-v2/other.ts'), false);
    assert.equal(scopeMatchesFile('src/billing.js', 'src/billing.jsx'), false);
    assert.equal(scopeMatchesFile('src/index.ts', 'index.ts'), false);

    const fileImpact = analyzeTraceability({
      feature: 'billing-sync',
      projectRoot: dir,
      changedFiles: ['./db/migrations/V002__add_amount_cents.sql'],
    });
    assert.deepEqual(fileImpact.impact.impactedTasks, ['T-002']);
    assert.deepEqual(fileImpact.impact.reusableTasks, ['T-001', 'T-003']);

    const md = formatTraceabilityMarkdown(baseReport);
    assert.match(md, /Impacted Tasks \(re-run\)\*\*: T-001, T-003/);
    assert.match(md, /Transitive \(via Blockers\): T-003/);

    // CLI exit code 2 on missing feature (distinct from --strict exit 1)
    const errRes = spawnSync(process.execPath, [TRACE_CLI, '--feature', 'no-such-feature', '--root', dir], {
      encoding: 'utf8',
    });
    assert.equal(errRes.status, 2);
  });

  it('Phase B-2: SQL & Cloud IaC sensors catch multiline/untracked real-world issues without comment false positives', () => {
    const dir = createMultiDomainFixture();
    // Initialize git repo so we also verify discoverChangedFiles picks up NEW UNTRACKED files!
    execFileSync('git', ['init', '-q'], { cwd: dir });
    execFileSync('git', ['config', 'user.email', 'test@example.invalid'], { cwd: dir });
    execFileSync('git', ['config', 'user.name', 'Test'], { cwd: dir });
    execFileSync('git', ['add', '.'], { cwd: dir });
    execFileSync('git', ['commit', '-qm', 'initial'], { cwd: dir });

    // 1. Safe SQL with cautionary comment + per-statement allow marker + benign egress comment -> PASS!
    fs.writeFileSync(
      path.join(dir, 'db', 'migrations', 'V003__safe.sql'),
      `-- Do not DROP TABLE users without review
-- sdd-allow-destructive
DROP TABLE temp_staging;
UPDATE invoices
SET status = 'paid'
WHERE id = 42;
`,
      'utf8',
    );
    fs.writeFileSync(
      path.join(dir, 'infra', 'aws', 'safe.tf'),
      `egress {
  from_port   = 443
  to_port     = 443
  cidr_blocks = ["0.0.0.0/0"] # ticket #2022
}
`,
      'utf8',
    );
    const safeRes = runSddGate({
      feature: 'billing-sync',
      taskId: 'T-001',
      projectRoot: dir,
      commands: [{ label: 'ok', command: 'node -e "process.exit(0)"' }],
    });
    assert.equal(safeRes.result.verdict, 'PASS', JSON.stringify(safeRes.result.checks.nonFunctionalSensors, null, 2));

    // 2. New UNTRACKED files with multiline SQL bypass, second unapproved DROP, multiline Terraform ingress/IAM, and leaked AWS key -> FAIL!
    fs.writeFileSync(
      path.join(dir, 'db', 'migrations', 'V004__bad.sql'),
      `-- sdd-allow-destructive
DROP TABLE temp_ok;
DROP DATABASE production_db;
TRUNCATE audit_log;
UPDATE invoices
SET status = 'void';
`,
      'utf8',
    );
    fs.writeFileSync(
      path.join(dir, 'infra', 'aws', 'bad.tf'),
      `resource "aws_security_group" "ssh" {
  ingress {
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_iam_policy" "wide" {
  actions = ["s3:GetObject", "*"]
}
`,
      'utf8',
    );
    fs.writeFileSync(path.join(dir, 'src', 'leaked.js'), 'export const k = "AKIAIOSFODNN7EXAMPLE";\n', 'utf8');

    // Note: NO explicit changedFiles passed — must discover new untracked files automatically!
    const badRes = runSddGate({
      feature: 'billing-sync',
      taskId: 'T-001',
      projectRoot: dir,
      commands: [{ label: 'ok', command: 'node -e "process.exit(0)"' }],
    });
    assert.equal(badRes.result.verdict, 'FAIL');
    const findings = badRes.result.checks.nonFunctionalSensors.findings;
    const rules = new Set(findings.map((f) => f.rule));
    assert.ok(rules.has('SQL_DESTRUCTIVE_DDL'), 'second unapproved DROP DATABASE & TRUNCATE must be caught');
    assert.ok(rules.has('SQL_UNGUARDED_DELETE_OR_UPDATE'), 'multiline UPDATE without WHERE must be caught');
    assert.ok(rules.has('CLOUD_OPEN_ADMIN_PORT'), 'multiline Terraform port 22 ingress must be caught');
    assert.ok(rules.has('CLOUD_WILDCARD_IAM'), 'Terraform actions = [...] wildcard must be caught');
    assert.ok(rules.has('SECRET_AWS_KEY'), 'untracked leaked.js AWS key must be caught');

    // Verify --skip-sensors CLI flag works cleanly and logs sensorsSkipped: true
    const skipCli = spawnSync(
      process.execPath,
      [GATE_CLI, '--feature', 'billing-sync', '--task', 'T-001', '--root', dir, '--skip-sensors', '--cmd', 'ok=node -e "process.exit(0)"'],
      { encoding: 'utf8' },
    );
    assert.equal(skipCli.status, 0, skipCli.stderr);
  });

  it('Phase C: sdd-doctor.mjs walks nested sdd/knowledge/**/INDEX.md with CRLF-normalized 3,000-char limit', () => {
    const dir = createMultiDomainFixture();
    fs.mkdirSync(path.join(dir, 'sdd', 'knowledge', 'sql'), { recursive: true });
    // Exactly 2,995 LF chars with CRLF line endings -> must NOT falsely warn on Windows!
    const nearLimit = `${'a'.repeat(50)}\r\n`.repeat(58);
    fs.writeFileSync(path.join(dir, 'sdd', 'knowledge', 'sql', 'INDEX.md'), nearLimit, 'utf8');
    let report = runDoctor({ root: dir });
    assert.equal(report.findings.some((f) => f.category === 'knowledge'), false);

    // Over 3,000 normalized chars in nested domain folder -> MUST WARN!
    fs.writeFileSync(path.join(dir, 'sdd', 'knowledge', 'sql', 'INDEX.md'), `# SQL Index\n${'x'.repeat(3050)}\n`, 'utf8');
    report = runDoctor({ root: dir });
    assert.ok(report.findings.some((f) => f.severity === 'WARN' && f.category === 'knowledge' && /sdd\/knowledge\/sql\/INDEX\.md/.test(f.path)));
  });

  it('parseAlternativesRejected skips aligned separators and handles escaped pipes', () => {
    const alts = parseAlternativesRejected(`
## 採らなかった設計（Alternatives Rejected）
| 候補案 | 不採用理由 | 再検討条件 |
| :--- | :---: | ---: |
| 案 A \\| B | コスト高 | 予算増 |
| <placeholder> | ignored | ignored |
`);
    assert.equal(alts.length, 1);
    assert.equal(alts[0].option, '案 A | B');
  });
});

describe('#817 invalid Blockers are reported and never scheduled', () => {
  it('unknown and self dependencies are listed apart from cycles, excluded with their downstream, and fail --strict', () => {
    const dir = trackTempDir('sdd-trace-invalid-');
    fs.mkdirSync(path.join(dir, 'specs', 'deps'), { recursive: true });
    fs.writeFileSync(path.join(dir, 'AGENTS.md'), '# t\n');
    fs.writeFileSync(
      path.join(dir, 'specs', 'deps', 'requirements.md'),
      '# r\n\n- **REQ-001**: x\n- **AC-001** (REQ-001): y\n',
      'utf8',
    );
    const task = (id, blockers, scope) =>
      `## ${id} t\nApproval: Approved\nStatus: Planned\nRisk: standard\n\n### Scope\n- \`${scope}\`\n\n### Done When\n- AC-001\n\n### Blockers\n- ${blockers}\n`;
    fs.writeFileSync(
      path.join(dir, 'specs', 'deps', 'tasks.md'),
      ['# tasks', task('T-001', 'None', 'src/a.js'), task('T-002', 'T-404', 'src/b.js'),
        task('T-003', 'T-002', 'src/c.js'), task('T-004', 'T-004', 'src/d.js')].join('\n'),
      'utf8',
    );
    const run = (...extra) =>
      spawnSync(process.execPath, [TRACE_CLI, '--feature', 'deps', '--root', dir, '--plan-batches', ...extra], { encoding: 'utf8' });
    const res = run();
    assert.equal(res.status, 0, res.stderr);
    const plan = JSON.parse(res.stdout).executionPlan;
    assert.deepEqual(plan.batches.flat(), ['T-001'], 'only the valid task is scheduled');
    assert.deepEqual(plan.unknownBlockers, [{ task: 'T-002', blocker: 'T-404' }]);
    assert.deepEqual(plan.invalidBlockerTasks.sort(), ['T-002', 'T-003', 'T-004']);
    assert.deepEqual(plan.cyclicTasks, [], 'invalid dependencies are not reported as cycles');
    assert.equal(run('--strict').status, 1);
  });
});

describe('#817 review: only bare Blocker IDs are declared dependencies', () => {
  it('prose mentioning the own ID or a range does not block; cycles stay visible next to invalid tasks', () => {
    const dir = trackTempDir('sdd-trace-prose-');
    fs.mkdirSync(path.join(dir, 'specs', 'prose'), { recursive: true });
    fs.writeFileSync(path.join(dir, 'AGENTS.md'), '# t\n');
    fs.writeFileSync(path.join(dir, 'specs', 'prose', 'requirements.md'), '# r\n\n- **REQ-001**: x\n- **AC-001** (REQ-001): y\n', 'utf8');
    const task = (id, blockersBody, scope) =>
      `## ${id} t\nApproval: Approved\nStatus: Planned\nRisk: standard\n\n### Scope\n- \`${scope}\`\n\n### Done When\n- AC-001\n\n### Blockers\n\n${blockersBody}\n`;
    fs.writeFileSync(
      path.join(dir, 'specs', 'prose', 'tasks.md'),
      [
        '# tasks',
        task('T-001', '- None', 'src/a.js'),
        task('T-002', 'T-001\n\n(records the T-002 -> T-001 edge; see T-001.md and the T-NNN-LIST note)', 'src/b.js'),
        task('T-003', '- T-001\n- Covers T-002..T-005 once they land', 'src/c.js'),
        task('T-004', '- T-005', 'src/d.js'),
        task('T-005', '- T-004, T-404', 'src/e.js'),
        task('T-006', '- None\n<!--\nT-777\n-->\n- T-XXX\n- T-NNN', 'src/f.js'),
      ].join('\n'),
      'utf8',
    );
    const res = spawnSync(process.execPath, [TRACE_CLI, '--feature', 'prose', '--root', dir, '--plan-batches'], { encoding: 'utf8' });
    assert.equal(res.status, 0, res.stderr);
    const plan = JSON.parse(res.stdout).executionPlan;
    assert.deepEqual(plan.batches.flat().sort(), ['T-001', 'T-002', 'T-003', 'T-006'], 'prose, comments and placeholders never block');
    assert.deepEqual(plan.unknownBlockers, [{ task: 'T-005', blocker: 'T-404' }], 'only bare IDs are checked for existence');
    assert.deepEqual(plan.invalidBlockerTasks.sort(), ['T-004', 'T-005']);
    assert.deepEqual(plan.cyclicTasks.sort(), ['T-004', 'T-005'], 'a cycle stays visible even when it touches an invalid task');
  });
});

describe('#816 overlapping Scopes never share a wave', () => {
  it('same file through a symlink, prose bullets, notes and braces serialize; empty Scope runs alone; independent paths stay parallel', () => {
    const dir = trackTempDir('sdd-trace-scope-');
    fs.mkdirSync(path.join(dir, 'specs', 'scope'), { recursive: true });
    fs.mkdirSync(path.join(dir, 'src'), { recursive: true });
    fs.writeFileSync(path.join(dir, 'src', 'a.ts'), '', 'utf8');
    fs.symlinkSync('src', path.join(dir, 'linked'), 'dir');
    fs.writeFileSync(path.join(dir, 'AGENTS.md'), '# t\n');
    fs.writeFileSync(path.join(dir, 'specs', 'scope', 'requirements.md'), '# r\n\n- **REQ-001**: x\n- **AC-001** (REQ-001): y\n', 'utf8');
    const task = (id, scopeBody) =>
      `## ${id} t\nApproval: Approved\nStatus: Planned\nRisk: standard\n\n### Scope\n${scopeBody}\n\n### Done When\n- AC-001\n\n### Blockers\n- None\n`;
    const plan = (tasks) => {
      fs.writeFileSync(path.join(dir, 'specs', 'scope', 'tasks.md'), ['# tasks', ...tasks].join('\n'), 'utf8');
      const res = spawnSync(process.execPath, [TRACE_CLI, '--feature', 'scope', '--root', dir, '--plan-batches'], { encoding: 'utf8' });
      assert.equal(res.status, 0, res.stderr);
      return JSON.parse(res.stdout).executionPlan.batches;
    };
    const serialized = (batches) => batches.every((wave) => wave.length === 1);

    assert.ok(serialized(plan([task('T-001', '- `src/a.ts`'), task('T-002', '- `linked/a.ts`')])), 'one file through a symlinked directory');
    assert.ok(serialized(plan([task('T-001', '- `src/new.ts`'), task('T-002', '- `linked/new.ts`')])), 'a not-yet-created file under a symlinked directory');
    assert.ok(serialized(plan([task('T-001', '- src/a.ts を更新'), task('T-002', '- `src/a.ts`')])), 'a bare bullet with prose after the path');
    assert.ok(serialized(plan([task('T-001', '- src/a.ts(rename only)'), task('T-002', '- `src/a.ts`')])), 'a trailing note on the path');
    assert.ok(serialized(plan([task('T-001', '- `src/{a,b}.ts`'), task('T-002', '- `src/b.ts`')])), 'brace alternatives');
    assert.ok(serialized(plan([task('T-001', '- `src/a.ts`'), task('T-002', '- 未定')])), 'a Scope with no path claims nothing it can share');
    assert.ok(serialized(plan([task('T-001', '- `src/a.ts`'), task('T-002', '')])), 'an empty Scope runs alone');
    assert.deepEqual(plan([task('T-001', '- `src/a.ts`'), task('T-002', '- `docs/b.md`')]), [['T-001', 'T-002']], 'independent paths stay parallel');
    assert.deepEqual(
      plan([task('T-001', '- `src/a.ts`'), task('T-002', '- 未定'), task('T-003', '- `docs/b.md`')]),
      [['T-001', 'T-003'], ['T-002']],
      'a task without a Scope waits for its own wave without holding back the others',
    );
  });
});

describe('#815 CLI locks are held by their owner, not by the exiting CLI process', () => {
  const TASK_LOCK_CLI = path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/task-lock.mjs');
  const lockCli = (dir, ...args) => spawnSync(process.execPath, [TASK_LOCK_CLI, ...args, '--feature', 'f', '--root', dir], { encoding: 'utf8' });

  it('ship acquires, the child re-acquires with the same owner, others are refused, and the owner releases', () => {
    const dir = trackTempDir('sdd-lock-owner-');
    fs.writeFileSync(path.join(dir, 'AGENTS.md'), '# t\n');
    assert.equal(lockCli(dir, 'acquire', '--owner', 'ship-1').status, 0);
    const status = JSON.parse(lockCli(dir, 'status').stdout);
    assert.equal(status.locked, true);
    assert.equal(status.stale, false, `a held lock stays active after the CLI exits (${status.staleReason})`);
    const child = lockCli(dir, 'acquire', '--owner', 'ship-1');
    assert.equal(child.status, 0, child.stdout);
    assert.equal(JSON.parse(child.stdout).reentrant, true);
    const other = lockCli(dir, 'acquire', '--owner', 'ship-2');
    assert.equal(other.status, 1);
    assert.equal(JSON.parse(other.stdout).stale, false);
    assert.equal(lockCli(dir, 'release', '--owner', 'ship-1').status, 0);
    assert.equal(JSON.parse(lockCli(dir, 'status').stdout).locked, false);
  });

  it('an expired owner lock is stale and recoverable; a CLI acquire without --owner is refused', () => {
    const dir = trackTempDir('sdd-lock-expiry-');
    fs.writeFileSync(path.join(dir, 'AGENTS.md'), '# t\n');
    assert.equal(lockCli(dir, 'acquire', '--owner', 'ship-1', '--ttl', '1').status, 0);
    const lockPath = path.join(dir, '.sdd', 'locks', 'f.lock');
    const record = JSON.parse(fs.readFileSync(lockPath, 'utf8'));
    record.expiresAt = '2020-01-01T00:00:00.000Z';
    fs.writeFileSync(lockPath, JSON.stringify(record), 'utf8');
    assert.equal(JSON.parse(lockCli(dir, 'status').stdout).staleReason, 'ttl-expired');
    assert.equal(lockCli(dir, 'acquire', '--owner', 'ship-2').status, 1, 'stale locks are not taken silently');
    assert.equal(lockCli(dir, 'acquire', '--owner', 'ship-2', '--break-stale').status, 0);
    const noOwner = spawnSync(process.execPath, [TASK_LOCK_CLI, 'acquire', '--feature', 'g', '--root', dir], { encoding: 'utf8' });
    assert.equal(noOwner.status, 2, noOwner.stdout);
    assert.match(noOwner.stderr, /--owner/);
  });
});

describe('#830 one approval grammar for the gate, the decision view and MCP', () => {
  it('Approved with an optional (note) is approved; other case and trailing words are not', async () => {
    const { isApprovedValue } = await import('../plugins/sdd-quality-loop/scripts/v2/v2-readonly-core.mjs');
    const cases = [
      ['Approved', true],
      ['Approved (2026-11-01 owner)', true],
      ['approved', false],
      ['APPROVED', false],
      ['Approved yes', false],
      ['Approved-ish', false],
      ['Draft', false],
    ];
    for (const [value, expected] of cases) assert.equal(isApprovedValue(value), expected, value);

    const dir = createMultiDomainFixture();
    const tasksPath = path.join(dir, 'specs', 'billing-sync', 'tasks.md');
    const original = fs.readFileSync(tasksPath, 'utf8');
    const head = '## T-002 PostgreSQL expand マイグレーション\nApproval: Approved';
    assert.ok(original.includes(head));
    const baseCount = buildDecisionViewData({ feature: 'billing-sync', projectRoot: dir }).counts.tasksApproved;
    for (const [value, expected] of cases) {
      fs.writeFileSync(tasksPath, original.replace(head, head.replace('Approval: Approved', `Approval: ${value}`)), 'utf8');
      const gate = runSddGate({
        feature: 'billing-sync',
        taskId: 'T-002',
        projectRoot: dir,
        changedFiles: ['db/migrations/V002__add_amount_cents.sql'],
        commands: [{ label: 'ok', command: 'node -e "process.exit(0)"' }],
        skipDrift: true,
      });
      const approvalError = gate.result.checks.taskPrecondition.errors.some((e) => /not Approved/.test(e));
      assert.equal(approvalError, !expected, `gate: ${value}`);
      const count = buildDecisionViewData({ feature: 'billing-sync', projectRoot: dir }).counts.tasksApproved;
      assert.equal(count, baseCount - (expected ? 0 : 1), `decision view: ${value}`);
    }
  });
});

describe('#972 review: Scope literals and lock renewal races', () => {
  it('a backtick path keeps parentheses that belong to the path (route groups)', async () => {
    const { extractScopePaths } = await import('../plugins/sdd-quality-loop/scripts/v2/v2-readonly-core.mjs');
    assert.deepEqual(
      extractScopePaths('### Scope\n- `src/app/(admin)/page.tsx`\n- `src/{a,b}.ts`\n- src/c.ts(note)\n'),
      ['src/app/(admin)/page.tsx', 'src/a.ts', 'src/b.ts', 'src/c.ts'],
    );
  });

  it('renewal never overwrites a lock another worker took after it was read', async () => {
    const { acquireLock } = await import('../plugins/sdd-quality-loop/scripts/v2/task-lock.mjs');
    const dir = trackTempDir('sdd-lock-race-');
    fs.writeFileSync(path.join(dir, 'AGENTS.md'), '# t\n');
    assert.equal(acquireLock({ feature: 'f', projectRoot: dir, owner: 'A' }).acquired, true);
    const lockPath = path.join(dir, '.sdd', 'locks', 'f.lock');
    const other = { ...JSON.parse(fs.readFileSync(lockPath, 'utf8')), owner: 'B', acquiredAt: new Date().toISOString() };
    const realRead = fs.readFileSync;
    let swapped = false;
    // A reads its own record; B replaces the lock right after that read.
    const spy = mock.method(fs, 'readFileSync', function (...args) {
      const out = realRead.apply(this, args);
      // Suffix match: the root may resolve through a symlink (macOS /var -> /private/var).
      if (!swapped && String(args[0]).endsWith(path.join('.sdd', 'locks', 'f.lock'))) {
        swapped = true;
        fs.writeFileSync(lockPath, JSON.stringify(other), 'utf8');
      }
      return out;
    });
    let renewed;
    try {
      renewed = acquireLock({ feature: 'f', projectRoot: dir, owner: 'A' });
    } finally {
      spy.mock.restore();
    }
    assert.ok(swapped);
    assert.equal(renewed.acquired, false, 'A must not believe it still holds the lock');
    assert.equal(JSON.parse(fs.readFileSync(lockPath, 'utf8')).owner, 'B', "B's lock survives");
    assert.deepEqual(fs.readdirSync(path.dirname(lockPath)), ['f.lock'], 'no temporary files are left behind');
  });
});

describe('#972 review: bounded braces and owner renewal after expiry', () => {
  it('a Scope whose brace expansion is too large is treated as touching everything', async () => {
    const { extractScopePaths } = await import('../plugins/sdd-quality-loop/scripts/v2/v2-readonly-core.mjs');
    const huge = `src/${'{a,b}'.repeat(14)}.ts`;
    const started = Date.now();
    assert.deepEqual(extractScopePaths(`### Scope\n- \`${huge}\`\n`), ['**']);
    assert.ok(Date.now() - started < 1000);
    assert.equal(extractScopePaths('### Scope\n- `src/{a,b}/{c,d}.ts`\n').length, 4, 'small lists still expand');
  });

  it('the owner of an expired lock renews it without --break-stale; another owner still cannot', async () => {
    const { acquireLock, getLockStatus } = await import('../plugins/sdd-quality-loop/scripts/v2/task-lock.mjs');
    const dir = trackTempDir('sdd-lock-own-expiry-');
    fs.writeFileSync(path.join(dir, 'AGENTS.md'), '# t\n');
    assert.equal(acquireLock({ feature: 'f', projectRoot: dir, owner: 'A' }).acquired, true);
    const lockPath = path.join(dir, '.sdd', 'locks', 'f.lock');
    const expire = () => {
      const r = JSON.parse(fs.readFileSync(lockPath, 'utf8'));
      r.expiresAt = '2020-01-01T00:00:00.000Z';
      fs.writeFileSync(lockPath, JSON.stringify(r), 'utf8');
    };
    expire();
    assert.equal(acquireLock({ feature: 'f', projectRoot: dir, owner: 'B' }).acquired, false);
    const renewed = acquireLock({ feature: 'f', projectRoot: dir, owner: 'A' });
    assert.equal(renewed.acquired, true, JSON.stringify(renewed));
    const status = getLockStatus({ feature: 'f', projectRoot: dir });
    assert.equal(status.stale, false);
    assert.ok(Date.parse(status.record.expiresAt) > Date.now());
    assert.equal(acquireLock({ feature: 'f', projectRoot: dir, owner: 'B' }).acquired, false, 'the renewed lock refuses others');
  });
});

describe('#972 re-review: nested braces, bare route groups, lease renewal', () => {
  it('nested brace lists are bounded by what they actually expand to', async () => {
    const { extractScopePaths } = await import('../plugins/sdd-quality-loop/scripts/v2/v2-readonly-core.mjs');
    const nested = `src/${'{1,2,3,4,5,6,7,8,9,{a,b}}'.repeat(4)}.ts`;
    assert.deepEqual(extractScopePaths(`### Scope\n- \`${nested}\`\n`), ['**']);
    assert.deepEqual(extractScopePaths('### Scope\n- `src/{a,{b,c}}.ts`\n'), ['src/a.ts', 'src/b.ts', 'src/c.ts']);
  });

  it('a bare path keeps a route group between slashes and drops a trailing note', async () => {
    const { extractScopePaths } = await import('../plugins/sdd-quality-loop/scripts/v2/v2-readonly-core.mjs');
    assert.deepEqual(extractScopePaths('### Scope\n- src/app/(admin)/page.tsx(rename) を更新\n'), ['src/app/(admin)/page.tsx']);
  });

  it('renewal never leaves a moment where another owner can take a live lock', async () => {
    const { acquireLock } = await import('../plugins/sdd-quality-loop/scripts/v2/task-lock.mjs');
    const dir = trackTempDir('sdd-lock-lease-');
    fs.writeFileSync(path.join(dir, 'AGENTS.md'), '# t\n');
    assert.equal(acquireLock({ feature: 'f', projectRoot: dir, owner: 'A' }).acquired, true);
    let stolen = null;
    const realWrite = fs.writeFileSync;
    // While A renews, B tries a plain acquire at every write A makes.
    const spy = mock.method(fs, 'writeFileSync', function (...args) {
      const out = realWrite.apply(this, args);
      if (stolen === null && /\.sdd[\\/]locks[\\/]f\.lock\.lease\./.test(String(args[0]))) {
        stolen = 'pending';
        stolen = acquireLock({ feature: 'f', projectRoot: dir, owner: 'B' }).acquired;
      }
      return out;
    });
    let renewed;
    try {
      renewed = acquireLock({ feature: 'f', projectRoot: dir, owner: 'A' });
    } finally {
      spy.mock.restore();
    }
    assert.equal(renewed.acquired, true);
    assert.equal(stolen, false, 'B must be refused while A holds the lock');
    const locks = path.join(dir, '.sdd', 'locks');
    assert.equal(JSON.parse(fs.readFileSync(path.join(locks, 'f.lock'), 'utf8')).owner, 'A');
  });

  it('a renewed lease keeps an otherwise expired lock active; a lease for an older lock is ignored', async () => {
    const { acquireLock, getLockStatus, releaseLock } = await import('../plugins/sdd-quality-loop/scripts/v2/task-lock.mjs');
    const dir = trackTempDir('sdd-lock-lease2-');
    fs.writeFileSync(path.join(dir, 'AGENTS.md'), '# t\n');
    const lockPath = path.join(dir, '.sdd', 'locks', 'f.lock');
    assert.equal(acquireLock({ feature: 'f', projectRoot: dir, owner: 'A', ttlSeconds: 60 }).acquired, true);
    const original = JSON.parse(fs.readFileSync(lockPath, 'utf8'));
    original.expiresAt = '2020-01-01T00:00:00.000Z';
    fs.writeFileSync(lockPath, JSON.stringify(original), 'utf8');
    assert.equal(getLockStatus({ feature: 'f', projectRoot: dir }).stale, true);
    assert.equal(acquireLock({ feature: 'f', projectRoot: dir, owner: 'A' }).acquired, true);
    assert.equal(getLockStatus({ feature: 'f', projectRoot: dir }).stale, false, 'the lease extends the lock');
    assert.equal(acquireLock({ feature: 'f', projectRoot: dir, owner: 'B', breakStale: true }).acquired, false);
    assert.equal(releaseLock({ feature: 'f', projectRoot: dir, owner: 'A' }).released, true);
    assert.deepEqual(fs.readdirSync(path.dirname(lockPath)), [], 'release removes the lock and its lease');
  });
});

describe('#972 review 4: wrapped prose, table cells, filesystems without hard links', () => {
  const evidence = async (files) => {
    const { featureEvidenceInputs, diffEvidenceInputs } = await import('../plugins/sdd-quality-loop/scripts/v2/v2-readonly-core.mjs');
    const io = { readText: (rel) => files[rel] ?? null, exists: (rel) => rel in files };
    return { before: featureEvidenceInputs(io, { feature: 'f' }).get('T-001'), now: () => featureEvidenceInputs(io, { feature: 'f' }).get('T-001'), diffEvidenceInputs };
  };
  const tasks = '# t\n\n## T-001 x\nApproval: Approved\nStatus: Done\n\n### Done When\n- AC-001\n';

  it('a wrapped line that starts with an ID stays part of its entry', async () => {
    const files = { 'specs/f/requirements.md': '# r\n\n- **AC-001**: GET /health answers and per\n  AC-001 the body is JSON; it must never\n  return a 500 status.\n', 'specs/f/tasks.md': tasks };
    const e = await evidence(files);
    files['specs/f/requirements.md'] = files['specs/f/requirements.md'].replace('return a 500 status', 'return a 200 status');
    assert.deepEqual(e.diffEvidenceInputs(e.before, e.now()), ['AC-001']);
  });

  it('a table row whose first cell starts with the ID is that ID\'s entry', async () => {
    const files = { 'specs/f/acceptance-tests.md': '# AT\n\n| AC | Check |\n|---|---|\n| AC-001 health is 200 | curl |\n| AC-002 other | curl |\n', 'specs/f/tasks.md': tasks };
    const e = await evidence(files);
    files['specs/f/acceptance-tests.md'] = files['specs/f/acceptance-tests.md'].replace('AC-002 other', 'AC-002 changed').replace('# AT', '# Acceptance');
    assert.deepEqual(e.diffEvidenceInputs(e.before, e.now()), [], 'edits outside AC-001 do not stale T-001');
    files['specs/f/acceptance-tests.md'] = files['specs/f/acceptance-tests.md'].replace('health is 200', 'health is 204');
    assert.deepEqual(e.diffEvidenceInputs(e.before, e.now()), ['AC-001']);
  });

  it('locking still works where hard links are not supported', async () => {
    const { acquireLock } = await import('../plugins/sdd-quality-loop/scripts/v2/task-lock.mjs');
    const dir = trackTempDir('sdd-lock-nolink-');
    fs.writeFileSync(path.join(dir, 'AGENTS.md'), '# t\n');
    const spy = mock.method(fs, 'linkSync', () => {
      const err = new Error('operation not permitted');
      err.code = 'EPERM';
      throw err;
    });
    try {
      assert.equal(acquireLock({ feature: 'f', projectRoot: dir, owner: 'A' }).acquired, true);
      assert.equal(acquireLock({ feature: 'f', projectRoot: dir, owner: 'B' }).acquired, false);
    } finally {
      spy.mock.restore();
    }
    assert.deepEqual(fs.readdirSync(path.join(dir, '.sdd', 'locks')), ['f.lock']);
    assert.equal(JSON.parse(fs.readFileSync(path.join(dir, '.sdd', 'locks', 'f.lock'), 'utf8')).owner, 'A');
  });
});
