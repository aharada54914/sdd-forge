import { test } from "node:test";
import assert from "node:assert/strict";
import type { Result } from "../../src/envelope.js";
import { getTaskState } from "../../src/tools/core.js";
import {
  evidenceDeepVerify,
  evidenceGetBundle,
  evidenceSummarizeContractChecks,
  evidenceValidatePaths,
} from "../../src/tools/evidence.js";
import { getEnvelopeValidator } from "../evidence/test-helpers.js";
import { writeFile } from "../test-helpers.js";
import { seedDeepVerifyRepo } from "./deep-verify-helpers.js";

function assertConforms(result: Result<unknown>): void {
  const validate = getEnvelopeValidator();
  assert.ok(validate(result), JSON.stringify(validate.errors));
}

function okData<T>(result: Result<T>): T {
  assertConforms(result);
  assert.equal(result.ok, true);
  return result.data;
}

function assertCannotParse(result: Result<unknown>): void {
  assertConforms(result);
  assert.equal(result.ok, false);
  assert.equal(result.error.code, "cannot-parse");
}

test("legacy evidence and task-state readers return domain results for malformed JSON shapes and recover", async (t) => {
  const fx = seedDeepVerifyRepo("evidence-shape-boundary");
  t.after(fx.tempRoot.cleanup);
  writeFile(fx.dir, "specs/demo/tasks.md", "## T-001 Task\nApproval: Approved\nStatus: Done\nRisk: low\n");
  const root = fx.tempRoot.root;
  const getBundle = () => evidenceGetBundle(root, fx.feature, fx.taskId);
  const validatePaths = () => evidenceValidatePaths(root, fx.feature, fx.taskId);
  const deepVerify = () => evidenceDeepVerify(root, fx.feature, fx.taskId);
  const contractChecks = () => evidenceSummarizeContractChecks(root, fx.feature, fx.taskId);
  const taskState = () => getTaskState(root, fx.feature);

  for (const value of [null, [], 7, "scalar", true]) {
    await t.test("bundle " + JSON.stringify(value), () => {
      fx.writeBundle(value);
      assertCannotParse(getBundle());
      assertCannotParse(validatePaths());
      assertCannotParse(deepVerify());
      assert.equal(okData(taskState()).verdict, "fail");
    });
  }
  for (const value of [null, [], 7, "scalar"]) {
    await t.test("contract " + JSON.stringify(value), () => {
      fx.writeBundle(fx.baseBundle());
      writeFile(fx.dir, fx.contractRel, JSON.stringify(value));
      const deep = okData(deepVerify());
      assert.equal(deep.verdict, "fail");
      assert.ok(deep.invariants.crossBindings.some(
        item => item.subject === "verification_contract" && item.status === "mismatch",
      ));
      assertCannotParse(contractChecks());
      assert.equal(okData(taskState()).verdict, "fail");
    });
  }
  writeFile(fx.dir, fx.contractRel, fx.contractContents);
  for (const value of [null, [], 7, "scalar"]) {
    await t.test("artifact " + JSON.stringify(value) + " retains valid siblings", () => {
      const bundle = fx.baseBundle();
      bundle.artifacts = [...(bundle.artifacts as unknown[]), value];
      fx.writeBundle(bundle);
      assert.equal(okData(getBundle()).kind, "evidence-bundle");
      assert.deepEqual(
        okData(validatePaths()).results.map(item => item.safe),
        [true, true, true, false],
      );
      const deep = okData(deepVerify());
      assert.deepEqual(
        deep.artifacts.map(item => item.status),
        ["match", "match", "match", "invalid-recorded-sha"],
      );
      assert.equal(deep.verdict, "fail");
      assert.equal(okData(taskState()).verdict, "fail");
    });
  }
  for (const checks of [null, {}, [null], [[]], [3]]) {
    await t.test("checks " + JSON.stringify(checks), () => {
      fx.writeBundle(fx.baseBundle());
      writeFile(fx.dir, fx.contractRel, JSON.stringify({ task_id: fx.taskId, checks }));
      assertCannotParse(contractChecks());
      assert.equal(okData(taskState()).verdict, "fail");
    });
  }
  await t.test("object-valued fields cannot replace primitive conversion methods", () => {
    const bundle = fx.baseBundle();
    bundle.artifacts = [{ path: { toString: null }, sha256: { toString: null } }];
    fx.writeBundle(bundle);
    assert.equal(okData(deepVerify()).verdict, "fail");
    assert.equal(okData(taskState()).verdict, "fail");
    bundle.task_id = { toString: null };
    fx.writeBundle(bundle);
    assertCannotParse(getBundle());
  });
  fx.writeBundle(fx.baseBundle());
  writeFile(fx.dir, fx.contractRel, fx.contractContents);
  assert.equal(okData(deepVerify()).verdict, "pass");
  assert.equal(okData(taskState()).verdict, "pass");
});
