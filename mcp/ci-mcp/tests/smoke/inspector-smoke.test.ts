/**
 * T-008 / AC-015: MCP Inspector CLI smoke test. Runs the real, bundled
 * `dist/index.js` server through `@modelcontextprotocol/inspector --cli`
 * (a separate process talking real stdio JSON-RPC, not the SDK's in-memory
 * transport used by every other suite) and asserts `tools/list` reports
 * exactly the 5 ci-mcp tools (`list_workflow_runs`, `get_workflow_run`,
 * `list_run_jobs`, `get_job_log`, `list_run_artifacts`). No network access
 * is required or performed — the inspector CLI drives a local stdio
 * subprocess only, and the one `tools/call` sanity check below is run with
 * the 3 token env vars and `CI_MCP_REPO` deliberately stripped so the
 * handler short-circuits to `auth-missing` (auth.ts's `withToken` gate runs
 * before any GitHub call — see src/auth.ts), never reaching the network.
 *
 * `dist/index.js` must exist before this suite runs; if it does not
 * (e.g. a fresh checkout before `npm run build` has been invoked), this
 * suite builds it once via `npm run build` rather than skipping — per task
 * instructions, the smoke test must actually run, not be silently skipped.
 */

import { test, before } from "node:test";
import assert from "node:assert/strict";
import { existsSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const THIS_FILE_DIR = dirname(fileURLToPath(import.meta.url));

/** Walks upward from this compiled test file to find the ci-mcp package root (identified by package.json). */
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
  throw new Error(`Could not locate the ci-mcp package root above ${startDir}`);
}

const PACKAGE_ROOT = findPackageRoot(THIS_FILE_DIR);
const DIST_ENTRYPOINT = join(PACKAGE_ROOT, "dist", "index.js");

/**
 * Absolute path to the inspector's CLI entry script, resolved through the
 * package's own manifest. Spawning it with `process.execPath` (instead of
 * `npx`) keeps the invocation portable: Windows has no `npx` executable —
 * only an `npx.cmd` shim that `spawnSync` cannot start without a shell.
 */
const require = createRequire(import.meta.url);
const INSPECTOR_CLI_ENTRYPOINT = join(
  dirname(require.resolve("@modelcontextprotocol/inspector/package.json")),
  "cli",
  "build",
  "cli.js",
);

const INSPECTOR_TIMEOUT_MS = 30_000;

/** Token / repo env vars that must be absent for the auth-missing sanity check (auth.ts TOKEN_ENV_PRIORITY + repo-resolve.ts's CI_MCP_REPO fallback). */
const SENSITIVE_ENV_KEYS = ["CI_MCP_GITHUB_TOKEN", "GH_READONLY_TOKEN", "GITHUB_TOKEN", "CI_MCP_REPO"] as const;

/** A copy of the current environment with every token/repo-fallback var stripped, regardless of what the ambient (e.g. CI runner) environment happens to carry. */
function envWithoutTokens(): NodeJS.ProcessEnv {
  const clean: NodeJS.ProcessEnv = { ...process.env };
  for (const key of SENSITIVE_ENV_KEYS) {
    delete clean[key];
  }
  return clean;
}

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

/** Runs the inspector CLI (`--cli node dist/index.js <extraArgs...>`) and returns parsed stdout JSON. */
function runInspector(extraArgs: readonly string[], env: NodeJS.ProcessEnv = process.env): InspectorInvocation {
  const result = spawnSync(
    process.execPath,
    [INSPECTOR_CLI_ENTRYPOINT, "--cli", process.execPath, DIST_ENTRYPOINT, ...extraArgs],
    {
      cwd: PACKAGE_ROOT,
      encoding: "utf-8",
      timeout: INSPECTOR_TIMEOUT_MS,
      env,
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

test("inspector CLI: server starts over stdio and tools/list reports exactly the 5 ci-mcp tools", () => {
  const { stdout } = runInspector(["--method", "tools/list"]);
  const parsed = JSON.parse(stdout) as { tools: Array<{ name: string }> };
  const names = parsed.tools.map((t) => t.name).sort();
  assert.deepEqual(names, [
    "get_job_log",
    "get_workflow_run",
    "list_run_artifacts",
    "list_run_jobs",
    "list_workflow_runs",
  ]);
});

test("inspector CLI: tools/call list_workflow_runs with no token env and no repo resolves to a schema-shaped auth-missing envelope, no network reached", () => {
  const { stdout } = runInspector(
    ["--method", "tools/call", "--tool-name", "list_workflow_runs"],
    envWithoutTokens(),
  );
  const parsed = JSON.parse(stdout) as { content: Array<{ type: string; text: string }> };
  const firstBlock = parsed.content[0];
  assert.ok(firstBlock !== undefined && firstBlock.type === "text");
  const envelope = JSON.parse(firstBlock.text) as { ok: boolean; error?: { code: string } };
  assert.equal(envelope.ok, false);
  assert.equal(envelope.error?.code, "auth-missing");
});
