/**
 * Read-only GitHub token resolution (REQ-005, OQ-004).
 *
 * OQ-004 resolution (recorded in full in
 * reports/implementation/ci-mcp/T-003.md): the token-variable priority order
 * is `CI_MCP_GITHUB_TOKEN` -> `GH_READONLY_TOKEN` -> `GITHUB_TOKEN`, first
 * non-empty value wins. Token values are read ONLY from these environment
 * variables — never via `gh` CLI invocation or any other exec path.
 *
 * `resolveToken` never throws and never terminates the process; when no
 * variable resolves to a non-empty value it returns the `auth-missing`
 * envelope. `withToken` is the shared gate every ci-mcp tool handler routes
 * through (starting at T-005's `tools/actions.ts`): it resolves the token
 * first and only invokes the handler when one was found, so a missing token
 * short-circuits to `auth-missing` without ever calling GitHub or doing any
 * other work (AC-008).
 *
 * Token values are NEVER written to any response, diagnostic, or error
 * message/details by this module — the only place a resolved token flows to
 * is `github-client.ts`'s `Authorization: Bearer <token>` header attachment,
 * which itself never logs or echoes it (see github-client.ts module docs).
 */

import { err, isOk, ok, type Result } from "./envelope.js";

/** Token env-var priority order (OQ-004, first non-empty value wins). */
export const TOKEN_ENV_PRIORITY = ["CI_MCP_GITHUB_TOKEN", "GH_READONLY_TOKEN", "GITHUB_TOKEN"] as const;

export interface ResolvedToken {
  token: string;
}

/**
 * Resolves a read-only GitHub token from `env` following the OQ-004 priority
 * order. Returns `auth-missing` when none of the 3 variables holds a
 * non-empty value. Never throws.
 */
export function resolveToken(env: NodeJS.ProcessEnv = process.env): Result<ResolvedToken> {
  for (const name of TOKEN_ENV_PRIORITY) {
    const value = env[name];
    if (typeof value === "string" && value.length > 0) {
      return ok({ token: value });
    }
  }
  return err(
    "auth-missing",
    "No GitHub token found. Set one of CI_MCP_GITHUB_TOKEN, GH_READONLY_TOKEN, or GITHUB_TOKEN.",
  );
}

/**
 * Resolves a token and, only if one was found, invokes `handler` with it.
 * This is the single gate every ci-mcp tool routes through: when the token
 * is missing, `handler` is never called (no GitHub call, no other side
 * effect) and the caller gets the `auth-missing` envelope back — the process
 * itself is never terminated (REQ-005, AC-008).
 */
export async function withToken<T>(
  handler: (token: string) => Promise<Result<T>> | Result<T>,
  env: NodeJS.ProcessEnv = process.env,
): Promise<Result<T>> {
  const resolved = resolveToken(env);
  if (!isOk(resolved)) {
    return resolved;
  }
  return handler(resolved.data.token);
}
