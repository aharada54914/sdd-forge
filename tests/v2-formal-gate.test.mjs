import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';
import { discoverStateMachines } from '../plugins/sdd-quality-loop/scripts/v2/discover-state-machines.mjs';
import {
  buildCheckerCommand,
  runFormalGate,
  validateNdjsonTrace,
  validateTlaModelStructure,
} from '../plugins/sdd-quality-loop/scripts/v2/run-formal-gate.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..');

describe('ADR-0054 T-005 (AC-003..AC-006): State Machine Discovery & Checker-Agnostic Formal Gate', () => {
  it('AC-003: discovers formal verification triggers from Risk: high and state-machine signals', () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-discover-sm-'));
    fs.mkdirSync(path.join(dir, 'specs', 'payments'), { recursive: true });
    fs.writeFileSync(
      path.join(dir, 'specs', 'payments', 'design.md'),
      '# Design\n\n```mermaid\nstateDiagram-v2\n  Pending --> Captured\n```\n\n排他制御と冪等性を保証する。\n',
      'utf8',
    );
    fs.writeFileSync(
      path.join(dir, 'specs', 'payments', 'tasks.md'),
      '# Tasks\n\n## T-001 Capture payment\nApproval: Approved\nStatus: Planned\nRisk: high\n',
      'utf8',
    );

    const report = discoverStateMachines({ feature: 'payments', projectRoot: dir });
    assert.equal(report.formalRequired, true);
    assert.equal(report.triggeredTasks.length, 1);
    assert.equal(report.triggeredTasks[0].id, 'T-001');
    assert.ok(report.signals.some((s) => s.signal === 'state_diagram'));
    assert.ok(report.signals.some((s) => s.signal === 'concurrency_lock'));
    fs.rmSync(dir, { recursive: true, force: true });
  });

  it('AC-004/AC-005: builds Windows-safe direct java commands (shell: false, no .cmd/.bat) for tlc & apalache and reserves lean4', () => {
    const tlcCmd = buildCheckerCommand({
      adapter: 'tlc',
      tlaFile: 'Reservation.tla',
      cfgFile: 'Reservation.cfg',
      adapterOptions: { workers: 2 },
      jarPath: '/opt/tla2tools.jar',
    });
    assert.equal(tlcCmd.bin, 'java');
    assert.equal(tlcCmd.options.shell, false);
    assert.ok(tlcCmd.args.includes('tlc2.TLC'));
    assert.ok(!tlcCmd.bin.endsWith('.cmd') && !tlcCmd.bin.endsWith('.bat'));

    const apalacheCmd = buildCheckerCommand({
      adapter: 'apalache',
      tlaFile: 'Reservation.tla',
      adapterOptions: { length: 12 },
      jarPath: '/opt/apalache.jar',
    });
    assert.equal(apalacheCmd.bin, 'java');
    assert.equal(apalacheCmd.options.shell, false);
    assert.ok(apalacheCmd.args.includes('--length=12'));

    const leanRes = runFormalGate({
      projectRoot: REPO_ROOT,
      tlaPath: 'tests/fixtures/project-skills/formal-review-reservation/Reservation.tla',
      cfgPath: 'tests/fixtures/project-skills/formal-review-reservation/Reservation.cfg',
      adapter: 'lean4',
      mode: 'shadow',
    });
    assert.equal(leanRes.status, 'NOT_IMPLEMENTED');
    assert.equal(leanRes.exitCode, 0);
  });

  it('AC-004/AC-006: validates canonical Reservation.tla baseline + negative (OneAccepted) + NDJSON trace', () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-formal-res-'));
    const negCfg = path.join(dir, 'Reservation.negative.cfg');
    fs.writeFileSync(negCfg, 'SPECIFICATION Spec\nCONSTANT UseLock = FALSE\nINVARIANT OneAccepted\n', 'utf8');

    const validTrace = path.join(dir, 'valid.ndjson');
    fs.writeFileSync(
      validTrace,
      [
        JSON.stringify({ step: 0, action: 'Init', state: { accepted: [] } }),
        JSON.stringify({ step: 1, action: 'Acquire', actor: 1, state: { accepted: [] } }),
        JSON.stringify({ step: 2, action: 'Publish', actor: 1, state: { accepted: [1] } }),
        JSON.stringify({ step: 3, action: 'Release', actor: 1, state: { accepted: [1] } }),
      ].join('\n'),
      'utf8',
    );

    const calls = [];
    const mockRunner = (cmd) => {
      calls.push(cmd);
      const isNeg = cmd.args.some((a) => String(a).includes('negative.cfg'));
      if (isNeg) {
        return { status: 12, stdout: 'Error: Invariant OneAccepted is violated.', stderr: '' };
      }
      return { status: 0, stdout: 'Model checking completed. No error has been found.', stderr: '' };
    };

    const res = runFormalGate({
      projectRoot: REPO_ROOT,
      tlaPath: 'tests/fixtures/project-skills/formal-review-reservation/Reservation.tla',
      cfgPath: 'tests/fixtures/project-skills/formal-review-reservation/Reservation.cfg',
      negativeCfgPath: negCfg,
      expectedViolatedInvariant: 'OneAccepted',
      mappingPath: 'tests/fixtures/project-skills/formal-review-reservation/mapping.json',
      tracePath: validTrace,
      adapter: 'tlc',
      mode: 'strict',
      execRunner: mockRunner,
    });
    assert.equal(res.status, 'PASS');
    assert.equal(res.exitCode, 0);
    assert.equal(res.checker.baseline.ok, true);
    assert.equal(res.checker.negative.ok, true);
    assert.equal(res.trace.ok, true);
    assert.equal(calls.length, 2);
    assert.ok(calls.every((c) => c.bin === 'java' && c.options.shell === false));

    // Violating trace (two accepted contenders) must fail strict mode
    const badTrace = path.join(dir, 'bad.ndjson');
    fs.writeFileSync(
      badTrace,
      [
        JSON.stringify({ step: 0, action: 'Init', state: { accepted: [] } }),
        JSON.stringify({ step: 1, action: 'Publish', actor: 1, state: { accepted: [1, 2] } }),
      ].join('\n'),
      'utf8',
    );
    const badRes = runFormalGate({
      projectRoot: REPO_ROOT,
      tlaPath: 'tests/fixtures/project-skills/formal-review-reservation/Reservation.tla',
      cfgPath: 'tests/fixtures/project-skills/formal-review-reservation/Reservation.cfg',
      mappingPath: 'tests/fixtures/project-skills/formal-review-reservation/mapping.json',
      tracePath: badTrace,
      adapter: 'none',
      mode: 'strict',
    });
    assert.equal(badRes.status, 'FAIL');
    assert.equal(badRes.exitCode, 1);
    assert.ok(badRes.trace.violations.some((v) => /OneAccepted/.test(v)));

    fs.rmSync(dir, { recursive: true, force: true });
  });
});

