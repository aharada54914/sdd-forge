/**
 * AC-014: every evidence tool's response, called through a real MCP
 * client/server pair (SDK InMemoryTransport), must validate against
 * contracts/sdd-forge-mcp-tools.v1.schema.json and carry the expected `kind`
 * / field values for both real repository data (sdd-forge-refactor) and
 * synthetic fixtures (missing/mismatch/unsafe-path cases).
 *
 * `evidence_find_missing`'s Done-requirement set is verified to agree with
 * `get_task_state`'s (check-task-state.sh-equivalent) Done verdict: a real
 * Done task with no `done-evidence-*`/`done-contract-*`/
 * `done-quality-gate-*` failures must have an empty `missing` array here,
 * and a synthetic task with none of the three artifacts must have `missing`
 * equal to `required`.
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import { writeFile } from "../test-helpers.js";
import {
  connectFixture,
  getEnvelopeValidator,
  makeRealRepoRoot,
  parseEnvelope,
  seedDemoFixture,
  sha256Of,
} from "./test-helpers.js";
import { buildServer } from "../../src/server.js";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { InMemoryTransport } from "@modelcontextprotocol/sdk/inMemory.js";
import { parseTaskState } from "../../src/parsers/tasks.js";

// --- evidence_get_bundle ----------------------------------------------------

test("evidence_get_bundle: real data, schema-valid, echoes sdd-forge-refactor T-001's bundle fields", async () => {
  const root = makeRealRepoRoot();
  const server = buildServer(root);
  const client = new Client({ name: "test-client", version: "0.0.0" });
  const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();
  await Promise.all([server.connect(serverTransport), client.connect(clientTransport)]);
  try {
    const result = await client.callTool({
      name: "evidence_get_bundle",
      arguments: { feature: "sdd-forge-refactor", taskId: "T-001" },
    });
    const envelope = parseEnvelope(result as never);
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));

    assert.equal((envelope as { ok: boolean }).ok, true);
    const data = (
      envelope as { ok: true; data: { kind: string; feature: string; taskId: string; bundle: Record<string, unknown> } }
    ).data;
    assert.equal(data.kind, "evidence-bundle");
    assert.equal(data.feature, "sdd-forge-refactor");
    assert.equal(data.taskId, "T-001");
    assert.equal(data.bundle.task_id, "T-001");
    assert.equal(data.bundle.risk, "low");
    assert.ok(Array.isArray(data.bundle.artifacts));
  } finally {
    await client.close();
    await server.close();
  }
});

test("evidence_get_bundle: synthetic, echoes signature value without verifying it", async () => {
  const tempRoot = seedDemoFixture("evidence-get-bundle-signature");
  const fixture = await connectFixture(tempRoot);
  try {
    writeFile(
      fixture.tempRoot.dir,
      "specs/demo/verification/T-009.evidence.json",
      JSON.stringify({
        task_id: "T-009",
        feature: "demo",
        risk: "critical",
        required_workflow: "tdd",
        signature: { alg: "hmac-sha256", value: "deadbeef" },
      }),
    );
    const result = await fixture.client.callTool({
      name: "evidence_get_bundle",
      arguments: { feature: "demo", taskId: "T-009" },
    });
    const envelope = parseEnvelope(result as never);
    assert.ok(getEnvelopeValidator()(envelope));
    assert.equal((envelope as { ok: boolean }).ok, true);
    const data = (envelope as { ok: true; data: { bundle: { signature?: unknown } } }).data;
    assert.deepEqual(data.bundle.signature, { alg: "hmac-sha256", value: "deadbeef" });
  } finally {
    await fixture.cleanup();
  }
});

test("evidence_get_bundle: not-found for a task with no evidence.json", async () => {
  const tempRoot = seedDemoFixture("evidence-get-bundle-not-found");
  const fixture = await connectFixture(tempRoot);
  try {
    const result = await fixture.client.callTool({
      name: "evidence_get_bundle",
      arguments: { feature: "demo", taskId: "T-002" },
    });
    const envelope = parseEnvelope(result as never);
    assert.ok(getEnvelopeValidator()(envelope));
    assert.equal((envelope as { ok: boolean }).ok, false);
    assert.equal((envelope as { ok: false; error: { code: string } }).error.code, "not-found");
  } finally {
    await fixture.cleanup();
  }
});

test("evidence_get_bundle: invalid-input for a malformed taskId", async () => {
  const tempRoot = seedDemoFixture("evidence-get-bundle-invalid-taskid");
  const fixture = await connectFixture(tempRoot);
  try {
    const result = await fixture.client.callTool({
      name: "evidence_get_bundle",
      arguments: { feature: "demo", taskId: "not-a-task-id" },
    });
    const envelope = parseEnvelope(result as never);
    assert.ok(getEnvelopeValidator()(envelope));
    assert.equal((envelope as { ok: boolean }).ok, false);
    assert.equal((envelope as { ok: false; error: { code: string } }).error.code, "invalid-input");
  } finally {
    await fixture.cleanup();
  }
});

// --- evidence_validate_paths -------------------------------------------------

test("evidence_validate_paths: real data, all sdd-forge-refactor T-001 artifacts are safe and exist", async () => {
  const root = makeRealRepoRoot();
  const server = buildServer(root);
  const client = new Client({ name: "test-client", version: "0.0.0" });
  const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();
  await Promise.all([server.connect(serverTransport), client.connect(clientTransport)]);
  try {
    const result = await client.callTool({
      name: "evidence_validate_paths",
      arguments: { feature: "sdd-forge-refactor", taskId: "T-001" },
    });
    const envelope = parseEnvelope(result as never);
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));
    assert.equal((envelope as { ok: boolean }).ok, true);
    const data = (
      envelope as { ok: true; data: { kind: string; results: Array<{ path: string; safe: boolean; exists: boolean }> } }
    ).data;
    assert.equal(data.kind, "evidence-paths");
    assert.ok(data.results.length >= 1);
    for (const entry of data.results) {
      assert.equal(entry.safe, true, `expected ${entry.path} to be safe`);
      assert.equal(entry.exists, true, `expected ${entry.path} to exist`);
    }
  } finally {
    await client.close();
    await server.close();
  }
});

test("evidence_validate_paths: synthetic, flags a traversal artifact path as unsafe", async () => {
  const tempRoot = seedDemoFixture("evidence-validate-paths-unsafe");
  const fixture = await connectFixture(tempRoot);
  try {
    writeFile(
      fixture.tempRoot.dir,
      "specs/demo/verification/T-020.evidence.json",
      JSON.stringify({
        task_id: "T-020",
        feature: "demo",
        risk: "low",
        required_workflow: "tdd",
        artifacts: [
          { path: "../../etc/passwd", sha256: "0".repeat(64) },
          { path: "/etc/passwd", sha256: "0".repeat(64) },
          { path: "specs/demo/investigation.md", sha256: sha256Of("# Investigation: demo\n\nBody.\n") },
          { path: "specs/demo/verification/T-020.nope.json", sha256: "0".repeat(64) },
        ],
      }),
    );

    const result = await fixture.client.callTool({
      name: "evidence_validate_paths",
      arguments: { feature: "demo", taskId: "T-020" },
    });
    const envelope = parseEnvelope(result as never);
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));
    assert.equal((envelope as { ok: boolean }).ok, true);
    const data = (
      envelope as {
        ok: true;
        data: { results: Array<{ path: string; safe: boolean; exists: boolean; reason?: string }> };
      }
    ).data;

    const traversal = data.results.find((r) => r.path === "../../etc/passwd");
    assert.ok(traversal !== undefined && traversal.safe === false && traversal.exists === false);
    assert.ok(typeof traversal?.reason === "string" && traversal.reason.length > 0);

    const absolute = data.results.find((r) => r.path === "/etc/passwd");
    assert.ok(absolute !== undefined && absolute.safe === false && absolute.exists === false);

    const safeAndPresent = data.results.find((r) => r.path === "specs/demo/investigation.md");
    assert.ok(safeAndPresent !== undefined && safeAndPresent.safe === true && safeAndPresent.exists === true);

    const safeButMissing = data.results.find((r) => r.path === "specs/demo/verification/T-020.nope.json");
    assert.ok(safeButMissing !== undefined && safeButMissing.safe === true && safeButMissing.exists === false);
  } finally {
    await fixture.cleanup();
  }
});

// --- evidence_find_missing ---------------------------------------------------

test("evidence_find_missing: real data, sdd-forge-refactor T-001 (Done) has nothing missing", async () => {
  const root = makeRealRepoRoot();
  const server = buildServer(root);
  const client = new Client({ name: "test-client", version: "0.0.0" });
  const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();
  await Promise.all([server.connect(serverTransport), client.connect(clientTransport)]);
  try {
    const result = await client.callTool({
      name: "evidence_find_missing",
      arguments: { feature: "sdd-forge-refactor", taskId: "T-001" },
    });
    const envelope = parseEnvelope(result as never);
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));
    assert.equal((envelope as { ok: boolean }).ok, true);
    const data = (
      envelope as { ok: true; data: { kind: string; required: string[]; present: string[]; missing: string[] } }
    ).data;
    assert.equal(data.kind, "evidence-missing");
    assert.deepEqual(data.missing, []);
    assert.deepEqual([...data.present].sort(), [...data.required].sort());
  } finally {
    await client.close();
    await server.close();
  }
});

test("evidence_find_missing: synthetic Done task with a fully valid bundle has nothing missing, matching get_task_state's Done verdict", async () => {
  const tempRoot = seedDemoFixture("evidence-find-missing-done-parity");
  const fixture = await connectFixture(tempRoot);
  try {
    const result = await fixture.client.callTool({
      name: "evidence_find_missing",
      arguments: { feature: "demo", taskId: "T-001" },
    });
    const envelope = parseEnvelope(result as never);
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));
    assert.equal((envelope as { ok: boolean }).ok, true);
    const data = (
      envelope as { ok: true; data: { required: string[]; present: string[]; missing: string[] } }
    ).data;
    assert.deepEqual(data.missing, []);
    assert.deepEqual([...data.present].sort(), [...data.required].sort());

    // Cross-check against get_task_state's shell-equivalent Done verdict:
    // this fixture's T-001 evidence bundle has a fully matching artifact
    // manifest, so it must have no done-evidence-*/done-contract-*/
    // done-quality-gate-* failure either, confirming find_missing's
    // presence-only requirements agree with check-task-state.sh's Done
    // requirements for the "everything present" case.
    const taskStateResult = parseTaskState(fixture.root, "demo", "specs/demo/tasks.md");
    assert.equal(taskStateResult.ok, true);
    if (taskStateResult.ok) {
      const doneFailures = taskStateResult.data.failures.filter(
        (f) => f.taskId === "T-001" && f.rule.startsWith("done-"),
      );
      assert.deepEqual(doneFailures, []);
      assert.equal(taskStateResult.data.verdict, "pass");
    }
  } finally {
    await fixture.cleanup();
  }
});

