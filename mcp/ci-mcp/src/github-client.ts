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
 *
 * `githubGetText` (T-013 addition) is a sibling of `githubGet` for the one
 * ci-mcp endpoint whose 2xx body is plain text, not JSON (`get_job_log`'s
 * upstream job-log endpoint). It mirrors `githubGet`'s host-fixing,
 * GET-only method, token-header attachment, and error-normalization
 * exactly. GitHub's actual job-log endpoint responds with a 302 redirect to
 * temporary blob storage; ordinary `fetch` follows redirects by default, so
 * the injected fetch-shaped function here is expected to already return the
 * final plain-text response, the same convention `GithubFetch` uses.
 *
 * T-013 cycle-2 (evaluator Major, security-spec.md B2 "リングバッファ +
 * 256 KiB 上限(末尾優先)"): reading the whole upstream body via `.text()`
 * before truncating materialized the entire job log in memory, unbounded.
 * `githubGetText` now reads a 2xx body via `readBoundedTail`, a bounded
 * streaming reader that consumes `response.body` (the Web ReadableStream
 * every real `fetch` `Response` exposes) chunk-by-chunk and retains only a
 * tail window bounded by `TAIL_READ_CAP_BYTES + TAIL_READ_MARGIN_BYTES` —
 * memory never scales with the full upstream body size. The margin exists
 * so `tools/actions.ts`'s `truncateLogTail` (which still owns the final,
 * byte-exact, UTF-8-boundary-safe cut to <= 262144 bytes) always has enough
 * slack above the cap to find a safe character boundary without needing to
 * re-read anything. When a caller's `fetchImpl` returns a response with no
 * `body` (e.g. some hand-written test fakes), `githubGetText` falls back to
 * `.text()` — that fallback path is not memory-bounded, but it is only ever
 * reachable when the injected fetch-shaped function itself did not provide a
 * stream; the real `defaultTextFetch` (`fetch`) always does.
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

/**
 * Minimal text-bodied response shape `githubGetText` needs; satisfied
 * structurally by the global Fetch API's `Response`. `body` is optional so
 * hand-written test fakes that only implement `.text()` still typecheck —
 * `githubGetText` uses `body` (a Web `ReadableStream<Uint8Array>`) as its
 * primary, memory-bounded read path and falls back to `.text()` only when
 * `body` is absent.
 */
export interface GithubTextHttpResponse {
  readonly status: number;
  readonly headers: { get(name: string): string | null };
  readonly body?: ReadableStream<Uint8Array> | null;
  text(): Promise<string>;
}

/** 256 KiB tail cap on a job log's returned bytes (security-spec.md B2, REQ-008 / AC-004). */
export const TAIL_READ_CAP_BYTES = 262144;

/**
 * Extra slack retained above `TAIL_READ_CAP_BYTES` while streaming, so the
 * downstream UTF-8-safe boundary trim (`tools/actions.ts`'s
 * `truncateLogTail`) always has room to advance past a split multi-byte
 * character without ever needing to read further bytes itself.
 */
export const TAIL_READ_MARGIN_BYTES = 65536;

/** Result of a bounded tail read (see `readBoundedTail`). */
export interface BoundedTailReadResult {
  /** The retained tail bytes — bounded, never the full body for large inputs. */
  readonly bytes: Uint8Array;
  /** Total bytes actually consumed off the stream (may exceed `bytes.byteLength` when eviction occurred). */
  readonly totalBytesRead: number;
  /**
   * The largest number of bytes ever held in the retention buffer at once
   * during this read. Exposed (not just internally tracked) so regression
   * tests can assert memory-boundedness directly instead of only inferring
   * it from the final output size.
   */
  readonly maxRetainedBytes: number;
}

/**
 * Reads `stream` chunk-by-chunk, retaining only a tail window bounded by
 * `capBytes + marginBytes` at the BYTE level, not just the whole-chunk
 * level. Two eviction paths keep the retention buffer bounded regardless of
 * how the upstream body happens to be chunked:
 *
 *   1. A chunk that is itself larger than `capBytes + marginBytes` (e.g. a
 *      redirected log delivered as one big `Uint8Array`) is sliced down to
 *      its own trailing `capBytes + marginBytes` bytes BEFORE it enters the
 *      deque, and — since a chunk that large can only ever leave its own
 *      tail standing — anything retained from earlier chunks is dropped at
 *      the same time.
 *   2. After every chunk is appended, the FRONT of the deque is trimmed at
 *      the byte level (slicing the oldest remaining chunk when only part of
 *      it needs to go, rather than only evicting whole chunks) until
 *      `retainedBytes` is back at or under the threshold.
 *
 * Tail-priority is preserved throughout (the END of the stream always
 * survives), `totalBytesRead` still counts the true total regardless of
 * eviction, and `maxRetainedBytes` reflects the truly bounded peak — it
 * never exceeds `capBytes + marginBytes` (security-spec.md B2 ring-buffer
 * mitigation; REQ-008 / AC-004 / TEST-004; Codex review, PR #98).
 */
