import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { describe, it } from 'node:test';
import { fileURLToPath, pathToFileURL } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..');
const RECORD_SCRIPT = path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/record-spec-baseline.mjs');
const GATE_SCRIPT = path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/run-sdd-gate.mjs');

function setupCoreRepo({ taskStatus = 'Implementation Complete', approved = true } = {}) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-v2-core-'));
  fs.mkdirSync(path.join(dir, '.git'));
  fs.mkdirSync(path.join(dir, 'specs', 'payments'), { recursive: true });
  fs.mkdirSync(path.join(dir, 'src'), { recursive: true });

  fs.writeFileSync(
    path.join(dir, 'specs', 'payments', 'requirements.md'),
    [
      '# 要件（SDD Core）: payments',
      '',
      '- **REQ-001**: Refund calculates exact prorated amount.',
      '- **AC-001**: Full refund returns 100% of captured cents.',
      '',
      '## Spec Amendments',
      '- （初期版のため変更なし）',
      '',
    ].join('\n'),
    'utf8',
  );

  fs.writeFileSync(
    path.join(dir, 'specs', 'payments', 'design.md'),
    [
      '# 設計（SDD Core）: payments',
      '',
      '## 方針',
      'Use integer minor-unit arithmetic in src/refund.js.',
      '',
      '## Spec Amendments',
      '- None',
      '',
    ].join('\n'),
    'utf8',
  );

  fs.writeFileSync(
    path.join(dir, 'specs', 'payments', 'tasks.md'),
    [
      '# タスク（SDD Core）: payments',
      '',
      '## T-001 Implement refund calculator',
      `Approval: ${approved ? 'Approved' : 'Draft'}`,
      `Status: ${taskStatus}`,
      'Risk: standard',
      '',
      '### Scope',
      '- src/refund.js',
      '',
      '### Done When',
      '- AC-001 passes',
      '',
      '## Spec Amendments',
      '- None',
      '',
    ].join('\n'),
    'utf8',
  );

  fs.writeFileSync(path.join(dir, 'src', 'refund.js'), 'export const refund = (cents) => cents;\n', 'utf8');
  return dir;
}

