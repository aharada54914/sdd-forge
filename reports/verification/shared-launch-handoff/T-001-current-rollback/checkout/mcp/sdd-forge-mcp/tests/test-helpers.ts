/**
 * Shared test helpers: build a throwaway SDD-shaped root under the OS temp
 * directory so tests never read or write real repository files.
 */

import { mkdtempSync, mkdirSync, writeFileSync, realpathSync, rmSync, symlinkSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { SddRoot } from "../src/root.js";

export interface TempSddRoot {
  root: SddRoot;
  dir: string;
  cleanup: () => void;
}

/**
 * Creates a fresh temp directory shaped like a minimal SDD root (AGENTS.md +
 * specs/) and returns a frozen SddRoot pointing at it, plus a cleanup hook.
 */
export function makeTempSddRoot(prefix: string): TempSddRoot {
  const dir = mkdtempSync(join(tmpdir(), `${prefix}-`));
  mkdirSync(join(dir, "specs"), { recursive: true });
  mkdirSync(join(dir, "reports"), { recursive: true });
  mkdirSync(join(dir, "docs", "review-tickets"), { recursive: true });
  mkdirSync(join(dir, "docs", "workflow-improvements"), { recursive: true });
  writeFileSync(join(dir, "AGENTS.md"), "# AGENTS\n", "utf-8");

  // Resolve symlinks (e.g. macOS /tmp -> /private/tmp) so this matches what
  // resolveRoot()/realpathSync() produce internally; otherwise equality
  // assertions against the guard/root modules would spuriously fail.
  const realDir = realpathSync(dir);
  const root: SddRoot = Object.freeze({ path: realDir, source: "cwd" as const });

  return {
    root,
    dir,
    cleanup: () => rmSync(dir, { recursive: true, force: true }),
  };
}

/** Creates a bare temp directory with no SDD structure at all. */
export function makeTempPlainDir(prefix: string): { dir: string; cleanup: () => void } {
  const dir = mkdtempSync(join(tmpdir(), `${prefix}-`));
  return { dir, cleanup: () => rmSync(dir, { recursive: true, force: true }) };
}

export function writeFile(dir: string, relPath: string, contents: string): string {
  const fullPath = join(dir, relPath);
  mkdirSync(join(fullPath, ".."), { recursive: true });
  writeFileSync(fullPath, contents, "utf-8");
  return fullPath;
}

export function makeSymlink(target: string, linkPath: string): void {
  symlinkSync(target, linkPath);
}