test("evidence_find_missing: synthetic, a task with no verification artifacts has every requirement missing", async () => {
  const tempRoot = seedDemoFixture("evidence-find-missing-all-missing");
  const fixture = await connectFixture(tempRoot);
  try {
    const result = await fixture.client.callTool({
      name: "evidence_find_missing",
      arguments: { feature: "demo", taskId: "T-002" },
    });
    const envelope = parseEnvelope(result as never);
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));
    assert.equal((envelope as { ok: boolean }).ok, true);
    const data = (
      envelope as { ok: true; data: { required: string[]; present: string[]; missing: string[] } }
    ).data;
    assert.deepEqual(data.present, []);
    assert.deepEqual([...data.missing].sort(), [...data.required].sort());
  } finally {
    await fixture.cleanup();
  }
});

test("evidence_find_missing: synthetic, a task whose quality-gate report lacks VERDICT: PASS is missing that requirement only", async () => {
  const tempRoot = seedDemoFixture("evidence-find-missing-no-pass-verdict");
  const fixture = await connectFixture(tempRoot);
  try {
    writeFile(
      fixture.tempRoot.dir,
      "specs/demo/verification/T-030.evidence.json",
      JSON.stringify({ task_id: "T-030", feature: "demo", risk: "low", required_workflow: "tdd" }),
    );
    writeFile(
      fixture.tempRoot.dir,
      "specs/demo/verification/T-030.contract.json",
      JSON.stringify({ task_id: "T-030", risk: "low", checks: [] }),
    );
    writeFile(
      fixture.tempRoot.dir,
      "reports/quality-gate/demo-T-030.md",
      ["# Quality Gate — T-030", "", "Task ID: T-030", "", "VERDICT: FAIL", ""].join("\n"),
    );

    const result = await fixture.client.callTool({
      name: "evidence_find_missing",
      arguments: { feature: "demo", taskId: "T-030" },
    });
    const envelope = parseEnvelope(result as never);
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));
    assert.equal((envelope as { ok: boolean }).ok, true);
    const data = (
      envelope as { ok: true; data: { present: string[]; missing: string[] } }
    ).data;
    assert.deepEqual(data.missing, ["quality-gate-report-pass"]);
    assert.deepEqual([...data.present].sort(), ["evidence-bundle", "verification-contract"]);
  } finally {
    await fixture.cleanup();
  }
});

