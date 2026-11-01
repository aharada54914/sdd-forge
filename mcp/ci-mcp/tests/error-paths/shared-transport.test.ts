import { test } from "node:test";
import assert from "node:assert/strict";
import { githubGet, githubGetText, type GithubFetch, type GithubTextFetch } from "../../src/github-client.js";

// Same transport contract, intentionally distinct successful body contracts.
for (const kind of ["json", "text"] as const) {
  test(`${kind}: shared transport authenticates once and rejects status before body reads`, async () => {
    let calls = 0;
    const fetchImpl: GithubFetch & GithubTextFetch = async (url, init) => {
      calls++;
      assert.equal(new URL(url).hostname, "api.github.com");
      assert.equal(init.method, "GET");
      assert.equal(init.headers.authorization, "Bearer transport-canary");
      assert.equal(init.headers.accept, kind === "json" ? "application/vnd.github+json" : "text/plain");
      assert.ok(init.signal instanceof AbortSignal);
      return {
        status: 401,
        headers: { get: () => null },
        json: async () => { throw new Error("body must not be read"); },
        text: async () => { throw new Error("body must not be read"); },
      };
    };
    const request = { pathSegments: ["repos", "owner", "repo"], token: "transport-canary" };
    const result = kind === "json" ? await githubGet(request, fetchImpl) : await githubGetText(request, fetchImpl);
    assert.equal(calls, 1, "transport must not add retries");
    assert.equal(result.ok, false);
    if (!result.ok) assert.equal(result.error.code, "auth-missing");
    assert.ok(!JSON.stringify(result).includes("transport-canary"));
  });
}
