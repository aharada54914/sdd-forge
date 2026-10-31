/**
 * AC (unit level, mirrors local-env-mcp/tests/no-secrets/diagnostics.test.ts):
 * proves the redaction-safe stderr logger (`src/diagnostics.ts`) emits ONLY
 * the fixed field allowlist and single-line JSON, and that its message
 * scrubber replaces verbatim occurrences of the home directory, username,
 * hostname, any long environment-variable value, AND (ci-mcp-specific,
 * beyond local-env-mcp's generic scrubber) any `Bearer <token>` pattern that
 * might appear in a message even when the raw token substring itself has
 * already been redacted by the generic env-value pass.
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

test("logStartup emits exactly the allowlisted startup fields", () => {
  const sink = makeSink();
  logStartup({ name: "ci-mcp", version: "0.1.0", transport: "stdio" }, sink.write);
  const lines = sink.lines();
  assert.equal(lines.length, 1, "startup diagnostic must be a single line");
  const obj = JSON.parse(lines[0]!) as Record<string, unknown>;
  assert.deepEqual(
    Object.keys(obj).sort(),
    ["event", "name", "transport", "version"],
    "only the fixed startup field allowlist may appear",
  );
  assert.equal(obj.event, "startup");
  assert.equal(obj.name, "ci-mcp");
});

test("logFatal emits exactly the allowlisted fatal fields", () => {
  const sink = makeSink();
  logFatal(new Error("boom happened"), sink.write);
  const obj = JSON.parse(sink.lines()[0]!) as Record<string, unknown>;
  assert.deepEqual(Object.keys(obj).sort(), ["code", "event", "message"]);
  assert.equal(obj.event, "fatal");
  assert.equal(obj.message, "boom happened");
});

test("scrubber redacts the home directory, username, and hostname from a message", () => {
  const home = os.homedir();
  if (home.length > 3) {
    assert.ok(!scrubMessage(`failed to open ${home}/config.json`).includes(home));
  }
  const username = os.userInfo().username;
  if (username.length > 3) {
    assert.ok(!scrubMessage(`permission denied for user ${username}`).includes(username));
  }
  const hostname = os.hostname();
  if (hostname.length > 3) {
    assert.ok(!scrubMessage(`cannot reach ${hostname}`).includes(hostname));
  }
});

test("scrubber redacts a long environment-variable value from a message", () => {
  const secret = "canary-secret-abcdef-0123456789";
  process.env.CI_MCP_CANARY_UNIT = secret;
  try {
    const scrubbed = scrubMessage(`boot aborted with token ${secret} still present`);
    assert.ok(!scrubbed.includes(secret));
  } finally {
    delete process.env.CI_MCP_CANARY_UNIT;
  }
});

test("ci-mcp-specific: scrubber redacts an `Authorization: Bearer <token>` pattern even without the raw token in process.env", () => {
  // Simulates a message that carries a Bearer-style header value the generic
  // env-value scrubber alone would not catch (e.g. a token that was already
  // rotated out of process.env by the time the message is scrubbed).
  const message = "GitHub API call failed. Authorization: Bearer ghp_not_in_env_right_now_1234567890";
  const scrubbed = scrubMessage(message);
  assert.ok(!scrubbed.toLowerCase().includes("ghp_not_in_env_right_now"));
  assert.ok(!/bearer\s+ghp_/i.test(scrubbed), `Bearer token pattern must be scrubbed: ${scrubbed}`);
});

test("logFatal scrubs a Bearer token pattern carried in the error message", () => {
  const sink = makeSink();
  logFatal(new Error("upstream 401: Authorization: Bearer ghp_live_canary_abcdef123456"), sink.write);
  const raw = sink.raw();
  assert.ok(!raw.includes("ghp_live_canary_abcdef123456"), `stderr output must not contain the token: ${raw}`);
});
