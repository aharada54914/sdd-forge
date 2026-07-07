/**
 * Version-probe engine (ADR-0004 / REQ-003, AC-004).
 *
 * The single choke point where local-env-mcp launches OS processes. It runs
 * ONLY the compile-time allowlist entries handed to it — no user input reaches
 * `command` or `args`. Each probe is subject to hard safety limits so a hung or
 * hostile CLI on PATH cannot exhaust resources:
 *
 *   - launched with `execFile` (NO shell — shell metacharacters are inert),
 *   - per-probe timeout of 2000 ms (process is killed on expiry),
 *   - collected output capped at 8 KiB (process is killed once exceeded),
 *   - global concurrency limit of 4 concurrent child processes,
 *   - version normalized to the first output line, trimmed, max 200 chars,
 *   - per-entry in-memory TTL cache (60 s) to avoid re-spawning on bursts.
 *
 * Probe failures are ALWAYS reported as per-entry results (never thrown / never
 * a whole-response error), using the contract `probeError` enum.
 */

import { execFile } from "node:child_process";
import path from "node:path";

import type { AllowlistEntry, CliName } from "./allowlist.js";

/** Contract-aligned failure reason for a single probe. */
export type ProbeError =
  | "not-found"
  | "timeout"
  | "output-too-large"
  | "nonzero-exit"
  | "spawn-error";

/** Result of probing one allowlist entry. */
export interface ProbeResult {
  name: CliName;
  available: boolean;
  version?: string;
  probeError?: ProbeError;
}

/** Options for the probe engine. `pathOverride` is a test-only affordance. */
export interface ProbeOptions {
  /**
   * When set, this directory is PREPENDED to the inherited PATH when resolving
   * `command` (tests point the engine at fake CLI fixtures placed here, which
   * therefore shadow any real binary of the same name while the shims can still
   * invoke system utilities like `sleep`). It only changes WHERE the fixed
   * allowlist commands are resolved — it never lets user input choose the
   * command or args. Omitted in production, where the inherited PATH is used.
   */
  pathOverride?: string;
}

const TIMEOUT_MS = 2000;
const MAX_OUTPUT_BYTES = 8 * 1024;
const CONCURRENCY_LIMIT = 4;
const CACHE_TTL_MS = 60_000;
const MAX_VERSION_CHARS = 200;

/** A cached per-entry result with its insertion timestamp. */
interface CacheEntry {
  at: number;
  result: ProbeResult;
}

/**
 * Module-level per-entry TTL cache. Keyed by CLI name (the stable identity of
 * an allowlist entry). No invalidation API — entries simply expire after the
 * TTL, matching the design's "per-entry, no invalidation" note.
 */
const cache = new Map<CliName, CacheEntry>();

/** Normalizes raw probe output to the first line, trimmed, <= 200 chars. */
function normalizeVersion(raw: string): string {
  const firstLine = raw.split(/\r?\n/, 1)[0] ?? "";
  return firstLine.trim().slice(0, MAX_VERSION_CHARS);
}

/**
 * Runs one probe with all safety limits. Never rejects — every failure mode is
 * mapped to a per-entry ProbeResult.
 */
