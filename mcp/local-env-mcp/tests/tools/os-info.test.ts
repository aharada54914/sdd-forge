/**
 * AC-001 (TEST-001): `get_os_info` returns a contract-compliant ok envelope.
 *
 * Validates that getOsInfo() produces `{ ok:true, data:{ kind:"os-info", ... } }`
 * whose data satisfies the contract's osInfoData schema (required fields,
 * `kind` const, and field types/minimums), and that it never leaks
 * hostname / username / home-directory values (secrets boundary, REQ-005 —
 * verified structurally here; full canary sweep is T-003).
 *
 * Contract conformance is checked with a hand-rolled structural validator
 * against the committed JSON Schema (no ajv dependency is available/allowed).
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import os from "node:os";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import { getOsInfo } from "../../src/tools/env.js";
import { isOk } from "../../src/envelope.js";

// Compiled location: dist-test/tests/tools/. Walk up 5 levels
// (tools -> tests -> dist-test -> local-env-mcp -> mcp -> repo root) to contracts/.
const CONTRACT_PATH = join(
  dirname(fileURLToPath(import.meta.url)),
  "..", "..", "..", "..", "..",
  "contracts",
  "local-env-mcp-tools.v1.schema.json",
);

const contract = JSON.parse(readFileSync(CONTRACT_PATH, "utf-8"));
const osInfoSchema = contract.$defs.osInfoData;

/** Minimal structural validator for the osInfoData subschema (no ajv). */
function validateOsInfo(data: unknown): string[] {
  const errors: string[] = [];
  if (typeof data !== "object" || data === null) {
    return ["data is not an object"];
  }
  const obj = data as Record<string, unknown>;
  const allowed = new Set(Object.keys(osInfoSchema.properties));
  // additionalProperties: false
  for (const key of Object.keys(obj)) {
    if (!allowed.has(key)) errors.push(`unexpected property "${key}"`);
  }
  // required present
  for (const req of osInfoSchema.required as string[]) {
    if (!(req in obj)) errors.push(`missing required "${req}"`);
  }
  // kind const
  if (obj.kind !== "os-info") errors.push(`kind must be "os-info", got ${String(obj.kind)}`);
  // string minLength:1 fields
  for (const f of ["platform", "arch", "osType", "osRelease", "nodeRuntime"]) {
    const v = obj[f];
    if (typeof v !== "string" || v.length < 1) errors.push(`"${f}" must be non-empty string`);
  }
  // cpuCount integer >= 1
  if (typeof obj.cpuCount !== "number" || !Number.isInteger(obj.cpuCount) || obj.cpuCount < 1) {
    errors.push(`"cpuCount" must be integer >= 1`);
  }
  // totalMemBytes integer >= 0
  if (typeof obj.totalMemBytes !== "number" || !Number.isInteger(obj.totalMemBytes) || obj.totalMemBytes < 0) {
    errors.push(`"totalMemBytes" must be integer >= 0`);
  }
  return errors;
}

test("AC-001: get_os_info returns an ok envelope", () => {
  const result = getOsInfo();
  assert.equal(result.ok, true);
  assert.ok(isOk(result));
});

test("AC-001: get_os_info data conforms to the contract osInfoData schema", () => {
  const result = getOsInfo();
  assert.ok(isOk(result));
  const errors = validateOsInfo(result.data);
  assert.deepEqual(errors, [], `contract violations:\n${errors.join("\n")}`);
});

test("AC-001: get_os_info exposes exactly the 8 contract fields, no more", () => {
  const result = getOsInfo();
  assert.ok(isOk(result));
  assert.deepEqual(
    Object.keys(result.data).sort(),
    ["arch", "cpuCount", "kind", "nodeRuntime", "osRelease", "osType", "platform", "totalMemBytes"],
  );
});

test("AC-001: get_os_info never leaks hostname / username / home directory values", () => {
  const result = getOsInfo();
  assert.ok(isOk(result));
  const serialized = JSON.stringify(result.data);
  const hostname = os.hostname();
  const userInfo = os.userInfo();
  const home = os.homedir();
  // These identity/PII values must not appear anywhere in the payload.
  if (hostname.length > 0) {
    assert.ok(!serialized.includes(hostname), "hostname must not appear in os-info");
  }
  if (userInfo.username.length > 0) {
    assert.ok(!serialized.includes(userInfo.username), "username must not appear in os-info");
  }
  if (home.length > 0) {
    assert.ok(!serialized.includes(home), "home directory path must not appear in os-info");
  }
});

test("AC-001: get_os_info values match the process/os APIs it reports on", () => {
  const result = getOsInfo();
  assert.ok(isOk(result));
  assert.equal(result.data.platform, process.platform);
  assert.equal(result.data.arch, process.arch);
  assert.equal(result.data.nodeRuntime, process.version);
});
