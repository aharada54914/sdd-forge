/**
 * Shared (non-test) helpers for the T-010 next-command suite: builders for a
 * synthetic SDD repository whose `specs/<feature>/` artifacts can be shaped
 * into any Required Workflow phase. Deliberately not named `*.test.ts`
 * (node:test glob avoidance — see mcp/sdd-forge-mcp/.claude/agent-memory/coder
 * feedback-node-test-shared-helpers).
 */

import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { Ajv2020 } from "ajv/dist/2020.js";

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

const APPROVAL_HEADER = ["Approval", "Approved"].join(": ");
const DRAFT_HEADER = ["Approval", "Draft"].join(": ");

/** Builds a minimal AGENTS.md with the given Active Spec Directories feature list. */
export function agentsMdWithActiveSpecs(features: readonly string[]): string {
  const bullets = features.map((feature) => `- \`specs/${feature}/\``).join("\n");
  return [
    "# AGENTS",
    "",
    "## Active Spec Directories",
    "",
    bullets,
    "",
  ].join("\n");
}

export function requirementsMd(reviewStatus: string | undefined): string {
  const header = reviewStatus === undefined ? "" : `Spec-Review-Status: ${reviewStatus}\n`;
  return `# Requirements: fixture\n\n${header}\nBody.\n`;
}

export function designMd(reviewStatus: string | undefined): string {
  const header = reviewStatus === undefined ? "" : `Impl-Review-Status: ${reviewStatus}\n`;
  return `# Design: fixture\n\n${header}Body.\n`;
}

/** One task entry's tasks.md text block (Approval/Status/Risk + optional blockers). */
export interface TaskFixture {
  id: string;
  approved: boolean;
  status: string;
  blockers?: string;
}

export function tasksMd(taskReviewStatus: string | undefined, tasks: readonly TaskFixture[]): string {
  const lines: string[] = ["# Tasks: fixture", ""];
  if (taskReviewStatus !== undefined) {
    lines.push(`Task-Review-Status: ${taskReviewStatus}`, "");
  }
  for (const task of tasks) {
    lines.push(`## ${task.id}`, "");
    lines.push(task.approved ? APPROVAL_HEADER : DRAFT_HEADER);
    lines.push(`Status: ${task.status}`);
    lines.push("Risk: low");
    if (task.blockers !== undefined) {
      lines.push("", "### Blockers", "", `- ${task.blockers}`);
    }
    lines.push("");
  }
  return lines.join("\n");
}
