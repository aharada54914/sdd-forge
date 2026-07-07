/**
 * Shared (non-test) helper for T-007's ajv contract suite: loads
 * contracts/ci-mcp-tools.v1.schema.json and compiles a strict ajv (draft
 * 2020-12) validator for it. Deliberately not named `*.test.ts` (node:test
 * glob avoidance — mirrors mcp/sdd-forge-mcp/tests/core-tools/test-helpers.ts's
 * ajv-validator pattern).
 */

import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { Ajv2020 } from "ajv/dist/2020.js";

const THIS_FILE_DIR = dirname(fileURLToPath(import.meta.url));

/**
 * Locates contracts/ci-mcp-tools.v1.schema.json by walking upward from this
 * file. Works from both tests/contract/ (real source) and
 * dist-test/tests/contract/ (compiled output) regardless of exact nesting
 * depth.
 */
function findContractsSchemaPath(): string {
  let dir = THIS_FILE_DIR;
  for (let i = 0; i < 12; i += 1) {
    const candidate = join(dir, "contracts", "ci-mcp-tools.v1.schema.json");
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
  throw new Error(`Could not locate contracts/ci-mcp-tools.v1.schema.json above ${THIS_FILE_DIR}`);
}

export type EnvelopeValidator = ((data: unknown) => boolean) & { errors?: unknown };

let cachedValidator: EnvelopeValidator | undefined;

/** Compiles (once) and returns a strict ajv validator for the v1 tool response envelope. */
export function getEnvelopeValidator(): EnvelopeValidator {
  if (cachedValidator !== undefined) {
    return cachedValidator;
  }
  const schema = JSON.parse(readFileSync(findContractsSchemaPath(), "utf-8")) as object;
  const ajv = new Ajv2020({ strict: true });
  const validate = ajv.compile(schema);
  cachedValidator = validate as unknown as EnvelopeValidator;
  return cachedValidator;
}
