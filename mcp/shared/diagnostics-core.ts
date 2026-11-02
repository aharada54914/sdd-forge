/** Shared stderr/known-secret mechanism. Package wrappers own event and provider policy. */
import os from "node:os";

/** A minimal write sink (process.stderr satisfies this). */
export type WriteSink = (chunk: string) => void;

/** Allowlisted fields for the startup diagnostic. */
export interface StartupInfo {
  name: string;
  version: string;
  transport: string;
}

const REDACTED = "[redacted]";
const MIN_SECRET_LEN = 4; // values of length > 3 are scrubbed

/** Default sink: write to the process's stderr. */
export function defaultSink(chunk: string): void {
  process.stderr.write(chunk);
}

/**
 * Builds the set of verbatim secret strings to redact: the home directory,
 * username, hostname, and every environment-variable VALUE longer than 3
 * characters. Longer strings are ordered first so that a value containing a
 * shorter one is redacted before its substring is considered.
 */
function collectSecrets(): string[] {
  const secrets = new Set<string>();

  const home = os.homedir();
  if (home.length >= MIN_SECRET_LEN) {
    secrets.add(home);
  }

  const username = os.userInfo().username;
  if (username.length >= MIN_SECRET_LEN) {
    secrets.add(username);
  }

  const hostname = os.hostname();
  if (hostname.length >= MIN_SECRET_LEN) {
    secrets.add(hostname);
  }

  for (const value of Object.values(process.env)) {
    if (typeof value === "string" && value.length >= MIN_SECRET_LEN) {
      secrets.add(value);
    }
  }

  // Redact longer secrets first (a value may contain a shorter one verbatim).
  return [...secrets].sort((a, b) => b.length - a.length);
}

/** Escapes a string for literal use inside a RegExp. */
function escapeRegExp(literal: string): string {
  return literal.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/**
 * Replaces verbatim occurrences of every known secret in `message` with the
 * fixed `[redacted]` token. Conservative: only exact substrings present in the
 * current secret set are removed (see module note on limits).
 */
export function scrubKnownSecrets(message: string): string {
  let scrubbed = message;
  for (const secret of collectSecrets()) {
    if (scrubbed.includes(secret)) {
      scrubbed = scrubbed.replace(new RegExp(escapeRegExp(secret), "g"), REDACTED);
    }
  }
  return scrubbed;
}
