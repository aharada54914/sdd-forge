import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';

const legacy = process.argv.includes('--legacy');
const module = legacy ? null : await import('./native-audit.mjs');
const base = path.dirname(fileURLToPath(import.meta.url));
function fixture() {
  const dir = fs.mkdtempSync(path.join(base, 'audit-fixture-'));
  const file = path.join(dir, 'events.jsonl');
  let rows = [];
  const recorder = legacy ? {
    capture(direction, line) {
      const event = JSON.parse(line);
      // Reproduces the prior observer's item/completed-only event filter.
      if (['item/completed', 'turn/completed', 'error'].includes(event.method)) rows.push(event);
    }, close() {},
  } : new module.AuditLog(file);
  return { recorder, file, read() { return legacy ? rows : fs.readFileSync(file, 'utf8').trim().split('\n').filter(Boolean).map(JSON.parse); },
    cleanup() { recorder.close(); fs.rmSync(dir, { recursive: true }); } };
}
const command = "rtk proxy rg -n 'literal' /fixture/guard.py";
const request = { method: 'codex/event/exec_command_begin', params: { msg: { type: 'exec_command_begin', call_id: 'synthetic-call', command: ['zsh', '-c', command], cwd: '/fixture' } } };
const refusal = { method: 'codex/event/exec_command_end', params: { msg: { type: 'exec_command_end', call_id: 'synthetic-call', exit_code: 2, stderr: 'Synthetic PreToolUse refusal: command did not execute.' } } };

test('retains exact synthetic tool request and refusal BEFORE summary filtering', () => {
  const f = fixture();
  try {
    f.recorder.capture('server', JSON.stringify(request));
    f.recorder.capture('server', JSON.stringify(refusal));
    const rows = f.read();
    assert.equal(rows.length, 2);
    assert.deepEqual(rows[0].event ?? rows[0], request);
    assert.deepEqual(rows[1].event ?? rows[1], refusal);
  } finally { f.cleanup(); }
});

if (!legacy) {
  test('stream fragments and Unicode survive, output deltas are not truncated', () => {
    const f = fixture();
    try {
      const event = { method: 'item/commandExecution/outputDelta', params: { itemId: 'c', delta: '読取拒否\n' + 'x'.repeat(9000) } };
      const data = JSON.stringify(event) + '\n';
      f.recorder.feed('server', data.slice(0, 31));
      f.recorder.feed('server', data.slice(31));
      assert.deepEqual(f.read()[0].event, event);
    } finally { f.cleanup(); }
  });
  test('tool item lifecycle and server approval requests are retained', () => {
    const f = fixture();
    try {
      const events = [
        { method: 'item/started', params: { item: { type: 'commandExecution', id: 'c', command } } },
        { method: 'item/commandExecution/requestApproval', id: 7, params: { command, reason: 'synthetic' } },
        { method: 'item/completed', params: { item: { type: 'commandExecution', id: 'c', aggregatedOutput: 'denied', exitCode: 2 } } },
      ];
      for (const e of events) f.recorder.capture('server', JSON.stringify(e));
      assert.deepEqual(f.read().map(r => r.event), events);
    } finally { f.cleanup(); }
  });
  test('excludes account/config/environment/reasoning notifications', () => {
    const f = fixture();
    try {
      for (const method of ['account/rateLimits/updated', 'config/read', 'environment/read', 'item/reasoning/textDelta']) {
        f.recorder.capture('server', JSON.stringify({ method, params: { secret: 'NEVER_RECORD' } }));
      }
      f.recorder.capture('server', JSON.stringify({ method: 'item/completed', params: { item: { type: 'reasoning', text: 'NEVER_RECORD' } } }));
      assert.equal(f.read().length, 0);
    } finally { f.cleanup(); }
  });
  test('secret-key payloads and credential strings are redacted with explicit notice', () => {
    const f = fixture();
    try {
      f.recorder.capture('server', JSON.stringify({ ...request, params: { ...request.params, env: { SECRET: 'NEVER_RECORD' }, config: { value: 'NEVER_RECORD' }, api_key: 'NEVER_RECORD', token: 'NEVER_RECORD', note: 'Authorization: Bearer synthetic-secret' } }));
      const raw = fs.readFileSync(f.file, 'utf8');
      assert.ok(!raw.includes('NEVER_RECORD'));
      assert.ok(!raw.includes('synthetic-secret'));
      assert.equal(f.read()[0].redacted, true);
      assert.deepEqual(f.read()[0].event.params.msg.command, request.params.msg.command);
    } finally { f.cleanup(); }
  });
  test('malformed JSON is a hard error with no raw payload saved', () => {
    const f = fixture();
    try { assert.throws(() => f.recorder.capture('server', '{NEVER_RECORD'), /invalid JSON/); assert.equal(f.read().length, 0); }
    finally { f.cleanup(); }
  });
  test('audit file is private, exclusive, and never overwrites prior evidence', () => {
    const f = fixture();
    try {
      assert.equal(fs.statSync(f.file).mode & 0o777, 0o600);
      assert.throws(() => new module.AuditLog(f.file), /EEXIST/);
    } finally { f.cleanup(); }
  });
  test('capture is durable before a throwing summary consumer runs', () => {
    const f = fixture();
    try {
      f.recorder.capture('server', JSON.stringify(request));
      assert.throws(() => { throw new Error('summary failed'); });
      assert.equal(f.read()[0].event.params.msg.call_id, 'synthetic-call');
    } finally { f.cleanup(); }
  });
  test('server tool request retains matching client result but not unrelated RPC replies', () => {
    const f = fixture();
    try {
      f.recorder.capture('server', JSON.stringify({ method: 'item/tool/call', id: 9, params: { tool: 'read', arguments: { path: '/fixture' } } }));
      f.recorder.capture('client', JSON.stringify({ id: 9, result: { success: false, contentItems: [{ text: 'synthetic refusal' }] } }));
      f.recorder.capture('client', JSON.stringify({ id: 100, result: { privateConfig: 'NEVER_RECORD' } }));
      assert.equal(f.read().length, 2);
      assert.equal(f.read()[1].event.result.success, false);
    } finally { f.cleanup(); }
  });
  test('incomplete frames cannot silently become completed evidence', () => {
    const f = fixture();
    try { f.recorder.feed('server', '{'); assert.throws(() => f.recorder.close(), /incomplete audit frame/); }
    finally { f.cleanup(); }
  });
}
