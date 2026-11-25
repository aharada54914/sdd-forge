import assert from 'node:assert/strict';
import fs from 'node:fs';
import { createHash } from 'node:crypto';
import { spawnSync, execFileSync } from 'node:child_process';
import { acquireLock, getLockStatus, releaseLock } from '../plugins/sdd-quality-loop/scripts/v2/task-lock.mjs';
import { runSddGate } from '../plugins/sdd-quality-loop/scripts/v2/run-sdd-gate.mjs';
import { buildSpecBaseline } from '../plugins/sdd-quality-loop/scripts/v2/record-spec-baseline.mjs';
import {
  buildDecisionViewData,
  renderDecisionViewHtml,
} from '../plugins/sdd-quality-loop/scripts/v2/render-decision-view.mjs';
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
        JSON.stringify({ step: 2, action: 'Check', actor: 1, state: { accepted: [] } }),
        JSON.stringify({ step: 3, action: 'Publish', actor: 1, state: { accepted: [1] } }),
        JSON.stringify({ step: 4, action: 'Release', actor: 1, state: { accepted: [1] } }),
      ].join('\n'),
      'utf8',
    );

    const calls = [];
    const mockRunner = (cmd) => {
      calls.push(cmd);
      if (cmd.args.includes('SDDTraceReplay.cfg'))
        return { status: 12, stdout: 'Error: Invariant TraceIncomplete is violated.' };
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
    assert.equal(calls.length, 3);
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
    assert.deepEqual(gateLifecycle.invariants, gateLifecycle.mapping.models.GateLifecycle.invariants);

    const mapping = gateLifecycle.mapping;
    const sources = [...new Set(Object.values(mapping.models).flatMap((model) => model.sources))].sort();
    assert.deepEqual(Object.keys(mapping.source_sha256).sort(), sources);
    for (const source of sources) {
      const digest = createHash('sha256')
        .update(fs.readFileSync(path.join(REPO_ROOT, source)))
        .digest('hex');
      assert.equal(mapping.source_sha256[source], digest, 'Recheck model correspondence after editing ' + source);
    }

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

describe('checker verdicts match the observed failure', () => {
  const input = {
    projectRoot: REPO_ROOT,
    tlaPath: 'tests/fixtures/project-skills/formal-review-reservation/Reservation.tla',
    cfgPath: 'tests/fixtures/project-skills/formal-review-reservation/Reservation.cfg',
    adapter: 'tlc',
    mode: 'strict',
  };
  it('does not accept a tool error mentioning the invariant as a negative control', () => {
    const result = runFormalGate({
      ...input,
      expectedViolatedInvariant: 'OneAccepted',
      execRunner: (cmd) =>
        cmd.args.includes('Reservation.negative.cfg')
          ? { status: 2, stdout: 'Parse error: OneAccepted' }
          : { status: 0, stdout: 'Model checking completed. No error has been found.' },
    });
    assert.equal(result.status, 'FAIL');
    assert.equal(result.checker.negative.ok, false);
  });
  it('defers a missing tool locally and fails CI', () => {
    for (const [ci, code] of [
      [false, 10],
      [true, 1],
    ]) {
      const result = runFormalGate({ ...input, ci, execRunner: () => ({ status: 127, unavailable: true }) });
      assert.equal(result.exitCode, code);
    }
  });
  it('rejects a gate pass with undeclared drift and an unapproved completion', () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'gate-model-mismatch-'));
    try {
      const tracePath = path.join(dir, 'trace.ndjson');
      fs.writeFileSync(
        tracePath,
        [
          { step: 0, action: 'Init', state: { status: 'Planned', gateVerdict: 'NONE', approved: false } },
          {
            step: 1,
            action: 'MarkDone',
            state: { status: 'Done', gateVerdict: 'PASS', approved: false, drift: 'UNDECLARED_DRIFT' },
          },
        ]
          .map((x) => JSON.stringify(x))
          .join('\n'),
      );
      const result = validateNdjsonTrace({ tracePath, modelName: 'GateLifecycle', allowedActions: ['MarkDone'] });
      assert.equal(result.ok, false);
    } finally {
      fs.rmSync(dir, { recursive: true, force: true });
    }
  });
});

const scripts = path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2');
const reservation = path.join(REPO_ROOT, 'tests/fixtures/project-skills/formal-review-reservation/Reservation.tla');
const formal = path.join(REPO_ROOT, 'specs/self-verification/formal');
function sandbox(t) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-formal-integration-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  return root;
}

