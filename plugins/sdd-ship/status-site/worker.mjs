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
    if (f.displayName !== undefined && (typeof f.displayName !== 'string' || !f.displayName.trim() || f.displayName.length>200)) return false;
    features.add(f.id);
  }
  for (const t of s.data.tasks) {
    if (!t || ['key','id','feature','title','body','status','approval','risk','source'].some(k => typeof t[k] !== 'string') || !(t.release === null || typeof t.release === 'string') || !Array.isArray(t.failures) || t.failures.some(f => typeof f !== 'string') || !features.has(t.feature) || keys.has(t.key)) return false;
    keys.add(t.key);
  }
  return true;
}

__OBSERVATION_CODE__
const HEALTH_STATES = ['starting','running','collection-failed','source-failed','auth-failed','data-rejected','conflict','http-failed','transport-failed'];
export function validHealth(h) {
  if (!h || Object.keys(h).some(k => !['schema','observedAt','state','publisherVersion','collectorVersion','lastPublishAt','lastSourceAt','consecutiveFailures','collectorRestarts','collectionMs','lastError'].includes(k)) || h.schema !== 'sdd-monitor/v1' || !validTime(h.observedAt) || Date.parse(h.observedAt) > Date.now()+30000 || !HEALTH_STATES.includes(h.state)) return false;
  if (!['publisherVersion','collectorVersion'].every(k => typeof h[k] === 'string' && /^[a-f0-9]{12}$/.test(h[k]))) return false;
  if (!['lastPublishAt','lastSourceAt'].every(k => h[k] === null || validTime(h[k]) && Date.parse(h[k]) <= Date.parse(h.observedAt))) return false;
  if (!['consecutiveFailures','collectorRestarts','collectionMs'].every(k => Number.isSafeInteger(h[k]) && h[k] >= 0 && h[k] <= 1e9)) return false;
  return h.lastError === null || HEALTH_STATES.includes(h.lastError);
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
    if (url.pathname === '/api/health') {
      if (request.method === 'GET') {
        const health = await env.BUCKET.get('health.json');
        return health ? new Response(await health.text(), {headers:{...headers,'Content-Type':'application/json'}}) : json({error:'health-unavailable'},503);
      }
      if (request.method !== 'PUT' || !isPublisher || origin) return json({error:'publisher-required'},403);
      let h; try { h = JSON.parse(await boundedBody(request)); } catch { return json({error:'invalid-health'},400); }
      if (!validHealth(h)) return json({error:'invalid-health'},400);
      const old = await env.BUCKET.get('health.json');
      if (old && Date.parse((await old.json()).observedAt) >= Date.parse(h.observedAt)) return json({error:'older-health'},409);
      const result = await env.BUCKET.put('health.json',JSON.stringify(h),{onlyIf:old?{etagMatches:old.etag}:{etagDoesNotMatch:'*'},httpMetadata:{contentType:'application/json'}});
      return result ? json({ok:true}) : json({error:'concurrent-update'},409);
    }
    if (request.method === 'GET' && url.pathname === '/api/observations') {
      const current = await env.BUCKET.get('snapshot.json');
      return json(observationView(current ? await current.json() : null));
    }
    if (request.method === 'GET' && url.pathname === '/api/dashboard') {
      const current = await env.BUCKET.get('snapshot.json');
      if (!current) return json({ schema: 'sdd-dashboard/v1', revision: '', attemptedAt: new Date().toISOString(), checkedAt: null, changedAt: null, lastSuccessAt: null, data: null, error: '収集プロセスからのデータを待っています' });
      return json(publicSnapshot(await current.json()));
    }
    if (request.method !== 'PUT' || url.pathname !== '/api/snapshot') return json({ error: 'not-found' }, 404);
    if (!isPublisher || origin) return json({ error: 'publisher-required' }, 403);
    let next;
    try { next = JSON.parse(await boundedBody(request)); } catch (e) { return json({ error: e.message === 'too-large' ? 'too-large' : 'invalid-json' }, e.message === 'too-large' ? 413 : 400); }
    if (!validSnapshot(next)) return json({ error: 'invalid-snapshot' }, 400);
    if (Object.hasOwn(next,'_observations')) return json({error:'reserved-field'},400);
    const current = await env.BUCKET.get('snapshot.json');
    const old = current ? await current.json() : null;
    if (old && Date.parse(old.attemptedAt) >= Date.parse(next.attemptedAt)) return json({ error: 'older-snapshot' }, 409);
    if (old?.data && next.data && old.data.project !== next.data.project) return json({ error: 'project-mismatch' }, 409);
    if (old?.data && next.error && !next.data) next = { ...publicSnapshot(old), attemptedAt: next.attemptedAt, error: next.error };
    // Retain content age across collector restarts; successful reads still advance checkedAt.
    if (old?.revision && old.revision === next.revision) next.changedAt = old.changedAt;
    const stored = {...next,_observations:observe(old,next)};
    const written = await env.BUCKET.put('snapshot.json', JSON.stringify(stored), { onlyIf: current ? { etagMatches: current.etag } : { etagDoesNotMatch: '*' }, httpMetadata: { contentType: 'application/json' } });
    if (!written) return json({ error: 'concurrent-update' }, 409);
    return json({ ok: true, revision: next.revision, checkedAt: next.checkedAt });
  }
};
