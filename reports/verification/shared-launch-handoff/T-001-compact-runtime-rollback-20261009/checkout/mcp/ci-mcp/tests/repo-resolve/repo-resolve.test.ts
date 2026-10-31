/**
 * AC-012 (TEST-012): owner/repo resolution unit + input-validation edge
 * cases.
 *
 * `resolveRepo` implements OQ-001's confirmed canonical priority: explicit
 * `owner`/`repo` tool arguments win (both must be present together and pass
 * GitHub-style name validation); otherwise fall back to env `CI_MCP_REPO` in
 * `owner/repo` form; if neither resolves, return `invalid-input`. It never
 * execs (no `child_process`, no git-remote lookup) — see
 * repo-resolve.no-exec.test.ts for the static check.
 */

import { test } from "node:test";
import assert from "node:assert/strict";

import { resolveRepo } from "../../src/repo-resolve.js";
import { isOk, isErr } from "../../src/envelope.js";

test("AC-012 / OQ-001: explicit owner+repo arguments resolve directly", () => {
  const result = resolveRepo({ owner: "octo-org", repo: "octo-repo" }, {});
  assert.ok(isOk(result));
  if (isOk(result)) {
    assert.deepEqual(result.data, { owner: "octo-org", repo: "octo-repo" });
  }
});

test("AC-012 / OQ-001: explicit arguments take priority over CI_MCP_REPO even when both are set", () => {
  const result = resolveRepo(
    { owner: "arg-owner", repo: "arg-repo" },
    { CI_MCP_REPO: "env-owner/env-repo" },
  );
  assert.ok(isOk(result));
  if (isOk(result)) {
    assert.deepEqual(result.data, { owner: "arg-owner", repo: "arg-repo" });
  }
});

test("AC-012 / OQ-001: CI_MCP_REPO is used when no explicit arguments are given", () => {
  const result = resolveRepo({}, { CI_MCP_REPO: "env-owner/env-repo" });
  assert.ok(isOk(result));
  if (isOk(result)) {
    assert.deepEqual(result.data, { owner: "env-owner", repo: "env-repo" });
  }
});

test("AC-012: neither explicit arguments nor CI_MCP_REPO set -> invalid-input", () => {
  const result = resolveRepo({}, {});
  assert.ok(isErr(result));
  if (isErr(result)) {
    assert.equal(result.error.code, "invalid-input");
  }
});

test("AC-012: CI_MCP_REPO set to an empty string is treated as unset -> invalid-input", () => {
  const result = resolveRepo({}, { CI_MCP_REPO: "" });
  assert.ok(isErr(result));
  if (isErr(result)) {
    assert.equal(result.error.code, "invalid-input");
  }
});

test("AC-012: malformed CI_MCP_REPO without a slash -> invalid-input", () => {
  const result = resolveRepo({}, { CI_MCP_REPO: "owneronly" });
  assert.ok(isErr(result));
  if (isErr(result)) {
    assert.equal(result.error.code, "invalid-input");
  }
});

test("AC-012: malformed CI_MCP_REPO with too many slashes -> invalid-input", () => {
  const result = resolveRepo({}, { CI_MCP_REPO: "owner/repo/extra" });
  assert.ok(isErr(result));
  if (isErr(result)) {
    assert.equal(result.error.code, "invalid-input");
  }
});

test("AC-012: CI_MCP_REPO with an empty owner or repo segment -> invalid-input", () => {
  assert.ok(isErr(resolveRepo({}, { CI_MCP_REPO: "/repo" })));
  assert.ok(isErr(resolveRepo({}, { CI_MCP_REPO: "owner/" })));
});

test("AC-012: only owner explicit argument given (repo missing) -> invalid-input, no fallback to env", () => {
  const result = resolveRepo({ owner: "octo-org" }, { CI_MCP_REPO: "env-owner/env-repo" });
  assert.ok(isErr(result));
  if (isErr(result)) {
    assert.equal(result.error.code, "invalid-input");
  }
});

test("AC-012: only repo explicit argument given (owner missing) -> invalid-input, no fallback to env", () => {
  const result = resolveRepo({ repo: "octo-repo" }, { CI_MCP_REPO: "env-owner/env-repo" });
  assert.ok(isErr(result));
});

test("AC-012: explicit owner/repo containing invalid characters (space) -> invalid-input", () => {
  const result = resolveRepo({ owner: "octo org", repo: "octo-repo" }, {});
  assert.ok(isErr(result));
  if (isErr(result)) {
    assert.equal(result.error.code, "invalid-input");
  }
});

test("AC-012: explicit owner containing a path separator -> invalid-input (cannot smuggle an extra path segment)", () => {
  const result = resolveRepo({ owner: "octo/evil", repo: "octo-repo" }, {});
  assert.ok(isErr(result));
});

test("AC-012: explicit repo containing a path separator -> invalid-input", () => {
  const result = resolveRepo({ owner: "octo-org", repo: "evil/repo" }, {});
  assert.ok(isErr(result));
});

test("AC-012: explicit owner/repo containing control characters -> invalid-input", () => {
  const result = resolveRepo({ owner: "octo-org", repo: "repo\nname" }, {});
  assert.ok(isErr(result));
});

test("AC-012: explicit repo of '.' or '..' -> invalid-input", () => {
  assert.ok(isErr(resolveRepo({ owner: "octo-org", repo: "." }, {})));
  assert.ok(isErr(resolveRepo({ owner: "octo-org", repo: ".." }, {})));
});

test("AC-012: explicit owner/repo with invalid characters does not silently fall back to a valid CI_MCP_REPO", () => {
  const result = resolveRepo(
    { owner: "octo org", repo: "octo-repo" },
    { CI_MCP_REPO: "valid-owner/valid-repo" },
  );
  assert.ok(isErr(result));
  if (isErr(result)) {
    assert.equal(result.error.code, "invalid-input");
  }
});

test("resolveRepo never throws for any input shape", () => {
  assert.doesNotThrow(() => resolveRepo({ owner: "", repo: "" }, { CI_MCP_REPO: undefined }));
  assert.doesNotThrow(() => resolveRepo({}, {}));
});
