/**
 * AC-011 (runtime part): calling all 4 v2 MCP tools against a synthetic
 * fixture repository must succeed (`!isError && parsed.ok === true`) and
 * leave every file under that repository byte-for-byte unchanged.
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { makeCoreToolsFixture, parseEnvelope } from "../core-tools/test-helpers.js";

function sha256(contents: Buffer): string {
  return createHash("sha256").update(contents).digest("hex");
}

/** Recursively lists every regular file under `dir` as `{ relPath, hash }`, sorted by relPath. */
function snapshot(dir: string): Array<{ relPath: string; hash: string }> {
  const results: Array<{ relPath: string; hash: string }> = [];
  const walk = (absDir: string): void => {
    for (const entry of readdirSync(absDir)) {
      const absPath = join(absDir, entry);
      const stats = statSync(absPath);
      if (stats.isDirectory()) {
        walk(absPath);
      } else if (stats.isFile()) {
        results.push({ relPath: relative(dir, absPath), hash: sha256(readFileSync(absPath)) });
      }
    }
  };
  walk(dir);
  results.sort((a, b) => a.relPath.localeCompare(b.relPath));
  return results;
}

test("all 4 v2 MCP tools succeed and leave the fixture repository byte-for-byte unchanged", async () => {
  const fixture = await makeCoreToolsFixture("readonly-v2-tools-snapshot");
  try {
    const before = snapshot(fixture.tempRoot.dir);

    const calls: Array<{ name: string; arguments: Record<string, unknown> }> = [
      { name: "sdd_project_overview", arguments: { includeDoctor: true } },
      { name: "sdd_feature_state", arguments: { feature: "feature-a", includeDecisionViewMarkdown: true } },
      { name: "sdd_gate_audit", arguments: { feature: "feature-a" } },
      { name: "sdd_dashboard_snapshot", arguments: {} },
    ];

    for (const call of calls) {
      const res = await fixture.client.callTool(call);
      assert.equal(Boolean(res.isError), false, `${call.name} unexpectedly returned isError=true`);
      const env = parseEnvelope(res) as { ok?: boolean };
      assert.equal(env.ok, true, `${call.name} expected ok=true envelope, got ${JSON.stringify(env)}`);
    }

    const after = snapshot(fixture.tempRoot.dir);
    assert.deepEqual(
      after.map((f) => f.relPath),
      before.map((f) => f.relPath),
      "file list changed after calling v2 tools",
    );
    assert.deepEqual(after, before, "file contents changed after calling v2 tools");
  } finally {
    await fixture.cleanup();
  }
});
