/** JSON stdin: credentials plus action/input. stdout never contains bearer tokens. */
import { apiClient } from './api.mjs';
import { digest } from './http.mjs';
try {
  let raw = ''; for await (const chunk of process.stdin) {raw += chunk; if (raw.length > 65536) throw new Error('too-large');}
  const config = JSON.parse(raw); const api = apiClient(config); const state = await api.read();
  if (!config.action) process.stdout.write(JSON.stringify(state) + '\n');
  else {
    if (config.action === 'register') {
      // Caller supplies a separately delivered random session token; it is not persisted in plaintext.
      if (!/^[a-f0-9]{64}$/.test(config.sessionToken)) throw new Error('invalid-session-token');
      config.input = {...config.input, tokenHash:await digest(config.sessionToken)};
    }
    const next = await api.command(state, config.action, config.input);
    process.stdout.write(JSON.stringify(next) + '\n');
  }
} catch (error) { process.stderr.write('Hub request failed: ' + (['revision-conflict','project-mismatch','invalid-session-token'].includes(error.message) ? error.message : 'check-connection-or-input') + '\n'); process.exitCode = 1; }
