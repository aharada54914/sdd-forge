import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';
import { runAgentLint } from '../plugins/sdd-quality-loop/scripts/v2/run-agent-lint.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..');
const LINT_CLI = path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/run-agent-lint.mjs');

describe('ADR-0054 T-004 (AC-007 / NFR-004): Layer 2/3 AST Agent-Strict Lint & Built-in Waivers', () => {
  it('passes cleanly on clean fixture and catches violations with remediation_hint in strict vs shadow mode', () => {
    const clean = runAgentLint({
      projectRoot: REPO_ROOT,
      files: ['tests/fixtures/agent-lint/clean.mjs'],
      mode: 'strict',
    });
    assert.equal(clean.status, 'PASS');
    assert.equal(clean.findings.length, 0);

    const shadowRes = spawnSync(
      process.execPath,
      [LINT_CLI, '--root', REPO_ROOT, '--files', 'tests/fixtures/agent-lint/violations.mjs', '--mode', 'shadow', '--format', 'json'],
      { encoding: 'utf8' },
    );
    assert.equal(shadowRes.status, 0, shadowRes.stderr);
    const shadowReport = JSON.parse(shadowRes.stdout);
    const rules = new Set(shadowReport.findings.map((f) => f.rule));
    assert.ok(rules.has('no-empty-catch'));
    assert.ok(rules.has('no-eval-or-new-function'));
    assert.ok(rules.has('no-child-process-shell-true'));
    assert.ok(rules.has('no-console-log'));
    assert.ok(shadowReport.findings.every((f) => typeof f.remediation_hint === 'string' && f.remediation_hint.length > 0));

    const strictRes = spawnSync(
      process.execPath,
      [LINT_CLI, '--root', REPO_ROOT, '--files', 'tests/fixtures/agent-lint/violations.mjs', '--mode', 'strict', '--format', 'json'],
      { encoding: 'utf8' },
    );
    assert.equal(strictRes.status, 1);
  });

  it('honors active built-in guardrails.yaml waivers and fails on expired waivers in strict mode', () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-agent-lint-waiver-'));
    fs.mkdirSync(path.join(dir, 'sdd'), { recursive: true });
    fs.mkdirSync(path.join(dir, 'src'), { recursive: true });
    fs.writeFileSync(path.join(dir, 'src/cli.mjs'), 'export function run() { console.log("ok"); }\n', 'utf8');
    fs.writeFileSync(
      path.join(dir, 'sdd/guardrails.yaml'),
      [
        'schema: sdd-guardrails/v1',
        'agent_lint:',
        '  enabled: true',
        '  mode: strict',
        '  waivers:',
        '    - rule: no-console-log',
        '      path: src/cli.mjs',
        '      reason: CLI stdout output',
        '      expires_on: 2027-06-01',
        '',
      ].join('\n'),
      'utf8',
    );

    const active = runAgentLint({ projectRoot: dir, files: ['src/cli.mjs'], mode: 'strict', today: '2026-11-25' });
    assert.equal(active.status, 'PASS');
    assert.equal(active.findings.length, 0);
    assert.equal(active.waived.length, 1);

    const expired = runAgentLint({ projectRoot: dir, files: ['src/cli.mjs'], mode: 'strict', today: '2027-06-02' });
    assert.equal(expired.status, 'FAIL');
    assert.equal(expired.expiredWaivers.length, 1);
    assert.equal(expired.expiredWaivers[0].code, 'EXPIRED_WAIVER');
    fs.rmSync(dir, { recursive: true, force: true });
  });

  it('NFR-004 performance budget: lints 100 files in <= 3000ms', () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-agent-lint-perf-'));
    fs.mkdirSync(path.join(dir, 'src'), { recursive: true });
    const files = [];
    for (let i = 0; i < 100; i += 1) {
      const rel = `src/mod_${i}.mjs`;
      fs.writeFileSync(
        path.join(dir, rel),
        `export function fn${i}(x) {\n  if (x > 0) {\n    return x * 2;\n  }\n  return 0;\n}\n`,
        'utf8',
      );
      files.push(rel);
    }
    const report = runAgentLint({ projectRoot: dir, files, mode: 'strict' });
    assert.equal(report.scannedFiles, 100);
    assert.equal(report.status, 'PASS');
    assert.ok(report.durationMs <= 3000, `100 files took ${report.durationMs}ms (budget <= 3000ms)`);
    fs.rmSync(dir, { recursive: true, force: true });
  });
});
