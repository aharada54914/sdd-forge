/**
 * AC-015 (REQ-012): contract conformance for evidence_deep_verify.
 *
 * Unlike deep-verify-tool.test.ts (which asserts the ok `evidenceDeepVerifyData`
 * shape *structurally* and only ajv-validates the shared error envelopes), this
 * suite validates the *ok* `evidence_deep_verify` responses — both a passing and
 * a richly-failing bundle — against the full v1 tool-response contract
 * (contracts/sdd-forge-mcp-tools.v1.schema.json) via ajv, exercising the
 * `evidenceDeepVerifyData` oneOf branch that T-007 adds to the contract. It also
 * re-checks the three error envelopes (invalid-input / not-found / cannot-parse)
 * and, for additivity, confirms the existing five evidence tools' ok responses
 * still conform after the additive contract change.
 *
 * The ajv validator (`getEnvelopeValidator`) compiles the whole envelope schema
 * with `strict: true` and `additionalProperties: false` throughout, so a
 * response that carries an unexpected field, an out-of-enum status, or a shape
 * matching no `data.oneOf` branch fails validation. Removing the
 * `evidenceDeepVerifyData` branch from the contract therefore turns the two ok
 * deep-verify cases red (they match no branch), which is the T-007 red state.
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import { writeFile } from "../test-helpers.js";
import {
  connectFixture,
  getEnvelopeValidator,
  parseEnvelope,
  seedDemoFixture,
} from "../evidence/test-helpers.js";
import { seedDeepVerifyRepo } from "./deep-verify-helpers.js";

/** Asserts a parsed envelope conforms to the v1 contract, surfacing ajv errors. */
function assertConforms(envelope: unknown, label: string): void {
  const validate = getEnvelopeValidator();
  const valid = validate(envelope);
  assert.ok(
    valid,
    `${label} does not conform to the v1 contract: ${JSON.stringify(validate.errors)}`,
  );
}

test("AC-015: a passing evidence_deep_verify response conforms to the v1 contract (ajv)", async () => {
  const fx = seedDeepVerifyRepo("dv-conformance-pass");
  const fixture = await connectFixture(fx.tempRoot);
  try {
    const result = await fixture.client.callTool({
      name: "evidence_deep_verify",
      arguments: { feature: fx.feature, taskId: fx.taskId },
    });
    const envelope = parseEnvelope(result as never);

    assert.equal((envelope as { ok: boolean }).ok, true);
    assert.equal((envelope as { data: { verdict: string } }).data.verdict, "pass");
    assertConforms(envelope, "passing evidence_deep_verify envelope");
  } finally {
    await fixture.cleanup();
  }
});

test("AC-015: a failing evidence_deep_verify response (mixed statuses) conforms to the v1 contract (ajv)", async () => {
  const fx = seedDeepVerifyRepo("dv-conformance-fail");
  const bundle = fx.baseBundle();
  // Drive as many contract-branch shapes as possible in one response:
  //  - specRevision mismatch (recorded non-empty, no spec files -> computed "")
  //  - gitCommit shapeValid=false (not 40-hex)
  //  - a `missing` artifact (valid 64-hex recorded sha, path absent on disk)
  //  - an `invalid-recorded-sha` artifact (recorded sha not 64-hex)
  //  - a `mismatch` artifact (baseline artifact tampered on disk after write)
  bundle.spec_revision = "deadbeef";
  bundle.git_commit = "not-a-valid-40-hex-commit";
  (bundle.artifacts as Array<Record<string, unknown>>).push(
    { path: "specs/demo/does-not-exist.md", sha256: "f".repeat(64) },
    { path: fx.artifactRel, sha256: "zz-not-hex" },
  );
  fx.writeBundle(bundle);
  // Tamper the on-disk baseline artifact so its recorded (valid) sha mismatches.
  writeFile(fx.dir, fx.artifactRel, `${fx.artifactContents}TAMPER\n`);

  const fixture = await connectFixture(fx.tempRoot);
  try {
    const result = await fixture.client.callTool({
      name: "evidence_deep_verify",
      arguments: { feature: fx.feature, taskId: fx.taskId },
    });
    const envelope = parseEnvelope(result as never);

    assert.equal((envelope as { ok: boolean }).ok, true);
    const data = (envelope as {
      data: { verdict: string; failures: string[]; artifacts: Array<{ status: string }> };
    }).data;
    assert.equal(data.verdict, "fail");
    assert.ok(data.failures.length > 0);
    const statuses = new Set(data.artifacts.map((a) => a.status));
    assert.ok(statuses.has("mismatch"));
    assert.ok(statuses.has("missing"));
    assert.ok(statuses.has("invalid-recorded-sha"));
    assertConforms(envelope, "failing evidence_deep_verify envelope");
  } finally {
    await fixture.cleanup();
  }
});

