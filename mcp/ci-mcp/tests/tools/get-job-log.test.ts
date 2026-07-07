/**
 * AC-004: `get_job_log` returns the job's plain-text log via `job-log`
 * envelope. Under the 256 KiB (262144 byte) cap, `truncated: false` and
 * `returnedBytes` equals the log's byte length. Over the cap, only the TAIL
 * (most recent bytes, best for failure diagnosis) is kept, `truncated: true`,
 * and `returnedBytes` is capped at 262144. Always `ok: true` regardless of
 * truncation (AC-004). Uses an injected fake text-fetch (no real network).
 *
 * T-013 cycle-2 (evaluator Major, security-spec.md B2 ring-buffer
 * mitigation): the tests below exercise `get_job_log` against a genuinely
 * *streaming* fake response (`body: ReadableStream<Uint8Array>`, the same
 * shape a real `fetch` `Response` exposes) instead of an in-memory
 * `.text()`-only fake, so they prove the tail-priority / truncation
 * behavior still holds end-to-end when `github-client.ts`'s bounded
 * streaming reader is actually on the read path — not just when body-level
 * truncation runs against an already-fully-buffered string. They also close
 * the previously-disclosed multibyte fixture gap (TEST-004 previously only
 * used single-byte ASCII fixtures).
 */

import { test } from "node:test";
import assert from "node:assert/strict";

import { getJobLog } from "../../src/tools/actions.js";
import { isOk } from "../../src/envelope.js";
import type { GithubTextFetch, GithubTextHttpResponse } from "../../src/github-client.js";

const TOKEN_ENV = { CI_MCP_GITHUB_TOKEN: "test-token-123" };
const MAX_LOG_BYTES = 262144;

/**
 * Builds a fake text-fetch whose response exposes a real streaming `body`
 * (a `ReadableStream<Uint8Array>`) that yields `body`'s UTF-8 bytes in
 * `chunkSize`-sized pieces, mirroring how a real `fetch` `Response` delivers
 * a large upstream body over many chunks rather than as one buffered string.
 */
function chunkedStreamTextFetch(
  body: string,
  chunkSize: number,
  status = 200,
): { fetchImpl: GithubTextFetch; calls: string[] } {
  const calls: string[] = [];
  const fullBytes = new TextEncoder().encode(body);
  const fetchImpl: GithubTextFetch = async (url) => {
    calls.push(url);
    let offset = 0;
    const stream = new ReadableStream<Uint8Array>({
      pull(controller) {
        if (offset >= fullBytes.byteLength) {
          controller.close();
          return;
        }
        const end = Math.min(offset + chunkSize, fullBytes.byteLength);
        controller.enqueue(fullBytes.slice(offset, end));
        offset = end;
      },
    });
    const response: GithubTextHttpResponse = {
      status,
      headers: { get: () => null },
      body: stream,
      // Present only to satisfy the required shape; the streaming `body`
      // above is what `githubGetText` actually reads when present.
      text: async () => {
        throw new Error("text() must not be called when a streaming body is available");
      },
    };
    return response;
  };
  return { fetchImpl, calls };
}

test("T-013 cycle-2: a streaming log over 1 MiB, delivered in many small chunks, is tail-truncated to <= 262144 bytes with the tail marker surviving", async () => {
  const line = "x".repeat(100) + "\n"; // 101 bytes per line
  const lineCount = Math.ceil((1024 * 1024 * 2) / line.length); // well over 2 MiB total
  const bodyLines: string[] = ["HEAD-MARKER-should-be-dropped\n"];
  for (let i = 0; i < lineCount; i += 1) {
    bodyLines.push(line);
  }
  bodyLines.push("TAIL-MARKER-should-survive\n");
  const largeLog = bodyLines.join("");
  assert.ok(Buffer.byteLength(largeLog, "utf-8") > 1024 * 1024, "fixture must exceed 1 MiB");

  const { fetchImpl } = chunkedStreamTextFetch(largeLog, 4096);

  const result = await getJobLog(
    { owner: "acme", repo: "widgets", jobId: 888 },
    { env: TOKEN_ENV, textFetchImpl: fetchImpl },
  );

  assert.ok(isOk(result));
  if (isOk(result)) {
    assert.equal(result.data.truncated, true);
    assert.ok(result.data.returnedBytes <= MAX_LOG_BYTES, `returnedBytes was ${result.data.returnedBytes}`);
    assert.equal(Buffer.byteLength(result.data.log, "utf-8"), result.data.returnedBytes);
    assert.ok(result.data.log.includes("TAIL-MARKER-should-survive"), "the tail marker must survive truncation");
    assert.ok(!result.data.log.includes("HEAD-MARKER-should-be-dropped"), "the head marker must be dropped");
  }
});