describe('run-sdd-gate.mjs (SDD Core unified deterministic gate)', () => {
  it('passes cleanly when task is approved, specs are CLEAN, code has no placeholders, and tests pass', () => {
    const repo = setupCoreRepo();
    assert.equal(
      spawnSync(process.execPath, [RECORD_SCRIPT, '--feature', 'payments', '--root', repo], { encoding: 'utf8' }).status,
      0,
    );

    const res = spawnSync(
      process.execPath,
      [
        GATE_SCRIPT,
        '--feature',
        'payments',
        '--task',
        'T-001',
        '--root',
        repo,
        '--changed-files',
        'src/refund.js',
        '--cmd',
        'unit=node -e "process.exit(0)"',
      ],
      { encoding: 'utf8' },
    );
    assert.equal(res.status, 0, res.stderr);
    const out = JSON.parse(res.stdout);
    assert.equal(out.verdict, 'PASS');
    assert.equal(out.checks.specDrift.status, 'CLEAN');
    assert.equal(out.checks.placeholders.passed, true);
    assert.equal(out.checks.commands[0].passed, true);
    assert.equal(fs.existsSync(out.outputPath), true);
  });

  it('#819: re-entering ship keeps the existing baseline; only --rerecord replaces it', () => {
    const repo = setupCoreRepo();
    const record = (...extra) =>
      spawnSync(process.execPath, [RECORD_SCRIPT, '--feature', 'payments', '--root', repo, ...extra], { encoding: 'utf8' });
    const first = record();
    assert.equal(first.status, 0, first.stderr);
    assert.equal(JSON.parse(first.stdout).status, 'RECORDED');
    const baselinePath = path.join(repo, 'specs', 'payments', '.spec-baseline.json');
    const original = fs.readFileSync(baselinePath, 'utf8');

    const reqPath = path.join(repo, 'specs', 'payments', 'requirements.md');
    fs.writeFileSync(reqPath, fs.readFileSync(reqPath, 'utf8').replace('100% of captured cents', '90% of captured cents'), 'utf8');
    const gate = () =>
      JSON.parse(
        spawnSync(
          process.execPath,
          [GATE_SCRIPT, '--feature', 'payments', '--task', 'T-001', '--root', repo, '--changed-files', 'src/refund.js', '--cmd', 'unit=node -e "process.exit(0)"'],
          { encoding: 'utf8' },
        ).stdout,
      );

    const again = record();
    assert.equal(again.status, 0, again.stderr);
    assert.equal(JSON.parse(again.stdout).status, 'EXISTING');
    assert.equal(fs.readFileSync(baselinePath, 'utf8'), original, 'existing baseline is untouched');
    assert.equal(gate().checks.specDrift.status, 'UNDECLARED_DRIFT', 'undeclared drift survives a re-entry');

    for (const broken of ['{}', 'null', '[]']) {
      fs.writeFileSync(baselinePath, broken, 'utf8');
      const res = record();
      assert.equal(res.status, 1, `a ${broken} baseline is reported, not accepted as EXISTING`);
      assert.match(res.stderr, /--rerecord/);
    }

    const forced = record('--rerecord');
    assert.equal(JSON.parse(forced.stdout).status, 'RECORDED');
    assert.equal(gate().checks.specDrift.status, 'CLEAN', 'an intended re-record still works');
  });

  it('#829: findings outside the task Scope are labelled, and the verdict stays fail-closed', () => {
    const repo = setupCoreRepo();
    assert.equal(
      spawnSync(process.execPath, [RECORD_SCRIPT, '--feature', 'payments', '--root', repo], { encoding: 'utf8' }).status,
      0,
    );
    // Another task's unfinished file in the same working tree. The marker is
    // assembled at runtime so this suite never trips the scanner it tests.
    const marker = ['TO', 'DO'].join('');
    fs.writeFileSync(path.join(repo, 'src', 'other.js'), `export const x = 1; // ${marker}: other task\n`, 'utf8');
    const run = (files) =>
      JSON.parse(
        spawnSync(
          process.execPath,
          [GATE_SCRIPT, '--feature', 'payments', '--task', 'T-001', '--root', repo, '--changed-files', files, '--cmd', 'unit=node -e "process.exit(0)"'],
          { encoding: 'utf8' },
        ).stdout,
      );
    const shared = run('src/refund.js,src/other.js');
    assert.equal(shared.verdict, 'FAIL', 'out-of-scope findings still fail by default');
    assert.deepEqual(shared.scope.taskScope, ['src/refund.js']);
    assert.deepEqual(shared.scope.outOfScopeFiles, ['src/other.js']);
    assert.deepEqual(shared.checks.placeholders.findings.map((f) => [f.file, f.inTaskScope]), [['src/other.js', false]]);
    const own = run('src/refund.js');
    assert.equal(own.verdict, 'PASS', 'scoping the run to the task\'s own files passes');
    assert.deepEqual(own.scope.outOfScopeFiles, []);

    // A plain Scope bullet may carry trailing prose after the path.
    const tasksPath = path.join(repo, 'specs', 'payments', 'tasks.md');
    fs.writeFileSync(tasksPath, fs.readFileSync(tasksPath, 'utf8').replace('- src/refund.js', '- src/refund.js — refund calculator'), 'utf8');
    assert.deepEqual(run('src/refund.js').scope.outOfScopeFiles, []);
  });

  it('#823: an unresolved critical/major review ticket for this task fails the gate; others do not', () => {
    const repo = setupCoreRepo();
    assert.equal(
      spawnSync(process.execPath, [RECORD_SCRIPT, '--feature', 'payments', '--root', repo], { encoding: 'utf8' }).status,
      0,
    );
    const tickets = path.join(repo, 'docs', 'review-tickets');
    fs.mkdirSync(tickets, { recursive: true });
    const ticket = (id, status, severity, feature, task) =>
      fs.writeFileSync(
        path.join(tickets, `${id}.yml`),
        `ticket_id: ${id}\nstatus: ${status}\ntype: bug\nseverity: ${severity}\ntarget:\n  feature: ${feature}\n  task: "${task}"\nsummary: s\n`,
        'utf8',
      );
    ticket('RT-1', 'resolved', 'critical', 'payments', 'T-001');
    ticket('RT-2', 'open', 'major', 'payments', 'T-002');
    ticket('RT-3', 'open', 'critical', 'billing', 'T-001');
    ticket('RT-4', 'open', 'minor', 'payments', 'T-001');
    const run = () =>
      spawnSync(
        process.execPath,
        [GATE_SCRIPT, '--feature', 'payments', '--task', 'T-001', '--root', repo, '--changed-files', 'src/refund.js', '--cmd', 'unit=node -e "process.exit(0)"'],
        { encoding: 'utf8' },
      );
    const clean = JSON.parse(run().stdout);
    assert.equal(clean.verdict, 'PASS', 'resolved, other-task, other-feature and minor tickets do not block');
    assert.deepEqual(clean.checks.reviewTickets.blocking, []);

    ticket('RT-6', 'rejected', 'critical', 'payments', 'T-001');
    try {
      fs.symlinkSync(path.join(tickets, 'missing-target.yml'), path.join(tickets, 'RT-dangling.yml'));
    } catch {
      // symlinks unavailable on this platform: the dangling case is skipped
    }
    const stillClean = run();
    assert.equal(stillClean.status, 0, stillClean.stderr);
    assert.deepEqual(JSON.parse(stillClean.stdout).checks.reviewTickets.blocking, [], 'rejected tickets do not block');

    ticket('RT-5', 'open', 'major', 'payments', 'T-001');
    // Targets T-001 for payments although a free-text block before `target:`
    // holds indented feature/task lines and `task:` carries a comment.
    fs.writeFileSync(
      path.join(tickets, 'RT-7.yml'),
      'ticket_id: RT-7\nstatus: open\nseverity: critical\nproblem: |\n  feature: billing\n  task: T-009\ntarget:\n  feature: payments\n  task: T-001 # main task\nsummary: s\n',
      'utf8',
    );
    // Flow-style target mapping must block too (it used to be skipped: fail-open).
    fs.writeFileSync(
      path.join(tickets, 'RT-8.yml'),
      'ticket_id: RT-8\nstatus: open\nseverity: critical\ntarget: {feature: payments, task: "T-001"}\nsummary: s\n',
      'utf8',
    );
    // Valid-YAML flow variants: a trailing comment with braces, quoted keys,
    // and a mapping split over lines.
    const raw = (id, target) =>
      fs.writeFileSync(path.join(tickets, `${id}.yml`), `ticket_id: ${id}\nstatus: open\nseverity: major\ntarget: ${target}\nsummary: s\n`, 'utf8');
    raw('RT-9', '{feature: payments, task: T-001} # see {x}');
    raw('RT-10', '{"feature": "payments", "task": "T-001"}');
    raw('RT-11', '{feature: payments,\n  task: T-001}');
    raw('RT-12', '{feature: payments, task: T-002} # other task');
    const blocked = run();
    assert.equal(blocked.status, 1);
    const out = JSON.parse(blocked.stdout);
    assert.equal(out.verdict, 'FAIL');
    assert.deepEqual(
      out.checks.reviewTickets.blocking.map((t) => t.ticketId).sort(),
      ['RT-10', 'RT-11', 'RT-5', 'RT-7', 'RT-8', 'RT-9'].sort(),
    );
  });

  it('fails gate on UNDECLARED_DRIFT (silent AC tampering) and passes once amendment rationale is declared', () => {
    const repo = setupCoreRepo();
    assert.equal(
      spawnSync(process.execPath, [RECORD_SCRIPT, '--feature', 'payments', '--root', repo], { encoding: 'utf8' }).status,
      0,
    );

    // Tamper with AC-001 silently
    const reqPath = path.join(repo, 'specs', 'payments', 'requirements.md');
    fs.writeFileSync(
      reqPath,
      fs.readFileSync(reqPath, 'utf8').replace('100% of captured cents', '90% of captured cents'),
      'utf8',
    );

    const failRes = spawnSync(
      process.execPath,
      [GATE_SCRIPT, '--feature', 'payments', '--task', 'T-001', '--root', repo, '--changed-files', 'src/refund.js'],
      { encoding: 'utf8' },
    );
    assert.equal(failRes.status, 1);
    const failJson = JSON.parse(failRes.stdout);
    assert.equal(failJson.verdict, 'FAIL');
    assert.equal(failJson.checks.specDrift.status, 'UNDECLARED_DRIFT');
    assert.equal(failJson.checks.specDrift.modifiedIdentifiers[0].id, 'AC-001');

    // Record user-agreed rationale under Spec Amendments -> now AMENDED & PASS
    fs.writeFileSync(
      reqPath,
      fs
        .readFileSync(reqPath, 'utf8')
        .replace('- （初期版のため変更なし）', '- 2026-11-21: ユーザー合意により手数料 10% 控除を AC-001 に反映'),
      'utf8',
    );
    const passRes = spawnSync(
      process.execPath,
      [GATE_SCRIPT, '--feature', 'payments', '--task', 'T-001', '--root', repo, '--changed-files', 'src/refund.js'],
      { encoding: 'utf8' },
    );
    assert.equal(passRes.status, 0);
    const passJson = JSON.parse(passRes.stdout);
    assert.equal(passJson.verdict, 'PASS');
    assert.equal(passJson.checks.specDrift.status, 'AMENDED');
  });

  it('scans the gate source itself and reports only actual unfinished work', t => {
    const repo = setupCoreRepo();
    t.after(() => fs.rmSync(repo, { recursive: true, force: true }));
    const file = path.relative(REPO_ROOT, GATE_SCRIPT).split(path.sep).join('/');
    const copy = path.join(repo, file);
    fs.mkdirSync(path.dirname(copy), { recursive: true });
    const original = fs.readFileSync(GATE_SCRIPT, 'utf8');
    fs.writeFileSync(copy, original);
    const baseline = spawnSync(process.execPath, [RECORD_SCRIPT, '--feature', 'payments', '--root', repo]);
    assert.equal(baseline.status, 0, baseline.stderr.toString());
    const args = [GATE_SCRIPT, '--feature', 'payments', '--task', 'T-001', '--root', repo, '--changed-files', file];
    const scan = () => spawnSync(process.execPath, args, { encoding: 'utf8' });
    const clean = scan();
    assert.equal(clean.status, 0, clean.stdout + clean.stderr);
    assert.deepEqual(JSON.parse(clean.stdout).checks.placeholders, {
      passed: true, scannedFiles: [file], findings: [],
    });

    const [todo, fixme, tbd] = ['todo', 'fixme', 'tbd'].map(word => word.toUpperCase());
    const defects = [todo, fixme, tbd, 'Not' + 'ImplementedError',
      'throw new Error(' + "'Not implemented')", 'unimplemented!' + '()'];
    const benign = ['todo', 'prefix' + todo, fixme + '_suffix', 'tbd!', 'NotimplementedError'];
    const firstLine = original.split('\n').length + 1;
    fs.appendFileSync(copy, '\n' + [...defects, ...benign].map(text => '// ' + text).join('\n') + '\n');
    const dirty = scan();
    assert.equal(dirty.status, 1, dirty.stdout + dirty.stderr);
    // inTaskScope is the #829 label; this task's Scope does not list the gate file.
    assert.deepEqual(JSON.parse(dirty.stdout).checks.placeholders.findings,
      defects.map((text, i) => ({ file, line: firstLine + i, text: '// ' + text, inTaskScope: false })));
  });

  it('fails gate when changed production code contains placeholders or a verification command fails', () => {
    const repo = setupCoreRepo();
    assert.equal(
      spawnSync(process.execPath, [RECORD_SCRIPT, '--feature', 'payments', '--root', repo], { encoding: 'utf8' }).status,
      0,
    );

    fs.writeFileSync(path.join(repo, 'src', 'refund.js'), '// TODO: implement refund\nexport const refund = () => 0;\n');
    const res = spawnSync(
      process.execPath,
      [
        GATE_SCRIPT,
        '--feature',
        'payments',
        '--task',
        'T-001',
        '--root',
        repo,
        '--changed-files',
        'src/refund.js',
        '--cmd',
        'unit=node -e "process.exit(1)"',
      ],
      { encoding: 'utf8' },
    );
    assert.equal(res.status, 1);
    const out = JSON.parse(res.stdout);
    assert.equal(out.verdict, 'FAIL');
    assert.equal(out.checks.placeholders.passed, false);
    assert.equal(out.checks.placeholders.findings.length, 1);
    assert.equal(out.checks.commands[0].passed, false);
  });

  it('rejects unapproved tasks at precondition check', () => {
    const repo = setupCoreRepo({ approved: false });
    assert.equal(
      spawnSync(process.execPath, [RECORD_SCRIPT, '--feature', 'payments', '--root', repo], { encoding: 'utf8' }).status,
      0,
    );
    const res = spawnSync(
      process.execPath,
      [GATE_SCRIPT, '--feature', 'payments', '--task', 'T-001', '--root', repo],
      { encoding: 'utf8' },
    );
    assert.equal(res.status, 1);
    const out = JSON.parse(res.stdout);
    assert.equal(out.verdict, 'FAIL');
    assert.equal(out.checks.taskPrecondition.passed, false);
  });
});

