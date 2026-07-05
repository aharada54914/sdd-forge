/**
 * AC-017 (partial): files over the 2 MiB limit must yield `too-large`, and a
 * root lacking SDD structure (no AGENTS.md / specs/) must be detected by
 * isSddRoot() so callers can emit `not-sdd-root`.
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { guardedRead } from "../../src/path-guard.js";
import { isSddRoot } from "../../src/root.js";
import { makeTempSddRoot, makeTempPlainDir } from "../test-helpers.js";

const TWO_MIB = 2 * 1024 * 1024;

test("rejects a file larger than the 2 MiB limit with too-large", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-guard-toolarge");
  try {
    const oversizedContents = "a".repeat(TWO_MIB + 1);
    writeFileSync(join(root.path, "reports", "huge.md"), oversizedContents, "utf-8");

    const result = guardedRead(root, "reports/huge.md");
    assert.equal(result.ok, false);
    if (!result.ok) {
      assert.equal(result.error.code, "too-large");
    }
  } finally {
    cleanup();
  }
});

test("accepts a file exactly at the 2 MiB limit", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-guard-exactlimit");
  try {
    const exactContents = "a".repeat(TWO_MIB);
    writeFileSync(join(root.path, "reports", "exact.md"), exactContents, "utf-8");

    const result = guardedRead(root, "reports/exact.md");
    assert.equal(result.ok, true);
  } finally {
    cleanup();
  }
});

test("isSddRoot is false for a root missing both AGENTS.md and specs/", () => {
  const { dir, cleanup } = makeTempPlainDir("sdd-notroot-plain");
  try {
    const fakeRoot = Object.freeze({ path: dir, source: "cwd" as const });
    assert.equal(isSddRoot(fakeRoot), false);
  } finally {
    cleanup();
  }
});

test("isSddRoot is false when only specs/ exists without AGENTS.md", () => {
  const { dir, cleanup } = makeTempPlainDir("sdd-notroot-partial");
  try {
    mkdirSync(join(dir, "specs"), { recursive: true });
    const fakeRoot = Object.freeze({ path: dir, source: "cwd" as const });
    assert.equal(isSddRoot(fakeRoot), false);
  } finally {
    cleanup();
  }
});

test("isSddRoot is true for a properly-shaped SDD root", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-isroot-true");
  try {
    assert.equal(isSddRoot(root), true);
  } finally {
    cleanup();
  }
});
