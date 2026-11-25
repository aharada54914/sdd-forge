import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { describe, it } from 'node:test';
import { fileURLToPath, pathToFileURL } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..');

const SOFT_GUARD = path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/sdd-soft-guard.mjs');
const DECISION_VIEW = path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/render-decision-view.mjs');
const TRACEABILITY = path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/check-traceability.mjs');
const TASK_LOCK = path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/task-lock.mjs');
const FACTORY_METRICS = path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/factory-metrics.mjs');
const SYNC_KNOWLEDGE = path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/sync-knowledge.mjs');
const GATE_SCRIPT = path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/run-sdd-gate.mjs');
const BASELINE_SCRIPT = path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/record-spec-baseline.mjs');
const SESSION_START = path.join(REPO_ROOT, 'plugins/sdd-implementation/scripts/session-model-start.py');


describe('#840/#843 factory metrics semantics', () => {
  it('separates guard auto-denials from human interventions and counts only real OQ blocks', async () => {
    const { summarizeFactoryMetrics } = await import(
      pathToFileURL(path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/factory-metrics.mjs')).href
    );
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-metrics-semantics-'));
    fs.mkdirSync(path.join(dir, '.sdd'), { recursive: true });
    fs.writeFileSync(path.join(dir, 'AGENTS.md'), '# test\n');
    const metrics = [
      // standard-risk run failing a test while an OQ is open: not an OQ block
      { feature: 'f', taskId: 'T-001', risk: 'standard', verdict: 'FAIL', provisionalOqCount: 1, provisionalOqBlocking: false },
      // OQ check itself stopped the run
      { feature: 'f', taskId: 'T-002', risk: 'high', verdict: 'FAIL', provisionalOqCount: 1, provisionalOqBlocking: true },
      // legacy records without provisionalOqBlocking: before #824 the gate blocked
      // only on exactly `high`, so legacy `critical` never stopped on OQs
      { feature: 'f', taskId: 'T-003', risk: 'standard', verdict: 'FAIL', provisionalOqCount: 2 },
      { feature: 'f', taskId: 'T-004', risk: 'critical', verdict: 'FAIL', provisionalOqCount: 1 },
      { feature: 'f', taskId: 'T-005', risk: 'high', verdict: 'FAIL', provisionalOqCount: 1 },
      { kind: 'attribution', feature: 'f', taskId: 'T-002', rootCausePhase: 'requirements', humanIntervention: true },
    ];
    const drift = [
      { feature: 'f', action: 'confirm_soft_deny' },
      { feature: 'f', action: 'strict_deny' },
      { feature: 'f', action: 'allow_override' },
    ];
    fs.writeFileSync(path.join(dir, '.sdd', 'factory-metrics.jsonl'), metrics.map((m) => JSON.stringify(m)).join('\n') + '\n');
    fs.writeFileSync(path.join(dir, '.sdd', 'drift-events.jsonl'), drift.map((m) => JSON.stringify(m)).join('\n') + '\n');
    const summary = summarizeFactoryMetrics({ projectRoot: dir });
    assert.equal(summary.guardAutoDenials, 2);
    assert.equal(summary.humanInterventions, 2, 'one explicit attribution + one spec-edit override');
    assert.equal(summary.driftEvents.override, 1);
    assert.equal(summary.gateRuns.provisionalOqBlocks, 2, 'T-002 (recorded) + T-005 (legacy high); legacy critical did not block');
    assert.equal(summary.finalReviews.passRate, null, 'no final verdicts recorded: no rate, never the mechanical one');
  });

  it('#838: per-attempt breakdown survives execution.json overwrites', async () => {
    const { summarizeFactoryMetrics } = await import(
      pathToFileURL(path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/factory-metrics.mjs')).href
    );
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-metrics-attempts-'));
    fs.mkdirSync(path.join(dir, '.sdd'), { recursive: true });
    const runs = [
      { feature: 'f', taskId: 'T-001', timestamp: '2026-01-01T00:00:00Z', verdict: 'FAIL', placeholderFindingCount: 2, failedCommandCount: 0 },
      { feature: 'f', taskId: 'T-001', timestamp: '2026-01-01T01:00:00Z', verdict: 'PASS', placeholderFindingCount: 0, failedCommandCount: 0 },
      { feature: 'f', taskId: 'T-002', timestamp: '2026-01-01T02:00:00Z', verdict: 'PASS', placeholderFindingCount: 0 },
    ];
    fs.writeFileSync(path.join(dir, '.sdd', 'factory-metrics.jsonl'), runs.map((m) => JSON.stringify(m)).join('\n') + '\n');
    const summary = summarizeFactoryMetrics({ projectRoot: dir });
    assert.equal(summary.gateRuns.placeholderFindingsTotal, 2);
    assert.equal(summary.gateRuns.retriedTasks, 1);
    const t1 = summary.attemptsByTask['f/T-001'];
    assert.deepEqual([t1.attempts, t1.failures], [2, 1]);
    assert.deepEqual(t1.history.map((h) => [h.verdict, h.placeholderFindingCount]), [['FAIL', 2], ['PASS', 0]]);
    fs.rmSync(dir, { recursive: true, force: true });
  });

  it('#844: one failed attempt is attributed once even when recorded by gate and afterwards', async () => {
    const { summarizeFactoryMetrics, recordRootCauseAttribution } = await import(
      pathToFileURL(path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/factory-metrics.mjs')).href
    );
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-metrics-attr-'));
    fs.mkdirSync(path.join(dir, '.sdd'), { recursive: true });
    const runs = [
      { runId: 'run-a', feature: 'f', taskId: 'T-001', verdict: 'FAIL', rootCausePhase: 'code' },
      { runId: 'run-b', feature: 'f', taskId: 'T-001', verdict: 'FAIL' },
    ];
    fs.writeFileSync(path.join(dir, '.sdd', 'factory-metrics.jsonl'), runs.map((m) => JSON.stringify(m)).join('\n') + '\n');
    // same attempt recorded again afterwards (sdd-gate + ship): counted once, latest phase wins
    recordRootCauseAttribution({ projectRoot: dir, feature: 'f', taskId: 'T-001', rootCause: 'test', runId: 'run-a' });
    // a different attempt with the same cause stays a separate attribution
    recordRootCauseAttribution({ projectRoot: dir, feature: 'f', taskId: 'T-001', rootCause: 'test', runId: 'run-b' });
    // legacy record without runId is still counted
    recordRootCauseAttribution({ projectRoot: dir, feature: 'f', taskId: 'T-002', rootCause: 'design' });
    // re-recording the same run's human correction is still one intervention
    recordRootCauseAttribution({ projectRoot: dir, feature: 'f', taskId: 'T-001', rootCause: 'test', runId: 'run-b', humanIntervention: true });
    recordRootCauseAttribution({ projectRoot: dir, feature: 'f', taskId: 'T-001', rootCause: 'test', runId: 'run-b', humanIntervention: true });
    const summary = summarizeFactoryMetrics({ projectRoot: dir });
    const b = summary.rootCauseBreakdown;
    assert.deepEqual([b.code, b.test, b.design], [0, 2, 1]);
    assert.equal(summary.humanInterventions, 1);
    fs.rmSync(dir, { recursive: true, force: true });
  });

  it('#837: final independent verdicts are summarized apart from mechanical gate PASS', async () => {
    const { summarizeFactoryMetrics, recordFinalVerdict } = await import(
      pathToFileURL(path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/factory-metrics.mjs')).href
    );
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-metrics-final-'));
    fs.mkdirSync(path.join(dir, '.sdd'), { recursive: true });
    const runs = [
      { feature: 'f', taskId: 'T-001', risk: 'standard', verdict: 'PASS' },
      { feature: 'f', taskId: 'T-002', risk: 'standard', verdict: 'PASS' },
    ];
    fs.writeFileSync(path.join(dir, '.sdd', 'factory-metrics.jsonl'), runs.map((m) => JSON.stringify(m)).join('\n') + '\n');
    recordFinalVerdict({ projectRoot: dir, feature: 'f', taskId: 'T-001', verdict: 'FAIL' });
    recordFinalVerdict({ projectRoot: dir, feature: 'f', taskId: 'T-002', verdict: 'pass' });
    assert.throws(() => recordFinalVerdict({ projectRoot: dir, feature: 'f', taskId: 'T-003', verdict: 'MAYBE' }));
    const summary = summarizeFactoryMetrics({ projectRoot: dir });
    assert.deepEqual([summary.gateRuns.total, summary.gateRuns.pass, summary.gateRuns.passRate], [2, 2, 100]);
    assert.deepEqual(summary.finalReviews, { total: 2, pass: 1, fail: 1, passRate: 50 });
    fs.rmSync(dir, { recursive: true, force: true });
    fs.rmSync(dir, { recursive: true, force: true });
  });
});

describe('Antigravity CLI (agy) native support & Software Factory v2.1 (F-1..F-8)', () => {
  it('ships valid .antigravity-plugin/plugin.json for all 8 plugins and root hooks.json for hook-bearing plugins', () => {
    const plugins = fs
      .readdirSync(path.join(REPO_ROOT, 'plugins'), { withFileTypes: true })
      .filter((d) => d.isDirectory())
      .map((d) => d.name)
      .sort();
    assert.equal(plugins.length, 8);

    for (const p of plugins) {
      const manifestPath = path.join(REPO_ROOT, 'plugins', p, '.antigravity-plugin', 'plugin.json');
      assert.equal(fs.existsSync(manifestPath), true, `Missing ${manifestPath}`);
      const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
      assert.equal(manifest.name, p);
      assert.match(manifest.version, /^\d+\.\d+\.\d+$/);
    }

    const qHooks = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, 'plugins/sdd-quality-loop/hooks.json'), 'utf8'));
    assert.equal(qHooks['sdd-soft-guard']?.PreToolUse?.[0]?.matcher, '*', 'Antigravity PreToolUse must use wildcard matcher so AGENT_STOP blocks run_command (NEW-H1)');
    assert.ok(qHooks['sdd-soft-guard']?.PreToolUse?.[0]?.hooks?.[0]?.command.includes('--emit antigravity'));
    const iHooks = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, 'plugins/sdd-implementation/hooks.json'), 'utf8'));
    assert.ok(iHooks['sdd-session-models']?.SessionStart?.[0]?.command.includes('--host antigravity-cli'));

    // H-5: Gemini sdd-bootstrap command exists & Codex Windows hook has CODEX_PLUGIN_ROOT fallback
    assert.equal(
      fs.existsSync(path.join(REPO_ROOT, 'plugins/sdd-bootstrap/gemini/commands/sdd-bootstrap/bootstrap.toml')),
      true,
    );
    const codexHooks = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, 'plugins/sdd-quality-loop/hooks/codex-hooks.json'), 'utf8'));
    assert.match(codexHooks.hooks.PreToolUse[0].hooks[0].command_windows, /CODEX_PLUGIN_ROOT/);
  });

  it('sdd-soft-guard.mjs --emit antigravity enforces approval & approved-spec guards and handles nested non-git SDD subprojects (M-7)', () => {
    const parentRepo = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-agy-guard-'));
    fs.mkdirSync(path.join(parentRepo, '.git'), { recursive: true });
    const childSub = path.join(parentRepo, 'packages', 'subapp');
    fs.mkdirSync(path.join(childSub, 'sdd'), { recursive: true });
    fs.mkdirSync(path.join(childSub, 'specs', 'feat1'), { recursive: true });
    fs.writeFileSync(path.join(childSub, 'sdd', 'guardrails.yaml'), 'spec_guard:\n  mode: strict\n', 'utf8');
    const tasksPath = path.join(childSub, 'specs', 'feat1', 'tasks.md');
    fs.writeFileSync(
      tasksPath,
      '# Tasks\n\n## T-001 Demo\nApproval: Draft\nStatus: Planned\nRisk: standard\n',
      'utf8',
    );

    // 1. Antigravity edit_file trying to add Approval: Approved -> deny
    const denyApproval = spawnSync(process.execPath, [SOFT_GUARD, '--emit', 'antigravity'], {
      input: JSON.stringify({
        toolCall: {
          id: 't1',
          name: 'edit_file',
          args: { Path: tasksPath, Target: 'Approval: Draft', Replacement: 'Approval: Approved' },
        },
        workspacePaths: [parentRepo],
        hookEventName: 'PreToolUse',
      }),
      encoding: 'utf8',
    });
    assert.equal(denyApproval.status, 0);
    assert.equal(JSON.parse(denyApproval.stdout).decision, 'deny');

    // 2. M-7: Approved spec in child non-git subproject with strict mode -> deny even with Spec Amendments
    fs.writeFileSync(
      tasksPath,
      '# Tasks\n\n## T-001 Demo\nApproval: Approved\nStatus: Planned\nRisk: standard\n',
      'utf8',
    );
    const reqPath = path.join(childSub, 'specs', 'feat1', 'requirements.md');
    fs.writeFileSync(reqPath, '# Req\n- **REQ-001**: Original\n\n## Spec Amendments\n- （初期版のため変更なし）\n', 'utf8');
    const denyStrict = spawnSync(process.execPath, [SOFT_GUARD, '--emit', 'antigravity'], {
      input: JSON.stringify({
        toolCall: {
          id: 't2',
          name: 'write_file',
          args: {
            Path: reqPath,
            Content: '# Req\n- **REQ-001**: Changed\n\n## Spec Amendments\n- 2026-11-22: Reason\n',
            Overwrite: true,
          },
        },
        cwd: parentRepo,
        hookEventName: 'PreToolUse',
      }),
      encoding: 'utf8',
    });
    assert.equal(denyStrict.status, 0);
    assert.equal(JSON.parse(denyStrict.stdout).decision, 'deny');

    // 3. Antigravity run_command passes through cleanly
    const allowCmd = spawnSync(process.execPath, [SOFT_GUARD, '--emit', 'antigravity'], {
      input: JSON.stringify({
        toolCall: { id: 't3', name: 'run_command', args: { CommandLine: 'npm test' } },
        cwd: parentRepo,
        hookEventName: 'PreToolUse',
      }),
      encoding: 'utf8',
    });
    assert.equal(allowCmd.status, 0);
    assert.equal(JSON.parse(allowCmd.stdout).decision, 'allow');
  });

  it('session-model-start.py --host antigravity-cli emits Antigravity injectSteps and model-discovery.py parses agy models', () => {
    const py = process.platform === 'win32' ? 'python' : 'python3';
    const startRes = spawnSync(
      py,
      [SESSION_START, '--host', 'antigravity-cli'],
      {
        input: JSON.stringify({ conversationId: 'conv-123', source: 'startup' }),
        encoding: 'utf8',
      },
    );
    assert.equal(startRes.status, 0, startRes.stderr);
    const startJson = JSON.parse(startRes.stdout);
    assert.ok(Array.isArray(startJson.injectSteps));
    assert.match(startJson.injectSteps[0].systemMessage.systemMessage, /antigravity-cli/);
    assert.match(startJson.injectSteps[0].systemMessage.systemMessage, /conv-123/);

    // Verify model-discovery.py antigravity parser & M-7 claude firstParty/non-string type checks
    const pyCheck = spawnSync(
      py,
      [
        '-c',
        `
import importlib.util, io, os, stat, tempfile
from pathlib import Path
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('md', ${JSON.stringify(
          path.join(REPO_ROOT, 'plugins/sdd-implementation/scripts/model-discovery.py'),
        )})
md = importlib.util.module_from_spec(spec)
spec.loader.exec_module(md)

assert 'antigravity-cli' in md.HOSTS and md.HOSTS['antigravity-cli'] == 'agy'
assert md._nonempty_str('pro') is True
assert md._nonempty_str(False) is False
assert md._nonempty_str(0) is False
assert md._nonempty_str('') is False
assert md._nonempty_str('none') is False

sample_out = '\\r\\u280b Fetching available models...\\ngemini-4-neon-xhigh              Gemini 4 Neon (XHigh)\\nclaude-opus-5-5-high            Claude Opus 5.5 (High)\\n'
with tempfile.TemporaryDirectory() as td:
    if os.name == 'nt':
        class FakeProc:
            def __init__(self, *a, **kw):
                self.pid = 1
                self.stdout = io.BytesIO(sample_out.encode('utf-8'))
                self.returncode = 0
            def wait(self, timeout=None):
                return 0
            def poll(self):
                return 0
            def kill(self):
                pass
        with patch.object(md.subprocess, 'Popen', FakeProc):
            rows, auth = md.antigravity('agy', td)
    else:
        fake_agy = Path(td) / 'agy'
        fake_agy.write_text('#!/bin/sh\\nprintf "%b" ' + repr(sample_out) + '\\n', encoding='utf-8')
        fake_agy.chmod(0o755)
        rows, auth = md.antigravity(str(fake_agy), td)
    assert auth == 'cli-managed'
    assert [r['model'] for r in rows] == ['gemini-4-neon-xhigh', 'claude-opus-5-5-high']
    assert rows[0]['host'] == 'antigravity-cli'
    assert rows[0]['display_name'] == 'Gemini 4 Neon (XHigh)'
print('OK')
`,
      ],
      { encoding: 'utf8' },
    );
    assert.equal(pyCheck.status, 0, pyCheck.stderr);
    assert.match(pyCheck.stdout, /OK/);
  });

  it('implements Software Factory F-1 (perspective matrix), F-2 (atomic lock & batch planner), F-3 (source line refs), F-4 (metrics & root cause), F-5 (code/test trace & SQL advisory), and F-6 (knowledge init/extract)', () => {
    const repo = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-factory-v21-'));
    fs.mkdirSync(path.join(repo, '.git'), { recursive: true });
    fs.mkdirSync(path.join(repo, 'specs', 'orders'), { recursive: true });
    fs.mkdirSync(path.join(repo, 'src'), { recursive: true });
    fs.mkdirSync(path.join(repo, 'tests'), { recursive: true });
    fs.mkdirSync(path.join(repo, 'db'), { recursive: true });

    // F-6: init knowledge base (idempotent, never overwrites)
    const initOut = JSON.parse(
      execFileSync(process.execPath, [SYNC_KNOWLEDGE, 'init', '--root', repo], { encoding: 'utf8' }),
    );
    assert.ok(initOut.created.includes('sdd/knowledge/INDEX.md'));
    assert.ok(initOut.created.includes('sdd/knowledge/review-perspectives.yaml'));
    const initAgain = JSON.parse(
      execFileSync(process.execPath, [SYNC_KNOWLEDGE, 'init', '--root', repo], { encoding: 'utf8' }),
    );
    assert.equal(initAgain.created.length, 0);

    // Populate specs with OQ-NNN, Alternatives Rejected, parallel + conflicting tasks
    fs.writeFileSync(
      path.join(repo, 'specs', 'orders', 'requirements.md'),
      [
        '# 要件: orders',
        '- **REQ-001**: Create order',
        '- **REQ-002**: Cancel order',
        '- **AC-001** (REQ-001): POST /orders returns 201',
        '- **AC-002** (REQ-002): DELETE /orders/:id returns 204',
        '',
        '## Open Questions',
        '| ID | 分類 | 設計した事実 | 理由 | 問い | 状態 | 影響タスク |',
        '|---|---|---|---|---|---|---|',
        '| OQ-001 | 事業判断 | キャンセル後は論理削除 | 監査要件 | 論理削除でよいか | Confirmed | T-001 |',
        '',
        '## Spec Amendments',
        '- 2026-11-22: 監査要件に合わせ論理削除へ統一',
        '',
      ].join('\n'),
      'utf8',
    );
    fs.writeFileSync(
      path.join(repo, 'specs', 'orders', 'design.md'),
      [
        '# 設計: orders',
        '',
        '## 採らなかった設計（Alternatives Rejected）',
        '| 候補案 | 不採用理由 | 再検討条件 |',
        '|---|---|---|',
        '| 物理削除 | 監査証跡が消えるため | 法令要件変更時 |',
        '',
        '## Spec Amendments',
        '- （初期版のため変更なし）',
        '',
      ].join('\n'),
      'utf8',
    );
    fs.writeFileSync(
      path.join(repo, 'specs', 'orders', 'tasks.md'),
      [
        '# タスク: orders',
        '',
        '## T-001 Create order API',
        'Approval: Approved',
        'Status: Implementation Complete',
        'Risk: standard',
        '### Scope',
        '- `src/orders.mjs`',
        '- `tests/orders.test.mjs`',
        '### Done When',
        '- AC-001 passes',
        '### Blockers',
        '- None',
        '',
        '## T-002 Cancel order API',
        'Approval: Approved',
        'Status: Planned',
        'Risk: standard',
        '### Scope',
        '- `src/orders.mjs`',
        '### Done When',
        '- AC-002 passes',
        '### Blockers',
        '- None',
        '',
        '## T-003 Independent telemetry',
        'Approval: Approved',
        'Status: Planned',
        'Risk: low',
        '### Scope',
        '- `src/telemetry.mjs`',
        '### Done When',
        '- AC-001 passes',
        '### Blockers',
        '- None',
        '',
      ].join('\n'),
      'utf8',
    );
    fs.writeFileSync(path.join(repo, 'src', 'orders.mjs'), 'export const createOrder = () => true;\n', 'utf8');
    fs.writeFileSync(path.join(repo, 'tests', 'orders.test.mjs'), 'export const ok = true;\n', 'utf8');
    fs.writeFileSync(path.join(repo, 'db', 'query.sql'), 'SELECT * FROM orders;\n', 'utf8');

    // F-1 + F-3: Decision View MD & HTML contain source file:line, traceability table, and 8 common + product perspectives
    const dvMd = execFileSync(process.execPath, [DECISION_VIEW, '--feature', 'orders', '--root', repo, '--format', 'markdown'], {
      encoding: 'utf8',
    });
    assert.match(dvMd, /specs\/orders\/requirements\.md:L10/);
    assert.match(dvMd, /specs\/orders\/design\.md:L6/);
    assert.match(dvMd, /レビュー観点と今回の採否・理由/);
    assert.match(dvMd, /\| C01 \|/);
    assert.match(dvMd, /\| P01 \|/);

    const dvHtml = execFileSync(process.execPath, [DECISION_VIEW, '--feature', 'orders', '--root', repo, '--format', 'html'], {
      encoding: 'utf8',
    });
    assert.match(dvHtml, /レビュー観点と今回の採否・理由/);
    assert.match(dvHtml, /specs\/orders\/requirements\.md:L10/);
    assert.match(dvHtml, /P01/);

    // F-2 + F-5: Traceability detects T-001 vs T-002 Scope overlap on src/orders.mjs, plans 2 waves, and maps Code/Test scopes
    const trace = JSON.parse(
      execFileSync(process.execPath, [TRACEABILITY, '--feature', 'orders', '--root', repo, '--plan-batches'], {
        encoding: 'utf8',
      }),
    );
    assert.equal(trace.complete, true);
    assert.equal(trace.executionPlan.scopeConflicts.length, 1);
    assert.deepEqual(trace.executionPlan.batches, [['T-001', 'T-003'], ['T-002']]);
    const ac1Cov = trace.acCodeTestCoverage.find((c) => c.ac === 'AC-001');
    assert.equal(ac1Cov.hasCodeScope, true);
    assert.equal(ac1Cov.hasTestScope, true);

    // F-2: task-lock.mjs atomic lock blocks duplicate acquire and releases cleanly
    const lock1 = spawnSync(process.execPath, [TASK_LOCK, 'acquire', '--feature', 'orders', '--root', repo, '--owner', 'worker-a'], {
      encoding: 'utf8',
    });
    assert.equal(lock1.status, 0);
    const lock2 = spawnSync(process.execPath, [TASK_LOCK, 'acquire', '--feature', 'orders', '--root', repo, '--owner', 'worker-b'], {
      encoding: 'utf8',
    });
    assert.equal(lock2.status, 1);
    const rel = spawnSync(process.execPath, [TASK_LOCK, 'release', '--feature', 'orders', '--root', repo, '--owner', 'worker-a'], {
      encoding: 'utf8',
    });
    assert.equal(rel.status, 0);

    // F-4 + F-5: run-sdd-gate emits advisory SQL_SELECT_STAR without false-failing + records metrics & root-cause attribution
    execFileSync(process.execPath, [BASELINE_SCRIPT, '--feature', 'orders', '--root', repo], { encoding: 'utf8' });
    const gateOut = JSON.parse(
      execFileSync(
        process.execPath,
        [GATE_SCRIPT, '--feature', 'orders', '--task', 'T-001', '--root', repo, '--changed-files', 'db/query.sql'],
        { encoding: 'utf8' },
      ),
    );
    assert.equal(gateOut.verdict, 'PASS');
    assert.equal(gateOut.checks.nonFunctionalSensors.advisoryFindings.some((f) => f.rule === 'SQL_SELECT_STAR'), true);

    execFileSync(
      process.execPath,
      [
        FACTORY_METRICS,
        'record-attribution',
        '--feature',
        'orders',
        '--task',
        'T-001',
        '--root-cause',
        'requirements',
        '--human-intervention',
        '--note',
        'Missing delete semantics in initial REQ',
        '--root',
        repo,
      ],
      { encoding: 'utf8' },
    );
    const metricsSummary = JSON.parse(
      execFileSync(process.execPath, [FACTORY_METRICS, '--root', repo, '--feature', 'orders'], { encoding: 'utf8' }),
    );
    assert.equal(metricsSummary.gateRuns.pass, 1);
    assert.equal(metricsSummary.rootCauseBreakdown.requirements, 1);
    assert.equal(metricsSummary.humanInterventions, 1);

    // F-6: sync-knowledge extract writes sourced knowledge summary
    const syncOut = JSON.parse(
      execFileSync(process.execPath, [SYNC_KNOWLEDGE, 'extract', '--feature', 'orders', '--root', repo, '--write'], {
        encoding: 'utf8',
      }),
    );
    assert.equal(syncOut.writtenPath, 'sdd/knowledge/specs/orders.md');
    const syncedMd = fs.readFileSync(path.join(repo, syncOut.writtenPath), 'utf8');
    assert.match(syncedMd, /OQ-001/);
    assert.match(syncedMd, /物理削除/);
    assert.match(syncedMd, /監査要件に合わせ論理削除へ統一/);
  });

  it(
    'install.sh & uninstall.sh register and cleanly remove Antigravity MCP config via SDD_ANTIGRAVITY_CONFIG_DIR',
    { skip: process.platform === 'win32' },
    () => {
      const installRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-agy-inst-'));
      const fakeAgyCfg = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-agy-cfg-'));
      // Seed stale local-env-mcp entry pointing into installRoot to verify C-4 upgrade pruning
      fs.writeFileSync(
        path.join(fakeAgyCfg, 'mcp_config.json'),
        JSON.stringify(
          {
            mcpServers: {
              'local-env-mcp': { command: 'node', args: [path.join(installRoot, 'mcp/local-env-mcp/dist/index.js')] },
              'user-custom': { command: 'echo', args: ['keep'] },
            },
          },
          null,
          2,
        ),
        'utf8',
      );

      const resInst = spawnSync(
        'bash',
        [
          path.join(REPO_ROOT, 'install.sh'),
          '--source-directory',
          REPO_ROOT,
          '--install-root',
          installRoot,
          '--target',
          'Antigravity',
          '--skip-plugin-install',
          '--with-mcp',
        ],
        { cwd: REPO_ROOT, encoding: 'utf8', env: { ...process.env, SDD_ANTIGRAVITY_CONFIG_DIR: fakeAgyCfg } },
      );
      assert.equal(resInst.status, 0, resInst.stderr);
      const cfgAfterInst = JSON.parse(fs.readFileSync(path.join(fakeAgyCfg, 'mcp_config.json'), 'utf8'));
      assert.ok(cfgAfterInst.mcpServers['sdd-forge-mcp']);
      assert.equal('local-env-mcp' in cfgAfterInst.mcpServers, false, 'Stale unselected local-env-mcp must be pruned on upgrade (C-4)');
      assert.ok(cfgAfterInst.mcpServers['user-custom'], 'Unrelated user MCP entries must be preserved');

      const resUninst = spawnSync(
        'bash',
        [
          path.join(REPO_ROOT, 'uninstall.sh'),
          '--install-root',
          installRoot,
          '--target',
          'Antigravity',
          '--skip-plugin-uninstall',
        ],
        { cwd: REPO_ROOT, encoding: 'utf8', env: { ...process.env, SDD_ANTIGRAVITY_CONFIG_DIR: fakeAgyCfg } },
      );
      assert.equal(resUninst.status, 0, resUninst.stderr);
      const cfgAfterUninst = JSON.parse(fs.readFileSync(path.join(fakeAgyCfg, 'mcp_config.json'), 'utf8'));
      assert.equal('sdd-forge-mcp' in cfgAfterUninst.mcpServers, false);
      assert.ok(cfgAfterUninst.mcpServers['user-custom']);
    },
  );

  it('NEW-H1/H2/H3/H5/M1/M3/L3: XHigh re-audit regression suite (global edit_file, line-scoped replace, baseline root isolation, task-lock owner/reclaim, empty SessionStart, transitive blockers, knowledge preservation)', () => {
    const repo = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-xhigh-reg-'));
    const otherRepo = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-xhigh-other-'));
    fs.mkdirSync(path.join(repo, 'specs', 'f1'), { recursive: true });
    fs.mkdirSync(path.join(otherRepo, 'specs', 'f1'), { recursive: true });
    fs.writeFileSync(
      path.join(repo, 'specs', 'f1', 'tasks.md'),
      [
        '# Tasks: f1',
        '## T-001 Base',
        'Approval: Approved',
        'Status: Planned',
        'Risk: standard',
        '### Scope',
        '- `src/a.mjs`',
        '### Done When',
        '- AC-001 passes',
        '### Blockers',
        '- None',
        '',
        '## T-002 Middle',
        'Approval: Approved',
        'Status: Planned',
        'Risk: standard',
        '### Scope',
        '- `src/b.mjs`',
        '### Done When',
        '- AC-001 passes',
        '### Blockers',
        '- T-001',
        '',
        '## T-003 Leaf',
        'Approval: Approved',
        'Status: Planned',
        'Risk: standard',
        '### Scope',
        '- `src/a.mjs`',
        '### Done When',
        '- AC-001 passes',
        '### Blockers',
        '- T-002',
        '',
      ].join('\n'),
      'utf8',
    );
    const reqPath = path.join(repo, 'specs', 'f1', 'requirements.md');
    fs.writeFileSync(
      reqPath,
      [
        '# Requirements: f1',
        '## Spec Amendments',
        '- 2026-11-22: note token-abc',
        '## Functional Requirements',
        '- REQ-001: preserve token-abc',
        '- AC-001: keep token-abc',
        '',
      ].join('\n'),
      'utf8',
    );

    // NEW-H3: record-spec-baseline.mjs ignores CLAUDE_PROJECT_DIR when --root is passed
    execFileSync(process.execPath, [BASELINE_SCRIPT, '--feature', 'f1', '--root', repo], {
      encoding: 'utf8',
      env: { ...process.env, CLAUDE_PROJECT_DIR: otherRepo },
    });
    assert.equal(fs.existsSync(path.join(repo, 'specs', 'f1', '.spec-baseline.json')), true);
    assert.equal(fs.existsSync(path.join(otherRepo, 'specs', 'f1', '.spec-baseline.json')), false);

    // NEW-H2a: Antigravity edit_file replaces ALL occurrences -> must DENY when token appears in both Amendments and protected body
    const editAllRes = spawnSync(process.execPath, [SOFT_GUARD, '--emit', 'antigravity'], {
      cwd: repo,
      encoding: 'utf8',
      input: JSON.stringify({
        workspacePaths: [repo],
        toolCall: {
          name: 'edit_file',
          args: { Path: reqPath, Target: 'token-abc', Replacement: 'token-evil' },
        },
      }),
    });
    assert.equal(JSON.parse(editAllRes.stdout).decision, 'deny', 'edit_file global replace must not bypass spec guard');

    // NEW-H2b: replace_file_content with StartLine/EndLine targeting body line 5 must DENY even though token-abc appears earlier in Amendments
    const lineScopedRes = spawnSync(process.execPath, [SOFT_GUARD, '--emit', 'antigravity'], {
      cwd: repo,
      encoding: 'utf8',
      input: JSON.stringify({
        workspacePaths: [repo],
        toolCall: {
          name: 'replace_file_content',
          args: { TargetFile: reqPath, TargetContent: 'token-abc', ReplacementContent: 'token-evil', StartLine: 5, EndLine: 6 },
        },
      }),
    });
    assert.equal(JSON.parse(lineScopedRes.stdout).decision, 'deny', 'line-scoped replace_file_content targeting protected body must deny');

    // NEW-H1: AGENT_STOP blocks Antigravity run_command
    fs.writeFileSync(path.join(repo, 'AGENT_STOP'), 'stop\n', 'utf8');
    const stopRes = spawnSync(process.execPath, [SOFT_GUARD, '--emit', 'antigravity'], {
      cwd: repo,
      encoding: 'utf8',
      input: JSON.stringify({
        workspacePaths: [repo],
        toolCall: { name: 'run_command', args: { CommandLine: 'rm -rf specs' } },
      }),
    });
    assert.equal(JSON.parse(stopRes.stdout).decision, 'deny');
    fs.unlinkSync(path.join(repo, 'AGENT_STOP'));

    // NEW-H5: task-lock release fails closed when --owner is omitted on an owned lock, and --break-stale atomically reclaims expired lock
    assert.equal(
      spawnSync(process.execPath, [TASK_LOCK, 'acquire', '--feature', 'f1', '--root', repo, '--owner', 'worker-1'], {
        encoding: 'utf8',
      }).status,
      0,
    );
    const unauthorizedRel = spawnSync(process.execPath, [TASK_LOCK, 'release', '--feature', 'f1', '--root', repo], {
      encoding: 'utf8',
    });
    assert.equal(unauthorizedRel.status, 1, 'release without --owner must fail closed on owned lock');
    assert.equal(
      spawnSync(process.execPath, [TASK_LOCK, 'release', '--feature', 'f1', '--root', repo, '--owner', 'worker-1'], {
        encoding: 'utf8',
      }).status,
      0,
    );
    // Write expired stale lock and reclaim via --break-stale
    fs.mkdirSync(path.join(repo, '.sdd', 'locks'), { recursive: true });
    fs.writeFileSync(
      path.join(repo, '.sdd', 'locks', 'f1.lock'),
      JSON.stringify({
        schema: 'sdd-task-lock/v1',
        feature: 'f1',
        owner: 'dead-worker',
        pid: 99999999,
        hostname: os.hostname(),
        acquiredAt: '2020-01-01T00:00:00Z',
        expiresAt: '2020-01-01T00:01:00Z',
      }),
      'utf8',
    );
    const reclaim = spawnSync(
      process.execPath,
      [TASK_LOCK, 'acquire', '--feature', 'f1', '--root', repo, '--owner', 'worker-2', '--break-stale'],
      { encoding: 'utf8' },
    );
    assert.equal(reclaim.status, 0, reclaim.stdout + reclaim.stderr);

    // NEW-M1: session-model-start.py emits {}\n on Antigravity suppression
    const py = process.platform === 'win32' ? 'python' : 'python3';
    const suppressed = spawnSync(py, [SESSION_START, '--host', 'antigravity-cli'], {
      cwd: repo,
      encoding: 'utf8',
      input: JSON.stringify({ source: 'resume' }),
    });
    assert.equal(suppressed.status, 0);
    assert.equal(suppressed.stdout.trim(), '{}');

    // NEW-M3: Transitive blocker chain (T-001 -> T-002 -> T-003) does NOT report false-positive scopeConflict between T-001 and T-003
    const plan = JSON.parse(
      execFileSync(process.execPath, [TRACEABILITY, '--feature', 'f1', '--root', repo, '--plan-batches'], {
        encoding: 'utf8',
      }),
    );
    assert.equal(plan.executionPlan.scopeConflicts.length, 0, 'Transitively serialized tasks must not report scopeConflicts');

    // NEW-L3: sync-knowledge.mjs --write preserves manual notes and updates sdd/knowledge/INDEX.md
    execFileSync(process.execPath, [SYNC_KNOWLEDGE, 'init', '--root', repo], { encoding: 'utf8' });
    const specKnowPath = path.join(repo, 'sdd', 'knowledge', 'specs', 'f1.md');
    fs.writeFileSync(specKnowPath, 'Team manual note: keep me safe.\n', 'utf8');
    execFileSync(process.execPath, [SYNC_KNOWLEDGE, 'extract', '--feature', 'f1', '--root', repo, '--write'], {
      encoding: 'utf8',
    });
    const mergedKnow = fs.readFileSync(specKnowPath, 'utf8');
    assert.match(mergedKnow, /Team manual note: keep me safe\./);
    assert.match(mergedKnow, /sdd-forge:knowledge-auto-start/);
    const idxMd = fs.readFileSync(path.join(repo, 'sdd', 'knowledge', 'INDEX.md'), 'utf8');
    assert.match(idxMd, /specs\/f1\.md/);
  });

  it('R3: factory-metrics.mjs scopes named-feature summaries with --feature and preserves project-wide totals without it', () => {
    const repo = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-metrics-scope-'));
    fs.mkdirSync(path.join(repo, '.sdd'), { recursive: true });
    fs.writeFileSync(
      path.join(repo, '.sdd', 'factory-metrics.jsonl'),
      `${[
        JSON.stringify({ feature: 'alpha', taskId: 'T-001', verdict: 'PASS', commandDurationMs: 100 }),
        JSON.stringify({ feature: 'beta', taskId: 'T-001', verdict: 'FAIL', commandDurationMs: 250 }),
        JSON.stringify({
          kind: 'attribution',
          feature: 'alpha',
          taskId: 'T-001',
          rootCausePhase: 'design',
          humanIntervention: true,
        }),
        JSON.stringify({
          kind: 'attribution',
          feature: 'beta',
          taskId: 'T-001',
          rootCausePhase: 'code',
          humanIntervention: false,
        }),
      ].join('\n')}\n`,
      'utf8',
    );
    fs.writeFileSync(
      path.join(repo, '.sdd', 'drift-events.jsonl'),
      `${[
        JSON.stringify({ feature: 'alpha', action: 'confirm_soft_deny' }),
        JSON.stringify({ feature: 'beta', action: 'warn_allow' }),
      ].join('\n')}\n`,
      'utf8',
    );

    const alphaJson = JSON.parse(
      execFileSync(process.execPath, [FACTORY_METRICS, '--root', repo, '--feature', 'alpha'], { encoding: 'utf8' }),
    );
    assert.equal(alphaJson.feature, 'alpha');
    assert.equal(alphaJson.gateRuns.total, 1);
    assert.equal(alphaJson.gateRuns.pass, 1);
    assert.equal(alphaJson.gateRuns.fail, 0);
    assert.equal(alphaJson.driftEvents.total, 1);
    assert.equal(alphaJson.driftEvents.deny, 1);
    assert.equal(alphaJson.rootCauseBreakdown.design, 1);
    assert.equal(alphaJson.rootCauseBreakdown.code, 0);
    // #840: the guard's automatic deny is not a human intervention.
    assert.equal(alphaJson.humanInterventions, 1);
    assert.equal(alphaJson.guardAutoDenials, 1);

    const alphaMd = execFileSync(
      process.execPath,
      [FACTORY_METRICS, '--root', repo, '--feature', 'alpha', '--format', 'markdown'],
      { encoding: 'utf8' },
    );
    assert.match(alphaMd, /^# Software Factory Metrics: alpha$/m);

    const allJson = JSON.parse(
      execFileSync(process.execPath, [FACTORY_METRICS, '--root', repo], { encoding: 'utf8' }),
    );
    assert.equal(allJson.feature, null);
    assert.equal(allJson.gateRuns.total, 2);
    assert.equal(allJson.gateRuns.pass, 1);
    assert.equal(allJson.gateRuns.fail, 1);
    assert.equal(allJson.driftEvents.total, 2);
    assert.equal(allJson.rootCauseBreakdown.design, 1);
    assert.equal(allJson.rootCauseBreakdown.code, 1);

    const allMd = execFileSync(
      process.execPath,
      [FACTORY_METRICS, '--root', repo, '--format', 'markdown'],
      { encoding: 'utf8' },
    );
    assert.match(allMd, /^# Software Factory Metrics$/m);
  });
});
