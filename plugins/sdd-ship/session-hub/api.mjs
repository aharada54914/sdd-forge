export function apiClient({ url, token, project, serviceToken }) {
  const base = new URL(url);
  if (base.username || base.password || base.search || base.hash || base.pathname !== '/' ||
      !(base.protocol === 'https:' || base.protocol === 'http:' && base.hostname === '127.0.0.1')) throw new Error('invalid-hub-origin');
  if (!/^[a-f0-9]{64}$/.test(token)) throw new Error('invalid-token');
  async function call(path, command) {
    const r = await fetch(new URL(path, base), {method:command ? 'POST' : 'GET', redirect:'error', signal:AbortSignal.timeout(15000),
      headers:{Authorization:'Bearer ' + token, ...(serviceToken ? {'OAI-Sites-Authorization':'Bearer ' + serviceToken} : {}), ...(command ? {'Content-Type':'application/json'} : {})},
      ...(command ? {body:JSON.stringify(command)} : {})});
    let body; try {body=await r.json();} catch {const e=new Error('http-'+r.status);e.status=r.status;throw e;} if (!r.ok) { const e = new Error(body.error || 'request-failed'); e.status = r.status; throw e; }
    if (body.schema !== 'sdd-session-hub/v1' || body.project !== project) throw new Error('project-mismatch');
    return body;
  }
  return { read:() => call('/api/hub'), command:(state,action,input) => call('/api/hub/command', {project,expectedRevision:state.revision,action,input}) };
}