describe('#821 gate task lookup uses the exact task ID', () => {
  it('never reads a sibling task whose ID shares a prefix, in either order', async () => {
    const { parseTaskBlock } = await import(
      pathToFileURL(path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/run-sdd-gate.mjs')).href
    );
    const sibling = ['## T-001.1 Sibling', 'Approval: Approved', 'Status: Done', 'Risk: high', ''].join('\n');
    const target = ['## T-001 Target', 'Approval: Draft', 'Status: Planned', 'Risk: low', ''].join('\n');
    const extra = ['## T-001-extra', 'Approval: Approved', 'Status: Done', ''].join('\n');
    for (const doc of [`${sibling}\n${extra}\n${target}`, `${target}\n${sibling}\n${extra}`]) {
      const t = parseTaskBlock(doc, 'T-001');
      assert.equal(t.approval, 'Draft');
      assert.equal(t.status, 'Planned');
      assert.equal(t.risk, 'low');
      assert.equal(parseTaskBlock(doc, 'T-001.1').status, 'Done');
      assert.equal(parseTaskBlock(doc, 'T-001-extra').approval, 'Approved');
    }
    assert.equal(parseTaskBlock(sibling, 'T-001'), null, 'a prefix-only heading must not satisfy the lookup');
    assert.equal(parseTaskBlock('## T-001\nApproval: Approved\n', 'T-001').approval, 'Approved');
  });
});

describe('#822/#828 gate change discovery', () => {
  it('lists non-ASCII names verbatim and stays relative to a nested project root', async () => {
    const { discoverChangedFiles } = await import(
      pathToFileURL(path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/run-sdd-gate.mjs')).href
    );
    const repo = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-gate-discover-'));
    const git = (...args) => {
      const r = spawnSync('git', args, { cwd: repo, encoding: 'utf8' });
      assert.equal(r.status, 0, r.stderr);
    };
    git('init', '-q');
    fs.mkdirSync(path.join(repo, 'pkg', 'src'), { recursive: true });
    fs.writeFileSync(path.join(repo, 'pkg', 'src', 'a.js'), 'export const a = 1;\n');
    fs.writeFileSync(path.join(repo, 'pkg', 'src', '変更.js'), 'export const b = 1;\n');
    fs.writeFileSync(path.join(repo, 'other.js'), 'export const o = 1;\n');
    git('add', '-A');
    git('-c', 'user.name=t', '-c', 'user.email=t@example.invalid', 'commit', '-qm', 'base');
    fs.writeFileSync(path.join(repo, 'pkg', 'src', 'a.js'), 'export const a = 2;\n');
    fs.writeFileSync(path.join(repo, 'pkg', 'src', '変更.js'), 'export const b = 2;\n');
    fs.writeFileSync(path.join(repo, 'pkg', 'src', '新規.js'), 'export const c = 1;\n');
    fs.writeFileSync(path.join(repo, 'other.js'), 'export const o = 2;\n');

    const nested = discoverChangedFiles(path.join(repo, 'pkg')).sort();
    assert.deepEqual(nested, ['src/a.js', 'src/変更.js', 'src/新規.js'].sort());
    for (const rel of nested) assert.ok(fs.existsSync(path.join(repo, 'pkg', rel)), `${rel} must be openable`);

    const top = discoverChangedFiles(repo).sort();
    assert.deepEqual(top, ['other.js', 'pkg/src/a.js', 'pkg/src/変更.js', 'pkg/src/新規.js'].sort());
    assert.deepEqual(discoverChangedFiles(repo, ['pkg/src/変更.js']), ['pkg/src/変更.js']);

    // #826: after committing part of the work, the default sees only what is
    // left uncommitted; --base <ref> brings the committed part back in scope.
    git('-c', 'user.name=t', '-c', 'user.email=t@example.invalid', 'commit', '-qam', 'midway');
    const base = spawnSync('git', ['rev-parse', 'HEAD~1'], { cwd: repo, encoding: 'utf8' }).stdout.trim();
    fs.writeFileSync(path.join(repo, 'pkg', 'src', 'later.js'), 'export const l = 1;\n');
    assert.deepEqual(discoverChangedFiles(path.join(repo, 'pkg')).sort(), ['src/later.js', 'src/新規.js'].sort());
    assert.deepEqual(
      discoverChangedFiles(path.join(repo, 'pkg'), null, { baseRef: base }).sort(),
      ['src/a.js', 'src/later.js', 'src/変更.js', 'src/新規.js'].sort(),
    );
    assert.throws(() => discoverChangedFiles(repo, null, { baseRef: '--output=/tmp/x' }), /base/i);
    fs.rmSync(repo, { recursive: true, force: true });
  });
});

describe('Phase 2 SDD Core skill & template contracts', () => {
  const coreSkills = [
    'plugins/sdd-bootstrap/skills/bootstrap/SKILL.md',
    'plugins/sdd-bootstrap/skills/sdd-core-spec/SKILL.md',
    'plugins/sdd-review-loop/skills/spec-check/SKILL.md',
    'plugins/sdd-quality-loop/skills/sdd-gate/SKILL.md',
    'plugins/sdd-ship/skills/ship/SKILL.md',
  ];

  it('all consolidated SDD Core skills have valid frontmatter and zero legacy canary/ERROR_STOP rituals', () => {
    for (const rel of coreSkills) {
      const content = fs.readFileSync(path.join(REPO_ROOT, rel), 'utf8');
      assert.match(content, /^---\nname:\s+\S+\ndescription:\s+.+/m, `${rel} must start with valid frontmatter`);
      assert.doesNotMatch(content, /check-hook-activation-handshake/, `${rel} must not require canary handshake`);
      assert.doesNotMatch(content, /\.hook-canary-sentinel/, `${rel} must not reference canary sentinel`);
      assert.doesNotMatch(content, /ERROR_STOP/, `${rel} must not contain ADR-0023 ERROR_STOP`);
    }
  });

  it('ship and sdd-gate skills wire directly to v2 Node.js ESM guardrail tools', () => {
    const ship = fs.readFileSync(path.join(REPO_ROOT, 'plugins/sdd-ship/skills/ship/SKILL.md'), 'utf8');
    const gate = fs.readFileSync(path.join(REPO_ROOT, 'plugins/sdd-quality-loop/skills/sdd-gate/SKILL.md'), 'utf8');
    assert.match(ship, /record-spec-baseline\.mjs/);
    assert.match(ship, /sdd-gate/);
    assert.match(gate, /run-sdd-gate\.mjs/);
    assert.match(gate, /check-spec-drift\.mjs/);
  });

  it('spec-check defines risk-scaled single and dual-parallel (Risk: high) 1-pass review modes', () => {
    const specCheck = fs.readFileSync(
      path.join(REPO_ROOT, 'plugins/sdd-review-loop/skills/spec-check/SKILL.md'),
      'utf8',
    );
    assert.match(specCheck, /dual-parallel/);
    assert.match(specCheck, /Reviewer A/);
    assert.match(specCheck, /Reviewer B/);
    assert.match(specCheck, /Risk: high/);
    assert.doesNotMatch(specCheck, /--reset --feature/);
  });

  it('all active core, implementation, Gemini, and command prompts have zero retired v1 contradictions', () => {
    const activePrompts = [
      'plugins/sdd-bootstrap/skills/bootstrap/SKILL.md',
      'plugins/sdd-bootstrap/skills/sdd-core-spec/SKILL.md',
      'plugins/sdd-bootstrap/GEMINI.md',
      'plugins/sdd-bootstrap/commands/sdd-bootstrap/bootstrap.toml',
      'plugins/sdd-review-loop/skills/spec-check/SKILL.md',
      'plugins/sdd-review-loop/GEMINI.md',
      'plugins/sdd-implementation/skills/implement-task/SKILL.md',
      'plugins/sdd-implementation/skills/implement-tasks/SKILL.md',
      'plugins/sdd-implementation/skills/diagnose/SKILL.md',
      'plugins/sdd-implementation/gemini/GEMINI.md',
      'plugins/sdd-quality-loop/skills/sdd-gate/SKILL.md',
      'plugins/sdd-quality-loop/skills/fix-by-review-ticket/SKILL.md',
      'plugins/sdd-quality-loop/gemini/GEMINI.md',
      'plugins/sdd-ship/skills/ship/SKILL.md',
      'plugins/sdd-ship/GEMINI.md',
      'plugins/sdd-ship/commands/sdd-ship/ship.toml',
    ];
    const forbiddenRe =
      /check-hook-activation-handshake|\.hook-canary-sentinel|ERROR_STOP|SDD_SUDO|\bsdd-lite\b|\blite-spec\b|\blite-gate\b|\bspec-review-loop\b|\bimpl-review-loop\b|\btask-review-loop\b|\bsdd-bootstrap-interviewer\b|\bquality-gate\b(?!\/)|Risk:[^\n]*critical/i;

    for (const rel of activePrompts) {
      const content = fs.readFileSync(path.join(REPO_ROOT, rel), 'utf8');
      const match = content.match(forbiddenRe);
      assert.equal(match, null, `${rel} contains retired v1 term: ${match?.[0]}`);
    }

    assert.equal(
      fs.existsSync(path.join(REPO_ROOT, 'plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer')),
      false,
      'duplicate legacy sdd-bootstrap-interviewer skill must be removed',
    );
    assert.equal(
      fs.existsSync(path.join(REPO_ROOT, 'plugins/sdd-quality-loop/skills/quality-gate')),
      false,
      'duplicate legacy quality-gate skill must be removed',
    );
  });

  it('SDD Core templates include REQ/AC/Risk structure and Spec Amendments section', () => {
    const req = fs.readFileSync(
      path.join(REPO_ROOT, 'plugins/sdd-bootstrap/skills/sdd-core-spec/templates/requirements.md'),
      'utf8',
    );
    const des = fs.readFileSync(
      path.join(REPO_ROOT, 'plugins/sdd-bootstrap/skills/sdd-core-spec/templates/design.md'),
      'utf8',
    );
    const tsk = fs.readFileSync(
      path.join(REPO_ROOT, 'plugins/sdd-bootstrap/skills/sdd-core-spec/templates/tasks.md'),
      'utf8',
    );
    assert.match(req, /REQ-001/);
    assert.match(req, /AC-001/);
    assert.match(req, /## Spec Amendments/);
    assert.match(des, /## Spec Amendments/);
    assert.match(tsk, /Approval: Draft/);
    assert.match(tsk, /Risk: standard/);
    assert.match(tsk, /## Spec Amendments/);
  });
});

describe('#827 re-verifying a fixed review ticket reaches the gate for exactly that task', () => {
  it('fix-by-review-ticket names the ticket task in the ship call, and ship auto-selection includes Implementation Complete', () => {
    const fix = fs.readFileSync(path.join(REPO_ROOT, 'plugins/sdd-quality-loop/skills/fix-by-review-ticket/SKILL.md'), 'utf8');
    const ship = fs.readFileSync(path.join(REPO_ROOT, 'plugins/sdd-ship/skills/ship/SKILL.md'), 'utf8');
    assert.match(fix, /\/sdd-ship:ship specs\/<feature>\/tasks\.md#<task-id>/, 'the re-run names the ticket feature and task');
    assert.match(fix, /<task-id>` が欠けている場合[^\n]*停止/, 'a ticket without feature and task stops instead of guessing');
    const selection = ship.split('### Step 1')[1].split('### Step 2')[0];
    assert.match(selection, /Implementation Complete/, 'a feature whose only open work awaits the gate is selectable');
  });
});

describe('#832 a Done task affected by a spec change has a re-verification path', () => {
  it('ship re-runs the gate for an affected Done task and sdd-gate accepts it without changing its status', () => {
    const ship = fs.readFileSync(path.join(REPO_ROOT, 'plugins/sdd-ship/skills/ship/SKILL.md'), 'utf8');
    const gate = fs.readFileSync(path.join(REPO_ROOT, 'plugins/sdd-quality-loop/skills/sdd-gate/SKILL.md'), 'utf8');
    assert.match(ship, /影響を受けた `Done` タスク[^\n]*sdd-gate[^\n]*再実行/);
    assert.match(ship, /Status[^\n]*変えない|状態を変えず/);
    assert.match(gate.split('## Process')[0], /再検証[^\n]*`Done`|`Done`[^\n]*再検証/);
  });
});

describe('human concept-test decisions at the public gate', () => {
  function linkedPackage(t) {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-installed-alias-'));
    t.after(() => fs.rmSync(tmp, { recursive: true, force: true }));
    const link = path.join(tmp, 'install-root');
    fs.symlinkSync(REPO_ROOT, link, process.platform === 'win32' ? 'junction' : 'dir');
    return path.join(link, 'plugins/sdd-quality-loop/scripts/v2');
  }
  function setup(t, gateScript = GATE_SCRIPT) {
    const repo = setupCoreRepo();
    t.after(() => fs.rmSync(repo, { recursive: true, force: true }));
    const feature = path.join(repo, 'specs/payments');
    function run(root = repo, options = {}) {
      const { env = process.env, commands = ['--cmd', 'unit=node -e "require(\'fs\').writeFileSync(\'ran\',\'yes\')"'] } = options;
      const response = spawnSync(process.execPath, [
        gateScript, '--root', root, '--feature', 'payments', '--task', 'T-001',
        '--skip-drift', '--skip-sensors', '--changed-files', 'src/refund.js',
        ...commands,
      ], { encoding: 'utf8', env });
      const report = JSON.parse(response.stdout);
      assert.equal(response.status, report.verdict === 'PASS' ? 0 : 1);
      return report;
    }
    function git(...args) {
      const response = spawnSync('git', ['-c', 'user.name=test', '-c', 'user.email=test@example.invalid', ...args],
        { cwd: repo, encoding: 'utf8' });
      assert.equal(response.status, 0, response.stderr);
    }
    function expectBlock() {
      const report = run();
      assert.equal(report.verdict, 'FAIL');
      assert.equal(report.checks.conceptTest.status, 'BLOCK');
      assert.deepEqual(report.checks.commands, []);
      assert.equal(fs.existsSync(path.join(repo, 'ran')), false);
    }
    return { repo, feature, run, git, expectBlock };
  }

  it('stops incomplete, malformed and receipt-only projects before verification', (t) => {
    const { feature, expectBlock } = setup(t);
    const proposal = path.join(feature, 'concept-test.json');
    fs.writeFileSync(proposal, JSON.stringify({ schema: 'concept-test/v2' }));
    expectBlock();
    fs.writeFileSync(proposal, '{');
    expectBlock();
    fs.writeFileSync(proposal, '{"schema":"concept-test/v2","schema":"concept-test/v1"}');
    expectBlock();
    fs.unlinkSync(proposal);
    const mirror = path.join(feature, 'concept-test.md');
    fs.writeFileSync(mirror, '```json\n{"schema":"concept-test/v2"}\n```\n');
    expectBlock();
    fs.unlinkSync(mirror);
    fs.writeFileSync(path.join(feature, 'concept-test.decision.json'), '{}');
    expectBlock();
  });

  it('runs the packaged validator through a symlink for FITS and all three local decisions, and rejects stale inputs', (t) => {
    const { repo, feature, run, expectBlock } = setup(t, path.join(linkedPackage(t), 'run-sdd-gate.mjs'));
    const files = ['domain/domain-contract.json', 'domain/context-map.md', 'specs/payments/concept-test-seed.md'];
    fs.mkdirSync(path.join(repo, 'domain'));
    fs.writeFileSync(path.join(repo, files[0]), JSON.stringify({
      schema: 'domain-contract/v2',
      meta: { version: '1.0.0', status: 'Approved', generated_from: [files[1]] },
      contexts: [{ name: 'billing', description: 'Payments', terms: [], aggregates: [] }],
      concepts: [{ id: 'CONCEPT-REFUND', name: 'Refund', context: 'billing', definition: 'Return a payment',
        essence: 'Reimbursement', responsibilities: ['Repay customer'], evidence: [files[1]] }],
    }));
    fs.writeFileSync(path.join(repo, files[1]), 'Domain-Model-Status: Approved\n');
    fs.writeFileSync(path.join(repo, files[2]), 'Refund a payment.\n');
    const digest = filename => createHash('sha256').update(fs.readFileSync(filename)).digest('hex');
    const proposal = { schema: 'concept-test/v2', feature: 'payments', proposal: 'FITS_EXISTING_CONCEPTS',
      rationale: 'The refund has the same responsibility.',
      distinctions: [{ concepts: ['CONCEPT-REFUND'], judgment: 'same', confirmed: true }],
      inputs: files.map(file => ({ path: file, sha256: digest(path.join(repo, file)) })) };
    const json = path.join(feature, 'concept-test.json');
    const md = path.join(feature, 'concept-test.md');
    const receipt = path.join(feature, 'concept-test.decision.json');
    const commandMarker = path.join(repo, 'ran');
    function saveProposal() {
      fs.writeFileSync(json, JSON.stringify(proposal));
      fs.writeFileSync(md, '# Concept Test\n\n```json\n' + JSON.stringify(proposal) + '\n```\n');
    }
    function expectResult(status) {
      const report = run();
      assert.equal(report.checks.conceptTest.status, status, JSON.stringify(report.checks.conceptTest));
      const proceed = status === 'CONTINUE';
      assert.equal(report.verdict, proceed ? 'PASS' : 'FAIL');
      assert.equal(fs.existsSync(commandMarker), proceed);
      assert.equal(report.checks.commands.length, proceed ? 1 : 0);
      if (proceed) fs.unlinkSync(commandMarker);
    }
    saveProposal();
    expectResult('CONTINUE');
    proposal.proposal = 'REQUIRES_HUMAN_DECISION';
    saveProposal();
    expectBlock();
    const decision = { schema: 'concept-test-decision/v1', feature: 'payments',
      proposal_json_sha256: digest(json), proposal_md_sha256: digest(md) };
    for (const [value, expected] of [['defer-to-domain-update', 'DEFER'], ['rejected', 'REJECT'], ['proceed', 'CONTINUE']]) {
      fs.writeFileSync(receipt, JSON.stringify({ ...decision, decision: value }));
      expectResult(expected);
    }
    fs.appendFileSync(path.join(repo, files[2]), 'The customer changed the request.\n');
    expectBlock();
  });

  it('records a baseline when invoked through an install symlink', (t) => {
    const scripts = linkedPackage(t);
    const { repo, feature } = setup(t);
    const record = spawnSync(process.execPath, [path.join(scripts, 'record-spec-baseline.mjs'),
      '--root', repo, '--feature', 'payments'], { encoding: 'utf8' });
    assert.equal(record.status, 0, record.stderr);
    assert.equal(fs.existsSync(path.join(feature, '.spec-baseline.json')), true, record.stdout);
    assert.equal(JSON.parse(record.stdout).status, 'RECORDED');
  });

  it('rejects human receipt edits when invoked through an install symlink', (t) => {
    const scripts = linkedPackage(t);
    const { repo, feature } = setup(t);
    const guard = spawnSync(process.execPath, [path.join(scripts, 'sdd-soft-guard.mjs'), '--root', repo],
      { cwd: repo, encoding: 'utf8', input: JSON.stringify({ tool_name: 'Edit',
        tool_input: { file_path: path.join(feature, 'concept-test.decision.json') } }) });
    assert.equal(guard.status, 2);
    assert.match(guard.stderr, /concept-test\.decision\.json/);
  });

  it('blocks a v1-only Concept Test record with a migration hint, before any command runs', (t) => {
    const { repo, feature, git, run } = setup(t);
    git('init', '-q');
    const legacy = JSON.stringify({ schema: 'concept-test/v1' });
    fs.writeFileSync(path.join(feature, 'concept-test.json'), legacy);
    fs.writeFileSync(path.join(feature, 'concept-test.md'), '```json\n' + legacy + '\n```\n');
    git('add', 'specs');
    git('commit', '-qm', 'legacy record');
    const report = run();
    assert.equal(report.verdict, 'FAIL');
    assert.equal(report.checks.conceptTest.status, 'BLOCK');
    assert.match(report.checks.conceptTest.error, /concept-test\/v1 records are no longer supported/);
    assert.deepEqual(report.checks.commands, []);
  });

  it('preserves ordinary and v1-only feature history and scopes receipts by feature', (t) => {
    const { repo, feature, git, run } = setup(t);
    git('init', '-q');
    const markdown = path.join(feature, 'concept-test.md');
    fs.writeFileSync(markdown, '# Concept Test\nThe classification is still under discussion.\n');
    git('add', 'specs');
    git('commit', '-qm', 'start narrative concept draft');
    const legacy = JSON.stringify({ schema: 'concept-test/v1' });
    fs.writeFileSync(path.join(feature, 'concept-test.json'), legacy);
    fs.writeFileSync(markdown, '```json\n' + legacy + '\n```\n');
    fs.mkdirSync(path.join(repo, 'specs/other'));
    fs.writeFileSync(path.join(repo, 'specs/other/concept-test.decision.json'), '{}');
    git('add', 'specs');
    git('commit', '-qm', 'legacy project');
    const report = run();
    assert.equal(report.verdict, 'PASS');
    assert.equal(report.checks.conceptTest.status, 'NOT_APPLICABLE');
    assert.equal(report.checks.commands[0].passed, true);
  });

  it('keeps the Node-only path without a Git executable but blocks visible v2 evidence', (t) => {
    const { repo, feature, run, git } = setup(t);
    git('init', '-q');
    const env = { ...process.env, PATH: path.join(repo, 'empty-path') };
    const ordinary = run(repo, { env, commands: [] });
    assert.equal(ordinary.verdict, 'PASS');
    assert.equal(ordinary.checks.conceptTest.history, 'GIT_UNAVAILABLE');
    fs.writeFileSync(path.join(feature, 'concept-test.decision.json'), '{}');
    const enrolled = run(repo, { env, commands: [] });
    assert.equal(enrolled.verdict, 'FAIL');
    assert.equal(enrolled.checks.conceptTest.status, 'BLOCK');
  });

  it('detects an indexed proposal missing from the working tree in an unborn repository', (t) => {
    const { feature, git, expectBlock } = setup(t);
    git('init', '-q');
    const file = path.join(feature, 'concept-test.json');
    fs.writeFileSync(file, JSON.stringify({ schema: 'concept-test/v2' }));
    git('add', 'specs');
    fs.unlinkSync(file);
    expectBlock();
    fs.writeFileSync(file, '{');
    git('add', 'specs');
    fs.unlinkSync(file);
    expectBlock();
  });

  it('scopes index evidence to the nested project with the same feature name', (t) => {
    const { repo, git, run } = setup(t);
    git('init', '-q');
    const nested = path.join(repo, 'application');
    fs.mkdirSync(nested);
    for (const name of ['specs', 'src']) fs.cpSync(path.join(repo, name), path.join(nested, name), { recursive: true });
    const receipt = path.join(nested, 'specs/payments/concept-test.decision.json');
    fs.writeFileSync(receipt, '{}');
    git('add', 'application');
    fs.unlinkSync(receipt);
    const parent = run();
    assert.equal(parent.checks.conceptTest.status, 'NOT_APPLICABLE');
    assert.equal(parent.checks.commands.length, 1);
    const child = run(nested);
    assert.equal(child.checks.conceptTest.status, 'BLOCK');
    assert.deepEqual(child.checks.commands, []);
  });

  it('uses current proposal and decision inputs equally in full and shallow clones', (t) => {
    const { repo, feature, git, run } = setup(t);
    git('init', '-q');
    const proposal = path.join(feature, 'concept-test.json');
    const receipt = path.join(feature, 'concept-test.decision.json');
    fs.writeFileSync(proposal, JSON.stringify({ schema: 'concept-test/v2' }));
    git('add', 'specs', 'src');
    git('commit', '-qm', 'proposal draft');
    fs.unlinkSync(proposal);
    fs.writeFileSync(receipt, '{}');
    git('add', 'specs');
    git('commit', '-qm', 'receipt draft');
    fs.unlinkSync(receipt);
    git('commit', '-qam', 'current inputs');
    const copies = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-clone-gate-'));
    t.after(() => fs.rmSync(copies, { recursive: true, force: true }));
    for (const [name, options] of [['full', []], ['shallow', ['--depth', '1']]]) {
      const checkout = path.join(copies, name);
      git('clone', '-q', ...options, pathToFileURL(repo).href, checkout);
      const report = run(checkout);
      assert.equal(report.checks.conceptTest.status, 'NOT_APPLICABLE', name);
      assert.equal(report.verdict, 'PASS');
      assert.equal(report.checks.commands.length, 1);
      assert.equal(fs.readFileSync(path.join(checkout, 'ran'), 'utf8'), 'yes');
    }
  });

  it('distinguishes unstaged proposal loss from a staged change of inputs', (t) => {
    const { feature, git, run, expectBlock } = setup(t);
    git('init', '-q');
    const file = path.join(feature, 'concept-test.json');
    fs.writeFileSync(file, JSON.stringify({ schema: 'concept-test/v2' }));
    git('add', 'specs');
    git('commit', '-qm', 'proposal draft');
    fs.unlinkSync(file);
    expectBlock();
    git('add', '-u');
    const report = run();
    assert.equal(report.checks.conceptTest.status, 'NOT_APPLICABLE');
    assert.equal(report.checks.commands.length, 1);
  });
});
