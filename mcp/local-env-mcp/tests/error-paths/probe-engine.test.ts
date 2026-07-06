/**
 * AC-004 (TEST-004): probe-engine error paths.
 *
 * Proves that a probe exceeding the 2s timeout or the 8 KiB output cap is
 * killed and reported as a per-entry failure (never a whole-response error),
 * and that successful / missing / nonzero-exit probes produce the correct
 * per-entry results. Uses fake CLI shims placed in a temp dir; the probe-engine
 * is pointed at them via a per-call PATH env override (test-only affordance).
 * User input can never reach the command/args — the engine still probes the
 * compile-time allowlist entries; only the PATH used to resolve them is
 * overridden for testability.
 *
 * NOTE: This test file is the only place that *creates* executable fixtures.
 * The src/ probe-engine performs no fs writes (enforced by AC-006 static test).
 */

import { test, before, after, beforeEach } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, writeFileSync, chmodSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { probeEngine, __clearProbeCache } from "../../src/probe-engine.js";
import type { AllowlistEntry } from "../../src/allowlist.js";

let fixtureDir: string;

/**
 * Writes an executable POSIX shell shim named `name` into fixtureDir.
 *
 * On win32, `execFile` resolves a bare command by searching each PATH
 * directory for `PATHEXT` matches (`.EXE`, `.CMD`, ...); an extension-less
 * file is invisible to that search and probing silently falls through to a
 * same-named binary elsewhere on the real PATH. So on win32 we additionally
 * drop a `<name>.cmd` launcher that PATHEXT resolution *can* find, which
 * hands off to the CI-guaranteed Git-for-Windows `bash` to run the identical
 * POSIX body — no shell-syntax translation, so cross-platform behavior stays
 * byte-for-byte the same.
 */
function writeShim(name: string, body: string): void {
  const p = join(fixtureDir, name);
  writeFileSync(p, `#!/bin/sh\n${body}\n`, "utf-8");
  chmodSync(p, 0o755);
  if (process.platform === "win32") {
    const cmdPath = join(fixtureDir, `${name}.cmd`);
    writeFileSync(cmdPath, `@echo off\r\nbash "%~dp0${name}" %*\r\n`, "utf-8");
  }
}

before(() => {
  fixtureDir = mkdtempSync(join(tmpdir(), "local-env-mcp-probe-"));

  // Fast, well-behaved CLI: prints a version line on stdout and exits 0.
  writeShim("goodcli", 'echo "goodcli 9.9.9 (build abc)"');

  // Multi-line output: only the first line, trimmed, <=200 chars, must be kept.
  writeShim("multiline", 'printf "first-line 1.0.0\\nSECOND LINE SHOULD BE DROPPED\\n"');

  // stderr-only version output (mimics `java -version`).
  writeShim("stderrcli", '>&2 echo "stderrcli 17.0.1"; exit 0');

  // Slow CLI: sleeps well past the 2s timeout, then would print. Must be killed
  // and reported as probeError "timeout".
  writeShim("slowcli", 'sleep 30; echo "too-late 1.0.0"');

  // Verbose CLI: emits far more than 8 KiB on stdout. Must be capped + killed
  // and reported as probeError "output-too-large".
  writeShim(
    "verbosecli",
    // ~50 KiB: 512 iterations of a 100-char line.
    'i=0; line=$(printf "%0.sX" $(seq 1 100)); while [ "$i" -lt 512 ]; do echo "$line"; i=$((i+1)); done',
  );

  // Nonzero-exit CLI: prints nothing useful and exits 3.
  writeShim("failcli", 'exit 3');
});

after(() => {
  rmSync(fixtureDir, { recursive: true, force: true });
});

// The probe-engine cache is module-level; clear it before each test so results
// are deterministic regardless of test execution order.
beforeEach(() => {
  __clearProbeCache();
});

/** Builds a single-entry allowlist-shaped probe target for testing. */
function entry(name: string, command: string, versionStream: "stdout" | "stderr" = "stdout"): AllowlistEntry {
  return { name: name as AllowlistEntry["name"], command, args: ["--version"], versionStream };
}

test("AC-004: successful probe yields available + normalized first-line version", async () => {
  const results = await probeEngine([entry("node", "goodcli")], { pathOverride: fixtureDir });
  assert.equal(results.length, 1);
  const r = results[0]!;
  assert.equal(r.name, "node");
  assert.equal(r.available, true);
  assert.equal(r.version, "goodcli 9.9.9 (build abc)");
  assert.equal(r.probeError, undefined);
});