it('scan finds related compound branches and graph validation fails on unreachable states', (t) => {
  const root = sandbox(t);
  fs.writeFileSync(
    path.join(root, 'example.js'),
    'function run(a,b,c){ if(a && b) return 1; if(!a && b) return 2; if(c) return 3; }',
  );
  fs.writeFileSync(
    path.join(root, 'graph.json'),
    JSON.stringify({ initial: 'New', states: ['New', 'Active', 'Lost'], transitions: [{ from: 'New', to: 'Active' }] }),
  );
  function discover(...args) {
    const p = spawnSync(
      process.execPath,
      [path.join(scripts, 'discover-state-machines.mjs'), '--root', root, ...args],
      { encoding: 'utf8' },
    );
    return [p.status, JSON.parse(p.stdout || JSON.stringify(p.stderr))];
  }
  const [code, scan] = discover('--scan', 'example.js');
  assert.equal(code, 0, JSON.stringify(scan));
  assert.equal(scan.signals.length, 2);
  const [status, graph] = discover('--validate', 'graph.json');
  assert.equal(status, 1);
  assert.deepEqual(graph.unreachable, ['Lost']);
});

it('skips an unchanged model and mapped sources only; fails timed-out checks and persists an OQ in the decision view', (t) => {
  const root = sandbox(t);
  const feature = 'demo';
  const spec = path.join(root, 'specs', feature);
  fs.mkdirSync(spec, { recursive: true });
  fs.cpSync(path.dirname(reservation), path.join(spec, 'formal'), { recursive: true });
  fs.writeFileSync(path.join(spec, 'requirements.md'), '# Requirements\n');
  const git = (...args) => execFileSync('git', args, { cwd: root, stdio: 'pipe' });
  git('init', '-q');
  git('add', '.');
  git('-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', 'commit', '-qm', 'model');
  const opts = {
    projectRoot: root,
    tlaPath: 'specs/demo/formal/Reservation.tla',
    mode: 'strict',
    feature,
    round: 99,
    runId: 'retry',
    baseRef: 'HEAD',
  };
  const unavailable = () => {
    throw new Error('unchanged inputs must short circuit');
  };
  assert.equal(runFormalGate({ ...opts, execRunner: unavailable }).status, 'SKIPPED');
  fs.appendFileSync(path.join(spec, 'formal', 'Reservation.tla'), '\n');
  const failed = runFormalGate({ ...opts, execRunner: () => ({ status: 1, timedOut: true, stderr: 'deadline' }) });
  assert.equal(failed.exitCode, 1);
  assert.equal(failed.checker.baseline.timedOut, true);
  const saved = JSON.parse(fs.readFileSync(path.join(root, failed.openQuestion.path)));
  assert.equal(saved.status, 'Provisional');
  assert.match(
    renderDecisionViewHtml(buildDecisionViewData({ feature, projectRoot: root })),
    /Reservation \(baseline\): timeout/,
  );
  assert.equal(fs.readFileSync(path.join(root, failed.evidence, 'baseline.log'), 'utf8'), 'deadline');
  const tracePath = path.join(root, 'malformed.ndjson');
  fs.writeFileSync(tracePath, '{}\n');
  const malformed = runFormalGate({ ...opts, tracePath, execRunner: unavailable });
  assert.equal(malformed.status, 'FAIL');
  assert.ok(fs.existsSync(path.join(root, malformed.openQuestion.path)));
  assert.equal(fs.readFileSync(path.join(root, malformed.evidence, 'observed.ndjson'), 'utf8'), '{}\n');
  assert.equal(runFormalGate({ ...opts, risk: 'high', execRunner: unavailable }).exitCode, 1);
});

function captureLock(projectRoot) {
  const arg = { projectRoot, feature: 'demo' };
  const steps = [];
  const observe = (action, actor) => {
    const lock = getLockStatus(arg);
    steps.push({
      step: steps.length,
      action,
      actor,
      state: { holders: lock.locked ? [lock.record.owner] : [], leaseActive: lock.locked && !lock.stale },
    });
  };
  observe('Init');
  assert.equal(acquireLock({ ...arg, owner: 'w1' }).acquired, true);
  observe('Acquire', 'w1');
  assert.equal(acquireLock({ ...arg, owner: 'w2' }).acquired, false);
  assert.equal(acquireLock({ ...arg, owner: 'w1' }).acquired, true);
  observe('Renew', 'w1');
  assert.equal(releaseLock({ ...arg, owner: 'w1' }).released, true);
  observe('Release', 'w1');
  return steps;
}

