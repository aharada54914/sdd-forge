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
const CHECK_SCRIPT = path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/check-spec-drift.mjs');

function setupFeatureRepo() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-v2-drift-'));
  fs.mkdirSync(path.join(dir, '.git'));
  fs.mkdirSync(path.join(dir, 'specs', 'checkout'), { recursive: true });

  fs.writeFileSync(
    path.join(dir, 'specs', 'checkout', 'requirements.md'),
    [
      '# Requirements: checkout',
      '',
      '- **REQ-001**: Compute subtotal and tax accurately.',
      '- **AC-001**: Tax is rounded half-up to nearest yen.',
      '- **AC-002**: Empty cart returns HTTP 400.',
      '',
      '## Spec Amendments',
      '- （初期版のため変更なし）',
      '',
    ].join('\n'),
    'utf8',
  );

  fs.writeFileSync(
    path.join(dir, 'specs', 'checkout', 'design.md'),
    [
      '# Design: checkout',
      '',
      '## Approach',
      'Use Decimal-safe integer yen arithmetic.',
      '',
      '## Spec Amendments',
      '- None',
      '',
    ].join('\n'),
    'utf8',
  );

  fs.writeFileSync(
    path.join(dir, 'specs', 'checkout', 'tasks.md'),
    [
      '# Tasks: checkout',
      '',
      '## T-001 Implement tax calculator',
      'Approval: Approved',
      'Status: Planned',
      'Risk: standard',
      '',
      '### Done When',
      '- AC-001 and AC-002 pass',
      '',
      '## Spec Amendments',
      '- None',
      '',
    ].join('\n'),
    'utf8',
  );

  return dir;
}

function runRecord(repo, feature) {
  return spawnSync(process.execPath, [RECORD_SCRIPT, '--feature', feature, '--root', repo], {
    cwd: repo,
    encoding: 'utf8',
  });
}

function runCheck(repo, feature, extraArgs = []) {
  return spawnSync(process.execPath, [CHECK_SCRIPT, '--feature', feature, '--root', repo, ...extraArgs], {
    cwd: repo,
    encoding: 'utf8',
  });
}

describe('record-spec-baseline.mjs & check-spec-drift.mjs', () => {
  it('AC-008: reports CLEAN on unchanged specs and after normal tasks.md Status transitions', () => {
    const repo = setupFeatureRepo();
    const rec = runRecord(repo, 'checkout');
    assert.equal(rec.status, 0, rec.stderr);

    const cleanRes = runCheck(repo, 'checkout');
    assert.equal(cleanRes.status, 0);
    assert.equal(JSON.parse(cleanRes.stdout).status, 'CLEAN');

    // Update tasks.md Status: Planned -> Done (should stay CLEAN)
    const tasksPath = path.join(repo, 'specs', 'checkout', 'tasks.md');
    fs.writeFileSync(tasksPath, fs.readFileSync(tasksPath, 'utf8').replace('Status: Planned', 'Status: Done'), 'utf8');

    const afterStatus = runCheck(repo, 'checkout', ['--fail-on-undeclared']);
    assert.equal(afterStatus.status, 0);
    const parsed = JSON.parse(afterStatus.stdout);
    assert.equal(parsed.status, 'CLEAN');
    assert.deepEqual(parsed.changedFiles, []);
  });

  it('AC-009: detects silent goalpost moving (deleted/modified AC) as UNDECLARED_DRIFT', () => {
    const repo = setupFeatureRepo();
    assert.equal(runRecord(repo, 'checkout').status, 0);

    // Silently weaken AC-001 and delete AC-002 without recording an amendment
    const reqPath = path.join(repo, 'specs', 'checkout', 'requirements.md');
    fs.writeFileSync(
      reqPath,
      [
        '# Requirements: checkout',
        '',
        '- **REQ-001**: Compute subtotal and tax accurately.',
        '- **AC-001**: Tax is truncated instead of half-up.',
        '',
        '## Spec Amendments',
        '- （初期版のため変更なし）',
        '',
      ].join('\n'),
      'utf8',
    );

    const driftRes = runCheck(repo, 'checkout', ['--fail-on-undeclared']);
    assert.equal(driftRes.status, 1);
    const report = JSON.parse(driftRes.stdout);
    assert.equal(report.status, 'UNDECLARED_DRIFT');
    assert.deepEqual(report.changedFiles, ['specs/checkout/requirements.md']);
    assert.equal(report.modifiedIdentifiers.length, 1);
    assert.equal(report.modifiedIdentifiers[0].id, 'AC-001');
    assert.equal(report.removedIdentifiers.length, 1);
    assert.equal(report.removedIdentifiers[0].id, 'AC-002');
  });

  it('AC-010: reports AMENDED with PR-ready markdown when rationale is recorded in Spec Amendments', () => {
    const repo = setupFeatureRepo();
    assert.equal(runRecord(repo, 'checkout').status, 0);

    const reqPath = path.join(repo, 'specs', 'checkout', 'requirements.md');
    fs.writeFileSync(
      reqPath,
      [
        '# Requirements: checkout',
        '',
        '- **REQ-001**: Compute subtotal and tax accurately.',
        '- **AC-001**: Tax is rounded half-up to nearest yen.',
        '- **AC-002**: Empty cart returns HTTP 422.',
        '',
        '## Spec Amendments',
        '- 2026-11-21: Agreed with PO to change AC-002 empty-cart status from 400 to 422.',
        '',
      ].join('\n'),
      'utf8',
    );

    const jsonRes = runCheck(repo, 'checkout', ['--fail-on-undeclared']);
    assert.equal(jsonRes.status, 0);
    const report = JSON.parse(jsonRes.stdout);
    assert.equal(report.status, 'AMENDED');
    assert.equal(report.modifiedIdentifiers[0].id, 'AC-002');

    const mdRes = runCheck(repo, 'checkout', ['--format', 'markdown']);
    assert.equal(mdRes.status, 0);
    assert.match(mdRes.stdout, /AMENDED \(Reviewable\)/);
    assert.match(mdRes.stdout, /specs\/checkout\/requirements\.md/);
    assert.match(mdRes.stdout, /AC-002/);
    assert.match(mdRes.stdout, /Agreed with PO to change AC-002/);
  });
});

