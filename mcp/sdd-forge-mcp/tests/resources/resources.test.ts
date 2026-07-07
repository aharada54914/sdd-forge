/**
 * AC-013: every one of the 5 `sdd://` resources, read through a real MCP
 * client/server pair (SDK InMemoryTransport), must (a) appear in
 * resources/list or resources/templates/list, (b) validate against
 * contracts/sdd-forge-mcp-tools.v1.schema.json, and (c) return a JSON body
 * that deep-equals the same-fixture tool call's envelope — resources are a
 * thin view over `tools/core.ts`, never a second implementation.
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import {
  getEnvelopeValidator,
  makeResourcesFixture,
  parseEnvelope,
  parseResourceEnvelope,
} from "./test-helpers.js";

test("resources/list + resources/templates/list together expose all 5 sdd:// resources", async () => {
  const fixture = await makeResourcesFixture("resources-list");
  try {
    const { resources } = await fixture.client.listResources();
    const { resourceTemplates } = await fixture.client.listResourceTemplates();

    const staticUris = resources.map((r) => r.uri).sort();
    assert.deepEqual(staticUris, ["sdd://active-specs", "sdd://quality-reports", "sdd://review-tickets"]);

    const templateUris = resourceTemplates.map((t) => t.uriTemplate).sort();
    assert.deepEqual(templateUris, ["sdd://spec/{feature}", "sdd://tasks/{feature}"]);

    assert.equal(resources.length + resourceTemplates.length, 5);
  } finally {
    await fixture.cleanup();
  }
});

test("sdd://active-specs matches list_active_specs exactly", async () => {
  const fixture = await makeResourcesFixture("resources-active-specs");
  try {
    const toolResult = await fixture.client.callTool({ name: "list_active_specs", arguments: {} });
    const toolEnvelope = parseEnvelope(toolResult as never);

    const resourceResult = await fixture.client.readResource({ uri: "sdd://active-specs" });
    const resourceEnvelope = parseResourceEnvelope(resourceResult);

    assert.ok(getEnvelopeValidator()(resourceEnvelope), JSON.stringify(getEnvelopeValidator().errors));
    assert.deepEqual(resourceEnvelope, toolEnvelope);
    assert.equal(resourceResult.contents[0]?.mimeType, "application/json");
  } finally {
    await fixture.cleanup();
  }
});

test("sdd://spec/{feature} matches get_spec_status exactly", async () => {
  const fixture = await makeResourcesFixture("resources-spec-status");
  try {
    const toolResult = await fixture.client.callTool({
      name: "get_spec_status",
      arguments: { feature: "feature-a" },
    });
    const toolEnvelope = parseEnvelope(toolResult as never);

    const resourceResult = await fixture.client.readResource({ uri: "sdd://spec/feature-a" });
    const resourceEnvelope = parseResourceEnvelope(resourceResult);

    assert.ok(getEnvelopeValidator()(resourceEnvelope), JSON.stringify(getEnvelopeValidator().errors));
    assert.deepEqual(resourceEnvelope, toolEnvelope);
  } finally {
    await fixture.cleanup();
  }
});

test("sdd://tasks/{feature} matches get_task_state exactly", async () => {
  const fixture = await makeResourcesFixture("resources-task-state");
  try {
    const toolResult = await fixture.client.callTool({
      name: "get_task_state",
      arguments: { feature: "feature-a" },
    });
    const toolEnvelope = parseEnvelope(toolResult as never);

    const resourceResult = await fixture.client.readResource({ uri: "sdd://tasks/feature-a" });
    const resourceEnvelope = parseResourceEnvelope(resourceResult);

    assert.ok(getEnvelopeValidator()(resourceEnvelope), JSON.stringify(getEnvelopeValidator().errors));
    assert.deepEqual(resourceEnvelope, toolEnvelope);
  } finally {
    await fixture.cleanup();
  }
});

test("sdd://tasks/{feature} surfaces invalid-input for a malformed feature, same as the tool", async () => {
  const fixture = await makeResourcesFixture("resources-task-state-invalid");
  try {
    const toolResult = await fixture.client.callTool({
      name: "get_task_state",
      arguments: { feature: "../escape" },
    });
    const toolEnvelope = parseEnvelope(toolResult as never) as { ok: false; error: { code: string } };
    assert.equal(toolEnvelope.ok, false);
    assert.equal(toolEnvelope.error.code, "invalid-input");

    const resourceResult = await fixture.client.readResource({ uri: "sdd://tasks/..%2Fescape" });
    const resourceEnvelope = parseResourceEnvelope(resourceResult) as { ok: false; error: { code: string } };

    assert.ok(getEnvelopeValidator()(resourceEnvelope), JSON.stringify(getEnvelopeValidator().errors));
    assert.equal(resourceEnvelope.ok, false);
    assert.equal(resourceEnvelope.error.code, "invalid-input");
  } finally {
    await fixture.cleanup();
  }
});

test("sdd://review-tickets matches list_review_tickets exactly", async () => {
  const fixture = await makeResourcesFixture("resources-review-tickets");
  try {
    const toolResult = await fixture.client.callTool({ name: "list_review_tickets", arguments: {} });
    const toolEnvelope = parseEnvelope(toolResult as never);

    const resourceResult = await fixture.client.readResource({ uri: "sdd://review-tickets" });
    const resourceEnvelope = parseResourceEnvelope(resourceResult);

    assert.ok(getEnvelopeValidator()(resourceEnvelope), JSON.stringify(getEnvelopeValidator().errors));
    assert.deepEqual(resourceEnvelope, toolEnvelope);
  } finally {
    await fixture.cleanup();
  }
});

test("sdd://quality-reports matches get_quality_gate_summary exactly", async () => {
  const fixture = await makeResourcesFixture("resources-quality-reports");
  try {
    const toolResult = await fixture.client.callTool({ name: "get_quality_gate_summary", arguments: {} });
    const toolEnvelope = parseEnvelope(toolResult as never);

    const resourceResult = await fixture.client.readResource({ uri: "sdd://quality-reports" });
    const resourceEnvelope = parseResourceEnvelope(resourceResult);

    assert.ok(getEnvelopeValidator()(resourceEnvelope), JSON.stringify(getEnvelopeValidator().errors));
    assert.deepEqual(resourceEnvelope, toolEnvelope);
  } finally {
    await fixture.cleanup();
  }
});
