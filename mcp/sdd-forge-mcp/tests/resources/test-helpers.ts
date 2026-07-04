/**
 * Shared (non-test) helpers for the T-009 resources suite. Reuses the T-004
 * core-tools fixture builder (synthetic SDD repo + in-memory MCP
 * client/server pair) so tool <-> resource parity assertions run against the
 * exact same fixture data. Deliberately not named `*.test.ts` (node:test glob
 * avoidance — see mcp/sdd-forge-mcp/.claude/agent-memory/coder
 * feedback-node-test-shared-helpers).
 */

import type { ReadResourceResult } from "@modelcontextprotocol/sdk/types.js";
import { getEnvelopeValidator, makeCoreToolsFixture, parseEnvelope } from "../core-tools/test-helpers.js";
import type { CoreToolsFixture } from "../core-tools/test-helpers.js";

export type { CoreToolsFixture };
export { getEnvelopeValidator, makeCoreToolsFixture };

/** Builds the same synthetic fixture the core-tools suite uses, for tool<->resource parity checks. */
export async function makeResourcesFixture(prefix: string): Promise<CoreToolsFixture> {
  return makeCoreToolsFixture(prefix);
}

/** Parses a single-content `ReadResourceResult`'s `contents[0].text` as JSON (the v1 envelope). */
export function parseResourceEnvelope(result: ReadResourceResult): unknown {
  const first = result.contents[0];
  if (first === undefined || typeof (first as { text?: unknown }).text !== "string") {
    throw new Error(`Expected a text resource content block, got: ${JSON.stringify(result.contents)}`);
  }
  return JSON.parse((first as { text: string }).text);
}

export { parseEnvelope };
