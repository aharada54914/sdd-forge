import { hubRequest, digest, hubHeaders } from './http.mjs';
import { mcpRequest } from './mcp.mjs';
import { assetResponse } from './asset-response.mjs';
/** Mount beside an existing Site without replacing its status/collector routes. */
export async function handleHostedHub(request, env, assets) {
  const url = new URL(request.url);
  if (!(url.pathname === '/mcp' || url.pathname === '/hub' || url.pathname.startsWith('/hub/') || url.pathname === '/api/hub' || url.pathname.startsWith('/api/hub/'))) return null;
  const json = (error,status) => Response.json({error},{status,headers:hubHeaders});
  const viewer = request.headers.get('oai-authenticated-user-id');
  const bearer = request.headers.get('authorization')?.match(/^Bearer ([a-f0-9]{64})$/)?.[1];
  const email = request.headers.get('oai-authenticated-user-email');
  const emailOwner = Boolean(viewer && email && env.SDD_HUB_OWNER_EMAIL && email.toLowerCase() === env.SDD_HUB_OWNER_EMAIL.toLowerCase());
  const isOwner = emailOwner || Boolean(viewer && env.SDD_HUB_OWNER_ID && viewer === env.SDD_HUB_OWNER_ID) ||
    Boolean(bearer && env.SDD_HUB_OWNER_TOKEN && await digest(bearer) === await digest(env.SDD_HUB_OWNER_TOKEN));
  if (!env.SDD_HUB_PROJECT || !env.BUCKET) return json('hub-not-configured',503);
  if (url.pathname === '/hub' || url.pathname.startsWith('/hub/')) {
    if (!isOwner) return json('owner-required',403);
    return assetResponse(url.pathname,assets) || json('not-found',404);
  }
  const store = {
    async load() { const value = await env.BUCKET.get('hub.json'); return {state:value ? await value.json() : null,etag:value?.etag}; },
    async save(state,etag) { return Boolean(await env.BUCKET.put('hub.json',JSON.stringify(state),{
      onlyIf:etag ? {etagMatches:etag} : {etagDoesNotMatch:'*'},httpMetadata:{contentType:'application/json'}})); }
  };
  const options = {project:env.SDD_HUB_PROJECT,store,isOwner};
  return url.pathname === '/mcp' ? mcpRequest(request,options) : hubRequest(request,options);
}
