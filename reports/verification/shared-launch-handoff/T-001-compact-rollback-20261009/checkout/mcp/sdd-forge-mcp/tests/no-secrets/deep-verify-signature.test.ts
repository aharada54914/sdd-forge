/**
 * TEST-011 / AC-011 (B3 signature-key boundary, REQ-008 / ADR-0008): the
 * central NO-KEY / NO-SIGNATURE-VERIFY control.
 *
 * `evidence_deep_verify` must treat the bundle `signature` block as echo-only:
 * it reports `present` + `alg` with `verified: false` FIXED, never reads any
 * signing key material (env var value or key file), never computes an HMAC,
 * and never lets the signature influence the verdict.
 *
 * These tests exercise the running tool with a canary secret installed in the
 * three documented key locations (`SDD_EVIDENCE_KEY`, `SDD_EVIDENCE_KEY_FILE`,
 * and a dummy key file) and assert the canary value appears in NEITHER the
 * response NOR stderr NOR any thrown error, that the signing key material has
 * zero effect on the output (behavioral proof it is never read), and that the
 * signature is echoed as `present: true` / `verified: false`.
 *
 * Note: a real `~/.sdd/evidence-key` is never written or overwritten — the
 * canary key file is placed in a throwaway temp directory pointed at by
 * `SDD_EVIDENCE_KEY_FILE`, and the `~/.sdd/evidence-key` case is covered by
 * path-guard's denylist (which this tool reuses) rather than by mutating the
 * user's home directory.
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import { writeFileSync } from "node:fs";
import { join } from "node:path";
import { makeTempPlainDir } from "../test-helpers.js";
import { evidenceDeepVerify } from "../../src/tools/evidence.js";
import {
  seedDeepVerifyRepo,
  sha256Of,
  type DeepVerifyFixture,
} from "../tools/deep-verify-helpers.js";

/**
 * A distinctive secret that must never surface. Assembled at runtime so the
 * literal is unmistakable in any leak while never resembling a real key file
 * committed to the repo.
 */
const CANARY = `CANARY-SIGNING-KEY-${"a1b2c3d4e5f6".repeat(2)}-DO-NOT-LEAK`;

/** Env vars this tool must never read the value of. */
const KEY_ENV_VARS = ["SDD_EVIDENCE_KEY", "SDD_EVIDENCE_KEY_FILE"] as const;

/**
 * Writes a fully consistent bundle carrying an `hmac-sha256` signature block
 * (present alg + a recorded value) into the seeded repo. The signature value
 * is a plausible HMAC hex, not the key — the key is the canary installed in the
 * environment.
 */
function seedSignedRepo(prefix: string): DeepVerifyFixture {
  const fx = seedDeepVerifyRepo(prefix);
  const bundle = fx.baseBundle();
  bundle.signature = {
    alg: "hmac-sha256",
    value: sha256Of("signed-payload"),
  };
  fx.writeBundle(bundle);
  return fx;
}

/** Runs `fn` with the canary key material installed, restoring env after. */
function withCanaryEnvironment<T>(keyFilePath: string, fn: () => T): T {
  const saved = new Map<string, string | undefined>();
  for (const name of KEY_ENV_VARS) {
    saved.set(name, process.env[name]);
  }
  process.env.SDD_EVIDENCE_KEY = CANARY;
  process.env.SDD_EVIDENCE_KEY_FILE = keyFilePath;
  try {
    return fn();
  } finally {
    for (const name of KEY_ENV_VARS) {
      const value = saved.get(name);
      if (value === undefined) {
        delete process.env[name];
      } else {
        process.env[name] = value;
      }
    }
  }
}

/** Captures everything written to stderr while `fn` runs. */
function captureStderr<T>(fn: () => T): { value: T; stderr: string } {
  const original = process.stderr.write.bind(process.stderr);
  let stderr = "";
  (process.stderr as unknown as { write: (chunk: unknown) => boolean }).write = (
    chunk: unknown,
  ): boolean => {
    stderr += String(chunk);
    return true;
  };
  try {
    return { value: fn(), stderr };
  } finally {
    (process.stderr as unknown as { write: typeof original }).write = original;
  }
}