describe('ADR-0054 T-006 (SELF-AC-001 / SELF-AC-002): sdd-forge Self-Verification Models (TaskLock & GateLifecycle)', () => {
  it('validates TaskLock.tla and GateLifecycle.tla structure, invariants, and NDJSON traces', () => {
    const taskLock = validateTlaModelStructure({
      tlaPath: path.join(REPO_ROOT, 'specs/self-verification/formal/TaskLock.tla'),
      cfgPath: path.join(REPO_ROOT, 'specs/self-verification/formal/TaskLock.cfg'),
      mappingPath: path.join(REPO_ROOT, 'specs/self-verification/formal/mapping.json'),
    });
    assert.equal(taskLock.ok, true, JSON.stringify(taskLock.errors));
    assert.equal(taskLock.moduleName, 'TaskLock');
    assert.deepEqual(taskLock.invariants, ['SingleOwner']);

    const gateLifecycle = validateTlaModelStructure({
      tlaPath: path.join(REPO_ROOT, 'specs/self-verification/formal/GateLifecycle.tla'),
      cfgPath: path.join(REPO_ROOT, 'specs/self-verification/formal/GateLifecycle.cfg'),
      mappingPath: path.join(REPO_ROOT, 'specs/self-verification/formal/mapping.json'),
    });
    assert.equal(gateLifecycle.ok, true, JSON.stringify(gateLifecycle.errors));
    assert.equal(gateLifecycle.moduleName, 'GateLifecycle');
    assert.deepEqual(gateLifecycle.invariants, ['DoneRequiresGatePass']);

    // Verify NDJSON trace validation catches both SingleOwner and DoneRequiresGatePass violations
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-self-trace-'));
    const badLockTrace = path.join(dir, 'bad-lock.ndjson');
    fs.writeFileSync(
      badLockTrace,
      [
        JSON.stringify({ step: 0, action: 'Init', state: { holders: [] } }),
        JSON.stringify({ step: 1, action: 'Acquire', state: { holders: ['w1', 'w2'] } }),
      ].join('\n'),
      'utf8',
    );
    const lockTraceRes = validateNdjsonTrace({
      tracePath: badLockTrace,
      allowedActions: Object.keys(taskLock.mapping.mapping),
      modelName: 'TaskLock',
    });
    assert.equal(lockTraceRes.ok, false);
    assert.ok(lockTraceRes.violations.some((v) => /SingleOwner/.test(v)));

    const badGateTrace = path.join(dir, 'bad-gate.ndjson');
    fs.writeFileSync(
      badGateTrace,
      [
        JSON.stringify({ step: 0, action: 'Init', state: { status: 'Planned', gateVerdict: 'NONE' } }),
        JSON.stringify({ step: 1, action: 'MarkDone', state: { status: 'Done', gateVerdict: 'FAIL' } }),
      ].join('\n'),
      'utf8',
    );
    const gateTraceRes = validateNdjsonTrace({
      tracePath: badGateTrace,
      allowedActions: Object.keys(gateLifecycle.mapping.mapping),
      modelName: 'GateLifecycle',
    });
    assert.equal(gateTraceRes.ok, false);
    assert.ok(gateTraceRes.violations.some((v) => /DoneRequiresGatePass/.test(v)));

    fs.rmSync(dir, { recursive: true, force: true });
  });
});