export async function readBoundedTail(
  stream: ReadableStream<Uint8Array>,
  capBytes: number,
  marginBytes: number,
): Promise<BoundedTailReadResult> {
  const threshold = capBytes + marginBytes;
  const chunks: Uint8Array[] = [];
  let retainedBytes = 0;
  let totalBytesRead = 0;
  let maxRetainedBytes = 0;

  const reader = stream.getReader();
  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) {
        break;
      }
      if (value === undefined || value.byteLength === 0) {
        continue;
      }
      totalBytesRead += value.byteLength;

      // A single chunk larger than the whole retention window can never be
      // fully retained no matter what else is evicted — slice it down to
      // its own tail up front (tail-priority), and since it alone already
      // fills (or exceeds) the window, everything retained so far is
      // superseded.
      let incoming = value;
      if (incoming.byteLength > threshold) {
        incoming = incoming.subarray(incoming.byteLength - threshold);
        chunks.length = 0;
        retainedBytes = 0;
      }

      chunks.push(incoming);
      retainedBytes += incoming.byteLength;

      // Byte-level front trim: shrink or drop the oldest chunk(s) until the
      // retained window is back at or under the threshold. This bounds
      // `retainedBytes` exactly, instead of only bounding it to "at least
      // one whole chunk over threshold" the way whole-chunk-only eviction
      // does.
      while (retainedBytes > threshold && chunks.length > 0) {
        const oldest = chunks[0]!;
        const excess = retainedBytes - threshold;
        if (excess >= oldest.byteLength) {
          chunks.shift();
          retainedBytes -= oldest.byteLength;
        } else {
          chunks[0] = oldest.subarray(excess);
          retainedBytes -= excess;
        }
      }

      if (retainedBytes > maxRetainedBytes) {
        maxRetainedBytes = retainedBytes;
      }
    }
  } finally {
    reader.releaseLock();
  }

  const bytes = new Uint8Array(retainedBytes);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }

  return { bytes, totalBytesRead, maxRetainedBytes };
}

/** Fetch-shaped function `githubGetText` calls. Only ever invoked with `method: "GET"`. */
export type GithubTextFetch = (
  url: string,
  init: { readonly method: "GET"; readonly headers: Readonly<Record<string, string>> },
) => Promise<GithubTextHttpResponse>;

export type GithubGetTextOutcome =
  | {
      ok: true;
      data: string;
      /**
       * Total bytes actually present in the upstream body, even when `data`
       * itself was already reduced to a bounded tail window. Callers (e.g.
       * `tools/actions.ts`'s `get_job_log`) compare this against their own
       * final returned-byte count to determine `truncated` — the source was
       * longer than what is returned iff `totalBytesRead > returnedBytes`.
       */
      totalBytesRead: number;
    }
  | ErrorEnvelope;

const defaultTextFetch: GithubTextFetch = (url, init) => fetch(url, init);

/**
 * Issues a single GET request against the GitHub Actions REST API and
 * resolves to either `{ ok: true, data, totalBytesRead }` (a possibly
 * tail-bounded slice of the 2xx body, plus how many bytes the upstream body
 * actually had) or a normalized error envelope (REQ-006). Identical
 * host-fixing, GET-only, token-header, and error-normalization behavior to
 * `githubGet` — errors are detected from `status` before any body is read,
 * exactly as before.
 *
 * The successful body is read via `readBoundedTail` against
 * `response.body` (a Web `ReadableStream<Uint8Array>`) whenever the response
 * exposes one — this is the primary, memory-bounded path (T-013 cycle-2; see
 * module doc comment). Only when `response.body` is absent does this fall
 * back to `.text()`. The upstream response body is discarded on every error
 * path, same as `githubGet`.
 */
export async function githubGetText(
  request: GithubGetRequest,
  fetchImpl: GithubTextFetch = defaultTextFetch,
): Promise<GithubGetTextOutcome> {
  const url = buildGithubUrl(request.pathSegments, request.searchParams);
  const headers: Record<string, string> = { accept: "text/plain" };
  if (request.token !== undefined && request.token.length > 0) {
    headers.authorization = `Bearer ${request.token}`;
  }

  let response: GithubTextHttpResponse;
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
    if (response.body != null) {
      const { bytes, totalBytesRead } = await readBoundedTail(
        response.body,
        TAIL_READ_CAP_BYTES,
        TAIL_READ_MARGIN_BYTES,
      );
      return { ok: true, data: Buffer.from(bytes.buffer, bytes.byteOffset, bytes.byteLength).toString("utf-8"), totalBytesRead };
    }
    const data = await response.text();
    return { ok: true, data, totalBytesRead: Buffer.byteLength(data, "utf-8") };
  } catch {
    return err("upstream-error", "Failed to read the GitHub API response body.");
  }
}
