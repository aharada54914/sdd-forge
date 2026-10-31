#!/usr/bin/env node
// Issue 290: a bounded, one-reviewer native launch.
// --probe never reserves an identity or starts a model turn.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import readline from 'node:readline';
import {spawn, spawnSync} from 'node:child_process';

const root = path.resolve(process.argv[2] || '.');
const mode = process.argv[3];
const isEntrypoint = process.argv[1] && path.resolve(process.argv[1]) === path.resolve(new URL(import.meta.url).pathname);
const attemptArg = process.argv[4];
if (isEntrypoint && (!['--probe', '--launch', '--launch-b'].includes(mode) || !/^[1-9][0-9]*$/.test(attemptArg || '') || !Number.isSafeInteger(Number(attemptArg))))
  throw Error('usage: node issue290-guarded-task-review-launch.mjs <repo> <--probe|--launch|--launch-b> <positive-attempt>');
const attempt = isEntrypoint ? Number(attemptArg) : 5;
const feature = 'sdd-domain-concept-test';
const stage = 'task';
const role = mode === '--launch-b' ? 'task-reviewer-b' : 'task-reviewer-a';
const roleLetter = role.endsWith('-b') ? 'b' : 'a';
const codexBinary = '/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex';
const roundDir = `reports/task-review/${feature}/attempt-${attempt}/round-1`;
const ledgerPath = 'reports/review-context/identity-ledger.json';
const outputDir = path.join(root, roundDir);
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const read = relative => fs.readFileSync(path.join(root, relative));
const fail = message => { throw Error(message); };
const assert = (condition, message) => { if (!condition) fail(message); };
const hex64 = /^[0-9a-f]{64}$/;

export function inputDigest(relativePath, bytes, precheck) {
  if (relativePath === `specs/${feature}/tasks.md`) {
    assert(precheck.tasks_sha256_form === 'normalized' && hex64.test(precheck.tasks_sha256), 'wrong task hash form');
    return precheck.tasks_sha256;
  }
  return sha(bytes);
}

function command(args) {
  const result = spawnSync('rtk', ['proxy', ...args], {cwd: root, encoding: 'utf8', timeout: 60000, maxBuffer: 1024 * 1024});
  if (result.error || result.status !== 0) fail(`command rejected or failed: ${args[0]} ${args[1]} (exit=${result.status}, error=${result.error?.code || 'none'}); no retry by another route`);
  return result.stdout.trim();
}

function ledgerTip() {
  const ledgerBytes = read(ledgerPath);
  const ledger = JSON.parse(ledgerBytes);
  assert(ledger.schema === 'review-identity-ledger/v1' && Array.isArray(ledger.records) && ledger.records.length, 'invalid ledger');
  const tip = ledger.records.at(-1);
  assert(Number.isSafeInteger(tip.sequence) && hex64.test(tip.record_sha256), 'invalid ledger tip');
  return {ledgerHash: sha(ledgerBytes), sequence: tip.sequence + 1, previous: tip.record_sha256};
}

export function reviewerInputPaths(letter, currentRoundDir) {
  assert(['a', 'b'].includes(letter), 'unknown reviewer role');
  return [
    'plugins/sdd-review-loop/references/reviewer-calibration.md',
    ...(letter === 'b' ? [
      'plugins/sdd-quality-loop/references/risk-classification-policy.md',
      'plugins/sdd-quality-loop/references/risk-gate-matrix.md',
      `${currentRoundDir}/integrated-summary.json`
    ] : [
      `${currentRoundDir}/dependency-graph.json`,
    ]),
    `${currentRoundDir}/precheck-result.json`,
    `specs/${feature}/acceptance-tests.md`,
    `specs/${feature}/design.md`,
    `specs/${feature}/frontend-spec.md`,
    `specs/${feature}/infra-spec.md`,
    `specs/${feature}/requirements.md`,
    `specs/${feature}/security-spec.md`,
    `specs/${feature}/tasks.md`,
    `specs/${feature}/traceability.md`,
    `specs/${feature}/ux-spec.md`
  ];
}

