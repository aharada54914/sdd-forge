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
import { existsSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

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

const INSPECTOR_TIMEOUT_MS = 30_000;

before(() => {
  if (existsSync(DIST_ENTRYPOINT)) {
    return;
  }
  const build = spawnSync("npm", ["run", "build"], {
    cwd: PACKAGE_ROOT,
    encoding: "utf-8",
    timeout: 60_000,
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

/** Runs `npx @modelcontextprotocol/inspector --cli node dist/index.js --root <repo> <extraArgs...>` and returns parsed stdout JSON. */
function runInspector(extraArgs: readonly string[]): InspectorInvocation {
  const result = spawnSync(
    "npx",
    [
      "@modelcontextprotocol/inspector",
      "--cli",
      "node",
      DIST_ENTRYPOINT,
      "--root",
      SDD_FORGE_REPO_ROOT,
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

test("inspector CLI: tools/list reports all 8 core tools + 5 evidence tools", () => {
  const { stdout } = runInspector(["--method", "tools/list"]);
  const parsed = JSON.parse(stdout) as { tools: Array<{ name: string }> };
  const names = parsed.tools.map((t) => t.name).sort();
  assert.deepEqual(names, [
    "evidence_compare_to_traceability",
    "evidence_find_missing",
    "evidence_get_bundle",
    "evidence_summarize_contract_checks",
    "evidence_validate_paths",
    "get_next_sdd_command",
    "get_quality_gate_summary",
    "get_spec_status",
    "get_task_state",
    "list_active_specs",
    "list_approved_tasks",
    "list_blocked_tasks",
    "list_review_tickets",
  ]);
});

test("inspector CLI: resources/list + resources/templates/list report 3 static + 2 template resources", () => {
  const { stdout: resourcesStdout } = runInspector(["--method", "resources/list"]);
  const resources = JSON.parse(resourcesStdout) as { resources: Array<{ uri: string }> };
  assert.deepEqual(
    resources.resources.map((r) => r.uri).sort(),
    ["sdd://active-specs", "sdd://quality-reports", "sdd://review-tickets"],
  );

  const { stdout: templatesStdout } = runInspector(["--method", "resources/templates/list"]);
  const templates = JSON.parse(templatesStdout) as { resourceTemplates: Array<{ uriTemplate: string }> };
  assert.deepEqual(
    templates.resourceTemplates.map((t) => t.uriTemplate).sort(),
    ["sdd://spec/{feature}", "sdd://tasks/{feature}"],
  );

  assert.equal(resources.resources.length + templates.resourceTemplates.length, 5);
});

test("inspector CLI: tools/call list_active_specs returns a schema-shaped envelope for the real repo", () => {
  const { stdout } = runInspector(["--method", "tools/call", "--tool-name", "list_active_specs"]);
  const parsed = JSON.parse(stdout) as { content: Array<{ type: string; text: string }> };
  const firstBlock = parsed.content[0];
  assert.ok(firstBlock !== undefined && firstBlock.type === "text");
  const envelope = JSON.parse(firstBlock.text) as {
    ok: boolean;
    data?: { kind: string; specs: Array<{ feature: string }> };
  };
  assert.equal(envelope.ok, true);
  assert.equal(envelope.data?.kind, "active-specs");
  const features = envelope.data?.specs.map((s) => s.feature) ?? [];
  assert.ok(features.includes("sdd-forge-mcp"));
});
