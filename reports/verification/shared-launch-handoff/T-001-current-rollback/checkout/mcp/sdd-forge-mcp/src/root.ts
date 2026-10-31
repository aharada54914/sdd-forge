/**
 * Project root resolution.
 *
 * Resolution order: CLI `--root <path>` > `SDD_FORGE_ROOT` env var > cwd.
 * The root is resolved via realpath exactly once at process startup and the
 * resulting object is frozen so nothing downstream can mutate it. Tool input
 * never carries a root parameter (REQ-007) — later changes to
 * `process.env.SDD_FORGE_ROOT` or `process.cwd()` must not affect the
 * resolved root.
 */

import { realpathSync, existsSync, statSync } from "node:fs";
import { resolve } from "node:path";

export interface SddRoot {
  /** Absolute, symlink-resolved path to the project root. */
  readonly path: string;
  /** Where the root value came from, recorded for diagnostics only. */
  readonly source: "cli" | "env" | "cwd";
}

function readCliRootArg(argv: readonly string[]): string | undefined {
  const flagIndex = argv.indexOf("--root");
  if (flagIndex === -1) {
    return undefined;
  }
  const value = argv[flagIndex + 1];
  if (value === undefined || value.length === 0) {
    throw new Error("--root flag requires a non-empty path argument");
  }
  return value;
}

/**
 * Resolves the project root using the documented precedence and realpath.
 * Throws if the candidate path does not exist or is not a directory —
 * callers running this at startup should let that surface as a fatal error.
 */
export function resolveRoot(
  argv: readonly string[] = process.argv.slice(2),
  env: NodeJS.ProcessEnv = process.env,
  cwd: string = process.cwd(),
): SddRoot {
  const cliRoot = readCliRootArg(argv);
  let candidate: string;
  let source: SddRoot["source"];

  if (cliRoot !== undefined) {
    candidate = resolve(cliRoot);
    source = "cli";
  } else if (env.SDD_FORGE_ROOT !== undefined && env.SDD_FORGE_ROOT.length > 0) {
    candidate = resolve(env.SDD_FORGE_ROOT);
    source = "env";
  } else {
    candidate = resolve(cwd);
    source = "cwd";
  }

  const resolvedPath = realpathSync(candidate);
  const stats = statSync(resolvedPath);
  if (!stats.isDirectory()) {
    throw new Error(`Resolved root is not a directory: ${resolvedPath}`);
  }

  return Object.freeze({ path: resolvedPath, source });
}

/**
 * Determines whether a resolved root looks like an SDD project root:
 * it must contain both an `AGENTS.md` file and a `specs/` directory.
 * This does not throw; callers use the boolean to decide whether to emit
 * a `not-sdd-root` error.
 */
export function isSddRoot(root: SddRoot): boolean {
  const agentsMdPath = resolve(root.path, "AGENTS.md");
  const specsPath = resolve(root.path, "specs");

  if (!existsSync(agentsMdPath) || !existsSync(specsPath)) {
    return false;
  }

  try {
    return statSync(agentsMdPath).isFile() && statSync(specsPath).isDirectory();
  } catch {
    return false;
  }
}
