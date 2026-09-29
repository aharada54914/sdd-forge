import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

// A missing runtime, timeout, native refusal or unexpected output is unavailable.
export function prepareWindowsStore(store, remaining) {
  try {
    if (!Number.isFinite(remaining) || remaining < 1 || remaining > 1000) throw new Error();
    const result = execFileSync('pwsh', ['-NoLogo', '-NoProfile', '-NonInteractive', '-File',
      fileURLToPath(new URL('./windows-store.ps1', import.meta.url)), '-Store', store],
    { timeout: Math.floor(remaining), encoding: 'utf8', maxBuffer: 1024, windowsHide: true,
      stdio: ['ignore', 'pipe', 'pipe'] });
    if (result !== 'created') throw new Error();
  } catch {
    const error = new Error('validation-rejected'); delete error.stack;
    error.code = 'validation-rejected'; throw error;
  }
}