test("T-013 cycle-2: a multibyte-character streaming log crossing the 262144-byte cut boundary yields no replacement characters", async () => {
  // "あ" (U+3042) is 3 bytes in UTF-8, so repeating it does not align to any
  // particular byte-cap boundary — this deliberately makes the naive cut
  // point (totalBytes - 262144) fall mid-character for many repeat counts,
  // exercising the UTF-8-safe boundary logic against a real multibyte body
  // (the ASCII-only "x" fixture above never could).
  const multibyteChar = "あ";
  const repeatCount = 200000; // ~600000 bytes, well over the 262144 cap
  const largeLog = "HEAD-MARKER-should-be-dropped\n" + multibyteChar.repeat(repeatCount) + "\nTAIL-MARKER-should-survive\n";
  assert.ok(Buffer.byteLength(largeLog, "utf-8") > MAX_LOG_BYTES, "fixture must exceed the 256 KiB cap");

  const { fetchImpl } = chunkedStreamTextFetch(largeLog, 8192);

  const result = await getJobLog(
    { owner: "acme", repo: "widgets", jobId: 999 },
    { env: TOKEN_ENV, textFetchImpl: fetchImpl },
  );

  assert.ok(isOk(result));
  if (isOk(result)) {
    assert.equal(result.data.truncated, true);
    assert.ok(result.data.returnedBytes <= MAX_LOG_BYTES, `returnedBytes was ${result.data.returnedBytes}`);
    assert.equal(Buffer.byteLength(result.data.log, "utf-8"), result.data.returnedBytes);
    assert.ok(!result.data.log.includes("�"), "no UTF-8 replacement character must appear in the returned tail");
    assert.ok(result.data.log.includes("TAIL-MARKER-should-survive"), "the tail marker must survive truncation");
    assert.ok(!result.data.log.includes("HEAD-MARKER-should-be-dropped"), "the head marker must be dropped");
  }
});

test("T-013 cycle-2: a small streaming log under the cap is returned whole with truncated:false", async () => {
  const smallLog = "line 1\nline 2\nline 3\n";
  const { fetchImpl, calls } = chunkedStreamTextFetch(smallLog, 4096);

  const result = await getJobLog(
    { owner: "acme", repo: "widgets", jobId: 1000 },
    { env: TOKEN_ENV, textFetchImpl: fetchImpl },
  );

  assert.ok(isOk(result));
  if (isOk(result)) {
    assert.equal(result.data.log, smallLog);
    assert.equal(result.data.truncated, false);
    assert.equal(result.data.returnedBytes, Buffer.byteLength(smallLog, "utf-8"));
  }
  assert.ok(calls[0]?.endsWith("/repos/acme/widgets/actions/jobs/1000/logs"), `url was ${calls[0]}`);
});

function fakeTextFetch(body: string, status = 200): { fetchImpl: GithubTextFetch; calls: string[] } {
  const calls: string[] = [];
  const fetchImpl: GithubTextFetch = async (url) => {
    calls.push(url);
    const response: GithubTextHttpResponse = {
      status,
      headers: { get: () => null },
      text: async () => body,
    };
    return response;
  };
  return { fetchImpl, calls };
}

