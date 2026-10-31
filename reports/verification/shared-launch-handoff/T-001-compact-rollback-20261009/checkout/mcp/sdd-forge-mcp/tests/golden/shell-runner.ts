/**
 * Shell test-harness helpers for the golden tests (AC-001). These functions
 * shell out to `check-task-state.sh` via child_process — this is the one
 * place in the whole test suite allowed to do so (per task instructions,
 * only test code may invoke the shell scripts; src/ never does).
 */

import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

export interface ShellRunResult {
  exitCode: number;
  combinedOutput: string;
}

/**
 * Repo root two levels above `mcp/sdd-forge-mcp` (this package's own
 * directory), resolved from this file's location so it works whether running
 * from `tests/` (tsx) or `dist-test/tests/` (tsc output).
 */
export function findRepoRoot(): string {
  const thisDir = dirname(fileURLToPath(import.meta.url));
  let dir = thisDir;
  for (let i = 0; i < 12; i += 1) {
    if (
      existsSync(join(dir, "plugins", "sdd-quality-loop", "scripts", "check-task-state.sh")) &&
      existsSync(join(dir, "specs"))
    ) {
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

/**
 * Runs check-task-state.sh against a real feature's tasks.md inside the
 * actual repository (read-only; the script itself never writes anything).
 * The tasks.md argument is passed as a repo-root-relative path (matching
 * what `parseTaskState` is called with in the comparison tests below), since
 * check-task-state.sh echoes that argument verbatim into its failure/report
 * messages (e.g. `verification/T-001.evidence.json does not exist in
 * <tasks_dir>`) — an absolute path would make those messages diverge from
 * the parser's relative-path output for reasons that have nothing to do with
 * verdict correctness.
 */
export function runCheckTaskState(repoRoot: string, feature: string): ShellRunResult {
  const tasksRelPath = join("specs", feature, "tasks.md");
  const scriptPath = join(
    repoRoot,
    "plugins",
    "sdd-quality-loop",
    "scripts",
    "check-task-state.sh",
  );
  try {
    const stdout = execFileSync("bash", [scriptPath, tasksRelPath], {
      cwd: repoRoot,
      encoding: "utf-8",
      stdio: ["ignore", "pipe", "pipe"],
    });
    return { exitCode: 0, combinedOutput: stdout };
  } catch (error) {
    const execError = error as { status?: number; stdout?: string; stderr?: string };
    const combinedOutput = `${execError.stdout ?? ""}${execError.stderr ?? ""}`;
    return { exitCode: execError.status ?? 1, combinedOutput };
  }
}

/**
 * check-task-state.sh's own `fail(msg)` calls always produce a message that
 * starts with a task id (`T-<digits> ...`), the literal `duplicate task id`,
 * or the `check-task-state:` prefix used by the no-tasks-found/file-not-found
 * paths. check-evidence-bundle.sh's own detail lines (sha256 mismatches,
 * manifest/contract/provenance messages) are also emitted with a leading
 * ` - ` by the same script run, but never start with one of those prefixes —
 * this lets the golden comparison isolate check-task-state.sh's own verdict
 * inputs from the evidence-bundle subprocess's implementation detail, which
 * this parser deliberately folds into a single `done-evidence-invalid`
 * summary message (see src/parsers/tasks.ts module doc).
 */
const OWN_FAILURE_PREFIX = /^(T-\d+ |duplicate task id |check-task-state:)/;

/** Extracts check-task-state.sh's own `fail()` message set from combined shell output. */
export function extractOwnFailureMessages(combinedOutput: string): string[] {
  const messages: string[] = [];
  for (const rawLine of combinedOutput.split("\n")) {
    const match = /^ - (.+)$/.exec(rawLine);
    if (match?.[1] !== undefined && OWN_FAILURE_PREFIX.test(match[1])) {
      messages.push(match[1]);
    }
  }
  return messages;
}

/** True if the shell's combined output indicates the tasks.md file itself was not found. */
export function shellReportsFileNotFound(combinedOutput: string): boolean {
  return /tasks file not found/.test(combinedOutput);
}

/**
 * `check-evidence-bundle.sh` detail lines whose CAUSE is the *checkout's git
 * object graph*, not anything recorded in tasks.md or in the evidence bundle's
 * own content. A bundle records the commit it was generated at; if that commit
 * later becomes unreachable (the feature branch was squash-merged, rebased, or
 * deleted), the bundle stops validating in a fresh clone while still validating
 * in a working copy that happens to retain the object.
 *
 * `parseTaskState` cannot observe this class at all — it never shells out to
 * git — so a live comparison that let it drive the expected verdict would
 * report a parser defect that does not exist, and would flip between machines
 * for the same commit. Measured 2026-08-31: 26 of the repository's 199 evidence
 * bundles pin commits unreachable from a full clone, one of them in a golden
 * feature; that one turned the live comparison red on CI while it stayed green
 * on a developer machine holding the orphaned object.
 */
const ENVIRONMENT_DEPENDENT_DETAIL = /^git_commit does not exist in repository: [0-9a-f]{7,40}$/;

/**
 * The one own-failure shape `check-task-state.sh` emits when the *subprocess*
 * bundle validation is what failed. Any other own failure is in the parser's
 * scope and must still be compared.
 */
const EVIDENCE_BUNDLE_SUMMARY = /^T-\d+ evidence bundle failed validation: /;

/**
 * Returns the environment-dependent detail lines behind a shell failure, but
 * ONLY when the failure is attributable to them alone: every own-failure line
 * must be an evidence-bundle summary, and at least one detail line must name an
 * environment-dependent cause.
 *
 * Deliberately narrow. If the shell also reports a status/approval failure, or
 * the bundle failed for a content reason the parser *can* see (a sha256
 * mismatch, a missing artifact), this returns an empty array and the caller
 * compares verdicts strictly, exactly as before. The predicate is a scalpel for
 * one unobservable cause, not a blanket amnesty for bundle failures — see the
 * negative controls in `environment-dependence.test.ts`.
 */
export function environmentDependentBundleFailures(
  combinedOutput: string,
  ownFailureMessages: string[],
): string[] {
  if (ownFailureMessages.length === 0) {
    return [];
  }
  if (!ownFailureMessages.every((message) => EVIDENCE_BUNDLE_SUMMARY.test(message))) {
    return [];
  }
  const causes: string[] = [];
  for (const rawLine of combinedOutput.split("\n")) {
    const match = /^ - (.+)$/.exec(rawLine);
    if (match?.[1] !== undefined && ENVIRONMENT_DEPENDENT_DETAIL.test(match[1])) {
      causes.push(match[1]);
    }
  }
  return causes;
}

export interface RecordedFixture {
  feature: string;
  exitCode: number;
  fileNotFound: boolean;
  ownFailureMessages: string[];
}

/**
 * Fixtures always live under the *source* tests/golden/fixtures directory
 * (`mcp/sdd-forge-mcp/tests/golden/fixtures/`), which is the committed
 * location, regardless of whether this code is currently running from
 * `tests/` (tsx) or `dist-test/tests/` (tsc output) — resolved relative to
 * the sdd-forge repo root rather than to this file's own (possibly
 * compiled-copy) location.
 */
export function fixturePathFor(feature: string): string {
  const repoRoot = findRepoRoot();
  return join(
    repoRoot,
    "mcp",
    "sdd-forge-mcp",
    "tests",
    "golden",
    "fixtures",
    `${feature}.expected.json`,
  );
}

export function loadRecordedFixture(feature: string): RecordedFixture {
  return JSON.parse(readFileSync(fixturePathFor(feature), "utf-8")) as RecordedFixture;
}