function inputs() {
  const paths = reviewerInputPaths(roleLetter, roundDir);
  const precheck = JSON.parse(read(`${roundDir}/precheck-result.json`));
  assert(precheck.feature === feature && precheck.attempt === attempt && precheck.round === 1, 'wrong precheck identity');
  assert(precheck.tasks_sha256_form === 'normalized' && hex64.test(precheck.tasks_sha256), 'wrong task hash form');
  if (roleLetter === 'b') {
    const summary = JSON.parse(read(`${roundDir}/integrated-summary.json`));
    const keys = ['schema', 'round', 'attempt', 'reviewer_a_check_ids', 'reviewer_a_fail_count', 'reviewer_a_pass_count', 'reviewer_a_skip_count', 'generated_at'];
    assert(JSON.stringify(Object.keys(summary).sort()) === JSON.stringify(keys.sort()), 'summary contains extra or missing fields');
    assert(summary.schema === 'integrated-summary/v1' && summary.attempt === attempt && summary.round === 1, 'wrong summary identity');
    const expected = 'PREREQ-AC-IDS,BLOCKERS-FORMAT,REQ-COVERAGE,AC-COVERAGE,ORPHAN-TASK,ORPHAN-TEST,INITIAL-STATE,RISK-WORKFLOW-FORMAT,NO-DUPLICATE-AC,DEPENDENCY-COMPLETE,DEPENDENCY-CYCLE,SINGLE-CONCERN,OBSERVABLE-DONE,TRACEABILITY-SYNC'.split(',');
    assert(JSON.stringify(summary.reviewer_a_check_ids) === JSON.stringify(expected), 'wrong A check order');
    assert(['reviewer_a_fail_count', 'reviewer_a_pass_count', 'reviewer_a_skip_count'].every(k => Number.isSafeInteger(summary[k]) && summary[k] >= 0), 'invalid A result counts');
    assert(summary.reviewer_a_fail_count + summary.reviewer_a_pass_count + summary.reviewer_a_skip_count === 14, 'wrong A result counts');
  }
  return paths.map(p => {
    const bytes = read(p); // Every admitted file must exist and be readable before reservation.
    return {path: p, sha256: inputDigest(p, bytes, precheck)};
  });
}

export function verifyIdle(start, reread) {
  const thread = start?.thread;
  assert(thread && typeof thread.id === 'string' && thread.id.length > 0, 'missing host thread ID');
  assert(thread.sessionId === thread.id, 'host session is not root thread ID');
  assert(thread.status?.type === 'idle' && thread.preview === '', 'thread not empty and idle');
  assert(thread.parentThreadId == null && thread.forkedFromId == null, 'inherited or forked context');
  assert(thread.ephemeral === true && thread.cwd === root, 'unexpected thread storage or cwd');
  assert(start.sandbox?.type === 'readOnly' && start.sandbox.networkAccess === false, 'not read-only');
  assert(start.approvalPolicy === 'never', 'unexpected approval policy');
  assert(thread.model === 'gpt-5.6-sol', 'wrong model');
  assert(reread?.thread?.id === thread.id && reread.thread.status?.type === 'idle', 'thread changed before reserve');
  return thread.id;
}

export function verifyReceipt(line, manifest) {
  const match = /^REVIEW_CONTEXT_OK ([0-9a-f]{64}) sequence=(\d+) previous_record_sha256=([0-9a-f]{64}|-) pre_append_tip_sequence=(\d+) identity_unique=yes$/.exec(line);
  assert(match, 'missing or incomplete REVIEW_CONTEXT_OK receipt');
  const expected = sha(`${manifest.sequence}|${manifest.stage}|${manifest.role}|${manifest.run_id}|${manifest.host_session_id}|${manifest.previous_record_sha256}`);
  assert(match[1] === expected && Number(match[2]) === manifest.sequence, 'receipt record hash or sequence mismatch');
  assert(match[3] === manifest.previous_record_sha256 && Number(match[4]) === manifest.sequence - 1, 'receipt chain mismatch');
  return {record_sha256: match[1], sequence: manifest.sequence, previous_record_sha256: match[3], identity_unique: true};
}

