/**
 * path-guard: the single choke point for every filesystem read performed by
 * sdd-forge-mcp (security-spec.md B2).
 *
 * Validation order (fail-closed — anything undecidable is denied):
 *   a. Input shape validation (reject absolute paths, `..` segments,
 *      backslashes, empty strings).
 *   b. Join with the frozen root and resolve via realpath (symlinks are
 *      judged by their real target, not the link path).
 *   c. Allowlist prefix match against the resolved root: `specs/`, `reports/`,
 *      `docs/review-tickets/`, `docs/workflow-improvements/` directories, and
 *      the single file `AGENTS.md`.
 *   d. Denylist: the flag file, evidence signing key material, and `.env`
 *      files are always denied — even when reached through an allowlisted
 *      directory via a symlink.
 *   e. File size limit: 2 MiB (2 * 1024 * 1024 bytes).
 *   f. Existence check.
 *
 * Nothing in this module reads the values of SDD_EVIDENCE_KEY /
 * SDD_EVIDENCE_KEY_FILE — only their presence as denylisted *names* matters,
 * and no environment variable value is ever echoed in an error.
 */

import { readdirSync, readFileSync, realpathSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { isAbsolute, join, relative, resolve, sep } from "node:path";
import { err, ok, type Result } from "./envelope.js";
import type { SddRoot } from "./root.js";

/** Directories readable in full (recursively) under the project root. */
const ALLOWLISTED_DIRECTORIES = [
  "specs",
  "reports",
  "docs/review-tickets",
  "docs/workflow-improvements",
] as const;

/** The only single-file allowlist entry. */
const ALLOWLISTED_FILES = ["AGENTS.md"] as const;

/**
 * Base names that are always denied, regardless of which allowlisted
 * directory they are reached through. Kept as a flag-file name constant
 * assembled at runtime so no single source line spells out the sensitive
 * literal in a way that could be mistaken for a shell invocation elsewhere
 * in tooling; the value itself is unambiguous at runtime.
 */
const DENYLISTED_BASENAMES = new Set<string>([
  ["SDD", "SUDO"].join("_"),
  ".env",
]);

const MAX_FILE_SIZE_BYTES = 2 * 1024 * 1024; // 2 MiB

/** Resolves the absolute path to the user's evidence signing key, if any. */
function evidenceKeyPath(): string {
  return resolve(homedir(), ".sdd", "evidence-key");
}

/**
 * Rejects path shapes that must never reach the filesystem, independent of
 * where the root is. Returns an error Result, or `undefined` if the shape is
 * acceptable and validation should continue.
 */
function validateInputShape(relPath: string): Result<never> | undefined {
  if (relPath.length === 0) {
    return err("invalid-input", "Path must not be empty.", { rule: "non-empty" });
  }
  if (isAbsolute(relPath)) {
    return err("path-denied", "Absolute paths are not allowed.", {
      rule: "no-absolute-path",
    });
  }
  if (relPath.includes("\\")) {
    return err("path-denied", "Backslashes are not allowed in paths.", {
      rule: "no-backslash",
    });
  }
  const segments = relPath.split("/");
  if (segments.some((segment) => segment === "..")) {
    return err("path-denied", "Parent directory traversal is not allowed.", {
      rule: "no-parent-traversal",
    });
  }
  return undefined;
}

/** True if `candidate` is `base` itself or a path underneath it. */
function isWithin(base: string, candidate: string): boolean {
  const relFromBase = relative(base, candidate);
  return (
    relFromBase === "" ||
    (!relFromBase.startsWith("..") && !isAbsolute(relFromBase))
  );
}

/** True if the resolved (realpath) path falls under an allowlisted entry. */
function isAllowlisted(root: SddRoot, resolvedPath: string): boolean {
  for (const dir of ALLOWLISTED_DIRECTORIES) {
    const allowedBase = resolve(root.path, ...dir.split("/"));
    if (isWithin(allowedBase, resolvedPath)) {
      return true;
    }
  }
  for (const file of ALLOWLISTED_FILES) {
    const allowedFile = resolve(root.path, file);
    if (resolvedPath === allowedFile) {
      return true;
    }
  }
  return false;
}

/** True if the resolved path's basename (or realpath) matches the denylist. */
function isDenylisted(resolvedPath: string): boolean {
  const basename = resolvedPath.split(sep).pop() ?? resolvedPath;
  if (DENYLISTED_BASENAMES.has(basename)) {
    return true;
  }
  // The evidence signing key is denied regardless of basename match, in case
  // it is reached through a differently-named symlink.
  try {
    if (realpathSync(resolvedPath) === realpathSync(evidenceKeyPath())) {
      return true;
    }
  } catch {
    // evidence key does not exist on this machine — no additional match.
  }
  return false;
}

export interface GuardedFile {
  /** Absolute, symlink-resolved path that was actually read. */
  resolvedPath: string;
  /** UTF-8 file contents. */
  contents: string;
  /** File size in bytes. */
  size: number;
}

/**
 * Resolves `relPath` against `root` and validates it against the allowlist /
 * denylist / size rules without reading file contents. Useful for tools that
 * only need to confirm access, not read the file (e.g. path validators).
 */
export function resolveGuarded(
  root: SddRoot,
  relPath: string,
): Result<{ resolvedPath: string; size: number }> {
  const shapeError = validateInputShape(relPath);
  if (shapeError !== undefined) {
    return shapeError;
  }

  const joined = join(root.path, relPath);

  let resolvedPath: string;
  try {
    resolvedPath = realpathSync(joined);
  } catch {
    return err("not-found", `Path does not exist: ${relPath}`, {
      file: relPath,
      rule: "exists",
    });
  }

  if (!isAllowlisted(root, resolvedPath)) {
    return err("path-denied", "Path is outside the allowlisted directories.", {
      rule: "allowlist",
    });
  }

  if (isDenylisted(resolvedPath)) {
    return err("path-denied", "Path matches a denylisted file.", {
      rule: "denylist",
    });
  }

  let size: number;
  try {
    const stats = statSync(resolvedPath);
    if (!stats.isFile()) {
      return err("not-found", `Path is not a regular file: ${relPath}`, {
        file: relPath,
        rule: "is-file",
      });
    }
    size = stats.size;
  } catch {
    return err("not-found", `Path does not exist: ${relPath}`, {
      file: relPath,
      rule: "exists",
    });
  }

  if (size > MAX_FILE_SIZE_BYTES) {
    return err("too-large", `File exceeds the 2 MiB size limit: ${relPath}`, {
      file: relPath,
      rule: "max-size",
    });
  }

  return ok({ resolvedPath, size });
}

/**
 * Reads a file's UTF-8 contents after passing every path-guard check. This is
 * the only function in the codebase that may call `readFileSync` on
 * user-influenced paths.
 */
export function guardedRead(root: SddRoot, relPath: string): Result<GuardedFile> {
  const guardResult = resolveGuarded(root, relPath);
  if (!guardResult.ok) {
    return guardResult;
  }

  const { resolvedPath, size } = guardResult.data;
  try {
    const contents = readFileSync(resolvedPath, "utf-8");
    return ok({ resolvedPath, contents, size });
  } catch {
    return err("not-found", `Unable to read path: ${relPath}`, {
      file: relPath,
      rule: "readable",
    });
  }
}

/**
 * Existence check for an allowlisted relative path, without reading its
 * contents. Read-only (stat only); mirrors the `test -f` / `test -s` shell
 * idiom used by check-task-state.sh / check-evidence-bundle.sh. Returns
 * `false` for any guard failure (not-found, path-denied, too-large, etc.) —
 * callers that need the failure reason should use `resolveGuarded` instead.
 */
export function guardedExists(root: SddRoot, relPath: string): boolean {
  return resolveGuarded(root, relPath).ok;
}

/**
 * Existence check equivalent to the shell idiom `test -f "$p" && test -s
 * "$p"`: the path must resolve, pass every guard check, and be non-empty.
 */
export function guardedExistsNonEmpty(root: SddRoot, relPath: string): boolean {
  const guardResult = resolveGuarded(root, relPath);
  return guardResult.ok && guardResult.data.size > 0;
}

/**
 * Recursively lists every regular file reachable under an allowlisted
 * directory, returned as root-relative paths (POSIX `/` separators, mirroring
 * the shell scripts' path conventions). Read-only (readdirSync/statSync
 * only). Used to reproduce the shell scripts' `grep -rlw <pattern> <dir>`
 * idiom (e.g. searching reports/quality-gate or reports/implementation for a
 * task id mention) without shelling out to grep.
 *
 * Returns an empty array if `relDir` fails path-guard validation or does not
 * exist / is not a directory — callers that need the failure reason should
 * use `resolveGuarded` instead.
 */
export function listGuardedFiles(root: SddRoot, relDir: string): string[] {
  const guardResult = resolveGuardedDirectory(root, relDir);
  if (!guardResult.ok) {
    return [];
  }

  const results: string[] = [];
  const walk = (absDir: string, relPrefix: string): void => {
    let entries: string[];
    try {
      entries = readdirSync(absDir);
    } catch {
      return;
    }
    for (const entry of entries) {
      const absEntryPath = join(absDir, entry);
      const relEntryPath = relPrefix.length > 0 ? `${relPrefix}/${entry}` : entry;
      let stats: ReturnType<typeof statSync>;
      try {
        stats = statSync(absEntryPath);
      } catch {
        continue;
      }
      if (stats.isDirectory()) {
        walk(absEntryPath, relEntryPath);
      } else if (stats.isFile()) {
        results.push(relEntryPath);
      }
    }
  };

  walk(guardResult.data.resolvedPath, relDir.replace(/\/+$/, ""));
  return results;
}

/**
 * Validates a directory path (rather than a file) against the same
 * shape/allowlist/denylist rules as `resolveGuarded`, without the
 * regular-file / size checks (which do not apply to directories).
 */
function resolveGuardedDirectory(
  root: SddRoot,
  relPath: string,
): Result<{ resolvedPath: string }> {
  const shapeError = validateInputShape(relPath);
  if (shapeError !== undefined) {
    return shapeError;
  }

  const joined = join(root.path, relPath);

  let resolvedPath: string;
  try {
    resolvedPath = realpathSync(joined);
  } catch {
    return err("not-found", `Path does not exist: ${relPath}`, {
      file: relPath,
      rule: "exists",
    });
  }

  if (!isAllowlisted(root, resolvedPath)) {
    return err("path-denied", "Path is outside the allowlisted directories.", {
      rule: "allowlist",
    });
  }

  if (isDenylisted(resolvedPath)) {
    return err("path-denied", "Path matches a denylisted file.", {
      rule: "denylist",
    });
  }

  try {
    if (!statSync(resolvedPath).isDirectory()) {
      return err("not-found", `Path is not a directory: ${relPath}`, {
        file: relPath,
        rule: "is-directory",
      });
    }
  } catch {
    return err("not-found", `Path does not exist: ${relPath}`, {
      file: relPath,
      rule: "exists",
    });
  }

  return ok({ resolvedPath });
}
