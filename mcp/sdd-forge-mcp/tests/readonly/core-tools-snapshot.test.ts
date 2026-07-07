/**
 * AC-011 (runtime part): calling all 8 core tools against a synthetic
 * fixture repository must not change any file under that repository — same
 * file list, same per-file sha256 content hash, before and after the calls.
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { makeCoreToolsFixture } from "../core-tools/test-helpers.js";

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

test("all 8 core tools leave the fixture repository byte-for-byte unchanged", async () => {
  const fixture = await makeCoreToolsFixture("readonly-core-tools-snapshot");
  try {
    const before = snapshot(fixture.tempRoot.dir);

    await fixture.client.callTool({ name: "list_active_specs", arguments: {} });
    await fixture.client.callTool({ name: "get_spec_status", arguments: { feature: "feature-a" } });
    await fixture.client.callTool({ name: "get_task_state", arguments: { feature: "feature-a" } });
    await fixture.client.callTool({ name: "list_approved_tasks", arguments: { feature: "feature-a" } });
    await fixture.client.callTool({ name: "list_blocked_tasks", arguments: { feature: "feature-a" } });
    await fixture.client.callTool({ name: "list_review_tickets", arguments: {} });
    await fixture.client.callTool({ name: "get_quality_gate_summary", arguments: {} });
    await fixture.client.callTool({ name: "get_next_sdd_command", arguments: { feature: "feature-a" } });

    const after = snapshot(fixture.tempRoot.dir);
    assert.deepEqual(
      after.map((f) => f.relPath),
      before.map((f) => f.relPath),
      "file list changed after calling core tools",
    );
    assert.deepEqual(after, before, "file contents changed after calling core tools");
  } finally {
    await fixture.cleanup();
  }
});
