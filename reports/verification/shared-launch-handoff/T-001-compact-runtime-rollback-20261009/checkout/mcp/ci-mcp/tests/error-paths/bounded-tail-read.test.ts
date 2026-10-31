/**
 * T-013 cycle-2 (evaluator Major, security-spec.md B2 "リングバッファ +
 * 256 KiB 上限(末尾優先)"): unit-level regression tests for
 * `github-client.ts`'s `readBoundedTail`, the bounded streaming tail reader
 * that backs `githubGetText`'s primary (memory-bounded) read path.
 *
 * These tests exercise `readBoundedTail` directly against a large,
 * many-chunk `ReadableStream` and assert on its exposed `maxRetainedBytes`
 * field — proving memory-boundedness directly (the retention buffer never
 * exceeds `capBytes + marginBytes` plus at most one extra chunk), rather
 * than only inferring it indirectly from the final truncated output size.
 */

import { test } from "node:test";
import assert from "node:assert/strict";

import { readBoundedTail } from "../../src/github-client.js";
import { truncateLogTail, MAX_JOB_LOG_BYTES } from "../../src/tools/actions.js";

const CAP_BYTES = 262144;
const MARGIN_BYTES = 65536;

/** A `ReadableStream<Uint8Array>` that yields `totalBytes` of `fillByte`, split into `chunkSize`-sized chunks. */
function makeChunkedStream(totalBytes: number, chunkSize: number, fillByte = 0x61): ReadableStream<Uint8Array> {
  let bytesEmitted = 0;
  return new ReadableStream<Uint8Array>({
    pull(controller) {
      if (bytesEmitted >= totalBytes) {
        controller.close();
        return;
      }
      const size = Math.min(chunkSize, totalBytes - bytesEmitted);
      controller.enqueue(new Uint8Array(size).fill(fillByte));
      bytesEmitted += size;
    },
  });
}

test("T-013 cycle-2: retention buffer never exceeds capBytes + marginBytes + one chunk, even for a multi-MiB stream", async () => {
  const chunkSize = 4096;
  const totalBytes = 3 * 1024 * 1024; // 3 MiB, ~24x the 256 KiB cap
  const stream = makeChunkedStream(totalBytes, chunkSize);

  const result = await readBoundedTail(stream, CAP_BYTES, MARGIN_BYTES);

  assert.equal(result.totalBytesRead, totalBytes, "totalBytesRead must reflect the entire stream, even though it was not all retained");
  const upperBound = CAP_BYTES + MARGIN_BYTES + chunkSize;
  assert.ok(
    result.maxRetainedBytes <= upperBound,
    `maxRetainedBytes (${result.maxRetainedBytes}) must never exceed capBytes + marginBytes + one chunk (${upperBound})`,
  );
  assert.ok(
    result.bytes.byteLength <= upperBound,
    `final retained bytes (${result.bytes.byteLength}) must also stay within the same bound`,
  );
  // The retained window must actually be much smaller than the full stream —
  // this is the crux of the fix: peak memory does not scale with body size.
  assert.ok(
    result.maxRetainedBytes < totalBytes / 2,
    "retention buffer must be far smaller than the full stream, proving memory does not scale with body size",
  );
});

test("T-013 cycle-2: tail content is preserved correctly under eviction (last bytes read survive, earliest bytes are dropped)", async () => {
  const chunkSize = 1000;
  const headByte = 0x41; // 'A'
  const tailByte = 0x5a; // 'Z'
  const headBytes = 500000; // way over cap+margin, will be evicted
  const tailBytes = 1000; // small, must survive whole

  const stream = new ReadableStream<Uint8Array>({
    start(controller) {
      let emittedHead = 0;
      while (emittedHead < headBytes) {
        const size = Math.min(chunkSize, headBytes - emittedHead);
        controller.enqueue(new Uint8Array(size).fill(headByte));
        emittedHead += size;
      }
      controller.enqueue(new Uint8Array(tailBytes).fill(tailByte));
      controller.close();
    },
  });

  const result = await readBoundedTail(stream, CAP_BYTES, MARGIN_BYTES);

  assert.equal(result.totalBytesRead, headBytes + tailBytes);
  // The tail-byte-filled region must be present in full at the end of the retained buffer.
  const retainedTailSlice = result.bytes.subarray(result.bytes.byteLength - tailBytes);
  assert.ok(
    retainedTailSlice.every((b) => b === tailByte),
    "the most-recently-read bytes must be fully retained",
  );
  // At least the earliest head bytes must have been evicted (retained buffer is bounded).
  assert.ok(result.bytes.byteLength < headBytes, "retained buffer must be smaller than the (evicted) head region");
});

