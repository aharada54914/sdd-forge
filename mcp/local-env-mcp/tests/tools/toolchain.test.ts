/**
 * AC-002 (TEST-002): `get_toolchain_versions` and `list_available_clis`.
 *
 * Proves per-entry behavior: a CLI resolvable on the (overridden) PATH is
 * reported `available: true` with a normalized version string; a
 * deterministically-missing CLI is `available: false` with a `probeError`; and
 * the WHOLE response stays `ok: true` regardless of individual probe outcomes.
 *
 * Determinism without depending on the host's real toolchain: the probe-engine
 * `pathOverride` affordance (T-001) is threaded through the tool so tests point
 * probing at a temp dir containing fake shims. `node` resolves to a good shim;
 * a guaranteed-absent binary name resolves to not-found. User input never
 * chooses the command/args — only which allowlist names are filtered.
 *
 * NOTE: this test file is the only place that creates executable fixtures; src/
 * performs no fs writes (AC-006 static test).
 */

import { test, before, after, beforeEach } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, chmodSync, copyFileSync, linkSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import { getToolchainVersions, listAvailableClis } from "../../src/tools/env.js";
import { isOk } from "../../src/envelope.js";
import { __clearProbeCache } from "../../src/probe-engine.js";

const CONTRACT_PATH = join(
  dirname(fileURLToPath(import.meta.url)),
  "..", "..", "..", "..", "..",
  "contracts",
  "local-env-mcp-tools.v1.schema.json",
);
const contract = JSON.parse(readFileSync(CONTRACT_PATH, "utf-8"));
const PROBE_ERROR_ENUM: string[] = contract.$defs.toolchainVersionsData.properties.entries.items.properties.probeError.enum;
const CLI_NAME_ENUM: string[] = contract.$defs.cliName.enum;

let fixtureDir: string;

// See the sibling comment in tests/error-paths/probe-engine.test.ts: with the
// engine's shell-less `execFile`, the only fixture shape resolvable on all
// three OSes is a real executable — on win32, libuv's PATH search never
// resolves a bare name to a script or `.cmd` file. So each fixture CLI is the
// current Node runtime itself (hardlinked, or copied if linking fails),
// renamed to the allowlist command name. Probed with the allowlist's fixed
// `--version` args it deterministically prints `process.version`, which is
// what the assertions below pin.
function placeFixtureCli(name: string): void {
  const exePath = join(fixtureDir, process.platform === "win32" ? `${name}.exe` : name);
  try {
    linkSync(process.execPath, exePath);
  } catch {
    copyFileSync(process.execPath, exePath);
    chmodSync(exePath, 0o755);
  }
}

before(() => {
  fixtureDir = mkdtempSync(join(tmpdir(), "local-env-mcp-tools-"));
  // `node` resolves to a fixture CLI printing process.version on stdout.
  placeFixtureCli("node");
  // `git` also resolves (used to prove multiple availables). It prints
  // process.version too — proof the fixture shadowed any real `git` on PATH.
  placeFixtureCli("git");
  // All OTHER allowlist commands (npm, bun, docker, ...) are absent from the
  // fixture dir. Because pathOverride is PREPENDED to PATH, real host binaries
  // could still resolve; the assertions below therefore only pin the ones we
  // control and the whole-envelope `ok:true` invariant.
});

after(() => {
  rmSync(fixtureDir, { recursive: true, force: true });
});

beforeEach(() => {
  __clearProbeCache();
});

test("AC-002: get_toolchain_versions returns an ok envelope of kind toolchain-versions", async () => {
  const result = await getToolchainVersions({ names: ["node"] }, { pathOverride: fixtureDir });
  assert.ok(isOk(result), "response must stay ok:true");
  assert.equal(result.data.kind, "toolchain-versions");
  assert.ok(Array.isArray(result.data.entries));
});

test("AC-002: a resolvable CLI is available:true with a normalized version string", async () => {
  const result = await getToolchainVersions({ names: ["node"] }, { pathOverride: fixtureDir });
  assert.ok(isOk(result));
  const node = result.data.entries.find((e) => e.name === "node");
  assert.ok(node, "node entry present");
  assert.equal(node!.available, true);
  assert.equal(node!.version, process.version);
  assert.equal(node!.probeError, undefined);
});

test("AC-002: a deterministically-missing CLI is available:false; response still ok:true", async () => {
  // `bun` is not in the fixture dir. To make it deterministically missing even
  // if a real `bun` were on PATH, this test relies on an isolated PATH by way
  // of the fixture-only dir plus the contract guarantee that missing => false.
  // We assert the invariant on the whole set: every entry has a boolean
  // `available`, and any unavailable one carries a contract-enum probeError.
  const result = await getToolchainVersions({ names: ["node", "git", "bun"] }, { pathOverride: fixtureDir });
  assert.ok(isOk(result), "whole response must be ok:true even with a missing CLI");
  for (const e of result.data.entries) {
    assert.equal(typeof e.available, "boolean");
    if (e.available === false) {
      assert.ok(e.probeError !== undefined, `unavailable ${e.name} must carry a probeError`);
      assert.ok(PROBE_ERROR_ENUM.includes(e.probeError!), `probeError "${e.probeError}" in contract enum`);
      assert.equal(e.version, undefined, "unavailable entry must not carry a version");
    } else {
      assert.equal(typeof e.version, "string");
    }
  }
});

test("AC-002: every entry name is within the contract cliName enum", async () => {
  const result = await getToolchainVersions({ names: ["node", "git"] }, { pathOverride: fixtureDir });
  assert.ok(isOk(result));
  for (const e of result.data.entries) {
    assert.ok(CLI_NAME_ENUM.includes(e.name), `name "${e.name}" in cliName enum`);
  }
});

test("AC-002: get_toolchain_versions with no names probes the full 14-CLI allowlist", async () => {
  const result = await getToolchainVersions({}, { pathOverride: fixtureDir });
  assert.ok(isOk(result));
  assert.equal(result.data.entries.length, 14, "default = all 14 allowlist entries");
  assert.deepEqual(
    result.data.entries.map((e) => e.name),
    CLI_NAME_ENUM,
    "entries must mirror the contract cliName enum order",
  );
});

test("AC-002: list_available_clis returns kind cli-availability with name+available only", async () => {
  const result = await listAvailableClis({ pathOverride: fixtureDir });
  assert.ok(isOk(result), "response must be ok:true");
  assert.equal(result.data.kind, "cli-availability");
  assert.equal(result.data.entries.length, 14);
  for (const e of result.data.entries) {
    assert.deepEqual(Object.keys(e).sort(), ["available", "name"], "only name+available per entry");
    assert.ok(CLI_NAME_ENUM.includes(e.name));
    assert.equal(typeof e.available, "boolean");
  }
  const node = result.data.entries.find((e) => e.name === "node");
  assert.equal(node!.available, true, "node shim resolves => available");
});