export function acceptReviewEvent(event, threadId, turnId, messages) {
  if (!['item/completed', 'turn/completed'].includes(event.method)) return null;
  const params = event.params;
  assert(params?.threadId === threadId, 'review event crossed thread boundary');
  assert((params.turnId ?? params.turn?.id) === turnId, 'review event crossed turn boundary');
  if (event.method === 'item/completed') {
    if (params.item?.type === 'agentMessage' && typeof params.item.text === 'string')
      messages.set(params.item.id, params.item.text);
    return null;
  }
  for (const item of params.turn?.items || []) {
    if (item?.type === 'agentMessage' && typeof item.text === 'string') messages.set(item.id, item.text);
  }
  return params;
}

export function buildReviewerPrompt(roleInstructions, manifestPath, receiptLine, reviewAttempt) {
  const taskPath = `specs/${feature}/tasks.md`;
  assert(Number.isSafeInteger(reviewAttempt) && reviewAttempt > 0, 'invalid review attempt');
  return `${roleInstructions}\n\nInvocation: stage=task, feature=${feature}, attempt=${reviewAttempt}, round=1, role=${role}. Manifest: ${manifestPath}. The caller ran the original validator with --reserve and verified this complete, quoted response:\n${receiptLine}\n\nUse ONLY the allowed_input_manifest. Perform an independent post-implementation provenance re-review. ${roleLetter === 'b' ? 'The integrated-summary.json has reviewer A check IDs and counts only; never read reviewer-a.json or any reviewer raw output. ' : ''}For ${taskPath} ONLY, the manifest and precheck-result.json declare tasks_sha256_form=normalized: verify its manifest digest using the original task-review precheck/validator canonical form 1, NOT the raw file SHA-256. That form changes Task-Review-Status to Pending, Approval to Draft, Status to Planned, and deletes Second Approval lines before SHA-256; all other admitted files use their raw SHA-256. A raw-versus-normalized difference for ${taskPath} is not an input mismatch. Reject any mismatch in the applicable digest or any other launch-boundary failure before substantive review. Emit only the role's canonical JSON result. Do not read previous reviewer outputs or the identity ledger.`;
}

export class AppServer {
  constructor(child = spawn('rtk', ['proxy', codexBinary, 'app-server', '--listen', 'stdio://'], {cwd: root, stdio: ['pipe', 'pipe', 'ignore']})) {
    this.child = child;
    this.pending = new Map();
    this.nextId = 1;
    this.buffer = '';
    this.malformedMessages = 0;
    this.notifications = [];
    this.notificationWaiters = [];
    this.child.stdout.on('data', chunk => this.consume(chunk));
    this.child.on('error', error => this.abort(`app-server spawn error (${error.code || 'unknown'})`));
    this.child.on('exit', (code, signal) => this.abort(`app-server exited (code=${code}, signal=${signal})`));
  }
  abort(reason) {
    if (this.closed) return;
    this.closed = true;
    const error = Error(reason);
    for (const entry of this.pending.values()) entry.reject(error);
    this.pending.clear();
    for (const waiter of this.notificationWaiters) waiter.reject(error);
    this.notificationWaiters = [];
  }
  consume(chunk) {
    this.buffer += chunk;
    let end;
    while ((end = this.buffer.indexOf('\n')) >= 0) {
      const line = this.buffer.slice(0, end); this.buffer = this.buffer.slice(end + 1);
      let message;
      try { message = JSON.parse(line); } catch { this.malformedMessages++; continue; }
      if (message.id === undefined) {
        const waiter = this.notificationWaiters.shift();
        if (waiter) waiter.resolve(message);
        else this.notifications.push(message);
        continue;
      }
      const entry = this.pending.get(message.id);
      if (!entry) continue;
      this.pending.delete(message.id);
      if (message.error) entry.reject(Error(`app-server ${entry.method} error code=${message.error.code}; malformed_stdout_lines=${this.malformedMessages}`));
      else entry.resolve(message.result);
    }
  }
  send(method, params) {
    if (this.closed) return Promise.reject(Error('app-server already closed'));
    const id = this.nextId++;
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {this.pending.delete(id); reject(Error(`${method} timed out`));}, 30000);
      this.pending.set(id, {method, resolve: value => {clearTimeout(timer); resolve(value);}, reject: error => {clearTimeout(timer); reject(error);}});
      this.child.stdin.write(JSON.stringify({id, method, params}) + '\n');
    });
  }
  notify(method) { this.child.stdin.write(JSON.stringify({method}) + '\n'); }
  nextNotification(timeoutMs = 20 * 60 * 1000) {
    if (this.notifications.length) return Promise.resolve(this.notifications.shift());
    if (this.closed) return Promise.reject(Error('app-server already closed'));
    return new Promise((resolve, reject) => {
      const waiter = {
        resolve: value => {clearTimeout(timer); resolve(value);},
        reject: error => {clearTimeout(timer); reject(error);}
      };
      const timer = setTimeout(() => {
        this.notificationWaiters = this.notificationWaiters.filter(entry => entry !== waiter);
        reject(Error(`notification timed out; malformed_stdout_lines=${this.malformedMessages}`));
      }, timeoutMs);
      this.notificationWaiters.push(waiter);
    });
  }
  close() { this.abort('app-server closed by launcher'); this.child.stdin.end(); this.child.kill(); }
}

