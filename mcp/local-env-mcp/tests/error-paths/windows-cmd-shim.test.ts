/**
 * AC-004 (Windows): cmd.exe fallback for `.cmd` / `.bat` shim CLIs.
 *
 * On Windows, npm / pnpm / yarn ship as `.cmd` shims. libuv's PATH search for
 * a bare command name only ever tries `.exe` / `.com`, and Node >= 20.12
 * refuses to spawn an explicit `.cmd` / `.bat` path without a shell
 * (CVE-2024-27980, a synchronous EINVAL throw). The probe-engine therefore
 * falls back on win32: it resolves `<command>.cmd` / `<command>.bat` against
 * the effective PATH itself (read-only fs), then launches
 * `%ComSpec% /d /s /c ""<resolved>" <fixed args>"` with
 * windowsVerbatimArguments. The resolved path comes from the environment's
 * PATH and the args stay the compile-time allowlist constants — no user input
 * reaches cmd.exe (ADR-0004). A resolved path containing characters that are
 * unsafe inside a cmd.exe quoted string (`"`, `%`, newlines) is refused and
 * reported as spawn-error instead of being executed.
 *
 * These tests are win32-only; POSIX behavior is pinned by the sibling
 * probe-engine.test.ts. This file is a permitted executable-fixture writer
 * (src/ itself performs no fs writes — AC-006 static test).
 */

import { test, before, after, beforeEach } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { probeEngine, __clearProbeCache } from "../../src/probe-engine.js";
import type { AllowlistEntry } from "../../src/allowlist.js";

const IS_WINDOWS = process.platform === "win32";
const SKIP = IS_WINDOWS ? false : "win32-only: exercises the cmd.exe shim fallback";

let fixtureDir: string;
let spacedDir: string;
let hostileDir: string;
let metaDir: string;

/** Writes a native batch fixture (CRLF line endings, no bash dependency). */
function writeBatch(dir: string, fileName: string, lines: string[]): void {
  writeFileSync(join(dir, fileName), `@echo off\r\n${lines.join("\r\n")}\r\n`, "utf-8");
}

before(() => {
  if (!IS_WINDOWS) {
    return;
  }
  fixtureDir = mkdtempSync(join(tmpdir(), "local-env-mcp-cmdshim-"));

  // A CLI that exists ONLY as a .cmd shim (like real npm/pnpm/yarn).
  writeBatch(fixtureDir, "shimonly.cmd", ['echo shimonly 3.2.1 (win)']);

  // Echoes its first argument so the test can prove the fixed allowlist args
  // survive the cmd.exe hop verbatim.
  writeBatch(fixtureDir, "argecho.cmd", ["echo args:%1"]);

  // A CLI that exists only as a .bat.
  writeBatch(fixtureDir, "batonly.bat", ["echo batonly 0.1.0"]);

  // Exits nonzero without printing a version.
  writeBatch(fixtureDir, "shimfail.cmd", ["exit /b 3"]);

  // Sleeps ~30s (ping-as-sleep: works without stdin, unlike timeout.exe),
  // then would print. Must be killed near the 2s probe timeout.
  writeBatch(fixtureDir, "slowshim.cmd", ["ping -n 31 127.0.0.1 > nul", "echo too-late 1.0.0"]);

  // A shim inside a directory whose name contains spaces (quoting coverage —
  // the real-world npm location is `C:\Program Files\nodejs\npm.cmd`).
  spacedDir = join(fixtureDir, "dir with spaces");
  mkdirSync(spacedDir);
  writeBatch(spacedDir, "spacedcli.cmd", ["echo spacedcli 2.0.0"]);

  // A shim inside a directory containing `%` — unsafe inside a cmd.exe quoted
  // string (percent expansion happens even inside quotes). Must be refused,
  // never executed.
  hostileDir = join(fixtureDir, "pct%hostile%");
  mkdirSync(hostileDir);
  writeBatch(hostileDir, "evilcli.cmd", ["echo evilcli 6.6.6"]);

  // A directory whose name combines legal-but-scary cmd.exe metacharacters
  // (`&`, `(`, `)`, `,`, `=`, spaces — `;` is excluded because a PATH segment
  // cannot carry an unquoted `;` at all). These are all inert INSIDE the
  // engine's `""<path>" <args>"` quoted construction; this fixture pins that
  // quoting invariant so a future change to the command-line construction
  // cannot silently turn them into an injection primitive. The shim echoes
  // its first arg: any quote-breaking would corrupt the echo.
  metaDir = join(fixtureDir, "AT&T (test) a=b, dir");
  mkdirSync(metaDir);
  writeBatch(metaDir, "metacli.cmd", ["echo meta-ok:%1"]);
});

