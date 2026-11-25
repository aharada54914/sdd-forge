import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';
import { NON_CHECKS, formatDoctorText, runDoctor } from '../plugins/sdd-quality-loop/scripts/v2/sdd-doctor.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..');
const DOCTOR_CLI = path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/sdd-doctor.mjs');

function makeTempProject() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-doctor-test-'));
  fs.mkdirSync(path.join(dir, 'sdd'), { recursive: true });
  fs.writeFileSync(
    path.join(dir, 'sdd/guardrails.yaml'),
    'schema: sdd-guardrails/v1\nspec_guard:\n  mode: confirm\nreview:\n  pre_impl_check: auto\nrisk_defaults:\n  default_tier: standard\n',
    'utf8',
  );
  return dir;
}

describe('sdd-doctor.mjs (Zenn §8/§11 read-only diagnostic CLI)', () => {
  it('passes cleanly on the sdd-forge repository itself with explicit Non-checks', () => {
    const res = spawnSync(process.execPath, [DOCTOR_CLI, '--root', REPO_ROOT, '--json'], {
      encoding: 'utf8',
    });
    assert.equal(res.status, 0, `sdd-doctor failed on repo:\n${res.stdout}\n${res.stderr}`);
    const report = JSON.parse(res.stdout);
    assert.equal(report.schema, 'sdd-doctor/v1');
    assert.equal(report.summary.ng, 0, JSON.stringify(report.findings, null, 2));
    assert.ok(Array.isArray(report.non_checks) && report.non_checks.length >= 4);
    assert.deepEqual(report.non_checks, [...NON_CHECKS]);

    const text = formatDoctorText(report);
    assert.match(text, /Non-checks（検査しないもの）/);
    assert.match(text, /CLEAN は以下の検査境界内で異常なしを意味し/);
  });

  it('detects skill description > 1024 chars as NG (prevents silent host drop)', () => {
    const dir = makeTempProject();
    const skillDir = path.join(dir, 'sdd/skills/oversized');
    fs.mkdirSync(skillDir, { recursive: true });
    fs.writeFileSync(
      path.join(skillDir, 'SKILL.md'),
      `---\nname: oversized\ndescription: ${'a'.repeat(1025)}\n---\n# Oversized\n`,
      'utf8',
    );
    const report = runDoctor({ root: dir });
    assert.equal(report.status, 'NG');
    assert.ok(report.findings.some((f) => f.severity === 'NG' && f.category === 'skills' && /1024/.test(f.message)));
  });

  it('detects raw ASCII control character corruption in specs/ as NG without modifying files', () => {
    const dir = makeTempProject();
    const specFile = path.join(dir, 'specs/demo/requirements.md');
    fs.mkdirSync(path.dirname(specFile), { recursive: true });
    const corrupted = '# Requirements\n\nPath: C:\\temp\x07broken\n';
    fs.writeFileSync(specFile, corrupted, 'utf8');

    const report = runDoctor({ root: dir });
    assert.equal(report.status, 'NG');
    assert.ok(report.findings.some((f) => f.severity === 'NG' && f.category === 'encoding' && /0x07/.test(f.message)));
    // Read-only invariant: doctor must never auto-mutate the file.
    assert.equal(fs.readFileSync(specFile, 'utf8'), corrupted);
  });

  it('warns on non-ASCII .ps1 without UTF-8 BOM, unbaselined approved specs, and AGENT_STOP', () => {
    const dir = makeTempProject();
    fs.writeFileSync(path.join(dir, 'AGENT_STOP'), 'stop\n', 'utf8');
    fs.writeFileSync(path.join(dir, 'sdd/check.ps1'), 'Write-Host "日本語テスト"\n', 'utf8');
    const tasksPath = path.join(dir, 'specs/feat-a/tasks.md');
    fs.mkdirSync(path.dirname(tasksPath), { recursive: true });
    fs.writeFileSync(
      tasksPath,
      '# Tasks\n\n## T-001: Demo\nApproval: Approved\nStatus: In Progress\n',
      'utf8',
    );
    // Backdate mtime by 20 days to trigger stale In Progress warning
    const old = new Date(Date.now() - 20 * 24 * 60 * 60 * 1000);
    fs.utimesSync(tasksPath, old, old);

    const report = runDoctor({ root: dir, staleDays: 14 });
    assert.equal(report.summary.ng, 0);
    assert.ok(report.findings.some((f) => f.severity === 'WARN' && f.category === 'kill-switch'));
    assert.ok(report.findings.some((f) => f.severity === 'WARN' && f.category === 'encoding' && /BOM/.test(f.message)));
    assert.ok(report.findings.some((f) => f.severity === 'WARN' && f.category === 'specs' && /baseline/.test(f.message)));
    assert.ok(report.findings.some((f) => f.severity === 'WARN' && f.category === 'specs' && /In Progress/.test(f.message)));
  });

  it('detects invalid guardrails.yaml mode and broken hook JSON as NG', () => {
    const dir = makeTempProject();
    fs.writeFileSync(path.join(dir, 'sdd/guardrails.yaml'), 'schema: sdd-guardrails/v1\nspec_guard:\n  mode: bogus\n', 'utf8');
    fs.mkdirSync(path.join(dir, '.claude'), { recursive: true });
    fs.writeFileSync(path.join(dir, '.claude/settings.json'), '{ invalid json', 'utf8');

    const res = spawnSync(process.execPath, [DOCTOR_CLI, '--root', dir, '--json'], { encoding: 'utf8' });
    assert.equal(res.status, 1);
    const report = JSON.parse(res.stdout);
    assert.ok(report.findings.some((f) => f.severity === 'NG' && f.category === 'config'));
    assert.ok(report.findings.some((f) => f.severity === 'NG' && f.category === 'hooks'));
  });

  it('verifies Zenn §8-§12 template & skill contracts (Alternatives Rejected, Non-checks, rules-first retrospective)', () => {
    const designTemplate = fs.readFileSync(
      path.join(REPO_ROOT, 'plugins/sdd-bootstrap/skills/sdd-core-spec/templates/design.md'),
      'utf8',
    );
    assert.match(designTemplate, /採らなかった設計（Alternatives Rejected）/);

    const gateReportTemplate = fs.readFileSync(
      path.join(REPO_ROOT, 'plugins/sdd-quality-loop/templates/sdd-gate-report.md'),
      'utf8',
    );
    assert.match(gateReportTemplate, /## Non-checks（検査しないもの）/);

    const retro = fs.readFileSync(
      path.join(REPO_ROOT, 'plugins/sdd-quality-loop/skills/workflow-retrospective/SKILL.md'),
      'utf8',
    );
    assert.match(retro, /sdd-doctor\.mjs/);
    assert.match(retro, /sdd\/rejected-decisions\.md/);
    assert.match(retro, /2 回以上/);
    assert.doesNotMatch(retro, /\bSDD_SUDO\b|--track <full\|lite>|spec-review-loop|impl-review-loop|task-review-loop/);

    const domainTemplate = /\[.*?\]\(([^)]+)#domain-drift-metrics\)/.exec(retro);
    assert.ok(domainTemplate, 'the active retrospective must load the optional domain report section');
    const retroDir = path.join(REPO_ROOT, 'plugins/sdd-quality-loop/skills/workflow-retrospective');
    const template = fs.readFileSync(path.resolve(retroDir, domainTemplate[1]), 'utf8');
    const domainRows = template.split('## Domain Drift Metrics')[1].split('\n## ')[0];
    assert.match(domainRows, /Term-Deviation Count/);
    assert.match(domainRows, /Boundary-Violation Count/);
    assert.match(domainRows, /Combined Domain-Drift Count/);
    assert.match(retro, /## Deterministic Summary[\s\S]*Domain Drift Metrics[\s\S]*## Recurring Friction/);

    const createSkill = fs.readFileSync(
      path.join(REPO_ROOT, 'plugins/sdd-bootstrap/skills/create-project-skill/SKILL.md'),
      'utf8',
    );
    assert.match(createSkill, /sdd\/rejected-decisions\.md/);
    assert.match(createSkill, /3 回以上/);
  });
});