function captureGate(projectRoot, tamper = false) {
  const feature = 'demo',
    taskId = 'T-001',
    spec = path.join(projectRoot, 'specs', feature);
  fs.mkdirSync(spec, { recursive: true });
  fs.writeFileSync(path.join(spec, 'requirements.md'), '# Requirements\n- REQ-001: Observe gate verdicts.\n');
  fs.writeFileSync(path.join(spec, 'design.md'), '# Design\nUse execution.json.\n');
  const steps = [];
  const observedStatus = { Planned: 'Planned', 'In Progress': 'InProgress', 'Implementation Complete': 'ImplComplete' };
  const args = { projectRoot, feature, taskId, changedFiles: [], commands: [], skipSensors: true };
  function observe(action, approval, status) {
    fs.writeFileSync(
      path.join(spec, 'tasks.md'),
      `## T-001 Exercise gate\nApproval: ${approval}\nStatus: ${status}\nRisk: low\n`,
    );
    const { result } = runSddGate({ ...args, skipDrift: true });
    const pre = result.checks.taskPrecondition;
    steps.push({
      step: steps.length,
      action,
      state: {
        status: observedStatus[pre.status],
        approved: pre.approval === 'Approved',
        rounds: 0,
        gateVerdict: 'NONE',
        tamper: false,
        drift: 'CLEAN',
        oq: false,
      },
    });
  }
  observe('Init', 'Draft', 'Planned');
  observe('Approve', 'Approved', 'Planned');
  observe('StartTask', 'Approved', 'In Progress');
  observe('CompleteImpl', 'Approved', 'Implementation Complete');
  fs.writeFileSync(path.join(spec, '.spec-baseline.json'), JSON.stringify(buildSpecBaseline({ feature, projectRoot })));
  if (tamper) {
    const manifest = path.join(projectRoot, 'sdd', 'approved-test-retirements.json');
    fs.mkdirSync(path.dirname(manifest), { recursive: true });
    fs.writeFileSync(manifest, JSON.stringify({ retirements: [] }));
    const git = (...args) => execFileSync('git', args, { cwd: projectRoot, stdio: 'pipe' });
    git('init', '-q');
    git('add', 'specs', 'sdd');
    git('-c', 'user.name=Fixture', '-c', 'user.email=test@example.invalid', 'commit', '-qm', 'approved inputs');
    fs.appendFileSync(manifest, '\n');
    fs.writeFileSync(path.join(spec, 'requirements.md'), '# Requirements\n- REQ-001: Changed without amendment.\n');
  }
  const { outputPath } = runSddGate({ ...args, enableAntiTamper: tamper, baseRef: tamper ? 'HEAD' : null });
  const { verdict, checks } = JSON.parse(fs.readFileSync(outputPath));
  assert.equal(verdict, tamper ? 'FAIL' : 'PASS', JSON.stringify(checks));
  let oq = false;
  if (tamper) {
    assert.equal(checks.antiTamper.status, 'TAMPER_DETECTED');
    assert.equal(checks.specDrift.status, 'UNDECLARED_DRIFT');
    const question = JSON.parse(fs.readFileSync(path.join(projectRoot, checks.antiTamper.openQuestion.path)));
    oq = question.status === 'Provisional';
    assert.equal(oq, true);
  }
  steps.push({
    step: steps.length,
    action: verdict === 'PASS' ? 'RunGatePass' : 'RunGateFail',
    state: {
      ...steps.at(-1).state,
      gateVerdict: verdict,
      drift: checks.specDrift.status,
      tamper: checks.antiTamper.status === 'TAMPER_DETECTED',
      oq,
    },
  });
  return steps;
}

