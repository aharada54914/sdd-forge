# T-005 — `mcp/ci-mcp/src/server.ts` tool registry + HTTP method enumeration (AC-016, TEST-016)

## Part A — tool registry method

```
$ grep -n "server.registerTool(" mcp/ci-mcp/src/server.ts
52:  server.registerTool(
65:  server.registerTool(
79:  server.registerTool(
93:  server.registerTool(
108:  server.registerTool(
$ grep -c "server.registerTool(" mcp/ci-mcp/src/server.ts
5
$ grep -rn "registerTool(" mcp --include="*.ts" | grep -v "\.test\.ts" | grep -v "/dist/" | grep "ci-mcp"
(all 5 lines above; none outside src/server.ts)
```

Five `server.registerTool(` call sites, all inside this one file. This
matches `server.ts:4-6`'s own module doc comment, which names "all 5
read-only GitHub Actions tools: `list_workflow_runs`, `get_workflow_run`,
`list_run_jobs`, `list_run_artifacts`, and `get_job_log`".

## Registered tools (5 of 5)

| # | Tool name | `registerTool(` line | Backing function (file:line) | Read-only judgment |
|---|---|---|---|---|
| 1 | `list_workflow_runs` | `server.ts:52` | `listWorkflowRuns` (`tools/actions.ts`, imported `server.ts:30`) | "Read-only: issues a single GET against the GitHub Actions REST API" (`server.ts:59`). Confirmed at the call site — see Part B. |
| 2 | `get_workflow_run` | `server.ts:65` | `getWorkflowRun` (`tools/actions.ts`) | "Read-only: issues a single GET…" (`server.ts:71-72`). Confirmed at the call site — see Part B. |
| 3 | `list_run_jobs` | `server.ts:79` | `listRunJobs` (`tools/actions.ts`) | "Read-only: issues a single GET…" (`server.ts:86-87`). Confirmed at the call site — see Part B. |
| 4 | `list_run_artifacts` | `server.ts:93` | `listRunArtifacts` (`tools/actions.ts`) | "Never returns binary artifact content … Read-only: issues a single GET…" (`server.ts:98-101`). Confirmed at the call site — see Part B. |
| 5 | `get_job_log` | `server.ts:108` | `getJobLog` (`tools/actions.ts`) | "Always returns `ok:true` regardless of truncation. Read-only: issues a single GET…" (`server.ts:116-118`). Confirmed at the call site — see Part B. |

Each of the 5 handlers in `tools/actions.ts` calls exactly one of two
GET-only client functions from `github-client.ts`:

```
$ grep -n "githubGet\|githubGetText\|fetch(" mcp/ci-mcp/src/tools/actions.ts
56:import { githubGet, githubGetText, type GithubFetch, type GithubTextFetch } from "../github-client.js";
256:    const outcome = await githubGet<UpstreamWorkflowRunsResponse>(   # list_workflow_runs
308:    const outcome = await githubGet<UpstreamWorkflowRun>(            # get_workflow_run
419:    const outcome = await githubGet<UpstreamRunJobsResponse>(        # list_run_jobs
519:    const outcome = await githubGet<UpstreamRunArtifactsResponse>(   # list_run_artifacts
627:    const outcome = await githubGetText(                             # get_job_log
```

No raw `fetch(` call site exists in `tools/actions.ts` itself — every
outbound call is routed through `github-client.ts`.

## Part B — HTTP method check across every outbound call site in `mcp/ci-mcp/src/` (TEST-016's second element)

```
$ grep -rn "method:" mcp/ci-mcp/src --include="*.ts"
mcp/ci-mcp/src/github-client.ts:61:/** Fetch-shaped function github-client calls. Only ever invoked with `method: "GET"`. */
mcp/ci-mcp/src/github-client.ts:64:  init: { readonly method: "GET"; readonly headers: Readonly<Record<string, string>> },
mcp/ci-mcp/src/github-client.ts:121:    response = await fetchImpl(url, { method: "GET", headers });
mcp/ci-mcp/src/github-client.ts:279:/** Fetch-shaped function `githubGetText` calls. Only ever invoked with `method: "GET"`. */
mcp/ci-mcp/src/github-client.ts:282:  init: { readonly method: "GET"; readonly headers: Readonly<Record<string, string>> },
mcp/ci-mcp/src/github-client.ts:330:    response = await fetchImpl(url, { method: "GET", headers });

$ grep -rniE "\"POST\"|'POST'|\"PUT\"|'PUT'|\"PATCH\"|'PATCH'|\"DELETE\"|'DELETE'" mcp/ci-mcp/src --include="*.ts"
(no output — no non-GET HTTP verb literal appears anywhere in this server's src tree)

$ cat mcp/ci-mcp/package.json | grep -A5 '"dependencies"'
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.29.0",
    "zod": "^4.4.3"
  },
```

Only two outbound-HTTP-issuing call sites exist in the entire
`mcp/ci-mcp/src/` tree:

| Call site | Function | `method` value | Caller (all 5 tools route through one of these two) |
|---|---|---|---|
| `github-client.ts:121` | `githubGet<T>` | literal `"GET"` (type-level literal at `:64`, runtime value at `:121`) | `list_workflow_runs`, `get_workflow_run`, `list_run_jobs`, `list_run_artifacts` |
| `github-client.ts:330` | `githubGetText` | literal `"GET"` (type-level literal at `:282`, runtime value at `:330`) | `get_job_log` |

The `GithubFetch`/`GithubTextFetch` function types (`:62-65`, `:280-283`)
constrain `init.method` to the TypeScript literal type `"GET"` — the type
system itself makes a `"POST"`/`"PUT"`/`"PATCH"`/`"DELETE"` value a compile
error at every call site, not just an unused-in-practice value. `package.json`
declares no HTTP client dependency beyond the MCP SDK and `zod` — the global
`fetch` (`github-client.ts:100,300`) is the only HTTP primitive in use, and
both of its call sites are the two rows above.

This matches `docs/adr/0006-ci-mcp-readonly-github-actions.md:35-36`'s
control: "GitHub API は **GET でのみ**呼び、POST / PATCH / PUT / DELETE を
発行しない。re-run / cancel / dispatch / delete / approve 等の write ツール
を公開しない。"

## Conclusion (AC-016)

All 5 registered tools in `mcp/ci-mcp/src/server.ts` are GitHub Actions
**read** operations (`list_*`, `get_*`), each routed through exactly one of
`github-client.ts`'s two client functions, and **every** outbound HTTP call
site in `mcp/ci-mcp/src/` — both of them — issues only the literal `GET`
method, enforced at the type level in addition to the two runtime call
sites. No non-GET method is issued anywhere in the client. **PASS — no
write, mutate, or advance tool is registered, and no non-GET HTTP method is
issued.**
