import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..');

describe('Phase 3-4: 4-host hooks, legacy removal, CI workflow, and installer', () => {
  it('all 4 host hook manifests parse as valid JSON and wire to v2/sdd-soft-guard.mjs', () => {
    const claude = JSON.parse(
      fs.readFileSync(path.join(REPO_ROOT, 'plugins/sdd-quality-loop/hooks/claude-hooks.json'), 'utf8'),
    );
    const codex = JSON.parse(
      fs.readFileSync(path.join(REPO_ROOT, 'plugins/sdd-quality-loop/hooks/hooks.json'), 'utf8'),
    );
    const copilot = JSON.parse(
      fs.readFileSync(path.join(REPO_ROOT, 'plugins/sdd-quality-loop/hooks/copilot-hooks.json'), 'utf8'),
    );
    const gemini = JSON.parse(
      fs.readFileSync(path.join(REPO_ROOT, 'plugins/sdd-quality-loop/gemini/hooks/hooks.json'), 'utf8'),
    );

    assert.match(JSON.stringify(claude), /scripts\/v2\/sdd-soft-guard\.mjs/);
    assert.match(JSON.stringify(codex), /scripts\/v2\/sdd-soft-guard\.mjs/);
    assert.match(JSON.stringify(copilot), /scripts\/v2\/sdd-soft-guard\.mjs/);
    assert.match(JSON.stringify(gemini), /scripts\/v2\/sdd-soft-guard\.mjs/);

    assert.doesNotMatch(JSON.stringify(claude), /sdd-hook-guard|kill-switch/);
    assert.doesNotMatch(JSON.stringify(codex), /sdd-hook-guard|kill-switch/);
    assert.doesNotMatch(JSON.stringify(copilot), /sdd-hook-guard/);
    assert.doesNotMatch(JSON.stringify(gemini), /sdd-hook-guard/);
  });

  it('deprecated hard-lock scripts, 3-loop reviews, and sdd-lite plugin are removed', () => {
    const removedPaths = [
      'plugins/sdd-quality-loop/scripts/sdd-hook-guard.py',
      'plugins/sdd-quality-loop/scripts/sdd-hook-guard.js',
      'plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1',
      'plugins/sdd-quality-loop/scripts/sdd-hook-guard.sh',
      'plugins/sdd-quality-loop/references/guard-invariants.json',
      'plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py',
      'plugins/sdd-quality-loop/skills/sdd-sudo',
      'plugins/sdd-quality-loop/skills/cross-model-verify',
      'plugins/sdd-review-loop/skills/spec-review-loop',
      'plugins/sdd-review-loop/skills/impl-review-loop',
      'plugins/sdd-review-loop/skills/task-review-loop',
      'plugins/sdd-lite',
    ];
    for (const rel of removedPaths) {
      assert.equal(fs.existsSync(path.join(REPO_ROOT, rel)), false, `${rel} should be removed`);
    }
  });

  it('CI workflow and CODEOWNERS cover Layer 3 guardrails boundary', () => {
    const ci = fs.readFileSync(path.join(REPO_ROOT, '.github/workflows/sdd-guardrails.yml'), 'utf8');
    assert.match(ci, /node --test tests\/v2-\*\.test\.mjs/);
    assert.match(ci, /check-spec-drift\.mjs/);
    assert.match(ci, /--fail-on-undeclared/);

    const owners = fs.readFileSync(path.join(REPO_ROOT, 'CODEOWNERS'), 'utf8');
    assert.match(owners, /\/plugins\/sdd-quality-loop\/hooks\//);
    assert.match(owners, /\/specs\//);
    assert.match(owners, /\/contracts\/guardrails\.schema\.json/);
  });

  it(
    'install.sh --target FilesOnly succeeds end-to-end and installs v2 guardrail scripts',
    { skip: process.platform === 'win32' },
    () => {
      const installRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-v2-install-'));
      const res = spawnSync(
        'bash',
        [
          path.join(REPO_ROOT, 'install.sh'),
          '--source-directory',
          REPO_ROOT,
          '--install-root',
          installRoot,
          '--target',
          'FilesOnly',
          '--skip-mcp',
          '--skip-agent-install',
        ],
        { cwd: REPO_ROOT, encoding: 'utf8' },
      );
      assert.equal(res.status, 0, `install.sh failed:\nSTDOUT:\n${res.stdout}\nSTDERR:\n${res.stderr}`);
      assert.equal(
        fs.existsSync(path.join(installRoot, 'plugins/sdd-quality-loop/scripts/v2/sdd-soft-guard.mjs')),
        true,
      );
      assert.equal(
        fs.existsSync(path.join(installRoot, 'plugins/sdd-quality-loop/scripts/v2/check-spec-drift.mjs')),
        true,
      );
      assert.equal(
        fs.existsSync(path.join(installRoot, 'plugins/sdd-quality-loop/scripts/v2/run-sdd-gate.mjs')),
        true,
      );
      assert.equal(fs.existsSync(path.join(installRoot, 'plugins/sdd-lite')), false);
    },
  );
});
