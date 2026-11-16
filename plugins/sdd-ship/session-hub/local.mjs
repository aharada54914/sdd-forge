/** Private loopback host. One writer owns each directory; fail rather than steal a stale lock. */
import { createServer } from 'node:http';
import { mkdir, open, readFile, rename, unlink, chmod } from 'node:fs/promises';
import { resolve } from 'node:path';
import { randomBytes, timingSafeEqual } from 'node:crypto';
import { pathToFileURL } from 'node:url';
import { hubRequest, readBody } from './http.mjs';
import { hubAssets } from './assets.mjs';
import { assetResponse } from './asset-response.mjs';
import { initial } from './core.mjs';
export async function startLocal({ directory, project, ownerToken, port = 0 }) {
  if (!/^[a-f0-9]{64}$/.test(ownerToken)) throw new Error('owner-token-must-be-32-random-bytes-in-hex');
  initial(project);
  const dir = resolve(directory); await mkdir(dir, {recursive:true, mode:0o700}); await chmod(dir, 0o700);
  const lockPath = resolve(dir, 'hub.lock'); const lock = await open(lockPath, 'wx', 0o600);
  const file = resolve(dir, 'hub.json'); const assets = hubAssets();
  const cookie = randomBytes(32).toString('hex');
  let state;
  try { state = JSON.parse(await readFile(file, 'utf8')); }
  catch (e) { if (e.code !== 'ENOENT') { await lock.close(); await unlink(lockPath); throw e; } state = initial(project); }
  const equal = value => typeof value === 'string' && value.length === ownerToken.length && timingSafeEqual(Buffer.from(value), Buffer.from(ownerToken));
  const store = {
    async load() { return {state:structuredClone(state), etag:state.revision}; },
    async save(next, etag) {
      if (state.revision !== etag) return false;
      const temporary = resolve(dir, 'hub.json.tmp');
      const handle = await open(temporary, 'w', 0o600);
      try { await handle.writeFile(JSON.stringify(next)); await handle.sync(); } finally { await handle.close(); }
      await rename(temporary, file); state = next; return true;
    }
  };
  let chain = Promise.resolve();
  const server = createServer((req, res) => {
    chain = chain.then(async () => {
      const expectedHost = '127.0.0.1:' + server.address().port;
      if (req.headers.host !== expectedHost) { res.writeHead(403); res.end(); return; }
      let response;
      try {
        const abort = new AbortController(); const timer = setTimeout(() => abort.abort(), 10000);
        const request = new Request('http://' + expectedHost + req.url, {method:req.method, headers:req.headers,
          ...(['GET','HEAD'].includes(req.method) ? {} : {body:req, duplex:'half'}), signal:abort.signal});
        const url = new URL(request.url); const origin = request.headers.get('origin');
        const owner = equal(request.headers.get('authorization')?.replace(/^Bearer /,'')) || request.headers.get('cookie')?.split(';').some(c => c.trim() === 'sdd_hub=' + cookie);
        try {
          if (url.pathname === '/api/hub/login' && req.method === 'POST') {
            if (origin !== url.origin) response = Response.json({error:'origin-denied'}, {status:403});
            else {
              const body = await readBody(request);
              response = equal(body.token) ? Response.json({ok:true}, {headers:{'Set-Cookie':'sdd_hub=' + cookie + '; HttpOnly; SameSite=Strict; Path=/api/hub', 'Cache-Control':'no-store'}}) : Response.json({error:'authentication-required'}, {status:401});
            }
          } else response = assetResponse(url.pathname === '/' ? '/hub' : url.pathname, assets) || await hubRequest(request, {project,store,isOwner:owner});
        } finally { clearTimeout(timer); }
      } catch { response = Response.json({error:'hub-unavailable'}, {status:503}); }
      res.writeHead(response.status, Object.fromEntries(response.headers)); res.end(Buffer.from(await response.arrayBuffer()));
    }).catch(() => { if (!res.headersSent) res.writeHead(503); res.end(); });
  });
  server.requestTimeout = 10000; server.headersTimeout = 10000;
  try { await new Promise((yes, no) => { server.once('error', no); server.listen(port, '127.0.0.1', yes); }); }
  catch (e) { await lock.close(); await unlink(lockPath); throw e; }
  return { url:'http://127.0.0.1:' + server.address().port,
    async close() { await new Promise(yes => server.close(yes)); await chain; await lock.close(); await unlink(lockPath); } };
}
if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    let raw = ''; for await (const chunk of process.stdin) { raw += chunk; if (raw.length > 8192) throw new Error('config-too-large'); }
    const host = await startLocal(JSON.parse(raw));
    process.stdout.write(JSON.stringify({url:host.url}) + '\n');
    for (const signal of ['SIGINT','SIGTERM']) process.once(signal, async () => { await host.close(); process.exit(0); });
  } catch { process.stderr.write('Hub startup failed; check configuration and directory lock.\n'); process.exitCode = 1; }
}
