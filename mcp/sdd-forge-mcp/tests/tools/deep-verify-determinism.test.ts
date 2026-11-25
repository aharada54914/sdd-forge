/** The retained v1 evidence reader must serialize deterministically across reads and roots. */
import { test } from "node:test";
import assert from "node:assert/strict";
import { evidenceDeepVerify } from "../../src/tools/evidence.js";
import { seedDeepVerifyRepo, type DeepVerifyFixture } from "./deep-verify-helpers.js";

function serializedPass(fx: DeepVerifyFixture): string {
  const result = evidenceDeepVerify(fx.tempRoot.root, fx.feature, fx.taskId);
  assert.equal(result.ok, true);
  assert.equal(result.data.kind, "evidence-deep-verify");
  assert.equal(result.data.verdict, "pass");
  return JSON.stringify(result);
}

test("AC-013: the serialized evidenceDeepVerify pass result is identical on two reads of one root", (t) => {
  const fx = seedDeepVerifyRepo("deep-verify-determinism-pass-same-root");
  t.after(fx.tempRoot.cleanup);
  const first = serializedPass(fx);
  assert.equal(first, serializedPass(fx));

  for (const key of ["timestamp", '"date"', '"now"', "pid", "random", "uuid"]) {
    assert.ok(!first.toLowerCase().includes(key), "unexpected volatile field: " + key);
  }
});

test("AC-013: the serialized evidenceDeepVerify pass result is identical across independently seeded roots", (t) => {
  const first = seedDeepVerifyRepo("deep-verify-determinism-pass-fresh-a");
  t.after(first.tempRoot.cleanup);
  const second = seedDeepVerifyRepo("deep-verify-determinism-pass-fresh-b");
  t.after(second.tempRoot.cleanup);
  assert.notEqual(first.dir, second.dir);
  assert.equal(serializedPass(first), serializedPass(second));
});

test("AC-013: an error envelope (not-found) is byte-identical across two calls with identical input", (t) => {
  const fx = seedDeepVerifyRepo("deep-verify-determinism-error");
  t.after(fx.tempRoot.cleanup);
  function readMissing(): string {
    const result = evidenceDeepVerify(fx.tempRoot.root, fx.feature, "T-999");
    assert.equal(result.ok, false);
    assert.equal(result.error.code, "not-found");
    return JSON.stringify(result);
  }
  assert.equal(readMissing(), readMissing());
});