test("AC-004: a small log is returned whole with truncated:false", async () => {
  const smallLog = "line 1\nline 2\nline 3\n";
  const { fetchImpl, calls } = fakeTextFetch(smallLog);

  const result = await getJobLog(
    { owner: "acme", repo: "widgets", jobId: 555 },
    { env: TOKEN_ENV, textFetchImpl: fetchImpl },
  );

  assert.ok(isOk(result));
  if (isOk(result)) {
    assert.equal(result.data.kind, "job-log");
    assert.equal(result.data.jobId, 555);
    assert.equal(result.data.log, smallLog);
    assert.equal(result.data.truncated, false);
    assert.equal(result.data.returnedBytes, Buffer.byteLength(smallLog, "utf-8"));
  }
  assert.ok(calls[0]?.endsWith("/repos/acme/widgets/actions/jobs/555/logs"), `url was ${calls[0]}`);
});

test("AC-004: a log over 256 KiB is truncated to the tail, truncated:true, returnedBytes capped at 262144", async () => {
  // Build a synthetic log well over 262144 bytes using distinguishable
  // head/tail markers so we can prove the TAIL (not the head) survives.
  const line = "x".repeat(100) + "\n"; // 101 bytes per line
  const lineCount = Math.ceil((MAX_LOG_BYTES * 3) / line.length); // well over 3x the cap
  const bodyLines: string[] = ["HEAD-MARKER-should-be-dropped\n"];
  for (let i = 0; i < lineCount; i += 1) {
    bodyLines.push(line);
  }
  bodyLines.push("TAIL-MARKER-should-survive\n");
  const largeLog = bodyLines.join("");
  assert.ok(Buffer.byteLength(largeLog, "utf-8") > MAX_LOG_BYTES, "fixture must exceed the 256 KiB cap");

  const { fetchImpl } = fakeTextFetch(largeLog);

  const result = await getJobLog(
    { owner: "acme", repo: "widgets", jobId: 777 },
    { env: TOKEN_ENV, textFetchImpl: fetchImpl },
  );

  assert.ok(isOk(result));
  if (isOk(result)) {
    assert.equal(result.data.truncated, true);
    assert.ok(result.data.returnedBytes <= MAX_LOG_BYTES, `returnedBytes was ${result.data.returnedBytes}`);
    assert.equal(Buffer.byteLength(result.data.log, "utf-8"), result.data.returnedBytes);
    assert.ok(result.data.log.includes("TAIL-MARKER-should-survive"), "the tail marker must survive truncation");
    assert.ok(!result.data.log.includes("HEAD-MARKER-should-be-dropped"), "the head marker must be dropped");
  }
});

test("AC-004: a log exactly at the 256 KiB cap is not truncated", async () => {
  const exactLog = "a".repeat(MAX_LOG_BYTES);
  const { fetchImpl } = fakeTextFetch(exactLog);

  const result = await getJobLog(
    { owner: "acme", repo: "widgets", jobId: 1 },
    { env: TOKEN_ENV, textFetchImpl: fetchImpl },
  );

  assert.ok(isOk(result));
  if (isOk(result)) {
    assert.equal(result.data.truncated, false);
    assert.equal(result.data.returnedBytes, MAX_LOG_BYTES);
  }
});

test("jobId is required: missing jobId is rejected with invalid-input", async () => {
  const { fetchImpl, calls } = fakeTextFetch("");

  const result = await getJobLog({ owner: "acme", repo: "widgets" } as never, {
    env: TOKEN_ENV,
    textFetchImpl: fetchImpl,
  });

  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.code, "invalid-input");
  }
  assert.equal(calls.length, 0);
});

test("AC-008: missing token short-circuits to auth-missing without calling GitHub", async () => {
  const { fetchImpl, calls } = fakeTextFetch("log body");

  const result = await getJobLog(
    { owner: "acme", repo: "widgets", jobId: 555 },
    { env: {}, textFetchImpl: fetchImpl },
  );

  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.code, "auth-missing");
  }
  assert.equal(calls.length, 0);
});

test("a non-existent job id yields not-found", async () => {
  const { fetchImpl } = fakeTextFetch("Not Found", 404);

  const result = await getJobLog(
    { owner: "acme", repo: "widgets", jobId: 404404 },
    { env: TOKEN_ENV, textFetchImpl: fetchImpl },
  );

  assert.equal(result.ok, false);
  if (!result.ok) {
    assert.equal(result.error.code, "not-found");
  }
});