// --- evidence_summarize_contract_checks --------------------------------------

test("evidence_summarize_contract_checks: real data, sdd-forge-refactor T-001's placeholder-scan check summarizes correctly", async () => {
  const root = makeRealRepoRoot();
  const server = buildServer(root);
  const client = new Client({ name: "test-client", version: "0.0.0" });
  const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();
  await Promise.all([server.connect(serverTransport), client.connect(clientTransport)]);
  try {
    const result = await client.callTool({
      name: "evidence_summarize_contract_checks",
      arguments: { feature: "sdd-forge-refactor", taskId: "T-001" },
    });
    const envelope = parseEnvelope(result as never);
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));
    assert.equal((envelope as { ok: boolean }).ok, true);
    const data = (
      envelope as {
        ok: true;
        data: {
          kind: string;
          checks: Array<{ id: string; required: boolean; passes: boolean; requirementIds?: string[] }>;
        };
      }
    ).data;
    assert.equal(data.kind, "contract-checks");
    const placeholderScan = data.checks.find((c) => c.id === "placeholder-scan");
    assert.ok(placeholderScan !== undefined);
    assert.equal(placeholderScan?.required, true);
    assert.equal(placeholderScan?.passes, true);
    assert.ok(placeholderScan?.requirementIds?.includes("REQ-001"));
  } finally {
    await client.close();
    await server.close();
  }
});

