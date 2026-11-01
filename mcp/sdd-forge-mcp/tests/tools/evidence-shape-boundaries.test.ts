import { test } from "node:test";
import assert from "node:assert/strict";
import { connectFixture, getEnvelopeValidator, parseEnvelope } from "../evidence/test-helpers.js";
import { seedDeepVerifyRepo } from "./deep-verify-helpers.js";
import { writeFile } from "../test-helpers.js";

test("public tools keep malformed JSON shapes within domain results and remain usable", async (t) => {
  const fx = seedDeepVerifyRepo("evidence-shape-boundary");
  writeFile(fx.dir, "specs/demo/tasks.md", "## T-001 Task\nApproval: Approved\nStatus: Done\nRisk: low\n");
  const fixture = await connectFixture(fx.tempRoot);
  const call = async (name: string) => {
    const result = await fixture.client.callTool({name, arguments: {feature: fx.feature, ...(name === "get_task_state" ? {} : {taskId: fx.taskId})}});
    assert.notEqual(result.isError, true, "protocol errors must not replace domain envelopes");
    const envelope = parseEnvelope(result) as {ok: boolean; error?: {code: string}; data: {verdict: string; artifacts: Array<{status: string}>; results: Array<{safe: boolean}>; invariants: {crossBindings: Array<{subject: string; status: string}>}}};
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));
    return envelope;
  };
  try {
    for (const value of [null, [], 7, "scalar", true]) {
      await t.test(`bundle ${JSON.stringify(value)}`, async () => {
        fx.writeBundle(value);
        for (const name of ["evidence_get_bundle", "evidence_validate_paths", "evidence_deep_verify"]) assert.equal((await call(name)).error?.code, "cannot-parse");
        assert.equal((await call("get_task_state")).data.verdict, "fail");
      });
    }
    for (const value of [null, [], 7, "scalar"]) {
      await t.test(`contract ${JSON.stringify(value)}`, async () => {
        fx.writeBundle(fx.baseBundle()); writeFile(fx.dir, fx.contractRel, JSON.stringify(value));
        const deep = await call("evidence_deep_verify");
        assert.equal(deep.data.verdict, "fail");
        assert.ok(deep.data.invariants.crossBindings.some(item => item.subject === "verification_contract" && item.status === "mismatch"));
        assert.equal((await call("evidence_summarize_contract_checks")).error?.code, "cannot-parse");
        assert.equal((await call("get_task_state")).data.verdict, "fail");
      });
    }
    writeFile(fx.dir, fx.contractRel, fx.contractContents);
    for (const value of [null, [], 7, "scalar"]) {
      await t.test(`artifact ${JSON.stringify(value)} retains valid siblings`, async () => {
        const bundle = fx.baseBundle(); bundle.artifacts = [...bundle.artifacts as unknown[], value]; fx.writeBundle(bundle);
        assert.equal((await call("evidence_get_bundle")).ok, true);
        assert.deepEqual((await call("evidence_validate_paths")).data.results.map(item => item.safe), [true, true, true, false]);
        const deep = await call("evidence_deep_verify");
        assert.deepEqual(deep.data.artifacts.map(item => item.status), ["match", "match", "match", "invalid-recorded-sha"]);
        assert.equal(deep.data.verdict, "fail");
        assert.equal((await call("get_task_state")).data.verdict, "fail");
      });
    }
    for (const checks of [null, {}, [null], [[]], [3]]) {
      await t.test(`checks ${JSON.stringify(checks)}`, async () => {
        fx.writeBundle(fx.baseBundle()); writeFile(fx.dir, fx.contractRel, JSON.stringify({ task_id: fx.taskId, checks }));
        assert.equal((await call("evidence_summarize_contract_checks")).error?.code, "cannot-parse");
        assert.equal((await call("get_task_state")).data.verdict, "fail");
      });
    }
    await t.test("object-valued fields cannot replace primitive conversion methods", async () => {
      const bundle = fx.baseBundle();
      bundle.artifacts = [{ path: {toString: null}, sha256: {toString: null} }];
      fx.writeBundle(bundle);
      assert.equal((await call("evidence_deep_verify")).data.verdict, "fail");
      assert.equal((await call("get_task_state")).data.verdict, "fail");
      bundle.task_id = {toString: null}; fx.writeBundle(bundle);
      assert.equal((await call("evidence_get_bundle")).error?.code, "cannot-parse");
    });
    fx.writeBundle(fx.baseBundle()); writeFile(fx.dir, fx.contractRel, fx.contractContents);
    assert.equal((await call("evidence_deep_verify")).data.verdict, "pass", "same connection recovers");
    assert.equal((await call("get_task_state")).data.verdict, "pass");
  } finally { await fixture.cleanup(); }
});
