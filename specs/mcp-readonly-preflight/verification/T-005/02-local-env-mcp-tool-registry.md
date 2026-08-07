# T-005 — `mcp/local-env-mcp/src/server.ts` tool registry enumeration (AC-015, TEST-015)

## Method

```
$ grep -n "server.registerTool(" mcp/local-env-mcp/src/server.ts
45:  server.registerTool(
57:  server.registerTool(
71:  server.registerTool(
$ grep -c "server.registerTool(" mcp/local-env-mcp/src/server.ts
3
$ grep -rn "registerTool(" mcp --include="*.ts" | grep -v "\.test\.ts" | grep -v "/dist/" | grep "local-env-mcp"
(all 3 lines above; none outside src/server.ts)
```

Three `server.registerTool(` call sites, all inside this one file. This
matches `server.ts:2-6`'s own module doc comment, which names "exactly the 3
local-env-mcp tools" (`get_os_info`, `get_toolchain_versions`,
`list_available_clis`).

Supplementary fs/child_process import sweep (diligence beyond the registry
declarations themselves):

```
$ grep -rn 'from "fs"\|from "node:fs"\|require("fs")' mcp/local-env-mcp/src --include="*.ts" | grep -v "\.test\.ts"
(no output — no fs import anywhere in this server's src tree)

$ grep -rn 'from "child_process"\|from "node:child_process"' mcp/local-env-mcp/src --include="*.ts" | grep -v "\.test\.ts"
mcp/local-env-mcp/src/probe-engine.ts:20:import { execFile } from "node:child_process";

$ grep -n "execFile(\|allowlist" mcp/local-env-mcp/src/probe-engine.ts | head
23:import type { AllowlistEntry, CliName } from "./allowlist.js";
48:   * allowlist commands are resolved — it never lets user input choose the
107:      child = execFile(
```

No file-write API is imported anywhere in this server's tree at all. The one
process-spawning primitive (`execFile`) is confined to `probe-engine.ts` and
is invoked only against a fixed, compile-time `allowlist.js` entry set — the
`server.ts:5,15-18` module doc comment states no tool input schema accepts a
command/args/path field (only the `names` enum filter on
`get_toolchain_versions`), so no caller input can steer `execFile`'s target
or arguments.

## Registered tools (3 of 3)

| # | Tool name | `registerTool(` line | Backing function (file:line) | Read-only judgment |
|---|---|---|---|---|
| 1 | `get_os_info` | `server.ts:45` | `getOsInfo` (`tools/env.ts`, imported `server.ts:25`) | "Reports platform, arch, OS type/release, logical CPU count, total memory, and the Node runtime version from os/process APIs. Never returns hostname, username, home directory, or environment values" (`server.ts:49-52`). Zero-arg, reads Node's `os`/`process` module state only — no fs, no child_process. Read-only. |
| 2 | `get_toolchain_versions` | `server.ts:57` | `getToolchainVersions` (`tools/env.ts`) | "Probes the fixed 14-CLI allowlist (or the subset named in `names`) with `execFile --version`" (`server.ts:61-63`) — the only input is the `names` filter over a closed 14-entry enum (`TOOLCHAIN_TOOL_INPUT_SHAPE`); `execFile` is always called with a fixed `--version`-shaped argument list from `allowlist.js`, never caller-supplied args. A version query, not a mutating invocation. Read-only. |
| 3 | `list_available_clis` | `server.ts:71` | `listAvailableClis` (`tools/env.ts`) | "Reports availability (present/absent) for each CLI in the fixed 14-CLI allowlist, without version strings. Takes no input" (`server.ts:75-77`). Zero-arg presence check. Read-only. |

## Conclusion (AC-015)

All 3 registered tools in `mcp/local-env-mcp/src/server.ts` are
environment/toolchain **query** operations (`get_os_info`,
`get_toolchain_versions`, `list_available_clis`). None registers a
create/update/delete/write/approve/advance verb, none accepts a
command/args/path field that could redirect `execFile` to an arbitrary
target, and the server tree has no `fs` write import at all. **PASS — no
write, mutate, or advance tool is registered.**
