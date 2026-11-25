/**
 * AC-015: every retained core domain function's `Result` envelope must validate
 * against contracts/sdd-forge-mcp-tools.v1.schema.json and carry the expected
 * `kind` / `feature` / count fields for a synthetic fixture repository. Current
 * public v2 MCP operations (`sdd_dashboard_snapshot`, `sdd_feature_state`,
 * tool inventory) are verified through a real MCP client/server pair
 * (SDK InMemoryTransport) and contracts/sdd-mcp.v2.schema.json.
 *
 * AC-017 (partial): a nonexistent `feature` argument surfaces `not-found` for
 * domain functions that read a per-feature tasks.md.
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import { CallToolResultSchema } from "@modelcontextprotocol/sdk/types.js";
import {
  getNextSddCommand,
  getQualityGateSummary,
  getSpecStatus,
  getTaskState,
  listActiveSpecs,
  listApprovedTasks,
  listBlockedTasks,
  listReviewTicketsTool,
} from "../../src/tools/core.js";
import {
  getEnvelopeValidator,
  getV2DefValidator,
  makeCoreToolsFixture,
  parseEnvelope,
  seedCoreToolsFixture,
} from "./test-helpers.js";

test("list_active_specs: schema-valid, flags feature-a active and feature-b inactive", () => {
  const tempRoot = seedCoreToolsFixture("core-tools-list-active-specs");
  try {
    const envelope = listActiveSpecs(tempRoot.root);
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));

    assert.equal(envelope.ok, true);
    assert.equal(envelope.data.kind, "active-specs");
    const featureA = envelope.data.specs.find((s) => s.feature === "feature-a");
    const featureB = envelope.data.specs.find((s) => s.feature === "feature-b");
    assert.ok(featureA !== undefined && featureA.hasApprovedPlannedOrInProgress === true);
    assert.ok(featureB !== undefined && featureB.hasApprovedPlannedOrInProgress === false);
  } finally {
    tempRoot.cleanup();
  }
});

test("get_spec_status: schema-valid, reports artifact existence and review-status headers", () => {
  const tempRoot = seedCoreToolsFixture("core-tools-get-spec-status");
  try {
    const envelope = getSpecStatus(tempRoot.root, "feature-a");
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));

    assert.equal(envelope.ok, true);
    assert.equal(envelope.data.kind, "spec-status");
    assert.equal(envelope.data.feature, "feature-a");
    const requirements = envelope.data.artifacts.find((a) => a.name === "requirements");
    const design = envelope.data.artifacts.find((a) => a.name === "design");
    const tasksArtifact = envelope.data.artifacts.find((a) => a.name === "tasks");
    const traceability = envelope.data.artifacts.find((a) => a.name === "traceability");
    assert.ok(requirements?.exists === true && requirements.reviewStatus === "Passed");
    assert.ok(design?.exists === true && design.reviewStatus === "Passed");
    assert.ok(tasksArtifact?.exists === true && tasksArtifact.reviewStatus === "Passed");
    assert.ok(traceability?.exists === false && traceability.reviewStatus === undefined);
  } finally {
    tempRoot.cleanup();
  }
});

test("get_task_state: schema-valid, valid task state includes the blocked task in feature-a", () => {
  const tempRoot = seedCoreToolsFixture("core-tools-get-task-state");
  try {
    const envelope = getTaskState(tempRoot.root, "feature-a");
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));

    assert.equal(envelope.ok, true);
    assert.equal(envelope.data.kind, "task-state");
    assert.equal(envelope.data.feature, "feature-a");
    assert.equal(envelope.data.taskCount, 2);
    assert.equal(envelope.data.verdict, "pass");
    assert.deepEqual(envelope.data.tasks.map((task) => [task.id, task.status]), [
      ["T-001", "Planned"],
      ["T-002", "Blocked"],
    ]);
  } finally {
    tempRoot.cleanup();
  }
});

test("get_task_state: not-found for a feature whose tasks.md does not exist", () => {
  const tempRoot = seedCoreToolsFixture("core-tools-get-task-state-missing");
  try {
    const envelope = getTaskState(tempRoot.root, "no-such-feature");
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));
    assert.equal(envelope.ok, false);
    assert.equal(envelope.error.code, "not-found");
  } finally {
    tempRoot.cleanup();
  }
});

test("list_approved_tasks: schema-valid, only Approved-shaped tasks for feature-a", () => {
  const tempRoot = seedCoreToolsFixture("core-tools-list-approved-tasks");
  try {
    const envelope = listApprovedTasks(tempRoot.root, "feature-a");
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));

    assert.equal(envelope.ok, true);
    assert.equal(envelope.data.kind, "approved-tasks");
    assert.equal(envelope.data.feature, "feature-a");
    assert.deepEqual(
      envelope.data.tasks.map((t) => t.id),
      ["T-001"],
    );
  } finally {
    tempRoot.cleanup();
  }
});

test("list_blocked_tasks: schema-valid, only Blocked-status tasks for feature-a", () => {
  const tempRoot = seedCoreToolsFixture("core-tools-list-blocked-tasks");
  try {
    const envelope = listBlockedTasks(tempRoot.root, "feature-a");
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));

    assert.equal(envelope.ok, true);
    assert.equal(envelope.data.kind, "blocked-tasks");
    assert.equal(envelope.data.feature, "feature-a");
    assert.deepEqual(
      envelope.data.tasks.map((t) => t.id),
      ["T-002"],
    );
  } finally {
    tempRoot.cleanup();
  }
});

test("list_review_tickets: schema-valid, includes the seeded RT ticket", () => {
  const tempRoot = seedCoreToolsFixture("core-tools-list-review-tickets");
  try {
    const envelope = listReviewTicketsTool(tempRoot.root);
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));

    assert.equal(envelope.ok, true);
    assert.equal(envelope.data.kind, "review-tickets");
    assert.deepEqual(
      envelope.data.tickets.map((t) => t.ticketId),
      ["RT-20260101-001"],
    );
  } finally {
    tempRoot.cleanup();
  }
});

test("get_quality_gate_summary: schema-valid, includes the seeded PASS report", () => {
  const tempRoot = seedCoreToolsFixture("core-tools-quality-gate-summary");
  try {
    const envelope = getQualityGateSummary(tempRoot.root);
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));

    assert.equal(envelope.ok, true);
    assert.equal(envelope.data.kind, "quality-gate-summary");
    const report = envelope.data.reports.find((r) => r.taskId === "T-001");
    assert.ok(report !== undefined && report.verdict === "PASS");
  } finally {
    tempRoot.cleanup();
  }
});

test("get_next_sdd_command: feature-a has a Blocked task -> blocked takes priority", () => {
  const tempRoot = seedCoreToolsFixture("core-tools-next-command");
  try {
    const envelope = getNextSddCommand(tempRoot.root, "feature-a");
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));

    assert.equal(envelope.ok, true);
    assert.equal(envelope.data.phase, "blocked");
    assert.equal(envelope.data.nextCommand, "human: resolve blockers");
  } finally {
    tempRoot.cleanup();
  }
});

test("get_next_sdd_command: no feature argument auto-selects feature-a (only active feature)", () => {
  const tempRoot = seedCoreToolsFixture("core-tools-next-command-no-feature");
  try {
    const envelope = getNextSddCommand(tempRoot.root);
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));
    assert.equal(envelope.ok, true);
    assert.equal(envelope.data.feature, "feature-a");
    assert.equal(envelope.data.phase, "blocked");
  } finally {
    tempRoot.cleanup();
  }
});

test("every tool's input schema never declares a root parameter", async () => {
  const fixture = await makeCoreToolsFixture("core-tools-no-root-param");
  try {
    const { tools } = await fixture.client.listTools();
    const expectedTools = [
      "sdd_dashboard_snapshot",
      "sdd_feature_state",
      "sdd_gate_audit",
      "sdd_project_overview",
    ];
    assert.deepEqual(
      tools.map((t) => t.name).sort(),
      [...expectedTools].sort(),
    );
    for (const tool of tools) {
      const schema = tool.inputSchema as {
        properties?: Record<string, unknown>;
        additionalProperties?: boolean;
      };
      const properties = schema.properties ?? {};
      assert.ok(!("root" in properties), `tool ${tool.name} must not declare a root input parameter`);
      assert.equal(
        schema.additionalProperties,
        false,
        `tool ${tool.name} strict input schema must reject undeclared parameters including root`,
      );
      assert.equal(tool.annotations?.readOnlyHint, true, `tool ${tool.name} must set readOnlyHint: true`);
      assert.equal(tool.annotations?.destructiveHint, false, `tool ${tool.name} must set destructiveHint: false`);
      assert.equal(tool.annotations?.idempotentHint, true, `tool ${tool.name} must set idempotentHint: true`);
    }
  } finally {
    await fixture.cleanup();
  }
});

test("invalid feature argument shape is rejected as invalid-input", async () => {
  const fixture = await makeCoreToolsFixture("core-tools-invalid-feature");
  try {
    const domainEnvelope = getTaskState(fixture.root, "../escape");
    assert.ok(getEnvelopeValidator()(domainEnvelope), JSON.stringify(getEnvelopeValidator().errors));
    assert.equal(domainEnvelope.ok, false);
    assert.equal(domainEnvelope.error.code, "invalid-input");

    const v2InvalidRaw = await fixture.client.callTool({
      name: "sdd_feature_state",
      arguments: { feature: 42 },
    });
    const v2Invalid = CallToolResultSchema.parse(v2InvalidRaw);
    assert.equal(v2Invalid.isError, true, "v2 SDK Zod validation error must set isError: true");
    const v2InvalidFirst = v2Invalid.content[0];
    assert.ok(v2InvalidFirst?.type === "text");
    assert.match(v2InvalidFirst.text, /Invalid arguments for tool sdd_feature_state/);

    const retired = CallToolResultSchema.parse(
      await fixture.client.callTool({ name: "get_task_state", arguments: { feature: "feature-a" } }),
    );
    assert.equal(retired.isError, true);
    const retiredFirst = retired.content[0];
    assert.ok(retiredFirst?.type === "text");
    assert.match(retiredFirst.text, /Tool get_task_state not found/);

    const missing = CallToolResultSchema.parse(
      await fixture.client.callTool({ name: "sdd_gate_audit", arguments: { feature: "feature-a", taskId: "T-999" } }),
    );
    assert.notEqual(missing.isError, true);
    const missingEnvelope = parseEnvelope(missing);
    const validateError = getV2DefValidator("errorEnvelope");
    assert.ok(validateError(missingEnvelope), JSON.stringify(validateError.errors));
    assert.equal((missingEnvelope as { error: { code: string } }).error.code, "not-found");
  } finally {
    await fixture.cleanup();
  }
});

test("sdd_dashboard_snapshot: real MCP response is schema-valid and read-only", async () => {
  const fixture = await makeCoreToolsFixture("core-tools-dashboard");
  try {
    const rawResult = await fixture.client.callTool({ name: "sdd_dashboard_snapshot", arguments: {} });
    const callResult = CallToolResultSchema.parse(rawResult);
    assert.notEqual(callResult.isError, true, "expected non-error CallToolResult from sdd_dashboard_snapshot");
    const envelope = parseEnvelope(callResult);
    assert.deepEqual(Object.keys(envelope as object).sort(), ["data", "ok"]);
    assert.equal((envelope as { ok: boolean }).ok, true);
    const data = (
      envelope as {
        ok: true;
        data: { kind: string; snapshot: { schema: string; data: { tasks: unknown[] } | null } };
      }
    ).data;
    const validateDashboardData = getV2DefValidator("sdd_dashboard_snapshot_data");
    assert.ok(validateDashboardData(data), JSON.stringify(validateDashboardData.errors));
    assert.equal(data.kind, "dashboard-snapshot");
    assert.equal(data.snapshot.schema, "sdd-dashboard/v1");
    assert.ok(data.snapshot.data !== null && data.snapshot.data.tasks.length > 0);
    const tool = (await fixture.client.listTools()).tools.find((t) => t.name === "sdd_dashboard_snapshot");
    assert.equal(tool?.annotations?.readOnlyHint, true);
  } finally {
    await fixture.cleanup();
  }
});
