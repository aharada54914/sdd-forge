import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { PassThrough } from 'node:stream';
import { test } from 'node:test';
import { AuditLog } from './native-audit.mjs';
const { observeTransport } = await import('./native-controller.mjs');
const base = path.dirname(fileURLToPath(import.meta.url));
const request = { id: 7, method: 'item/tool/call', params: { tool: 'synthetic', arguments: { argv: ['read', '/fixture'], env: { TOKEN: 'NEVER_RECORD' } } } };
const denial = { method: 'codex/event/exec_command_end', params: { msg: { stderr: '疑似拒否: not executed', exit_code: 2 } } };
function fixture() {
  const dir = fs.mkdtempSync(path.join(base, 'controller-fixture-'));
  const file = path.join(dir, 'audit.jsonl');
  const audit = new AuditLog(file);
  const readable = new PassThrough();
  const writable = new PassThrough();
  return { audit, readable, writable, read: () => fs.readFileSync(file, 'utf8'),
    cleanup() { audit.close(); readable.destroy(); writable.destroy(); fs.rmSync(dir, { recursive: true }); } };
}
test('byte splits, multiple events, EOF flush, audit precedes safe summary and reply', async () => {
  const f = fixture();
  const summaries = [];
  let wire = '';
  f.writable.on('data', b => { assert.ok(f.read().includes('synthetic deny')); wire += b; });
  try {
    const run = observeTransport({ ...f, onRecorded: async row => {
      assert.ok(f.read().includes(JSON.stringify(row)));
      summaries.push(row);
      if (row.event.id === 7) return { id: 7, result: { error: 'synthetic deny', token: 'NEVER_RECORD' } };
    } });
    const payload = Buffer.from(JSON.stringify(request) + '\n' + JSON.stringify({ method: 'config/read', params: { value: 'NEVER_RECORD' } }) + '\n' + JSON.stringify(denial));
    const split = payload.indexOf(Buffer.from('疑')) + 1;
    f.readable.write(payload.subarray(0, 17));
    f.readable.write(payload.subarray(17, split));
    f.readable.end(payload.subarray(split));
    await run;
    const rows = f.read().trim().split('\n').map(JSON.parse);
    assert.equal(rows.length, 3);
    assert.deepEqual(rows[0].event.params.arguments.argv, ['read', '/fixture']);
    assert.equal(rows[2].event.params.msg.stderr, denial.params.msg.stderr);
    assert.equal(summaries.length, 2);
    assert.ok(!f.read().includes('NEVER_RECORD'));
    assert.ok(!JSON.stringify(summaries).includes('NEVER_RECORD'));
    assert.equal(JSON.parse(wire).id, 7);
  } finally { f.cleanup(); }
});
test('incomplete EOF is failure, not successful flush', async () => {
  const f = fixture();
  try { const run = observeTransport(f); f.readable.end('{'); await assert.rejects(run, /invalid JSON/); assert.equal(f.read(), ''); }
  finally { f.cleanup(); }
});
test('summary failure leaves durable request and stops observation', async () => {
  const f = fixture();
  try {
    const run = observeTransport({ ...f, onRecorded() { throw new Error('summary failed'); } });
    f.readable.end(JSON.stringify(request) + '\n');
    await assert.rejects(run, /summary failed/);
    assert.ok(f.read().includes('argv'));
    assert.equal(f.audit.closed, true);
  } finally { f.cleanup(); }
});
test('correlated initialize and allocation responses survive alongside tool events without private fields', async () => {
  const f = fixture();
  const responses = [];
  try {
    const run = observeTransport({ ...f,
      responseMethods: new Map([[1, 'initialize'], [2, 'thread/start']]),
      onResponse: row => { assert.ok(f.read().includes(JSON.stringify(row))); responses.push(row); },
    });
    f.readable.end([
      { id: 1, result: { userAgent: 'synthetic-cli', config: { token: 'NEVER_RECORD' } } },
      request,
      { id: 2, result: { model: 'synthetic-model', modelProvider: 'synthetic-provider', reasoningEffort: 'high', approvalPolicy: 'never', sandbox: { type: 'dangerFullAccess' }, instructionSources: ['/fixture/AGENTS.md'], thread: { id: 'synthetic-thread', sessionId: 'synthetic-session', status: { type: 'idle' }, turns: [], token: 'NEVER_RECORD' }, config: { token: 'NEVER_RECORD' } } },
      { id: 3, result: { secret: 'NEVER_RECORD' } },
      denial,
    ].map(JSON.stringify).join('\n'));
    await run;
    assert.equal(responses.length, 2);
    assert.equal(responses[1].event.result.thread.sessionId, 'synthetic-session');
    assert.equal(responses[1].event.result.thread.turnCount, 0);
    assert.equal(f.read().trim().split('\n').length, 4);
    assert.ok(!f.read().includes('NEVER_RECORD'));
  } finally { f.cleanup(); }
});
