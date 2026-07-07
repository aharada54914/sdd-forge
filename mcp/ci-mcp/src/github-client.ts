/**
 * GET-only GitHub Actions REST API client (REQ-001, REQ-003, REQ-006).
 *
 * The host is fixed to `https://api.github.com` — no caller input can change
 * it. Every request URL is built by percent-encoding each of `pathSegments`
 * individually and joining them onto that hardcoded base, so no segment can
 * inject a new scheme/host (`:` and `/` are both percent-encoded by
 * `encodeURIComponent`) or escape into a different path. Only the GET method
 * is ever issued: there is no parameter through which a caller could select
 * POST/PUT/PATCH/DELETE (`GithubFetch`'s `init.method` type is the literal
 * `"GET"`).
 *
 * `token`, when provided, is attached as `Authorization: Bearer <token>` and
 * is never logged, echoed, or included in any error output (T-003 owns full
 * token-resolution + scrubbing; this module only ever forwards a token it
 * was explicitly given as a parameter). Upstream error responses are
 * normalized via `error-normalizer.ts`; the upstream response BODY is never
 * read on an error path and is never copied into a returned envelope
 * (REQ-006).
 */

import { err, type ErrorEnvelope } from "./envelope.js";
import { normalizeNetworkError, normalizeUpstreamResponse } from "./error-normalizer.js";

/** Host is fixed; no request can override it (SSRF boundary, security-spec.md B2). */
const GITHUB_API_BASE_URL = "https://api.github.com";

/** Minimal response shape github-client needs; satisfied structurally by the global Fetch API's `Response`. */
export interface GithubHttpResponse {
  readonly status: number;
  readonly headers: { get(name: string): string | null };
  json(): Promise<unknown>;
}

/** Fetch-shaped function github-client calls. Only ever invoked with `method: "GET"`. */
export type GithubFetch = (
  url: string,
  init: { readonly method: "GET"; readonly headers: Readonly<Record<string, string>> },
) => Promise<GithubHttpResponse>;

export interface GithubGetRequest {
  /**
   * URL path segments (e.g. `["repos", owner, repo, "actions", "runs"]`).
   * Each segment is percent-encoded individually and joined with "/" onto
   * the fixed `GITHUB_API_BASE_URL` — a segment can never introduce a new
   * host, scheme, or unescaped path separator.
   */
  pathSegments: readonly string[];
  /** Optional query-string parameters. `undefined` values are omitted. */
  searchParams?: Readonly<Record<string, string | number | boolean | undefined>>;
  /** Read-only GitHub token. When provided, sent as `Authorization: Bearer <token>` only — never logged or echoed. */
  token?: string;
}

export type GithubGetOutcome<T> = { ok: true; data: T } | ErrorEnvelope;

/** Builds the fixed-host request URL. `pathSegments` cannot alter the host (see module docs). */
function buildGithubUrl(
  pathSegments: readonly string[],
  searchParams?: Readonly<Record<string, string | number | boolean | undefined>>,
): string {
  const encodedPath = pathSegments.map((segment) => encodeURIComponent(segment)).join("/");
  const url = new URL(`${GITHUB_API_BASE_URL}/${encodedPath}`);
  if (searchParams) {
    for (const [key, value] of Object.entries(searchParams)) {
      if (value !== undefined) {
        url.searchParams.set(key, String(value));
      }
    }
  }
  return url.toString();
}

const defaultFetch: GithubFetch = (url, init) => fetch(url, init);

/**
 * Issues a single GET request against the GitHub Actions REST API and
 * resolves to either `{ ok: true, data }` (the parsed JSON body) or a
 * normalized error envelope (REQ-006). The upstream response body is
 * discarded on every error path — it is never attached to the returned
 * envelope.
 */
export async function githubGet<T>(
  request: GithubGetRequest,
  fetchImpl: GithubFetch = defaultFetch,
): Promise<GithubGetOutcome<T>> {
  const url = buildGithubUrl(request.pathSegments, request.searchParams);
  const headers: Record<string, string> = { accept: "application/vnd.github+json" };
  if (request.token !== undefined && request.token.length > 0) {
    headers.authorization = `Bearer ${request.token}`;
  }

  let response: GithubHttpResponse;
  try {
    response = await fetchImpl(url, { method: "GET", headers });
  } catch (error) {
    return normalizeNetworkError(error);
  }

  const normalized = normalizeUpstreamResponse({
    status: response.status,
    getHeader: (name) => response.headers.get(name),
  });
  if (normalized !== undefined) {
    return normalized;
  }

  try {
    const data = (await response.json()) as T;
    return { ok: true, data };
  } catch {
    return err("upstream-error", "Failed to parse the GitHub API response body.");
  }
}
