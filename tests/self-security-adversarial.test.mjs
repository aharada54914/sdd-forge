import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';
import { sanitizeRelPath } from '../plugins/sdd-quality-loop/scripts/v2/v2-pure-lib.mjs';
import { resolveSafeExternalCommand, runSecurityGate } from '../plugins/sdd-quality-loop/scripts/v2/run-security-gate.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..');
const SECURITY_CLI = path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/run-security-gate.mjs');
const SOFT_GUARD_CLI = path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/sdd-soft-guard.mjs');

describe('ADR-0054 T-007 (SELF-AC-004 / AC-008): Adversarial Security Suite & Allowlist Security Gate', () => {
  it('1. Rejects arbitrary command keys in guardrails.yaml and unallowed adapters with exit code 2', () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-sec-adv-cmd-'));
    fs.mkdirSync(path.join(dir, 'sdd'), { recursive: true });
    fs.writeFileSync(
      path.join(dir, 'sdd/guardrails.yaml'),
      'schema: sdd-guardrails/v1\nsecurity_audit:\n  enabled: true\n  mode: strict\n  command: "echo pwned"\n',
      'utf8',
    );
    const res = spawnSync(process.execPath, [SECURITY_CLI, '--root', dir, '--mode', 'strict'], { encoding: 'utf8' });
    assert.equal(res.status, 2);
    assert.equal(JSON.parse(res.stdout).status, 'TOOL_ERROR');

    const unallowed = runSecurityGate({ projectRoot: REPO_ROOT, adapters: ['evil-custom-tool'], mode: 'strict' });
    assert.equal(unallowed.status, 'TOOL_ERROR');
    assert.equal(unallowed.exitCode, 2);
    fs.rmSync(dir, { recursive: true, force: true });
  });

  it('2. Refuses Windows .cmd/.bat wrappers (CVE-2024-27980 defense) and enforces shell: false', () => {
    assert.throws(() => resolveSafeExternalCommand('semgrep', REPO_ROOT, 'semgrep.cmd'), /\.cmd\/\.bat/);
    assert.throws(() => resolveSafeExternalCommand('gitleaks', REPO_ROOT, 'gitleaks.BAT'), /\.cmd\/\.bat/);
    const safeSpec = resolveSafeExternalCommand('semgrep', REPO_ROOT);
    assert.equal(safeSpec.options.shell, false);
  });

  it('3. Detects leaked secrets and ALWAYS masks raw secret tokens in output', () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-sec-adv-secret-'));
    fs.mkdirSync(path.join(dir, 'src'), { recursive: true });
    // Construct synthetic secret dynamically (WFI-012)
    const fakeAwsKey = ['AKIA', 'IOSFODNN', '7EXAMPLE'].join('');
    fs.writeFileSync(path.join(dir, 'src/config.mjs'), `export const KEY = "${fakeAwsKey}";\n`, 'utf8');

    const res = spawnSync(
      process.execPath,
      [SECURITY_CLI, '--root', dir, '--files', 'src/config.mjs', '--adapters', 'builtin-secret-pattern', '--mode', 'strict'],
      { encoding: 'utf8' },
    );
    assert.equal(res.status, 1);
    assert.ok(!res.stdout.includes(fakeAwsKey), 'Raw secret must NEVER appear unmasked in stdout');
    const report = JSON.parse(res.stdout);
    assert.equal(report.status, 'FAIL');
    assert.equal(report.findings.length, 1);
    assert.equal(report.findings[0].masked_match, 'AKIA****LE');
    fs.rmSync(dir, { recursive: true, force: true });
  });

  it('4. Detects slopsquatting / typosquatting packages and insecure HTTP deps in package.json', () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-sec-adv-slop-'));
    fs.writeFileSync(
      path.join(dir, 'package.json'),
      JSON.stringify({
        name: 'demo',
        dependencies: {
          lodasx: '^4.17.21',
          'internal-lib': 'http://untrusted.example/lib.tgz',
        },
      }),
      'utf8',
    );
    const report = runSecurityGate({
      projectRoot: dir,
      adapters: ['builtin-slopsquatting'],
      mode: 'strict',
    });
    assert.equal(report.status, 'FAIL');
    assert.equal(report.exitCode, 1);
    assert.ok(report.findings.some((f) => f.rule === 'suspected-typosquat-package'));
    assert.ok(report.findings.some((f) => f.rule === 'insecure-http-dependency'));
    fs.rmSync(dir, { recursive: true, force: true });
  });

  it('5. Fails closed (exit 2) in CI strict mode when an enabled external adapter is unavailable', () => {
    const report = runSecurityGate({
      projectRoot: REPO_ROOT,
      adapters: ['semgrep'],
      mode: 'strict',
      ci: true,
      externalRunner: () => ({ status: 127, unavailable: true, stdout: '', stderr: 'not found' }),
    });
    assert.equal(report.status, 'TOOL_ERROR');
    assert.equal(report.exitCode, 2);
  });

  it('6. Core path traversal & soft-guard self-approval defense hold against adversarial inputs', () => {
    assert.equal(sanitizeRelPath('../../etc/passwd'), null);
    assert.equal(sanitizeRelPath('specs\\demo\\tasks.md'), null);
    assert.equal(sanitizeRelPath('/abs/path'), null);

    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-sec-adv-guard-'));
    fs.mkdirSync(path.join(dir, '.git'));
    fs.mkdirSync(path.join(dir, 'specs', 'demo'), { recursive: true });
    const tasksPath = path.join(dir, 'specs', 'demo', 'tasks.md');
    fs.writeFileSync(tasksPath, '# Tasks\n\n## T-001 Demo\nApproval: Draft\nStatus: Planned\n', 'utf8');

    const payload = JSON.stringify({
      tool_name: 'Edit',
      tool_input: {
        file_path: tasksPath,
        old_string: 'Approval: Draft',
        new_string: 'Approval: Approved',
      },
    });
    const res = spawnSync(process.execPath, [SOFT_GUARD_CLI, '--emit', 'claude'], {
      cwd: dir,
      input: payload,
      encoding: 'utf8',
    });
    assert.equal(res.status, 2, 'sdd-soft-guard.mjs must deny agent self-approval with exit 2');
    fs.rmSync(dir, { recursive: true, force: true });
  });
});
