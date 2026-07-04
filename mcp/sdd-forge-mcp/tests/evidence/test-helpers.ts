/**
 * Shared (non-test) helpers for the T-005 evidence-tools suite: locating the
 * real sdd-forge repo root, and building synthetic SDD repository fixtures
 * plus an in-memory MCP client/server pair. Deliberately not named
 * `*.test.ts` (node:test glob avoidance — see
 * mcp/sdd-forge-mcp/.claude/agent-memory/coder
 * feedback-node-test-shared-helpers).
 */

import { createHash } from "node:crypto";
import { existsSync, readFileSync, realpathSync } from "node:fs";
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

/**
 * Locates the real sdd-forge repository root by walking upward from this
 * file's compiled location until `AGENTS.md` + `specs/` are both present.
 * Used only by the "real file" verification tests in this suite — synthetic
 * fixture tests use `makeTempSddRoot` from `tests/test-helpers.ts` instead.
 */
export function findSddForgeRepoRoot(): string {
  let dir = THIS_FILE_DIR;
  for (let i = 0; i < 12; i += 1) {
    if (existsSync(join(dir, "AGENTS.md")) && existsSync(join(dir, "specs"))) {
      return dir;
    }
    const parent = dirname(dir);
    if (parent === dir) {
      break;
    }
    dir = parent;
  }
  throw new Error(`Could not locate sdd-forge repo root above ${THIS_FILE_DIR}`);
}

/** Builds a frozen `SddRoot` pointing at the real sdd-forge repository. */
export function makeRealRepoRoot(): SddRoot {
  return Object.freeze({ path: realpathSync(findSddForgeRepoRoot()), source: "cwd" as const });
}

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

export function sha256Of(contents: string): string {
  return createHash("sha256").update(contents, "utf-8").digest("hex");
}

export interface EvidenceToolsFixture {
  tempRoot: TempSddRoot;
  root: SddRoot;
  client: Client;
  cleanup: () => Promise<void>;
}

/**
 * Connects a fresh in-memory MCP client/server pair (via
 * `InMemoryTransport.createLinkedPair()`) to an already-populated temp SDD
 * root, ready for `client.callTool(...)`.
 */
export async function connectFixture(tempRoot: TempSddRoot): Promise<EvidenceToolsFixture> {
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

/**
 * Builds a synthetic feature `demo` with:
 * - `T-001`: Done, Approved, low risk, a complete + valid evidence bundle
 *   (matching artifact manifest, passing quality-gate report, matching
 *   contract) — the "everything present" case for `evidence_find_missing`.
 * - `T-002`: Approved, Planned (not Done yet) with no verification/ artifacts
 *   at all — the "everything missing" case for `evidence_find_missing`.
 * - A `traceability.md` with one REQ -> Task row pointing at `T-001` (valid)
 *   and one pointing at a nonexistent `T-099` (mismatch), plus an
 *   AC -> TEST -> Task row pointing at `T-001`.
 *
 * Returns the connected fixture plus the artifact contents' sha256 (so
 * per-test assertions can rebuild expectations without re-reading files).
 */
export function seedDemoFixture(prefix: string): TempSddRoot {
  const tempRoot = makeTempSddRoot(prefix);
  const dir = tempRoot.dir;

  writeFile(
    dir,
    "AGENTS.md",
    ["# AGENTS", "", "## Active Spec Directories", "", "- `specs/demo/`", ""].join("\n"),
  );

  const tasksLines = [
    "# Tasks: demo",
    "",
    ["Task-Review-Status", "Passed"].join(": "),
    "",
    "## T-001",
    "",
    ["Approval", "Approved (alice 2026-01-01T00:00:00Z)"].join(": "),
    "Status: Done",
    "Risk: low",
    "",
    "## T-002",
    "",
    ["Approval", "Approved (alice 2026-01-01T00:00:00Z)"].join(": "),
    "Status: Planned",
    "Risk: low",
    "",
  ];
  writeFile(dir, "specs/demo/tasks.md", tasksLines.join("\n"));

  const investigationContents = "# Investigation: demo\n\nBody.\n";
  writeFile(dir, "specs/demo/investigation.md", investigationContents);

  const qualityReportContents = [
    "# Quality Gate — T-001",
    "",
    "Task ID: T-001",
    "Feature: demo",
    "",
    "VERDICT: PASS",
    "",
  ].join("\n");
  writeFile(dir, "reports/quality-gate/demo-T-001.md", qualityReportContents);

  const contractContents = JSON.stringify({
    task_id: "T-001",
    feature: "demo",
    risk: "low",
    required_workflow: "tdd",
    checks: [
      {
        id: "unit-tests",
        required: true,
        passes: true,
        evidence: "specs/demo/investigation.md",
        requirement_ids: ["REQ-001"],
      },
    ],
  });
  writeFile(dir, "specs/demo/verification/T-001.contract.json", contractContents);

  const bundle = {
    task_id: "T-001",
    feature: "demo",
    risk: "low",
    required_workflow: "tdd",
    quality_report: "reports/quality-gate/demo-T-001.md",
    verification_contract: "specs/demo/verification/T-001.contract.json",
    git_commit: "a".repeat(40),
    git_generated_dirty: false,
    artifacts: [
      {
        path: "reports/quality-gate/demo-T-001.md",
        sha256: sha256Of(qualityReportContents),
      },
      {
        path: "specs/demo/verification/T-001.contract.json",
        sha256: sha256Of(contractContents),
      },
      {
        path: "specs/demo/investigation.md",
        sha256: sha256Of(investigationContents),
      },
    ],
  };
  writeFile(dir, "specs/demo/verification/T-001.evidence.json", JSON.stringify(bundle));

  writeFile(
    dir,
    "specs/demo/traceability.md",
    [
      "# Traceability: demo",
      "",
      "## REQ -> Task",
      "",
      "| REQ-ID | Task-ID |",
      "|--------|---------|",
      "| REQ-001 | T-001 |",
      "| REQ-002 | T-099 |",
      "",
      "## AC -> TEST -> Task",
      "",
      "| AC-ID | TEST-ID | Task-ID |",
      "|-------|---------|---------|",
      "| AC-001 | TEST-001 | T-001 |",
      "",
    ].join("\n"),
  );

  return tempRoot;
}
