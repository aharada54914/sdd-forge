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
 * Windows `.cmd` / `.bat` shim handling: on win32, npm / pnpm / yarn ship as
 * `.cmd` shims. libuv's PATH search for a bare command name only tries
 * `.exe` / `.com`, and Node >= 20.12 refuses to launch an explicit `.cmd` /
 * `.bat` path without a shell (CVE-2024-27980 hardening — a synchronous
 * EINVAL). So on win32 the engine resolves the command itself with Windows
 * semantics (walk the effective PATH in directory order; within a directory
 * try `.com` / `.exe` / `.bat` / `.cmd` — the canonical PATHEXT order; using
 * only read-only fs APIs). A `.com` / `.exe` hit launches directly via
 * `execFile`; a `.bat` / `.cmd` hit launches as
 * `%ComSpec% /d /s /c ""<resolved>" <fixed args>"`. The command line handed to
 * cmd.exe is built ONLY from that PATH-resolved file and the compile-time
 * allowlist args — no user input can reach it (same trust boundary as the
 * PATH-spoofing residual risk already accepted by ADR-0004). A resolved path
 * containing characters that are unsafe inside a cmd.exe quoted string
 * (`"`, `%`, newlines) is refused and reported as spawn-error, never run.
 * Resolution deliberately searches PATH only (not the CWD, which Windows
 * would otherwise consult first) — a probe must never pick up a binary
 * planted in the current directory.
 *
 * Probe failures are ALWAYS reported as per-entry results (never thrown / never
 * a whole-response error), using the contract `probeError` enum.
 */

import { execFile } from "node:child_process";
import { statSync } from "node:fs";
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

/**
 * Extra window after TIMEOUT_MS before the engine-side backstop fires. On
 * Windows the killed cmd.exe can leave an orphaned grandchild holding the
 * inherited stdio pipes, which delays execFile's own timeout callback; the
 * backstop resolves the probe as `timeout` regardless.
 */
const BACKSTOP_GRACE_MS = 500;

/**
 * Executable extensions the win32 resolver tries within each PATH directory,
 * in the canonical default PATHEXT order. A fixed compile-time set is used
 * instead of reading the PATHEXT env var: deterministic, and a tampered
 * PATHEXT cannot widen what the engine will launch.
 */
const WINDOWS_EXECUTABLE_EXTENSIONS = [".com", ".exe", ".bat", ".cmd"] as const;

/** Extensions that must be launched through cmd.exe rather than directly. */
const WINDOWS_BATCH_EXTENSIONS = new Set([".bat", ".cmd"]);

/**
 * Characters that must never appear in a path interpolated into THIS
 * module's specific `""<path>" <args>"` + `/s` + windowsVerbatimArguments
 * construction: `"` breaks the quoting itself and `%` still triggers
 * environment-variable expansion inside quotes. Windows paths cannot legally
 * contain `"` or newlines, so this only ever rejects hostile input. Other
 * cmd.exe metacharacters (`& | < > ( ) ^ ! , ; =`) ARE legal in paths and are
 * deliberately allowed — they are inert ONLY while the path sits inside the
 * preserved inner quote pair (and `!` only while /v:on is not passed). Any
 * change to how the cmd.exe command line is built must re-derive this set;
 * the quoting invariant is pinned by the metacharacter-directory test in
 * tests/error-paths/windows-cmd-shim.test.ts.
 */
