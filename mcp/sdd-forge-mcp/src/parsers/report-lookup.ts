/**
 * Whole-word file search helpers reproducing the "does any report mention
 * this task id" half of check-task-state.sh's `grep -rlw <pattern> <dir> |
 * head -1` idiom.
 *
 * Deliberately does not reproduce `head -1`'s "pick exactly one file" step:
 * `grep -r`'s traversal order is raw-filesystem-readdir order, which is
 * unspecified and platform-dependent (verified to differ between this
 * module's `readdirSync`-based traversal — alphabetically sorted on the
 * Node/macOS combination this was developed on — and the shell's raw
 * directory order on the same filesystem). When more than one report
 * mentions a task id (e.g. one report mentions a *different* task in
 * passing, such as a migration note), which single file `head -1` happens to
 * select is not a meaningful signal, so `hasQualityGateVerdictPass` below
 * checks *all* matching files rather than gambling on traversal order
 * matching the shell's.
 */

import { guardedRead, listGuardedFiles } from "../path-guard.js";
import type { SddRoot } from "../root.js";

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/** Every path-guard-relative file path under `relDir` whose contents contain `pattern` as a whole word. */
export function anyFileContaining(root: SddRoot, relDir: string, pattern: string): string[] {
  const wordBoundary = new RegExp(`(^|[^A-Za-z0-9_-])${escapeRegExp(pattern)}([^A-Za-z0-9_-]|$)`);
  const matches: string[] = [];
  for (const relFilePath of listGuardedFiles(root, relDir)) {
    const read = guardedRead(root, relFilePath);
    if (read.ok && wordBoundary.test(read.data.contents)) {
      matches.push(relFilePath);
    }
  }
  return matches;
}

/**
 * True if at least one report under `relDir` mentions `taskId` as a whole
 * word (regardless of which one `head -1` would have picked in the shell).
 */
export function hasAnyFileMentioning(root: SddRoot, relDir: string, taskId: string): boolean {
  return anyFileContaining(root, relDir, taskId).length > 0;
}

/**
 * True if, among every quality-gate report mentioning `taskId`, at least one
 * contains `VERDICT: PASS`. See this module's doc comment for why this
 * checks all matches instead of only the one `head -1` would select.
 */
export function hasQualityGateVerdictPass(root: SddRoot, relDir: string, taskId: string): boolean {
  return anyFileContaining(root, relDir, taskId).some((relFilePath) => {
    const read = guardedRead(root, relFilePath);
    return read.ok && /VERDICT: PASS/.test(read.data.contents);
  });
}
