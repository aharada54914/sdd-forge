/**
 * AC-005: MCP Inspector CLI smoke test. Runs the real, bundled
 * `dist/index.js` server through `@modelcontextprotocol/inspector --cli`
 * (a separate process talking real stdio JSON-RPC, not the SDK's in-memory
 * transport used by every other suite) and asserts `tools/list`,
 * `resources/list`, and a representative `tools/call` all succeed. No
 * network access is required — the inspector CLI drives a local stdio
 * subprocess only.
 *
 * `dist/index.js` must exist before this suite runs; if it does not
 * (e.g. a fresh checkout before `npm run build` has been invoked), this
 * suite builds it once via `npm run build` rather than skipping — per task
 * instructions, the smoke test must actually run, not be silently skipped.
 */

import { test, before } from "node:test";
import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import {
  CallToolResultSchema, ListResourcesResultSchema, ListResourceTemplatesResultSchema, ListToolsResultSchema,
} from "@modelcontextprotocol/sdk/types.js";
import type { Result } from "../../src/envelope.js";
import type { ProjectOverviewData } from "../../src/tools/v2.js";
import { getV2DefValidator, parseEnvelope } from "../core-tools/test-helpers.js";

const THIS_FILE_DIR = dirname(fileURLToPath(import.meta.url));

/** Walks upward from this compiled test file to find the sdd-forge-mcp package root (identified by package.json). */
function findPackageRoot(startDir: string): string {
  let dir = startDir;
  for (let i = 0; i < 10; i += 1) {
    if (existsSync(join(dir, "package.json")) && existsSync(join(dir, "src", "index.ts"))) {
      return dir;
    }
    const parent = dirname(dir);
    if (parent === dir) {
      break;
    }
    dir = parent;
  }
  throw new Error(`Could not locate the sdd-forge-mcp package root above ${startDir}`);
}

const PACKAGE_ROOT = findPackageRoot(THIS_FILE_DIR);
const DIST_ENTRYPOINT = join(PACKAGE_ROOT, "dist", "index.js");
const SDD_FORGE_REPO_ROOT = dirname(dirname(PACKAGE_ROOT));

const require = createRequire(import.meta.url);

/**
 * Absolute path to the inspector's executable entry script, read from the
 * `bin` field of the package's own manifest rather than hard-coded to one
 * release's layout: the script sits at `cli/build/cli.js` in inspector 0.x
 * and at `clients/launcher/build/index.js` in 2.x, and both accept the
 * leading `--cli` flag this suite passes. Spawning it with
 * `process.execPath` (instead of `npx`) keeps the invocation portable:
 * Windows has no `npx` executable — only an `npx.cmd` shim that
 * `spawnSync` cannot start without a shell.
 */
function resolveInspectorCliEntrypoint(): string {
  const manifestPath = require.resolve("@modelcontextprotocol/inspector/package.json");
  const { bin } = JSON.parse(readFileSync(manifestPath, "utf-8")) as {
    bin?: string | Record<string, string | undefined>;
  };
  const binRelativePath = typeof bin === "string" ? bin : bin?.["mcp-inspector"];
  if (binRelativePath === undefined) {
    throw new Error(
      `@modelcontextprotocol/inspector's manifest (${manifestPath}) declares no 'mcp-inspector' bin entry`,
    );
  }
  return join(dirname(manifestPath), binRelativePath);
}

const INSPECTOR_CLI_ENTRYPOINT = resolveInspectorCliEntrypoint();

// 120s, not 30s: the real-repo smoke legs scan the whole repository through a
// spawned CLI, and PR #229's Windows CI showed the scan legitimately exceeding
// 30s on a windows-latest runner (SIGTERM at exactly 30013ms with empty
// stdout/stderr — a timeout, not a hang: the same leg passes in seconds on
// POSIX runners and the suite still bounds runaway processes).
const INSPECTOR_TIMEOUT_MS = 120_000;

