// Task-local diagnostic recorder. No host launch, shell execution, or config reads.
import fs from 'node:fs';

const toolTypes = new Set([
  'commandExecution', 'mcpToolCall', 'dynamicToolCall', 'function_call',
  'function_call_output', 'custom_tool_call', 'custom_tool_call_output',
  'exec_command_begin', 'exec_command_end', 'exec_command_output_delta',
  'mcp_tool_call_begin', 'mcp_tool_call_end', 'tool_call', 'tool_result',
]);
const methods = new Set([
  'error', 'turn/completed', 'turn/started',
  'item/commandExecution/outputDelta', 'item/commandExecution/requestApproval',
  'item/tool/requestUserInput', 'item/tool/call',
  'codex/event/exec_command_begin', 'codex/event/exec_command_end',
  'codex/event/exec_command_output_delta', 'codex/event/mcp_tool_call_begin',
  'codex/event/mcp_tool_call_end', 'codex/event/error',
]);
const secretKeys = /^(?:env|environment|config|configuration|authorization|headers|api[_-]?key|access[_-]?token|refresh[_-]?token|token|password|secret|cookie|credentials)$/i;

function sanitize(value, state) {
  if (Array.isArray(value)) return value.map(v => sanitize(v, state));
  if (value !== null && typeof value === 'object') {
    const out = {};
    for (const [key, field] of Object.entries(value)) {
      if (secretKeys.test(key)) { out[key] = '[REDACTED]'; state.redacted = true; }
      else out[key] = sanitize(field, state);
    }
    return out;
  }
  if (typeof value !== 'string') return value;
  const safe = value
    .replace(/(Bearer\s+)[A-Za-z0-9._~+\/-]+/gi, '$1[REDACTED]')
    .replace(/\bsk-[A-Za-z0-9_-]{12,}\b/g, '[REDACTED]')
    .replace(/((?:api[_-]?key|access[_-]?token|refresh[_-]?token|password|secret)\s*[=:]\s*)[^\s,;]+/gi, '$1[REDACTED]');
  if (safe !== value) state.redacted = true;
  return safe;
}

function selected(event) {
  if (methods.has(event.method)) return true;
  if (['item/started', 'item/completed'].includes(event.method)) {
    return toolTypes.has(event.params?.item?.type);
  }
  // Older protocol can wrap calls inside a generic event/response-item envelope.
  if (event.method === 'codex/event' || event.method === 'codex/event/raw_response_item') {
    const msg = event.params?.msg;
    return toolTypes.has(msg?.type) || toolTypes.has(msg?.item?.type);
  }
  return false;
}

export class AuditLog {
  constructor(file) {
    // Existing evidence and symlinks are never overwritten.
    this.fd = fs.openSync(file, 'wx', 0o600);
    this.pending = new Map();
    this.requestIds = new Set();
    this.sequence = 0;
    this.closed = false;
  }

  capture(direction, line) {
    if (this.closed) throw new Error('audit is closed');
    if (!['server', 'client'].includes(direction)) throw new Error('invalid direction');
    let event;
    try { event = JSON.parse(line); } catch { throw new Error('invalid JSON: audit stopped; raw bytes not retained'); }
    if (!event || typeof event !== 'object' || Array.isArray(event)) throw new Error('invalid event envelope');
    const matchingReply = direction === 'client' && !event.method && this.requestIds.has(event.id);
    if (!selected(event) && !matchingReply) return false;
    if (matchingReply) this.requestIds.delete(event.id);
    if (direction === 'server' && event.method && event.id !== undefined) this.requestIds.add(event.id);
    // Do not retain nested turn history, which can contain reasoning/configuration.
    if (['turn/completed', 'turn/started'].includes(event.method)) {
      const t = event.params?.turn;
      event = { method: event.method, params: { threadId: event.params?.threadId,
        turn: { id: t?.id, status: t?.status, error: t?.error } } };
    }
    return this.persist(direction, event);
  }

  captureResponse(method, response) {
    if (!['initialize', 'thread/start'].includes(method)) throw new Error('RPC response not admitted');
    const r = response.result;
    const t = r?.thread;
    const event = { id: response.id, method, ...(response.error ? { error: { code: response.error.code, message: response.error.message } } : {
      result: method === 'initialize' ? { userAgent: r?.userAgent } : {
        model: r?.model, modelProvider: r?.modelProvider, reasoningEffort: r?.reasoningEffort,
        approvalPolicy: r?.approvalPolicy, sandbox: { type: r?.sandbox?.type },
        instructionSources: r?.instructionSources,
        thread: { id: t?.id, sessionId: t?.sessionId, parentThreadId: t?.parentThreadId,
          forkedFromId: t?.forkedFromId, status: t?.status?.type, turnCount: Array.isArray(t?.turns) ? t.turns.length : undefined },
      },
    }) };
    return this.persist('server', event);
  }

  persist(direction, event) {
    if (this.closed) throw new Error('audit is closed');
    const state = { redacted: false };
    const safe = sanitize(event, state);
    const row = { sequence: ++this.sequence, observedAt: new Date().toISOString(), direction,
      redacted: state.redacted, event: safe };
    fs.writeSync(this.fd, JSON.stringify(row) + '\n');
    fs.fsyncSync(this.fd); // Persist BEFORE any model/UI summary can discard an event.
    return row; // Only sanitized, durably persisted content reaches summaries.
  }

  feed(direction, chunk) {
    const text = (this.pending.get(direction) ?? '') + chunk;
    if (Buffer.byteLength(text) > 16 * 1024 * 1024) throw new Error('audit frame bound exceeded; stop transport, do not truncate');
    const lines = text.split('\n');
    this.pending.set(direction, lines.pop());
    for (const line of lines) if (line.trim()) this.capture(direction, line);
  }

  close() {
    if (this.closed) return;
    const unfinished = [...this.pending.values()].some(s => s.trim());
    fs.closeSync(this.fd);
    this.closed = true;
    if (unfinished) throw new Error('incomplete audit frame; transport evidence incomplete');
  }
}
