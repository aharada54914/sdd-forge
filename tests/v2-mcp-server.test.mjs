import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..');
const MCP_BIN = path.join(REPO_ROOT, 'mcp/sdd-forge-mcp/dist/index.js');
const BASELINE_SCRIPT = path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/record-spec-baseline.mjs');
const GATE_SCRIPT = path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/run-sdd-gate.mjs');

function callMcp(rootDir, requests) {
  const payload = [
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
  });
  const byId = new Map();
  for (const line of stdout.trim().split('\n').filter(Boolean)) {
    const parsed = JSON.parse(line);
    if (parsed.id !== undefined) byId.set(parsed.id, parsed);
  }
  return [1, ...requests.map((_, idx) => idx + 2)].map((id) => byId.get(id));
}

function createV2TestRepo() {
  const repo = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-mcp-v2-'));
  fs.mkdirSync(path.join(repo, '.git'), { recursive: true });
  fs.mkdirSync(path.join(repo, 'sdd'), { recursive: true });
  fs.mkdirSync(path.join(repo, 'specs', 'demo-api'), { recursive: true });
  fs.mkdirSync(path.join(repo, 'reports', 'quality-gate'), { recursive: true });
  fs.mkdirSync(path.join(repo, 'src'), { recursive: true });

  fs.writeFileSync(
    path.join(repo, 'AGENTS.md'),
    '# AGENTS.md\n\n## Active Spec Directories\n- `specs/demo-api/`\n',
    'utf8',
  );
  fs.writeFileSync(
    path.join(repo, 'sdd', 'guardrails.yaml'),
    'spec_guard:\n  mode: confirm\nreview:\n  pre_impl_check: auto\nrisk_defaults:\n  default_tier: standard\n',
    'utf8',
  );
  fs.writeFileSync(
    path.join(repo, 'specs', 'demo-api', 'requirements.md'),
    [
      '# 要件（SDD Core）: demo-api',
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
    path.join(repo, 'specs', 'demo-api', 'design.md'),
    [
      '# 設計（SDD Core）: demo-api',
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
    path.join(repo, 'specs', 'demo-api', 'tasks.md'),
    [
      '# タスク（SDD Core）: demo-api',
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

  execFileSync(process.execPath, [BASELINE_SCRIPT, '--feature', 'demo-api', '--root', repo], { encoding: 'utf8' });
  execFileSync(
    process.execPath,
    [GATE_SCRIPT, '--feature', 'demo-api', '--task', 'T-001', '--root', repo, '--cmd', 'test=node -e "process.exit(0)"'],
    { encoding: 'utf8' },
  );
  fs.writeFileSync(
    path.join(repo, 'reports', 'quality-gate', 'demo-api-T-001.md'),
    '# SDD Gate Report\n\n- **VERDICT**: PASS\n',
    'utf8',
  );
  return repo;
}

describe('ADR-0052: sdd-forge-mcp v2 (4-tool SSOT server & opt-in installer)', () => {
  it('exposes exactly 4 read-only tools (<3.5KB schema, zero root params) and 2 sdd:// resources', () => {
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

  it('serves accurate v2 overview, feature state, gate audit, drift detection, and rejects path traversal', () => {
    const repo = createV2TestRepo();
    const responses = callMcp(repo, [
      { method: 'tools/call', params: { name: 'sdd_project_overview', arguments: { includeDoctor: true } } },
      {
        method: 'tools/call',
        params: { name: 'sdd_feature_state', arguments: { feature: 'demo-api', includeDecisionViewMarkdown: true } },
      },
      { method: 'tools/call', params: { name: 'sdd_gate_audit', arguments: { feature: 'demo-api', taskId: 'T-001' } } },
      { method: 'tools/call', params: { name: 'sdd_feature_state', arguments: { feature: '../etc' } } },
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

    const featureState = JSON.parse(responses[2].result.content[0].text);
    assert.equal(featureState.ok, true);
    assert.equal(featureState.data.kind, 'feature-state');
    assert.equal(featureState.data.traceability.complete, true);
    assert.equal(featureState.data.traceability.requirementCount, 1);
    assert.equal(featureState.data.traceability.acCount, 1);
    assert.equal(featureState.data.drift.status, 'CLEAN');
    assert.equal(featureState.data.openQuestions.provisionalCount, 0);
    assert.match(featureState.data.decisionViewMarkdown, /# Decision View: demo-api/);

    const gateAudit = JSON.parse(responses[3].result.content[0].text);
    assert.equal(gateAudit.ok, true);
    assert.equal(gateAudit.data.kind, 'gate-audit');
    assert.equal(gateAudit.data.tasks.length, 1);
    assert.equal(gateAudit.data.tasks[0].executionArtifact.verdict, 'PASS');
    assert.equal(gateAudit.data.tasks[0].reviewReport.verdict, 'PASS');
    assert.equal(gateAudit.data.tasks[0].readyForDone, true);

    const traversal = JSON.parse(responses[4].result.content[0].text);
    assert.equal(traversal.ok, false);
    assert.equal(traversal.error.code, 'invalid-input');

    const missing = JSON.parse(responses[5].result.content[0].text);
    assert.equal(missing.ok, false);
    assert.equal(missing.error.code, 'not-found');

    const overviewRes = JSON.parse(responses[6].result.contents[0].text);
    assert.equal(overviewRes.ok, true);
    assert.equal(overviewRes.data.kind, 'project-overview');

    const featureRes = JSON.parse(responses[7].result.contents[0].text);
    assert.equal(featureRes.ok, true);
    assert.match(featureRes.data.decisionViewMarkdown, /# Decision View: demo-api/);

    // Silent AC mutation -> UNDECLARED_DRIFT & readyForDone: false
    const reqPath = path.join(repo, 'specs', 'demo-api', 'requirements.md');
    fs.writeFileSync(reqPath, fs.readFileSync(reqPath, 'utf8').replace('HTTP 200', 'HTTP 204'), 'utf8');
    const afterDrift = callMcp(repo, [
      { method: 'tools/call', params: { name: 'sdd_gate_audit', arguments: { feature: 'demo-api', taskId: 'T-001' } } },
    ]);
    const driftAudit = JSON.parse(afterDrift[1].result.content[0].text);
    assert.equal(driftAudit.data.tasks[0].readyForDone, false);
  });

  it(
    'install.sh defaults to opt-in MCP (0 servers), --with-mcp installs only sdd-forge-mcp v2, and local-env-mcp emits deprecation warning',
    { skip: process.platform === 'win32' },
    () => {
      // 1. Default install: zero MCP servers placed (0 token tax)
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
      assert.equal(fs.existsSync(path.join(defaultRoot, 'mcp')), false, 'Default install must not place MCP servers');
      assert.match(resDefault.stdout, /--with-mcp/);

      // 2. --with-mcp: places ONLY single sdd-forge-mcp v2
      const withMcpRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-optin-withmcp-'));
      const resWithMcp = spawnSync(
        'bash',
        [
          path.join(REPO_ROOT, 'install.sh'),
          '--source-directory',
          REPO_ROOT,
          '--install-root',
          withMcpRoot,
          '--target',
          'FilesOnly',
          '--with-mcp',
          '--skip-agent-install',
        ],
        { cwd: REPO_ROOT, encoding: 'utf8' },
      );
      assert.equal(resWithMcp.status, 0, resWithMcp.stderr);
      assert.equal(fs.existsSync(path.join(withMcpRoot, 'mcp/sdd-forge-mcp/dist/index.js')), true);
      assert.equal(fs.existsSync(path.join(withMcpRoot, 'mcp/local-env-mcp')), false);
      assert.equal(fs.existsSync(path.join(withMcpRoot, 'mcp/ci-mcp')), false);

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
