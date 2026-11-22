/** Checks the retained v1 evidence results with the production reader and real fixture files. */
import { test } from "node:test";
import assert from "node:assert/strict";
import { evidenceDeepVerify } from "../../src/tools/evidence.js";
import { writeFile } from "../test-helpers.js";
import { getEnvelopeValidator } from "../evidence/test-helpers.js";
import { seedDeepVerifyRepo } from "./deep-verify-helpers.js";

test("AC-001: legacy evidenceDeepVerify returns an ok pass envelope for a consistent bundle", (t) => {
  const fx = seedDeepVerifyRepo("deep-verify-tool-pass");
  t.after(fx.tempRoot.cleanup);
  const envelope = evidenceDeepVerify(fx.tempRoot.root, fx.feature, fx.taskId);

  assert.equal(envelope.ok, true);
  const data = envelope.data;

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

  // AC-012 leg (epic-136-phase4-mcp T-002): this pre-existing ok-shape case
  // now also asserts the top-level `hostRequiredChecks` field.
  const hostRequiredChecks = data.hostRequiredChecks;
  if (!Array.isArray(hostRequiredChecks)) {
    assert.fail("hostRequiredChecks is absent from the ok evidence_deep_verify response");
  }
  assert.equal(hostRequiredChecks.length, 2);
  assert.deepEqual(
    hostRequiredChecks.map((entry) => entry.check),
    ["git-commit-ancestry", "signature-verification"],
  );
  assert.ok(hostRequiredChecks.every((entry) => entry.verified === false));
  assert.equal(hostRequiredChecks[0]?.note, data.invariants.gitCommit.reason);
  assert.equal(hostRequiredChecks[1]?.note, data.signature.note);
});

test("error envelope: an invalid taskId maps to invalid-input in evidenceDeepVerify", (t) => {
  const fx = seedDeepVerifyRepo("deep-verify-tool-invalid-input");
  t.after(fx.tempRoot.cleanup);
  const envelope = evidenceDeepVerify(fx.tempRoot.root, fx.feature, "not-a-task-id");

  assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));
  assert.equal(envelope.ok, false);
  assert.equal(envelope.error.code, "invalid-input");
});

test("error envelope: an invalid feature maps to invalid-input in evidenceDeepVerify", (t) => {
  const fx = seedDeepVerifyRepo("deep-verify-tool-invalid-feature");
  t.after(fx.tempRoot.cleanup);
  const envelope = evidenceDeepVerify(fx.tempRoot.root, "../escape", fx.taskId);

  assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));
  assert.equal(envelope.ok, false);
  assert.equal(envelope.error.code, "invalid-input");
});

test("error envelope: a missing bundle maps to not-found in evidenceDeepVerify", (t) => {
  const fx = seedDeepVerifyRepo("deep-verify-tool-not-found");
  t.after(fx.tempRoot.cleanup);
  // Valid taskId shape, but no <T-999>.evidence.json exists in the fixture.
  const envelope = evidenceDeepVerify(fx.tempRoot.root, fx.feature, "T-999");

  assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));
  assert.equal(envelope.ok, false);
  assert.equal(envelope.error.code, "not-found");
});

test("error envelope: a malformed-JSON bundle maps to cannot-parse in evidenceDeepVerify", (t) => {
  const fx = seedDeepVerifyRepo("deep-verify-tool-cannot-parse");
  t.after(fx.tempRoot.cleanup);
  writeFile(fx.dir, fx.bundleRel, "{ this is not valid json");
  const envelope = evidenceDeepVerify(fx.tempRoot.root, fx.feature, fx.taskId);

  assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));
  assert.equal(envelope.ok, false);
  assert.equal(envelope.error.code, "cannot-parse");
});
