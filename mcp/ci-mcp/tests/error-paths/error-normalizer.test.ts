/**
 * AC-010 / AC-011 (TEST-010 / TEST-011): REQ-006 deterministic upstream-error
 * normalization, unit-level.
 *
 * Every branch of the mapping table is exercised directly against
 * `normalizeUpstreamResponse` / `normalizeNetworkError`:
 *   401                                            -> auth-missing (details.status: 401)
 *   403 + rate-limit indicator (x-ratelimit-remaining: 0) -> rate-limited
 *   403 + rate-limit indicator (retry-after)              -> rate-limited
 *   403 without indicator                          -> upstream-error (details.status: 403)
 *   404                                            -> not-found
 *   429                                            -> rate-limited
 *   5xx                                            -> upstream-error
 *   network failure                                -> upstream-error
 *   2xx                                            -> undefined (not an error)
 *
 * AC-011: rate-limited `details` carries only non-sensitive metadata (a
 * derived ISO reset time) — never a token, and malformed/missing reset
 * headers are handled gracefully (details omits the field rather than
 * forwarding a raw header value).
 */

import { test } from "node:test";
import assert from "node:assert/strict";

import { normalizeNetworkError, normalizeUpstreamResponse } from "../../src/error-normalizer.js";
import type { UpstreamResponseInfo } from "../../src/error-normalizer.js";

function response(status: number, headers: Record<string, string> = {}): UpstreamResponseInfo {
  const lower = new Map(Object.entries(headers).map(([k, v]) => [k.toLowerCase(), v]));
  return {
    status,
    getHeader: (name: string) => lower.get(name.toLowerCase()) ?? null,
  };
}

test("401 always maps to auth-missing with details.status:401, never upstream-error", () => {
  const result = normalizeUpstreamResponse(response(401));
  assert.ok(result !== undefined);
  assert.equal(result.error.code, "auth-missing");
  assert.deepEqual(result.error.details, { status: 401 });
});

test("403 with x-ratelimit-remaining:0 maps to rate-limited", () => {
  const result = normalizeUpstreamResponse(response(403, { "x-ratelimit-remaining": "0" }));
  assert.ok(result !== undefined);
  assert.equal(result.error.code, "rate-limited");
});

test("403 with retry-after maps to rate-limited", () => {
  const result = normalizeUpstreamResponse(response(403, { "retry-after": "30" }));
  assert.ok(result !== undefined);
  assert.equal(result.error.code, "rate-limited");
});

test("403 without any rate-limit indicator maps to upstream-error with details.status:403 (never path-denied)", () => {
  const result = normalizeUpstreamResponse(response(403));
  assert.ok(result !== undefined);
  assert.equal(result.error.code, "upstream-error");
  assert.deepEqual(result.error.details, { status: 403 });
  assert.notEqual(result.error.code, "path-denied");
});

test("404 maps to not-found", () => {
  const result = normalizeUpstreamResponse(response(404));
  assert.ok(result !== undefined);
  assert.equal(result.error.code, "not-found");
});

test("429 maps to rate-limited", () => {
  const result = normalizeUpstreamResponse(response(429));
  assert.ok(result !== undefined);
  assert.equal(result.error.code, "rate-limited");
});

test("5xx maps to upstream-error", () => {
  for (const status of [500, 502, 503]) {
    const result = normalizeUpstreamResponse(response(status));
    assert.ok(result !== undefined, `status ${status} should be an error`);
    assert.equal(result.error.code, "upstream-error");
    assert.deepEqual(result.error.details, { status });
  }
});

test("2xx is not an error (returns undefined)", () => {
  for (const status of [200, 201, 204]) {
    const result = normalizeUpstreamResponse(response(status));
    assert.equal(result, undefined, `status ${status} should not be an error`);
  }
});

test("network failure maps to upstream-error", () => {
  const result = normalizeNetworkError(new Error("getaddrinfo ENOTFOUND api.github.com"));
  assert.equal(result.error.code, "upstream-error");
});

test("AC-011: rate-limited details carry only a non-sensitive reset time, never a token", () => {
  const resetEpochSeconds = Math.floor(Date.now() / 1000) + 60;
  const result = normalizeUpstreamResponse(
    response(429, { "x-ratelimit-reset": String(resetEpochSeconds) }),
  );
  assert.ok(result !== undefined);
  assert.equal(result.error.code, "rate-limited");
  assert.ok(result.error.details !== undefined);
  const details = result.error.details as Record<string, unknown>;
  assert.equal(typeof details.rateLimitResetAt, "string");
  assert.equal(
    new Date(details.rateLimitResetAt as string).toISOString(),
    new Date(resetEpochSeconds * 1000).toISOString(),
  );
  // No property anywhere on details may carry a token-shaped or Authorization value.
  for (const value of Object.values(details)) {
    assert.equal(typeof value === "string" && /bearer|ghp_|github_pat_/i.test(value), false);
  }
});

test("AC-011: malformed x-ratelimit-reset header is ignored (details omits the field, still rate-limited)", () => {
  const result = normalizeUpstreamResponse(response(429, { "x-ratelimit-reset": "not-a-number" }));
  assert.ok(result !== undefined);
  assert.equal(result.error.code, "rate-limited");
  assert.deepEqual(result.error.details, { status: 429 });
});

test("error message strings are fixed and non-sensitive (never echo header/body content)", () => {
  const secretLikeHeader = "ghp_verysecrettoken1234567890";
  const result = normalizeUpstreamResponse(
    response(403, { "x-ratelimit-remaining": "0", "x-ratelimit-reset": secretLikeHeader }),
  );
  assert.ok(result !== undefined);
  assert.ok(!result.error.message.includes(secretLikeHeader));
  assert.ok(!JSON.stringify(result.error.details ?? {}).includes(secretLikeHeader));
});
