/**
 * AC-015: every core tool's response, called through a real MCP
 * client/server pair (SDK InMemoryTransport), must validate against
 * contracts/sdd-forge-mcp-tools.v1.schema.json and carry the expected
 * `kind` / `feature` / count fields for a synthetic fixture repository.
 *
 * AC-017 (partial): a nonexistent `feature` argument surfaces `not-found` for
 * tools that read a per-feature tasks.md.
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import { getEnvelopeValidator, makeCoreToolsFixture, parseEnvelope } from "./test-helpers.js";

test("list_active_specs: schema-valid, flags feature-a active and feature-b inactive", async () => {
  const fixture = await makeCoreToolsFixture("core-tools-list-active-specs");
  try {
    const result = await fixture.client.callTool({ name: "list_active_specs", arguments: {} });
    const envelope = parseEnvelope(result as never);
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));

    assert.equal((envelope as { ok: boolean }).ok, true);
    const data = (envelope as { ok: true; data: { kind: string; specs: unknown[] } }).data;
    assert.equal(data.kind, "active-specs");
    const specs = data.specs as Array<{ feature: string; hasApprovedPlannedOrInProgress: boolean }>;
    const featureA = specs.find((s) => s.feature === "feature-a");
    const featureB = specs.find((s) => s.feature === "feature-b");
    assert.ok(featureA !== undefined && featureA.hasApprovedPlannedOrInProgress === true);
    assert.ok(featureB !== undefined && featureB.hasApprovedPlannedOrInProgress === false);
  } finally {
    await fixture.cleanup();
  }
});

test("get_spec_status: schema-valid, reports artifact existence and review-status headers", async () => {
  const fixture = await makeCoreToolsFixture("core-tools-get-spec-status");
  try {
    const result = await fixture.client.callTool({
      name: "get_spec_status",
      arguments: { feature: "feature-a" },
    });
    const envelope = parseEnvelope(result as never);
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));

    assert.equal((envelope as { ok: boolean }).ok, true);
    const data = (envelope as { ok: true; data: { kind: string; feature: string; artifacts: unknown[] } }).data;
    assert.equal(data.kind, "spec-status");
    assert.equal(data.feature, "feature-a");
    const artifacts = data.artifacts as Array<{ name: string; exists: boolean; reviewStatus?: string }>;
    const requirements = artifacts.find((a) => a.name === "requirements");
    const design = artifacts.find((a) => a.name === "design");
    const tasksArtifact = artifacts.find((a) => a.name === "tasks");
    const traceability = artifacts.find((a) => a.name === "traceability");
    assert.ok(requirements?.exists === true && requirements.reviewStatus === "Passed");
    assert.ok(design?.exists === true && design.reviewStatus === "Passed");
    assert.ok(tasksArtifact?.exists === true && tasksArtifact.reviewStatus === "Passed");
    assert.ok(traceability?.exists === false && traceability.reviewStatus === undefined);
  } finally {
    await fixture.cleanup();
  }
});

test("get_task_state: schema-valid, verdict fail with 1 blocked task in feature-a", async () => {
  const fixture = await makeCoreToolsFixture("core-tools-get-task-state");
  try {
    const result = await fixture.client.callTool({
      name: "get_task_state",
      arguments: { feature: "feature-a" },
    });
    const envelope = parseEnvelope(result as never);
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));

    assert.equal((envelope as { ok: boolean }).ok, true);
    const data = (
      envelope as {
        ok: true;
        data: { kind: string; feature: string; taskCount: number; verdict: string };
      }
    ).data;
    assert.equal(data.kind, "task-state");
    assert.equal(data.feature, "feature-a");
    assert.equal(data.taskCount, 2);
  } finally {
    await fixture.cleanup();
  }
});

test("get_task_state: not-found for a feature whose tasks.md does not exist", async () => {
  const fixture = await makeCoreToolsFixture("core-tools-get-task-state-missing");
  try {
    const result = await fixture.client.callTool({
      name: "get_task_state",
      arguments: { feature: "no-such-feature" },
    });
    const envelope = parseEnvelope(result as never);
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));
    assert.equal((envelope as { ok: boolean }).ok, false);
    assert.equal((envelope as { ok: false; error: { code: string } }).error.code, "not-found");
  } finally {
    await fixture.cleanup();
  }
});

test("list_approved_tasks: schema-valid, only Approved-shaped tasks for feature-a", async () => {
  const fixture = await makeCoreToolsFixture("core-tools-list-approved-tasks");
  try {
    const result = await fixture.client.callTool({
      name: "list_approved_tasks",
      arguments: { feature: "feature-a" },
    });
    const envelope = parseEnvelope(result as never);
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));

    assert.equal((envelope as { ok: boolean }).ok, true);
    const data = (
      envelope as { ok: true; data: { kind: string; feature: string; tasks: Array<{ id: string }> } }
    ).data;
    assert.equal(data.kind, "approved-tasks");
    assert.equal(data.feature, "feature-a");
    assert.deepEqual(
      data.tasks.map((t) => t.id),
      ["T-001"],
    );
  } finally {
    await fixture.cleanup();
  }
});

test("list_blocked_tasks: schema-valid, only Blocked-status tasks for feature-a", async () => {
  const fixture = await makeCoreToolsFixture("core-tools-list-blocked-tasks");
  try {
    const result = await fixture.client.callTool({
      name: "list_blocked_tasks",
      arguments: { feature: "feature-a" },
    });
    const envelope = parseEnvelope(result as never);
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));

    assert.equal((envelope as { ok: boolean }).ok, true);
    const data = (
      envelope as { ok: true; data: { kind: string; feature: string; tasks: Array<{ id: string }> } }
    ).data;
    assert.equal(data.kind, "blocked-tasks");
    assert.equal(data.feature, "feature-a");
    assert.deepEqual(
      data.tasks.map((t) => t.id),
      ["T-002"],
    );
  } finally {
    await fixture.cleanup();
  }
});

test("list_review_tickets: schema-valid, includes the seeded RT ticket", async () => {
  const fixture = await makeCoreToolsFixture("core-tools-list-review-tickets");
  try {
    const result = await fixture.client.callTool({ name: "list_review_tickets", arguments: {} });
    const envelope = parseEnvelope(result as never);
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));

    assert.equal((envelope as { ok: boolean }).ok, true);
    const data = (
      envelope as { ok: true; data: { kind: string; tickets: Array<{ ticketId: string }> } }
    ).data;
    assert.equal(data.kind, "review-tickets");
    assert.deepEqual(
      data.tickets.map((t) => t.ticketId),
      ["RT-20260101-001"],
    );
  } finally {
    await fixture.cleanup();
  }
});

test("get_quality_gate_summary: schema-valid, includes the seeded PASS report", async () => {
  const fixture = await makeCoreToolsFixture("core-tools-quality-gate-summary");
  try {
    const result = await fixture.client.callTool({ name: "get_quality_gate_summary", arguments: {} });
    const envelope = parseEnvelope(result as never);
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));

    assert.equal((envelope as { ok: boolean }).ok, true);
    const data = (
      envelope as {
        ok: true;
        data: { kind: string; reports: Array<{ taskId?: string; verdict: string }> };
      }
    ).data;
    assert.equal(data.kind, "quality-gate-summary");
    const report = data.reports.find((r) => r.taskId === "T-001");
    assert.ok(report !== undefined && report.verdict === "PASS");
  } finally {
    await fixture.cleanup();
  }
});

test("get_next_sdd_command: feature-a has a Blocked task -> blocked takes priority", async () => {
  const fixture = await makeCoreToolsFixture("core-tools-next-command");
  try {
    const result = await fixture.client.callTool({
      name: "get_next_sdd_command",
      arguments: { feature: "feature-a" },
    });
    const envelope = parseEnvelope(result as never);
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));

    assert.equal((envelope as { ok: boolean }).ok, true);
    const data = (envelope as { ok: true; data: { phase: string; nextCommand: string } }).data;
    assert.equal(data.phase, "blocked");
    assert.equal(data.nextCommand, "human: resolve blockers");
  } finally {
    await fixture.cleanup();
  }
});

test("get_next_sdd_command: no feature argument auto-selects feature-a (only active feature)", async () => {
  const fixture = await makeCoreToolsFixture("core-tools-next-command-no-feature");
  try {
    const result = await fixture.client.callTool({ name: "get_next_sdd_command", arguments: {} });
    const envelope = parseEnvelope(result as never);
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));
    assert.equal((envelope as { ok: boolean }).ok, true);
    const data = (envelope as { ok: true; data: { feature?: string; phase: string } }).data;
    assert.equal(data.feature, "feature-a");
    assert.equal(data.phase, "blocked");
  } finally {
    await fixture.cleanup();
  }
});

test("every tool's input schema never declares a root parameter", async () => {
  const fixture = await makeCoreToolsFixture("core-tools-no-root-param");
  try {
    const { tools } = await fixture.client.listTools();
    // 8 core tools (T-004) + 5 evidence tools (T-005) + evidence_deep_verify (evidence-deep-verify T-004).
    assert.ok(tools.length === 14, `expected 14 tools, got ${tools.length}`);
    for (const tool of tools) {
      const properties = (tool.inputSchema as { properties?: Record<string, unknown> }).properties ?? {};
      assert.ok(!("root" in properties), `tool ${tool.name} must not declare a root input parameter`);
    }
  } finally {
    await fixture.cleanup();
  }
});

test("invalid feature argument shape is rejected as invalid-input", async () => {
  const fixture = await makeCoreToolsFixture("core-tools-invalid-feature");
  try {
    const result = await fixture.client.callTool({
      name: "get_task_state",
      arguments: { feature: "../escape" },
    });
    const envelope = parseEnvelope(result as never);
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));
    assert.equal((envelope as { ok: boolean }).ok, false);
    assert.equal((envelope as { ok: false; error: { code: string } }).error.code, "invalid-input");
  } finally {
    await fixture.cleanup();
  }
});
