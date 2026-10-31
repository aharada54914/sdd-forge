/**
 * Compile-time probe allowlist (ADR-0004 / REQ-003).
 *
 * This is the ONLY set of commands local-env-mcp will ever launch. It is a
 * frozen `as const` table so no user input can add, remove, or mutate an entry:
 * the tool layer may only *filter* this list by name (an enum), never supply a
 * command, argument, or path. `execFile` (no shell) launches each `command`
 * with its fixed `args`; the version string is read from `versionStream`.
 *
 * Every CLI uses `--version` on stdout except `java`, which prints its version
 * banner to stderr in response to `-version`.
 */

/** Which stream a CLI writes its version banner to. */
export type VersionStream = "stdout" | "stderr";

/** The 14 probeable CLI names (must match contract cliName enum). */
export type CliName =
  | "node"
  | "npm"
  | "pnpm"
  | "yarn"
  | "bun"
  | "deno"
  | "git"
  | "gh"
  | "python3"
  | "go"
  | "rustc"
  | "cargo"
  | "java"
  | "docker";

/** A single fixed probe target. */
export interface AllowlistEntry {
  /** Stable identifier surfaced in tool responses (contract cliName enum). */
  readonly name: CliName;
  /** Bare binary name resolved against PATH by execFile (never a path/shell). */
  readonly command: string;
  /** Fixed arguments; no user input is ever appended. */
  readonly args: readonly string[];
  /** Stream carrying the version banner. */
  readonly versionStream: VersionStream;
}

/**
 * The frozen allowlist. Order is stable and mirrors the contract cliName enum.
 * Adding a CLI is a minor, contract-compatible change (enum extension).
 */
export const ALLOWLIST = [
  { name: "node", command: "node", args: ["--version"], versionStream: "stdout" },
  { name: "npm", command: "npm", args: ["--version"], versionStream: "stdout" },
  { name: "pnpm", command: "pnpm", args: ["--version"], versionStream: "stdout" },
  { name: "yarn", command: "yarn", args: ["--version"], versionStream: "stdout" },
  { name: "bun", command: "bun", args: ["--version"], versionStream: "stdout" },
  { name: "deno", command: "deno", args: ["--version"], versionStream: "stdout" },
  { name: "git", command: "git", args: ["--version"], versionStream: "stdout" },
  { name: "gh", command: "gh", args: ["--version"], versionStream: "stdout" },
  { name: "python3", command: "python3", args: ["--version"], versionStream: "stdout" },
  { name: "go", command: "go", args: ["--version"], versionStream: "stdout" },
  { name: "rustc", command: "rustc", args: ["--version"], versionStream: "stdout" },
  { name: "cargo", command: "cargo", args: ["--version"], versionStream: "stdout" },
  { name: "java", command: "java", args: ["-version"], versionStream: "stderr" },
  { name: "docker", command: "docker", args: ["--version"], versionStream: "stdout" },
] as const satisfies readonly AllowlistEntry[];

/** Set of valid CLI names for O(1) membership checks in the tool layer. */
export const ALLOWLIST_NAMES: ReadonlySet<CliName> = new Set(ALLOWLIST.map((e) => e.name));
