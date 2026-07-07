/**
 * owner/repo resolution (REQ-007, OQ-001). NO exec.
 *
 * OQ-001 resolution (recorded in full in
 * reports/implementation/ci-mcp/T-004.md): the canonical priority is
 * explicit `owner`/`repo` tool arguments (both required together) first;
 * otherwise fall back to the `CI_MCP_REPO` environment variable in
 * `owner/repo` form; if neither resolves to a valid pair, return
 * `invalid-input`.
 *
 * This module NEVER execs a subprocess and NEVER reads a git remote — it
 * imports nothing from Node's subprocess-spawning module anywhere in this
 * file (statically verified by tests/repo-resolve/no-exec.test.ts), matching
 * the Non-goal in design.md/security-spec.md that ci-mcp must not shell out
 * to `git`.
 *
 * The returned `owner`/`repo` are passed to `github-client.ts` as URL PATH
 * elements only (each individually percent-encoded and joined onto the
 * fixed `https://api.github.com` host) — nothing returned from here can
 * substitute the host, so this module's job is limited to validating that
 * `owner`/`repo` look like GitHub-style names before they ever reach that
 * boundary (security-spec.md B2 SSRF control; defense-in-depth alongside the
 * host-fixing in github-client.ts, which is the primary control).
 */

import { err, ok, type Result } from "./envelope.js";

export interface RepoResolveArgs {
  owner?: string;
  repo?: string;
}

export interface ResolvedRepo {
  owner: string;
  repo: string;
}

// Conservative GitHub-style name allowlists. These exist as defense-in-depth
// input validation (REQ-007, security-spec.md B1) — the SSRF-relevant
// guarantee (host cannot be substituted) is already enforced by
// github-client.ts's fixed base URL + per-segment percent-encoding
// regardless of what strings pass validation here.
const OWNER_PATTERN = /^[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?$/; // 1-39 chars, no leading/trailing hyphen
const REPO_PATTERN = /^[A-Za-z0-9_.-]{1,100}$/; // 1-100 chars

function isValidOwner(value: string): boolean {
  return OWNER_PATTERN.test(value);
}

function isValidRepo(value: string): boolean {
  if (value === "." || value === "..") {
    return false;
  }
  return REPO_PATTERN.test(value);
}

/** Treats an empty/whitespace-only string the same as "not provided". */
function normalize(value: string | undefined): string | undefined {
  const trimmed = value?.trim();
  return trimmed === undefined || trimmed.length === 0 ? undefined : trimmed;
}

/** Parses `CI_MCP_REPO`'s `owner/repo` form. Exactly one slash, both parts valid. */
function parseEnvRepo(value: string): ResolvedRepo | undefined {
  const parts = value.split("/");
  if (parts.length !== 2) {
    return undefined;
  }
  const [owner, repo] = parts;
  if (!owner || !repo || !isValidOwner(owner) || !isValidRepo(repo)) {
    return undefined;
  }
  return { owner, repo };
}

/**
 * Resolves the target owner/repo (OQ-001 canonical priority):
 *
 * 1. Explicit `owner`/`repo` tool arguments, when BOTH are provided — this
 *    branch never falls back to `CI_MCP_REPO`, even if the explicit values
 *    fail validation (a caller who names a repo explicitly gets a direct
 *    `invalid-input`, not a silent substitution).
 * 2. `CI_MCP_REPO` (`owner/repo` form), when no explicit arguments were
 *    given.
 * 3. `invalid-input` when neither resolves.
 *
 * Never execs; never reads a git remote. Never throws.
 */
export function resolveRepo(
  args: RepoResolveArgs,
  env: NodeJS.ProcessEnv = process.env,
): Result<ResolvedRepo> {
  const owner = normalize(args.owner);
  const repo = normalize(args.repo);

  if (owner !== undefined || repo !== undefined) {
    if (owner === undefined || repo === undefined) {
      return err(
        "invalid-input",
        "Both owner and repo must be provided together as explicit tool arguments.",
      );
    }
    if (!isValidOwner(owner) || !isValidRepo(repo)) {
      return err(
        "invalid-input",
        "owner/repo contain characters outside the allowed GitHub naming charset.",
      );
    }
    return ok({ owner, repo });
  }

  const envRepo = normalize(env.CI_MCP_REPO);
  if (envRepo !== undefined) {
    const parsed = parseEnvRepo(envRepo);
    if (parsed === undefined) {
      return err(
        "invalid-input",
        "CI_MCP_REPO must be in the form owner/repo using valid GitHub-style names.",
      );
    }
    return ok(parsed);
  }

  return err(
    "invalid-input",
    "No target repository resolved: pass explicit owner/repo tool arguments or set CI_MCP_REPO.",
  );
}
