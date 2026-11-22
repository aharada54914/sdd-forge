/** Exercise both published resources against the same v2 server as tools/call. */
import { test, type TestContext } from "node:test";
import assert from "node:assert/strict";
import { CallToolResultSchema } from "@modelcontextprotocol/sdk/types.js";
import type { Result } from "../../src/envelope.js";
import type { GateAuditData } from "../../src/tools/v2.js";
import { getV2DefValidator, makeCoreToolsFixture, parseEnvelope } from "../core-tools/test-helpers.js";
import { readResource } from "./test-helpers.js";

async function connect(t: TestContext) {
  const fixture = await makeCoreToolsFixture("v2-resources");
  t.after(fixture.cleanup);
  return fixture.client;
}

test("resources/list and resources/templates/list advertise the two v2 JSON views", async (t) => {
  const client = await connect(t);
  const { resources } = await client.listResources();
  const { resourceTemplates } = await client.listResourceTemplates();
  assert.deepEqual(resources.map(r => [r.uri, r.mimeType]), [["sdd://overview", "application/json"]]);
  assert.deepEqual(resourceTemplates.map(t => [t.uriTemplate, t.mimeType]), [["sdd://feature/{feature}", "application/json"]]);
});

test("sdd://overview includes health and matches the project overview tool", async (t) => {
  const client = await connect(t);
  const resource = await readResource(client, "sdd://overview", "sdd_project_overview_data");
  assert.equal(resource.ok, true);
  assert.ok(resource.data.doctor);
  assert.deepEqual(resource.data.activeFeatures.map(f => f.feature).sort(), ["feature-a", "feature-b"]);
  const feature = resource.data.activeFeatures.find(f => f.feature === "feature-a");
  assert.equal(feature?.taskCounts.total, 2);
  const tool = await client.callTool({ name: "sdd_project_overview", arguments: { includeDoctor: true } });
  assert.deepEqual(parseEnvelope(tool), resource);
});

test("sdd://feature reads the requested feature state and its rendered Decision View", async (t) => {
  const client = await connect(t);
  for (const feature of ["feature-a", "feature-b"]) {
    const resource = await readResource(client, "sdd://feature/" + feature, "sdd_feature_state_data");
    assert.equal(resource.ok, true);
    assert.equal(resource.data.feature, feature);
    assert.ok(resource.data.decisionViewMarkdown?.includes("# Decision View: " + feature));
    const tool = await client.callTool({ name: "sdd_feature_state", arguments: { feature, includeDecisionViewMarkdown: true } });
    assert.deepEqual(parseEnvelope(tool), resource);
  }
});

test("the feature tool defaults to the same state without the resource's optional markdown", async (t) => {
  const client = await connect(t);
  const resource = await readResource(client, "sdd://feature/feature-a", "sdd_feature_state_data");
  assert.equal(resource.ok, true);
  assert.equal(resource.data.files.tasks, true);
  assert.equal(resource.data.traceability.taskCount, 2);
  const { decisionViewMarkdown, ...state } = resource.data;
  assert.ok(decisionViewMarkdown);
  const tool = await client.callTool({ name: "sdd_feature_state", arguments: { feature: "feature-a" } });
  assert.deepEqual(parseEnvelope(tool), { ok: true, data: state });
});

test("a valid missing feature returns the same not-found envelope through both APIs", async (t) => {
  const client = await connect(t);
  const feature = "missing-feature";
  const resource = await readResource(client, "sdd://feature/" + feature, "sdd_feature_state_data");
  assert.equal(resource.ok, false);
  assert.equal(resource.error.code, "not-found");
  const tool = await client.callTool({ name: "sdd_feature_state", arguments: { feature, includeDecisionViewMarkdown: true } });
  assert.deepEqual(parseEnvelope(tool), resource);
});

test("a feature slug containing a space reports the resource and tool input errors", async (t) => {
  const client = await connect(t);
  const resource = await readResource(client, "sdd://feature/feature%20two", "sdd_feature_state_data");
  assert.equal(resource.ok, false);
  assert.equal(resource.error.code, "invalid-input");
  const raw = await client.callTool({ name: "sdd_feature_state", arguments: { feature: "feature two" } });
  const tool = CallToolResultSchema.parse(raw);
  assert.equal(tool.isError, true);
  const [message] = tool.content;
  assert.ok(message?.type === "text");
  assert.match(message.text, /-32602/);
  assert.match(message.text, /Invalid arguments for tool sdd_feature_state/);
});

test("the retired project, spec, task and ticket resource URIs have no public read handler", async (t) => {
  const client = await connect(t);
  for (const uri of [
    "sdd://active-specs", "sdd://spec/feature-a", "sdd://tasks/feature-a", "sdd://review-tickets",
  ]) {
    await assert.rejects(client.readResource({ uri }), { message: new RegExp("Resource " + uri + " not found") });
  }
});

test("the retired quality summary URI is absent and gate audit identifies a task's review report", async (t) => {
  const client = await connect(t);
  await assert.rejects(client.readResource({ uri: "sdd://quality-reports" }), /Resource sdd:\/\/quality-reports not found/);
  const tool = await client.callTool({ name: "sdd_gate_audit", arguments: { feature: "feature-b", taskId: "T-001" } });
  const envelope = parseEnvelope(tool) as Result<GateAuditData>;
  assert.equal(envelope.ok, true);
  const validate = getV2DefValidator("sdd_gate_audit_data");
  assert.ok(validate(envelope.data), JSON.stringify(validate.errors));
  assert.deepEqual(envelope.data.tasks.map(task => task.taskId), ["T-001"]);
  const [task] = envelope.data.tasks;
  assert.equal(task.reviewReport.verdict, "PASS");
  assert.equal(task.executionArtifact.exists, false);
  assert.equal(task.readyForDone, false);
});
