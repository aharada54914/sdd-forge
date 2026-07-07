/**
 * AC (acceptance, T-001): envelope structural / contract-parity checks.
 *
 * - `ok()`/`err()`/`isOk()`/`isErr()` behave like sdd-forge-mcp / local-env-mcp.
 * - The `ErrorCode` union matches the contract's `error.code` enum exactly: the
 *   existing 7 codes PLUS the 3 ci-mcp additions (`upstream-error` /
 *   `rate-limited` / `auth-missing`) for a 10-code enum
 *   (contracts/ci-mcp-tools.v1.schema.json).
 *
 * This is the acceptance test for the envelope contract, written before
 * src/envelope.ts exists (acceptance-first discipline for T-001): the pretest
 * `tsc` compile fails until src/envelope.ts is implemented (captured as the
 * Red run in specs/ci-mcp/verification/T-001-red.txt).
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import { ok, err, isOk, isErr } from "../../src/envelope.js";
import type { ErrorCode } from "../../src/envelope.js";

// Compiled location: mcp/ci-mcp/dist-test/tests/envelope/. Walk up to the repo
// root (5 levels: envelope -> tests -> dist-test -> ci-mcp -> mcp -> repo root)
// to reach contracts/.
const CONTRACT_PATH = join(
  dirname(fileURLToPath(import.meta.url)),
  "..",
  "..",
  "..",
  "..",
  "..",
  "contracts",
  "ci-mcp-tools.v1.schema.json",
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

  const withDetails = err("rate-limited", "rate limited", { rateLimitResetAt: "2026-07-08T00:00:00Z" });
  assert.deepEqual(withDetails.error.details, { rateLimitResetAt: "2026-07-08T00:00:00Z" });
});

test("ErrorCode union matches the contract error.code enum exactly (10 codes)", () => {
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
    "upstream-error",
    "rate-limited",
    "auth-missing",
  ];

  assert.equal(tsCodes.length, 10, "ci-mcp ErrorCode union must have exactly 10 members");
  assert.deepEqual([...tsCodes].sort(), [...contractCodes].sort(), "TS ErrorCode must equal contract code enum");
});

test("the 7 pre-existing codes and the 3 ci-mcp additions are all present", () => {
  const preExisting: ErrorCode[] = [
    "cannot-parse",
    "cannot-determine",
    "not-found",
    "path-denied",
    "not-sdd-root",
    "too-large",
    "invalid-input",
  ];
  const additions: ErrorCode[] = ["upstream-error", "rate-limited", "auth-missing"];
  assert.equal(preExisting.length, 7);
  assert.equal(additions.length, 3);
  for (const code of [...preExisting, ...additions]) {
    // Exercises err() with every code to prove the union accepts each literal.
    const envelope = err(code, "message");
    assert.equal(envelope.error.code, code);
  }
});