function probeOne(entry: AllowlistEntry, options: ProbeOptions): Promise<ProbeResult> {
  return new Promise<ProbeResult>((resolve) => {
    const env = { ...process.env };
    if (options.pathOverride !== undefined) {
      const inherited = process.env.PATH ?? "";
      env.PATH = inherited.length > 0
        ? `${options.pathOverride}${path.delimiter}${inherited}`
        : options.pathOverride;
    }

    let settled = false;
    const finish = (result: ProbeResult): void => {
      if (settled) {
        return;
      }
      settled = true;
      resolve(result);
    };

    // maxBuffer enforces the 8 KiB cap: execFile kills the child and reports an
    // ERR_CHILD_PROCESS_STDIO_MAXBUFFER error once either stream exceeds it.
    // timeout enforces the 2s bound: execFile sends `killSignal` on expiry.
    let child: ReturnType<typeof execFile>;
    try {
      child = execFile(
      entry.command,
      [...entry.args],
      {
        env,
        timeout: TIMEOUT_MS,
        killSignal: "SIGKILL",
        maxBuffer: MAX_OUTPUT_BYTES,
        windowsHide: true,
      },
      (error, stdout, stderr) => {
        if (error) {
          const code = (error as NodeJS.ErrnoException).code;
          if (code === "ENOENT") {
            finish({ name: entry.name, available: false, probeError: "not-found" });
            return;
          }
          if (code === "ERR_CHILD_PROCESS_STDIO_MAXBUFFER") {
            finish({ name: entry.name, available: false, probeError: "output-too-large" });
            return;
          }
          // execFile marks a timeout kill with `killed === true` (and/or a
          // signal). Distinguish timeout from a plain nonzero exit.
          const killed = (error as { killed?: boolean }).killed === true;
          const signal = (error as { signal?: string | null }).signal;
          if (killed || signal === "SIGKILL" || signal === "SIGTERM") {
            finish({ name: entry.name, available: false, probeError: "timeout" });
            return;
          }
          if (typeof (error as { code?: unknown }).code === "number") {
            finish({ name: entry.name, available: false, probeError: "nonzero-exit" });
            return;
          }
          finish({ name: entry.name, available: false, probeError: "spawn-error" });
          return;
        }

        const raw = entry.versionStream === "stderr" ? stderr : stdout;
        const version = normalizeVersion(String(raw));
        if (version.length === 0) {
          finish({ name: entry.name, available: false, probeError: "nonzero-exit" });
          return;
        }
        finish({ name: entry.name, available: true, version });
      },
      );
    } catch {
      // On win32, spawn throws SYNCHRONOUSLY (EINVAL) when PATH resolution
      // lands on a .bat/.cmd file and no shell is enabled (Node/libuv
      // CVE-2024-27980 hardening; e.g. npm resolves to npm.cmd on Windows).
      // Honor the per-entry contract: a probe failure is never thrown.
      finish({ name: entry.name, available: false, probeError: "spawn-error" });
      return;
    }

    // Guarantee the child cannot outlive the timeout even if the callback path
    // is delayed: force-kill shortly after the timeout window as a backstop.
    child.on("error", (error) => {
      const code = (error as NodeJS.ErrnoException).code;
      if (code === "ENOENT") {
        finish({ name: entry.name, available: false, probeError: "not-found" });
      } else {
        finish({ name: entry.name, available: false, probeError: "spawn-error" });
      }
    });
  });
}

/**
 * Probes the given allowlist entries, honoring the TTL cache and the global
 * concurrency limit. Returns one ProbeResult per input entry, in input order.
 */
export async function probeEngine(
  entries: readonly AllowlistEntry[],
  options: ProbeOptions = {},
): Promise<ProbeResult[]> {
  const now = Date.now();
  const results = new Array<ProbeResult>(entries.length);
  const pending: number[] = [];

  // Serve cache hits immediately; queue the rest.
  for (let i = 0; i < entries.length; i += 1) {
    const entry = entries[i]!;
    const cached = cache.get(entry.name);
    if (cached !== undefined && now - cached.at < CACHE_TTL_MS) {
      results[i] = cached.result;
    } else {
      pending.push(i);
    }
  }

  // Bounded worker pool over the pending indices.
  let cursor = 0;
  async function worker(): Promise<void> {
    while (cursor < pending.length) {
      const idx = pending[cursor]!;
      cursor += 1;
      const entry = entries[idx]!;
      const result = await probeOne(entry, options);
      results[idx] = result;
      cache.set(entry.name, { at: Date.now(), result });
    }
  }

  const workerCount = Math.min(CONCURRENCY_LIMIT, pending.length);
  await Promise.all(Array.from({ length: workerCount }, () => worker()));

  return results;
}

/** Clears the TTL cache. Intended for tests only; unused in production paths. */
export function __clearProbeCache(): void {
  cache.clear();
}
