import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..');
const GUARD = path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/sdd-soft-guard.mjs');
const RECORD = path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/record-spec-baseline.mjs');
const DRIFT = path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/check-spec-drift.mjs');
const GATE = path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/run-sdd-gate.mjs');

describe('v2 Real-World Flows E2E (Software, DDD, Cloud)', () => {
  it('Flow 1 (Software): bootstrap -> human approval -> baseline -> autonomous dev -> soft guard -> sdd-gate -> Done', () => {
    const appDir = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-v2-e2e-app-'));
    execFileSync('git', ['init', '-q'], { cwd: appDir });
    execFileSync('git', ['config', 'user.email', 'test@example.com'], { cwd: appDir });
    execFileSync('git', ['config', 'user.name', 'Test'], { cwd: appDir });

    fs.mkdirSync(path.join(appDir, 'sdd'), { recursive: true });
    fs.mkdirSync(path.join(appDir, 'specs', 'order-cancel'), { recursive: true });
    fs.mkdirSync(path.join(appDir, 'src'), { recursive: true });
    fs.mkdirSync(path.join(appDir, 'test'), { recursive: true });
    fs.copyFileSync(path.join(REPO_ROOT, 'sdd/guardrails.example.yaml'), path.join(appDir, 'sdd/guardrails.yaml'));

    const reqPath = path.join(appDir, 'specs/order-cancel/requirements.md');
    const tasksPath = path.join(appDir, 'specs/order-cancel/tasks.md');
    fs.writeFileSync(
      reqPath,
      [
        '# 要件（SDD Core）: order-cancel',
        '- **REQ-001**: 注文確定から24時間以内のキャンセルは手数料0円とする。',
        '- **AC-001**: 経過時間 <= 24h のとき fee === 0 を返す。',
        '- **AC-002**: 経過時間 > 24h のとき fee === 500 を返す。',
        '',
        '## Spec Amendments',
        '- （初期版のため変更なし）',
        '',
      ].join('\n'),
      'utf8',
    );
    fs.writeFileSync(
      path.join(appDir, 'specs/order-cancel/design.md'),
      '# 設計（SDD Core）: order-cancel\n\n## 方針\nsrc/cancel.mjs に実装する。\n\n## Spec Amendments\n- None\n',
      'utf8',
    );
    fs.writeFileSync(
      tasksPath,
      [
        '# タスク（SDD Core）: order-cancel',
        '',
        '## T-001 キャンセル手数料ロジック実装',
        'Approval: Draft',
        'Status: Planned',
        'Risk: standard',
        '',
        '### Scope',
        '- src/cancel.mjs',
        '- test/cancel.test.mjs',
        '',
        '### Done When',
        '- AC-001, AC-002 が node --test で PASS する',
        '',
        '### Blockers',
        '- None',
        '',
        '## Spec Amendments',
        '- None',
        '',
      ].join('\n'),
      'utf8',
    );

    // Agent self-approval denied
    const selfApprove = spawnSync(process.execPath, [GUARD, '--root', appDir, '--emit', 'exit'], {
      input: JSON.stringify({
        tool_name: 'Edit',
        tool_input: { file_path: tasksPath, old_string: 'Approval: Draft', new_string: 'Approval: Approved' },
      }),
      encoding: 'utf8',
    });
    assert.equal(selfApprove.status, 2);

    // Human approves & ship records baseline
    fs.writeFileSync(tasksPath, fs.readFileSync(tasksPath, 'utf8').replace('Approval: Draft', 'Approval: Approved'));
    assert.equal(
      spawnSync(process.execPath, [RECORD, '--feature', 'order-cancel', '--root', appDir], { encoding: 'utf8' }).status,
      0,
    );

    // Autonomous code & test work allowed
    fs.writeFileSync(path.join(appDir, 'src/cancel.mjs'), 'export const calculateCancelFee = (h) => (h <= 24 ? 0 : 500);\n');
    fs.writeFileSync(
      path.join(appDir, 'test/cancel.test.mjs'),
      `import assert from 'node:assert/strict';
import { test } from 'node:test';
import { calculateCancelFee } from '../src/cancel.mjs';
test('AC-001', () => assert.equal(calculateCancelFee(24), 0));
test('AC-002', () => assert.equal(calculateCancelFee(25), 500));
`,
    );
    assert.equal(
      spawnSync(process.execPath, [GUARD, '--root', appDir, '--emit', 'exit'], {
        input: JSON.stringify({ tool_name: 'Bash', tool_input: { command: 'node --test test/cancel.test.mjs' } }),
        encoding: 'utf8',
      }).status,
      0,
    );

    // Silent AC weakening blocked by soft guard (confirm)
    assert.equal(
      spawnSync(process.execPath, [GUARD, '--root', appDir, '--emit', 'exit'], {
        input: JSON.stringify({
          tool_name: 'Edit',
          tool_input: { file_path: reqPath, old_string: 'fee === 500', new_string: 'fee === 0' },
        }),
        encoding: 'utf8',
      }).status,
      2,
    );

    // Implementation Complete -> run-sdd-gate.mjs runs real tests + drift check -> PASS
    fs.writeFileSync(tasksPath, fs.readFileSync(tasksPath, 'utf8').replace('Status: Planned', 'Status: Implementation Complete'));
    const gateRes = spawnSync(
      process.execPath,
      [
        GATE,
        '--feature',
        'order-cancel',
        '--task',
        'T-001',
        '--root',
        appDir,
        '--changed-files',
        'src/cancel.mjs,test/cancel.test.mjs',
        '--cmd',
        'unit=node --test test/cancel.test.mjs',
      ],
      { encoding: 'utf8' },
    );
    assert.equal(gateRes.status, 0, gateRes.stderr || gateRes.stdout);
    const gateOut = JSON.parse(gateRes.stdout);
    assert.equal(gateOut.verdict, 'PASS');
    assert.equal(gateOut.checks.specDrift.status, 'CLEAN');

    // Done transition stays CLEAN
    fs.writeFileSync(tasksPath, fs.readFileSync(tasksPath, 'utf8').replace('Status: Implementation Complete', 'Status: Done'));
    const driftRes = spawnSync(process.execPath, [DRIFT, '--feature', 'order-cancel', '--root', appDir, '--fail-on-undeclared'], {
      encoding: 'utf8',
    });
    assert.equal(driftRes.status, 0);
    assert.equal(JSON.parse(driftRes.stdout).status, 'CLEAN');
  });

  it('Flow 2 (DDD): sdd-domain skills align with v2 and Domain-Model-Status approval is guarded', () => {
    const domainSkills = [
      'plugins/sdd-domain/skills/domain-model/SKILL.md',
      'plugins/sdd-domain/skills/domain-interviewer/SKILL.md',
      'plugins/sdd-domain/skills/domain-reverse/SKILL.md',
      'plugins/sdd-domain/skills/domain-review-loop/SKILL.md',
      'plugins/sdd-domain/skills/domain-sync/SKILL.md',
    ];
    const forbiddenRe = /prepare-panelist-input|check-cross-model|SDD_SUDO|\bsdd-bootstrap-interviewer\b/;
    for (const rel of domainSkills) {
      const text = fs.readFileSync(path.join(REPO_ROOT, rel), 'utf8');
      const match = text.match(forbiddenRe);
      assert.equal(match, null, `${rel} contains retired v1 reference: ${match?.[0]}`);
    }

    // Shared helpers required by sdd-domain & cloud exist
    for (const helper of [
      'plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py',
      'plugins/sdd-quality-loop/scripts/generate-approval-sidecar.py',
      'plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.py',
    ]) {
      assert.equal(fs.existsSync(path.join(REPO_ROOT, helper)), true, `missing shared helper: ${helper}`);
    }
  });

  it(
    'Flow 3 (Cloud): AWS/Azure plugins install cleanly and UTC metric queries stay invariant under JST',
    { skip: process.platform === 'win32' },
    () => {
      const installRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-v2-cloud-install-'));
      const inst = spawnSync(
        'bash',
        [
          path.join(REPO_ROOT, 'install.sh'),
          '--source-directory',
          REPO_ROOT,
          '--install-root',
          installRoot,
          '--plugins',
          'sdd-aws-cloud,sdd-azure-cloud',
          '--target',
          'FilesOnly',
          '--skip-mcp',
          '--skip-agent-install',
        ],
        { cwd: REPO_ROOT, encoding: 'utf8' },
      );
      assert.equal(inst.status, 0, inst.stderr);
      assert.equal(fs.existsSync(path.join(installRoot, 'plugins/sdd-aws-cloud/scripts/cloud.py')), true);
      assert.equal(fs.existsSync(path.join(installRoot, 'plugins/sdd-azure-cloud/scripts/cloud.py')), true);

      // Verify Issue #786 fix under explicit JST timezone (Asia/Tokyo)
      const pyCheck = spawnSync(
        'python3',
        [
          '-c',
          [
            'import sys',
            `sys.path.insert(0, ${JSON.stringify(path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts'))})`,
            'import cloud_verification as cv',
            'got = cv.metric_start("2026-10-18T04:00:00Z", "2026-10-18T06:02:30Z", 300)',
            'assert got == "2026-10-18T05:58:00Z", f"expected UTC 05:58:00Z, got {got}"',
            'print("CLOUD UTC OK:", got)',
          ].join('; '),
        ],
        { cwd: REPO_ROOT, encoding: 'utf8', env: { ...process.env, TZ: 'Asia/Tokyo' } },
      );
      assert.equal(pyCheck.status, 0, pyCheck.stderr || pyCheck.stdout);
      assert.match(pyCheck.stdout, /CLOUD UTC OK: 2026-10-18T05:58:00Z/);
    },
  );
});
