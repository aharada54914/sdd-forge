/**
 * AC-013 (REQ-010): determinism. `evidence_deep_verify` is a pure function of
 * `(bundle contents, on-disk artifact contents)` — `evidenceDeepVerify`
 * (`src/tools/evidence.ts`) never reads a clock, a random source, or any
 * host/process identifier, so calling it twice through the registered tool
 * with identical input and unchanged disk state must yield byte-identical
 * `content[0].text` (not just deep-equal `data` — byte equality also catches
 * incidental key-order drift, which `assert.deepEqual` would silently
 * tolerate).
 *
 * Covers both the `ok` (pass verdict) branch and an `error` envelope branch,
 * since AC-013's "同一入力で2回呼ぶと data がバイト等価" is not scoped to the
 * pass case alone.
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import type { CallToolResult } from "@modelcontextprotocol/sdk/types.js";
import { connectFixture } from "../evidence/test-helpers.js";
import { seedDeepVerifyRepo } from "./deep-verify-helpers.js";

/** Extracts the raw `content[0].text` string (not parsed) for byte comparison. */
function rawText(result: unknown): string {
  const content = (result as CallToolResult).content;
  const first = content[0];
  if (first === undefined || first.type !== "text") {
    throw new Error(`Expected a text content block, got: ${JSON.stringify(content)}`);
  }
  return first.text;
}

test("AC-013: evidence_deep_verify (pass verdict) is byte-identical across two calls, same connection", async () => {
  const fx = seedDeepVerifyRepo("deep-verify-determinism-pass-same-conn");
  const fixture = await connectFixture(fx.tempRoot);
  try {
    const args = { feature: fx.feature, taskId: fx.taskId };
    const first = rawText(await fixture.client.callTool({ name: "evidence_deep_verify", arguments: args }));
    const second = rawText(await fixture.client.callTool({ name: "evidence_deep_verify", arguments: args }));
    assert.equal(first, second);

    // Guard against a future volatile field slipping in unnoticed (clock,
    // pid, random id) — none of these key names should ever appear in a
    // deep-verify response.
    const parsed = JSON.parse(first) as unknown;
    const serialized = JSON.stringify(parsed);
    for (const volatileKey of ["timestamp", "\"date\"", "\"now\"", "pid", "random", "uuid"]) {
      assert.ok(
        !serialized.toLowerCase().includes(volatileKey.toLowerCase()),
        `response unexpectedly contains a volatile-looking field: ${volatileKey}`,
      );
    }
  } finally {
    await fixture.cleanup();
  }
});

test("AC-013: evidence_deep_verify (pass verdict) is byte-identical across two independently seeded, independently connected servers", async () => {
  // Two separate `seedDeepVerifyRepo` calls (distinct temp directories, each
  // with its own `buildServer` + client pair) rules out any in-process
  // cache/memoization as the source of the (expected) equality — the tool
  // must be deterministic on its own, not merely idempotent within one
  // server instance. `seedDeepVerifyRepo` always records the same
  // repo-relative paths and byte-identical file contents regardless of which
  // OS temp directory backs a given call, so the two responses must match.
  const fxA = seedDeepVerifyRepo("deep-verify-determinism-pass-fresh-a");
  const fxB = seedDeepVerifyRepo("deep-verify-determinism-pass-fresh-b");
  const fixtureA = await connectFixture(fxA.tempRoot);
  const fixtureB = await connectFixture(fxB.tempRoot);
  try {
    const argsA = { feature: fxA.feature, taskId: fxA.taskId };
    const argsB = { feature: fxB.feature, taskId: fxB.taskId };
    const firstText = rawText(await fixtureA.client.callTool({ name: "evidence_deep_verify", arguments: argsA }));
    const secondText = rawText(await fixtureB.client.callTool({ name: "evidence_deep_verify", arguments: argsB }));
    assert.equal(firstText, secondText);
  } finally {
    await fixtureA.cleanup();
    await fixtureB.cleanup();
  }
});

test("AC-013: an error envelope (not-found) is byte-identical across two calls with identical input", async () => {
  const fx = seedDeepVerifyRepo("deep-verify-determinism-error");
  const fixture = await connectFixture(fx.tempRoot);
  try {
    const args = { feature: fx.feature, taskId: "T-999" };
    const first = rawText(await fixture.client.callTool({ name: "evidence_deep_verify", arguments: args }));
    const second = rawText(await fixture.client.callTool({ name: "evidence_deep_verify", arguments: args }));
    assert.equal(first, second);
  } finally {
    await fixture.cleanup();
  }
});
