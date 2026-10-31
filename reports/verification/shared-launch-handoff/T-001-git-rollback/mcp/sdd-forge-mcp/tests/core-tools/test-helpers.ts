/**
 * Shared (non-test) helpers for the T-004 core-tools suite: a synthetic SDD
 * repository fixture, an ajv v1-envelope schema validator, and an in-memory
 * MCP client/server pair. Deliberately not named `*.test.ts` (node:test glob
 * avoidance — see mcp/sdd-forge-mcp/.claude/agent-memory/coder
 * feedback-node-test-shared-helpers).
 */

import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { Ajv2020 } from "ajv/dist/2020.js";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { InMemoryTransport } from "@modelcontextprotocol/sdk/inMemory.js";
import type { CallToolResult } from "@modelcontextprotocol/sdk/types.js";
import { buildServer } from "../../src/server.js";
import type { SddRoot } from "../../src/root.js";
import { makeTempSddRoot, writeFile, type TempSddRoot } from "../test-helpers.js";

const THIS_FILE_DIR = dirname(fileURLToPath(import.meta.url));

/** Locates contracts/sdd-forge-mcp-tools.v1.schema.json by walking upward from this file. */
function findContractsSchemaPath(): string {
  let dir = THIS_FILE_DIR;
  for (let i = 0; i < 12; i += 1) {
    const candidate = join(dir, "contracts", "sdd-forge-mcp-tools.v1.schema.json");
    try {
      readFileSync(candidate, "utf-8");
      return candidate;
    } catch {
      // keep walking upward
    }
    const parent = dirname(dir);
    if (parent === dir) {
      break;
    }
    dir = parent;
  }
  throw new Error(`Could not locate contracts/sdd-forge-mcp-tools.v1.schema.json above ${THIS_FILE_DIR}`);
}

let cachedValidator: ((data: unknown) => boolean) & { errors?: unknown } | undefined;

/** Compiles (once) and returns an ajv validator for the v1 tool response envelope. */
export function getEnvelopeValidator(): ((data: unknown) => boolean) & { errors?: unknown } {
  if (cachedValidator !== undefined) {
    return cachedValidator;
  }
  const schema = JSON.parse(readFileSync(findContractsSchemaPath(), "utf-8")) as object;
  const ajv = new Ajv2020({ strict: true });
  const validate = ajv.compile(schema);
  cachedValidator = validate as unknown as ((data: unknown) => boolean) & { errors?: unknown };
  return cachedValidator;
}

/** Parses a `CallToolResult`'s `content[0].text` as JSON (the v1 envelope). */
export function parseEnvelope(result: CallToolResult): unknown {
  const first = result.content[0];
  if (first === undefined || first.type !== "text") {
    throw new Error(`Expected a text content block, got: ${JSON.stringify(result.content)}`);
  }
  return JSON.parse(first.text);
}

export interface CoreToolsFixture {
  tempRoot: TempSddRoot;
  root: SddRoot;
  client: Client;
  cleanup: () => Promise<void>;
}

/**
 * Builds a synthetic SDD repository fixture under a temp directory with two
 * active spec features (`feature-a` fully populated with Phase 1/2
 * artifacts and a rich tasks.md, `feature-b` a minimal tasks.md with no
 * active task), one review ticket, and one quality-gate report — enough
 * surface for every one of the 8 core tools to return non-trivial data.
 */
function seedFixtureRepo(dir: string): void {
  writeFile(
    dir,
    "AGENTS.md",
    [
      "# AGENTS",
      "",
      "## Active Spec Directories",
      "",
      "- `specs/feature-a/`",
      "- `specs/feature-b/`",
      "",
      "## Required Workflow",
      "",
      "1. Write requirements.",
      "2. Implement.",
      "",
    ].join("\n"),
  );

  writeFile(
    dir,
    "specs/feature-a/requirements.md",
    ["# Requirements: feature-a", "", "Spec-Review-Status: Passed", "", "Body.", ""].join("\n"),
  );
  writeFile(
    dir,
    "specs/feature-a/design.md",
    ["# Design: feature-a", "", "Impl-Review-Status: Passed", "", "Body.", ""].join("\n"),
  );
  writeFile(dir, "specs/feature-a/acceptance-tests.md", ["# Acceptance Tests: feature-a", "", "Body.", ""].join("\n"));

  const featureATasksLines = [
    "# Tasks: feature-a",
    "",
    ["Task-Review-Status", "Passed"].join(": "),
    "",
    "## T-001",
    "",
    ["Approval", "Approved (alice 2026-01-01T00:00:00Z)"].join(": "),
    "Status: Planned",
    "Risk: low",
    "",
    "## T-002",
    "",
    "Approval: Draft",
    "Status: Blocked",
    "",
    "### Blockers",
    "",
    "- waiting on design review",
    "",
  ];
  writeFile(dir, "specs/feature-a/tasks.md", featureATasksLines.join("\n"));

  // feature-b: a single Done, already-Approved task with no active
  // (Planned/In Progress) work — hasApprovedPlannedOrInProgress must be false.
  const featureBTasksLines = [
    "# Tasks: feature-b",
    "",
    ["Task-Review-Status", "Passed"].join(": "),
    "",
    "## T-001",
    "",
    ["Approval", "Approved (bob 2026-01-01T00:00:00Z)"].join(": "),
    "Status: Done",
    "Risk: low",
    "",
  ];
  writeFile(dir, "specs/feature-b/tasks.md", featureBTasksLines.join("\n"));
  writeFile(
    dir,
    "specs/feature-b/verification/T-001.evidence.json",
    JSON.stringify({
      task_id: "T-001",
      git_commit: "a".repeat(40),
      test_command: "npm test",
      test_output_hash: "b".repeat(64),
      timestamp: "2026-01-01T00:00:00Z",
      signature: "sig",
    }),
  );
  writeFile(dir, "specs/feature-b/verification/T-001.contract.json", JSON.stringify({ task_id: "T-001" }));
  writeFile(
    dir,
    "reports/quality-gate/feature-b-T-001.md",
    ["# Quality Gate Report", "", "Task ID: T-001", "Feature: feature-b", "", "VERDICT: PASS", ""].join("\n"),
  );

  writeFile(
    dir,
    "reports/implementation/feature-a-T-002.md",
    ["# Implementation Report", "", "Task ID: T-002", ""].join("\n"),
  );

  writeFile(
    dir,
    "docs/review-tickets/RT-20260101-001.yml",
    [
      "ticket_id: RT-20260101-001",
      "status: open",
      "severity: major",
      "type: bug",
      "target:",
      "  feature: feature-a",
      "  task: T-002",
      "summary: Something to fix.",
      "",
    ].join("\n"),
  );
}

/**
 * Builds the synthetic fixture repo plus a connected in-memory MCP
 * client/server pair (via `InMemoryTransport.createLinkedPair()`), ready for
 * `client.callTool(...)`.
 */
export async function makeCoreToolsFixture(prefix: string): Promise<CoreToolsFixture> {
  const tempRoot = makeTempSddRoot(prefix);
  seedFixtureRepo(tempRoot.dir);

  const server = buildServer(tempRoot.root);
  const client = new Client({ name: "test-client", version: "0.0.0" });
  const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();

  await Promise.all([server.connect(serverTransport), client.connect(clientTransport)]);

  return {
    tempRoot,
    root: tempRoot.root,
    client,
    cleanup: async () => {
      await client.close();
      await server.close();
      tempRoot.cleanup();
    },
  };
}
