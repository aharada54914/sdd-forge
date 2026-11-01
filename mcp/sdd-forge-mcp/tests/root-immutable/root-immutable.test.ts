/**
 * AC-016: the resolved root is fixed once at startup. Changing
 * process.env.SDD_FORGE_ROOT or process.cwd() afterwards must not affect the
 * already-resolved root object.
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import { tmpdir } from "node:os";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { resolveRoot } from "../../src/root.js";
import { makeTempSddRoot } from "../test-helpers.js";

test("resolved root is frozen and immutable after construction", () => {
  const { root, cleanup } = makeTempSddRoot("sdd-root-frozen");
  try {
    assert.ok(Object.isFrozen(root));
    assert.throws(() => {
      // @ts-expect-error intentionally attempting a mutation for the test
      root.path = "/somewhere-else";
    });
  } finally {
    cleanup();
  }
});

test("changing SDD_FORGE_ROOT after resolution does not affect the already-resolved root", () => {
  const first = makeTempSddRoot("sdd-root-env-a");
  const second = makeTempSddRoot("sdd-root-env-b");
  try {
    const resolved = resolveRoot([], { SDD_FORGE_ROOT: first.dir }, "/nonexistent-cwd");
    assert.equal(resolved.path, first.root.path);

    // Mutating the real process env after the fact must not retroactively
    // change a value that was already captured.
    const originalEnvValue = process.env.SDD_FORGE_ROOT;
    process.env.SDD_FORGE_ROOT = second.dir;
    try {
      assert.equal(resolved.path, first.root.path);
    } finally {
      if (originalEnvValue === undefined) {
        delete process.env.SDD_FORGE_ROOT;
      } else {
        process.env.SDD_FORGE_ROOT = originalEnvValue;
      }
    }
  } finally {
    first.cleanup();
    second.cleanup();
  }
});

test("changing cwd after resolution does not affect the already-resolved root", () => {
  const tempRoot = makeTempSddRoot("sdd-root-cwd");
  try {
    const resolved = resolveRoot([], {}, tempRoot.dir);
    assert.equal(resolved.path, tempRoot.root.path);

    const originalCwd = process.cwd();
    process.chdir(tmpdir());
    try {
      assert.equal(resolved.path, tempRoot.root.path);
    } finally {
      process.chdir(originalCwd);
    }
  } finally {
    tempRoot.cleanup();
  }
});

test("CLI --root takes precedence over SDD_FORGE_ROOT and cwd", () => {
  const cliRoot = makeTempSddRoot("sdd-root-cli");
  const envRoot = makeTempSddRoot("sdd-root-cli-env");
  try {
    const resolved = resolveRoot(
      ["--root", cliRoot.dir],
      { SDD_FORGE_ROOT: envRoot.dir },
      "/nonexistent-cwd",
    );
    assert.equal(resolved.path, cliRoot.root.path);
    assert.equal(resolved.source, "cli");
  } finally {
    cliRoot.cleanup();
    envRoot.cleanup();
  }
});

test("SDD_FORGE_ROOT takes precedence over cwd when no CLI flag is given", () => {
  const envRoot = makeTempSddRoot("sdd-root-env-precedence");
  try {
    const resolved = resolveRoot([], { SDD_FORGE_ROOT: envRoot.dir }, "/nonexistent-cwd");
    assert.equal(resolved.path, envRoot.root.path);
    assert.equal(resolved.source, "env");
  } finally {
    envRoot.cleanup();
  }
});

test("falls back to cwd when neither --root nor SDD_FORGE_ROOT is set", () => {
  const cwdRoot = makeTempSddRoot("sdd-root-cwd-fallback");
  try {
    const resolved = resolveRoot([], {}, cwdRoot.dir);
    assert.equal(resolved.path, cwdRoot.root.path);
    assert.equal(resolved.source, "cwd");
  } finally {
    cwdRoot.cleanup();
  }
});

 test("unknown CLI options and missing root values fail before cwd fallback", () => {
  for (const args of [["--unknown"], ["positional"], ["--root"], ["--root", "--status-ui"]]) {
    assert.throws(() => resolveRoot(args, {}, process.cwd()));
  }
});

 test("stdio entry rejects unknown options without protocol stdout", () => {
  const entry = fileURLToPath(new URL("../../../dist/index.js", import.meta.url));
  const result = spawnSync(process.execPath, [entry, "--unknown"], { encoding: "utf8", timeout: 5000 });
  assert.equal(result.status, 1);
  assert.equal(result.stdout, "");
  assert.match(result.stderr, /Unknown option/);
});
