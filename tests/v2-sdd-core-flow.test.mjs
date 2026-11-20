import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';

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
