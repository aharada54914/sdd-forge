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

function git(dir, ...args) {
  const result = spawnSync('git', ['-c', 'user.name=Fixture', '-c', 'user.email=test@example.invalid', ...args], { cwd: dir, encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr);
}

function gate(dir, ...args) {
  const result = spawnSync(process.execPath, [GATE_CLI, '--root', dir, '--feature', 'rebuild-demo', '--task', 'T-001', ...args], { encoding: 'utf8' });
  assert.ok(result.stdout, result.stderr);
  return { code: result.status, checks: JSON.parse(result.stdout).checks, report: JSON.parse(result.stdout) };
}

function setupGateProject() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-wave3-'));
  git(dir, 'init', '-q');
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
  for (const rel of ['contracts/demo.json', 'tests/golden/result.txt', 'nfr-budget.json']) {
    fs.mkdirSync(path.dirname(path.join(dir, rel)), { recursive: true });
    fs.writeFileSync(path.join(dir, rel), rel === 'nfr-budget.json' ? '{"max_regression_ratio":10}' : 'fixture');
  }
  git(dir, 'add', '.');
  git(dir, 'commit', '-qm', 'fixture inputs');
  return dir;
}

describe('ADR-0054 Wave 3 (T-008 / T-009): Fail-Fast Gate, --mode rebuild, Lock Fail-Closed, OTel GenAI & MCP v2', () => {
  it('T-008 (AC-010/AC-011): --mode rebuild passes on matching Differential + NFR budget and fails on output divergence or budget breach', () => {
    const dir = setupGateProject();
    const budgetPath = path.join(dir, 'nfr-budget.json');

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
    const measured = passReport.checks.rebuildDifferential;
    assert.equal(measured.nfrPassed, true);
    for (const run of [measured.baseline, measured.candidate]) {
      assert.equal(run.samples, 20);
      assert.ok(run.p95Ms > 0);
    }

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

  it('T-008 rebuild rejects changed contracts, goldens and budget regardless of explicit selection', (t) => {
    const dir = setupGateProject();
    t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
    const expected = ['contracts/demo.json', 'nfr-budget.json', 'tests/golden/result.txt'];
    for (const rel of expected) fs.appendFileSync(path.join(dir, rel), ' ');
    const result = gate(dir, '--mode', 'rebuild', '--changed-files', 'src/app.mjs',
      '--baseline-cmd', 'node -v', '--candidate-cmd', 'node -v');
    assert.equal(result.code, 1);
    assert.deepEqual(result.checks.rebuildDifferential.immutablePaths, expected);
  });

  it('T-008 resolves the baseline command against the committed implementation', (t) => {
    const dir = setupGateProject();
    t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
    fs.writeFileSync(path.join(dir, 'src/app.mjs'), 'console.log("old")');
    git(dir, 'commit', '-qam', 'baseline version');
    fs.writeFileSync(path.join(dir, 'src/app.mjs'), 'console.log("new")');
    const result = gate(dir, '--mode', 'rebuild', '--baseline-cmd', 'node src/app.mjs', '--candidate-cmd', 'node src/app.mjs');
    assert.equal(result.code, 1);
    assert.equal(result.checks.rebuildDifferential.differentialMatched, false);
  });

  it('T-008 stops at the first failing verification command in fail-fast mode', (t) => {
    const dir = setupGateProject();
    t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
    const result = gate(dir, '--fail-fast', '--mode', 'rebuild',
      '--cmd', 'first=node -e "process.exit(1)"', '--cmd', 'second=node -v');
    assert.equal(result.code, 1);
    assert.equal(result.report.failFastStoppedAt, 'commands');
    assert.deepEqual(result.checks.commands.map(command => command.label), ['first']);
    assert.equal(result.checks.rebuildDifferential.skipped, true);
  });

  it('T-008 rebuild measures default p95 and absolute budgets independently from exact output', (t) => {
    const dir = setupGateProject();
    t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
    fs.writeFileSync(path.join(dir, 'nfr-budget.json'), '{}');
    git(dir, 'commit', '-qam', 'default budget');
    // Use the same JS output path on both sides. On Windows node -v and
    // console.log can emit different line endings, which is a real byte difference.
    const versionCommand = 'node -e "console.log(process.version)"';
    const rebuild = (...args) => gate(dir, '--mode', 'rebuild', '--baseline-cmd', versionCommand, ...args);
    const slow = rebuild('--candidate-cmd', 'node -e "setTimeout(() => console.log(process.version), 60)"');
    assert.equal(slow.code, 1);
    assert.equal(slow.checks.rebuildDifferential.differentialMatched, true);
    assert.equal(slow.checks.rebuildDifferential.nfrPassed, false);
    assert.match(slow.checks.rebuildDifferential.nfrViolations.join(' '), /1\.1/);
    fs.writeFileSync(path.join(dir, 'nfr-budget.json'), '{"max_duration_ms":0.1,"max_regression_ratio":10}');
    git(dir, 'commit', '-qam', 'absolute budget');
    const capped = rebuild('--candidate-cmd', versionCommand);
    assert.equal(capped.code, 1);
    assert.match(capped.checks.rebuildDifferential.nfrViolations.join(' '), /max_duration_ms/);
    const spaces = rebuild('--candidate-cmd', 'node -e "console.log(process.version + String.fromCharCode(32))"');
    assert.equal(spaces.checks.rebuildDifferential.differentialMatched, false);
    const failed = rebuild('--candidate-cmd', 'node -e "process.exitCode = 2"');
    assert.equal(failed.checks.rebuildDifferential.candidate.exitCode, 2);
    assert.equal(failed.checks.rebuildDifferential.differentialMatched, false);
  });

  it('T-008 rebuild rechecks immutable inputs after running the candidate', (t) => {
    const dir = setupGateProject();
    t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
    fs.writeFileSync(path.join(dir, 'candidate.cjs'), 'require("node:fs").appendFileSync("tests/golden/result.txt", "x"); console.log(process.version);');
    const result = gate(dir, '--mode', 'rebuild', '--baseline-cmd', 'node -v', '--candidate-cmd', 'node candidate.cjs');
    assert.equal(result.code, 1);
    assert.deepEqual(result.checks.rebuildDifferential.immutablePaths, ['tests/golden/result.txt']);
  });

  it('T-008 enforces implementer write scope through both public CLIs using the Git diff', (t) => {
    const dir = setupGateProject();
    t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
    const traceCli = path.join(path.dirname(GATE_CLI), 'check-traceability.mjs');
    const trace = () => spawnSync(process.execPath, [traceCli, '--root', dir, '--feature', 'rebuild-demo',
      '--role', 'implementer', '--base', 'HEAD', '--changed-files', 'src/app.mjs'], { encoding: 'utf8' });
    fs.appendFileSync(path.join(dir, 'src/app.mjs'), '// application change');
    assert.equal(trace().status, 0);
    fs.mkdirSync(path.join(dir, '.github/workflows'), { recursive: true });
    fs.writeFileSync(path.join(dir, '.github/workflows/check.yml'), 'name: current');
    fs.writeFileSync(path.join(dir, 'CODEOWNERS'), 'before');
    git(dir, 'add', '.');
    git(dir, 'commit', '-qm', 'protected inputs');
    fs.renameSync(path.join(dir, 'CODEOWNERS'), path.join(dir, 'old-owners'));
    fs.appendFileSync(path.join(dir, '.github/workflows/check.yml'), ' edited');
    fs.writeFileSync(path.join(dir, '.github/CODEOWNERS'), 'new');
    const expected = ['.github/CODEOWNERS', '.github/workflows/check.yml', 'CODEOWNERS'];
    const blocked = trace();
    assert.equal(blocked.status, 1, blocked.stdout + blocked.stderr);
    assert.deepEqual(JSON.parse(blocked.stdout).writeScope.violations, expected);
    const result = gate(dir, '--role', 'implementer', '--base', 'HEAD', '--changed-files', 'src/app.mjs', '--fail-fast', '--cmd', 'unused=node -v');
    assert.equal(result.code, 1);
    assert.deepEqual(result.checks.writeScope.violations, expected);
    assert.equal(result.report.failFastStoppedAt, 'writeScope');
    assert.deepEqual(result.checks.commands, []);
  });

  it('T-008 resolves a nested project’s protected paths from its committed policy', (t) => {
    const dir = setupGateProject();
    t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
    const nested = path.join(dir, 'nested');
    fs.mkdirSync(path.join(nested, 'sdd'), { recursive: true });
    fs.cpSync(path.join(dir, 'specs'), path.join(nested, 'specs'), { recursive: true });
    fs.writeFileSync(path.join(nested, 'sdd/guardrails.json'), JSON.stringify({
      anti_tampering: { protected_repo_paths: ['proof.txt'] },
    }));
    git(dir, 'add', 'nested');
    git(dir, 'commit', '-qm', 'nested project policy');
    fs.writeFileSync(path.join(nested, 'proof.txt'), 'unreviewed');
    const result = gate(nested, '--role', 'implementer', '--base', 'HEAD', '--fail-fast');
    assert.equal(result.code, 1);
    assert.deepEqual(result.checks.writeScope.violations, ['proof.txt']);
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