const checkerAvailable = Boolean(process.env.TLA2TOOLS_JAR);
it(
  'TLC checks reservation, lock and gate baselines and named mutants, and replays implementation traces',
  { skip: checkerAvailable ? false : 'requires pinned TLA2TOOLS_JAR' },
  (t) => {
    const projectRoot = sandbox(t);
    function run(model, extra = {}) {
      const report = runFormalGate({
        projectRoot,
        tlaPath: model,
        mode: 'strict',
        adapter: 'tlc',
        runId: 'model-test',
        ...extra,
      });
      for (const phase of ['baseline', 'negative', 'replay']) {
        const result = report.checker?.[phase];
        if (result)
          t.diagnostic(
            [
              report.moduleName,
              phase,
              result.violatedInvariant || 'no violation',
              'exit=' + result.status,
              'states=' + result.distinctStates,
              'depth=' + result.depth,
            ].join(' '),
          );
      }
      return report;
    }
    const cases = [
      [
        reservation,
        'OneAccepted',
        [
          { step: 0, action: 'Init', state: { accepted: [] } },
          { step: 1, action: 'Acquire', actor: 1, state: { accepted: [] } },
          { step: 2, action: 'Check', actor: 1, state: { accepted: [] } },
          { step: 3, action: 'Publish', actor: 1, state: { accepted: [1] } },
          { step: 4, action: 'Release', actor: 1, state: { accepted: [1] } },
        ],
      ],
      [path.join(formal, 'TaskLock.tla'), 'SingleOwner', captureLock(projectRoot)],
      [path.join(formal, 'GateLifecycle.tla'), 'DoneRequiresGatePass', captureGate(projectRoot)],
      [path.join(formal, 'GateLifecycle.tla'), 'DoneRequiresGatePass', captureGate(sandbox(t), true)],
    ];
    for (const [model, invariant, events] of cases) {
      const tracePath = events ? path.join(projectRoot, path.basename(model) + '.ndjson') : null;
      if (events) fs.writeFileSync(tracePath, events.map((ev) => JSON.stringify(ev)).join('\n'));
      const checked = run(model, { tracePath, risk: events ? 'high' : 'standard' });
      const detail = checked.evidence
        ? fs.readFileSync(
            path.join(
              projectRoot,
              checked.evidence,
              checked.checker.replay ? 'replay.log' : checked.checker.negative ? 'negative.log' : 'baseline.log',
            ),
            'utf8',
          )
        : JSON.stringify(checked);
      assert.equal(checked.status, 'PASS', detail);
      assert.equal(checked.checker.negative.violatedInvariant, invariant);
      assert.ok(fs.existsSync(path.join(projectRoot, checked.evidence, 'negative-SpecTE.tla')));
      if (events) {
        assert.equal(checked.checker.replay.violatedInvariant, 'TraceIncomplete');
        if (invariant === 'SingleOwner' && process.env.APALACHE_JAR) {
          const cross = run(model, { adapter: 'apalache', tracePath, risk: 'high' });
          assert.equal(cross.status, 'PASS', JSON.stringify(cross));
          assert.equal(cross.checker.negative.violatedInvariant, 'SingleOwner');
          assert.equal(cross.checker.replay.violatedInvariant, 'TraceIncomplete');
          assert.ok(fs.existsSync(path.join(projectRoot, cross.evidence, 'negative-violation1.itf.json')));
          t.diagnostic(
            cross.checker.baseline.version +
              ' TaskLock baseline, negative, and projection: length=' +
              cross.checker.baseline.length,
          );
        }
        const invalid = structuredClone(events);
        if (invariant === 'SingleOwner') invalid[1].state.leaseActive = false;
        else if (invariant === 'OneAccepted') invalid[2].state.accepted = [1];
        else invalid[2].state.rounds = 1;
        fs.writeFileSync(tracePath, invalid.map((ev) => JSON.stringify(ev)).join('\n'));
        const mismatch = run(model, { tracePath, risk: 'high' });
        assert.equal(mismatch.status, 'FAIL');
        assert.equal(mismatch.trace.ok, false);
      }
    }
    for (const [fault, invariant] of [
      ['retry', 'RetryBound'],
      ['oq', 'EscalationRequiresOQ'],
      ['tamper', 'NoTamperRepair'],
      ['drift', 'NoDriftPass'],
    ]) {
      const checked = run(path.join(formal, 'GateLifecycle.tla'), {
        negativeCfgPath: path.join(formal, 'GateLifecycle.' + fault + '.negative.cfg'),
        expectedViolatedInvariant: invariant,
      });
      assert.equal(checked.status, 'PASS', JSON.stringify(checked));
      assert.equal(checked.checker.negative.violatedInvariant, invariant);
    }
  },
);
