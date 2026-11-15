/** Explicit local allowlist, argv without a shell. No provider credentials or model invocation. */
import { spawn } from 'node:child_process';
import { freemem, loadavg, availableParallelism } from 'node:os';
import { resolve, isAbsolute } from 'node:path';
import { pathToFileURL } from 'node:url';
import { randomUUID } from 'node:crypto';
import { apiClient } from './api.mjs';
import { id } from './core.mjs';
const wait = ms => new Promise(yes => setTimeout(yes, ms));
export function validateRunner(config) {
  id(config.sessionId);
  if (!config.commands || typeof config.commands !== 'object' || Array.isArray(config.commands) || Object.keys(config.commands).length > 50) throw new Error('invalid-commands');
  if (!Number.isSafeInteger(config.minFreeMb) || config.minFreeMb < 0 || !Number.isFinite(config.maxLoad) || config.maxLoad <= 0) throw new Error('invalid-resource-budget');
  for (const [key, command] of Object.entries(config.commands)) {
    id(key);
    if (!command || !Array.isArray(command.argv) || !command.argv.length || command.argv.some(a => typeof a !== 'string' || a.length > 8192) ||
        !isAbsolute(command.argv[0]) || typeof command.cwd !== 'string' || !isAbsolute(command.cwd) || !Number.isSafeInteger(command.timeoutMs) || command.timeoutMs < 100 || command.timeoutMs > 3600000) throw new Error('invalid-command');
  }
}
function stop(child) {
  if (child.exitCode !== null || child.signalCode !== null) return;
  try { if (process.platform === 'win32') child.kill('SIGKILL'); else process.kill(-child.pid, 'SIGKILL'); } catch {}
}
export async function runOne(config, hooks = {}) {
  validateRunner(config);
  if (process.platform === 'win32') throw new Error('runner-requires-posix-process-groups');
  const api = apiClient(config); let state = await api.read();
  if (!state.away || state.jobs.some(j => ['running','uncertain'].includes(j.status))) return false;
  if (freemem() / 1048576 < config.minFreeMb || loadavg()[0] / availableParallelism() > config.maxLoad) return false;
  const job = state.jobs.find(j => j.status === 'queued' && j.sessionId === config.sessionId && Object.hasOwn(config.commands,j.commandId));
  if (!job) return false;
  const command = config.commands[job.commandId]; const claimId = randomUUID();
  await api.command(state, 'claim', {id:job.id, claimId, timeoutMs:command.timeoutMs});
  let child, timeout, heartbeat, cancelled = false, unavailable = false, timedOut = false, exited = false;
  const kill = () => { if (child) stop(child); };
  try {
    child = spawn(command.argv[0], command.argv.slice(1), {cwd:command.cwd, shell:false, detached:true,
      env:{PATH:process.env.PATH || '', LANG:process.env.LANG || 'C.UTF-8'}, stdio:'ignore'});
    process.once('SIGTERM', kill); process.once('SIGINT', kill);
    timeout = setTimeout(() => { timedOut = true; kill(); }, command.timeoutMs);
    let checking = false;
    heartbeat = setInterval(async () => {
      if (checking || exited) return; checking = true;
      try { const latest = await api.read(); const live = latest.jobs.find(j => j.id === job.id);
        if (!live || live.cancelRequested || live.status !== 'running') { cancelled = true; kill(); }
      } catch { unavailable = true; kill(); }
      finally { checking = false; }
    }, 1000);
    const result = await new Promise(yes => { child.once('error', () => yes(false)); child.once('exit', code => yes(code === 0)); });
    exited = true; clearInterval(heartbeat); clearTimeout(timeout);
    // Kill leftover descendants as well; success is only meaningful once the process group is stopped.
    try { process.kill(-child.pid, 'SIGKILL'); } catch {}
    for (let attempt = 0; attempt < 3; attempt++) {
      state = await api.read();
      try {
        await api.command(state, 'finish', {id:job.id, claimId, status:unavailable ? 'uncertain' : cancelled ? 'cancelled' : result && !timedOut ? 'succeeded' : 'failed'});
        break;
      } catch (error) { if (error.status !== 409 || attempt === 2) throw error; }
    }
    hooks.completed?.(job.id); return true;
  } finally {
    exited = true; clearTimeout(timeout); clearInterval(heartbeat); kill();
    process.removeListener('SIGTERM', kill); process.removeListener('SIGINT', kill);
  }
}
if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    let raw = ''; for await (const chunk of process.stdin) { raw += chunk; if (raw.length > 65536) throw new Error('config-too-large'); }
    const config = JSON.parse(raw); validateRunner(config);
    let stopping = false;
    for (const signal of ['SIGINT','SIGTERM']) process.on(signal, () => {stopping = true;});
    do { await runOne(config); if (!config.once && !stopping) await wait(5000); } while (!config.once && !stopping);
  } catch { process.stderr.write('Hub worker stopped; check connection, job state and local allowlist.\n'); process.exitCode = 1; }
}
