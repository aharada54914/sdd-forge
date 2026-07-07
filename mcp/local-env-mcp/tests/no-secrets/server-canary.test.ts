/**
 * AC-005 (TEST-005) — end-to-end no-secrets sweep.
 *
 * Spawns the compiled server entrypoint (dist-test/src/index.js) under a canary
 * environment, drives one `tools/list` and one `tools/call` for EACH of the
 * three tools over stdio JSON-RPC (newline-delimited framing, matching the MCP
 * SDK's StdioServerTransport), captures the combined stdout + stderr, and
 * asserts none of the following appear anywhere:
 *
 *   - the canary env value (LOCAL_ENV_MCP_CANARY),
 *   - os.userInfo().username,
 *   - os.hostname(),
 *   - os.homedir(),
 *   - the full process.env.PATH value.
 *
 * This exercises the real startup diagnostic (stderr) plus every tool response
 * (stdout), covering both channels named by AC-005.
 *
 * The imported diagnostics module is NOT used at runtime here; requiring the
 * compiled entrypoint to exist (and to start clean under a canary env) is the
 * whole test. It intentionally spawns a real node process — the only "execution"
 * is on the test side; src/ still launches nothing at startup.
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import os from "node:os";
import { spawn } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

// Compiled location: dist-test/tests/no-secrets/. The entrypoint compiles to
// dist-test/src/index.js — two levels up, then into src/.
const ENTRYPOINT = join(dirname(fileURLToPath(import.meta.url)), "..", "..", "src", "index.js");

const CANARY_VALUE = "canary-secret-9f3b2a-do-not-leak-01234567";

/** A JSON-RPC request line (newline-delimited, per MCP stdio framing). */
function rpc(id: number, method: string, params: unknown): string {
  return `${JSON.stringify({ jsonrpc: "2.0", id, method, params })}\n`;
}

interface SweepResult {
  stdout: string;
  stderr: string;
  exitCode: number | null;
}

/**
 * Spawns the server, drives initialize + tools/list + a tools/call for each of
 * the three tools, then closes stdin and resolves with the captured streams.
 */
function runServerSweep(): Promise<SweepResult> {
  return new Promise<SweepResult>((resolve, reject) => {
    const child = spawn(process.execPath, [ENTRYPOINT], {
      // Canary env is present; the server must never echo its value.
      env: { ...process.env, LOCAL_ENV_MCP_CANARY: CANARY_VALUE },
      stdio: ["pipe", "pipe", "pipe"],
    });

    let stdout = "";
    let stderr = "";
    child.stdout.setEncoding("utf-8");
    child.stderr.setEncoding("utf-8");
    child.stdout.on("data", (chunk: string) => {
      stdout += chunk;
    });
    child.stderr.on("data", (chunk: string) => {
      stderr += chunk;
    });

    child.on("error", reject);
    child.on("close", (code) => {
      resolve({ stdout, stderr, exitCode: code });
    });

    // Drive the protocol. initialize first (required handshake), then list, then
    // one call per tool. get_toolchain_versions is probed with an explicit
    // allowlist subset so the sweep stays fast and deterministic.
    child.stdin.write(
      rpc(1, "initialize", {
        protocolVersion: "2024-11-05",
        capabilities: {},
        clientInfo: { name: "no-secrets-sweep", version: "0.0.0" },
      }),
    );
    child.stdin.write(`${JSON.stringify({ jsonrpc: "2.0", method: "notifications/initialized" })}\n`);
    child.stdin.write(rpc(2, "tools/list", {}));
    child.stdin.write(rpc(3, "tools/call", { name: "get_os_info", arguments: {} }));
    child.stdin.write(rpc(4, "tools/call", { name: "get_toolchain_versions", arguments: { names: ["node"] } }));
    child.stdin.write(rpc(5, "tools/call", { name: "list_available_clis", arguments: {} }));

    // Give the server time to answer, then close stdin so it exits.
    setTimeout(() => {
      child.stdin.end();
      // Safety backstop: never let the test hang if the server stays open.
      setTimeout(() => {
        if (child.exitCode === null) {
          child.kill("SIGKILL");
        }
      }, 3000);
    }, 2500);
  });
}

test("AC-005: server startup + all three tools leak no secrets to stdout or stderr", async () => {
  const { stdout, stderr, exitCode } = await runServerSweep();
  const combined = `${stdout}\n${stderr}`;

  // Sanity: the server actually responded (tools/list result present) so the
  // absence assertions are meaningful, not vacuous.
  assert.ok(
    stdout.includes("get_os_info") &&
      stdout.includes("get_toolchain_versions") &&
      stdout.includes("list_available_clis"),
    `tools/list should have returned the 3 tools; got stdout:\n${stdout}\nstderr:\n${stderr}`,
  );
  // The os-info payload rides inside an escaped-JSON MCP text field
  // (content[0].text), so the inner quotes are backslash-escaped on the wire;
  // match the kind marker without assuming a particular quote framing.
  assert.ok(stdout.includes("os-info"), "get_os_info should have returned an os-info payload");

  // The canary value must never appear on either stream.
  assert.ok(!combined.includes(CANARY_VALUE), "canary env value must not appear in stdout/stderr");

  const username = os.userInfo().username;
  if (username.length > 3) {
    assert.ok(!combined.includes(username), `username "${username}" must not appear in stdout/stderr`);
  }

  const hostname = os.hostname();
  if (hostname.length > 3) {
    assert.ok(!combined.includes(hostname), `hostname "${hostname}" must not appear in stdout/stderr`);
  }

  const home = os.homedir();
  if (home.length > 3) {
    assert.ok(!combined.includes(home), `home directory "${home}" must not appear in stdout/stderr`);
  }

  const fullPath = process.env.PATH ?? "";
  if (fullPath.length > 0) {
    assert.ok(!combined.includes(fullPath), "the full PATH value must not appear in stdout/stderr");
  }

  // The server should exit cleanly once stdin closes (not crash).
  assert.ok(exitCode === 0 || exitCode === null, `server exited abnormally with code ${String(exitCode)}`);
});
