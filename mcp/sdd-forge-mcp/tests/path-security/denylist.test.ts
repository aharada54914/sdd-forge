/**
 * AC-004: allowlist-external directories (plugins/, .git/) and denylisted
 * files (the SDD sudo flag file, .env, the evidence signing key) must never
 * be readable, and no response/details may leak their contents or the value
 * of any environment variable.
 *
 * The flag file name is a plain string literal here (test code, not a shell
 * command), matching the task instructions.
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { guardedRead } from "../../src/path-guard.js";
import { makeTempSddRoot } from "../test-helpers.js";

const FLAG_FILE_NAME = "SDD_SUDO";
const SECRET_MARKER = "top-secret-flag-contents-do-not-leak";

test("denies reads under a plugins/ directory that is not on the allowlist", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-guard-plugins");
  try {
    mkdirSync(join(root.path, "plugins", "some-plugin"), { recursive: true });
    writeFileSync(
      join(root.path, "plugins", "some-plugin", "script.sh"),
      "#!/bin/sh\necho hi\n",
      "utf-8",
    );
    const result = guardedRead(root, "plugins/some-plugin/script.sh");
    assert.equal(result.ok, false);
    if (!result.ok) {
      assert.equal(result.error.code, "path-denied");
    }
  } finally {
    cleanup();
  }
});

test("denies reads under a .git/ directory", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-guard-git");
  try {
    mkdirSync(join(root.path, ".git"), { recursive: true });
    writeFileSync(join(root.path, ".git", "config"), "[core]\n", "utf-8");
    const result = guardedRead(root, ".git/config");
    assert.equal(result.ok, false);
    if (!result.ok) {
      assert.equal(result.error.code, "path-denied");
    }
  } finally {
    cleanup();
  }
});

test("denies the SDD sudo flag file even when placed inside an allowlisted directory", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-guard-flagfile");
  try {
    writeFileSync(join(root.path, "reports", FLAG_FILE_NAME), SECRET_MARKER, "utf-8");
    const result = guardedRead(root, `reports/${FLAG_FILE_NAME}`);
    assert.equal(result.ok, false);
    if (!result.ok) {
      assert.equal(result.error.code, "path-denied");
      const serialized = JSON.stringify(result.error);
      assert.ok(!serialized.includes(SECRET_MARKER));
    }
  } finally {
    cleanup();
  }
});

test("denies .env files reached via an allowlisted directory", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-guard-dotenv");
  try {
    writeFileSync(join(root.path, "reports", ".env"), "SECRET=abc123", "utf-8");
    const result = guardedRead(root, "reports/.env");
    assert.equal(result.ok, false);
    if (!result.ok) {
      assert.equal(result.error.code, "path-denied");
      const serialized = JSON.stringify(result.error);
      assert.ok(!serialized.includes("abc123"));
    }
  } finally {
    cleanup();
  }
});

test("never includes file contents or the offending value in the denial message or details", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-guard-no-leak");
  try {
    writeFileSync(join(root.path, "reports", FLAG_FILE_NAME), SECRET_MARKER, "utf-8");
    const result = guardedRead(root, `reports/${FLAG_FILE_NAME}`);
    assert.equal(result.ok, false);
    if (!result.ok) {
      const serialized = JSON.stringify(result);
      assert.ok(!serialized.includes(SECRET_MARKER));
    }
  } finally {
    cleanup();
  }
});
