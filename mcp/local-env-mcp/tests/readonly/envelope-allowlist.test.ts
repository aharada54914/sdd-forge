/**
 * Structural / contract-parity checks for envelope.ts and allowlist.ts.
 *
 * - Envelope: ok()/err()/isOk()/isErr() behave like sdd-forge-mcp, and the
 *   ErrorCode union matches the contract's error.code enum exactly (WFI-001
 *   preflight row 7).
 * - Allowlist: exactly the 14 CLIs required by design.md / ADR-0004, each with
 *   { name, command, args, versionStream }, and java uses -version + stderr.
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import { ok, err, isOk, isErr } from "../../src/envelope.js";
import type { ErrorCode } from "../../src/envelope.js";
import { ALLOWLIST } from "../../src/allowlist.js";
import type { AllowlistEntry } from "../../src/allowlist.js";

// Compiled location: mcp/local-env-mcp/dist-test/tests/readonly/. Walk up to
// the repo root (5 levels: readonly -> tests -> dist-test -> local-env-mcp ->
// mcp -> repo root) to reach contracts/.
const CONTRACT_PATH = join(
  dirname(fileURLToPath(import.meta.url)),
  "..",
  "..",
  "..",
  "..",
  "..",
  "contracts",
  "local-env-mcp-tools.v1.schema.json",
);

test("ok() builds a success envelope", () => {
  const e = ok({ hello: "world" });
  assert.equal(e.ok, true);
  assert.deepEqual(e.data, { hello: "world" });
  assert.ok(isOk(e));
  assert.ok(!isErr(e));
});

test("err() builds a failure envelope; details optional and secret-free", () => {
  const bare = err("invalid-input", "bad");
  assert.equal(bare.ok, false);
  assert.equal(bare.error.code, "invalid-input");
  assert.equal(bare.error.message, "bad");
  assert.equal("details" in bare.error, false);
  assert.ok(isErr(bare));

  const withDetails = err("cannot-determine", "nope", { rule: "R1" });
  assert.deepEqual(withDetails.error.details, { rule: "R1" });
});

test("ErrorCode union matches the contract error.code enum exactly", () => {
  const contract = JSON.parse(readFileSync(CONTRACT_PATH, "utf-8"));
  const contractCodes: string[] = contract.$defs.errorEnvelope.properties.error.properties.code.enum;

  // Mirror the TS union as runtime values; a compile error here (unknown
  // member) would flag drift on the TS side.
  const tsCodes: ErrorCode[] = [
    "cannot-parse",
    "cannot-determine",
    "not-found",
    "path-denied",
    "not-sdd-root",
    "too-large",
    "invalid-input",
  ];

  assert.deepEqual([...tsCodes].sort(), [...contractCodes].sort(), "TS ErrorCode must equal contract code enum");
});

test("allowlist has exactly the 14 required CLIs in order", () => {
  const expected = [
    "node", "npm", "pnpm", "yarn", "bun", "deno", "git",
    "gh", "python3", "go", "rustc", "cargo", "java", "docker",
  ];
  assert.deepEqual(ALLOWLIST.map((e: AllowlistEntry) => e.name), expected);
});

test("every allowlist entry has name/command/args/versionStream; java uses -version+stderr", () => {
  for (const e of ALLOWLIST) {
    assert.equal(typeof e.name, "string");
    assert.equal(typeof e.command, "string");
    assert.ok(Array.isArray(e.args));
    assert.ok(e.versionStream === "stdout" || e.versionStream === "stderr");
  }
  const java = ALLOWLIST.find((e) => e.name === "java")!;
  assert.deepEqual(java.args, ["-version"]);
  assert.equal(java.versionStream, "stderr");

  const node = ALLOWLIST.find((e) => e.name === "node")!;
  assert.deepEqual(node.args, ["--version"]);
  assert.equal(node.versionStream, "stdout");
});

test("allowlist command names contain no shell metacharacters or path separators", () => {
  for (const e of ALLOWLIST) {
    assert.ok(/^[a-z0-9]+$/.test(e.command), `command "${e.command}" must be a bare binary name`);
  }
});
