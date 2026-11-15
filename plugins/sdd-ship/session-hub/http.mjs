import { HubError, initial, publicState, transition, validateState } from './core.mjs';
export const hubHeaders = { 'Cache-Control': 'private, no-store', 'X-Content-Type-Options': 'nosniff', 'Referrer-Policy': 'no-referrer' };
const json = (body, status = 200) => Response.json(body, { status, headers: hubHeaders });
export async function digest(value) {
  return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value))), b => b.toString(16).padStart(2, '0')).join('');
}
export async function readBody(request) {
  if (Number(request.headers.get('content-length')) > 32768) throw new HubError('too-large', 413);
  const reader = request.body?.getReader(); if (!reader) throw new HubError('empty-body');
  let size = 0; const chunks = [];
  while (true) {
    const { value, done } = await reader.read(); if (done) break;
    size += value.length; if (size > 32768) { await reader.cancel(); throw new HubError('too-large', 413); }
    chunks.push(value);
  }
  const bytes = new Uint8Array(size); let offset = 0;
  for (const c of chunks) { bytes.set(c, offset); offset += c.length; }
  try { return JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(bytes)); }
  catch { throw new HubError('invalid-json'); }
}
/** Store must provide load() -> {state, etag} and CAS save(next, etag). */
export async function hubRequest(request, { project, store, isOwner }) {
  try {
    if (!project) return json({ error: 'hub-not-configured' }, 503);
    const url = new URL(request.url);
    const origin = request.headers.get('origin');
    if (origin && origin !== url.origin) return json({ error: 'origin-denied' }, 403);
    const record = await store.load();
    const state = validateState(record.state || initial(project), project);
    let actor = isOwner ? { role: 'owner' } : null;
    if (!actor) {
      const token = request.headers.get('authorization')?.match(/^Bearer ([a-f0-9]{64})$/)?.[1];
      if (token) {
        const hash = await digest(token);
        const session = state.sessions.find(s => s.tokenHash === hash);
        if (session) actor = { role: 'session', sessionId: session.id };
      }
    }
    if (!actor) return json({ error: 'authentication-required' }, 401);
    if (url.pathname === '/api/hub' && request.method === 'GET') return json(publicState(state, actor));
    if (url.pathname !== '/api/hub/command' || request.method !== 'POST') return json({ error: 'not-found' }, 404);
    if (isOwner && (!origin || origin !== url.origin) && !request.headers.has('authorization')) return json({ error: 'origin-required' }, 403);
    const next = transition(state, await readBody(request), actor);
    if (next !== state && !await store.save(next, record.etag)) return json({ error: 'revision-conflict' }, 409);
    return json(publicState(next, actor));
  } catch (error) {
    return json({ error: error instanceof HubError ? error.message : 'hub-unavailable' }, error instanceof HubError ? error.status : 503);
  }
}