after(() => {
  if (!IS_WINDOWS) {
    return;
  }
  rmSync(fixtureDir, { recursive: true, force: true });
});

beforeEach(() => {
  __clearProbeCache();
});

/** Builds a single-entry allowlist-shaped probe target for testing. */
function entry(name: string, command: string): AllowlistEntry {
  return { name: name as AllowlistEntry["name"], command, args: ["--version"], versionStream: "stdout" };
}

test("win32: a .cmd-only CLI is probed via the cmd.exe fallback", { skip: SKIP }, async () => {
  const results = await probeEngine([entry("npm", "shimonly")], { pathOverride: fixtureDir });
  const r = results[0]!;
  assert.equal(r.available, true);
  assert.equal(r.version, "shimonly 3.2.1 (win)");
  assert.equal(r.probeError, undefined);
});

test("win32: the fixed allowlist args reach the shim unchanged through cmd.exe", { skip: SKIP }, async () => {
  const results = await probeEngine([entry("pnpm", "argecho")], { pathOverride: fixtureDir });
  const r = results[0]!;
  assert.equal(r.available, true);
  assert.equal(r.version, "args:--version");
});

test("win32: a .bat-only CLI is also probed via the fallback", { skip: SKIP }, async () => {
  const results = await probeEngine([entry("yarn", "batonly")], { pathOverride: fixtureDir });
  const r = results[0]!;
  assert.equal(r.available, true);
  assert.equal(r.version, "batonly 0.1.0");
});

test("win32: a shim in a directory with spaces is quoted correctly", { skip: SKIP }, async () => {
  const results = await probeEngine([entry("node", "spacedcli")], { pathOverride: spacedDir });
  const r = results[0]!;
  assert.equal(r.available, true);
  assert.equal(r.version, "spacedcli 2.0.0");
});

test("win32: a resolved path containing % is refused (spawn-error), never executed", { skip: SKIP }, async () => {
  const results = await probeEngine([entry("deno", "evilcli")], { pathOverride: hostileDir });
  const r = results[0]!;
  assert.equal(r.available, false);
  assert.equal(r.probeError, "spawn-error");
  assert.equal(r.version, undefined, "the shim must not run and must not yield a version");
});

test("win32: & ( ) , = and spaces in the resolved path stay inert inside the quoted construction", { skip: SKIP }, async () => {
  const results = await probeEngine([entry("gh", "metacli")], { pathOverride: metaDir });
  const r = results[0]!;
  assert.equal(r.available, true, "a legal path with cmd metacharacters must still probe");
  assert.equal(r.version, "meta-ok:--version", "args must arrive unbroken — no quote escape, no injection");
});

test("win32: nonzero shim exit maps to probeError=nonzero-exit through the fallback", { skip: SKIP }, async () => {
  const results = await probeEngine([entry("go", "shimfail")], { pathOverride: fixtureDir });
  const r = results[0]!;
  assert.equal(r.available, false);
  assert.equal(r.probeError, "nonzero-exit");
});

test("win32: a hung shim is killed near the 2s bound (grandchild cannot stall the probe)", { skip: SKIP }, async () => {
  const start = Date.now();
  const results = await probeEngine([entry("cargo", "slowshim")], { pathOverride: fixtureDir });
  const elapsed = Date.now() - start;
  const r = results[0]!;
  assert.equal(r.available, false);
  assert.equal(r.probeError, "timeout");
  assert.ok(elapsed < 10_000, `probe should be killed near timeout, took ${elapsed}ms`);
});

test("win32: a command with no .cmd/.bat anywhere on PATH is still not-found", { skip: SKIP }, async () => {
  const results = await probeEngine([entry("bun", "definitely-not-a-real-shim-xyz")], { pathOverride: fixtureDir });
  const r = results[0]!;
  assert.equal(r.available, false);
  assert.equal(r.probeError, "not-found");
});