test("T-013 cycle-2: a small stream under the cap is retained whole with no eviction", async () => {
  const totalBytes = 1000;
  const stream = makeChunkedStream(totalBytes, 128);

  const result = await readBoundedTail(stream, CAP_BYTES, MARGIN_BYTES);

  assert.equal(result.totalBytesRead, totalBytes);
  assert.equal(result.bytes.byteLength, totalBytes, "nothing should be evicted when the stream is under the cap");
  assert.equal(result.maxRetainedBytes, totalBytes);
});

test("Codex P2 (PR #98): a SINGLE chunk far larger than capBytes + marginBytes is still bounded (byte-level, not whole-chunk eviction)", async () => {
  // A redirected log delivered as one big Uint8Array — the whole-chunk-only
  // eviction bug retained this kind of chunk in full, since evicting the
  // only chunk in the deque would have left 0 bytes (which whole-chunk
  // eviction refuses to do), so the ring-buffer bound could still OOM.
  const headByte = 0x41; // 'A' — must be evicted
  const tailByte = 0x5a; // 'Z' — must survive (tail-priority)
  const chunkSize = 2 * 1024 * 1024; // 2 MiB, delivered as ONE chunk
  const tailBytes = 2000;
  const bigChunk = new Uint8Array(chunkSize);
  bigChunk.fill(headByte, 0, chunkSize - tailBytes);
  bigChunk.fill(tailByte, chunkSize - tailBytes);

  const stream = new ReadableStream<Uint8Array>({
    start(controller) {
      controller.enqueue(bigChunk);
      controller.close();
    },
  });

  const result = await readBoundedTail(stream, CAP_BYTES, MARGIN_BYTES);

  const streamingBound = CAP_BYTES + MARGIN_BYTES;
  assert.equal(result.totalBytesRead, chunkSize, "totalBytesRead must reflect the full chunk even though most of it was evicted");
  assert.ok(
    result.bytes.byteLength <= streamingBound,
    `a single oversized chunk must still be bounded to capBytes + marginBytes (${streamingBound}), got ${result.bytes.byteLength}`,
  );
  assert.ok(
    result.maxRetainedBytes <= streamingBound,
    `maxRetainedBytes (${result.maxRetainedBytes}) must never exceed capBytes + marginBytes (${streamingBound}) even for a single huge chunk`,
  );
  const retainedTailSlice = result.bytes.subarray(result.bytes.byteLength - tailBytes);
  assert.ok(retainedTailSlice.every((b) => b === tailByte), "the tail of the oversized chunk must survive eviction");
  const retainedHeadSlice = result.bytes.subarray(0, result.bytes.byteLength - tailBytes);
  assert.ok(
    retainedHeadSlice.every((b) => b === headByte) || retainedHeadSlice.byteLength === 0,
    "only trailing bytes of the oversized chunk may survive",
  );

  // Compose with the final byte-exact cut (`tools/actions.ts`'s
  // `truncateLogTail`) to prove the whole pipeline lands at the real
  // 262144-byte contract cap, not just the streaming layer's cap+margin
  // window.
  const text = Buffer.from(result.bytes.buffer, result.bytes.byteOffset, result.bytes.byteLength).toString("utf-8");
  const final = truncateLogTail(text);
  assert.ok(
    final.returnedBytes <= MAX_JOB_LOG_BYTES,
    `final returned bytes (${final.returnedBytes}) must not exceed the contract cap (${MAX_JOB_LOG_BYTES})`,
  );
  assert.equal(final.truncated, true);
});