const UNSAFE_CMD_PATH_CHARS = /[\r\n"%]/;

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
 * Finds the key actually carrying PATH in an env object. On Windows the
 * inherited key is usually spelled `Path`; a plain object copy of process.env
 * loses Node's case-insensitive lookup, so the key must be located explicitly
 * (writing a second `PATH` key would put ambiguous duplicates in the child's
 * environment block).
 */
function findPathKey(env: NodeJS.ProcessEnv): string | undefined {
  return Object.keys(env).find((key) => key.toUpperCase() === "PATH");
}

/** Builds the child environment, applying the test-only pathOverride. */
function buildProbeEnv(options: ProbeOptions): NodeJS.ProcessEnv {
  const env = { ...process.env };
  if (options.pathOverride !== undefined) {
    const inherited = process.env.PATH ?? "";
    const merged = inherited.length > 0
      ? `${options.pathOverride}${path.delimiter}${inherited}`
      : options.pathOverride;
    env[findPathKey(env) ?? "PATH"] = merged;
  }
  return env;
}

/** Reads the effective PATH value from a built child environment. */
function effectivePath(env: NodeJS.ProcessEnv): string {
  const key = findPathKey(env);
  return key === undefined ? "" : env[key] ?? "";
}

/**
 * win32 command resolution with Windows shadowing semantics: walks the
 * effective PATH directories in order; the first directory containing the
 * command under ANY executable extension wins, trying extensions in canonical
 * PATHEXT order within each directory. Uses only read-only fs APIs (AC-006).
 * Returns undefined when nothing resolves. PATH-only by design — never the
 * current working directory.
 */
function resolveWindowsCommand(command: string, searchPath: string): string | undefined {
  for (const rawDir of searchPath.split(path.delimiter)) {
    // PATH segments may be wrapped in quotes on Windows; quotes are never part
    // of the on-disk directory name. Stripping ALL quotes (not just a wrapping
    // pair) is a simplification that only affects which directories are
    // searched, never what gets launched.
    const dir = rawDir.replace(/"/g, "");
    if (dir.length === 0) {
      continue;
    }
    for (const extension of WINDOWS_EXECUTABLE_EXTENSIONS) {
      const candidate = path.join(dir, `${command}${extension}`);
      try {
        if (statSync(candidate, { throwIfNoEntry: false })?.isFile() === true) {
          return candidate;
        }
      } catch {
        // An unreadable directory entry is treated as absent, like execFile's
        // own PATH walk would.
      }
    }
  }
  return undefined;
}

/**
 * Runs one probe with all safety limits. Never rejects — every failure mode
 * (including Node's synchronous EINVAL throw for batch-file targets) is mapped
 * to a per-entry ProbeResult.
 */
function probeOne(entry: AllowlistEntry, options: ProbeOptions): Promise<ProbeResult> {
  return new Promise<ProbeResult>((resolve) => {
    const env = buildProbeEnv(options);

    let settled = false;
    let backstop: NodeJS.Timeout | undefined;
    const finish = (result: ProbeResult): void => {
      if (settled) {
        return;
      }
      settled = true;
      if (backstop !== undefined) {
        clearTimeout(backstop);
      }
      resolve(result);
    };
    const fail = (probeError: ProbeError): void => {
      finish({ name: entry.name, available: false, probeError });
    };

    /**
     * Launches one attempt. `onLaunchFailure` is invoked (with the errno code)
     * when the target could not be started at all — ENOENT / EINVAL, whether
     * reported synchronously, via the callback, or via the child 'error'
     * event. All other failures map directly to the contract enum.
     */
    const runAttempt = (
      file: string,
      args: readonly string[],
      useVerbatimArgs: boolean,
      onLaunchFailure: (code: string | undefined) => void,
    ): void => {
      const handleResult = (error: Error | null, stdout: string, stderr: string): void => {
        if (error) {
          const code = (error as NodeJS.ErrnoException).code;
          if (code === "ENOENT" || code === "EINVAL") {
            onLaunchFailure(code);
            return;
          }
          if (code === "ERR_CHILD_PROCESS_STDIO_MAXBUFFER") {
            fail("output-too-large");
            return;
          }
          // execFile marks a timeout kill with `killed === true` (and/or a
          // signal). Distinguish timeout from a plain nonzero exit.
          const killed = (error as { killed?: boolean }).killed === true;
          const signal = (error as { signal?: string | null }).signal;
          if (killed || signal === "SIGKILL" || signal === "SIGTERM") {
            fail("timeout");
            return;
          }
          if (typeof (error as { code?: unknown }).code === "number") {
            fail("nonzero-exit");
            return;
          }
          fail("spawn-error");
          return;
        }

        const raw = entry.versionStream === "stderr" ? stderr : stdout;
        const version = normalizeVersion(String(raw));
        if (version.length === 0) {
          fail("nonzero-exit");
          return;
        }
        finish({ name: entry.name, available: true, version });
      };

      // maxBuffer enforces the 8 KiB cap: execFile kills the child and reports
      // an ERR_CHILD_PROCESS_STDIO_MAXBUFFER error once either stream exceeds
      // it. timeout enforces the 2s bound: execFile sends `killSignal` on
      // expiry.
      let child: ReturnType<typeof execFile>;
      try {
        child = execFile(
          file,
          [...args],
          {
            env,
            timeout: TIMEOUT_MS,
            killSignal: "SIGKILL",
            maxBuffer: MAX_OUTPUT_BYTES,
            windowsHide: true,
            windowsVerbatimArguments: useVerbatimArgs,
          },
          handleResult,
        );
      } catch (error) {
        // Node >= 20.12 throws EINVAL synchronously for `.cmd` / `.bat`
        // targets; a rejection here would break the never-rejects contract.
        onLaunchFailure((error as NodeJS.ErrnoException).code);
        return;
      }

      // Backstop: guarantee the probe resolves near the timeout even if the
      // execFile callback is delayed (e.g. an orphaned grandchild keeps the
      // inherited stdio pipes open after the direct child was killed).
      // runAttempt runs at most once per probe, so no prior timer can exist.
      backstop = setTimeout(() => {
        child.kill("SIGKILL");
        child.stdout?.destroy();
        child.stderr?.destroy();
        fail("timeout");
      }, TIMEOUT_MS + BACKSTOP_GRACE_MS);

      child.on("error", (error) => {
        const code = (error as NodeJS.ErrnoException).code;
        if (code === "ENOENT" || code === "EINVAL") {
          onLaunchFailure(code);
        } else {
          fail("spawn-error");
        }
      });
    };

    // Launch failure on a direct (non-cmd.exe) attempt: a vanished target is
    // not-found; anything else is a spawn-error.
    const onDirectLaunchFailure = (code: string | undefined): void => {
      fail(code === "ENOENT" ? "not-found" : "spawn-error");
    };

    if (process.platform !== "win32") {
      runAttempt(entry.command, entry.args, false, onDirectLaunchFailure);
      return;
    }

    // win32 (see module doc): resolve with Windows shadowing semantics first,
    // then pick the launch strategy by extension.
    const resolved = resolveWindowsCommand(entry.command, effectivePath(env));
    if (resolved === undefined) {
      fail("not-found");
      return;
    }
    if (!WINDOWS_BATCH_EXTENSIONS.has(path.extname(resolved).toLowerCase())) {
      runAttempt(resolved, entry.args, false, onDirectLaunchFailure);
      return;
    }

    if (UNSAFE_CMD_PATH_CHARS.test(resolved)) {
      fail("spawn-error");
      return;
    }

    // /d: skip AutoRun registry commands. /s: strip exactly the outer quote
    // pair, so the shim path may itself be quoted (paths with spaces). /c:
    // run and exit. windowsVerbatimArguments passes this command line through
    // untouched — it is built ONLY from the PATH-resolved shim path and the
    // compile-time allowlist args.
    const comSpec = process.env.ComSpec ?? "cmd.exe";
    const joinedArgs = entry.args.join(" ");
    const commandLine = joinedArgs.length > 0 ? `""${resolved}" ${joinedArgs}"` : `""${resolved}""`;
    runAttempt(comSpec, ["/d", "/s", "/c", commandLine], true, () => fail("spawn-error"));
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
