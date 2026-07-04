/**
 * AC-003: path traversal (`..`, absolute paths, symlinks resolving outside
 * the allowlist) must be rejected with `path-denied` / `invalid-input`,
 * fail-closed.
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { guardedRead, resolveGuarded } from "../../src/path-guard.js";
import { makeTempSddRoot, makeSymlink, makeTempPlainDir } from "../test-helpers.js";

test("rejects a relative path containing a parent traversal segment", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-guard-traversal");
  try {
    const result = guardedRead(root, "specs/../../etc/passwd");
    assert.equal(result.ok, false);
    if (!result.ok) {
      assert.equal(result.error.code, "path-denied");
    }
  } finally {
    cleanup();
  }
});

test("rejects an absolute path argument outright", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-guard-absolute");
  try {
    const result = guardedRead(root, "/etc/passwd");
    assert.equal(result.ok, false);
    if (!result.ok) {
      assert.equal(result.error.code, "path-denied");
    }
  } finally {
    cleanup();
  }
});

test("rejects an empty path as invalid input", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-guard-empty");
  try {
    const result = guardedRead(root, "");
    assert.equal(result.ok, false);
    if (!result.ok) {
      assert.equal(result.error.code, "invalid-input");
    }
  } finally {
    cleanup();
  }
});

test("rejects a path argument containing backslashes", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-guard-backslash");
  try {
    const result = guardedRead(root, "specs\\..\\..\\etc\\passwd");
    assert.equal(result.ok, false);
    if (!result.ok) {
      assert.equal(result.error.code, "path-denied");
    }
  } finally {
    cleanup();
  }
});

test("rejects a symlink inside the allowlist that resolves outside it", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-guard-symlink");
  const { dir: outsideDir, cleanup: cleanupOutside } = makeTempPlainDir(
    "sdd-guard-symlink-target",
  );
  try {
    const secretPath = join(outsideDir, "secret.txt");
    writeFileSync(secretPath, "outside-allowlist-content", "utf-8");

    const linkPath = join(root.path, "specs", "escape-link");
    makeSymlink(secretPath, linkPath);

    const result = guardedRead(root, "specs/escape-link");
    assert.equal(result.ok, false);
    if (!result.ok) {
      assert.equal(result.error.code, "path-denied");
    }
  } finally {
    cleanup();
    cleanupOutside();
  }
});

test("resolveGuarded rejects the same traversal shapes without reading contents", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-guard-resolve-only");
  try {
    const result = resolveGuarded(root, "../outside");
    assert.equal(result.ok, false);
    if (!result.ok) {
      assert.equal(result.error.code, "path-denied");
    }
  } finally {
    cleanup();
  }
});

test("allows a legitimate allowlisted file to be read", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-guard-allow");
  try {
    mkdirSync(join(root.path, "specs", "demo-feature"), { recursive: true });
    writeFileSync(
      join(root.path, "specs", "demo-feature", "tasks.md"),
      "# Tasks\n",
      "utf-8",
    );
    const result = guardedRead(root, "specs/demo-feature/tasks.md");
    assert.equal(result.ok, true);
    if (result.ok) {
      assert.equal(result.data.contents, "# Tasks\n");
    }
  } finally {
    cleanup();
  }
});