test("AC-015: an invalid-input error envelope conforms to the v1 contract (ajv)", async () => {
  const fx = seedDeepVerifyRepo("dv-conformance-invalid-input");
  const fixture = await connectFixture(fx.tempRoot);
  try {
    const result = await fixture.client.callTool({
      name: "evidence_deep_verify",
      arguments: { feature: fx.feature, taskId: "not-a-task-id" },
    });
    const envelope = parseEnvelope(result as never);

    assertConforms(envelope, "invalid-input error envelope");
    assert.equal((envelope as { ok: boolean }).ok, false);
    assert.equal((envelope as { error: { code: string } }).error.code, "invalid-input");
  } finally {
    await fixture.cleanup();
  }
});

test("AC-015: a not-found error envelope conforms to the v1 contract (ajv)", async () => {
  const fx = seedDeepVerifyRepo("dv-conformance-not-found");
  const fixture = await connectFixture(fx.tempRoot);
  try {
    // Valid taskId shape, but no <T-999>.evidence.json exists in the fixture.
    const result = await fixture.client.callTool({
      name: "evidence_deep_verify",
      arguments: { feature: fx.feature, taskId: "T-999" },
    });
    const envelope = parseEnvelope(result as never);

    assertConforms(envelope, "not-found error envelope");
    assert.equal((envelope as { ok: boolean }).ok, false);
    assert.equal((envelope as { error: { code: string } }).error.code, "not-found");
  } finally {
    await fixture.cleanup();
  }
});

test("AC-015: a cannot-parse error envelope conforms to the v1 contract (ajv)", async () => {
  const fx = seedDeepVerifyRepo("dv-conformance-cannot-parse");
  // Overwrite the consistent bundle with invalid JSON before connecting.
  writeFile(fx.dir, fx.bundleRel, "{ this is not valid json");
  const fixture = await connectFixture(fx.tempRoot);
  try {
    const result = await fixture.client.callTool({
      name: "evidence_deep_verify",
      arguments: { feature: fx.feature, taskId: fx.taskId },
    });
    const envelope = parseEnvelope(result as never);

    assertConforms(envelope, "cannot-parse error envelope");
    assert.equal((envelope as { ok: boolean }).ok, false);
    assert.equal((envelope as { error: { code: string } }).error.code, "cannot-parse");
  } finally {
    await fixture.cleanup();
  }
});

test("AC-015 additivity: the existing five evidence tool responses still conform to the v1 contract", async () => {
  const tempRoot = seedDemoFixture("dv-conformance-existing");
  const fixture = await connectFixture(tempRoot);
  try {
    const calls = [
      { name: "evidence_get_bundle", arguments: { feature: "demo", taskId: "T-001" } },
      { name: "evidence_validate_paths", arguments: { feature: "demo", taskId: "T-001" } },
      { name: "evidence_find_missing", arguments: { feature: "demo", taskId: "T-001" } },
      { name: "evidence_summarize_contract_checks", arguments: { feature: "demo", taskId: "T-001" } },
      { name: "evidence_compare_to_traceability", arguments: { feature: "demo" } },
    ];
    for (const call of calls) {
      const result = await fixture.client.callTool(call);
      const envelope = parseEnvelope(result as never);
      assert.equal((envelope as { ok: boolean }).ok, true, `${call.name} did not return an ok envelope`);
      assertConforms(envelope, `${call.name} ok envelope`);
    }
  } finally {
    await fixture.cleanup();
  }
});