test("AC-011: signature is echoed as present/verified:false without reading any signing key", () => {
  const fx = seedSignedRepo("no-secrets-signature");
  const keyDir = makeTempPlainDir("no-secrets-key");
  const keyFilePath = join(keyDir.dir, "evidence-key");
  writeFileSync(keyFilePath, `${CANARY}\n`, "utf-8");
  try {
    const { value: result, stderr } = captureStderr(() =>
      withCanaryEnvironment(keyFilePath, () =>
        evidenceDeepVerify(fx.tempRoot.root, fx.feature, fx.taskId),
      ),
    );

    assert.equal(result.ok, true);
    if (!result.ok) {
      return;
    }
    const data = result.data;

    // Signature is echoed only: present fact + alg, verified FIXED false.
    assert.equal(data.signature.present, true);
    assert.equal(data.signature.alg, "hmac-sha256");
    assert.equal(data.signature.verified, false);

    // The signature (and thus its unverifiable state) does not drag the
    // verdict down: a fully consistent bundle still passes.
    assert.equal(data.verdict, "pass");
    assert.deepEqual(data.failures, []);

    // The canary key value leaks into neither the response nor stderr.
    const serialized = JSON.stringify(data);
    assert.equal(
      serialized.includes(CANARY),
      false,
      "canary signing key must not appear anywhere in the response",
    );
    assert.equal(
      stderr.includes(CANARY),
      false,
      "canary signing key must not appear on stderr",
    );

    // The recorded HMAC value itself is not echoed either (only present + alg).
    assert.equal(data.signature.alg, "hmac-sha256");
    assert.equal(
      JSON.stringify(data.signature).includes(sha256Of("signed-payload")),
      false,
      "the recorded signature value must not be echoed",
    );
  } finally {
    keyDir.cleanup();
    fx.tempRoot.cleanup();
  }
});

test("AC-011: signing key material has zero effect on the output (behavioral proof it is never read)", () => {
  const fx = seedSignedRepo("no-secrets-invariance");
  const keyDir = makeTempPlainDir("no-secrets-key-invariance");
  const keyFilePath = join(keyDir.dir, "evidence-key");
  writeFileSync(keyFilePath, `${CANARY}\n`, "utf-8");
  try {
    // Baseline: no signing key material present in the environment at all.
    for (const name of KEY_ENV_VARS) {
      assert.equal(process.env[name], undefined, `${name} must be unset for the baseline`);
    }
    const baseline = evidenceDeepVerify(fx.tempRoot.root, fx.feature, fx.taskId);
    assert.equal(baseline.ok, true);

    // Same call with the canary key installed in every documented location.
    const withKey = withCanaryEnvironment(keyFilePath, () =>
      evidenceDeepVerify(fx.tempRoot.root, fx.feature, fx.taskId),
    );
    assert.equal(withKey.ok, true);
    if (!baseline.ok || !withKey.ok) {
      return;
    }

    // Byte-equal data proves the key material is never read: if the tool read
    // (or verified against) the key, the presence of the key would change the
    // output. It does not.
    assert.equal(
      JSON.stringify(withKey.data),
      JSON.stringify(baseline.data),
      "signing key material must not influence the deep-verify output",
    );
    assert.equal(withKey.data.signature.verified, false);
  } finally {
    keyDir.cleanup();
    fx.tempRoot.cleanup();
  }
});

test("AC-011: a thrown path (unreadable bundle) never carries the canary key value", () => {
  // Point at a feature with no bundle so parse fails; assert no error text
  // carries the canary, and no exception is thrown (errors are returned as
  // envelopes, not thrown).
  const fx = seedSignedRepo("no-secrets-error-path");
  const keyDir = makeTempPlainDir("no-secrets-key-error");
  const keyFilePath = join(keyDir.dir, "evidence-key");
  writeFileSync(keyFilePath, `${CANARY}\n`, "utf-8");
  try {
    let thrown: unknown;
    const { value: result, stderr } = captureStderr(() =>
      withCanaryEnvironment(keyFilePath, () => {
        try {
          return evidenceDeepVerify(fx.tempRoot.root, "does-not-exist", "T-999");
        } catch (error) {
          thrown = error;
          return undefined;
        }
      }),
    );

    assert.equal(thrown, undefined, "deep-verify must not throw on a missing bundle");
    assert.ok(result !== undefined);
    assert.equal(result?.ok, false);
    const serialized = JSON.stringify(result);
    assert.equal(serialized.includes(CANARY), false, "error envelope must not carry the canary");
    assert.equal(stderr.includes(CANARY), false, "stderr must not carry the canary");
  } finally {
    keyDir.cleanup();
    fx.tempRoot.cleanup();
  }
});
