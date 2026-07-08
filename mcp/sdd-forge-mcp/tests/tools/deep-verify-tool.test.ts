/**
 * evidence_deep_verify — server.ts registration + integrated response (T-004).
 *
 * Unlike deep-verify.test.ts (which calls the pure `evidenceDeepVerify`
 * function directly), these tests drive the *registered* tool through a real
 * MCP client/server pair (SDK InMemoryTransport), exercising the same request
 * path an external client uses. They assert the assembled
 * `evidenceDeepVerifyData` response and the error-envelope mapping.
 *
 * - AC-001: a fully consistent bundle -> `verdict: "pass"`, `failures: []`,
 *   every artifact `match`, every invariant satisfied — returned as an `ok`
 *   envelope through the tool.
 * - Error envelopes (existing conventions, design.md "API / Contract Plan"):
 *   invalid feature/taskId -> `invalid-input`; a missing bundle -> `not-found`;
 *   a malformed-JSON bundle -> `cannot-parse`. The error branch of the v1
 *   envelope is shared (not tool-specific), so it is additionally checked
 *   against the contract schema; the ok-branch `evidenceDeepVerifyData` shape
 *   is added to the contract by T-007, so it is asserted structurally here.
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import { writeFile } from "../test-helpers.js";
import { connectFixture, getEnvelopeValidator, parseEnvelope } from "../evidence/test-helpers.js";
import { seedDeepVerifyRepo } from "./deep-verify-helpers.js";

interface ErrorEnvelope {
  ok: false;
  error: { code: string; message: string };
}

test("AC-001: evidence_deep_verify tool returns an ok pass envelope for a consistent bundle", async () => {
  const fx = seedDeepVerifyRepo("deep-verify-tool-pass");
  const fixture = await connectFixture(fx.tempRoot);
  try {
    const result = await fixture.client.callTool({
      name: "evidence_deep_verify",
      arguments: { feature: fx.feature, taskId: fx.taskId },
    });
    const envelope = parseEnvelope(result as never);

    assert.equal((envelope as { ok: boolean }).ok, true);
    const data = (
      envelope as {
        ok: true;
        data: {
          kind: string;
          feature: string;
          taskId: string;
          verdict: string;
          failures: string[];
          artifacts: Array<{ status: string }>;
          invariants: {
            artifactsDigest: { status: string };
            specRevision: { status: string };
            gitCommit: { shapeValid: boolean; ancestryVerified: boolean };
            crossBindings: Array<{ status: string }>;
          };
          signature: { verified: boolean };
        };
      }
    ).data;

    assert.equal(data.kind, "evidence-deep-verify");
    assert.equal(data.feature, fx.feature);
    assert.equal(data.taskId, fx.taskId);
    assert.equal(data.verdict, "pass");
    assert.deepEqual(data.failures, []);
    assert.equal(data.artifacts.length, 3);
    assert.ok(data.artifacts.every((a) => a.status === "match"));
    assert.equal(data.invariants.artifactsDigest.status, "match");
    assert.equal(data.invariants.specRevision.status, "match");
    assert.equal(data.invariants.gitCommit.shapeValid, true);
    assert.equal(data.invariants.gitCommit.ancestryVerified, false);
    assert.ok(data.invariants.crossBindings.every((b) => b.status === "match"));
    assert.equal(data.signature.verified, false);
  } finally {
    await fixture.cleanup();
  }
});

test("error envelope: an invalid taskId maps to invalid-input through the tool", async () => {
  const fx = seedDeepVerifyRepo("deep-verify-tool-invalid-input");
  const fixture = await connectFixture(fx.tempRoot);
  try {
    const result = await fixture.client.callTool({
      name: "evidence_deep_verify",
      arguments: { feature: fx.feature, taskId: "not-a-task-id" },
    });
    const envelope = parseEnvelope(result as never) as ErrorEnvelope;

    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));
    assert.equal(envelope.ok, false);
    assert.equal(envelope.error.code, "invalid-input");
  } finally {
    await fixture.cleanup();
  }
});

test("error envelope: an invalid feature maps to invalid-input through the tool", async () => {
  const fx = seedDeepVerifyRepo("deep-verify-tool-invalid-feature");
  const fixture = await connectFixture(fx.tempRoot);
  try {
    const result = await fixture.client.callTool({
      name: "evidence_deep_verify",
      arguments: { feature: "../escape", taskId: fx.taskId },
    });
    const envelope = parseEnvelope(result as never) as ErrorEnvelope;

    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));
    assert.equal(envelope.ok, false);
    assert.equal(envelope.error.code, "invalid-input");
  } finally {
    await fixture.cleanup();
  }
});

test("error envelope: a missing bundle maps to not-found through the tool", async () => {
  const fx = seedDeepVerifyRepo("deep-verify-tool-not-found");
  const fixture = await connectFixture(fx.tempRoot);
  try {
    // Valid taskId shape, but no <T-999>.evidence.json exists in the fixture.
    const result = await fixture.client.callTool({
      name: "evidence_deep_verify",
      arguments: { feature: fx.feature, taskId: "T-999" },
    });
    const envelope = parseEnvelope(result as never) as ErrorEnvelope;

    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));
    assert.equal(envelope.ok, false);
    assert.equal(envelope.error.code, "not-found");
  } finally {
    await fixture.cleanup();
  }
});

test("error envelope: a malformed-JSON bundle maps to cannot-parse through the tool", async () => {
  const fx = seedDeepVerifyRepo("deep-verify-tool-cannot-parse");
  // Overwrite the consistent bundle with invalid JSON before connecting.
  writeFile(fx.dir, fx.bundleRel, "{ this is not valid json");
  const fixture = await connectFixture(fx.tempRoot);
  try {
    const result = await fixture.client.callTool({
      name: "evidence_deep_verify",
      arguments: { feature: fx.feature, taskId: fx.taskId },
    });
    const envelope = parseEnvelope(result as never) as ErrorEnvelope;

    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));
    assert.equal(envelope.ok, false);
    assert.equal(envelope.error.code, "cannot-parse");
  } finally {
    await fixture.cleanup();
  }
});
