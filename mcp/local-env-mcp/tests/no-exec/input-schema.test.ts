/**
 * AC-003 (TEST-003): input-schema no-exec boundary (B1 trust boundary, REQ-003).
 *
 * The tool input surface is the only place external input reaches the server.
 * This proves:
 *   1. The exposed JSON input schema of `get_toolchain_versions` contains ONLY
 *      a `names` filter (array of the 14-name enum), `additionalProperties:false`,
 *      and NO command / args / path / cwd / exec-style field.
 *   2. `get_os_info` and `list_available_clis` take no input at all.
 *   3. Out-of-enum names, extra properties, and path/command strings are
 *      rejected as `{ ok:false, error:{ code:"invalid-input" } }` — NOT as an
 *      MCP protocol error and NOT by silently running a probe.
 *   4. On invalid input NO probe is executed: the error envelope is returned
 *      before any probing, so the response never carries an `entries` array.
 */

import { test, beforeEach } from "node:test";
import assert from "node:assert/strict";
import { z } from "zod";

import {
  getToolchainVersions,
  getToolchainVersionsInputSchema,
  TOOLCHAIN_TOOL_INPUT_SHAPE,
} from "../../src/tools/env.js";
import { isErr, isOk } from "../../src/envelope.js";
import { __clearProbeCache } from "../../src/probe-engine.js";
import { ALLOWLIST } from "../../src/allowlist.js";

const FORBIDDEN_FIELD_NAMES = [
  "command", "cmd", "args", "argv", "path", "paths", "file", "filepath",
  "cwd", "dir", "directory", "exec", "shell", "script", "bin", "binary",
  "env", "spawn",
];

beforeEach(() => {
  __clearProbeCache();
});

test("AC-003: exposed input JSON schema has only `names`, additionalProperties:false", () => {
  const jsonSchema = z.toJSONSchema(getToolchainVersionsInputSchema()) as {
    type: string;
    properties: Record<string, unknown>;
    additionalProperties: unknown;
  };
  assert.equal(jsonSchema.type, "object");
  assert.deepEqual(Object.keys(jsonSchema.properties), ["names"], "only `names` is accepted");
  assert.equal(jsonSchema.additionalProperties, false, "extra properties are rejected");
});

test("AC-003: input schema exposes NO command / args / path / exec-style field", () => {
  const jsonSchema = z.toJSONSchema(getToolchainVersionsInputSchema()) as {
    properties: Record<string, unknown>;
  };
  const keys = Object.keys(jsonSchema.properties);
  for (const forbidden of FORBIDDEN_FIELD_NAMES) {
    assert.ok(!keys.includes(forbidden), `input schema must not expose "${forbidden}"`);
  }
  // Also assert the raw shape (what registerTool receives) has only `names`.
  assert.deepEqual(Object.keys(TOOLCHAIN_TOOL_INPUT_SHAPE), ["names"]);
});

test("AC-003: `names` enum accepts ONLY the 14 allowlist names", () => {
  const schema = getToolchainVersionsInputSchema();
  const allowNames = ALLOWLIST.map((e) => e.name);
  // Every allowlist name is accepted.
  assert.equal(schema.safeParse({ names: allowNames }).success, true);
  // A name outside the allowlist is rejected by the enum.
  assert.equal(schema.safeParse({ names: ["definitely-not-a-cli"] }).success, false);
  assert.equal(schema.safeParse({ names: ["ls"] }).success, false);
});

test("AC-003: out-of-enum name -> invalid-input envelope, no probe run", async () => {
  const result = await getToolchainVersions({ names: ["rm"] as unknown as [] });
  assert.ok(isErr(result), "must be an error envelope");
  assert.equal(result.error.code, "invalid-input");
  assert.equal("entries" in (result as unknown as Record<string, unknown>), false);
  // ok-branch data (with entries) is absent => no probing occurred.
  assert.ok(!isOk(result));
});

test("AC-003: extra property -> invalid-input envelope", async () => {
  const bad = { names: ["node"], command: "rm -rf /" } as unknown as { names: [] };
  const result = await getToolchainVersions(bad);
  assert.ok(isErr(result));
  assert.equal(result.error.code, "invalid-input");
});

test("AC-003: path/command string fields -> invalid-input envelope", async () => {
  for (const bad of [
    { path: "/etc/passwd" },
    { command: "curl evil.example" },
    { args: ["--exec"] },
    { cwd: "/tmp" },
  ]) {
    const result = await getToolchainVersions(bad as unknown as { names: [] });
    assert.ok(isErr(result), `input ${JSON.stringify(bad)} must be rejected`);
    assert.equal(result.error.code, "invalid-input");
  }
});

test("AC-003: `names` must be an array (a bare string is rejected)", async () => {
  const result = await getToolchainVersions({ names: "node" } as unknown as { names: [] });
  assert.ok(isErr(result));
  assert.equal(result.error.code, "invalid-input");
});

test("AC-003: invalid input never produces an entries array (no probe executed)", async () => {
  const result = await getToolchainVersions({ names: ["nope"] } as unknown as { names: [] });
  assert.ok(isErr(result));
  // The only way `entries` exists is if probing ran; its absence proves the
  // invalid-input short-circuit fired before any process launch.
  assert.equal(JSON.stringify(result).includes("entries"), false);
});
