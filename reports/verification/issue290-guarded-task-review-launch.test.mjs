import test from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import {EventEmitter} from 'node:events';
import {AppServer, acceptReviewEvent, buildReviewerPrompt, inputDigest, reviewerInputPaths, verifyIdle, verifyReceipt} from './issue290-guarded-task-review-launch.mjs';

const hash = text => crypto.createHash('sha256').update(text).digest('hex');
const id = '01a1033f-5902-7830-97e6-934dbcc8d3b5';
const idle = {
  thread: {id, sessionId: id, status: {type: 'idle'}, preview: '', parentThreadId: null,
    forkedFromId: null, model: 'gpt-5.6-sol', ephemeral: true, cwd: process.cwd()},
  sandbox: {type: 'readOnly', networkAccess: false}, approvalPolicy: 'never'
};

test('accepts a host-issued empty root idle thread on a read-only Sol session', () => {
  assert.equal(verifyIdle(idle, {thread: {id, status: {type: 'idle'}}}), id);
});
test('rejects an inherited context and a non-idle reread', () => {
  assert.throws(() => verifyIdle({...idle, thread: {...idle.thread, parentThreadId: 'parent'}}, {thread: {id, status: {type: 'idle'}}}));
  assert.throws(() => verifyIdle(idle, {thread: {id, status: {type: 'active'}}}));
});
test('rejects wrong session, model, and sandbox', () => {
  assert.throws(() => verifyIdle({...idle, thread: {...idle.thread, sessionId: 'other'}}, {thread: {id, status: {type: 'idle'}}}));
  assert.throws(() => verifyIdle({...idle, thread: {...idle.thread, model: 'gemini'}}, {thread: {id, status: {type: 'idle'}}}));
  assert.throws(() => verifyIdle({...idle, sandbox: {type: 'dangerFullAccess'}}, {thread: {id, status: {type: 'idle'}}}));
});
test('validates the original reservation receipt fields and record hash', () => {
  const m = {sequence: 1212, stage: 'task', role: 'task-reviewer-a', run_id: id,
    host_session_id: id, previous_record_sha256: 'a'.repeat(64)};
  const recordHash = hash(`${m.sequence}|${m.stage}|${m.role}|${m.run_id}|${m.host_session_id}|${m.previous_record_sha256}`);
  const line = `REVIEW_CONTEXT_OK ${recordHash} sequence=1212 previous_record_sha256=${m.previous_record_sha256} pre_append_tip_sequence=1211 identity_unique=yes`;
  assert.equal(verifyReceipt(line, m).record_sha256, recordHash);
  assert.throws(() => verifyReceipt(line.replace('identity_unique=yes', 'identity_unique=no'), m));
  assert.throws(() => verifyReceipt(line.replace('pre_append_tip_sequence=1211', 'pre_append_tip_sequence=1210'), m));
  assert.throws(() => verifyReceipt(line.replace(recordHash, 'b'.repeat(64)), m));
});
test('first-turn instructions distinguish normalized task digest from raw input hashes', () => {
  const prompt = buildReviewerPrompt('ROLE INSTRUCTIONS', '/absolute/invocation.json', 'REVIEW_CONTEXT_OK receipt', 6);
  assert.match(prompt, /attempt=6, round=1/);
  assert.doesNotMatch(prompt, /attempt=5/);
  assert.match(prompt, /specs\/sdd-domain-concept-test\/tasks\.md ONLY/);
  assert.match(prompt, /tasks_sha256_form=normalized/);
  assert.match(prompt, /NOT the raw file SHA-256/);
  assert.match(prompt, /Task-Review-Status to Pending, Approval to Draft, Status to Planned, and deletes Second Approval/);
  assert.match(prompt, /all other admitted files use their raw SHA-256/);
  assert.match(prompt, /Reject any mismatch in the applicable digest/);
  assert.match(prompt, /REVIEW_CONTEXT_OK receipt/);
  assert.throws(() => buildReviewerPrompt('role', '/manifest', 'receipt', 0), /invalid review attempt/);
});
test('task manifest uses precheck normalized digest while sibling inputs remain raw', () => {
  const bytes = Buffer.from('Approval: Approved\nStatus: Implementation Complete\n');
  const normalized = '6'.repeat(64);
  const precheck = {tasks_sha256_form: 'normalized', tasks_sha256: normalized};
  assert.notEqual(hash(bytes), normalized);
  assert.equal(inputDigest('specs/sdd-domain-concept-test/tasks.md', bytes, precheck), normalized);
  assert.equal(inputDigest('specs/sdd-domain-concept-test/design.md', bytes, precheck), hash(bytes));
  assert.throws(() => inputDigest('specs/sdd-domain-concept-test/tasks.md', bytes,
    {tasks_sha256_form: 'raw', tasks_sha256: normalized}), /wrong task hash form/);
});
test('reviewer B gets risk references and ID-only summary, never reviewer A raw output', () => {
  const paths = reviewerInputPaths('b', 'reports/task-review/sdd-domain-concept-test/attempt-6/round-1');
  assert.equal(paths.length, 14);
  assert(paths.includes('plugins/sdd-quality-loop/references/risk-gate-matrix.md'));
  assert(paths.includes('plugins/sdd-quality-loop/references/risk-classification-policy.md'));
  assert(paths.includes('plugins/sdd-review-loop/references/reviewer-calibration.md'));
  assert(paths.includes('reports/task-review/sdd-domain-concept-test/attempt-6/round-1/integrated-summary.json'));
  assert(!paths.some(p => /reviewer-a\.json|native-turn|identity-ledger/.test(p)));
  assert(!reviewerInputPaths('a', 'round').some(p => /risk-gate-matrix|integrated-summary/.test(p)));
  assert.throws(() => reviewerInputPaths('quality', 'round'), /unknown reviewer/);
});
test('preserves completed assistant text from item/completed even when turn/completed omits items', () => {
  const messages = new Map();
  assert.equal(acceptReviewEvent({method: 'item/completed', params: {threadId: id, turnId: 'turn-1', item: {id: 'item-1', type: 'agentMessage', text: '{"verdict":"PASS"}'}}}, id, 'turn-1', messages), null);
  const completion = acceptReviewEvent({method: 'turn/completed', params: {threadId: id, turn: {id: 'turn-1', status: 'completed', items: []}}}, id, 'turn-1', messages);
  assert.equal(completion.turn.status, 'completed');
  assert.equal(messages.get('item-1'), '{"verdict":"PASS"}');
  assert.throws(() => acceptReviewEvent({method: 'item/completed', params: {threadId: 'other', turnId: 'turn-1', item: {type: 'agentMessage', text: 'wrong'}}}, id, 'turn-1', messages));
  assert.throws(() => acceptReviewEvent({method: 'turn/completed', params: {threadId: id, turn: {id: 'other', status: 'completed'}}}, id, 'turn-1', messages));
});
function fakeChild() {
  const child = new EventEmitter();
  child.stdout = new EventEmitter();
  child.stdin = {write() {}, end() {}};
  child.kill = () => {};
  return child;
}
test('child exit rejects both pending RPC and notification wait', async () => {
  const child = fakeChild();
  const server = new AppServer(child);
  const rpc = server.send('thread/read', {threadId: id});
  const notification = server.nextNotification(1000);
  child.emit('exit', 1, null);
  await assert.rejects(rpc, /app-server exited/);
  await assert.rejects(notification, /app-server exited/);
  assert.equal(server.pending.size, 0);
  assert.equal(server.notificationWaiters.length, 0);
});
test('spawn error rejects a pending request without leaking process output', async () => {
  const child = fakeChild();
  const server = new AppServer(child);
  const rpc = server.send('initialize', {});
  child.emit('error', Object.assign(Error('private process detail'), {code: 'ENOENT'}));
  await assert.rejects(rpc, /app-server spawn error \(ENOENT\)/);
  assert.equal(server.pending.size, 0);
});
test('notification timeout cleans up its waiter; malformed stdout is counted', async () => {
  const child = fakeChild();
  const server = new AppServer(child);
  child.stdout.emit('data', Buffer.from('not-json\n'));
  assert.equal(server.malformedMessages, 1);
  await assert.rejects(server.nextNotification(5), /malformed_stdout_lines=1/);
  assert.equal(server.notificationWaiters.length, 0);
  server.close();
});