async function main() {
  assert(fs.existsSync(path.join(root, 'AGENTS.md')), 'repository root required');
  let preparedInputs;
  let roleInstructions;
  if (mode === '--launch' || mode === '--launch-b') {
    // Retain the lock even on failure: a human must audit any partially reserved identity.
    const lockPath = path.join(outputDir, `reviewer-${roleLetter}-native-launch.lock`);
    fs.writeFileSync(lockPath, JSON.stringify({pid: process.pid, startedAt: new Date().toISOString(), role}) + '\n', {flag: 'wx', mode: 0o600});
    const roundEntries = fs.readdirSync(outputDir);
    const nativePrefix = roleLetter === 'a' ? '' : 'b-';
    assert(!roundEntries.some(name => name === `reviewer-${roleLetter}.json` || name.startsWith(`reserved-${nativePrefix}`) || name.startsWith(`native-turn-${nativePrefix}`) || name.startsWith(`native-turn-aborted-${nativePrefix}`)), `existing reviewer ${roleLetter} launch/output; no duplicate launch`);
    const contextEntries = fs.readdirSync(path.join(root, 'reports/review-context'));
    assert(!contextEntries.some(name => name.startsWith(`${feature}-task-a${attempt}r1-${roleLetter}-`) && name.endsWith('-invocation.json')), `existing reviewer ${roleLetter} invocation; no duplicate launch`);
    command(['bash', 'plugins/sdd-review-loop/scripts/task-review-precheck.sh', feature, String(attempt), '1', '--verify-inputs']);
    preparedInputs = inputs();
    const roleFile = read(`plugins/sdd-review-loop/agents/task-reviewer-${roleLetter}.md`).toString('utf8');
    roleInstructions = roleFile.replace(/^---\n[\s\S]*?\n---\n/, '').replace(/^<!-- x-sdd-effort: [^\n]* -->\n/, '');
    assert(roleInstructions.includes('REVIEW_CONTEXT_OK') && roleInstructions.includes(roleLetter === 'a' ? 'Structural Coverage Reviewer' : 'Quality and Risk Reviewer'), `invalid reviewer ${roleLetter} role instructions`);
  }
  const server = new AppServer();
  try {
    await server.send('initialize', {clientInfo: {name: 'issue290-guarded-task-review', version: '1'}, capabilities: {experimentalApi: true}});
    server.notify('initialized');
    const start = await server.send('thread/start', {
      cwd: root, sandbox: 'read-only', approvalPolicy: 'never', ephemeral: true,
      model: 'gpt-5.6-sol', allowProviderModelFallback: false
    });
    const id = start?.thread?.id;
    assert(typeof id === 'string' && id.length > 0, 'thread/start returned no ID');
    const reread = await server.send('thread/read', {threadId: id, includeTurns: false});
    const runId = verifyIdle(start, reread);
    assert(server.malformedMessages === 0, 'malformed app-server stdout before reservation');
    const allocation = {schema: 'issue290-idle-allocation/v1', feature, attempt, round: 1, role, host_thread_id: runId, host_session_id: start.thread.sessionId, status: 'idle', forked: false, model: start.thread.model, sandbox: start.sandbox, reservation: false, turn_started: false};
    if (mode === '--probe') {
      const location = path.join(outputDir, `idle-probe-${runId}.json`);
      fs.writeFileSync(location, JSON.stringify(allocation, null, 2) + '\n', {flag: 'wx', mode: 0o600});
      process.stdout.write(JSON.stringify({status: 'IDLE_ONLY', receipt: location, host_thread_id: runId}) + '\n');
      return;
    }
    const tip = ledgerTip();
    const manifest = {
      schema: 'review-context-invocation/v2', stage, feature, role,
      run_id: runId, host_session_id: runId, input_mode: 'file-manifest',
      fallback_mode: 'none', read_only: true, identity_ledger_path: ledgerPath,
      identity_ledger_sha256: tip.ledgerHash, previous_record_sha256: tip.previous,
      sequence: tip.sequence, allowed_input_manifest: preparedInputs
    };
    const manifestPath = path.join(root, 'reports/review-context', `${feature}-task-a${attempt}r1-${roleLetter}-${runId}-invocation.json`);
    fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + '\n', {flag: 'wx', mode: 0o600});
    const line = command(['bash', 'plugins/sdd-quality-loop/scripts/validate-review-context-set.sh', manifestPath, root, '--reserve']);
    const receipt = verifyReceipt(line, manifest);
    const reserved = {...allocation, reservation: true, validator_receipt: receipt, manifest_path: manifestPath};
    const receiptPath = path.join(outputDir, `reserved-${roleLetter === 'a' ? '' : 'b-'}${runId}.json`);
    fs.writeFileSync(receiptPath, JSON.stringify(reserved, null, 2) + '\n', {flag: 'wx', mode: 0o600});
    const prompt = buildReviewerPrompt(roleInstructions, manifestPath, line, attempt);
    const resultPath = path.join(outputDir, `native-turn-${roleLetter === 'a' ? '' : 'b-'}${runId}.json`);
    const messages = new Map();
    let turn;
    let completed;
    try {
      turn = await server.send('turn/start', {threadId: runId, input: [{type: 'text', text: prompt}], model: 'gpt-5.6-sol', effort: 'high'});
      assert(typeof turn?.turn?.id === 'string', 'turn/start returned no turn ID');
      process.stdout.write(JSON.stringify({status: 'FIRST_TURN_STARTED', host_thread_id: runId, turn_id: turn.turn.id, manifest: manifestPath, receipt: receiptPath}) + '\n');
      while (!completed) completed = acceptReviewEvent(await server.nextNotification(), runId, turn.turn.id, messages);
      const nativeTurn = {
        threadId: runId, turnId: turn.turn.id, status: completed.turn.status,
        agentMessages: [...messages].map(([itemId, text]) => ({itemId, text})),
        completedTurn: completed.turn, malformed_stdout_lines: server.malformedMessages
      };
      fs.writeFileSync(resultPath, JSON.stringify(nativeTurn, null, 2) + '\n', {flag: 'wx', mode: 0o600});
      assert(server.malformedMessages === 0, 'malformed app-server stdout during reviewer turn');
      assert(completed.turn.status === 'completed' && messages.size > 0, 'turn ended without completed assistant output');
      process.stdout.write(JSON.stringify({status: completed.turn.status, host_thread_id: runId, turn_id: turn.turn.id, native_turn: resultPath}) + '\n');
    } catch (error) {
      const abortedPath = path.join(outputDir, `native-turn-aborted-${roleLetter === 'a' ? '' : 'b-'}${runId}.json`);
      fs.writeFileSync(abortedPath, JSON.stringify({threadId: runId, turnId: turn?.turn?.id ?? null,
        status: 'ABORTED_OR_UNVERIFIED', reason: error.message, malformed_stdout_lines: server.malformedMessages,
        agentMessages: [...messages].map(([itemId, text]) => ({itemId, text}))}, null, 2) + '\n', {flag: 'wx', mode: 0o600});
      throw error;
    }
  } finally { server.close(); }
}

if (isEntrypoint) {
  main().catch(error => {process.stderr.write(`STOP: ${error.message}\n`); process.exitCode = 1;});
}
