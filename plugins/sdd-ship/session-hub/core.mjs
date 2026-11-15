/** Durable coordination only; canonical workflow files and approvals stay untouched. */
export class HubError extends Error {
  constructor(code, status = 400) { super(code); this.status = status; }
}
const fail = (code, status) => { throw new HubError(code, status); };
export function text(value, max = 200) {
  if (typeof value !== 'string' || !value.trim() || value.length > max) fail('invalid-text');
  return value;
}
export function id(value) {
  if (typeof value !== 'string' || !/^[a-zA-Z0-9_-]{1,80}$/.test(value)) fail('invalid-id');
  return value;
}
export function initial(project) {
  return { schema: 'sdd-session-hub/v1', project: id(project), revision: 0, away: false,
    sessions: [], questions: [], jobs: [], verification: null };
}
export function validateState(state, project) {
  if (!state || state.schema !== 'sdd-session-hub/v1' || state.project !== project ||
      !Number.isSafeInteger(state.revision) || state.revision < 0 || typeof state.away !== 'boolean' ||
      !['sessions', 'questions', 'jobs'].every(k => Array.isArray(state[k]) && state[k].length <= 500)) fail('invalid-state', 503);
  return state;
}
export function publicState(state, actor, now = Date.now()) {
  const own = item => actor.role === 'owner' || item.sessionId === actor.sessionId;
  return { ...state, sessions: state.sessions.filter(s => actor.role === 'owner' || s.id === actor.sessionId).map(({ tokenHash, ...s }) => s),
    questions: state.questions.filter(own).map(q => ({ ...q, status: q.status === 'open' && q.expiresAt <= now ? 'expired' : q.status })),
    jobs: state.jobs.filter(own).map(j => ({ ...j, status: j.status === 'running' && j.deadline <= now ? 'uncertain' : j.status })) };
}
function owner(actor) { if (actor.role !== 'owner') fail('owner-required', 403); }
function session(state, value) {
  const found = state.sessions.find(s => s.id === id(value));
  if (!found) fail('session-not-found', 404);
  return found;
}
function scoped(actor, sessionId) { if (actor.role !== 'owner' && actor.sessionId !== sessionId) fail('session-denied', 403); }
function timestamp(value, now) {
  if (!Number.isSafeInteger(value) || value <= now || value > now + 30 * 86400000) fail('invalid-expiry');
  return value;
}
function capacity(items) { if (items.length >= 500) fail('capacity-reached', 409); }
export function transition(current, command, actor, now = Date.now()) {
  if (!command || Object.keys(command).some(k => !['project','expectedRevision','action','input'].includes(k)) || !command.input || typeof command.input !== 'object' || Array.isArray(command.input)) fail('invalid-command');
  if (command.project !== current.project) fail('project-mismatch', 409);
  if (command.expectedRevision !== current.revision) fail('revision-conflict', 409);
  const state = structuredClone(current);
  const body = command.input || {};
  switch (command.action) {
    case 'register': {
      owner(actor); const sessionId = id(body.id);
      if (!/^[a-f0-9]{64}$/.test(body.tokenHash)) fail('invalid-token-hash');
      if (state.sessions.some(s => s.id !== sessionId && s.tokenHash === body.tokenHash)) fail('token-already-used',409);
      const old = state.sessions.find(s => s.id === sessionId);
      const next = { id: sessionId, label: text(body.label), tokenHash: body.tokenHash, transport: 'pull', registeredAt: now };
      if (old) state.sessions[state.sessions.indexOf(old)] = next;
      else { capacity(state.sessions); state.sessions.push(next); }
      break;
    }
    case 'ask': {
      const target = session(state, body.sessionId); scoped(actor, target.id);
      const questionId = id(body.id);
      if (state.questions.some(q => q.id === questionId)) fail('question-exists', 409);
      if (!Array.isArray(body.options) || body.options.length < 2 || body.options.length > 8) fail('invalid-options');
      const options = body.options.map(o => {
        const option = { id: id(o.id), label: text(o.label) };
        if (o.preview) {
          if (!['primary', 'secondary'].includes(o.preview.variant) || o.preview.storyId !== 'hub-choice--variants' || o.preview.version !== '1') fail('unknown-component');
          option.preview = { storyId: o.preview.storyId, version: '1', variant: o.preview.variant };
        }
        return option;
      });
      if (new Set(options.map(o => o.id)).size !== options.length) fail('duplicate-option');
      capacity(state.questions);
      state.questions.push({ id: questionId, sessionId: target.id, title: text(body.title, 2000), options,
        status: 'open', createdAt: now, expiresAt: timestamp(body.expiresAt, now), answer: null });
      break;
    }
    case 'answer': {
      owner(actor);
      const q = state.questions.find(q => q.id === id(body.id));
      if (!q) fail('question-not-found', 404);
      id(body.requestId);
      if (q.answer?.requestId === body.requestId && q.answer.optionId === body.optionId) return current;
      if (q.status !== 'open' || q.expiresAt <= now) fail('question-closed', 409);
      if (!q.options.some(o => o.id === body.optionId)) fail('invalid-option');
      q.answer = { optionId: body.optionId, requestId: body.requestId, answeredAt: now };
      q.status = 'answered'; break;
    }
    case 'receive': {
      const q = state.questions.find(q => q.id === id(body.id));
      if (!q) fail('question-not-found', 404);
      if (actor.role !== 'session' || actor.sessionId !== q.sessionId) fail('session-required', 403);
      if (!q.answer || q.answer.requestId !== body.requestId) fail('answer-mismatch', 409);
      if (q.status === 'received') return current;
      q.status = 'received'; q.receivedAt = now; break;
    }
    case 'away': owner(actor); if (typeof body.enabled !== 'boolean') fail('invalid-mode'); state.away = body.enabled; break;
    case 'enqueue': {
      owner(actor); session(state, body.sessionId); id(body.id); id(body.commandId);
      if (body.approved !== true) fail('approval-required', 403);
      if (state.jobs.some(j => j.id === body.id)) fail('job-exists', 409);
      capacity(state.jobs);
      state.jobs.push({ id: body.id, sessionId: body.sessionId, commandId: body.commandId,
        title: text(body.title), status: 'queued', approvedAt: now, createdAt: now });
      break;
    }
    case 'claim': {
      if (actor.role !== 'session') fail('session-required', 403);
      const job = state.jobs.find(j => j.id === id(body.id));
      if (!job) fail('job-not-found', 404);
      scoped(actor, job.sessionId);
      // Never automatically retry an expired lease: external side effects may already exist.
      if (!state.away || state.jobs.some(j => j.status === 'running') || job.status !== 'queued') fail('not-runnable', 409);
      if (!Number.isSafeInteger(body.timeoutMs) || body.timeoutMs < 100 || body.timeoutMs > 3600000) fail('invalid-timeout');
      job.status = 'running'; job.startedAt = now; job.deadline = now + body.timeoutMs + 30000;
      job.claimId = id(body.claimId); break;
    }
    case 'finish': {
      const job = state.jobs.find(j => j.id === id(body.id));
      if (!job) fail('job-not-found', 404);
      if (actor.role !== 'session' || actor.sessionId !== job.sessionId) fail('session-required', 403);
      if (job.status !== 'running' || job.claimId !== body.claimId) fail('claim-mismatch', 409);
      if (!['succeeded', 'failed', 'uncertain', 'cancelled'].includes(body.status)) fail('invalid-status');
      if (body.status === 'cancelled' && !job.cancelRequested) fail('cancellation-not-requested',409);
      job.status = now > job.deadline ? 'uncertain' : body.status; job.finishedAt = now; break;
    }
    case 'cancel': {
      owner(actor); const job = state.jobs.find(j => j.id === id(body.id));
      if (!job || !['queued', 'running'].includes(job.status)) fail('not-cancellable', 409);
      // Running commands observe this on the next heartbeat; stay running until worker confirms exit.
      if (job.status === 'running') job.cancelRequested = true;
      else job.status = 'cancelled';
      break;
    }
    case 'resolve': {
      owner(actor); const job = state.jobs.find(j => j.id === id(body.id));
      if (!job || job.status !== 'running' || job.deadline > now) fail('not-uncertain', 409);
      if (body.workerStopped !== true) fail('stop-worker-first', 409);
      job.status = 'uncertain'; job.finishedAt = now; break;
    }
    case 'verification': {
      owner(actor);
      const v = body;
      if (v.schema !== 'sdd-merge-readiness/v1' || !/^[a-f0-9]{40}$/.test(v.head) || !['ready', 'blocked'].includes(v.status) ||
          !Array.isArray(v.reasons) || v.reasons.length > 100 || v.reasons.some(r => typeof r !== 'string' || r.length > 500) ||
          !/^[a-f0-9]{64}$/.test(v.evidenceSha256) || !Number.isSafeInteger(v.checkedAt) || v.checkedAt > now + 30000 || v.checkedAt < now - 86400000) fail('invalid-verification');
      state.verification = { schema: v.schema, head: v.head, status: v.status, reasons: v.reasons,
        evidenceSha256: v.evidenceSha256, checkedAt: v.checkedAt }; break;
    }
    default: fail('unknown-action');
  }
  state.revision++;
  if (JSON.stringify(state).length > 1024 * 1024) fail('capacity-reached', 409);
  return state;
}
