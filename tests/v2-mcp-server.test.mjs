import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import { createRequire } from 'node:module';
import os from 'node:os';
import path from 'node:path';
import { describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..');
const MCP_BIN = path.join(REPO_ROOT, 'mcp/sdd-forge-mcp/dist/index.js');
const BASELINE_SCRIPT = path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/record-spec-baseline.mjs');
const GATE_SCRIPT = path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/run-sdd-gate.mjs');
const SCHEMA_PATH = path.join(REPO_ROOT, 'contracts/sdd-mcp.v2.schema.json');

const requireFromMcp = createRequire(path.join(REPO_ROOT, 'mcp/sdd-forge-mcp/package.json'));
let Ajv2020 = null;
try {
  Ajv2020 = requireFromMcp('ajv/dist/2020').default;
} catch {
  Ajv2020 = null;
}

function callMcp(rootDir, requests, extraEnv = {}) {
  const payload =
    [
      JSON.stringify({
        jsonrpc: '2.0',
        id: 1,
        method: 'initialize',
        params: { protocolVersion: '2024-11-05', capabilities: {}, clientInfo: { name: 'test', version: '1.0' } },
      }),
      ...requests.map((req, idx) => JSON.stringify({ jsonrpc: '2.0', id: idx + 2, ...req })),
    ].join('\n') + '\n';

  const stdout = execFileSync(process.execPath, [MCP_BIN, '--root', rootDir], {
    input: payload,
    encoding: 'utf8',
    stdio: ['pipe', 'pipe', 'pipe'],
    env: { ...process.env, ...extraEnv },
  });
  const byId = new Map();
  for (const line of stdout.trim().split('\n').filter(Boolean)) {
    const parsed = JSON.parse(line);
    if (parsed.id !== undefined) byId.set(parsed.id, parsed);
  }
  return [1, ...requests.map((_, idx) => idx + 2)].map((id) => byId.get(id));
}

function createV2TestRepo(feature = 'demo-api') {
  const repo = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-mcp-v2-'));
  fs.mkdirSync(path.join(repo, '.git'), { recursive: true });
  fs.mkdirSync(path.join(repo, 'sdd'), { recursive: true });
  fs.mkdirSync(path.join(repo, 'specs', feature), { recursive: true });
  fs.mkdirSync(path.join(repo, 'reports', 'quality-gate'), { recursive: true });
  fs.mkdirSync(path.join(repo, 'src'), { recursive: true });

  fs.writeFileSync(
    path.join(repo, 'AGENTS.md'),
    `# AGENTS.md\n\n## Active Spec Directories\n- \`specs/${feature}/\`\n`,
    'utf8',
  );
  fs.writeFileSync(
    path.join(repo, 'sdd', 'guardrails.yaml'),
    'spec_guard:\n  mode: confirm\nreview:\n  pre_impl_check: auto\nrisk_defaults:\n  default_tier: standard\n',
    'utf8',
  );
  fs.writeFileSync(
    path.join(repo, 'specs', feature, 'requirements.md'),
    [
      `# 要件（SDD Core）: ${feature}`,
      '',
      '## 要件（Requirements）',
      '- **REQ-001**: Health endpoint returns HTTP 200.',
      '',
      '## 受入条件（Acceptance Criteria）',
      '- **AC-001** (REQ-001): GET /health returns `{ ok: true }`.',
      '',
      '## Open Questions',
      '| ID | 分類 | 設計した事実 | 理由 | 問い | 状態 | 影響タスク |',
      '|---|---|---|---|---|---|---|',
      '| OQ-001 | 技術選定 | JSON 応答固定 | シンプル | 確定でよいか | Confirmed | T-001 |',
      '',
      '## Spec Amendments',
      '- （初期版のため変更なし）',
      '',
    ].join('\n'),
    'utf8',
  );
  fs.writeFileSync(
    path.join(repo, 'specs', feature, 'design.md'),
    [
      `# 設計（SDD Core）: ${feature}`,
      '',
      '## 採らなかった設計（Alternatives Rejected）',
      '| 候補案 | 不採用理由 | 再検討条件 |',
      '|---|---|---|',
      '| Express | 外部依存を避けるため | ルート数急増時 |',
      '',
      '## Spec Amendments',
      '- （初期版のため変更なし）',
      '',
    ].join('\n'),
    'utf8',
  );
  fs.writeFileSync(
    path.join(repo, 'specs', feature, 'tasks.md'),
    [
      `# タスク（SDD Core）: ${feature}`,
      '',
      '## T-001 Implement health endpoint',
      'Approval: Approved',
      'Status: Implementation Complete',
      'Risk: standard',
      '',
      '### Scope',
      '- `src/health.mjs` (REQ-001, AC-001)',
      '',
      '### Done When',
      '- AC-001 passes',
      '',
      '### Blockers',
      '- None',
      '',
      '## Spec Amendments',
      '- （初期版のため変更なし）',
      '',
    ].join('\n'),
    'utf8',
  );
  fs.writeFileSync(path.join(repo, 'src', 'health.mjs'), 'export const ok = true;\n', 'utf8');

  execFileSync(process.execPath, [BASELINE_SCRIPT, '--feature', feature, '--root', repo], { encoding: 'utf8' });
  execFileSync(
    process.execPath,
    [GATE_SCRIPT, '--feature', feature, '--task', 'T-001', '--root', repo, '--cmd', 'test=node -e "process.exit(0)"'],
    { encoding: 'utf8' },
  );
  fs.writeFileSync(
    path.join(repo, 'reports', 'quality-gate', `${feature}-T-001.md`),
    '# SDD Gate Report\n\n- **VERDICT**: PASS\n',
    'utf8',
  );
  return repo;
}

describe('ADR-0052: sdd-forge-mcp v2 (4-tool SSOT server, security boundaries & opt-in installer)', () => {
  it('exposes exactly 4 read-only tools (<3.5KB schema, zero root params, strict input) and 2 sdd:// resources', () => {
    const repo = createV2TestRepo();
    const responses = callMcp(repo, [
      { method: 'tools/list', params: {} },
      { method: 'resources/list', params: {} },
      { method: 'resources/templates/list', params: {} },
    ]);

    const tools = responses[1].result.tools;
    const toolNames = tools.map((t) => t.name).sort();
    assert.deepEqual(toolNames, [
      'sdd_dashboard_snapshot',
      'sdd_feature_state',
      'sdd_gate_audit',
      'sdd_project_overview',
    ]);

    for (const tool of tools) {
      assert.equal(tool.annotations?.readOnlyHint, true, `${tool.name} must declare readOnlyHint: true`);
      assert.equal(tool.annotations?.destructiveHint, false, `${tool.name} must declare destructiveHint: false`);
      assert.equal(tool.annotations?.idempotentHint, true, `${tool.name} must declare idempotentHint: true`);
      assert.equal(tool.inputSchema?.additionalProperties, false, `${tool.name} must enforce additionalProperties: false`);
      const props = tool.inputSchema?.properties || {};
      assert.equal('root' in props, false, `${tool.name} must never expose a root input parameter`);
    }

    const schemaBytes = Buffer.byteLength(JSON.stringify(tools), 'utf8');
    assert.ok(schemaBytes < 3500, `Expected compact v2 tool schema (<3500 B), got ${schemaBytes} B`);

    const staticResources = responses[2].result.resources.map((r) => r.uri);
    const templateResources = responses[3].result.resourceTemplates.map((r) => r.uriTemplate);
    assert.deepEqual(staticResources, ['sdd://overview']);
    assert.deepEqual(templateResources, ['sdd://feature/{feature}']);
  });

  it('serves contract-valid v2 overview, feature state, gate audit, dashboard snapshot, and rejects extra/traversal args', () => {
    const repo = createV2TestRepo();
    fs.appendFileSync(path.join(repo, 'sdd/guardrails.yaml'), 'agent_lint:\n  enabled: true\n  mode: strict\n');
    const responses = callMcp(repo, [
      { method: 'tools/call', params: { name: 'sdd_project_overview', arguments: { includeDoctor: true } } },
      {
        method: 'tools/call',
        params: { name: 'sdd_feature_state', arguments: { feature: 'demo-api', includeDecisionViewMarkdown: true } },
      },
      { method: 'tools/call', params: { name: 'sdd_gate_audit', arguments: { feature: 'demo-api', taskId: 'T-001' } } },
      { method: 'tools/call', params: { name: 'sdd_dashboard_snapshot', arguments: {} } },
      { method: 'tools/call', params: { name: 'sdd_feature_state', arguments: { feature: '../etc' } } },
      { method: 'tools/call', params: { name: 'sdd_gate_audit', arguments: { feature: 'demo-api', extraForbidden: 123 } } },
      { method: 'tools/call', params: { name: 'sdd_feature_state', arguments: { feature: 'missing-feature' } } },
      { method: 'resources/read', params: { uri: 'sdd://overview' } },
      { method: 'resources/read', params: { uri: 'sdd://feature/demo-api' } },
    ]);

    const overview = JSON.parse(responses[1].result.content[0].text);
    assert.equal(overview.ok, true);
    assert.equal(overview.data.kind, 'project-overview');
    assert.equal(overview.data.activeFeatures.length, 1);
    assert.equal(overview.data.activeFeatures[0].feature, 'demo-api');
    assert.equal(overview.data.activeFeatures[0].driftStatus, 'CLEAN');
    assert.equal(overview.data.activeFeatures[0].nextAction.phase, 'sdd-gate');
    assert.ok(['CLEAN', 'WARN', 'NG'].includes(overview.data.doctor.status));
    assert.deepEqual(overview.data.doctor.v2_2_gates.agent_lint, { enabled: true, mode: 'strict', waiver_count: 0 });
    const [, compact] = callMcp(repo, [{ method: 'tools/call', params: { name: 'sdd_project_overview', arguments: { includeDoctor: false } } }]);
    assert.equal(JSON.parse(compact.result.content[0].text).data.doctor, undefined);

    const featureState = JSON.parse(responses[2].result.content[0].text);
    assert.equal(featureState.ok, true);
    assert.equal(featureState.data.kind, 'feature-state');
    assert.equal(featureState.data.traceability.complete, true);
    assert.match(featureState.data.decisionViewMarkdown, /# Decision View: demo-api/);
    assert.match(featureState.data.decisionViewMarkdown, /レビュー観点と今回の採否・理由/);

    const gateAudit = JSON.parse(responses[3].result.content[0].text);
    assert.equal(gateAudit.ok, true);
    assert.equal(gateAudit.data.kind, 'gate-audit');
    assert.equal(gateAudit.data.tasks[0].executionArtifact.verdict, 'PASS');
    assert.equal(typeof gateAudit.data.tasks[0].executionArtifact.executedAt, 'string');
    assert.deepEqual(gateAudit.data.tasks[0].executionArtifact.failedCommands, []);
    assert.equal(gateAudit.data.tasks[0].executionArtifact.coverageComplete, true);
    assert.equal(gateAudit.data.tasks[0].reviewReport.verdict, 'PASS');
    assert.equal(gateAudit.data.tasks[0].readyForDone, true);

    // H-1: sdd_dashboard_snapshot wrapped in uniform Result<T> envelope
    const dash = JSON.parse(responses[4].result.content[0].text);
    assert.equal(dash.ok, true);
    assert.equal(dash.data.kind, 'dashboard-snapshot');
    assert.equal(dash.data.snapshot.schema, 'sdd-dashboard/v1');

    // H-3: strict inputSchema rejects traversal & unknown arguments at protocol boundary
    assert.equal(responses[5].result.isError, true);
    assert.equal(responses[6].result.isError, true);

    const missing = JSON.parse(responses[7].result.content[0].text);
    assert.equal(missing.ok, false);
    assert.equal(missing.error.code, 'not-found');
    assert.equal(missing.error.message.includes(repo), false, 'Error message must not leak absolute host path (M-3)');

    const overviewRes = JSON.parse(responses[8].result.contents[0].text);
    assert.equal(overviewRes.ok, true);
    const featureRes = JSON.parse(responses[9].result.contents[0].text);
    assert.equal(featureRes.ok, true);

    // Validate all tool outputs against contracts/sdd-mcp.v2.schema.json. CI sets
    // SDD_REQUIRE_AJV=1 so a missing dependency fails instead of silently skipping (#857).
    if (process.env.SDD_REQUIRE_AJV === '1') {
      assert.ok(Ajv2020, 'SDD_REQUIRE_AJV=1 but ajv could not be resolved from mcp/sdd-forge-mcp (run npm ci there)');
    }
    if (Ajv2020) {
      const schema = JSON.parse(fs.readFileSync(SCHEMA_PATH, 'utf8'));
      const ajv = new Ajv2020({ strict: false });
      ajv.addSchema(schema, 'sdd-mcp-v2');
      const checks = [
        ['sdd_project_overview_data', overview.data],
        ['sdd_feature_state_data', featureState.data],
        ['sdd_gate_audit_data', gateAudit.data],
        ['sdd_dashboard_snapshot_data', dash.data],
        ['errorEnvelope', missing],
      ];
      for (const [def, value] of checks) {
        const validate = ajv.getSchema(`sdd-mcp-v2#/$defs/${def}`);
        assert.ok(validate, `Missing schema def ${def}`);
        assert.equal(validate(value), true, `${def} failed schema validation: ${JSON.stringify(validate.errors)}`);
      }
      // The comparison must be able to fail: a controlled mismatch is rejected.
      const envelope = ajv.getSchema('sdd-mcp-v2#/$defs/errorEnvelope');
      assert.equal(envelope({ ...missing, ok: true, error: 42 }), false, 'schema check accepted a corrupted error envelope');
    }
  });

  it('enforces frozen root (C-1), path-guard symlink/denylist/baseline containment (C-2), fail-closed gate audit (H-2), and graceful draft state (M-1/M-2)', () => {
    // C-1: CLAUDE_PROJECT_DIR must NEVER hijack --root repoB
    const repoA = createV2TestRepo('shared');
    const repoB = createV2TestRepo('shared');
    fs.writeFileSync(
      path.join(repoA, 'specs', 'shared', 'requirements.md'),
      '# 要件: shared\n\n## Open Questions\n| ID | 分類 | 設計した事実 | 理由 | 問い | 状態 | 影響タスク |\n|---|---|---|---|---|---|---|\n| OQ-099 | 不可逆リスク | LEAKED_FROM_REPO_A | x | y | Provisional | T-001 |\n',
      'utf8',
    );
    const isolatedRes = callMcp(
      repoB,
      [{ method: 'tools/call', params: { name: 'sdd_feature_state', arguments: { feature: 'shared', includeDecisionViewMarkdown: true } } }],
      { CLAUDE_PROJECT_DIR: repoA, SDD_PROJECT_ROOT: repoA },
    );
    const isolated = JSON.parse(isolatedRes[1].result.content[0].text);
    assert.equal(isolated.ok, true);
    assert.equal(isolated.data.decisionViewMarkdown.includes('LEAKED_FROM_REPO_A'), false);

    // C-2: Symlink to external .env must NOT leak through decisionViewMarkdown
    const outsideDir = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-outside-'));
    const secretFile = path.join(outsideDir, '.env');
    fs.writeFileSync(secretFile, '| OQ-001 | 事業判断 | SUPER_SECRET_TOKEN_XYZ | r | q | Provisional | T-001 |\n', 'utf8');
    fs.mkdirSync(path.join(repoB, 'specs', 'symfeat'), { recursive: true });
    fs.symlinkSync(secretFile, path.join(repoB, 'specs', 'symfeat', 'requirements.md'));
    fs.writeFileSync(path.join(repoB, 'specs', 'symfeat', 'design.md'), '# Design\n', 'utf8');

    const symRes = callMcp(repoB, [
      { method: 'tools/call', params: { name: 'sdd_feature_state', arguments: { feature: 'symfeat', includeDecisionViewMarkdown: true } } },
    ]);
    const symData = JSON.parse(symRes[1].result.content[0].text);
    assert.equal(symData.ok, true, 'Draft/partial feature without tasks.md must not crash (M-1)');
    assert.equal(symData.data.files.requirements, false);
    assert.equal(symData.data.nextAction.phase, 'bootstrap');
    assert.equal(symData.data.decisionViewMarkdown.includes('SUPER_SECRET_TOKEN_XYZ'), false);

    // C-2 + H-2: Tampered .spec-baseline.json pointing outside root -> BASELINE_ERROR & readyForDone: false
    const baselinePath = path.join(repoB, 'specs', 'shared', '.spec-baseline.json');
    const tampered = JSON.parse(fs.readFileSync(baselinePath, 'utf8'));
    tampered.files['../outside.txt'] = { fileName: 'outside.txt', contractSha256: 'deadbeef', identifiers: {} };
    fs.writeFileSync(baselinePath, JSON.stringify(tampered), 'utf8');
    const badBaseRes = callMcp(repoB, [
      { method: 'tools/call', params: { name: 'sdd_gate_audit', arguments: { feature: 'shared', taskId: 'T-001' } } },
      { method: 'tools/call', params: { name: 'sdd_feature_state', arguments: { feature: 'shared' } } },
    ]);
    const badBaseAudit = JSON.parse(badBaseRes[1].result.content[0].text);
    const badBaseState = JSON.parse(badBaseRes[2].result.content[0].text);
    assert.equal(badBaseState.data.drift.status, 'BASELINE_ERROR');
    assert.equal(badBaseAudit.data.tasks[0].readyForDone, false);

    // H-2: Review report mentioning VERDICT: PASS above final VERDICT: FAIL must fail closed
    const repoC = createV2TestRepo('verdict-test');
    fs.writeFileSync(
      path.join(repoC, 'reports', 'quality-gate', 'verdict-test-T-001.md'),
      '# Report\nCriteria: VERDICT: PASS requires all checks green.\n\n- **VERDICT**: **FAIL**\n',
      'utf8',
    );
    const failVerdictRes = callMcp(repoC, [
      { method: 'tools/call', params: { name: 'sdd_gate_audit', arguments: { feature: 'verdict-test', taskId: 'T-001' } } },
    ]);
    const failVerdict = JSON.parse(failVerdictRes[1].result.content[0].text);
    assert.equal(failVerdict.data.tasks[0].reviewReport.verdict, 'FAIL');
    assert.equal(failVerdict.data.tasks[0].readyForDone, false);

    // #825: a mechanical PASS that ran zero verification commands is not Done evidence,
    // even next to a PASS review report; one real command restores readiness.
    const repoZero = createV2TestRepo('zero-cmd');
    const zeroGate = spawnSync(
      process.execPath,
      [GATE_SCRIPT, '--feature', 'zero-cmd', '--task', 'T-001', '--root', repoZero],
      { encoding: 'utf8' },
    );
    assert.equal(zeroGate.status, 0, zeroGate.stderr);
    const zeroResult = JSON.parse(zeroGate.stdout);
    assert.equal(zeroResult.verdict, 'PASS');
    assert.deepEqual(zeroResult.coverage, { commandsRun: 0, specDriftChecked: true, sensorsChecked: true, complete: false });
    assert.match(zeroResult.warnings.join('\n'), /NO_VERIFICATION_COMMANDS/);
    assert.match(zeroGate.stderr, /NO_VERIFICATION_COMMANDS/);
    const zeroAudit = JSON.parse(
      callMcp(repoZero, [
        { method: 'tools/call', params: { name: 'sdd_gate_audit', arguments: { feature: 'zero-cmd', taskId: 'T-001' } } },
      ])[1].result.content[0].text,
    );
    assert.equal(zeroAudit.data.tasks[0].executionArtifact.verdict, 'PASS');
    assert.equal(zeroAudit.data.tasks[0].executionArtifact.coverageComplete, false);
    assert.equal(zeroAudit.data.tasks[0].reviewReport.verdict, 'PASS');
    assert.equal(zeroAudit.data.tasks[0].readyForDone, false);

    // A self-declared coverage.complete that its own checks contradict is not trusted.
    const execPath = path.join(repoZero, 'reports', 'quality-gate', 'zero-cmd-T-001.execution.json');
    const forged = JSON.parse(fs.readFileSync(execPath, 'utf8'));
    forged.coverage = { ...forged.coverage, complete: true };
    fs.writeFileSync(execPath, JSON.stringify(forged), 'utf8');
    const forgedAudit = JSON.parse(
      callMcp(repoZero, [
        { method: 'tools/call', params: { name: 'sdd_gate_audit', arguments: { feature: 'zero-cmd', taskId: 'T-001' } } },
      ])[1].result.content[0].text,
    );
    assert.equal(forgedAudit.data.tasks[0].executionArtifact.coverageComplete, false);
    assert.equal(forgedAudit.data.tasks[0].readyForDone, false);

    // NEW-M3a: Existing empty specs/<feature>/ directory must return ok: true, phase: 'bootstrap'
    fs.mkdirSync(path.join(repoC, 'specs', 'empty-draft'), { recursive: true });
    // NEW-M3b: Fenced code block containing VERDICT: FAIL must not trigger false-negative FAIL
    fs.writeFileSync(
      path.join(repoC, 'reports', 'quality-gate', 'verdict-test-T-001.md'),
      '# Report\n```markdown\nVERDICT: FAIL\n```\n\n- **VERDICT**: **PASS**\n',
      'utf8',
    );
    const m3Res = callMcp(repoC, [
      { method: 'tools/call', params: { name: 'sdd_feature_state', arguments: { feature: 'empty-draft' } } },
      { method: 'tools/call', params: { name: 'sdd_gate_audit', arguments: { feature: 'verdict-test', taskId: 'T-001' } } },
    ]);
    const emptyDraft = JSON.parse(m3Res[1].result.content[0].text);
    assert.equal(emptyDraft.ok, true, 'Empty existing feature dir must not return cannot-parse');
    assert.equal(emptyDraft.data.nextAction.phase, 'bootstrap');
    const fencedPass = JSON.parse(m3Res[2].result.content[0].text);
    assert.equal(fencedPass.data.tasks[0].reviewReport.verdict, 'PASS', 'Fenced code block VERDICT: FAIL must be ignored');

    // M-2: One Done task + one Draft task must NOT report phase === 'done'
    const tasksPath = path.join(repoC, 'specs', 'verdict-test', 'tasks.md');
    fs.writeFileSync(
      tasksPath,
      fs.readFileSync(tasksPath, 'utf8').replace('Status: Implementation Complete', 'Status: Done') +
        '\n## T-002 Follow-up\nApproval: Draft\nStatus: Planned\nRisk: high\n\n### Scope\n- `src/b.mjs`\n\n### Done When\n- AC-001\n\n### Blockers\n- None\n',
      'utf8',
    );
    execFileSync(process.execPath, [BASELINE_SCRIPT, '--feature', 'verdict-test', '--root', repoC, '--rerecord'], { encoding: 'utf8' });
    const nextRes = callMcp(repoC, [
      { method: 'tools/call', params: { name: 'sdd_feature_state', arguments: { feature: 'verdict-test' } } },
    ]);
    const nextState = JSON.parse(nextRes[1].result.content[0].text);
    assert.equal(nextState.data.nextAction.phase, 'approval-gate');
  });

  it('#835: a Done task with a mechanical PASS but a failing or missing independent verdict shows as failed', () => {
    const cases = [
      ['NEEDS_WORK', '# SDD Gate Report\n\n- **Task ID**: T-001\nVERDICT: NEEDS_WORK\n', false],
      ['BLOCKED', '# SDD Gate Report\n\n- **Task ID**: T-001\n- **VERDICT**: BLOCKED\n', false],
      ['missing', null, false],
      ['PASS', '# SDD Gate Report\n\n- **Task ID**: T-001\n- **VERDICT**: PASS\n', true],
      // Review findings on the first #835 fix: legitimate PASS reports must stay PASS.
      ['round history', '# Report\n\nTask ID: T-001\nVERDICT: PASS\n\n## Round 1\n> VERDICT: NEEDS_WORK\n', true],
      ['fenced evaluator block only', '# Report\n\nTask ID: T-001\n\n```\nVERDICT: PASS\n```\n', true],
      ['rules prose', '# Report\n\nTask ID: T-001\nVERDICT: PASS\n\n- verdict: fail if any Major remains\n', true],
      ['first plain verdict wins', '# Report\n\nTask ID: T-001\nVERDICT: NEEDS_WORK\n\n## Earlier draft\nVERDICT: PASS\n', false],
    ];
    for (const [label, report, expectPass] of cases) {
      const repo = createV2TestRepo('nw-check');
      const tasksPath = path.join(repo, 'specs', 'nw-check', 'tasks.md');
      fs.writeFileSync(tasksPath, fs.readFileSync(tasksPath, 'utf8').replace('Status: Implementation Complete', 'Status: Done'), 'utf8');
      const mdPath = path.join(repo, 'reports', 'quality-gate', 'nw-check-T-001.md');
      if (report === null) fs.rmSync(mdPath);
      else fs.writeFileSync(mdPath, report, 'utf8');
      const res = callMcp(repo, [
        { method: 'tools/call', params: { name: 'sdd_gate_audit', arguments: { feature: 'nw-check', taskId: 'T-001' } } },
        { method: 'tools/call', params: { name: 'sdd_dashboard_snapshot', arguments: {} } },
      ]);
      const audit = JSON.parse(res[1].result.content[0].text);
      assert.equal(audit.data.tasks[0].executionArtifact.verdict, 'PASS', `${label}: mechanical gate passed`);
      assert.equal(audit.data.tasks[0].readyForDone, expectPass, `${label}: readyForDone`);
      if (report !== null) assert.equal(audit.data.tasks[0].reviewReport.verdict, expectPass ? 'PASS' : 'FAIL', `${label}: verdict`);
      const dash = JSON.parse(res[2].result.content[0].text);
      const task = dash.data.snapshot.data.tasks.find((t) => t.key === 'nw-check/T-001');
      assert.ok(task, `${label}: dashboard lists the task`);
      const verdictFailures = task.failures.filter((f) => /quality-gate/.test(f));
      assert.equal(verdictFailures.length === 0, expectPass, `${label}: dashboard failures ${JSON.stringify(task.failures)}`);
    }
  });

  it(
    'install.sh places dashboard CLI runtime by default without registering MCPs, rejects conflicting flags, and supports --with-mcp',
    { skip: process.platform === 'win32' },
    () => {
      // 1. Default install: places sdd-forge-mcp/dist/index.js for /sdd-ship:status (C-4), does NOT place local-env/ci-mcp, and skips MCP registration
      const defaultRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-optin-default-'));
      const resDefault = spawnSync(
        'bash',
        [
          path.join(REPO_ROOT, 'install.sh'),
          '--source-directory',
          REPO_ROOT,
          '--install-root',
          defaultRoot,
          '--target',
          'FilesOnly',
          '--skip-agent-install',
        ],
        { cwd: REPO_ROOT, encoding: 'utf8' },
      );
      assert.equal(resDefault.status, 0, resDefault.stderr);
      assert.equal(fs.existsSync(path.join(defaultRoot, 'mcp/sdd-forge-mcp/dist/index.js')), true);
      assert.equal(fs.existsSync(path.join(defaultRoot, 'mcp/local-env-mcp')), false);
      assert.equal(fs.existsSync(path.join(defaultRoot, 'mcp/ci-mcp')), false);
      assert.match(resDefault.stdout, /--with-mcp/);

      // 2. Conflicting --skip-mcp --with-mcp rejected explicitly (M-4)
      const resConflict = spawnSync(
        'bash',
        [path.join(REPO_ROOT, 'install.sh'), '--skip-mcp', '--with-mcp', '--target', 'FilesOnly'],
        { cwd: REPO_ROOT, encoding: 'utf8' },
      );
      assert.notEqual(resConflict.status, 0);
      assert.match(resConflict.stderr, /cannot be combined/);

      // 3. Explicit --mcp local-env-mcp warns deprecated
      const depRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-optin-dep-'));
      const resDep = spawnSync(
        'bash',
        [
          path.join(REPO_ROOT, 'install.sh'),
          '--source-directory',
          REPO_ROOT,
          '--install-root',
          depRoot,
          '--target',
          'FilesOnly',
          '--mcp',
          'sdd-forge-mcp,local-env-mcp',
          '--skip-agent-install',
        ],
        { cwd: REPO_ROOT, encoding: 'utf8' },
      );
      assert.equal(resDep.status, 0, resDep.stderr);
      assert.match(resDep.stderr, /local-env-mcp.*deprecated.*ADR-0052/i);
      assert.equal(fs.existsSync(path.join(depRoot, 'mcp/sdd-forge-mcp/dist/index.js')), true);
      assert.equal(fs.existsSync(path.join(depRoot, 'mcp/local-env-mcp/dist/index.js')), true);
    },
  );
});

describe('#834 a spec file over the MCP read limit is unverifiable, not deleted', () => {
  it('the CLI stays CLEAN, MCP reports UNVERIFIABLE and blocks with the reason, and a real deletion is still drift', () => {
    const repo = createV2TestRepo();
    const designPath = path.join(repo, 'specs', 'demo-api', 'design.md');
    const original = fs.readFileSync(designPath, 'utf8');
    const firstBreak = original.indexOf('\n') + 1;
    // Padding goes above every section so it is neither an amendment nor an identifier line.
    fs.writeFileSync(designPath, `${original.slice(0, firstBreak)}\n<!-- ${'x'.repeat(2.2 * 1024 * 1024)} -->\n${original.slice(firstBreak)}`, 'utf8');
    execFileSync(process.execPath, [BASELINE_SCRIPT, '--feature', 'demo-api', '--root', repo, '--rerecord'], { encoding: 'utf8' });
    const cli = JSON.parse(
      execFileSync(process.execPath, [path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/check-spec-drift.mjs'), '--feature', 'demo-api', '--root', repo], { encoding: 'utf8' }),
    );
    assert.equal(cli.status, 'CLEAN');

    const [, overviewRes, stateRes] = callMcp(repo, [
      { method: 'tools/call', params: { name: 'sdd_project_overview', arguments: {} } },
      { method: 'tools/call', params: { name: 'sdd_feature_state', arguments: { feature: 'demo-api' } } },
    ]);
    const feature = JSON.parse(overviewRes.result.content[0].text).data.activeFeatures[0];
    assert.equal(feature.driftStatus, 'UNVERIFIABLE');
    assert.equal(feature.nextAction.phase, 'blocked');
    assert.match(feature.nextAction.rationale, /read limit/);
    assert.doesNotMatch(feature.nextAction.rationale, /revert undeclared edits/);
    const state = JSON.parse(stateRes.result.content[0].text);
    assert.equal(state.ok, true);
    if (Ajv2020) {
      const ajv = new Ajv2020({ strict: false });
      ajv.addSchema(JSON.parse(fs.readFileSync(SCHEMA_PATH, 'utf8')), 'sdd-mcp-v2');
      const validate = ajv.getSchema('sdd-mcp-v2#/$defs/sdd_feature_state_data');
      assert.equal(validate(state.data), true, JSON.stringify(validate.errors));
    }

    fs.unlinkSync(designPath);
    const [, afterDelete] = callMcp(repo, [{ method: 'tools/call', params: { name: 'sdd_project_overview', arguments: {} } }]);
    assert.equal(JSON.parse(afterDelete.result.content[0].text).data.activeFeatures[0].driftStatus, 'UNDECLARED_DRIFT');
  });
});

describe('#831/#832 gate evidence is bound to the spec inputs it verified', () => {
  const gateAudit = (repo) => {
    const [, res] = callMcp(repo, [{ method: 'tools/call', params: { name: 'sdd_gate_audit', arguments: { feature: 'demo-api' } } }]);
    return JSON.parse(res.result.content[0].text).data.tasks;
  };
  const overviewAction = (repo) => {
    const [, res] = callMcp(repo, [{ method: 'tools/call', params: { name: 'sdd_project_overview', arguments: {} } }]);
    return JSON.parse(res.result.content[0].text).data.activeFeatures[0].nextAction;
  };
  const runGate = (repo, task) =>
    execFileSync(process.execPath, [GATE_SCRIPT, '--feature', 'demo-api', '--task', task, '--root', repo, '--cmd', 'test=node -e "process.exit(0)"'], { encoding: 'utf8' });
  const edit = (file, from, to) => {
    const text = fs.readFileSync(file, 'utf8');
    assert.ok(text.includes(from), from);
    fs.writeFileSync(file, text.replace(from, to), 'utf8');
  };
  const validateAudit = (tasks) => {
    if (!Ajv2020) return;
    const ajv = new Ajv2020({ strict: false });
    ajv.addSchema(JSON.parse(fs.readFileSync(SCHEMA_PATH, 'utf8')), 'sdd-mcp-v2');
    const validate = ajv.getSchema('sdd-mcp-v2#/$defs/sdd_gate_audit_data');
    assert.equal(validate({ kind: 'gate-audit', feature: 'demo-api', tasks }), true, JSON.stringify(validate.errors));
  };

  it('a PASS recorded before an amended AC is not ready for Done until the gate runs again', () => {
    const repo = createV2TestRepo();
    const req = path.join(repo, 'specs', 'demo-api', 'requirements.md');
    let [t1] = gateAudit(repo);
    assert.equal(t1.executionArtifact.specInputsCurrent, true);
    assert.equal(t1.readyForDone, true);
    validateAudit([t1]);

    edit(req, 'GET /health returns `{ ok: true }`.', 'GET /health returns `{ ok: true, version }`.');
    edit(req, '- （初期版のため変更なし）', '- 2026-11-25: AC-001 adds the version field (owner agreed).');
    [t1] = gateAudit(repo);
    assert.equal(t1.executionArtifact.specInputsCurrent, false);
    assert.deepEqual(t1.executionArtifact.specInputsChanged, ['AC-001']);
    assert.equal(t1.readyForDone, false, 'the old PASS verified the old AC');
    validateAudit([t1]);

    runGate(repo, 'T-001');
    [t1] = gateAudit(repo);
    assert.equal(t1.executionArtifact.specInputsCurrent, true);
    assert.equal(t1.readyForDone, true);
  });

  it('status and approval edits keep evidence current; legacy evidence counts only while drift is CLEAN', () => {
    const repo = createV2TestRepo();
    const tasksPath = path.join(repo, 'specs', 'demo-api', 'tasks.md');
    edit(tasksPath, 'Status: Implementation Complete', 'Status: Done');
    assert.equal(gateAudit(repo)[0].executionArtifact.specInputsCurrent, true);

    const artifactPath = path.join(repo, 'reports', 'quality-gate', 'demo-api-T-001.execution.json');
    const artifact = JSON.parse(fs.readFileSync(artifactPath, 'utf8'));
    delete artifact.specInputs;
    fs.writeFileSync(artifactPath, JSON.stringify(artifact), 'utf8');
    let [t1] = gateAudit(repo);
    assert.equal(t1.executionArtifact.specInputsCurrent, undefined);
    assert.equal(t1.readyForDone, true, 'legacy evidence with CLEAN drift');

    const design = path.join(repo, 'specs', 'demo-api', 'design.md');
    edit(design, '| Express |', '| Fastify |');
    edit(design, '- （初期版のため変更なし）', '- 2026-11-25: alternatives table updated (owner agreed).');
    [t1] = gateAudit(repo);
    assert.equal(t1.readyForDone, false, 'legacy evidence cannot prove it saw the amended design');
  });

  it('#832 a Done task whose evidence is stale is re-verified through ship for that task; others are not', () => {
    const repo = createV2TestRepo();
    const req = path.join(repo, 'specs', 'demo-api', 'requirements.md');
    const tasksPath = path.join(repo, 'specs', 'demo-api', 'tasks.md');
    edit(req, '## Open Questions', '- **AC-002** (REQ-001): HEAD /health returns 200.\n\n## Open Questions');
    edit(tasksPath, '## Spec Amendments',
      '## T-002 Implement HEAD\nApproval: Approved\nStatus: Implementation Complete\nRisk: standard\n\n### Scope\n- `src/head.mjs`\n\n### Done When\n- AC-002 passes\n\n### Blockers\n- None\n\n## Spec Amendments');
    fs.writeFileSync(path.join(repo, 'src', 'head.mjs'), 'export const head = true;\n', 'utf8');
    execFileSync(process.execPath, [BASELINE_SCRIPT, '--feature', 'demo-api', '--root', repo, '--rerecord'], { encoding: 'utf8' });
    runGate(repo, 'T-001');
    runGate(repo, 'T-002');
    fs.writeFileSync(path.join(repo, 'reports', 'quality-gate', 'demo-api-T-002.md'), '# SDD Gate Report\n\n- **VERDICT**: PASS\n', 'utf8');
    fs.writeFileSync(tasksPath, fs.readFileSync(tasksPath, 'utf8').replaceAll('Status: Implementation Complete', 'Status: Done'), 'utf8');
    assert.equal(overviewAction(repo).phase, 'done');

    edit(req, 'HEAD /health returns 200.', 'HEAD /health returns 204.');
    edit(req, '- （初期版のため変更なし）', '- 2026-11-25: AC-002 now expects 204 (owner agreed).');
    const action = overviewAction(repo);
    assert.equal(action.phase, 'sdd-gate');
    assert.equal(action.command, '/sdd-ship:ship specs/demo-api/tasks.md#T-002');
    const [t1, t2] = gateAudit(repo);
    assert.equal(t1.executionArtifact.specInputsCurrent, true, 'T-001 does not reference AC-002');
    assert.equal(t2.executionArtifact.specInputsCurrent, false);

    runGate(repo, 'T-002');
    assert.equal(overviewAction(repo).phase, 'done');
  });
});

describe('#972 batch-6 review: re-verification outcome and input coverage', () => {
  const overview = (repo) => {
    const [, res] = callMcp(repo, [{ method: 'tools/call', params: { name: 'sdd_project_overview', arguments: {} } }]);
    return JSON.parse(res.result.content[0].text).data.activeFeatures[0].nextAction;
  };
  const audit = (repo) => {
    const [, res] = callMcp(repo, [{ method: 'tools/call', params: { name: 'sdd_gate_audit', arguments: { feature: 'demo-api' } } }]);
    return JSON.parse(res.result.content[0].text).data.tasks[0];
  };
  const gate = (repo, cmd) =>
    spawnSync(process.execPath, [GATE_SCRIPT, '--feature', 'demo-api', '--task', 'T-001', '--root', repo, ...(cmd ? ['--cmd', cmd] : [])], { encoding: 'utf8' });
  const edit = (file, from, to) => {
    const text = fs.readFileSync(file, 'utf8');
    assert.ok(text.includes(from), from);
    fs.writeFileSync(file, text.replace(from, to), 'utf8');
  };
  const doneRepo = () => {
    const repo = createV2TestRepo();
    const tasksPath = path.join(repo, 'specs', 'demo-api', 'tasks.md');
    edit(tasksPath, 'Status: Implementation Complete', 'Status: Done');
    assert.equal(overview(repo).phase, 'done');
    return repo;
  };
  const amend = (repo, from, to, file = 'requirements.md') => {
    const p = path.join(repo, 'specs', 'demo-api', file);
    edit(p, from, to);
    if (fs.readFileSync(p, 'utf8').includes('- （初期版のため変更なし）')) edit(p, '- （初期版のため変更なし）', '- 2026-11-25: amended (owner agreed).');
  };

  it('a failed or command-less re-verification of a Done task is not reported as done', () => {
    const repo = doneRepo();
    amend(repo, 'GET /health returns `{ ok: true }`.', 'GET /health returns `{ ok: true, v: 2 }`.');
    assert.equal(overview(repo).phase, 'sdd-gate');
    gate(repo, 'test=node -e "process.exit(1)"');
    const failed = overview(repo);
    assert.equal(failed.phase, 'blocked', JSON.stringify(failed));
    assert.match(failed.rationale, /T-001/);
    gate(repo, null);
    assert.notEqual(overview(repo).phase, 'done', 'a run with no verification commands does not complete it');
    gate(repo, 'test=node -e "process.exit(0)"');
    assert.equal(overview(repo).phase, 'done');
  });

  it('continuation lines, table rows and fenced code in the task are part of the inputs', () => {
    const repo = createV2TestRepo();
    const req = path.join(repo, 'specs', 'demo-api', 'requirements.md');
    edit(req, '- **AC-001** (REQ-001): GET /health returns `{ ok: true }`.', '- **AC-001** (REQ-001): GET /health returns `{ ok: true }`.\n  - Then the body has no other keys');
    fs.writeFileSync(path.join(repo, 'specs', 'demo-api', 'acceptance-tests.md'), '# AT\n\n| AC | REQ | Test | Check |\n|---|---|---|---|\n| AC-001 | REQ-001 | TEST-001 | status 200 |\n', 'utf8');
    const tasksPath = path.join(repo, 'specs', 'demo-api', 'tasks.md');
    edit(tasksPath, '### Done When\n- AC-001 passes', '### Done When\n- AC-001 passes\n\n```bash\ncurl -s localhost/health\n```');
    execFileSync(process.execPath, [BASELINE_SCRIPT, '--feature', 'demo-api', '--root', repo, '--rerecord'], { encoding: 'utf8' });
    gate(repo, 'test=node -e "process.exit(0)"');
    assert.equal(audit(repo).executionArtifact.specInputsCurrent, true);

    edit(req, '  - Then the body has no other keys', '  - Then the body may carry a version');
    assert.equal(audit(repo).executionArtifact.specInputsCurrent, false, 'continuation line');
    gate(repo, 'test=node -e "process.exit(0)"');
    edit(path.join(repo, 'specs', 'demo-api', 'acceptance-tests.md'), '| status 200 |', '| status 204 |');
    assert.equal(audit(repo).executionArtifact.specInputsCurrent, false, 'table row');
    gate(repo, 'test=node -e "process.exit(0)"');
    edit(tasksPath, 'curl -s localhost/health', 'curl -sf localhost/health');
    assert.equal(audit(repo).executionArtifact.specInputsCurrent, false, 'fenced code in the task');
  });
});

describe('#972 review 3: heading-style IDs and failed review verdicts', () => {
  const tool = (repo, name, args) => {
    const [, res] = callMcp(repo, [{ method: 'tools/call', params: { name, arguments: args } }]);
    return JSON.parse(res.result.content[0].text).data;
  };
  const gate = (repo) =>
    execFileSync(process.execPath, [GATE_SCRIPT, '--feature', 'demo-api', '--task', 'T-001', '--root', repo, '--cmd', 'test=node -e "process.exit(0)"'], { encoding: 'utf8' });
  const edit = (file, from, to) => {
    const text = fs.readFileSync(file, 'utf8');
    assert.ok(text.includes(from), from);
    fs.writeFileSync(file, text.replace(from, to), 'utf8');
  };

  it('an AC written as a heading is still an evidence input', () => {
    const repo = createV2TestRepo();
    const req = path.join(repo, 'specs', 'demo-api', 'requirements.md');
    edit(req, '- **AC-001** (REQ-001): GET /health returns `{ ok: true }`.', '### AC-001 (REQ-001)\nGET /health returns `{ ok: true }`.');
    execFileSync(process.execPath, [BASELINE_SCRIPT, '--feature', 'demo-api', '--root', repo, '--rerecord'], { encoding: 'utf8' });
    gate(repo);
    assert.equal(tool(repo, 'sdd_gate_audit', { feature: 'demo-api' }).tasks[0].executionArtifact.specInputsCurrent, true);
    edit(req, 'GET /health returns `{ ok: true }`.', 'GET /health returns 500.');
    edit(req, '- （初期版のため変更なし）', '- 2026-11-25: AC-001 changed (owner agreed).');
    const t1 = tool(repo, 'sdd_gate_audit', { feature: 'demo-api' }).tasks[0];
    assert.equal(t1.executionArtifact.specInputsCurrent, false);
    assert.equal(t1.readyForDone, false);
  });

  it('a nested AC bullet under its REQ is its own entry', async () => {
    const { featureEvidenceInputs, diffEvidenceInputs } = await import('../plugins/sdd-quality-loop/scripts/v2/v2-readonly-core.mjs');
    const files = {
      'specs/f/requirements.md': '# r\n\n- **REQ-001**: health\n  - **AC-001**: returns 200\n  - **AC-002**: returns json\n',
      'specs/f/tasks.md': '# t\n\n## T-001 x\nApproval: Approved\nStatus: Done\n\n### Done When\n- AC-001\n',
    };
    const io = { readText: (rel) => files[rel] ?? null, exists: (rel) => rel in files };
    const before = featureEvidenceInputs(io, { feature: 'f' }).get('T-001');
    files['specs/f/requirements.md'] = files['specs/f/requirements.md'].replace('returns 200', 'returns 204');
    assert.ok(diffEvidenceInputs(before, featureEvidenceInputs(io, { feature: 'f' }).get('T-001')).includes('AC-001'));
  });

  it('a Done task re-verified with a FAIL review verdict is not reported as done', () => {
    const repo = createV2TestRepo();
    const tasksPath = path.join(repo, 'specs', 'demo-api', 'tasks.md');
    edit(tasksPath, 'Status: Implementation Complete', 'Status: Done');
    fs.writeFileSync(path.join(repo, 'reports', 'quality-gate', 'demo-api-T-001.md'), '# SDD Gate Report\n\nVERDICT: FAIL\n', 'utf8');
    const action = tool(repo, 'sdd_project_overview', {}).activeFeatures[0].nextAction;
    assert.equal(action.phase, 'blocked', JSON.stringify(action));
  });
});