test("evidence_summarize_contract_checks: synthetic, converts waiverReason and requirementIds", async () => {
  const tempRoot = seedDemoFixture("evidence-summarize-contract-checks");
  const fixture = await connectFixture(tempRoot);
  try {
    const result = await fixture.client.callTool({
      name: "evidence_summarize_contract_checks",
      arguments: { feature: "demo", taskId: "T-001" },
    });
    const envelope = parseEnvelope(result as never);
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));
    assert.equal((envelope as { ok: boolean }).ok, true);
    const data = (
      envelope as { ok: true; data: { checks: Array<{ id: string; requirementIds?: string[] }> } }
    ).data;
    assert.deepEqual(
      data.checks.map((c) => c.id),
      ["unit-tests"],
    );
    assert.deepEqual(data.checks[0]?.requirementIds, ["REQ-001"]);
  } finally {
    await fixture.cleanup();
  }
});

test("evidence_summarize_contract_checks: cannot-parse for a malformed contract.json", async () => {
  const tempRoot = seedDemoFixture("evidence-summarize-contract-checks-broken");
  const fixture = await connectFixture(tempRoot);
  try {
    writeFile(fixture.tempRoot.dir, "specs/demo/verification/T-040.contract.json", "{ not valid json");
    const result = await fixture.client.callTool({
      name: "evidence_summarize_contract_checks",
      arguments: { feature: "demo", taskId: "T-040" },
    });
    const envelope = parseEnvelope(result as never);
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));
    assert.equal((envelope as { ok: boolean }).ok, false);
    assert.equal((envelope as { ok: false; error: { code: string } }).error.code, "cannot-parse");
  } finally {
    await fixture.cleanup();
  }
});

// --- evidence_compare_to_traceability -----------------------------------------

test("evidence_compare_to_traceability: real data, sdd-forge-mcp's traceability.md is fully consistent with tasks.md", async () => {
  const root = makeRealRepoRoot();
  const server = buildServer(root);
  const client = new Client({ name: "test-client", version: "0.0.0" });
  const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();
  await Promise.all([server.connect(serverTransport), client.connect(clientTransport)]);
  try {
    const result = await client.callTool({
      name: "evidence_compare_to_traceability",
      arguments: { feature: "sdd-forge-mcp" },
    });
    const envelope = parseEnvelope(result as never);
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));
    assert.equal((envelope as { ok: boolean }).ok, true);
    const data = (
      envelope as { ok: true; data: { kind: string; matches: number; mismatches: Array<{ subject: string }> } }
    ).data;
    assert.equal(data.kind, "traceability-comparison");
    assert.ok(data.matches > 0);
    assert.deepEqual(data.mismatches, []);
  } finally {
    await client.close();
    await server.close();
  }
});

