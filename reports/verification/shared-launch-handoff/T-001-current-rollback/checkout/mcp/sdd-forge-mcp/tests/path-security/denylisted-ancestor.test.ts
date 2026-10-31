import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdirSync, realpathSync } from "node:fs";
import { join } from "node:path";
import {
  guardedRead,
  listGuardedFilesWithDiagnostics,
} from "../../src/path-guard.js";
import {
  makeSymlink,
  makeTempPlainDir,
  makeTempSddRoot,
  writeFile,
} from "../test-helpers.js";

const SECRET_MARKER = "denylisted-ancestor-secret-must-not-leak";

test("guardedRead denies a regular file beneath a denylisted ancestor directory", () => {
  const { root, cleanup } = makeTempSddRoot("denylisted-ancestor-read");
  try {
    writeFile(root.path, "reports/.env/nested/secret-name.txt", SECRET_MARKER);

    const result = guardedRead(root, "reports/.env/nested/secret-name.txt");

    assert.equal(result.ok, false);
    if (!result.ok) {
      assert.equal(result.error.code, "path-denied");
      assert.equal(result.error.message, "Path matches a denylisted file.");
      assert.doesNotMatch(JSON.stringify(result), new RegExp(SECRET_MARKER));
    }
  } finally {
    cleanup();
  }
});

test("recursive listing denies a requested directory beneath a denylisted ancestor", () => {
  const { root, cleanup } = makeTempSddRoot("denylisted-ancestor-direct-list");
  try {
    writeFile(root.path, "reports/.env/nested/secret-name.txt", SECRET_MARKER);

    const result = listGuardedFilesWithDiagnostics(root, "reports/.env/nested");

    assert.deepEqual(result.files, []);
    assert.deepEqual(result.errors, [
      {
        path: "reports/.env/nested",
        reason: "Path matches a denylisted file.",
      },
    ]);
    assert.doesNotMatch(
      JSON.stringify(result),
      /secret-name\.txt|denylisted-ancestor-secret-must-not-leak/,
    );
  } finally {
    cleanup();
  }
});

test("recursive listing denies a safe-looking symlink whose target is beneath a denylisted ancestor", (t) => {
  const { root, cleanup } = makeTempSddRoot("denylisted-ancestor-list");
  try {
    writeFile(root.path, "reports/.env/nested/secret-name.txt", SECRET_MARKER);
    writeFile(root.path, "reports/public/visible.txt", "visible\n");
    try {
      makeSymlink(
        join(root.path, "reports", ".env", "nested"),
        join(root.path, "reports", "public", "safe-looking-alias"),
      );
    } catch (error) {
      t.skip(`host refused to create a symlink: ${String(error)}`);
      return;
    }

    const result = listGuardedFilesWithDiagnostics(root, "reports/public");

    assert.deepEqual(result.files, ["reports/public/visible.txt"]);
    assert.deepEqual(result.errors, [
      {
        path: "reports/public/safe-looking-alias",
        reason: "Path matches a denylisted file.",
      },
    ]);
    assert.doesNotMatch(
      JSON.stringify(result),
      /secret-name\.txt|denylisted-ancestor-secret-must-not-leak/,
    );
  } finally {
    cleanup();
  }
});

test("guardedRead preserves the denylisted lexical name when it is a symlink to an allowed target", (t) => {
  const { root, cleanup } = makeTempSddRoot("denylisted-lexical-read");
  try {
    writeFile(root.path, "reports/public-target/visible.txt", "visible\n");
    try {
      makeSymlink(
        join(root.path, "reports", "public-target"),
        join(root.path, "reports", ".env"),
      );
    } catch (error) {
      t.skip(`host refused to create a symlink: ${String(error)}`);
      return;
    }

    const result = guardedRead(root, "reports/.env/visible.txt");

    assert.equal(result.ok, false);
    if (!result.ok) {
      assert.equal(result.error.code, "path-denied");
      assert.equal(result.error.message, "Path matches a denylisted file.");
    }
  } finally {
    cleanup();
  }
});

test("recursive listing preserves a denylisted lexical directory name that aliases an allowed target", (t) => {
  const { root, cleanup } = makeTempSddRoot("denylisted-lexical-list");
  try {
    writeFile(root.path, "reports/public-target/visible.txt", "visible\n");
    try {
      makeSymlink(
        join(root.path, "reports", "public-target"),
        join(root.path, "reports", ".env"),
      );
    } catch (error) {
      t.skip(`host refused to create a symlink: ${String(error)}`);
      return;
    }

    const result = listGuardedFilesWithDiagnostics(root, "reports/.env");

    assert.deepEqual(result.files, []);
    assert.deepEqual(result.errors, [
      {
        path: "reports/.env",
        reason: "Path matches a denylisted file.",
      },
    ]);
  } finally {
    cleanup();
  }
});

test("denylist matching ignores components above the project root", () => {
  const { dir, cleanup } = makeTempPlainDir("denylisted-root-boundary");
  try {
    const projectDir = join(dir, ".env", "project");
    mkdirSync(projectDir, { recursive: true });
    writeFile(projectDir, "reports/ok.txt", "allowed\n");
    const root = Object.freeze({ path: realpathSync(projectDir), source: "cwd" as const });

    const result = guardedRead(root, "reports/ok.txt");

    assert.equal(result.ok, true);
    if (result.ok) {
      assert.equal(result.data.contents, "allowed\n");
    }
  } finally {
    cleanup();
  }
});
