import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';
import { analyzeTraceability, formatTraceabilityMarkdown } from '../plugins/sdd-quality-loop/scripts/v2/check-traceability.mjs';
import { writeSpecBaseline } from '../plugins/sdd-quality-loop/scripts/v2/record-spec-baseline.mjs';
import {
  buildDecisionViewData,
  renderDecisionViewHtml,
  renderDecisionViewMarkdown,
} from '../plugins/sdd-quality-loop/scripts/v2/render-decision-view.mjs';
import { runSddGate } from '../plugins/sdd-quality-loop/scripts/v2/run-sdd-gate.mjs';
import { runDoctor } from '../plugins/sdd-quality-loop/scripts/v2/sdd-doctor.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..');

function createMultiDomainFixture() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-factory-test-'));
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
|---|---|---|
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
- \`db/migrations/V002__add_amount_cents.sql\`

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
- （初期版のため変更なし）
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
  it('Phase A-1: sql-develop skill and policy align cleanly with SDD Core v2 (zero retired v1 terms)', () => {
    const skill = fs.readFileSync(
      path.join(REPO_ROOT, 'plugins/sdd-implementation/skills/sql-develop/SKILL.md'),
      'utf8',
    );
    const policy = fs.readFileSync(
      path.join(REPO_ROOT, 'plugins/sdd-implementation/skills/sql-develop/references/sql-development-policy.md'),
      'utf8',
    );
    assert.match(skill, /Risk: low \| standard \| high/);
    assert.match(skill, /OQ-NNN/);
    assert.doesNotMatch(skill, /lite-spec|interviewer|handshake|--lite/);
    assert.match(policy, /run-sdd-gate\.mjs/);
    assert.doesNotMatch(policy, /lite-gate|quality-gate|evidence-bundle/);
  });

  it('Phase A-2 & A-3: render-decision-view.mjs generates 4-domain Fact/Reason/Question views (Markdown & HTML)', () => {
    const dir = createMultiDomainFixture();
    const data = buildDecisionViewData({ feature: 'billing-sync', projectRoot: dir });

    assert.deepEqual(new Set(data.domains), new Set(['Software', 'SQL', 'AWS']));
    assert.equal(data.highestRisk, 'high');
    assert.equal(data.counts.openQuestionsProvisional, 1);
    assert.equal(data.counts.alternativesRejected, 1);

    const md = renderDecisionViewMarkdown(data);
    assert.match(md, /OQ-001 \[不可逆リスク\]/);
    assert.match(md, /設計した事実（仮決定）/);
    assert.match(md, /なぜそうしたか/);
    assert.match(md, /人が判断する問い/);
    assert.match(md, /単一トランザクションで即 DROP COLUMN/);

    const html = renderDecisionViewHtml(data);
    assert.match(html, /<!doctype html>/i);
    assert.match(html, /OQ-001/);
    assert.match(html, /人が判断する問い/);
  });

  it('Phase A-3: run-sdd-gate.mjs blocks Risk: high tasks when Provisional OQ-NNN remains, and passes once Confirmed', () => {
    const dir = createMultiDomainFixture();

    // T-002 is Risk: high and OQ-001 is Provisional -> MUST FAIL
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

    // T-001 is Risk: standard (not impacted by OQ-001) -> PASSES and records factory-metrics.jsonl
    const standardPass = runSddGate({
      feature: 'billing-sync',
      taskId: 'T-001',
      projectRoot: dir,
      changedFiles: ['src/billing.js'],
      commands: [{ label: 'ok', command: 'node -e "process.exit(0)"' }],
    });
    assert.equal(standardPass.result.verdict, 'PASS');
    const metricsPath = path.join(dir, '.sdd', 'factory-metrics.jsonl');
    assert.equal(fs.existsSync(metricsPath), true);
    const lines = fs.readFileSync(metricsPath, 'utf8').trim().split('\n').map((l) => JSON.parse(l));
    assert.equal(lines.length, 2);
    assert.equal(lines[1].taskId, 'T-001');
    assert.equal(lines[1].verdict, 'PASS');

    // Confirm OQ-001 in requirements.md (+ Spec Amendment) -> T-002 PASSES
    const reqPath = path.join(dir, 'specs', 'billing-sync', 'requirements.md');
    const updatedReq = fs
      .readFileSync(reqPath, 'utf8')
      .replace('| Provisional | T-002 |', '| Confirmed | T-002 |')
      .replace('- （初期版のため変更なし）', '- 2026-11-21: 人間が OQ-001 を Confirmed に確定');
    fs.writeFileSync(reqPath, updatedReq, 'utf8');

    const passed = runSddGate({
      feature: 'billing-sync',
      taskId: 'T-002',
      projectRoot: dir,
      changedFiles: ['db/migrations/V002__add_amount_cents.sql'],
      commands: [{ label: 'ok', command: 'node -e "process.exit(0)"' }],
    });
    assert.equal(passed.result.verdict, 'PASS');
    assert.equal(passed.result.checks.openQuestions.passed, true);
  });

  it('Phase B-1: check-traceability.mjs verifies REQ->AC->Task completeness and computes minimal follow-up impact', () => {
    const dir = createMultiDomainFixture();
    const report = analyzeTraceability({
      feature: 'billing-sync',
      projectRoot: dir,
      changedIds: ['REQ-002'],
    });
    assert.equal(report.complete, true);
    assert.deepEqual(report.gaps.orphanReqs, []);
    assert.deepEqual(report.gaps.unassignedAcs, []);
    // Only T-002 (SQL) is impacted by REQ-002; T-001 (Software) and T-003 (AWS) are reusable!
    assert.deepEqual(report.impact.impactedTasks, ['T-002']);
    assert.deepEqual(report.impact.reusableTasks, ['T-001', 'T-003']);

    const md = formatTraceabilityMarkdown(report);
    assert.match(md, /COMPLETE/);
    assert.match(md, /Impacted Tasks \(re-run\)\*\*: T-002/);
    assert.match(md, /Reusable Tasks \(skip\)\*\*: T-001, T-003/);
  });

  it('Phase B-2: run-sdd-gate.mjs non-functional static sensors catch destructive SQL, wildcard IAM, and hardcoded secrets', () => {
    const dir = createMultiDomainFixture();

    // Inject destructive SQL, wildcard IAM, and hardcoded AWS key
    fs.writeFileSync(path.join(dir, 'db', 'migrations', 'V002__add_amount_cents.sql'), 'DROP TABLE invoices;\nDELETE FROM audit_log;\n', 'utf8');
    fs.writeFileSync(path.join(dir, 'infra', 'aws', 'billing-alarm.ts'), 'export const policy = { "Action": "*", cidr: "0.0.0.0/0 port 22" };\n', 'utf8');
    fs.writeFileSync(path.join(dir, 'src', 'billing.js'), 'export const key = "AKIAIOSFODNN7EXAMPLE";\n', 'utf8');

    const res = runSddGate({
      feature: 'billing-sync',
      taskId: 'T-001',
      projectRoot: dir,
      changedFiles: [
        'db/migrations/V002__add_amount_cents.sql',
        'infra/aws/billing-alarm.ts',
        'src/billing.js',
      ],
      commands: [{ label: 'ok', command: 'node -e "process.exit(0)"' }],
    });
    assert.equal(res.result.verdict, 'FAIL');
    assert.equal(res.result.checks.nonFunctionalSensors.passed, false);
    const rules = new Set(res.result.checks.nonFunctionalSensors.findings.map((f) => f.rule));
    assert.ok(rules.has('SQL_DESTRUCTIVE_DDL'));
    assert.ok(rules.has('SQL_UNGUARDED_DELETE_OR_UPDATE'));
    assert.ok(rules.has('CLOUD_WILDCARD_IAM'));
    assert.ok(rules.has('CLOUD_OPEN_ADMIN_PORT'));
    assert.ok(rules.has('SECRET_AWS_KEY'));
  });

  it('Phase C: sdd-doctor.mjs warns when 2-layer knowledge INDEX exceeds 3,000 characters', () => {
    const dir = createMultiDomainFixture();
    fs.mkdirSync(path.join(dir, 'sdd', 'knowledge', 'common'), { recursive: true });
    fs.writeFileSync(path.join(dir, 'sdd', 'knowledge', 'common', 'INDEX.md'), `# Index\n${'x'.repeat(3100)}\n`, 'utf8');

    const report = runDoctor({ root: dir });
    assert.ok(report.findings.some((f) => f.severity === 'WARN' && f.category === 'knowledge' && /3000/.test(f.message)));
  });
});
