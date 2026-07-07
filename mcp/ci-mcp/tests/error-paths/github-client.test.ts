/**
 * AC-010 (TEST-010): github-client integration with an injected fake fetch
 * (no real network, per REQ-013 / design.md Test Strategy). Also covers the
 * GET-fixed / host-fixed unit requirement from T-002 Done When, token header
 * attachment, and the "upstream response body never copied into the
 * envelope" guarantee (REQ-006).
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import { githubGet } from "../../src/github-client.js";
import type { GithubFetch, GithubHttpResponse } from "../../src/github-client.js";

const UPSTREAM_BODY_SECRET = "UPSTREAM-BODY-MARKER-do-not-leak-9f3b2a";

interface FakeResponseSpec {
  status: number;
  headers?: Record<string, string>;
  body?: unknown;
}

function fakeResponse(spec: FakeResponseSpec): GithubHttpResponse {
  const lower = new Map(Object.entries(spec.headers ?? {}).map(([k, v]) => [k.toLowerCase(), v]));
  return {
    status: spec.status,
    headers: { get: (name: string) => lower.get(name.toLowerCase()) ?? null },
    json: async () => spec.body ?? {},
  };
}

/** Records every call made through the fake fetch for assertion. */
interface RecordedCall {
  url: string;
  method: string;
  headers: Readonly<Record<string, string>>;
}

function makeFakeFetch(spec: FakeResponseSpec): { fetchImpl: GithubFetch; calls: RecordedCall[] } {
  const calls: RecordedCall[] = [];
  const fetchImpl: GithubFetch = async (url, init) => {
    calls.push({ url, method: init.method, headers: init.headers });
    return fakeResponse(spec);
  };
  return { fetchImpl, calls };
}

test("GET is the only HTTP method ever issued, host is fixed to api.github.com", async () => {
  const { fetchImpl, calls } = makeFakeFetch({ status: 200, body: { ok: true } });
  await githubGet({ pathSegments: ["repos", "acme", "widgets", "actions", "runs"] }, fetchImpl);

  assert.equal(calls.length, 1);
  assert.equal(calls[0]?.method, "GET");
  assert.ok(calls[0]?.url.startsWith("https://api.github.com/"), `url was ${calls[0]?.url}`);
});

test("path segments cannot change the host even when they look like a host or contain separators", async () => {
  const { fetchImpl, calls } = makeFakeFetch({ status: 200, body: {} });
  await githubGet(
    { pathSegments: ["repos", "evil.com", "..%2f..%2fattacker", "actions", "runs"] },
    fetchImpl,
  );

  const url = new URL(calls[0]?.url ?? "");
  assert.equal(url.host, "api.github.com");
  assert.equal(url.protocol, "https:");
});

test("no other HTTP method literal (POST/PUT/PATCH/DELETE) appears in github-client.ts source", () => {
  // Compiled location: dist-test/tests/error-paths/. tsconfig.test.json
  // compiles with rootDir "." so dist-test mirrors the whole package layout
  // (dist-test/src/*.js, dist-test/tests/*.js) — walk up 3 levels
  // (error-paths -> tests -> dist-test) to the ci-mcp package root, then into
  // the REAL (uncompiled) src/github-client.ts.
  const SRC_PATH = join(
    dirname(fileURLToPath(import.meta.url)),
    "..",
    "..",
    "..",
    "src",
    "github-client.ts",
  );
  const source = readFileSync(SRC_PATH, "utf-8");
  for (const method of ["POST", "PUT", "PATCH", "DELETE"]) {
    assert.ok(!source.includes(`"${method}"`), `github-client.ts must never reference HTTP method "${method}"`);
  }
});

test("Authorization header is attached only when a token is provided", async () => {
  const withToken = makeFakeFetch({ status: 200, body: {} });
  await githubGet({ pathSegments: ["rate_limit"], token: "ghp_exampletoken" }, withToken.fetchImpl);
  assert.equal(withToken.calls[0]?.headers.authorization, "Bearer ghp_exampletoken");

  const withoutToken = makeFakeFetch({ status: 200, body: {} });
  await githubGet({ pathSegments: ["rate_limit"] }, withoutToken.fetchImpl);
  assert.equal("authorization" in withoutToken.calls[0]!.headers, false);
});

test("successful 2xx response resolves to ok:true with the parsed body", async () => {
  const { fetchImpl } = makeFakeFetch({ status: 200, body: { kind: "workflow-runs", runs: [] } });
  const result = await githubGet<{ kind: string }>({ pathSegments: ["repos", "a", "b"] }, fetchImpl);
  assert.equal(result.ok, true);
  if (result.ok) {
    assert.equal(result.data.kind, "workflow-runs");
  }
});

const ERROR_BRANCHES: Array<{ name: string; spec: FakeResponseSpec; expectedCode: string }> = [
  { name: "401", spec: { status: 401, body: { message: UPSTREAM_BODY_SECRET } }, expectedCode: "auth-missing" },
  {
    name: "403 with rate-limit indicator",
    spec: { status: 403, headers: { "x-ratelimit-remaining": "0" }, body: { message: UPSTREAM_BODY_SECRET } },
    expectedCode: "rate-limited",
  },
  {
    name: "403 without indicator",
    spec: { status: 403, body: { message: UPSTREAM_BODY_SECRET } },
    expectedCode: "upstream-error",
  },
  { name: "404", spec: { status: 404, body: { message: UPSTREAM_BODY_SECRET } }, expectedCode: "not-found" },
  { name: "429", spec: { status: 429, body: { message: UPSTREAM_BODY_SECRET } }, expectedCode: "rate-limited" },
  { name: "500", spec: { status: 500, body: { message: UPSTREAM_BODY_SECRET } }, expectedCode: "upstream-error" },
  { name: "503", spec: { status: 503, body: { message: UPSTREAM_BODY_SECRET } }, expectedCode: "upstream-error" },
];

for (const branch of ERROR_BRANCHES) {
  test(`AC-010: ${branch.name} maps deterministically to ${branch.expectedCode} and never leaks the upstream body`, async () => {
    const { fetchImpl } = makeFakeFetch(branch.spec);
    const result = await githubGet({ pathSegments: ["repos", "a", "b", "actions", "runs"] }, fetchImpl);
    assert.equal(result.ok, false);
    if (!result.ok) {
      assert.equal(result.error.code, branch.expectedCode);
      assert.ok(
        !JSON.stringify(result).includes(UPSTREAM_BODY_SECRET),
        "upstream response body must never be copied into the envelope",
      );
    }
  });
}

test("AC-010: network failure (fetch throws) maps to upstream-error", async () => {
  const throwingFetch: GithubFetch = async () => {
    throw new Error("getaddrinfo ENOTFOUND api.github.com");
  };
  const result = await githubGet({ pathSegments: ["repos", "a", "b"] }, throwingFetch);
  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.code, "upstream-error");
  }
});

test("a non-JSON upstream body on an otherwise-2xx response yields upstream-error (not a thrown exception)", async () => {
  const fetchImpl: GithubFetch = async () => ({
    status: 200,
    headers: { get: () => null },
    json: async () => {
      throw new SyntaxError("Unexpected token");
    },
  });
  const result = await githubGet({ pathSegments: ["repos", "a", "b"] }, fetchImpl);
  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.code, "upstream-error");
  }
});