describe('#820 AMENDED names the changed IDs no amendment entry mentions', () => {
  it('two changed ACs with a reason for only one stay AMENDED but list the unexplained one', () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-amend-'));
    fs.mkdirSync(path.join(dir, '.git'));
    fs.mkdirSync(path.join(dir, 'specs', 'f'), { recursive: true });
    const req = (a1, a2, amend) =>
      `# r\n\n- **REQ-001**: x\n- **AC-001** (REQ-001): ${a1}\n- **AC-002** (REQ-001): ${a2}\n\n## Spec Amendments\n${amend}\n`;
    fs.writeFileSync(path.join(dir, 'specs', 'f', 'requirements.md'), req('one', 'two', '- （初期版のため変更なし）'), 'utf8');
    fs.writeFileSync(path.join(dir, 'specs', 'f', 'tasks.md'), '# t\n\n## T-001 x\nApproval: Approved\nStatus: Planned\n', 'utf8');
    assert.equal(spawnSync(process.execPath, [RECORD_SCRIPT, '--feature', 'f', '--root', dir], { encoding: 'utf8' }).status, 0);
    fs.writeFileSync(
      path.join(dir, 'specs', 'f', 'requirements.md'),
      req('one changed', 'two changed', '- 2026-11-25: AC-001 の閾値を顧客合意により変更'),
      'utf8',
    );
    const res = spawnSync(process.execPath, [CHECK_SCRIPT, '--feature', 'f', '--root', dir], { encoding: 'utf8' });
    const out = JSON.parse(res.stdout);
    assert.equal(out.status, 'AMENDED');
    assert.deepEqual(out.changedIdsWithoutAmendment, ['AC-002']);

    // An amendment written before the baseline does not explain a later change.
    fs.writeFileSync(path.join(dir, 'specs', 'f', 'requirements.md'), req('one', 'two', '- 2026-01-01: AC-002 の初期調整'), 'utf8');
    assert.equal(
      spawnSync(process.execPath, [RECORD_SCRIPT, '--feature', 'f', '--root', dir, '--rerecord'], { encoding: 'utf8' }).status,
      0,
    );
    fs.writeFileSync(
      path.join(dir, 'specs', 'f', 'requirements.md'),
      req('one changed', 'two changed', '- 2026-01-01: AC-002 の初期調整\n- 2026-11-25: AC-001 を変更'),
      'utf8',
    );
    const later = JSON.parse(spawnSync(process.execPath, [CHECK_SCRIPT, '--feature', 'f', '--root', dir], { encoding: 'utf8' }).stdout);
    assert.equal(later.status, 'AMENDED');
    assert.deepEqual(later.changedIdsWithoutAmendment, ['AC-002']);

    // Entries are counted per file: a new design.md entry must not make an old
    // requirements.md entry look new (re-review finding).
    const design = (amend) => `# d\n\nREQ-001 design note\n\n## Spec Amendments\n${amend}\n`;
    fs.writeFileSync(path.join(dir, 'specs', 'f', 'requirements.md'), req('one', 'two', '- 2026-01-01: AC-001 の初期調整'), 'utf8');
    fs.writeFileSync(path.join(dir, 'specs', 'f', 'design.md'), design('- 2026-01-02: 設計メモ'), 'utf8');
    assert.equal(
      spawnSync(process.execPath, [RECORD_SCRIPT, '--feature', 'f', '--root', dir, '--rerecord'], { encoding: 'utf8' }).status,
      0,
    );
    fs.writeFileSync(path.join(dir, 'specs', 'f', 'requirements.md'), req('one changed', 'two changed', '- 2026-01-01: AC-001 の初期調整'), 'utf8');
    fs.writeFileSync(path.join(dir, 'specs', 'f', 'design.md'), design('- 2026-01-02: 設計メモ\n- 2026-11-25: AC-002 の理由'), 'utf8');
    const perFile = JSON.parse(spawnSync(process.execPath, [CHECK_SCRIPT, '--feature', 'f', '--root', dir], { encoding: 'utf8' }).stdout);
    assert.equal(perFile.status, 'AMENDED');
    assert.deepEqual(perFile.changedIdsWithoutAmendment, ['AC-001']);
    fs.rmSync(dir, { recursive: true, force: true });
  });
});

