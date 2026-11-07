import { test, mock } from "node:test";
import assert from "node:assert/strict";
import path from "node:path";
import { execFile } from "node:child_process";
import { createProbeEngine } from "../../src/probe-engine.js";
import type { AllowlistEntry } from "../../src/allowlist.js";

const entry: AllowlistEntry = {
  name: "node",
  command: process.execPath,
  args: ["-e", "console.log(process.env.PROBE_FIXTURE)"],
  versionStream: "stdout",
};

test("injected clock expires cache without waiting and environments stay isolated", async () => {
  let now = 0;
  const run = mock.fn(execFile);
  const environment = { ...process.env, PROBE_FIXTURE: "first" };
  const first = createProbeEngine({ run, now: () => now, environment: () => environment });
  const second = createProbeEngine({ environment: () => ({ ...process.env, PROBE_FIXTURE: "second" }) });
  assert.equal((await first.probe([entry]))[0]?.version, "first");
  assert.equal((await second.probe([entry]))[0]?.version, "second");
  environment.PROBE_FIXTURE = "refreshed";
  now = 59_999;
  assert.equal((await first.probe([entry]))[0]?.version, "first");
  assert.equal(run.mock.callCount(), 1);
  now = 60_000;
  assert.equal((await first.probe([entry]))[0]?.version, "refreshed");
  assert.equal(run.mock.callCount(), 2);
  assert.equal((await second.probe([entry]))[0]?.version, "second");
});

test("injected process launch failure remains a per-entry result and releases slots", async () => {
  const run = () => { throw new Error("synthetic launch failure"); };
  const engine = createProbeEngine({ run });
  const results = await engine.probe(Array.from({ length: 8 }, () => entry));
  assert.equal(results.length, 8);
  assert.ok(results.every(result => result.probeError === "spawn-error" && !result.available));
});

test("PATH override preserves inherited Windows Path casing without duplicate keys", async () => {
  const key = process.platform === "win32" ? "Path" : "PATH";
  const environment = { [key]: "inherited-tools" };
  const run = mock.fn(execFile);
  const engine = createProbeEngine({ run, environment: () => environment });
  await engine.probe([entry], { pathOverride: "fixture-tools" });
  const passed = run.mock.calls[0]?.arguments[2];
  assert.ok(passed && typeof passed === "object" && "env" in passed);
  assert.equal(passed.env?.[key], `fixture-tools${path.delimiter}inherited-tools`);
  assert.deepEqual(Object.keys(passed.env ?? {}).filter(name => name.toUpperCase() === "PATH"), [key]);
  assert.deepEqual(environment, { [key]: "inherited-tools" });
});