before(() => {
  if (existsSync(DIST_ENTRYPOINT)) {
    return;
  }
  const build = spawnSync("npm", ["run", "build"], {
    cwd: PACKAGE_ROOT,
    encoding: "utf-8",
    timeout: 60_000,
    // npm is npm.cmd on Windows; cmd shims need a shell to start.
    shell: process.platform === "win32",
  });
  if (build.status !== 0) {
    throw new Error(
      `npm run build failed while preparing ${DIST_ENTRYPOINT} for the inspector smoke suite:\n${build.stderr}`,
    );
  }
  if (!existsSync(DIST_ENTRYPOINT)) {
    throw new Error(`npm run build reported success but ${DIST_ENTRYPOINT} still does not exist`);
  }
});

interface InspectorInvocation {
  stdout: string;
  status: number | null;
}

/**
 * Runs the inspector CLI (`--cli node dist/index.js --root <repo> -- <extraArgs...>`)
 * and returns parsed stdout JSON.
 *
 * The bare `--` separates the spawned server's own arguments from the
 * inspector's: inspector 2.x otherwise stops collecting server arguments at
 * the first token beginning with `-`, which silently swallows `--root` and
 * leaves the server resolving its repository root from the CLI's cwd
 * (`rootSource: "cwd"`, this package rather than the repository) instead.
 * Inspector 0.x honours the same separator, so the invocation is correct on
 * both.
 */
function runInspector(extraArgs: readonly string[]): InspectorInvocation {
  const result = spawnSync(
    process.execPath,
    [
      INSPECTOR_CLI_ENTRYPOINT,
      "--cli",
      process.execPath,
      DIST_ENTRYPOINT,
      "--root",
      SDD_FORGE_REPO_ROOT,
      "--",
      ...extraArgs,
    ],
    {
      cwd: PACKAGE_ROOT,
      encoding: "utf-8",
      timeout: INSPECTOR_TIMEOUT_MS,
    },
  );

  assert.equal(
    result.status,
    0,
    `inspector CLI exited non-zero (status=${String(result.status)}, signal=${String(result.signal)}):\n` +
      `stdout:\n${result.stdout}\nstderr:\n${result.stderr}`,
  );

  return { stdout: result.stdout, status: result.status };
}

test("inspector CLI: tools/list reports the four public v2 tools", () => {
  const { stdout } = runInspector(["--method", "tools/list"]);
  const { tools } = ListToolsResultSchema.parse(JSON.parse(stdout));
  assert.deepEqual(tools.map(t => t.name).sort(), [
    "sdd_dashboard_snapshot", "sdd_feature_state", "sdd_gate_audit", "sdd_project_overview",
  ]);
});

test("inspector CLI: each public tool declares read-only behavior and a strict input schema", () => {
  const { stdout } = runInspector(["--method", "tools/list"]);
  const { tools } = ListToolsResultSchema.parse(JSON.parse(stdout));
  assert.equal(tools.length, 4);
  const validate = getV2DefValidator("toolAnnotations");
  for (const tool of tools) {
    assert.ok(validate(tool.annotations), tool.name + ": " + JSON.stringify(validate.errors));
    assert.equal(tool.inputSchema.additionalProperties, false, tool.name);
  }
});

test("inspector CLI: the server lists the overview and feature resource template", () => {
  const resources = runInspector(["--method", "resources/list"]);
  const templates = runInspector(["--method", "resources/templates/list"]);
  const listed = ListResourcesResultSchema.parse(JSON.parse(resources.stdout));
  const templated = ListResourceTemplatesResultSchema.parse(JSON.parse(templates.stdout));
  assert.deepEqual(listed.resources.map(r => r.uri), ["sdd://overview"]);
  assert.deepEqual(templated.resourceTemplates.map(t => t.uriTemplate), ["sdd://feature/{feature}"]);
});

test("inspector CLI: sdd_project_overview returns schema-valid active features for the real repo", () => {
  const { stdout } = runInspector(["--method", "tools/call", "--tool-name", "sdd_project_overview"]);
  const result = CallToolResultSchema.parse(JSON.parse(stdout));
  assert.notEqual(result.isError, true);
  const envelope = parseEnvelope(result) as Result<ProjectOverviewData>;
  assert.equal(envelope.ok, true);
  const validate = getV2DefValidator("sdd_project_overview_data");
  assert.ok(validate(envelope.data), JSON.stringify(validate.errors));
  assert.equal(envelope.data.kind, "project-overview");
  assert.ok(envelope.data.doctor);
  assert.ok(envelope.data.activeFeatures.some(f => f.feature === "sdd-forge-mcp"));
});
