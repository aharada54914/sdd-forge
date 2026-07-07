/**
 * REQ-006 deterministic upstream-error normalization.
 *
 * Maps a GitHub Actions REST API HTTP response (status + headers) or a
 * network-level failure to one of ci-mcp's error envelopes:
 *
 *   401                                              -> auth-missing   (details.status: 401)
 *   403 + rate-limit indicator (x-ratelimit-remaining: 0 or retry-after) -> rate-limited
 *   403 without indicator                            -> upstream-error (details.status: 403)
 *   404                                               -> not-found
 *   429                                               -> rate-limited
 *   5xx / network failure                             -> upstream-error
 *
 * `path-denied` is reserved for local input-guard use only (sdd-forge-mcp /
 * local-env-mcp convention) and is never produced here for an upstream 403.
 *
 * The upstream response BODY is never read or forwarded by this module —
 * only status and a small, fixed set of headers are inspected. Returned
 * `details` carry only non-sensitive, derived metadata (HTTP status, and for
 * rate-limited responses a derived ISO-8601 reset time) — never a token,
 * an `Authorization` value, or a raw header/body value.
 */

import { err, type ErrorEnvelope } from "./envelope.js";

/** The subset of an upstream HTTP response needed to normalize its error. */
export interface UpstreamResponseInfo {
  status: number;
  /** Case-insensitive header getter (the Fetch API's `Headers#get` satisfies this). */
  getHeader: (name: string) => string | null;
}

/** True when the response carries a GitHub rate-limit indicator (REQ-006). */
function hasRateLimitIndicator(response: UpstreamResponseInfo): boolean {
  const remaining = response.getHeader("x-ratelimit-remaining");
  const retryAfter = response.getHeader("retry-after");
  return remaining === "0" || (retryAfter !== null && retryAfter.trim().length > 0);
}

/**
 * Derives a non-sensitive ISO-8601 rate-limit reset time from response
 * headers, if one can be computed. Malformed or missing headers yield
 * `undefined` rather than forwarding a raw header value.
 */
function rateLimitResetAt(response: UpstreamResponseInfo): string | undefined {
  const resetHeader = response.getHeader("x-ratelimit-reset");
  if (resetHeader !== null) {
    const resetEpochSeconds = Number(resetHeader);
    if (Number.isFinite(resetEpochSeconds) && resetEpochSeconds > 0) {
      return new Date(resetEpochSeconds * 1000).toISOString();
    }
  }
  const retryAfterHeader = response.getHeader("retry-after");
  if (retryAfterHeader !== null) {
    const retryAfterSeconds = Number(retryAfterHeader);
    if (Number.isFinite(retryAfterSeconds) && retryAfterSeconds >= 0) {
      return new Date(Date.now() + retryAfterSeconds * 1000).toISOString();
    }
  }
  return undefined;
}

function rateLimitedError(status: number, response: UpstreamResponseInfo): ErrorEnvelope {
  const resetAt = rateLimitResetAt(response);
  return err(
    "rate-limited",
    "GitHub API rate limit reached.",
    resetAt === undefined ? { status } : { status, rateLimitResetAt: resetAt },
  );
}

/**
 * Normalizes an upstream GitHub Actions REST API HTTP response into a ci-mcp
 * error envelope (REQ-006). Returns `undefined` for a 2xx status — the
 * caller should treat that as success, not an error.
 */
export function normalizeUpstreamResponse(response: UpstreamResponseInfo): ErrorEnvelope | undefined {
  const { status } = response;

  if (status >= 200 && status < 300) {
    return undefined;
  }

  if (status === 401) {
    return err("auth-missing", "GitHub API rejected the request: unauthorized.", { status: 401 });
  }

  if (status === 403) {
    if (hasRateLimitIndicator(response)) {
      return rateLimitedError(403, response);
    }
    return err("upstream-error", "GitHub API rejected the request: forbidden.", { status: 403 });
  }

  if (status === 404) {
    return err("not-found", "The requested GitHub resource was not found.", { status: 404 });
  }

  if (status === 429) {
    return rateLimitedError(429, response);
  }

  if (status >= 500) {
    return err("upstream-error", "GitHub API returned a server error.", { status });
  }

  // Any other unexpected non-2xx status is treated conservatively as an
  // upstream error rather than guessed.
  return err("upstream-error", "GitHub API returned an unexpected status.", { status });
}

/** Normalizes a network-level failure (DNS, connection refused, timeout, abort) to `upstream-error`. */
export function normalizeNetworkError(_error: unknown): ErrorEnvelope {
  return err("upstream-error", "Network failure while calling the GitHub API.");
}
