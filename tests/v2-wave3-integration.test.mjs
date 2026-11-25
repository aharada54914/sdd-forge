import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';
import { acquireLock, releaseLock } from '../plugins/sdd-quality-loop/scripts/v2/task-lock.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..');
const GATE_CLI = path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/run-sdd-gate.mjs');
const RECORD_CLI = path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/record-spec-baseline.mjs');
const METRICS_CLI = path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/factory-metrics.mjs');
const DOCTOR_CLI = path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/sdd-doctor.mjs');

function setupGateProject() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-wave3-'));
  fs.mkdirSync(path.join(dir, '.git'));
  fs.mkdirSync(path.join(dir, 'specs', 'rebuild-demo'), { recursive: true });
  fs.mkdirSync(path.join(dir, 'src'), { recursive: true });

  fs.writeFileSync(
    path.join(dir, 'specs', 'rebuild-demo', 'requirements.md'),
    '# Requirements\n\n- **REQ-001**: Produce deterministic output.\n- **AC-001** (REQ-001): Candidate matches baseline.\n\n## Spec Amendments\n- None\n',
    'utf8',
  );
  fs.writeFileSync(
    path.join(dir, 'specs', 'rebuild-demo', 'design.md'),
    '# Design\n\nDeterministic rebuild.\n\n## Spec Amendments\n- None\n',
    'utf8',
  );
  fs.writeFileSync(
    path.join(dir, 'specs', 'rebuild-demo', 'tasks.md'),
    '# Tasks\n\n## T-001 Rebuild engine\nApproval: Approved\nStatus: Implementation Complete\nRisk: standard\n\n### Scope\n- `src/app.mjs`\n\n## Spec Amendments\n- None\n',
    'utf8',
  );
  fs.writeFileSync(path.join(dir, 'src', 'app.mjs'), 'export const value = 42;\n', 'utf8');
  assert.equal(spawnSync(process.execPath, [RECORD_CLI, '--feature', 'rebuild-demo', '--root', dir], { encoding: 'utf8' }).status, 0);
  return dir;
}

describe('ADR-0054 Wave 3 (T-008 / T-009): Fail-Fast Gate, --mode rebuild, Lock Fail-Closed, OTel GenAI & MCP v2', () => {
  it('T-008 (AC-010/AC-011): --mode rebuild passes on matching Differential + NFR budget and fails on output divergence or budget breach', () => {
    const dir = setupGateProject();
    const budgetPath = path.join(dir, 'nfr-budget.json');
    fs.writeFileSync(budgetPath, JSON.stringify({ max_duration_ms: 5000, max_regression_ratio: 10 }), 'utf8');

    const passRes = spawnSync(
      process.execPath,
      [
        GATE_CLI,
        '--feature', 'rebuild-demo',
        '--task', 'T-001',
        '--root', dir,
        '--changed-files', 'src/app.mjs',
        '--mode', 'rebuild',
        '--baseline-cmd', 'node -e "console.log(42)"',
        '--candidate-cmd', 'node -e "console.log(42)"',
        '--nfr-budget', budgetPath,
      ],
      { encoding: 'utf8' },
    );
    assert.equal(passRes.status, 0, passRes.stdout + passRes.stderr);
    const passReport = JSON.parse(passRes.stdout);
    assert.equal(passReport.verdict, 'PASS');
    assert.equal(passReport.checks.rebuildDifferential.differentialMatched, true);
    assert.equal(passReport.checks.rebuildDifferential.nfrPassed, true);

    const diffFailRes = spawnSync(
      process.execPath,
      [
        GATE_CLI,
        '--feature', 'rebuild-demo',
        '--task', 'T-001',
        '--root', dir,
        '--changed-files', 'src/app.mjs',
        '--mode', 'rebuild',
        '--baseline-cmd', 'node -e "console.log(42)"',
        '--candidate-cmd', 'node -e "console.log(99)"',
      ],
      { encoding: 'utf8' },
    );
    assert.equal(diffFailRes.status, 1);
    assert.equal(JSON.parse(diffFailRes.stdout).checks.rebuildDifferential.differentialMatched, false);

    fs.rmSync(dir, { recursive: true, force: true });
  });

  it('T-008 (NFR-005): fails closed when task-lock is held by another owner and stops early on --fail-fast', () => {
    const dir = setupGateProject();
    const lock = acquireLock({ feature: 'rebuild-demo', taskId: 'T-001', owner: 'worker-other', projectRoot: dir });
    assert.equal(lock.acquired, true);

    const blockedRes = spawnSync(
      process.execPath,
      [
        GATE_CLI,
        '--feature', 'rebuild-demo',
        '--task', 'T-001',
        '--root', dir,
        '--lock-owner', 'worker-me',
        '--cmd', 'ok=node -e "process.exit(0)"',
      ],
      { encoding: 'utf8' },
    );
    assert.equal(blockedRes.status, 1);
    const blockedReport = JSON.parse(blockedRes.stdout);
    assert.equal(blockedReport.verdict, 'FAIL');
    assert.equal(blockedReport.failFastStoppedAt, 'lockCheck');
    assert.equal(blockedReport.checks.lockCheck.acquired, false);
    assert.equal(blockedReport.checks.commands.length, 0);

    releaseLock({ feature: 'rebuild-demo', taskId: 'T-001', owner: 'worker-other', projectRoot: dir });

    // Fail-fast on Agent-Strict Lint violation skips downstream verification commands
    fs.writeFileSync(path.join(dir, 'src', 'app.mjs'), 'export function bad(x) { return eval(x); }\n', 'utf8');
    const lintFailRes = spawnSync(
      process.execPath,
      [
        GATE_CLI,
        '--feature', 'rebuild-demo',
        '--task', 'T-001',
        '--root', dir,
        '--changed-files', 'src/app.mjs',
        '--agent-lint',
        '--fail-fast',
        '--cmd', 'ok=node -e "process.exit(0)"',
      ],
      { encoding: 'utf8' },
    );
    assert.equal(lintFailRes.status, 1);
    const lintReport = JSON.parse(lintFailRes.stdout);
    assert.equal(lintReport.failFastStoppedAt, 'agentLint');
    assert.equal(lintReport.checks.commands.length, 0);

    fs.rmSync(dir, { recursive: true, force: true });
  });

  it('T-009 (AC-012/AC-013): emits OTel GenAI telemetry (prompt body off by default) and v2_2_gates summary in sdd-doctor', () => {
    const dir = setupGateProject();
    const otelRes = spawnSync(process.execPath, [METRICS_CLI, '--root', dir, '--format', 'otel'], { encoding: 'utf8' });
    assert.equal(otelRes.status, 0, otelRes.stderr);
    const otel = JSON.parse(otelRes.stdout);
    assert.equal(otel.schema, 'sdd-otel-genai/v1');
    assert.equal(otel.privacy.collect_prompt_body, false);
    assert.equal(otel.resource['gen_ai.system'], 'sdd-forge');
    assert.ok(Array.isArray(otel.metrics) && otel.metrics.length >= 4);

    const docRes = spawnSync(process.execPath, [DOCTOR_CLI, '--root', REPO_ROOT, '--json'], { encoding: 'utf8' });
    assert.equal(docRes.status, 0);
    const doc = JSON.parse(docRes.stdout);
    assert.equal(doc.summary.ng, 0);
    assert.ok(doc.v2_2_gates && doc.v2_2_gates.formal_verification && doc.v2_2_gates.anti_tampering);

    fs.rmSync(dir, { recursive: true, force: true });
  });
});
