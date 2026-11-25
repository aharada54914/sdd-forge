import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { describe, it } from 'node:test';
import { fileURLToPath, pathToFileURL } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..');
const GUARD_SCRIPT = path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/sdd-soft-guard.mjs');

function createTempRepo({ approved = true, guardMode = 'confirm', allowAmendments = true } = {}) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-v2-guard-'));
  fs.mkdirSync(path.join(dir, '.git'));
  fs.mkdirSync(path.join(dir, 'sdd'), { recursive: true });
  fs.mkdirSync(path.join(dir, 'specs', 'demo-feature'), { recursive: true });
  fs.mkdirSync(path.join(dir, 'src'), { recursive: true });

  fs.writeFileSync(
    path.join(dir, 'sdd', 'guardrails.yaml'),
    [
      'schema: sdd-guardrails/v1',
      'spec_guard:',
      `  mode: ${guardMode}`,
      `  allow_amendment_section: ${allowAmendments}`,
      '  protected_globs:',
      '    - specs/*/requirements.md',
      '    - specs/*/design.md',
      '    - specs/*/acceptance-tests.md',
      '    - specs/*/tasks.md',
      '',
    ].join('\n'),
    'utf8',
  );

  fs.writeFileSync(
    path.join(dir, 'specs', 'demo-feature', 'requirements.md'),
    [
      '# Requirements: demo-feature',
      '',
      '- REQ-001: Users can log in with passkey.',
      '- AC-001: Login returns HTTP 200 on valid credential.',
      '',
      '## Spec Amendments',
      '- None',
      '',
    ].join('\n'),
    'utf8',
  );

  fs.writeFileSync(
    path.join(dir, 'specs', 'demo-feature', 'tasks.md'),
    [
      '# Tasks: demo-feature',
      '',
      '## T-001 Implement passkey login',
      `Approval: ${approved ? 'Approved' : 'Draft'}`,
      'Status: Planned',
      'Risk: standard',
      '',
      '### Scope',
      '- src/auth.js',
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

  fs.writeFileSync(path.join(dir, 'src', 'auth.js'), 'export const ok = true;\n', 'utf8');
  return dir;
}

function runGuard(repoDir, payload, { emit = 'exit', env = {} } = {}) {
  const args = [GUARD_SCRIPT, '--root', repoDir, '--emit', emit];
  return spawnSync(process.execPath, args, {
    cwd: repoDir,
    input: JSON.stringify(payload),
    encoding: 'utf8',
    env: { ...process.env, CLAUDE_PROJECT_DIR: repoDir, ...env },
  });
}

describe('sdd-soft-guard.mjs (v2 Lightweight Guardrails)', () => {
  it('AC-001: blocks all tools across all emit modes when AGENT_STOP exists', () => {
    const repo = createTempRepo();
    fs.writeFileSync(path.join(repo, 'AGENT_STOP'), 'paused\n', 'utf8');

    const exitRes = runGuard(repo, { tool_name: 'Bash', tool_input: { command: 'ls' } }, { emit: 'exit' });
    assert.equal(exitRes.status, 2);
    assert.match(exitRes.stderr, /AGENT_STOP/);

    const copilotRes = runGuard(
      repo,
      { sessionId: 's1', timestamp: 1, cwd: repo, toolName: 'bash', toolArgs: { command: 'ls' } },
      { emit: 'copilot' },
    );
    assert.equal(copilotRes.status, 0);
    assert.equal(JSON.parse(copilotRes.stdout).permissionDecision, 'deny');

    const geminiRes = runGuard(
      repo,
      { tool_name: 'run_shell_command', tool_input: { command: 'ls' } },
      { emit: 'gemini' },
    );
    assert.equal(geminiRes.status, 0);
    assert.equal(JSON.parse(geminiRes.stdout).decision, 'deny');
  });

  it('AC-002: allows Bash/shell/run_shell_command and source edits without false positives', () => {
    const repo = createTempRepo({ approved: true, guardMode: 'strict' });

    const complexBash = runGuard(repo, {
      tool_name: 'Bash',
      tool_input: { command: 'for F in src/*.js; do rg "ok" "$F"; done && npm test' },
    });
    assert.equal(complexBash.status, 0);

    const geminiShell = runGuard(
      repo,
      { tool_name: 'run_shell_command', tool_input: { command: 'node --test' } },
      { emit: 'gemini' },
    );
    assert.equal(JSON.parse(geminiShell.stdout).decision, 'allow');

    const srcEdit = runGuard(repo, {
      tool_name: 'Edit',
      tool_input: {
        file_path: path.join(repo, 'src', 'auth.js'),
        old_string: 'export const ok = true;',
        new_string: 'export const ok = false;',
      },
    });
    assert.equal(srcEdit.status, 0);
  });

  it('#833: a legacy Second Approval line neither hides nor offsets a primary approval', async () => {
    const { countPrimaryApprovals } = await import(
      pathToFileURL(path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/v2-pure-lib.mjs')).href
    );
    assert.equal(countPrimaryApprovals('## T-001\nApproval: Approved\nSecond Approval: Approved\n'), 1);
    assert.equal(countPrimaryApprovals('## T-001\nApproval: Approved\n'), 1);
    assert.equal(countPrimaryApprovals('## T-001\nSecond Approval: Approved\n'), 0);

    // Inserting both lines at once used to net to zero and slip past the guard.
    const draftRepo = createTempRepo({ approved: false });
    const paired = runGuard(draftRepo, {
      tool_name: 'Edit',
      tool_input: {
        file_path: path.join(draftRepo, 'specs', 'demo-feature', 'tasks.md'),
        old_string: 'Approval: Draft',
        new_string: 'Approval: Approved\nSecond Approval: Approved',
      },
    });
    assert.equal(paired.status, 2);
  });

  it('AC-003: denies adding Approval: Approved in tasks.md, but allows Status transitions', () => {
    const draftRepo = createTempRepo({ approved: false });
    const selfApprove = runGuard(draftRepo, {
      tool_name: 'Edit',
      tool_input: {
        file_path: path.join(draftRepo, 'specs', 'demo-feature', 'tasks.md'),
        old_string: 'Approval: Draft',
        new_string: 'Approval: Approved',
      },
    });
    assert.equal(selfApprove.status, 2);
    assert.match(selfApprove.stderr, /Approval: Approved/);

    const approvedRepo = createTempRepo({ approved: true, guardMode: 'strict' });
    const statusUpdate = runGuard(approvedRepo, {
      tool_name: 'Edit',
      tool_input: {
        file_path: path.join(approvedRepo, 'specs', 'demo-feature', 'tasks.md'),
        old_string: 'Status: Planned',
        new_string: 'Status: In Progress',
      },
    });
    assert.equal(statusUpdate.status, 0);
  });

  it('AC-004: allows free edits to unapproved (Draft) specification files', () => {
    const draftRepo = createTempRepo({ approved: false, guardMode: 'strict' });
    const editReq = runGuard(draftRepo, {
      tool_name: 'Edit',
      tool_input: {
        file_path: path.join(draftRepo, 'specs', 'demo-feature', 'requirements.md'),
        old_string: '- AC-001: Login returns HTTP 200 on valid credential.',
        new_string: '- AC-001: Login returns HTTP 201 on valid credential.',
      },
    });
    assert.equal(editReq.status, 0);
  });

  it('AC-005: enforces confirm, warn, and strict modes on approved spec body edits', () => {
    // confirm mode (default): soft stop with guidance
    const confirmRepo = createTempRepo({ approved: true, guardMode: 'confirm' });
    const confirmRes = runGuard(confirmRepo, {
      tool_name: 'Edit',
      tool_input: {
        file_path: path.join(confirmRepo, 'specs', 'demo-feature', 'requirements.md'),
        old_string: 'HTTP 200',
        new_string: 'HTTP 204',
      },
    });
    assert.equal(confirmRes.status, 2);
    assert.match(confirmRes.stderr, /Spec Amendments/);
    assert.match(confirmRes.stderr, /SDD_ALLOW_SPEC_EDIT=1/);

    // warn mode: allows with advisory stderr + drift event log
    const warnRepo = createTempRepo({ approved: true, guardMode: 'warn' });
    const warnRes = runGuard(warnRepo, {
      tool_name: 'Edit',
      tool_input: {
        file_path: path.join(warnRepo, 'specs', 'demo-feature', 'requirements.md'),
        old_string: 'HTTP 200',
        new_string: 'HTTP 204',
      },
    });
    assert.equal(warnRes.status, 0);
    assert.match(warnRes.stderr, /\[SDD warn\]/);
    const warnLog = fs.readFileSync(path.join(warnRepo, '.sdd', 'drift-events.jsonl'), 'utf8');
    assert.match(warnLog, /"action":"warn_allow"/);

    // strict mode: denies
    const strictRepo = createTempRepo({ approved: true, guardMode: 'strict' });
    const strictRes = runGuard(strictRepo, {
      tool_name: 'Edit',
      tool_input: {
        file_path: path.join(strictRepo, 'specs', 'demo-feature', 'requirements.md'),
        old_string: 'HTTP 200',
        new_string: 'HTTP 204',
      },
    });
    assert.equal(strictRes.status, 2);
    assert.match(strictRes.stderr, /strict/);
  });

  it('AC-006: allows Spec Amendments additions and SDD_ALLOW_SPEC_EDIT=1 explicit override', () => {
    const repo = createTempRepo({ approved: true, guardMode: 'confirm' });

    const amendOnly = runGuard(repo, {
      tool_name: 'Edit',
      tool_input: {
        file_path: path.join(repo, 'specs', 'demo-feature', 'requirements.md'),
        old_string: '## Spec Amendments\n- None',
        new_string: '## Spec Amendments\n- 2026-11-21: Agreed with user to change AC-001 to HTTP 204.',
      },
    });
    assert.equal(amendOnly.status, 0);

    const overrideBody = runGuard(
      repo,
      {
        tool_name: 'Edit',
        tool_input: {
          file_path: path.join(repo, 'specs', 'demo-feature', 'requirements.md'),
          old_string: 'HTTP 200',
          new_string: 'HTTP 204',
        },
      },
      { env: { SDD_ALLOW_SPEC_EDIT: '1' } },
    );
    assert.equal(overrideBody.status, 0);
    const log = fs.readFileSync(path.join(repo, '.sdd', 'drift-events.jsonl'), 'utf8');
    assert.match(log, /"action":"allow_override"/);
  });

  it('AC-007: supports Codex apply_patch, Copilot native envelope, and Gemini replace/write_file', () => {
    const repo = createTempRepo({ approved: true, guardMode: 'confirm' });

    // Codex apply_patch modifying approved requirements body -> soft deny
    const codexPatchDeny = runGuard(repo, {
      tool_name: 'apply_patch',
      tool_input: {
        command: [
          '*** Begin Patch',
          '*** Update File: specs/demo-feature/requirements.md',
          '@@',
          '-- AC-001: Login returns HTTP 200 on valid credential.',
          '+- AC-001: Login returns HTTP 204 on valid credential.',
          '*** End Patch',
        ].join('\n'),
      },
    });
    assert.equal(codexPatchDeny.status, 2);

    // Codex apply_patch updating only tasks.md Status -> allow
    const codexStatusAllow = runGuard(repo, {
      tool_name: 'apply_patch',
      tool_input: {
        command: [
          '*** Begin Patch',
          '*** Update File: specs/demo-feature/tasks.md',
          '@@',
          '-Status: Planned',
          '+Status: Implementation Complete',
          '*** End Patch',
        ].join('\n'),
      },
    });
    assert.equal(codexStatusAllow.status, 0);

    // Copilot native create targeting approved requirements -> deny JSON
    const copilotRes = runGuard(
      repo,
      {
        sessionId: 's1',
        timestamp: 12345,
        cwd: repo,
        toolName: 'create',
        toolArgs: {
          path: 'specs/demo-feature/requirements.md',
          file_text: '# Requirements: demo-feature\n- REQ-001: weakened\n',
        },
      },
      { emit: 'copilot' },
    );
    assert.equal(copilotRes.status, 0);
    assert.equal(JSON.parse(copilotRes.stdout).permissionDecision, 'deny');

    // Gemini replace targeting approved requirements -> deny JSON
    const geminiRes = runGuard(
      repo,
      {
        tool_name: 'replace',
        tool_input: {
          file_path: path.join(repo, 'specs', 'demo-feature', 'requirements.md'),
          old_string: 'HTTP 200',
          new_string: 'HTTP 204',
        },
      },
      { emit: 'gemini' },
    );
    assert.equal(geminiRes.status, 0);
    assert.equal(JSON.parse(geminiRes.stdout).decision, 'deny');
  });

  it('REQ-001: falls back safely to confirm mode when sdd/guardrails.yaml is absent', () => {
    const repo = createTempRepo({ approved: true, guardMode: 'confirm' });
    fs.rmSync(path.join(repo, 'sdd', 'guardrails.yaml'));

    const res = runGuard(repo, {
      tool_name: 'Edit',
      tool_input: {
        file_path: path.join(repo, 'specs', 'demo-feature', 'requirements.md'),
        old_string: 'HTTP 200',
        new_string: 'HTTP 204',
      },
    });
    assert.equal(res.status, 2);
    assert.match(res.stderr, /confirm/);
  });

  it('Issue #785: denies agent self-approval of Domain-Model-Status: Approved in domain/context-map.md', () => {
    const repo = createTempRepo({ approved: false });
    fs.mkdirSync(path.join(repo, 'domain'), { recursive: true });
    const cmPath = path.join(repo, 'domain', 'context-map.md');
    fs.writeFileSync(cmPath, '# Context Map\n\nDomain-Model-Status: Pending\n', 'utf8');

    const denyApprove = runGuard(repo, {
      tool_name: 'Edit',
      tool_input: {
        file_path: cmPath,
        old_string: 'Domain-Model-Status: Pending',
        new_string: 'Domain-Model-Status: Approved',
      },
    });
    assert.equal(denyApprove.status, 2);
    assert.match(denyApprove.stderr, /Domain-Model-Status: Approved/);

    const allowReviewed = runGuard(repo, {
      tool_name: 'Edit',
      tool_input: {
        file_path: cmPath,
        old_string: 'Domain-Model-Status: Pending',
        new_string: 'Domain-Model-Status: Reviewed',
      },
    });
    assert.equal(allowReviewed.status, 0);
  });

  it('Issue #797: blocks approved spec edits inside a child Git repo even when invoked from a parent workspace cwd', () => {
    const parentWorkspace = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-parent-ws-'));
    const childRepo = path.join(parentWorkspace, 'child-repo');
    fs.mkdirSync(path.join(childRepo, '.git'), { recursive: true });
    fs.mkdirSync(path.join(childRepo, 'sdd'), { recursive: true });
    fs.mkdirSync(path.join(childRepo, 'specs', 'demo-feature'), { recursive: true });
    fs.writeFileSync(path.join(childRepo, 'sdd', 'guardrails.yaml'), 'spec_guard:\n  mode: confirm\n', 'utf8');
    fs.writeFileSync(
      path.join(childRepo, 'specs', 'demo-feature', 'requirements.md'),
      '# Requirements: demo-feature\n\n- REQ-001: Auth works.\n- AC-001: Returns 200.\n\n## Spec Amendments\n\n- 初期版。変更なし。\n',
      'utf8',
    );
    fs.writeFileSync(
      path.join(childRepo, 'specs', 'demo-feature', 'tasks.md'),
      '# Tasks\n\n## T-001 Task\nApproval: Approved\nStatus: Planned\nRisk: standard\n',
      'utf8',
    );

    // Invoke guard with --root set to the parent workspace (simulating Claude launched from $HOME editing a child repo)
    const denyRes = runGuard(parentWorkspace, {
      cwd: parentWorkspace,
      tool_name: 'Edit',
      tool_input: {
        file_path: path.join(childRepo, 'specs', 'demo-feature', 'requirements.md'),
        old_string: 'Returns 200.',
        new_string: 'Returns 204.',
      },
    });
    assert.equal(denyRes.status, 2, `Expected confirm deny from parent cwd, got status=${denyRes.status} stderr=${denyRes.stderr}`);
    assert.match(denyRes.stderr, /confirm/);

    // Also verify AGENT_STOP inside childRepo blocks edits even when launched from parentWorkspace
    fs.writeFileSync(path.join(childRepo, 'AGENT_STOP'), 'paused\n', 'utf8');
    const killRes = runGuard(parentWorkspace, {
      cwd: parentWorkspace,
      tool_name: 'Edit',
      tool_input: {
        file_path: path.join(childRepo, 'src', 'index.mjs'),
        old_string: '',
        new_string: 'console.log(1);',
      },
    });
    assert.equal(killRes.status, 2);
    assert.match(killRes.stderr, /AGENT_STOP/);
  });
});

describe('human concept-test decisions', () => {
  it('denies receipt mutations in every supported file tool family and both patch move directions', (t) => {
    const repo = createTempRepo({ approved: false, guardMode: 'warn' });
    t.after(() => fs.rmSync(repo, { recursive: true, force: true }));
    const receipt = 'specs/demo-feature/concept-test.decision.json';
    const other = 'specs/demo-feature/concept-test.json';
    const patch = (headers) => ['*** Begin Patch', ...headers, '*** End Patch'].join('\n');
    const cases = [
      ...['Edit', 'Write', 'MultiEdit'].map(tool_name => ['exit', { tool_name, tool_input: { file_path: receipt } }]),
      ['gemini', { tool_name: 'replace', tool_input: { file_path: receipt } }],
      ['gemini', { tool_name: 'write_file', tool_input: { file_path: receipt } }],
      ['copilot', { toolName: 'create', toolArgs: JSON.stringify({ path: receipt, file_text: '{}' }) }],
      ['antigravity', { toolCall: { name: 'write_file', args: { Path: receipt, Content: '{}' } } }],
      ['antigravity', { toolCall: { name: 'edit_file', args: { Path: receipt } } }],
      ['antigravity', { toolCall: { name: 'replace_file_content', args: { TargetFile: receipt } } }],
      ['antigravity', { toolCall: { name: 'multi_replace_file_content', args: { TargetFile: receipt, ReplacementChunks: [] } } }],
      ['exit', { tool_name: 'apply_patch', tool_input: { command: patch(['*** Add File: ' + receipt, '+{}']) } }],
      ['exit', { tool_name: 'apply_patch', tool_input: { input: patch(['*** Delete File: ' + receipt]) } }],
      ['exit', { tool_name: 'apply_patch', tool_input: patch(['*** Update File: ' + receipt, '*** Move to: ' + other]) }],
      ['copilot', { toolName: 'apply_patch', toolArgs: patch(['*** Update File: ' + other, '*** Move to: ' + receipt]) }],
      ['copilot', { toolName: 'apply_patch', toolArgs: { patch: patch(['*** Update File: ' + receipt]) } }],
      ['copilot', { toolName: 'apply_patch', toolArgs: JSON.stringify({ input: patch(['*** Delete File: ' + receipt]) }) }],
    ];
    for (const [emit, payload] of cases) {
      const res = runGuard(repo, payload, { emit, env: { SDD_ALLOW_SPEC_EDIT: '1' } });
      if (emit === 'exit') assert.equal(res.status, 2, JSON.stringify(payload));
      else assert.equal(JSON.parse(res.stdout).permissionDecision ?? JSON.parse(res.stdout).decision, 'deny', JSON.stringify(payload));
      assert.match(res.stderr + res.stdout, /concept-test\.decision\.json/);
    }
    assert.equal(runGuard(repo, { tool_name: 'Write', tool_input: { file_path: other, content: '{}' } }).status, 0);
    const example = 'docs/examples/' + receipt;
    assert.equal(runGuard(repo, { tool_name: 'Write', tool_input: { file_path: example, content: '{}' } }).status, 0);
  });
});