describe('#818 staged human approval is not spec drift', () => {
  const addDraftTask = (repo) => {
    const tasksPath = path.join(repo, 'specs', 'checkout', 'tasks.md');
    const text = fs.readFileSync(tasksPath, 'utf8').replace(
      '## Spec Amendments',
      '## T-002 Render receipt\nApproval: Draft\nStatus: Planned\nRisk: standard\n\n### Done When\n- AC-002 passes\n\n## Spec Amendments',
    );
    fs.writeFileSync(tasksPath, text, 'utf8');
    return tasksPath;
  };
  const edit = (file, from, to) => fs.writeFileSync(file, fs.readFileSync(file, 'utf8').replace(from, to), 'utf8');

  it('approving a second task stays CLEAN and is listed; revoking an approval or editing the body is drift', () => {
    const repo = setupFeatureRepo();
    const tasksPath = addDraftTask(repo);
    assert.equal(runRecord(repo, 'checkout').status, 0);

    edit(tasksPath, 'Approval: Draft', 'Approval: Approved');
    const approved = runCheck(repo, 'checkout', ['--fail-on-undeclared']);
    assert.equal(approved.status, 0, approved.stdout);
    const approvedResult = JSON.parse(approved.stdout);
    assert.equal(approvedResult.status, 'CLEAN');
    assert.deepEqual(approvedResult.newlyApprovedTasks, ['T-002']);

    edit(tasksPath, 'Approval: Approved\nStatus: Planned\nRisk: standard\n\n### Done When\n- AC-001', 'Approval: Draft\nStatus: Planned\nRisk: standard\n\n### Done When\n- AC-001');
    const revoked = JSON.parse(runCheck(repo, 'checkout').stdout);
    assert.equal(revoked.status, 'UNDECLARED_DRIFT');
    assert.deepEqual(revoked.revokedApprovals, ['T-001']);

    edit(tasksPath, 'Approval: Draft\nStatus: Planned\nRisk: standard\n\n### Done When\n- AC-001', 'Approval: Approved\nStatus: Planned\nRisk: standard\n\n### Done When\n- AC-001');
    edit(tasksPath, '- AC-002 passes', '- AC-002 passes for carts of any size');
    assert.equal(JSON.parse(runCheck(repo, 'checkout').stdout).status, 'UNDECLARED_DRIFT', 'body edits stay drift');
  });

  it('a baseline recorded before this change keeps its old comparison', () => {
    const repo = setupFeatureRepo();
    const tasksPath = addDraftTask(repo);
    assert.equal(runRecord(repo, 'checkout').status, 0);
    const baselinePath = path.join(repo, 'specs', 'checkout', '.spec-baseline.json');
    const baseline = JSON.parse(fs.readFileSync(baselinePath, 'utf8'));
    for (const info of Object.values(baseline.files)) {
      delete info.approvalContractSha256;
      delete info.taskApprovals;
    }
    fs.writeFileSync(baselinePath, JSON.stringify(baseline), 'utf8');
    assert.equal(JSON.parse(runCheck(repo, 'checkout').stdout).status, 'CLEAN');
    edit(tasksPath, 'Approval: Draft', 'Approval: Approved');
    assert.equal(JSON.parse(runCheck(repo, 'checkout').stdout).status, 'UNDECLARED_DRIFT', 'old baselines cannot tell approval from body edits');
  });
});

