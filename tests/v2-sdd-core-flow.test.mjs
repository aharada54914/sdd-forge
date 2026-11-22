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

  it('reads the right paths for a nested project and detects a committed receipt deletion', (t) => {
    const { repo, git, run } = setup(t);
    git('init', '-q');
    const nested = path.join(repo, 'application');
    fs.mkdirSync(nested);
    for (const name of ['specs', 'src']) fs.renameSync(path.join(repo, name), path.join(nested, name));
    const receipt = path.join(nested, 'specs/payments/concept-test.decision.json');
    fs.writeFileSync(receipt, '{}');
    git('add', 'application');
    git('commit', '-qm', 'record receipt');
    fs.unlinkSync(receipt);
    git('commit', '-qam', 'remove receipt');
    const report = run(nested);
    assert.equal(report.checks.conceptTest.status, 'BLOCK');
    assert.equal(report.verdict, 'FAIL');
    assert.deepEqual(report.checks.commands, []);
  });

  it('checks the available history of shallow clones and preserves its explicit boundary', (t) => {
    const { repo, feature, git, run } = setup(t);
    git('init', '-q');
    const file = path.join(feature, 'concept-test.json');
    fs.writeFileSync(file, JSON.stringify({ schema: 'concept-test/v2' }));
    git('add', 'specs', 'src');
    git('commit', '-qm', 'new proposal');
    fs.unlinkSync(file);
    git('commit', '-qam', 'remove proposal');
    git('commit', '--allow-empty', '-qm', 'later work');
    const copies = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-shallow-gate-'));
    t.after(() => fs.rmSync(copies, { recursive: true, force: true }));
    for (const [depth, expected] of [[1, 'NOT_APPLICABLE'], [3, 'BLOCK']]) {
      const checkout = path.join(copies, 'depth-' + depth);
      git('clone', '-q', '--depth', String(depth), pathToFileURL(repo).href, checkout);
      const report = run(checkout);
      assert.equal(report.checks.conceptTest.status, expected);
      assert.equal(report.verdict, depth === 1 ? 'PASS' : 'FAIL');
      assert.equal(report.checks.commands.length, depth === 1 ? 1 : 0);
    }
  });

  it('detects previously committed v2 even after a committed downgrade to v1', (t) => {
    const { feature, git, expectBlock } = setup(t);
    git('init', '-q');
    const file = path.join(feature, 'concept-test.json');
    fs.writeFileSync(file, JSON.stringify({ schema: 'concept-test/v2' }));
    git('add', 'specs');
    git('commit', '-qm', 'new proposal');
    fs.writeFileSync(file, JSON.stringify({ schema: 'concept-test/v1' }));
    git('commit', '-qam', 'restore old format');
    expectBlock();
  });
});
