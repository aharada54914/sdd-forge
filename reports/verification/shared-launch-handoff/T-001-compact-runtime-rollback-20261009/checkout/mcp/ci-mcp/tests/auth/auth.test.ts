/**
 * AC-008 (TEST-008): token resolution priority + `auth-missing` on all-unset,
 * process-continuation guarantee.
 *
 * `resolveToken` implements OQ-004's confirmed priority order
 * `CI_MCP_GITHUB_TOKEN` -> `GH_READONLY_TOKEN` -> `GITHUB_TOKEN` (first
 * non-empty value wins; empty-string values are treated as unset). When none
 * resolve, it returns the `auth-missing` envelope rather than throwing —
 * this is the primitive every future tool surface (T-005 / T-012 / T-013)
 * will call through, so proving it here proves the "all tools return
 * auth-missing, process stays alive" acceptance criterion at the one place
 * that gates every tool call (`withToken`), since no concrete tool surfaces
 * are registered yet (T-001 scope; tools start at T-005).
 */

import { test } from "node:test";
import assert from "node:assert/strict";

import { resolveToken, withToken } from "../../src/auth.js";
import { isOk, isErr } from "../../src/envelope.js";

const TOKEN_ENV_VARS = ["CI_MCP_GITHUB_TOKEN", "GH_READONLY_TOKEN", "GITHUB_TOKEN"] as const;

/** Saves and clears all 3 token env vars, restoring them after `fn` runs. */
async function withCleanTokenEnv(fn: () => void | Promise<void>): Promise<void> {
  const saved: Record<string, string | undefined> = {};
  for (const name of TOKEN_ENV_VARS) {
    saved[name] = process.env[name];
    delete process.env[name];
  }
  try {
    await fn();
  } finally {
    for (const name of TOKEN_ENV_VARS) {
      const value = saved[name];
      if (value === undefined) {
        delete process.env[name];
      } else {
        process.env[name] = value;
      }
    }
  }
}

test("AC-008: no token env set resolves to auth-missing", async () => {
  await withCleanTokenEnv(() => {
    const resolved = resolveToken(process.env);
    assert.ok(isErr(resolved));
    if (isErr(resolved)) {
      assert.equal(resolved.error.code, "auth-missing");
    }
  });
});

test("OQ-004: CI_MCP_GITHUB_TOKEN wins over GH_READONLY_TOKEN and GITHUB_TOKEN", async () => {
  await withCleanTokenEnv(() => {
    process.env.CI_MCP_GITHUB_TOKEN = "primary-token";
    process.env.GH_READONLY_TOKEN = "secondary-token";
    process.env.GITHUB_TOKEN = "tertiary-token";
    const resolved = resolveToken(process.env);
    assert.ok(isOk(resolved));
    if (isOk(resolved)) {
      assert.equal(resolved.data.token, "primary-token");
    }
  });
});

test("OQ-004: GH_READONLY_TOKEN wins over GITHUB_TOKEN when CI_MCP_GITHUB_TOKEN is unset", async () => {
  await withCleanTokenEnv(() => {
    process.env.GH_READONLY_TOKEN = "secondary-token";
    process.env.GITHUB_TOKEN = "tertiary-token";
    const resolved = resolveToken(process.env);
    assert.ok(isOk(resolved));
    if (isOk(resolved)) {
      assert.equal(resolved.data.token, "secondary-token");
    }
  });
});

test("OQ-004: GITHUB_TOKEN is used when it is the only variable set", async () => {
  await withCleanTokenEnv(() => {
    process.env.GITHUB_TOKEN = "tertiary-token";
    const resolved = resolveToken(process.env);
    assert.ok(isOk(resolved));
    if (isOk(resolved)) {
      assert.equal(resolved.data.token, "tertiary-token");
    }
  });
});

test("OQ-004: an empty-string value is treated as unset and falls through to the next variable", async () => {
  await withCleanTokenEnv(() => {
    process.env.CI_MCP_GITHUB_TOKEN = "";
    process.env.GH_READONLY_TOKEN = "";
    process.env.GITHUB_TOKEN = "tertiary-token";
    const resolved = resolveToken(process.env);
    assert.ok(isOk(resolved));
    if (isOk(resolved)) {
      assert.equal(resolved.data.token, "tertiary-token");
    }
  });
});

test("resolveToken never throws regardless of env state", async () => {
  await withCleanTokenEnv(() => {
    assert.doesNotThrow(() => resolveToken(process.env));
  });
});

test("AC-008: withToken (the shared gate every future tool calls through) returns auth-missing and never invokes the handler when no token is resolvable", async () => {
  await withCleanTokenEnv(async () => {
    let handlerCalled = false;
    const result = await withToken(async (_token) => {
      handlerCalled = true;
      return { ok: true as const, data: "unreachable" };
    }, process.env);
    assert.ok(isErr(result));
    if (isErr(result)) {
      assert.equal(result.error.code, "auth-missing");
    }
    assert.equal(handlerCalled, false, "the tool handler must not run when auth is missing");
  });
});

test("AC-008: withToken invokes the handler with the resolved token when one is set, and the process does not exit", async () => {
  await withCleanTokenEnv(async () => {
    process.env.CI_MCP_GITHUB_TOKEN = "resolved-token";
    const result = await withToken(async (token) => {
      assert.equal(token, "resolved-token");
      return { ok: true as const, data: "handled" };
    }, process.env);
    assert.ok(isOk(result));
    if (isOk(result)) {
      assert.equal(result.data, "handled");
    }
  });
});
