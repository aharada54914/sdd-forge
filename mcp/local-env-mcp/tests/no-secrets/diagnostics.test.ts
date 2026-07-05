/**
 * AC-005 (TEST-005) — diagnostics unit level.
 *
 * Proves the redaction-safe stderr logger (`src/diagnostics.ts`) emits ONLY the
 * fixed field allowlist and single-line JSON, and that its fatal-message
 * scrubber replaces verbatim occurrences of the home directory, username,
 * hostname, and long environment-variable values. The logger must NEVER
 * serialize process.env, os.userInfo(), os.homedir(), or os.hostname() into its
 * output — only caller-supplied allowlisted primitives (plus a scrubbed
 * message) are emitted.
 *
 * The logger writes to a caller-provided sink (defaulting to process.stderr) so
 * the emitted line can be captured deterministically without spawning.
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import os from "node:os";

import { logStartup, logFatal, scrubMessage } from "../../src/diagnostics.js";

/** Captures every string written through it, for assertions. */
function makeSink(): { write: (s: string) => void; lines: () => string[]; raw: () => string } {
  let buffer = "";
  return {
    write: (s: string): void => {
      buffer += s;
    },
    lines: (): string[] => buffer.split("\n").filter((l) => l.length > 0),
    raw: (): string => buffer,
  };
}

test("AC-005: logStartup emits exactly the allowlisted startup fields", () => {
  const sink = makeSink();
  logStartup({ name: "local-env-mcp", version: "0.1.0", transport: "stdio" }, sink.write);
  const lines = sink.lines();
  assert.equal(lines.length, 1, "startup diagnostic must be a single line");
  const obj = JSON.parse(lines[0]!) as Record<string, unknown>;
  assert.deepEqual(
    Object.keys(obj).sort(),
    ["event", "name", "transport", "version"],
    "only the fixed startup field allowlist may appear",
  );
  assert.equal(obj.event, "startup");
  assert.equal(obj.name, "local-env-mcp");
  assert.equal(obj.version, "0.1.0");
  assert.equal(obj.transport, "stdio");
});

test("AC-005: logStartup output is a single JSON line terminated by exactly one newline", () => {
  const sink = makeSink();
  logStartup({ name: "local-env-mcp", version: "0.1.0", transport: "stdio" }, sink.write);
  const raw = sink.raw();
  assert.ok(raw.endsWith("\n"), "line must be newline-terminated");
  assert.equal(raw.indexOf("\n"), raw.length - 1, "there must be exactly one newline (single line)");
});

test("AC-005: logFatal emits exactly the allowlisted fatal fields", () => {
  const sink = makeSink();
  logFatal(new Error("boom happened"), sink.write);
  const lines = sink.lines();
  assert.equal(lines.length, 1, "fatal diagnostic must be a single line");
  const obj = JSON.parse(lines[0]!) as Record<string, unknown>;
  assert.deepEqual(
    Object.keys(obj).sort(),
    ["code", "event", "message"],
    "only the fixed fatal field allowlist may appear",
  );
  assert.equal(obj.event, "fatal");
  assert.equal(typeof obj.code, "string");
  assert.equal(obj.message, "boom happened");
});

test("AC-005: logFatal accepts a non-Error value without leaking its structure", () => {
  const sink = makeSink();
  logFatal("plain string failure", sink.write);
  const obj = JSON.parse(sink.lines()[0]!) as Record<string, unknown>;
  assert.deepEqual(Object.keys(obj).sort(), ["code", "event", "message"]);
  assert.equal(obj.event, "fatal");
  assert.equal(obj.message, "plain string failure");
});

test("AC-005: scrubber redacts the home directory path from a fatal message", () => {
  const home = os.homedir();
  if (home.length <= 3) {
    return; // environment without a meaningful home path; nothing to prove
  }
  const message = `failed to open ${home}/config.json`;
  const scrubbed = scrubMessage(message);
  assert.ok(!scrubbed.includes(home), `home path must be scrubbed: ${scrubbed}`);
});

test("AC-005: scrubber redacts the username from a fatal message", () => {
  const username = os.userInfo().username;
  if (username.length <= 3) {
    return;
  }
  const message = `permission denied for user ${username}`;
  const scrubbed = scrubMessage(message);
  assert.ok(!scrubbed.includes(username), `username must be scrubbed: ${scrubbed}`);
});

test("AC-005: scrubber redacts the hostname from a fatal message", () => {
  const hostname = os.hostname();
  if (hostname.length <= 3) {
    return;
  }
  const message = `cannot reach ${hostname} on the local bus`;
  const scrubbed = scrubMessage(message);
  assert.ok(!scrubbed.includes(hostname), `hostname must be scrubbed: ${scrubbed}`);
});

test("AC-005: scrubber redacts a long environment-variable value from a fatal message", () => {
  // A value longer than 3 chars appearing verbatim in a message must be scrubbed.
  const secret = "canary-secret-abcdef-0123456789";
  process.env.LOCAL_ENV_MCP_CANARY_UNIT = secret;
  try {
    const message = `boot aborted with token ${secret} still present`;
    const scrubbed = scrubMessage(message);
    assert.ok(!scrubbed.includes(secret), `env value must be scrubbed: ${scrubbed}`);
  } finally {
    delete process.env.LOCAL_ENV_MCP_CANARY_UNIT;
  }
});

test("AC-005: logFatal scrubs secrets carried in the error message", () => {
  const sink = makeSink();
  const home = os.homedir();
  logFatal(new Error(`crash while reading ${home}/.secret`), sink.write);
  const raw = sink.raw();
  if (home.length > 3) {
    assert.ok(!raw.includes(home), "logFatal output must not contain the home path");
  }
});
