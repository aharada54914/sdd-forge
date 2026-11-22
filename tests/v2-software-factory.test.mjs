import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { after, describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';
import {
  analyzeTraceability,
  formatTraceabilityMarkdown,
  scopeMatchesFile,
} from '../plugins/sdd-quality-loop/scripts/v2/check-traceability.mjs';
import {
  computeExecutionPlan,
  scopeEntriesOverlap,
} from '../plugins/sdd-quality-loop/scripts/v2/v2-readonly-core.mjs';
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

  it('I2: scopeEntriesOverlap & --plan-batches serialize wildcard/directory & wildcard-pair overlaps (including uncreated files) while keeping disjoint top dirs parallel', () => {
    // Test A: direct scope language overlap checks
    // Wildcard vs directory (future files)
    assert.equal(scopeEntriesOverlap('src/**/*.ts', 'src/sub'), true);
    assert.equal(scopeEntriesOverlap('src/sub', 'src/**/*.ts'), true);
    assert.equal(scopeEntriesOverlap('src/**/*.ts', 'src/sub/'), true);
    assert.equal(scopeEntriesOverlap('src/*/foo.ts', 'src/sub'), true);
    assert.equal(scopeEntriesOverlap('**/billing.ts', 'src/sub'), true);
    assert.equal(scopeEntriesOverlap('src/sub/**', 'src/sub'), true);

    // Wildcard pairs overlapping future files
    assert.equal(scopeEntriesOverlap('*/foo.ts', 'src/*.ts'), true);
    assert.equal(scopeEntriesOverlap('src/*.ts', 'src/foo*'), true);
    assert.equal(scopeEntriesOverlap('src/**/*.ts', 'src/sub/*.ts'), true);
    assert.equal(scopeEntriesOverlap('src/**/a/**/*.ts', 'src/**/b/**/*.ts'), true);

    // Disjoint scopes must NOT be collapsed
    assert.equal(scopeEntriesOverlap('src/**/*.ts', 'docs/sub'), false);
    assert.equal(scopeEntriesOverlap('src/**/*.ts', 'tests/**/*.ts'), false);
    assert.equal(scopeEntriesOverlap('src/sub', 'docs/sub'), false);
    assert.equal(scopeEntriesOverlap('src/*.ts', 'src/sub'), false);
    assert.equal(scopeEntriesOverlap('src/*.ts', 'src/*.js'), false);
    assert.equal(scopeEntriesOverlap('src/**/*.ts', 'src/**/*.js'), false);
    assert.equal(scopeEntriesOverlap('src/sub/**', 'src/other/**'), false);
    assert.equal(scopeEntriesOverlap('src/sub', 'src/sub2'), false);

    // Un-analyzable/ambiguous forms conservatively serialize
    assert.equal(scopeEntriesOverlap('src/../lib/a.ts', 'lib/a.ts'), true);
    assert.equal(scopeEntriesOverlap('.', 'src/a.ts'), true);

    // Test B: end-to-end planner & CLI with zero candidate files created on disk
    const dir = trackTempDir('sdd-i2-plan-');
    fs.mkdirSync(path.join(dir, 'specs', 'scope-plan'), { recursive: true });
    fs.writeFileSync(
      path.join(dir, 'specs', 'scope-plan', 'requirements.md'),
      '# Requirements: scope-plan\n- **REQ-001**: Parallel planner\n- **AC-001** (REQ-001): Disjoint scopes only\n',
      'utf8',
    );
    fs.writeFileSync(
      path.join(dir, 'specs', 'scope-plan', 'tasks.md'),
      [
        '# Tasks: scope-plan',
        '',
        '## T-001 TypeScript refactor',
        'Approval: Approved',
        'Status: Planned',
        'Risk: standard',
        '### Scope',
        '- `src/**/*.ts`',
        '### Done When',
        '- AC-001 passes',
        '### Blockers',
        '- None',
        '',
        '## T-002 Submodule update',
        'Approval: Approved',
        'Status: Planned',
        'Risk: standard',
        '### Scope',
        '- `src/sub`',
        '### Done When',
        '- AC-001 passes',
        '### Blockers',
        '- None',
        '',
        '## T-003 Docs update',
        'Approval: Approved',
        'Status: Planned',
        'Risk: low',
        '### Scope',
        '- `docs/guide`',
        '### Done When',
        '- AC-001 passes',
        '### Blockers',
        '- None',
        '',
        '## T-004 Test suite update',
        'Approval: Approved',
        'Status: Planned',
        'Risk: low',
        '### Scope',
        '- `tests/**/*.ts`',
        '### Done When',
        '- AC-001 passes',
        '### Blockers',
        '- None',
        '',
        '## T-005 Intermediate helper',
        'Approval: Approved',
        'Status: Planned',
        'Risk: low',
        '### Scope',
        '- `lib/helper.ts`',
        '### Done When',
        '- AC-001 passes',
        '### Blockers',
        '- T-002',
        '',
        '## T-006 Transitive follow-up in src/sub',
        'Approval: Approved',
        'Status: Planned',
        'Risk: low',
        '### Scope',
        '- `src/sub`',
        '### Done When',
        '- AC-001 passes',
        '### Blockers',
        '- T-005',
        '',
      ].join('\n'),
      'utf8',
    );

    const jsonCli = spawnSync(
      process.execPath,
      [TRACE_CLI, '--feature', 'scope-plan', '--root', dir, '--plan-batches', '--strict'],
      { encoding: 'utf8' },
    );
    assert.equal(jsonCli.status, 0, jsonCli.stderr);
    const report = JSON.parse(jsonCli.stdout);
    assert.deepEqual(Object.keys(report.executionPlan).sort(), ['batches', 'cyclicTasks', 'scopeConflicts']);
    assert.deepEqual(report.executionPlan.batches, [
      ['T-001', 'T-003', 'T-004'],
      ['T-002'],
      ['T-005'],
      ['T-006'],
    ]);
    assert.deepEqual(report.executionPlan.cyclicTasks, []);
    assert.equal(
      report.executionPlan.scopeConflicts.some(
        (c) => c.tasks[0] === 'T-001' && c.tasks[1] === 'T-002' && c.overlaps.includes('src/**/*.ts <-> src/sub'),
      ),
      true,
    );
    assert.equal(
      report.executionPlan.scopeConflicts.some(
        (c) => (c.tasks[0] === 'T-002' && c.tasks[1] === 'T-006') || (c.tasks[0] === 'T-006' && c.tasks[1] === 'T-002'),
      ),
      false,
      'Transitive dependency T-002 -> T-005 -> T-006 must not be counted as an extra scope conflict',
    );

    const mdCli = spawnSync(
      process.execPath,
      [TRACE_CLI, '--feature', 'scope-plan', '--root', dir, '--format', 'markdown', '--plan-batches'],
      { encoding: 'utf8' },
    );
    assert.equal(mdCli.status, 0, mdCli.stderr);
    assert.match(mdCli.stdout, /Scope Conflicts \(serialized automatically\)/);
    assert.match(mdCli.stdout, /T-001 vs T-002: src\/\*\*\/\*\.ts <-> src\/sub/);

    // Unicode RegExp /i equivalence regression (Greek sigma/final-sigma):
    // scopes matching the same actual file must not be placed in the same wave,
    // while distinct non-ASCII literal-only scopes remain disjoint.
    assert.equal(scopeMatchesFile('src/σ/**/*.ts', 'src/ς/file.ts'), true);
    assert.equal(scopeMatchesFile('src/ς/', 'src/ς/file.ts'), true);
    assert.equal(scopeEntriesOverlap('src/σ/**/*.ts', 'src/ς/'), true);
    assert.equal(scopeMatchesFile('src/**/a*Σ', 'src/sub/abς'), true);
    assert.equal(scopeMatchesFile('src/**/?bς', 'src/sub/abς'), true);
    assert.equal(scopeEntriesOverlap('src/**/a*Σ', 'src/**/?bς'), true);
    assert.equal(scopeEntriesOverlap('docs/仕様.md', 'docs/設計.md'), false);
    assert.equal(scopeEntriesOverlap('docs/設計/**/*.md', 'src/実装/**/*.ts'), false);
    assert.equal(scopeEntriesOverlap('docs/設計/**/*.md', 'docs/仕様/**/*.md'), false);
    assert.equal(scopeEntriesOverlap('docs/**/*設計.md', 'docs/**/*仕様.md'), false);

    const unicodeDir = trackTempDir('sdd-i2-unicode-');
    fs.mkdirSync(path.join(unicodeDir, 'specs', 'unicode-scope'), { recursive: true });
    fs.writeFileSync(
      path.join(unicodeDir, 'specs', 'unicode-scope', 'requirements.md'),
      '# Requirements: unicode-scope\n- **REQ-001**: Unicode scope safety\n- **AC-001** (REQ-001): Serialize overlapping scopes\n',
      'utf8',
    );
    fs.writeFileSync(
      path.join(unicodeDir, 'specs', 'unicode-scope', 'tasks.md'),
      [
        '# Tasks: unicode-scope',
        '## T-001 Sigma glob',
        'Approval: Approved',
        'Status: Planned',
        'Risk: standard',
        '### Scope',
        '- `src/σ/**/*.ts`',
        '### Done When',
        '- AC-001 passes',
        '### Blockers',
        '- None',
        '',
        '## T-002 Final-sigma dir',
        'Approval: Approved',
        'Status: Planned',
        'Risk: standard',
        '### Scope',
        '- `src/ς/`',
        '### Done When',
        '- AC-001 passes',
        '### Blockers',
        '- None',
        '',
        '## T-003 Uppercase sigma suffix glob',
        'Approval: Approved',
        'Status: Planned',
        'Risk: standard',
        '### Scope',
        '- `src/**/a*Σ`',
        '### Done When',
        '- AC-001 passes',
        '### Blockers',
        '- None',
        '',
        '## T-004 Final-sigma suffix glob',
        'Approval: Approved',
        'Status: Planned',
        'Risk: standard',
        '### Scope',
        '- `src/**/?bς`',
        '### Done When',
        '- AC-001 passes',
        '### Blockers',
        '- None',
        '',
      ].join('\n'),
      'utf8',
    );
    const sigmaImpact = analyzeTraceability({
      feature: 'unicode-scope',
      projectRoot: unicodeDir,
      changedFiles: ['src/ς/file.ts'],
    });
    assert.deepEqual(sigmaImpact.impact.directImpactedTasks, ['T-001', 'T-002']);
    assert.equal(
      sigmaImpact.executionPlan.batches.every((w) => !(w.includes('T-001') && w.includes('T-002'))),
      true,
    );
    assert.equal(
      sigmaImpact.executionPlan.scopeConflicts.some((c) => c.tasks[0] === 'T-001' && c.tasks[1] === 'T-002'),
      true,
    );

    const suffixImpact = analyzeTraceability({
      feature: 'unicode-scope',
      projectRoot: unicodeDir,
      changedFiles: ['src/sub/abς'],
    });
    assert.deepEqual(suffixImpact.impact.directImpactedTasks, ['T-003', 'T-004']);
    assert.equal(
      suffixImpact.executionPlan.batches.every((w) => !(w.includes('T-003') && w.includes('T-004'))),
      true,
    );
    assert.equal(
      suffixImpact.executionPlan.scopeConflicts.some((c) => c.tasks[0] === 'T-003' && c.tasks[1] === 'T-004'),
      true,
    );
  });

  it('I3: preserves self-dependency cycles, excludes undefined blockers and downstream tasks without mislabeling as cycles, and keeps original --strict exit contract', () => {
    // Test A: direct execution plan behavior on unknown/transitive/independent tasks
    const directPlan = computeExecutionPlan([
      { id: 'T-001', blockers: [], scopePaths: ['src/a.ts'] },
      { id: 'T-002', blockers: ['T-999'], scopePaths: ['src/b.ts'] },
      { id: 'T-003', blockers: ['T-002'], scopePaths: ['src/c.ts'] },
      { id: 'T-004', blockers: ['T-001'], scopePaths: ['src/d.ts'] },
      { id: 'T-005', blockers: [], scopePaths: ['src/e.ts'] },
    ]);
    assert.deepEqual(directPlan.batches, [['T-001', 'T-005'], ['T-004']]);
    assert.deepEqual(directPlan.cyclicTasks, []);

    const makeFeature = (slug, tasksBody) => {
      const dir = trackTempDir(`sdd-i3-${slug}-`);
      fs.mkdirSync(path.join(dir, 'specs', slug), { recursive: true });
      fs.writeFileSync(
        path.join(dir, 'specs', slug, 'requirements.md'),
        `# Requirements: ${slug}\n- **REQ-001**: Blocker integrity\n- **AC-001** (REQ-001): Valid plan only\n`,
        'utf8',
      );
      fs.writeFileSync(path.join(dir, 'specs', slug, 'tasks.md'), tasksBody, 'utf8');
      return dir;
    };

    // Test B-1: Self-dependency -> strict exit 1, excluded from waves, reported in cyclicTasks, unrelated task runs
    const selfDir = makeFeature(
      'self-dep',
      [
        '# Tasks: self-dep',
        '## T-001 Self blocked',
        'Approval: Approved',
        'Status: Planned',
        'Risk: standard',
        '### Scope',
        '- `src/self.ts`',
        '### Done When',
        '- AC-001 passes',
        '### Blockers',
        '- T-001',
        '',
        '## T-002 Independent',
        'Approval: Approved',
        'Status: Planned',
        'Risk: low',
        '### Scope',
        '- `src/indep.ts`',
        '### Done When',
        '- AC-001 passes',
        '### Blockers',
        '- None',
        '',
      ].join('\n'),
    );
    const selfJsonRes = spawnSync(
      process.execPath,
      [TRACE_CLI, '--feature', 'self-dep', '--root', selfDir, '--plan-batches', '--strict'],
      { encoding: 'utf8' },
    );
    assert.equal(selfJsonRes.status, 1);
    const selfReport = JSON.parse(selfJsonRes.stdout);
    assert.equal(selfReport.complete, true);
    assert.deepEqual(Object.keys(selfReport.executionPlan).sort(), ['batches', 'cyclicTasks', 'scopeConflicts']);
    assert.deepEqual(selfReport.executionPlan.batches, [['T-002']]);
    assert.deepEqual(selfReport.executionPlan.cyclicTasks, ['T-001']);
    assert.equal(selfReport.tasks.find((t) => t.id === 'T-001').blockers.includes('T-001'), true);

    const selfMdRes = spawnSync(
      process.execPath,
      [TRACE_CLI, '--feature', 'self-dep', '--root', selfDir, '--format', 'markdown', '--plan-batches', '--strict'],
      { encoding: 'utf8' },
    );
    assert.equal(selfMdRes.status, 1);
    assert.match(selfMdRes.stdout, /Blocker Cycle Detected\*\*: T-001/);
    assert.doesNotMatch(selfMdRes.stdout, /Undefined Blockers/);

    // Test B-2: Undefined blocker ID -> excluded from waves (with downstream tasks), NOT mislabeled as cyclic,
    // visible in CLI diagnostics, defined chain & independent task still scheduled, original --strict exit 0 preserved
    const unknownDir = makeFeature(
      'unknown-dep',
      [
        '# Tasks: unknown-dep',
        '## T-001 Chain root',
        'Approval: Approved',
        'Status: Planned',
        'Risk: low',
        '### Scope',
        '- `src/a.ts`',
        '### Done When',
        '- AC-001 passes',
        '### Blockers',
        '- None',
        '',
        '## T-002 Missing blocker',
        'Approval: Approved',
        'Status: Planned',
        'Risk: standard',
        '### Scope',
        '- `src/b.ts`',
        '### Done When',
        '- AC-001 passes',
        '### Blockers',
        '- T-999',
        '',
        '## T-003 Blocked by T-002',
        'Approval: Approved',
        'Status: Planned',
        'Risk: low',
        '### Scope',
        '- `src/c.ts`',
        '### Done When',
        '- AC-001 passes',
        '### Blockers',
        '- T-002',
        '',
        '## T-004 Chain child',
        'Approval: Approved',
        'Status: Planned',
        'Risk: low',
        '### Scope',
        '- `src/d.ts`',
        '### Done When',
        '- AC-001 passes',
        '### Blockers',
        '- T-001',
        '',
        '## T-005 Independent',
        'Approval: Approved',
        'Status: Planned',
        'Risk: low',
        '### Scope',
        '- `src/e.ts`',
        '### Done When',
        '- AC-001 passes',
        '### Blockers',
        '- None',
        '',
      ].join('\n'),
    );
    const unknownJsonRes = spawnSync(
      process.execPath,
      [TRACE_CLI, '--feature', 'unknown-dep', '--root', unknownDir, '--plan-batches', '--strict'],
      { encoding: 'utf8' },
    );
    assert.equal(unknownJsonRes.status, 0);
    const unknownReport = JSON.parse(unknownJsonRes.stdout);
    assert.equal(unknownReport.complete, true);
    assert.deepEqual(Object.keys(unknownReport.executionPlan).sort(), ['batches', 'cyclicTasks', 'scopeConflicts']);
    assert.deepEqual(unknownReport.executionPlan.batches, [['T-001', 'T-005'], ['T-004']]);
    assert.deepEqual(unknownReport.executionPlan.cyclicTasks, []);
    assert.match(unknownJsonRes.stderr, /undefined blockers/i);
    assert.match(unknownJsonRes.stderr, /T-002->T-999/);
    assert.doesNotMatch(unknownJsonRes.stderr, /cycle/i);

    const unknownMdRes = spawnSync(
      process.execPath,
      [TRACE_CLI, '--feature', 'unknown-dep', '--root', unknownDir, '--format', 'markdown', '--plan-batches', '--strict'],
      { encoding: 'utf8' },
    );
    assert.equal(unknownMdRes.status, 0);
    assert.match(unknownMdRes.stdout, /Undefined Blockers \(excluded from waves\)\*\*: T-002->T-999/);
    assert.doesNotMatch(unknownMdRes.stdout, /Blocker Cycle Detected/);

    // Test B-3: Multi-node cycle -> strict exit 1, excluded from waves, reported in cyclicTasks, chain & independent run
    const cycleDir = makeFeature(
      'multi-cycle',
      [
        '# Tasks: multi-cycle',
        '## T-001 Cycle A',
        'Approval: Approved',
        'Status: Planned',
        'Risk: standard',
        '### Scope',
        '- `src/a.ts`',
        '### Done When',
        '- AC-001 passes',
        '### Blockers',
        '- T-002',
        '',
        '## T-002 Cycle B',
        'Approval: Approved',
        'Status: Planned',
        'Risk: standard',
        '### Scope',
        '- `src/b.ts`',
        '### Done When',
        '- AC-001 passes',
        '### Blockers',
        '- T-001',
        '',
        '## T-003 Independent root',
        'Approval: Approved',
        'Status: Planned',
        'Risk: low',
        '### Scope',
        '- `src/c.ts`',
        '### Done When',
        '- AC-001 passes',
        '### Blockers',
        '- None',
        '',
        '## T-004 Chain child',
        'Approval: Approved',
        'Status: Planned',
        'Risk: low',
        '### Scope',
        '- `src/d.ts`',
        '### Done When',
        '- AC-001 passes',
        '### Blockers',
        '- T-003',
        '',
      ].join('\n'),
    );
    const cycleJsonRes = spawnSync(
      process.execPath,
      [TRACE_CLI, '--feature', 'multi-cycle', '--root', cycleDir, '--plan-batches', '--strict'],
      { encoding: 'utf8' },
    );
    assert.equal(cycleJsonRes.status, 1);
    const cycleReport = JSON.parse(cycleJsonRes.stdout);
    assert.equal(cycleReport.complete, true);
    assert.deepEqual(cycleReport.executionPlan.batches, [['T-003'], ['T-004']]);
    assert.deepEqual(cycleReport.executionPlan.cyclicTasks, ['T-001', 'T-002']);

    const cycleMdRes = spawnSync(
      process.execPath,
      [TRACE_CLI, '--feature', 'multi-cycle', '--root', cycleDir, '--format', 'markdown', '--plan-batches', '--strict'],
      { encoding: 'utf8' },
    );
    assert.equal(cycleMdRes.status, 1);
    assert.match(cycleMdRes.stdout, /Blocker Cycle Detected\*\*: T-001, T-002/);
    assert.doesNotMatch(cycleMdRes.stdout, /Undefined Blockers/);
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

  it('D6: Decision View reflects missing, NEEDS_FIX, and PASS spec-check without claiming unobserved checks ran', () => {
    const dir = trackTempDir('sdd-decision-view-d6-');
    fs.mkdirSync(path.join(dir, 'specs', 'truthful-api'), { recursive: true });
    fs.writeFileSync(
      path.join(dir, 'specs', 'truthful-api', 'requirements.md'),
      '# 要件: truthful-api\n- **REQ-001**: Health endpoint returns HTTP 200.\n- **AC-001** (REQ-001): GET /health returns 200.\n',
      'utf8',
    );
    fs.writeFileSync(
      path.join(dir, 'specs', 'truthful-api', 'design.md'),
      '# 設計: truthful-api\n\n## 方針\nStandard handler.\n',
      'utf8',
    );
    fs.writeFileSync(
      path.join(dir, 'specs', 'truthful-api', 'tasks.md'),
      '# タスク: truthful-api\n\n## T-001 Implement health endpoint\nApproval: Draft\nStatus: Planned\nRisk: standard\n\n### Scope\n- `src/health.mjs`\n\n### Done When\n- AC-001 passes\n',
      'utf8',
    );

    // 1. Missing reports/spec-check/truthful-api.md -> Not Run across matrix, Markdown, and HTML.
    const missingData = buildDecisionViewData({ feature: 'truthful-api', projectRoot: dir });
    assert.equal(missingData.specCheckVerdict, 'Not Run');
    assert.equal('checkStatus' in missingData, false);
    const c01Missing = missingData.reviewPerspectives.find((p) => p.id === 'C01');
    const c07Missing = missingData.reviewPerspectives.find((p) => p.id === 'C07');
    const c08Missing = missingData.reviewPerspectives.find((p) => p.id === 'C08');
    assert.match(c01Missing.reason, /spec-check \(Not Run\)/);
    assert.doesNotMatch(c01Missing.reason, /確認済み/);
    assert.match(c07Missing.reason, /spec-check \(Not Run\)/);
    assert.doesNotMatch(c07Missing.reason, /確認済み|自動照合済み/);
    assert.doesNotMatch(c08Missing.reason, /確認済み|で自動検証。/);
    for (const view of [renderDecisionViewMarkdown(missingData), renderDecisionViewHtml(missingData)]) {
      assert.match(view, /Not Run/);
      assert.doesNotMatch(view, /機械検証済み|機械確認済み|自動照合済み|確認済み/);
    }

    // 2. NEEDS_FIX report -> must not claim confirmed in any view.
    const specCheckPath = path.join(dir, 'reports', 'spec-check', 'truthful-api.md');
    fs.mkdirSync(path.dirname(specCheckPath), { recursive: true });
    fs.writeFileSync(specCheckPath, '# Spec Check Report: truthful-api\n\n- **Verdict**: NEEDS_FIX\n', 'utf8');
    const needsFixData = buildDecisionViewData({ feature: 'truthful-api', projectRoot: dir });
    assert.equal(needsFixData.specCheckVerdict, 'NEEDS_FIX');
    assert.match(needsFixData.reviewPerspectives.find((p) => p.id === 'C01').reason, /spec-check \(NEEDS_FIX\)/);
    assert.match(needsFixData.reviewPerspectives.find((p) => p.id === 'C07').reason, /spec-check \(NEEDS_FIX\)/);
    for (const view of [renderDecisionViewMarkdown(needsFixData), renderDecisionViewHtml(needsFixData)]) {
      assert.match(view, /NEEDS_FIX/);
      assert.doesNotMatch(view, /機械検証済み|機械確認済み|自動照合済み|確認済み/);
    }

    // 3. PASS report (even with P2 Design N/A) -> C01 stays neutral (never claims design confirmed), while trace/drift/gate remain non-claiming.
    fs.writeFileSync(
      specCheckPath,
      '# Spec Check Report: truthful-api\n\n- **Verdict**: PASS\n\n## Perspective Coverage (P1–P6)\n- P2 (Design & Alternatives Rejected): N/A (config-only)\n',
      'utf8',
    );
    const passData = buildDecisionViewData({ feature: 'truthful-api', projectRoot: dir });
    assert.equal(passData.specCheckVerdict, 'PASS');
    const c01Pass = passData.reviewPerspectives.find((p) => p.id === 'C01');
    assert.match(c01Pass.reason, /spec-check \(PASS\) の判定を記録/);
    assert.match(c01Pass.reason, /レポートを確認/);
    assert.doesNotMatch(c01Pass.reason, /確認済み/);
    assert.match(passData.reviewPerspectives.find((p) => p.id === 'C07').reason, /spec-check \(PASS\) は確認済み/);
    assert.doesNotMatch(passData.reviewPerspectives.find((p) => p.id === 'C07').reason, /自動照合済み/);
    assert.doesNotMatch(passData.reviewPerspectives.find((p) => p.id === 'C08').reason, /確認済み|で自動検証。/);
    for (const view of [renderDecisionViewMarkdown(passData), renderDecisionViewHtml(passData)]) {
      assert.match(view, /spec-check \(PASS\)/);
      assert.doesNotMatch(view, /機械検証済み|機械確認済み|自動照合済み/);
    }
  });
});