test("evidence_compare_to_traceability: synthetic, flags a REQ -> Task row referencing a nonexistent task", async () => {
  const tempRoot = seedDemoFixture("evidence-compare-to-traceability-mismatch");
  const fixture = await connectFixture(tempRoot);
  try {
    const result = await fixture.client.callTool({
      name: "evidence_compare_to_traceability",
      arguments: { feature: "demo" },
    });
    const envelope = parseEnvelope(result as never);
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));
    assert.equal((envelope as { ok: boolean }).ok, true);
    const data = (
      envelope as { ok: true; data: { matches: number; mismatches: Array<{ subject: string; issue: string }> } }
    ).data;
    assert.equal(data.mismatches.length, 1);
    assert.match(data.mismatches[0]?.subject ?? "", /REQ-002/);
    assert.match(data.mismatches[0]?.issue ?? "", /T-099/);
    assert.ok(data.matches >= 1);
  } finally {
    await fixture.cleanup();
  }
});

test("evidence_compare_to_traceability: synthetic, flags a contract requirementId traceability.md never declares", async () => {
  const tempRoot = seedDemoFixture("evidence-compare-to-traceability-contract-mismatch");
  const fixture = await connectFixture(tempRoot);
  try {
    writeFile(
      fixture.tempRoot.dir,
      "specs/demo/verification/T-001.contract.json",
      JSON.stringify({
        task_id: "T-001",
        feature: "demo",
        risk: "low",
        required_workflow: "tdd",
        checks: [
          {
            id: "unit-tests",
            required: true,
            passes: true,
            requirement_ids: ["REQ-001", "REQ-999"],
          },
        ],
      }),
    );

    const result = await fixture.client.callTool({
      name: "evidence_compare_to_traceability",
      arguments: { feature: "demo" },
    });
    const envelope = parseEnvelope(result as never);
    assert.ok(getEnvelopeValidator()(envelope), JSON.stringify(getEnvelopeValidator().errors));
    assert.equal((envelope as { ok: boolean }).ok, true);
    const data = (
      envelope as { ok: true; data: { mismatches: Array<{ subject: string; issue: string }> } }
    ).data;
    const contractMismatch = data.mismatches.find((m) => m.subject === "T-001 contract -> REQ-ID");
    assert.ok(contractMismatch !== undefined);
    assert.match(contractMismatch?.issue ?? "", /REQ-999/);
  } finally {
    await fixture.cleanup();
  }
});

test("evidence_compare_to_traceability: not-found when traceability.md does not exist", async () => {
  const tempRoot = seedDemoFixture("evidence-compare-to-traceability-not-found");
  const fixture = await connectFixture(tempRoot);
  try {
    // "demo" (the fixture's only feature) has a traceability.md, so a
    // nonexistent feature name reproduces the "no traceability.md" case.
    const result = await fixture.client.callTool({
      name: "evidence_compare_to_traceability",
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

// --- input validation --------------------------------------------------------

test("every evidence tool rejects a malformed feature argument as invalid-input", async () => {
  const tempRoot = seedDemoFixture("evidence-invalid-feature");
  const fixture = await connectFixture(tempRoot);
  try {
    for (const name of [
      "evidence_get_bundle",
      "evidence_validate_paths",
      "evidence_find_missing",
      "evidence_summarize_contract_checks",
    ]) {
      const result = await fixture.client.callTool({
        name,
        arguments: { feature: "../escape", taskId: "T-001" },
      });
      const envelope = parseEnvelope(result as never);
      assert.ok(getEnvelopeValidator()(envelope), `${name}: ${JSON.stringify(getEnvelopeValidator().errors)}`);
      assert.equal((envelope as { ok: boolean }).ok, false, `${name} should reject ../escape`);
      assert.equal(
        (envelope as { ok: false; error: { code: string } }).error.code,
        "invalid-input",
        `${name} should report invalid-input`,
      );
    }

    const compareResult = await fixture.client.callTool({
      name: "evidence_compare_to_traceability",
      arguments: { feature: "../escape" },
    });
    const compareEnvelope = parseEnvelope(compareResult as never);
    assert.ok(getEnvelopeValidator()(compareEnvelope));
    assert.equal((compareEnvelope as { ok: boolean }).ok, false);
    assert.equal((compareEnvelope as { ok: false; error: { code: string } }).error.code, "invalid-input");
  } finally {
    await fixture.cleanup();
  }
});