test("AC-004: multi-line output is normalized to first line only", async () => {
  const results = await probeEngine([entry("git", "multiline")], { pathOverride: fixtureDir });
  const r = results[0]!;
  assert.equal(r.available, true);
  assert.equal(r.version, "first-line 1.0.0");
  assert.ok(!r.version!.includes("SECOND"), "second line must be dropped");
});

test("AC-004: stderr-stream CLI (java-style) reads version from stderr", async () => {
  const results = await probeEngine([entry("java", "stderrcli", "stderr")], { pathOverride: fixtureDir });
  const r = results[0]!;
  assert.equal(r.available, true);
  assert.equal(r.version, "stderrcli 17.0.1");
});

test("AC-004: timeout (>2s) kills the process and reports probeError=timeout", async () => {
  const start = Date.now();
  const results = await probeEngine([entry("go", "slowcli")], { pathOverride: fixtureDir });
  const elapsed = Date.now() - start;
  const r = results[0]!;
  assert.equal(r.available, false);
  assert.equal(r.probeError, "timeout");
  assert.equal(r.version, undefined);
  // Must have been killed near the 2s bound, not after the 30s sleep.
  assert.ok(elapsed < 10_000, `probe should be killed near timeout, took ${elapsed}ms`);
});

test("AC-004: output over 8 KiB is capped, process killed, probeError=output-too-large", async () => {
  const results = await probeEngine([entry("rustc", "verbosecli")], { pathOverride: fixtureDir });
  const r = results[0]!;
  assert.equal(r.available, false);
  assert.equal(r.probeError, "output-too-large");
  assert.equal(r.version, undefined);
});

test("AC-004: missing CLI reports probeError=not-found (spawn ENOENT)", async () => {
  const results = await probeEngine([entry("bun", "definitely-not-a-real-binary-xyz")], { pathOverride: fixtureDir });
  const r = results[0]!;
  assert.equal(r.available, false);
  assert.equal(r.probeError, "not-found");
});

test("AC-004: nonzero exit reports probeError=nonzero-exit", async () => {
  const results = await probeEngine([entry("deno", "failcli")], { pathOverride: fixtureDir });
  const r = results[0]!;
  assert.equal(r.available, false);
  assert.equal(r.probeError, "nonzero-exit");
});

test("AC-004: probeError values are all within the contract enum", async () => {
  const contractEnum = new Set([
    "not-found",
    "timeout",
    "output-too-large",
    "nonzero-exit",
    "spawn-error",
  ]);
  const results = await probeEngine(
    [
      entry("node", "goodcli"),
      entry("go", "slowcli"),
      entry("rustc", "verbosecli"),
      entry("bun", "missing-xyz"),
      entry("deno", "failcli"),
    ],
    { pathOverride: fixtureDir },
  );
  for (const r of results) {
    if (r.probeError !== undefined) {
      assert.ok(contractEnum.has(r.probeError), `probeError "${r.probeError}" must be in contract enum`);
    }
  }
});

test("AC-004: concurrency is bounded (many slow probes still all resolve, none hang the response)", async () => {
  // Six slow probes with a concurrency cap of 4 must all still resolve to
  // per-entry timeout failures; the whole response stays well-formed.
  const entries = Array.from({ length: 6 }, (_, i) => entry(["node", "npm", "git", "gh", "go", "cargo"][i]!, "slowcli"));
  const results = await probeEngine(entries, { pathOverride: fixtureDir });
  assert.equal(results.length, 6);
  for (const r of results) {
    assert.equal(r.available, false);
    assert.equal(r.probeError, "timeout");
  }
});

test("AC-004: TTL cache reuses a prior result within the window (no re-probe)", async () => {
  const first = await probeEngine([entry("cargo", "goodcli")], { pathOverride: fixtureDir });
  assert.equal(first[0]!.available, true);
  // Second call within TTL: even pointing at a now-different shim path, the
  // cached per-entry result for "cargo" is reused (proving in-memory caching).
  const second = await probeEngine([entry("cargo", "failcli")], { pathOverride: fixtureDir });
  assert.equal(second[0]!.available, true, "cached result should be reused within TTL");
  assert.equal(second[0]!.version, "goodcli 9.9.9 (build abc)");
});
