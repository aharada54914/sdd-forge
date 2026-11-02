/** Independent memory oracle: count reachable backing buffers, not the reader's own byte counter. */
import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";

for (const shape of ["oversized", "small-view"] as const) {
  test(`tail reader releases ${shape} upstream backing allocation before EOF`, () => {
    const clientUrl = new URL("../../src/github-client.js", import.meta.url).href;
    const probe = `
      import assert from 'node:assert/strict';
      import {readBoundedTail} from ${JSON.stringify(clientUrl)};
      let weak, controller, step = 0;
      const allocationBytes = 16 * 1024 * 1024;
      const inputBytes = ${shape === "oversized" ? "allocationBytes" : "32"};
      const stream = new ReadableStream({pull(c) {
        controller = c;
        if (step++ === 0) {
          const allocation = new ArrayBuffer(allocationBytes);
          weak = new WeakRef(allocation);
          c.enqueue(new Uint8Array(allocation, 0, inputBytes).fill(65));
        } else if (step <= 3) c.enqueue(new Uint8Array([66]));
      }}, {highWaterMark: 0});
      const reading = readBoundedTail(stream, 64, 0);
      await new Promise(resolve => setImmediate(resolve));
      for (let i = 0; i < 10; i++) {
        global.gc();
        await new Promise(resolve => setImmediate(resolve));
      }
      const retained = weak.deref() !== undefined;
      controller.close();
      const result = await reading;
      assert.equal(result.totalBytesRead, inputBytes + 2);
      assert.deepEqual(result.bytes, Uint8Array.from([
        ...Array(Math.min(inputBytes, 62)).fill(65), 66, 66,
      ]));
      assert.equal(retained, false, 'upstream allocation must be collectible while the stream is open');
    `;
    const result = spawnSync(process.execPath, ["--expose-gc", "--input-type=module", "-e", probe], {
      encoding: "utf8",
      timeout: 10_000,
    });
    assert.equal(result.error, undefined);
    assert.equal(result.status, 0, result.stderr);
  });
}
