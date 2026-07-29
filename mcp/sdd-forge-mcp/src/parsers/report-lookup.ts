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

import { guardedRead, listGuardedFilesWithDiagnostics } from "../path-guard.js";
import type { SddRoot } from "../root.js";

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/**
 * One failure encountered while scanning a directory for matching files.
 *
 * Structurally identical to `path-guard.ts`'s `GuardedListError` (which is
 * what actually populates it) and declared here so this module's own callers
 * do not have to reach into the path guard's vocabulary for a type.
 */
export interface DirectoryReadError {
  /** The scanned `relDir` for a guard-validation failure, or the root-relative sub-path where the walk failed. */
  path: string;
  /** The caught error's message, or the guard's own denial message. */
  reason: string;
}

/**
 * Every path-guard-relative file path under `relDir` whose contents contain
 * `pattern` as a whole word, PLUS every failure the directory scan hit.
 *
 * This is the diagnostics-carrying form of `anyFileContaining` below. It
 * exists because an empty `matches` is ambiguous on its own: a directory that
 * was read successfully and simply holds no match is indistinguishable from a
 * directory that could not be scanned at all. Callers that must not conflate
 * the two (REQ-004: `evidence_find_missing`'s `undeterminable`) check
 * `errors.length` FIRST and only then interpret `matches`.
 *
 * `errors` is reported exactly as `listGuardedFilesWithDiagnostics` produced
 * it — no message is rewritten, and no absolute path or extra filesystem
 * detail is interpolated here (security-spec.md Boundary B4).
 *
 * A scan can be BOTH partially successful and errored (a readable top-level
 * directory with one unreadable subdirectory), so `matches` is still fully
 * populated from whatever was readable even when `errors` is non-empty; this
 * function does not fail fast and does not discard partial results.
 */
export function anyFileContainingWithDiagnostics(
  root: SddRoot,
  relDir: string,
  pattern: string,
): { matches: string[]; errors: DirectoryReadError[] } {
  const wordBoundary = new RegExp(`(^|[^A-Za-z0-9_-])${escapeRegExp(pattern)}([^A-Za-z0-9_-]|$)`);
  const { files, errors } = listGuardedFilesWithDiagnostics(root, relDir);
  const matches: string[] = [];
  for (const relFilePath of files) {
    const read = guardedRead(root, relFilePath);
    if (read.ok && wordBoundary.test(read.data.contents)) {
      matches.push(relFilePath);
    }
  }
  return { matches, errors };
}

/**
 * Every path-guard-relative file path under `relDir` whose contents contain
 * `pattern` as a whole word.
 *
 * Exact signature and exact behavior preserved (BL-003): this is a thin
 * wrapper over `anyFileContainingWithDiagnostics` that discards the
 * diagnostics, so a scan failure still collapses to `[]` here exactly as it
 * did before. Callers that need the failure reason must use
 * `anyFileContainingWithDiagnostics` instead.
 */
export function anyFileContaining(root: SddRoot, relDir: string, pattern: string): string[] {
  return anyFileContainingWithDiagnostics(root, relDir, pattern).matches;
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
