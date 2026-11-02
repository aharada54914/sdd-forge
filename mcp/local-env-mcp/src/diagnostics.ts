/**
 * Redaction-safe stderr diagnostics logger (REQ-005 / AC-005).
 *
 * local-env-mcp emits diagnostics on stderr for exactly two events — a single
 * startup line and fatal startup errors — and NOTHING else. stdout is reserved
 * for the MCP JSON-RPC transport, so every diagnostic goes to stderr as ONE
 * single-line JSON object.
 *
 * Two guarantees make the output non-leaking:
 *
 *  1. Fixed field allowlist. `logStartup` emits only {event, name, version,
 *     transport}; `logFatal` emits only {event, code, message}. No other field
 *     is ever serialized, and the module never serializes `process.env`,
 *     `os.userInfo()`, `os.homedir()`, or `os.hostname()` — those are only read
 *     (never written to output) to build the scrubber's redaction set.
 *  2. Conservative message scrubber. The only free-form field, `logFatal`'s
 *     `message`, is passed through `scrubMessage`, which replaces verbatim
 *     occurrences of the home directory, username, hostname, and any
 *     environment-variable value longer than 3 characters with a fixed
 *     `[redacted]` token.
 *
 * Scrubber limits (documented, conservative by design): it only catches VERBATIM
 * substrings of the known-secret set present at scrub time. It does not attempt
 * to detect transformed, encoded, partial, or newly-set secrets, and it never
 * inspects arbitrary error properties (stack, cause) — those are dropped
 * entirely rather than scrubbed. The field allowlist, not the scrubber, is the
 * primary control; the scrubber is defense-in-depth for the single free-form
 * field.
 */

import { defaultSink, type StartupInfo, type WriteSink } from "./diagnostics-core.js";
export type { StartupInfo, WriteSink } from "./diagnostics-core.js";

export { scrubKnownSecrets as scrubMessage } from "./diagnostics-core.js";
import { scrubKnownSecrets as scrubMessage } from "./diagnostics-core.js";

/**
 * Writes the single startup diagnostic line to stderr (or the provided sink).
 * Only the fixed {event, name, version, transport} allowlist is serialized.
 */
export function logStartup(info: StartupInfo, sink: WriteSink = defaultSink): void {
  const line = {
    event: "startup" as const,
    name: info.name,
    version: info.version,
    transport: info.transport,
  };
  sink(`${JSON.stringify(line)}\n`);
}

/**
 * Writes a single fatal-error diagnostic line to stderr (or the provided sink).
 * Only {event, code, message} is serialized; `message` is scrubbed and no other
 * error property (stack, cause, custom fields) is ever emitted.
 */
export function logFatal(error: unknown, sink: WriteSink = defaultSink): void {
  const rawMessage = error instanceof Error ? error.message : String(error);
  const line = {
    event: "fatal" as const,
    code: "cannot-determine",
    message: scrubMessage(rawMessage),
  };
  sink(`${JSON.stringify(line)}\n`);
}
