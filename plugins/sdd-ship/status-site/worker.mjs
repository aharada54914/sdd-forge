// Served only behind the private Sites access policy. No workflow write endpoint.
const page = __DASHBOARD_PAGE__;
const MAX_BYTES = 2 * 1024 * 1024;
const headers = { 'Cache-Control': 'private, no-store', 'X-Content-Type-Options': 'nosniff', 'Referrer-Policy': 'no-referrer' };
const json = (value, status = 200) => Response.json(value, { status, headers });
function validTime(value) { return typeof value === 'string' && Number.isFinite(Date.parse(value)); }
export function validSnapshot(s) {
  if (!s || s.schema !== 'sdd-dashboard/v1' || !validTime(s.attemptedAt) || Date.parse(s.attemptedAt) > Date.now() + 30000) return false;
  if (typeof s.revision !== 'string' || !(s.error === null || typeof s.error === 'string')) return false;
  for (const field of ['checkedAt','lastSuccessAt','changedAt']) if (s[field] !== null && (!validTime(s[field]) || Date.parse(s[field]) > Date.parse(s.attemptedAt))) return false;
  if (s.data === null) return s.error !== null && s.checkedAt === null && s.lastSuccessAt === null;
  if (!s.data || typeof s.data.project !== 'string' || !Array.isArray(s.data.features) || !Array.isArray(s.data.tasks)) return false;
  if (!s.checkedAt || !s.lastSuccessAt || !s.changedAt || !/^[a-f0-9]{64}$/.test(s.revision)) return false;
  if (s.data.features.length > 1000 || s.data.tasks.length > 10000) return false;
  const features = new Set(); const keys = new Set();
  for (const f of s.data.features) {
    if (!f || ['id','phase','nextCommand'].some(k => typeof f[k] !== 'string') || !Array.isArray(f.warnings) || f.warnings.some(w => typeof w !== 'string') || features.has(f.id)) return false;
    features.add(f.id);
  }
  for (const t of s.data.tasks) {
    if (!t || ['key','id','feature','title','body','status','approval','risk','source'].some(k => typeof t[k] !== 'string') || !(t.release === null || typeof t.release === 'string') || !Array.isArray(t.failures) || t.failures.some(f => typeof f !== 'string') || !features.has(t.feature) || keys.has(t.key)) return false;
    keys.add(t.key);
  }
  return true;
}
async function publisher(request, env) {
  const given = request.headers.get('X-SDD-Publisher') || '';
  if (!env.SDD_PUBLISHER_TOKEN || !given) return false;
  const encode = value => new TextEncoder().encode(value);
  const a = new Uint8Array(await crypto.subtle.digest('SHA-256', encode(given)));
  const b = new Uint8Array(await crypto.subtle.digest('SHA-256', encode(env.SDD_PUBLISHER_TOKEN)));
  let diff = 0; for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
  return diff === 0;
}
async function boundedBody(request) {
  if (Number(request.headers.get('content-length')) > MAX_BYTES) throw new Error('too-large');
  const reader = request.body?.getReader(); if (!reader) throw new Error('empty');
  const chunks = []; let size = 0;
  while (true) {
    const { done, value } = await reader.read(); if (done) break;
    size += value.length; if (size > MAX_BYTES) { await reader.cancel(); throw new Error('too-large'); }
    chunks.push(value);
  }
  const bytes = new Uint8Array(size); let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
  return new TextDecoder('utf-8', { fatal: true }).decode(bytes);
}
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const isPublisher = await publisher(request, env);
    const viewer = request.headers.get('oai-authenticated-user-id');
    if (!viewer && !isPublisher) return json({ error: 'authentication-required' }, 401);
    const origin = request.headers.get('origin');
    if (origin && origin !== url.origin) return json({ error: 'origin-denied' }, 403);
    if (request.method === 'GET' && url.pathname === '/') return new Response(page, { headers: { ...headers, 'Content-Type': 'text/html; charset=utf-8', 'Content-Security-Policy': "default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; connect-src 'self'; base-uri 'none'; frame-ancestors 'self'" } });
    if (!env.BUCKET) return json({ error: 'storage-unavailable' }, 503);
    if (request.method === 'GET' && url.pathname === '/api/dashboard') {
      const current = await env.BUCKET.get('snapshot.json');
      if (!current) return json({ schema: 'sdd-dashboard/v1', revision: '', attemptedAt: new Date().toISOString(), checkedAt: null, changedAt: null, lastSuccessAt: null, data: null, error: '収集プロセスからのデータを待っています' });
      return new Response(await current.text(), { headers: { ...headers, 'Content-Type': 'application/json' } });
    }
    if (request.method !== 'PUT' || url.pathname !== '/api/snapshot') return json({ error: 'not-found' }, 404);
    if (!isPublisher || origin) return json({ error: 'publisher-required' }, 403);
    let next;
    try { next = JSON.parse(await boundedBody(request)); } catch (e) { return json({ error: e.message === 'too-large' ? 'too-large' : 'invalid-json' }, e.message === 'too-large' ? 413 : 400); }
    if (!validSnapshot(next)) return json({ error: 'invalid-snapshot' }, 400);
    const current = await env.BUCKET.get('snapshot.json');
    const old = current ? await current.json() : null;
    if (old && Date.parse(old.attemptedAt) >= Date.parse(next.attemptedAt)) return json({ error: 'older-snapshot' }, 409);
    if (old?.data && next.data && old.data.project !== next.data.project) return json({ error: 'project-mismatch' }, 409);
    if (old?.data && next.error && !next.data) next = { ...old, attemptedAt: next.attemptedAt, error: next.error };
    // Retain content age across collector restarts; successful reads still advance checkedAt.
    if (old?.revision && old.revision === next.revision) next.changedAt = old.changedAt;
    const written = await env.BUCKET.put('snapshot.json', JSON.stringify(next), { onlyIf: current ? { etagMatches: current.etag } : { etagDoesNotMatch: '*' }, httpMetadata: { contentType: 'application/json' } });
    if (!written) return json({ error: 'concurrent-update' }, 409);
    return json({ ok: true, revision: next.revision, checkedAt: next.checkedAt });
  }
};
