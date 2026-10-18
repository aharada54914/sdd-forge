import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, writeFileSync, readFileSync, chmodSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, delimiter } from "node:path";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { InMemoryTransport } from "@modelcontextprotocol/sdk/inMemory.js";
import { buildServer } from "../../src/server.js";
import { probeEngine, __clearProbeCache } from "../../src/probe-engine.js";
import type { AllowlistEntry } from "../../src/allowlist.js";

// Windows cannot exec script shims without a shell; failure/slot release runs on every platform below.
test("simultaneous registered tool calls share four probe slots", { skip: process.platform === "win32" }, async () => {
  const dir = mkdtempSync(join(tmpdir(), "probe-concurrency-"));
  const log = join(dir, "events.jsonl");
  const groups = [["node", "npm", "pnpm", "yarn"], ["bun", "deno", "git", "gh"]];
  const previousPath = process.env.PATH;
  const server = buildServer();
  const client = new Client({ name: "concurrency-test", version: "1.0" });
  try {
    for (const name of groups.flat()) {
      const file = join(dir, name);
      writeFileSync(file, `#!${process.execPath}\nconst fs=require('node:fs');const log=${JSON.stringify(log)};const record=event=>fs.appendFileSync(log,JSON.stringify({event,pid:process.pid})+'\\n');record('start');setTimeout(()=>{record('end');console.log('fixture 1.0');},500);\n`);
      chmodSync(file, 0o755);
    }
    process.env.PATH = `${dir}${delimiter}${previousPath ?? ""}`;
    __clearProbeCache();
    const [a, b] = InMemoryTransport.createLinkedPair();
    await Promise.all([server.connect(a), client.connect(b)]);
    const requests = [...groups, groups[0]];
    const replies = await Promise.all(requests.map(names => client.callTool({ name: "get_toolchain_versions", arguments: { names } })));
    for (let i = 0; i < replies.length; i += 1) {
      const first = replies[i].content as Array<{type: string; text: string}>;
      const envelope = JSON.parse(first[0].text);
      assert.equal(envelope.ok, true);
      assert.deepEqual(envelope.data.entries.map((entry: {name: string}) => entry.name), requests[i]);
      assert.ok(envelope.data.entries.every((entry: {available: boolean}) => entry.available));
    }
    let active = 0;
    let peak = 0;
    const events = readFileSync(log, "utf8").trim().split("\n").map(line => JSON.parse(line) as {event: string});
    for (const event of events) { active += event.event === "start" ? 1 : -1; peak = Math.max(peak, active); }
    assert.equal(events.filter(event => event.event === "start").length, 8);
    assert.equal(active, 0);
    assert.ok(peak <= 4, `four shared slots exceeded: ${peak}`);
    const before = readFileSync(log, "utf8");
    await client.callTool({ name: "get_toolchain_versions", arguments: { names: groups[0] } });
    assert.equal(readFileSync(log, "utf8"), before, "completed cache hits must not spawn");
  } finally {
    if (previousPath === undefined) delete process.env.PATH; else process.env.PATH = previousPath;
    await client.close(); await server.close(); __clearProbeCache();
    rmSync(dir, { recursive: true, force: true });
  }
});

test("queued probes continue after timeout, nonzero exit, output limit and spawn failure", async () => {
  __clearProbeCache();
  const entry = (name: AllowlistEntry["name"], code: string): AllowlistEntry => ({ name, command: process.execPath, args: ["-e", code], versionStream: "stdout" });
  const cachedEntry = entry("docker", "console.log('cached 1.0')");
  await probeEngine([cachedEntry]);
  let failuresFinished = false;
  const failures = probeEngine([
    entry("node", "setTimeout(()=>{},10000)"), entry("npm", "process.exit(3)"),
    entry("pnpm", "process.stdout.write('X'.repeat(100000))"),
    { name: "yarn", command: join(tmpdir(), "missing-probe-executable-a3be82"), args: [], versionStream: "stdout" },
  ]);
  const observedFailures = failures.then(results => { failuresFinished = true; return results; });
  assert.equal((await probeEngine([cachedEntry]))[0].available, true);
  assert.equal(failuresFinished, false, "a cache hit must not wait behind active probes");
  const successors = probeEngine(["bun", "deno", "git", "gh"].map(name => entry(name as AllowlistEntry["name"], "console.log('fixture 1.0')")));
  const [bad, good] = await Promise.all([observedFailures, successors]);
  assert.deepEqual(bad.map(result => result.probeError), ["timeout", "nonzero-exit", "output-too-large", "not-found"]);
  assert.ok(good.every(result => result.available));
  __clearProbeCache();
  assert.equal((await probeEngine([entry("node", "console.log('after 1.0')")]))[0].available, true);
});
