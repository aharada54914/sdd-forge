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

import { guardedDirExists, guardedRead, listGuardedFilesWithDiagnostics } from "../path-guard.js";
import type { SddRoot } from "../root.js";
import { parseReviewReportVerdict } from "./review-verdict.js";

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
 * True when a `sdd-gate-execution/v1` artifact actually verified something:
 * at least one command ran and neither drift nor sensor checks were skipped
 * (#825), derived from `checks` so a self-declared flag cannot override them.
 */
export function isExecutionCoverageComplete(parsed: Record<string, unknown>): boolean {
  // A stated coverage.complete can only narrow what the checks show, never widen it.
  const coverage = parsed.coverage as Record<string, unknown> | undefined;
  if (coverage && typeof coverage === "object" && coverage.complete === false) {
    return false;
  }
  const checks = parsed.checks as Record<string, unknown> | undefined;
  if (!checks || typeof checks !== "object") return false;
  const commands = checks.commands;
  const drift = checks.specDrift as Record<string, unknown> | undefined;
  const sensors = checks.nonFunctionalSensors as Record<string, unknown> | undefined;
  return (
    Array.isArray(commands) &&
    commands.length > 0 &&
    drift?.skipped !== true &&
    sensors?.skipped !== true
  );
}

// An identity line as the report templates write it: `Feature: x`,
// `- **Feature**: x` (sdd-gate-report.md) or `**Feature:** x`.
const FEATURE_LINE = /^[ \t*-]*(?:\*\*)?feature(?:\*\*)?[ \t]*:(?:\*\*)?(.*)$/i;
const SPEC_SLUG = /^[a-z0-9][a-z0-9-]*$/;

/** The first `Feature:` identity line outside block quotes and fenced code, if any. */
function declaredFeature(contents: string): string | undefined {
  let activeFence: string | null = null;
  for (const line of contents.replace(/^\uFEFF/, "").replace(/\r\n/g, "\n").split("\n")) {
    const fence = /^(`{3,}|~{3,})/.exec(line.trimStart());
    if (activeFence !== null) {
      if (line.trimStart().startsWith(activeFence)) activeFence = null;
      continue;
    }
    if (fence) {
      activeFence = fence[1] ?? "```";
      continue;
    }
    const match = FEATURE_LINE.exec(line);
    if (match) return (match[1] ?? "").trim().replace(/^[`*]+|[`*]+$/g, "").trim();
  }
  return undefined;
}

/**
 * The feature a report's file name carries (`<feature>-T-NNN.md`, or with a
 * timestamp in front): the longest dash-separated suffix of the part before
 * the task id that names an existing `specs/` directory.
 */
function featureFromFileName(root: SddRoot, relFilePath: string, taskId: string): string | undefined {
  const base = relFilePath.slice(relFilePath.lastIndexOf("/") + 1);
  const at = base.lastIndexOf(`-${taskId}.`);
  if (at <= 0) return undefined;
  const parts = base.slice(0, at).split("-");
  for (let first = 0; first < parts.length; first++) {
    const slug = parts.slice(first).join("-");
    if (SPEC_SLUG.test(slug) && guardedDirExists(root, `specs/${slug}`)) return slug;
  }
  return undefined;
}

/**
 * Task ids are unique only within a feature, so a quality-gate report counts
 * for `feature` unless its file name or its first `Feature:` line names
 * another one. Reports written before the identity block was required, with
 * neither, still count.
 */
function isReportForFeature(root: SddRoot, relFilePath: string, contents: string, taskId: string, feature: string): boolean {
  const named = featureFromFileName(root, relFilePath, taskId);
  const declared = declaredFeature(contents);
  return (named === undefined || named === feature) && (declared === undefined || declared === feature);
}

function isQualityGatePassContent(relFilePath: string, contents: string): boolean {
  // Done evidence is the independent G1-G5 verdict. A run-sdd-gate
  // `.execution.json` is the mechanical pre-review result and never counts on
  // its own (#835).
  if (relFilePath.endsWith(".execution.json")) return false;
  return parseReviewReportVerdict(contents) === "PASS";
}

/** Every quality-gate report under `relDir` that mentions `taskId` and belongs to `feature`. */
export function qualityGateReportsFor(root: SddRoot, relDir: string, taskId: string, feature: string): string[] {
  return createReportLookup().qualityGateReportsFor(root, relDir, taskId, feature);
}

/**
 * True if, among every quality-gate report of `feature` mentioning `taskId`,
 * at least one independent report's verdict is PASS (see review-verdict.ts).
 */
export function hasQualityGateVerdictPass(root: SddRoot, relDir: string, taskId: string, feature: string): boolean {
  return createReportLookup().hasQualityGateVerdictPass(root, relDir, taskId, feature);
}

interface ReportDirectory {
  files: ReadonlyArray<{ path: string; contents: string }>;
  errors: DirectoryReadError[];
}

/** Internal dependency for one synchronous operation; never retain across requests. */
export interface ReportLookup {
  anyFileContainingWithDiagnostics: typeof anyFileContainingWithDiagnostics;
  anyFileContaining: typeof anyFileContaining;
  hasAnyFileMentioning: typeof hasAnyFileMentioning;
  qualityGateReportsFor: typeof qualityGateReportsFor;
  hasQualityGateVerdictPass: typeof hasQualityGateVerdictPass;
}

/**
 * Lazily reads each root/directory through the existing guards once. Only report
 * bytes and listing diagnostics are reused, never authorization or task verdicts.
 * A directory is observed at its first scan, not as an atomic filesystem snapshot.
 */
export function createReportLookup(): ReportLookup {
  const roots = new Map<SddRoot, Map<string, ReportDirectory>>();
  const directory = (root: SddRoot, relDir: string): ReportDirectory => {
    let directories = roots.get(root);
    if (directories === undefined) {
      directories = new Map();
      roots.set(root, directories);
    }
    let snapshot = directories.get(relDir);
    if (snapshot === undefined) {
      const { files, errors } = listGuardedFilesWithDiagnostics(root, relDir);
      const readable: { path: string; contents: string }[] = [];
      for (const path of files) {
        const read = guardedRead(root, path);
        if (read.ok) readable.push({ path, contents: read.data.contents });
      }
      snapshot = { files: readable, errors };
      directories.set(relDir, snapshot);
    }
    return snapshot;
  };
  const matching = (root: SddRoot, relDir: string, pattern: string) => {
    const wordBoundary = new RegExp(`(^|[^A-Za-z0-9_-])${escapeRegExp(pattern)}([^A-Za-z0-9_-]|$)`);
    return directory(root, relDir).files.filter(file => wordBoundary.test(file.contents));
  };
  return {
    anyFileContainingWithDiagnostics: (root, relDir, pattern) => ({
      matches: matching(root, relDir, pattern).map(file => file.path),
      errors: directory(root, relDir).errors.map(error => ({ ...error })),
    }),
    anyFileContaining: (root, relDir, pattern) => matching(root, relDir, pattern).map(file => file.path),
    hasAnyFileMentioning: (root, relDir, taskId) => matching(root, relDir, taskId).length > 0,
    qualityGateReportsFor: (root, relDir, taskId, feature) =>
      matching(root, relDir, taskId)
        .filter(file => isReportForFeature(root, file.path, file.contents, taskId, feature))
        .map(file => file.path),
    hasQualityGateVerdictPass: (root, relDir, taskId, feature) =>
      matching(root, relDir, taskId).some(file =>
        isReportForFeature(root, file.path, file.contents, taskId, feature) &&
        isQualityGatePassContent(file.path, file.contents)),
  };
}