describe('#834 unreadable spec files are reported apart from deletions', () => {
  it('an existing file the IO cannot read is UNVERIFIABLE; drift elsewhere still wins', async () => {
    const { checkSpecDriftCore } = await import('../plugins/sdd-quality-loop/scripts/v2/v2-readonly-core.mjs');
    const { createFsReadonlyIo } = await import('../plugins/sdd-quality-loop/scripts/v2/guardrails-lib.mjs');
    const repo = setupFeatureRepo();
    assert.equal(runRecord(repo, 'checkout').status, 0);
    const real = createFsReadonlyIo(repo);
    const capped = { ...real, readText: (rel) => (rel.endsWith('/design.md') ? null : real.readText(rel)) };

    const unreadable = checkSpecDriftCore(capped, { feature: 'checkout' });
    assert.equal(unreadable.status, 'UNVERIFIABLE');
    assert.deepEqual(unreadable.unreadableFiles, ['specs/checkout/design.md']);
    assert.deepEqual(unreadable.deletedFiles, []);

    const reqPath = path.join(repo, 'specs', 'checkout', 'requirements.md');
    fs.writeFileSync(reqPath, fs.readFileSync(reqPath, 'utf8').replace('HTTP 400', 'HTTP 422'), 'utf8');
    assert.equal(checkSpecDriftCore(capped, { feature: 'checkout' }).status, 'UNDECLARED_DRIFT');
    const res = runCheck(repo, 'checkout', ['--fail-on-undeclared']);
    assert.equal(res.status, 1);
  });
});

describe('#972 review: unreadable and newly approved are visible and enforced', () => {
  const GATE = path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/run-sdd-gate.mjs');
  const breakDesign = (repo) => {
    // Over the CLI's 8 MiB read cap: present, but not read for drift.
    const design = path.join(repo, 'specs', 'checkout', 'design.md');
    const text = fs.readFileSync(design, 'utf8');
    const cut = text.indexOf('\n') + 1;
    fs.writeFileSync(design, `${text.slice(0, cut)}\n<!-- ${'x'.repeat(9 * 1024 * 1024)} -->\n${text.slice(cut)}`, 'utf8');
  };
  const gate = (repo, task = 'T-001') =>
    spawnSync(process.execPath, [GATE, '--feature', 'checkout', '--task', task, '--root', repo, '--cmd', 'ok=node -e "process.exit(0)"'], { cwd: repo, encoding: 'utf8' });

  it('UNVERIFIABLE alone fails --fail-on-undeclared and the gate; AMENDED plus an unreadable file is UNVERIFIABLE', () => {
    const repo = setupFeatureRepo();
    const tasksPath = path.join(repo, 'specs', 'checkout', 'tasks.md');
    fs.writeFileSync(tasksPath, fs.readFileSync(tasksPath, 'utf8').replace('Status: Planned', 'Status: Implementation Complete'), 'utf8');
    assert.equal(runRecord(repo, 'checkout').status, 0);
    breakDesign(repo);
    const res = runCheck(repo, 'checkout', ['--fail-on-undeclared']);
    assert.equal(JSON.parse(res.stdout).status, 'UNVERIFIABLE');
    assert.equal(res.status, 1, 'UNVERIFIABLE on its own must fail');
    const gated = JSON.parse(gate(repo).stdout);
    assert.equal(gated.checks.specDrift.status, 'UNVERIFIABLE');
    assert.equal(gated.verdict, 'FAIL');

    const reqPath = path.join(repo, 'specs', 'checkout', 'requirements.md');
    fs.writeFileSync(reqPath, fs.readFileSync(reqPath, 'utf8')
      .replace('HTTP 400', 'HTTP 422')
      .replace('- （初期版のため変更なし）', '- 2026-11-25: AC-002 uses 422 (owner agreed).'), 'utf8');
    assert.equal(JSON.parse(runCheck(repo, 'checkout').stdout).status, 'UNVERIFIABLE', 'an amendment does not excuse an unread file');
  });

  it('a task approved after the baseline is listed even when CLEAN, and its gate run warns', () => {
    const repo = setupFeatureRepo();
    const tasksPath = path.join(repo, 'specs', 'checkout', 'tasks.md');
    fs.writeFileSync(tasksPath, fs.readFileSync(tasksPath, 'utf8')
      .replace('Approval: Approved', 'Approval: Draft')
      .replace('Status: Planned', 'Status: Implementation Complete'), 'utf8');
    assert.equal(runRecord(repo, 'checkout').status, 0);
    fs.writeFileSync(tasksPath, fs.readFileSync(tasksPath, 'utf8').replace('Approval: Draft', 'Approval: Approved'), 'utf8');
    const md = runCheck(repo, 'checkout', ['--format', 'markdown']).stdout;
    assert.match(md, /CLEAN/);
    assert.match(md, /T-001/, 'the approval change is shown to the PR reviewer');
    const gated = JSON.parse(gate(repo).stdout);
    assert.ok(gated.warnings.some((w) => /^APPROVED_AFTER_BASELINE: .*T-001/.test(w)), JSON.stringify(gated.warnings));
  });
});

