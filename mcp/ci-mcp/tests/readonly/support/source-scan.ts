/**
 * Shared static-source-scanning helpers for T-006's write-boundary tests
 * (tests/readonly/static-check.test.ts). Walks the REAL (uncompiled) src/
 * tree — not the dist-test compiled output — so the checks inspect the
 * actual TypeScript source text, mirroring
 * mcp/local-env-mcp/tests/readonly/static-check.test.ts's approach.
 */

import { existsSync, readdirSync, statSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

/**
 * Walks upward from `startDir` until it finds the package root (identified
 * by package.json), so the check works regardless of whether it runs from
 * tests/ or dist-test/tests/.
 */
export function findPackageRoot(startDir: string): string {
  let dir = startDir;
  for (let i = 0; i < 10; i += 1) {
    if (existsSync(join(dir, "package.json"))) {
      return dir;
    }
    const parent = dirname(dir);
    if (parent === dir) {
      break;
    }
    dir = parent;
  }
  throw new Error(`Could not locate package root above ${startDir}`);
}

const THIS_FILE_DIR = dirname(fileURLToPath(import.meta.url));
export const PACKAGE_ROOT = findPackageRoot(THIS_FILE_DIR);
export const SRC_DIR = join(PACKAGE_ROOT, "src");

/** Recursively lists every `.ts` file under `dir`. */
export function listTsFiles(dir: string): string[] {
  const entries = readdirSync(dir);
  const files: string[] = [];
  for (const entry of entries) {
    const fullPath = join(dir, entry);
    const stats = statSync(fullPath);
    if (stats.isDirectory()) {
      files.push(...listTsFiles(fullPath));
    } else if (entry.endsWith(".ts")) {
      files.push(fullPath);
    }
  }
  return files;
}

/**
 * Strips `//` line comments and block comments (including JSDoc) from
 * TypeScript source so the static checks only inspect executable code, not
 * prose that discusses these concepts (e.g. this very module's doc
 * comments, or github-client.ts's module doc mentioning "POST/PUT/PATCH/
 * DELETE").
 */
export function stripComments(source: string): string {
  return source.replace(/\/\*[\s\S]*?\*\//g, "").replace(/\/\/.*$/gm, "");
}
