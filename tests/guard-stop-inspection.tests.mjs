import { createHmac } from 'node:crypto';
import { realpathSync } from 'node:fs';
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, chmodSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const scripts = fileURLToPath(new URL('../plugins/sdd-quality-loop/scripts/', import.meta.url));
const payload = JSON.stringify({ tool_name: 'Read', tool_input: { file_path: 'README.md' } });

for (const script of ['kill-switch.js', 'sdd-hook-guard.js']) {
  test(`${script}: real inaccessible marker parent denies instead of treating it absent`, t => {
    if (process.platform === 'win32') return t.skip('POSIX permission fixture; Windows ACL path is not exercised here');
    const root = mkdtempSync(join(tmpdir(), 'sdd-stop-inspection-'));
    const inaccessible = join(root, 'private');
    mkdirSync(inaccessible);
    chmodSync(root, 0o755);
    chmodSync(inaccessible, 0o000);
    try {
      const options = { cwd: root, env: { ...process.env, CLAUDE_PROJECT_DIR: inaccessible, PAYLOAD: payload }, encoding: 'utf8', timeout: 5000 };
      // Root bypasses mode bits; exercise the actual kernel denial as nobody.
      if (process.getuid?.() === 0) Object.assign(options, { uid: 65534, gid: 65534 });
      const result = spawnSync(process.execPath, [join(scripts, script)], options);
      assert.equal(result.error, undefined);
      assert.equal(result.status, 2, result.stderr);
      assert.match(result.stderr, /unable to inspect the stop marker/);
    } finally { chmodSync(inaccessible, 0o700); rmSync(root, { recursive: true, force: true }); }
  });

  test(`${script}: injected I/O failure denies through the public entry`, () => {
    const preload = `const fs=require('fs'); const original=fs.statSync; fs.statSync=function(p,...args){if(String(p).endsWith('AGENT_STOP')){const e=new Error('injected disk error');e.code='EIO';throw e;}return original.call(this,p,...args)};require(process.argv[1]);`;
    const result = spawnSync(process.execPath, ['-e', preload, join(scripts, script)], {
      env: { ...process.env, PAYLOAD: payload }, encoding: 'utf8', timeout: 5000,
    });
    assert.equal(result.status, 2, result.stderr);
    assert.match(result.stderr, /unable to inspect the stop marker/);
  });
}

for (const marker of ['absent', 'directory', 'file']) {
  test(`marker contract remains regular-file-only: ${marker}`, () => {
    const root = mkdtempSync(join(tmpdir(), 'sdd-stop-control-'));
    try {
      const stop = join(root, 'AGENT_STOP');
      if (marker === 'directory') mkdirSync(stop);
      if (marker === 'file') writeFileSync(stop, '');
      for (const script of ['kill-switch.js', 'sdd-hook-guard.js']) {
        const result = spawnSync(process.execPath, [join(scripts, script)], {
          cwd: root, env: { ...process.env, CLAUDE_PROJECT_DIR: root, PAYLOAD: payload }, encoding: 'utf8', timeout: 5000,
        });
        assert.equal(result.status, marker === 'file' ? 2 : 0, result.stderr);
      }
    } finally { rmSync(root, { recursive: true, force: true }); }
  });
}

test('Copilot gets a structured deny when stop-marker inspection fails', () => {
  const preload = `const fs=require('fs'); const original=fs.statSync; fs.statSync=function(p,...args){if(String(p).endsWith('AGENT_STOP')){const e=new Error('injected disk error');e.code='EIO';throw e;}return original.call(this,p,...args)};require(process.argv[1]);`;
  const result = spawnSync(process.execPath, ['-e', preload, join(scripts, 'sdd-hook-guard.js'), '--emit', 'copilot'], {
    env: { ...process.env, PAYLOAD: payload }, encoding: 'utf8', timeout: 5000,
  });
  assert.equal(result.status, 0);
  assert.equal(JSON.parse(result.stdout).permissionDecision, 'deny');
});

 test('signed stop-bypass token rejects partially parsed epoch fields', () => {
  const root = realpathSync(mkdtempSync(join(tmpdir(), 'sdd-epoch-boundary-')));
  const key = 'epoch-boundary-test-key';
  try {
    const issued = String(Math.floor(Date.now() / 1000) - 1);
    const expires = String(Number(issued) + 60);
    const nonce = 'a'.repeat(32);
    const canonical = ['fixture', nonce, root, issued, expires].join('\n');
    const sig = createHmac('sha256', key).update(canonical).digest('hex');
    for (const suffix of ['', 'oops', '.5', 'e0']) {
      writeFileSync(join(root, ['SDD', 'SUDO'].join('_')), `issuer: fixture\nnonce: ${nonce}\nrepo: ${root}\nissued-epoch: ${issued}${suffix}\nexpires-epoch: ${expires}\nsig: ${sig}\n`);
      const result = spawnSync(process.execPath, [join(scripts, 'sdd-hook-guard.js')], {
        cwd: root, encoding: 'utf8', timeout: 5000,
        env: { ...process.env, CLAUDE_PROJECT_DIR: root, SDD_SUDO_KEY: key, PAYLOAD: JSON.stringify({
          tool_name: 'Write', tool_input: { file_path: join(root, 'tasks.md'), content: ['Approval', 'Approved'].join(': ') },
        }) },
      });
      assert.equal(result.status, suffix === '' ? 0 : 2, `epoch suffix ${JSON.stringify(suffix)}: ${result.stderr}`);
    }
  } finally { rmSync(root, { recursive: true, force: true }); }
});

for (const mode of ['exit', 'copilot']) {
  test(`hook stdin error fails closed through ${mode} public entry`, () => {
    const preload = `const {PassThrough}=require('node:stream'); const input=new PassThrough(); Object.defineProperty(process,'stdin',{value:input}); require(process.argv[1]); process.nextTick(()=>input.destroy(new Error('injected stdin error')));`;
    const env = { ...process.env };
    delete env.PAYLOAD;
    const result = spawnSync(process.execPath, ['-e', preload, join(scripts, 'sdd-hook-guard.js'), '--emit', mode], {
      env, encoding: 'utf8', timeout: 5000,
    });
    assert.equal(result.error, undefined);
    if (mode === 'copilot') {
      assert.equal(result.status, 0);
      const decision = JSON.parse(result.stdout);
      assert.equal(decision.permissionDecision, 'deny');
      assert.match(decision.permissionDecisionReason, /unable to read the hook payload/);
    } else {
      assert.equal(result.status, 2, result.stderr);
      assert.equal(result.stdout, '');
      assert.match(result.stderr, /unable to read the hook payload/);
    }
  });
}
