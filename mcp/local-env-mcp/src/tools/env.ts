/**
 * The three local-env-mcp tools (design.md "API / Contract Plan"):
 *   - get_os_info            — os/process facts only (no probing, no input)
 *   - get_toolchain_versions — version probe over the allowlist (optional names)
 *   - list_available_clis    — availability-only probe over the whole allowlist
 *
 * Every function returns the common `Result<T>` envelope
 * (contracts/local-env-mcp-tools.v1.schema.json). No filesystem writes, no
 * process launching happens here: the ONLY way a process is started is by
 * handing fixed allowlist entries to the probe-engine, which uses `execFile`
 * (no shell) exclusively. User input can only *filter* the allowlist by name
 * (a zod enum) — it can never supply a command, argument, or path (B1/B2
 * trust boundaries, REQ-003, AC-003, AC-006).
 *
 * The `names` input is validated with a strict zod schema INSIDE each handler
 * so that invalid input becomes a first-class `invalid-input` error envelope
 * (returned as ordinary MCP text) rather than an MCP protocol error — matching
 * sdd-forge-mcp's convention that envelope errors are never protocol errors.
 */

import os from "node:os";
import { z } from "zod";

import { ok, err, type Result } from "../envelope.js";
import { ALLOWLIST, type CliName } from "../allowlist.js";
import { probeEngine, type ProbeError } from "../probe-engine.js";

/** os-info payload (contract `osInfoData`). */
export interface OsInfoData {
  kind: "os-info";
  platform: string;
  arch: string;
  osType: string;
  osRelease: string;
  cpuCount: number;
  totalMemBytes: number;
  nodeRuntime: string;
}

/** One toolchain-versions entry (contract `toolchainVersionsData.entries[]`). */
export interface ToolchainEntry {
  name: CliName;
  available: boolean;
  version?: string;
  probeError?: ProbeError;
}

/** toolchain-versions payload (contract `toolchainVersionsData`). */
export interface ToolchainVersionsData {
  kind: "toolchain-versions";
  entries: ToolchainEntry[];
}

/** One cli-availability entry (contract `cliAvailabilityData.entries[]`). */
export interface CliAvailabilityEntry {
  name: CliName;
  available: boolean;
}

/** cli-availability payload (contract `cliAvailabilityData`). */
export interface CliAvailabilityData {
  kind: "cli-availability";
  entries: CliAvailabilityEntry[];
}

/**
 * Probe options threaded to the engine. `pathOverride` is a test-only
 * affordance (see probe-engine) that changes only WHERE the fixed allowlist
 * commands are resolved; it is omitted in production tool registration.
 */
export interface ToolProbeOptions {
  pathOverride?: string;
}

/** The 14 allowlist names as a readonly tuple, for the zod enum. */
const CLI_NAME_VALUES = ALLOWLIST.map((e) => e.name) as [CliName, ...CliName[]];

/**
 * Strict input schema for `get_toolchain_versions`. `names` is an optional
 * array whose members must each be one of the 14 allowlist names. `.strict()`
 * rejects any additional property, so no command/args/path field can slip in.
 */
const toolchainInput = z
  .object({
    names: z.array(z.enum(CLI_NAME_VALUES)).optional(),
  })
  .strict();

/** Input type accepted by `getToolchainVersions`. */
export type ToolchainVersionsInput = z.infer<typeof toolchainInput>;

/**
 * Raw shape registered with the MCP SDK's `registerTool` (so `tools/list`
 * advertises exactly the `names` filter and nothing else).
 */
export const TOOLCHAIN_TOOL_INPUT_SHAPE = {
  names: z
    .array(z.enum(CLI_NAME_VALUES))
    .optional()
    .describe("Optional subset of the 14 allowlist CLI names to probe. Omit to probe all."),
};

/** Returns the strict input schema (used for validation and JSON-schema introspection). */
export function getToolchainVersionsInputSchema(): typeof toolchainInput {
  return toolchainInput;
}

/**
 * get_os_info: OS and Node runtime facts from `os` / `process` APIs only.
 *
 * Deliberately EXCLUDES hostname, username, home directory, and any
 * environment-variable value (REQ-005 / AC-001): the payload carries only
 * non-identifying platform facts.
 */
export function getOsInfo(): Result<OsInfoData> {
  const data: OsInfoData = {
    kind: "os-info",
    platform: process.platform,
    arch: process.arch,
    osType: os.type(),
    osRelease: os.release(),
    cpuCount: os.cpus().length,
    totalMemBytes: os.totalmem(),
    nodeRuntime: process.version,
  };
  return ok(data);
}

/** Resolves the allowlist entries to probe for the given (already-validated) names. */
function selectEntries(names: readonly CliName[] | undefined): typeof ALLOWLIST[number][] {
  if (names === undefined || names.length === 0) {
    return [...ALLOWLIST];
  }
  const wanted = new Set<CliName>(names);
  return ALLOWLIST.filter((e) => wanted.has(e.name));
}

/**
 * get_toolchain_versions: per-entry {name, available, version?, probeError?}.
 *
 * Missing CLIs are reported `available:false` with a `probeError`; the whole
 * response stays `ok:true`. Invalid input (out-of-enum name, extra property,
 * path/command field, wrong type) short-circuits to an `invalid-input` error
 * envelope BEFORE any probe runs.
 */
export async function getToolchainVersions(
  input: ToolchainVersionsInput,
  options: ToolProbeOptions = {},
): Promise<Result<ToolchainVersionsData>> {
  const parsed = toolchainInput.safeParse(input);
  if (!parsed.success) {
    return err("invalid-input", "get_toolchain_versions: invalid input", {
      rule: "names must be an array of allowlist CLI names; no other fields are accepted",
    });
  }

  const entries = selectEntries(parsed.data.names);
  const probeOptions = options.pathOverride === undefined ? {} : { pathOverride: options.pathOverride };
  const results = await probeEngine(entries, probeOptions);

  const mapped: ToolchainEntry[] = results.map((r) => {
    const entry: ToolchainEntry = { name: r.name, available: r.available };
    if (r.version !== undefined) {
      entry.version = r.version;
    }
    if (r.probeError !== undefined) {
      entry.probeError = r.probeError;
    }
    return entry;
  });

  return ok({ kind: "toolchain-versions", entries: mapped });
}

/**
 * list_available_clis: availability-only view over the full allowlist. Shares
 * the probe-engine (and its TTL cache) with get_toolchain_versions; the version
 * string is intentionally dropped from this payload.
 */
export async function listAvailableClis(
  options: ToolProbeOptions = {},
): Promise<Result<CliAvailabilityData>> {
  const probeOptions = options.pathOverride === undefined ? {} : { pathOverride: options.pathOverride };
  const results = await probeEngine([...ALLOWLIST], probeOptions);
  const entries: CliAvailabilityEntry[] = results.map((r) => ({ name: r.name, available: r.available }));
  return ok({ kind: "cli-availability", entries });
}
