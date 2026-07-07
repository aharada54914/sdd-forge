/**
 * AC-009 (TEST-009): canary-token end-to-end no-secrets check.
 *
 * Sets a canary GitHub token in the env, resolves it through `auth.ts`
 * (the same primitive every future tool surface uses), attaches it to a
 * `githubGet` call the way a real tool will, and drives it through an
 * upstream-error path (401) via an injected fake fetch (no real network).
 * Asserts the canary value and the literal `Authorization`/`Bearer` header
 * value appear NOWHERE in: the returned error envelope, its JSON
 * serialization, or scrubbed diagnostics output — matching security-spec.md's
 * B2 "Information Disclosure" control and REQ-005.
 */

import { test } from "node:test";
import assert from "node:assert/strict";

import { resolveToken } from "../../src/auth.js";
import { logFatal } from "../../src/diagnostics.js";
import { isOk } from "../../src/envelope.js";
import { githubGet } from "../../src/github-client.js";
import type { GithubFetch, GithubHttpResponse } from "../../src/github-client.js";

const CANARY_TOKEN = "ghp_canarysecret_do_not_leak_1234567890";

function fakeUnauthorizedResponse(): GithubHttpResponse {
  return {
    status: 401,
    headers: { get: () => null },
    json: async () => ({ message: "Bad credentials" }),
  };
}

test("AC-009: canary token resolved via auth.ts never appears in a githubGet error envelope", async () => {
  const priorToken = process.env.CI_MCP_GITHUB_TOKEN;
  process.env.CI_MCP_GITHUB_TOKEN = CANARY_TOKEN;
  try {
    const resolved = resolveToken(process.env);
    assert.ok(isOk(resolved));
    const token = isOk(resolved) ? resolved.data.token : undefined;
    assert.equal(token, CANARY_TOKEN);

    let capturedAuthHeader: string | undefined;
    const fakeFetch: GithubFetch = async (_url, init) => {
      capturedAuthHeader = init.headers.authorization;
      return fakeUnauthorizedResponse();
    };

    const outcome = await githubGet(
      { pathSegments: ["repos", "octo-org", "octo-repo", "actions", "runs"], token },
      fakeFetch,
    );

    // Sanity: the header really was attached (proves the test exercises the
    // real leak surface, not a no-op).
    assert.equal(capturedAuthHeader, `Bearer ${CANARY_TOKEN}`);

    const serialized = JSON.stringify(outcome);
    assert.ok(!serialized.includes(CANARY_TOKEN), `envelope must not contain the canary token: ${serialized}`);
    assert.ok(
      !serialized.toLowerCase().includes("bearer"),
      `envelope must not contain an Authorization/Bearer value: ${serialized}`,
    );
  } finally {
    if (priorToken === undefined) {
      delete process.env.CI_MCP_GITHUB_TOKEN;
    } else {
      process.env.CI_MCP_GITHUB_TOKEN = priorToken;
    }
  }
});

test("AC-009: canary token never appears in scrubbed stderr diagnostics even when it is live in process.env", () => {
  const priorToken = process.env.CI_MCP_GITHUB_TOKEN;
  process.env.CI_MCP_GITHUB_TOKEN = CANARY_TOKEN;
  try {
    let stderrOutput = "";
    const sink = (chunk: string): void => {
      stderrOutput += chunk;
    };
    logFatal(new Error(`request failed with header Authorization: Bearer ${CANARY_TOKEN}`), sink);
    assert.ok(!stderrOutput.includes(CANARY_TOKEN), `stderr must not contain the canary token: ${stderrOutput}`);
    // The scrubber keeps the literal word "Bearer" for readability but must
    // replace the token value that follows it — so no "Bearer <secret>" pair
    // may survive, even though the word "Bearer" alone is harmless.
    assert.ok(
      !new RegExp(`Bearer\\s+${CANARY_TOKEN}`, "i").test(stderrOutput),
      `stderr must not contain the Bearer <token> pair: ${stderrOutput}`,
    );
  } finally {
    if (priorToken === undefined) {
      delete process.env.CI_MCP_GITHUB_TOKEN;
    } else {
      process.env.CI_MCP_GITHUB_TOKEN = priorToken;
    }
  }
});
