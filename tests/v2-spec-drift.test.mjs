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
    fs.rmSync(dir, { recursive: true, force: true });
  });
});