describe('#972 re-review: text added to an Approval line is drift', () => {
  it('only a bare approval value is normalized', () => {
    const repo = setupFeatureRepo();
    const tasksPath = path.join(repo, 'specs', 'checkout', 'tasks.md');
    fs.writeFileSync(tasksPath, fs.readFileSync(tasksPath, 'utf8').replace('Approval: Approved', 'Approval: Draft'), 'utf8');
    assert.equal(runRecord(repo, 'checkout').status, 0);
    fs.writeFileSync(tasksPath, fs.readFileSync(tasksPath, 'utf8').replace('Approval: Draft', 'Approval: Draft — Scope now covers src/** and AC-001 is waived'), 'utf8');
    const res = JSON.parse(runCheck(repo, 'checkout').stdout);
    assert.equal(res.status, 'UNDECLARED_DRIFT');
  });
});

describe('ADR-0054 T-002 (AC-009): git diff Anti-Tampering & CODEOWNERS retirement manifest', () => {
  function initGitRepoWithTests() {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-anti-tamper-'));
    const git = (...args) =>
      spawnSync('git', args, { cwd: dir, encoding: 'utf8', shell: false });
    assert.equal(git('init').status, 0);
    assert.equal(git('config', 'user.email', 'test@example.com').status, 0);
    assert.equal(git('config', 'user.name', 'Test User').status, 0);

    fs.mkdirSync(path.join(dir, 'tests'), { recursive: true });
    fs.mkdirSync(path.join(dir, 'specs', 'demo', 'formal'), { recursive: true });
    fs.mkdirSync(path.join(dir, 'sdd'), { recursive: true });
    fs.writeFileSync(path.join(dir, 'tests', 'sample.test.mjs'), 'import { it } from "node:test";\nit("ok", () => {});\n', 'utf8');
    fs.writeFileSync(path.join(dir, 'specs', 'demo', 'formal', 'Model.tla'), '---- MODULE Model ----\nInv == x >= 0\n====\n', 'utf8');
    fs.writeFileSync(path.join(dir, 'sdd', 'approved-test-retirements.json'), JSON.stringify({ schema: 'sdd-approved-test-retirements/v1', retirements: [] }, null, 2), 'utf8');
    assert.equal(git('add', '.').status, 0);
    assert.equal(git('commit', '-m', 'init').status, 0);
    return { dir, git };
  }

  it('exits 4 on unauthorized test skip injection, inline lint disable, and TLA+ == TRUE weakening', () => {
    const { dir } = initGitRepoWithTests();
    const clean = spawnSync(process.execPath, [CHECK_SCRIPT, '--anti-tamper', '--root', dir], { encoding: 'utf8' });
    assert.equal(clean.status, 0, clean.stderr);
    assert.equal(JSON.parse(clean.stdout).status, 'CLEAN');

    // Construct markers dynamically (WFI-012)
    const skipCall = ['it', '.skip("tampered", () => {});'].join('');
    const disableComment = ['// ', 'sdd-lint', '-disable next-line'].join('');
    fs.writeFileSync(path.join(dir, 'tests', 'sample.test.mjs'), `import { it } from "node:test";\n${skipCall}\n${disableComment}\n`, 'utf8');
    fs.writeFileSync(path.join(dir, 'specs', 'demo', 'formal', 'Model.tla'), '---- MODULE Model ----\nInv == TRUE\n====\n', 'utf8');

    const tampered = spawnSync(process.execPath, [CHECK_SCRIPT, '--anti-tamper', '--root', dir], { encoding: 'utf8' });
    assert.equal(tampered.status, 4);
    const report = JSON.parse(tampered.stdout);
    assert.equal(report.status, 'TAMPER_DETECTED');
    const codes = new Set(report.violations.map((v) => v.code));
    assert.ok(codes.has('TEST_SKIP_ADDED'), JSON.stringify(report.violations));
    assert.ok(codes.has('LINT_DISABLE_ADDED'), JSON.stringify(report.violations));
    assert.ok(codes.has('FORMAL_INVARIANT_WEAKENED'), JSON.stringify(report.violations));
    fs.rmSync(dir, { recursive: true, force: true });
  });

  function runAntiTamper(dir) {
    return spawnSync(process.execPath, [CHECK_SCRIPT, '--anti-tamper', '--root', dir, '--feature', 'demo'], { encoding: 'utf8' });
  }

  it('allows documentation and quoted examples of inline lint directives without opening an OQ', (t) => {
    const { dir, git } = initGitRepoWithTests();
    t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
    const marker = ['sdd-lint', '-disable'].join('');
    fs.writeFileSync(path.join(dir, 'README.md'), [
      'The ' + marker + ' directive is forbidden.',
      '```js', '// ' + marker + ' example', '```',
    ].join('\n'));
    assert.equal(git('add', 'README.md').status, 0);
    fs.appendFileSync(path.join(dir, 'tests/sample.test.mjs'), [
      'const inline = "// ' + marker + ' example";',
      "const block = '/* " + marker + " example */';",
      'const multiline = `', '// ' + marker + ' example', '`;',
      '// Explain the ' + marker + ' directive.',
    ].join('\n'));
    const result = runAntiTamper(dir);
    assert.equal(result.status, 0, result.stdout);
    assert.deepEqual(JSON.parse(result.stdout).violations, []);
    assert.equal(fs.existsSync(path.join(dir, 'reports/verification/demo/anti-tampering')), false);
  });

  it('reports added lint directives in source comments with a persisted OQ', (t) => {
    const { dir } = initGitRepoWithTests();
    t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
    const marker = ['sdd-lint', '-disable'].join('');
    for (const [file, source] of [
      ['tests/sample.test.mjs', 'const x = 1; // ' + marker + ' rule-a\n'],
      ['tests/extra.ts', '/**\n * ' + marker + ' rule-b\n */\n'],
      ['tests/extra.py', 'x = 1  # ' + marker + ' rule-c\n'],
    ]) {
      fs.writeFileSync(path.join(dir, file), source);
    }
    const result = runAntiTamper(dir);
    assert.equal(result.status, 4, result.stdout);
    const { violations, openQuestion } = JSON.parse(result.stdout);
    const expected = ['tests/extra.py', 'tests/extra.ts', 'tests/sample.test.mjs'];
    assert.deepEqual(violations.map(v => v.path).sort(), expected);
    assert.ok(violations.every(v => v.code === 'LINT_DISABLE_ADDED'));
    const persisted = JSON.parse(fs.readFileSync(path.join(dir, openQuestion.path)));
    assert.deepEqual(persisted.violations, violations.map(({ code, path }) => ({ code, path })));
  });

  it('allows renaming an already skipped test and editing existing skip reasons', (t) => {
    const { dir, git } = initGitRepoWithTests();
    t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
    const file = path.join(dir, 'tests/sample.test.mjs');
    const skipped = ['it', '.skip'].join('');
    fs.writeFileSync(file, skipped + '("old description", () => {});\n');
    assert.equal(git('commit', '-am', 'record existing test state').status, 0);
    fs.writeFileSync(file, skipped + '("new description", () => {});\n');
    const report = runAntiTamper(dir);
    assert.equal(report.status, 0, report.stdout);
  });

  it('counts active Node options across layout changes alongside prior Python and Go directives', (t) => {
    const { dir, git } = initGitRepoWithTests();
    t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
    const file = path.join(dir, 'tests/sample.test.mjs');
    const option = ['sk', 'ip'].join('');
    function source(values) {
      return ['const metadata = { ' + option + ': true };',
        ...values.map((value, index) => 'test("case ' + index + '", {\n  timeout: 100,\n  "' + option + '": ' + value + ',\n}, () => {});')].join('\n');
    }
    fs.writeFileSync(file, source(['"old reason"', 'false']));
    assert.equal(git('commit', '-am', 'record conditional test options').status, 0);
    fs.writeFileSync(file, source(['"new reason"', 'false']));
    assert.equal(runAntiTamper(dir).status, 0);
    fs.writeFileSync(file, source(['"new reason"', 'true']));
    const increased = runAntiTamper(dir);
    assert.equal(increased.status, 4, increased.stdout);
    assert.deepEqual(JSON.parse(increased.stdout).violations.map(v => v.code), ['TEST_SKIP_ADDED']);
    fs.writeFileSync(file, source(['false']));
    assert.equal(runAntiTamper(dir).status, 0);
    fs.writeFileSync(file, ['test({ ' + option + ': true }, () => {});',
      'it("conditional", { ' + option + ': process.env.CI }, () => {});'].join('\n'));
    assert.equal(runAntiTamper(dir).status, 4);
    fs.writeFileSync(file, source(['false']));
    for (const [name, marker] of [['sample_test.py', ['@pytest.mark.', 'skip'].join('')],
      ['sample_test.go', ['t.', 'Skip'].join('')]]) {
      fs.writeFileSync(path.join(dir, 'tests', name), marker + '("reason")\n');
      assert.equal(git('add', 'tests/' + name).status, 0);
    }
    assert.deepEqual(JSON.parse(runAntiTamper(dir).stdout).violations.map(v => v.path).sort(),
      ['tests/sample_test.go', 'tests/sample_test.py']);
  });

  it('counts Node test context calls using the callback parameter, including subtests', (t) => {
    const { dir, git } = initGitRepoWithTests();
    t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
    const file = path.join(dir, 'tests/sample.test.mjs');
    const method = ['sk', 'ip'].join('');
    const existing = 'test("context", async (ctx) => { ctx.' + method + '("platform"); });\n';
    fs.writeFileSync(file, existing);
    assert.equal(git('commit', '-am', 'record one platform-specific test').status, 0);
    const renamed = existing.replace('platform', 'optional fixture');
    fs.writeFileSync(file, renamed + 'test("metadata", () => { list.' + method + '(2); });\n');
    assert.equal(runAntiTamper(dir).status, 0);
    for (const call of [
      'it("feature", t => t.' + method + '("optional"));',
      'test("feature", function (context) { context.' + method + '(); });',
      'test("parent", async parent => { await parent.test("child", child => child.' + method + '()); });',
    ]) {
      fs.writeFileSync(file, renamed + call);
      const added = runAntiTamper(dir);
      assert.equal(added.status, 4, added.stdout);
      assert.deepEqual(JSON.parse(added.stdout).violations.map(v => v.code), ['TEST_SKIP_ADDED']);
    }
  });

  it('distinguishes an entire TRUE definition from conjunctions and their continuations', (t) => {
    const { dir } = initGitRepoWithTests();
    t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
    const file = path.join(dir, 'specs/demo/formal/Model.tla');
    function writeBody(body) {
      fs.writeFileSync(file, '---- MODULE Model ----\nVARIABLE x\nInv == ' + body + '\n====\n');
    }
    for (const body of ['TRUE /\\ x = 1', 'TRUE\n     /\\ x = 1', 'TRUE (* checked below *)\n     /\\ x = 1']) {
      writeBody(body);
      const result = runAntiTamper(dir);
      assert.equal(result.status, 0, result.stdout);
    }
    for (const body of ['TRUE', '\n    TRUE \\* constant predicate']) {
      writeBody(body);
      const result = runAntiTamper(dir);
      assert.equal(result.status, 4, result.stdout);
      assert.deepEqual(JSON.parse(result.stdout).violations.map(v => v.code), ['FORMAL_INVARIANT_WEAKENED']);
    }
  });

  it('ignores Python and Go documentation while counting executable skip directives', (t) => {
    const { dir, git } = initGitRepoWithTests();
    t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
    const py = path.join(dir, 'tests/sample_test.py');
    const go = path.join(dir, 'tests/sample_test.go');
    const decorator = ['unittest', '.skip'].join('');
    const goMethod = ['t.', 'Skip'].join('');
    fs.writeFileSync(py, '# ' + decorator + ' is used for platform exclusions\n' +
      '"""\nAn example is @' + decorator + '("reason").\n"""\n' +
      'message = "' + decorator + '"\n');
    fs.writeFileSync(go, 'package sample\n// ' + goMethod + '("optional")\n' +
      '/* ' + goMethod + '("old") */\nconst doc = `' + goMethod + '("demo")`\n');
    assert.equal(git('add', 'tests').status, 0);
    const docs = runAntiTamper(dir);
    assert.equal(docs.status, 0, docs.stdout);
    fs.appendFileSync(py, '@' + decorator + '("requires device")\ndef test_device():\n    pass\n');
    fs.appendFileSync(go, 'func TestDevice(t *testing.T) { ' + goMethod + '("requires device") }\n');
    const added = runAntiTamper(dir);
    assert.equal(added.status, 4, added.stdout);
    assert.deepEqual(JSON.parse(added.stdout).violations.map(v => v.path).sort(),
      ['tests/sample_test.go', 'tests/sample_test.py']);
  });

  for (const defect of ['invalid JSON', 'wrong id', 'wrong feature']) {
    it('preserves an existing question with ' + defect + ' and records a valid replacement', (t) => {
      const { dir } = initGitRepoWithTests();
      t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
      fs.appendFileSync(path.join(dir, 'sdd/approved-test-retirements.json'), '\n');
      const first = JSON.parse(runAntiTamper(dir).stdout).openQuestion;
      const filename = path.join(dir, first.path);
      const question = JSON.parse(fs.readFileSync(filename));
      const old = defect === 'invalid JSON' ? '{' : JSON.stringify({
        ...question, [defect === 'wrong id' ? 'id' : 'feature']: 'other',
      });
      fs.writeFileSync(filename, old);
      const next = runAntiTamper(dir);
      assert.equal(next.status, 4, next.stderr);
      const replacement = JSON.parse(next.stdout).openQuestion;
      assert.equal(replacement.id, 'OQ-002');
      assert.equal(fs.readFileSync(filename, 'utf8'), old);
      const replacementFile = path.join(dir, replacement.path);
      const persisted = JSON.parse(fs.readFileSync(replacementFile));
      assert.equal(persisted.id, replacement.id);
      assert.equal(persisted.feature, 'demo');
      fs.writeFileSync(replacementFile, JSON.stringify({ ...persisted, status: 'Confirmed' }));
      assert.deepEqual(JSON.parse(runAntiTamper(dir).stdout).openQuestion, replacement);
    });
  }

  it('uses committed retirement approvals and mandatory protection; records a repeatable OQ', (t) => {
    const { dir, git } = initGitRepoWithTests();
    t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
    const testPath = 'tests/sample.test.mjs';
    const row = { path: testPath, git_blob_sha: git('rev-parse', 'HEAD:' + testPath).stdout.trim(),
      reason: 'superseded', approved_by: 'fixture-owner' };
    const manifest = 'sdd/approved-test-retirements.json';
    fs.writeFileSync(path.join(dir, 'sdd', 'guardrails.json'), JSON.stringify({
      anti_tampering: { retirements_manifest: 'sdd/other.json', protected_repo_paths: ['custom/**'] },
    }));
    fs.writeFileSync(path.join(dir, 'sdd', 'other.json'), JSON.stringify({ retirements: [row] }));
    fs.writeFileSync(path.join(dir, manifest), JSON.stringify({ retirements: [row] }));
    fs.rmSync(path.join(dir, testPath));
    function run() {
      return spawnSync(process.execPath, [CHECK_SCRIPT, '--anti-tamper', '--root', dir, '--feature', 'demo'], { encoding: 'utf8' });
    }
    const first = run();
    assert.equal(first.status, 4, first.stdout);
    const report = JSON.parse(first.stdout);
    assert.ok(report.violations.some(v => v.code === 'PROTECTED_PATH_MODIFIED' && v.path === manifest));
    assert.ok(report.violations.some(v => v.code === 'UNAUTHORIZED_TEST_DELETION' && v.path === testPath));
    assert.match(report.openQuestion.id, /^OQ-[0-9]{3,}$/);
    const persisted = JSON.parse(fs.readFileSync(path.join(dir, report.openQuestion.path), 'utf8'));
    assert.equal(persisted.id, report.openQuestion.id);
    assert.equal(persisted.status, 'Provisional');
    assert.deepEqual(persisted.violations, report.violations.map(({ code, path }) => ({code, path})));
    assert.deepEqual(JSON.parse(run().stdout).openQuestion, report.openQuestion);
  });

  for (const field of ['reason', 'approved_by']) {
    it('requires a nonempty retirement ' + field + ' in the trusted manifest', (t) => {
      const { dir, git } = initGitRepoWithTests();
      t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
      const file = 'tests/sample.test.mjs';
      const entry = { path: file, git_blob_sha: git('rev-parse', 'HEAD:' + file).stdout.trim(),
        reason: 'replaced', approved_by: 'owner', [field]: '  ' };
      fs.writeFileSync(path.join(dir, 'sdd/approved-test-retirements.json'), JSON.stringify({
        schema: 'sdd-approved-test-retirements/v1', retirements: [entry],
      }));
      assert.equal(git('add', 'sdd/approved-test-retirements.json').status, 0);
      assert.equal(git('commit', '-m', 'fixture metadata').status, 0);
      fs.rmSync(path.join(dir, file));
      const result = spawnSync(process.execPath, [CHECK_SCRIPT, '--anti-tamper', '--root', dir], { encoding: 'utf8' });
      assert.equal(result.status, 4, result.stdout);
    });
  }

  it('rejects unapproved test deletion (exit 4) and allows deletion matching path + git_blob_sha in manifest (exit 0)', () => {
    const { dir, git } = initGitRepoWithTests();
    const blobSha = git('rev-parse', 'HEAD:tests/sample.test.mjs').stdout.trim();
    fs.rmSync(path.join(dir, 'tests', 'sample.test.mjs'));

    const unapproved = spawnSync(process.execPath, [CHECK_SCRIPT, '--anti-tamper', '--root', dir], { encoding: 'utf8' });
    assert.equal(unapproved.status, 4);
    assert.ok(JSON.parse(unapproved.stdout).violations.some((v) => v.code === 'UNAUTHORIZED_TEST_DELETION'));

    // Commit human-approved retirement manifest on base commit, then delete test file
    git('checkout', '--', 'tests/sample.test.mjs');
    fs.writeFileSync(
      path.join(dir, 'sdd', 'approved-test-retirements.json'),
      JSON.stringify({
        schema: 'sdd-approved-test-retirements/v1',
        retirements: [{ path: 'tests/sample.test.mjs', git_blob_sha: blobSha, approved_by: '@aharada54914', reason: 'Superseded' }],
      }, null, 2),
      'utf8',
    );
    assert.equal(git('add', 'sdd/approved-test-retirements.json').status, 0);
    assert.equal(git('commit', '-m', 'approve retirement').status, 0);

    fs.rmSync(path.join(dir, 'tests', 'sample.test.mjs'));
    const approved = spawnSync(process.execPath, [CHECK_SCRIPT, '--anti-tamper', '--root', dir], { encoding: 'utf8' });
    assert.equal(approved.status, 0, approved.stdout);
    assert.equal(JSON.parse(approved.stdout).status, 'CLEAN');
    fs.rmSync(dir, { recursive: true, force: true });
  });
});
