import { join } from "node:path";
import { findSddForgeRepoRoot } from "./parsers-state/test-helpers.js";

export function repoPath(...segments: string[]): string {
  return join(findSddForgeRepoRoot(), ...segments);
}

export function packagePath(...segments: string[]): string {
  return join(findSddForgeRepoRoot(), "mcp", "sdd-forge-mcp", ...segments);
}
