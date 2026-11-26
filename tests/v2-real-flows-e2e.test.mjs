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

      const packaged = spawnSync(process.execPath, ['tests/lib/check-cloud-release.mjs', '--installed-root', installRoot], {
        cwd: REPO_ROOT, encoding: 'utf8',
      });
      assert.equal(packaged.status, 0, packaged.error?.message || packaged.stderr || packaged.stdout);

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

  it('N12/N24/N25: domain v2/v1 entry-point boundary, soft-guard Domain-Model-Status enforcement without SDD_SUDO, and finalize-domain-review wrapper diagnostics', () => {
    // N12: verify legacy finalizer --help and canonical domain docs distinguish v2 4-key single-pass vs v1 8-key finalizer
    const py = process.platform === 'win32' ? 'python' : 'python3';
    const helpRes = spawnSync(
      py,
      [path.join(REPO_ROOT, 'plugins/sdd-domain/scripts/finalize-domain-review.py'), '--help'],
      { encoding: 'utf8', env: { ...process.env, COLUMNS: '200' } },
    );
    assert.equal(helpRes.status, 0, helpRes.stderr);
    const helpText = helpRes.stdout.replace(/-\r?\n\s*/g, '-').replace(/\s+/g, ' ');
    assert.match(helpText, /domain-reviewer-\{a,b\}\/v1/);
    assert.match(helpText, /domain-reviewer-\{a,b\}\/v2/);

    const reviewSkill = fs.readFileSync(
      path.join(REPO_ROOT, 'plugins/sdd-domain/skills/domain-review-loop/SKILL.md'),
      'utf8',
    );
    assert.match(reviewSkill, /domain-reviewer-\{a,b\}\/v2/);
    assert.match(reviewSkill, /finalize-domain-review/);
    assert.match(reviewSkill, /domain-reviewer-\{a,b\}\/v1/);

    // N24: verify actual sdd-soft-guard.mjs behavior on domain/context-map.md (no SDD_SUDO bypass; Pending->Reviewed allowed; Bash passes through when AGENT_STOP absent)
    const guardTmp = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-n24-domain-guard-'));
    try {
      fs.mkdirSync(path.join(guardTmp, '.git'), { recursive: true });
      fs.mkdirSync(path.join(guardTmp, 'domain'), { recursive: true });
      const cmPath = path.join(guardTmp, 'domain/context-map.md');
      fs.writeFileSync(cmPath, '# Context Map\n\nDomain-Model-Status: Pending\n', 'utf8');
      fs.writeFileSync(path.join(guardTmp, 'SDD_SUDO'), 'expires-epoch: 9999999999\n', 'utf8');

      const approveDeniedEvenWithSudo = spawnSync(process.execPath, [GUARD, '--root', guardTmp, '--emit', 'exit'], {
        input: JSON.stringify({
          tool_name: 'Edit',
          tool_input: {
            file_path: cmPath,
            old_string: 'Domain-Model-Status: Pending',
            new_string: 'Domain-Model-Status: Approved',
          },
        }),
        encoding: 'utf8',
      });
      assert.equal(approveDeniedEvenWithSudo.status, 2);
      assert.match(approveDeniedEvenWithSudo.stderr, /Domain-Model-Status: Approved/);

      const reviewedAllowed = spawnSync(process.execPath, [GUARD, '--root', guardTmp, '--emit', 'exit'], {
        input: JSON.stringify({
          tool_name: 'Edit',
          tool_input: {
            file_path: cmPath,
            old_string: 'Domain-Model-Status: Pending',
            new_string: 'Domain-Model-Status: Reviewed',
          },
        }),
        encoding: 'utf8',
      });
      assert.equal(reviewedAllowed.status, 0);

      const bashPassThrough = spawnSync(process.execPath, [GUARD, '--root', guardTmp, '--emit', 'exit'], {
        input: JSON.stringify({ tool_name: 'Bash', tool_input: { command: 'echo ok' } }),
        encoding: 'utf8',
      });
      assert.equal(bashPassThrough.status, 0);
    } finally {
      fs.rmSync(guardTmp, { recursive: true, force: true });
    }

    const pluginContracts = fs.readFileSync(path.join(REPO_ROOT, 'PLUGIN-CONTRACTS.md'), 'utf8');
    const domainSectionMatch = pluginContracts.match(/## sdd-domain domain model[\s\S]*?\n---/);
    assert.ok(domainSectionMatch, 'Expected sdd-domain section in PLUGIN-CONTRACTS.md');
    const domainSection = domainSectionMatch[0];
    assert.match(domainSection, /ADR-0051/);
    assert.match(domainSection, /plugins\/sdd-quality-loop\/scripts\/v2\/sdd-soft-guard\.mjs/);
    assert.match(domainSection, /finalize-domain-review/);
    assert.doesNotMatch(
      domainSection,
      /`sdd-hook-guard` rejects an agent-authored write of the approved value[\s\S]*SDD_SUDO token permits it/,
    );

    // N25: finalize-domain-review wrappers keep legacy machine token line byte-stable and append targeted operation/cause stderr line
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-n25-wrap-'));
    try {
      const emptyBin = path.join(tmp, 'empty-bin');
      fs.mkdirSync(emptyBin, { recursive: true });
      const cleanEnv = Object.fromEntries(
        Object.entries(process.env).filter(([k]) => k.toUpperCase() !== 'PATH'),
      );
      cleanEnv.PATH = emptyBin;

      if (process.platform !== 'win32') {
        const missingHelperDir = path.join(tmp, 'sh-missing-helper', 'plugins/sdd-domain/scripts');
        fs.mkdirSync(missingHelperDir, { recursive: true });
        const shMissing = path.join(missingHelperDir, 'finalize-domain-review.sh');
        fs.copyFileSync(path.join(REPO_ROOT, 'plugins/sdd-domain/scripts/finalize-domain-review.sh'), shMissing);

        const resMissingHelper = spawnSync('/bin/sh', [shMissing], { cwd: tmp, encoding: 'utf8' });
        assert.equal(resMissingHelper.status, 3, resMissingHelper.stderr);
        assert.equal(resMissingHelper.stdout, '');
        const helperLines = resMissingHelper.stderr.trimEnd().split(/\r?\n/);
        assert.equal(
          helperLines[0],
          'finalize-domain-review: FINALIZE_DOMAIN_REVIEW_RUNTIME_UNAVAILABLE: lib/py-dispatch.sh unavailable beside this script',
        );
        assert.match(helperLines[1] || '', /operation=finalize-domain-review/);
        assert.match(helperLines[1] || '', /cause=missing-dispatch-helper/);

        const missingPyRoot = path.join(tmp, 'sh-missing-py');
        const missingPyDir = path.join(missingPyRoot, 'plugins/sdd-domain/scripts');
        const libDir = path.join(missingPyRoot, 'plugins/sdd-quality-loop/scripts/lib');
        fs.mkdirSync(missingPyDir, { recursive: true });
        fs.mkdirSync(libDir, { recursive: true });
        const shMissingPy = path.join(missingPyDir, 'finalize-domain-review.sh');
        fs.copyFileSync(path.join(REPO_ROOT, 'plugins/sdd-domain/scripts/finalize-domain-review.sh'), shMissingPy);
        fs.copyFileSync(
          path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/lib/py-dispatch.sh'),
          path.join(libDir, 'py-dispatch.sh'),
        );

        const resMissingPy = spawnSync('/bin/sh', [shMissingPy], { cwd: tmp, env: cleanEnv, encoding: 'utf8' });
        assert.equal(resMissingPy.status, 3, resMissingPy.stderr);
        assert.equal(resMissingPy.stdout, '');
        const pyLines = resMissingPy.stderr.trimEnd().split(/\r?\n/);
        assert.equal(
          pyLines[0],
          'finalize-domain-review: FINALIZE_DOMAIN_REVIEW_RUNTIME_UNAVAILABLE: no python3 or python interpreter found on PATH',
        );
      }

      const pwshProbe = spawnSync(
        'pwsh',
        ['-NoProfile', '-Command', '[System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName'],
        { encoding: 'utf8' },
      );
      if (pwshProbe.status === 0 && pwshProbe.stdout.trim()) {
        const pwshDir = path.dirname(pwshProbe.stdout.trim());
        const missingHelperDir = path.join(tmp, 'ps1-missing-helper', 'plugins/sdd-domain/scripts');
        fs.mkdirSync(missingHelperDir, { recursive: true });
        const ps1Missing = path.join(missingHelperDir, 'finalize-domain-review.ps1');
        fs.copyFileSync(path.join(REPO_ROOT, 'plugins/sdd-domain/scripts/finalize-domain-review.ps1'), ps1Missing);

        const resPsHelper = spawnSync('pwsh', ['-NoProfile', '-File', ps1Missing], { cwd: tmp, encoding: 'utf8' });
        assert.equal(resPsHelper.status, 3, resPsHelper.stderr);
        assert.equal(resPsHelper.stdout, '');
        const psHelperLines = resPsHelper.stderr.trimEnd().split(/\r?\n/);
        assert.equal(
          psHelperLines[0],
          'finalize-domain-review: FINALIZE_DOMAIN_REVIEW_RUNTIME_UNAVAILABLE: lib/py-dispatch.ps1 unavailable beside this script',
        );

        const colocatedPython = ['python3', 'python', 'python3.exe', 'python.exe'].some((name) =>
          fs.existsSync(path.join(pwshDir, name)),
        );
        if (!colocatedPython) {
          const missingPyRoot = path.join(tmp, 'ps1-missing-py');
          const missingPyDir = path.join(missingPyRoot, 'plugins/sdd-domain/scripts');
          const libDir = path.join(missingPyRoot, 'plugins/sdd-quality-loop/scripts/lib');
          fs.mkdirSync(missingPyDir, { recursive: true });
          fs.mkdirSync(libDir, { recursive: true });
          const ps1MissingPy = path.join(missingPyDir, 'finalize-domain-review.ps1');
          fs.copyFileSync(path.join(REPO_ROOT, 'plugins/sdd-domain/scripts/finalize-domain-review.ps1'), ps1MissingPy);
          fs.copyFileSync(
            path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/lib/py-dispatch.ps1'),
            path.join(libDir, 'py-dispatch.ps1'),
          );

          const resPsPy = spawnSync(
            'pwsh',
            ['-NoProfile', '-Command', '$env:PATH = $env:SDD_TEST_EMPTY_BIN; & $env:SDD_TEST_PS1_SCRIPT; exit $LASTEXITCODE'],
            {
              cwd: tmp,
              env: { ...process.env, SDD_TEST_EMPTY_BIN: emptyBin, SDD_TEST_PS1_SCRIPT: ps1MissingPy },
              encoding: 'utf8',
            },
          );
          assert.equal(resPsPy.status, 3, resPsPy.stderr);
          assert.equal(resPsPy.stdout, '');
          const psPyLines = resPsPy.stderr.trimEnd().split(/\r?\n/);
          assert.equal(
            psPyLines[0],
            'finalize-domain-review: FINALIZE_DOMAIN_REVIEW_RUNTIME_UNAVAILABLE: no python3 or python interpreter found on PATH',
          );
        }
      }
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
    }
  });

  it('R6: sync-knowledge emits real 1-based file:line for CRLF/repeated/placeholder amendments, preserves manual notes across reruns, and keeps drift/baseline/guard output compatible', () => {
    const syncKnowledge = path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/sync-knowledge.mjs');
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-r6-knowledge-'));
    try {
      fs.mkdirSync(path.join(tmp, '.git'), { recursive: true });
      fs.mkdirSync(path.join(tmp, 'specs', 'orders'), { recursive: true });

      const reqPath = path.join(tmp, 'specs/orders/requirements.md');
      fs.writeFileSync(
        reqPath,
        [
          '# 要件: orders',
          '- **REQ-001**: Create order',
          '- **AC-001** (REQ-001): Returns 201',
          '- 2026-11-22: 監査要件に合わせ論理削除へ統一',
          '',
          '## Spec Amendments',
          '',
          '- （初期版のため変更なし）',
          '- 2026-11-22: 監査要件に合わせ論理削除へ統一',
          '- None',
          '- 2026-11-22: 監査要件に合わせ論理削除へ統一',
          '',
        ].join('\r\n'),
        'utf8',
      );
      fs.writeFileSync(
        path.join(tmp, 'specs/orders/design.md'),
        '# 設計: orders\n\n## Spec Amendments\n- 2026-11-22: 設計改訂メモ\n',
        'utf8',
      );
      fs.writeFileSync(
        path.join(tmp, 'specs/orders/tasks.md'),
        '# タスク: orders\n\n## T-001 Order API\nApproval: Approved\nStatus: Planned\nRisk: standard\n\n### Spec Amendments\n- (initial version)\n- 2026-11-22: タスク改訂メモ\n### Notes\n- 2026-11-22: タスク改訂メモ\n',
        'utf8',
      );

      assert.equal(spawnSync(process.execPath, [RECORD, '--feature', 'orders', '--root', tmp], { encoding: 'utf8' }).status, 0);
      const baseline = JSON.parse(fs.readFileSync(path.join(tmp, 'specs/orders/.spec-baseline.json'), 'utf8'));
      assert.equal(baseline.amendmentCount, 4);

      fs.writeFileSync(reqPath, fs.readFileSync(reqPath, 'utf8').replace('Returns 201', 'Returns 204'), 'utf8');
      const driftRes = spawnSync(process.execPath, [DRIFT, '--feature', 'orders', '--root', tmp, '--format', 'markdown'], { encoding: 'utf8' });
      assert.equal(driftRes.status, 0);
      assert.match(driftRes.stdout, /\(`specs\/orders\/requirements\.md`\) - 2026-11-22: 監査要件に合わせ論理削除へ統一/);
      assert.equal(driftRes.stdout.includes('requirements.md:L'), false);
      assert.equal(
        spawnSync(process.execPath, [GUARD, '--root', tmp, '--emit', 'exit'], {
          input: JSON.stringify({ tool_name: 'Edit', tool_input: { file_path: reqPath, old_string: 'Returns 204', new_string: 'Returns 200' } }),
          encoding: 'utf8',
        }).status,
        2,
      );

      const knowPath = path.join(tmp, 'sdd/knowledge/specs/orders.md');
      fs.mkdirSync(path.dirname(knowPath), { recursive: true });
      fs.writeFileSync(knowPath, 'Manual note above.\n', 'utf8');
      execFileSync(process.execPath, [syncKnowledge, 'extract', '--feature', 'orders', '--root', tmp, '--write'], { encoding: 'utf8' });
      fs.writeFileSync(knowPath, `${fs.readFileSync(knowPath, 'utf8')}\nManual note below.\n`, 'utf8');
      execFileSync(process.execPath, [syncKnowledge, 'extract', '--feature', 'orders', '--root', tmp, '--write'], { encoding: 'utf8' });

      const knowMd = fs.readFileSync(knowPath, 'utf8');
      assert.match(knowMd, /Manual note above\./);
      assert.match(knowMd, /Manual note below\./);
      assert.deepEqual(
        knowMd.split('\n').filter((line) => line.startsWith('- (`specs/orders/')),
        [
          '- (`specs/orders/requirements.md:L9`) - 2026-11-22: 監査要件に合わせ論理削除へ統一',
          '- (`specs/orders/requirements.md:L11`) - 2026-11-22: 監査要件に合わせ論理削除へ統一',
          '- (`specs/orders/design.md:L4`) - 2026-11-22: 設計改訂メモ',
          '- (`specs/orders/tasks.md:L10`) - 2026-11-22: タスク改訂メモ',
        ],
      );
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
    }
  });
});
