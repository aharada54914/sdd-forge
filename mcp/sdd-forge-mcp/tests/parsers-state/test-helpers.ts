/**
 * Shared (non-test) helpers for the T-003 state-parser test suite. Deliberately
 * not named `*.test.ts` so `node --test`'s glob never picks it up as a test
 * file in its own right — importing a `.test.ts` file from another
 * `.test.ts` file would re-register that file's top-level `test()` calls a
 * second time (see mcp/sdd-forge-mcp/.claude/agent-memory/coder
 * feedback-node-test-shared-helpers).
 */

import { existsSync, realpathSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import type { SddRoot } from "../../src/root.js";

/**
 * Locates the real sdd-forge repository root by walking upward from this
 * file's compiled location until `AGENTS.md` + `specs/` are both present.
 * Used only by the "real file" verification tests in this suite — synthetic
 * fixture tests use `makeTempSddRoot` from `tests/test-helpers.ts` instead.
 */
export function findSddForgeRepoRoot(): string {
  const thisDir = dirname(fileURLToPath(import.meta.url));
  let dir = thisDir;
  for (let i = 0; i < 12; i += 1) {
    if (existsSync(join(dir, "AGENTS.md")) && existsSync(join(dir, "specs"))) {
      return dir;
    }
    const parent = dirname(dir);
    if (parent === dir) {
      break;
    }
    dir = parent;
  }
  throw new Error(`Could not locate sdd-forge repo root above ${thisDir}`);
}

/** Builds a frozen `SddRoot` pointing at the real sdd-forge repository. */
export function makeRealRepoRoot(): SddRoot {
  return Object.freeze({ path: realpathSync(findSddForgeRepoRoot()), source: "cwd" as const });
}
