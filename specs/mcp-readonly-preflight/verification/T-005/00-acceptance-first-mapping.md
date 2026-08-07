# T-005 — Done-When ↔ AC/TEST mapping (authored before enumeration)

`tasks.md` T-005 sets `Required Workflow: test-after`, not
`acceptance-first` (T-001/T-002/T-003/T-004 in this feature are
acceptance-first; T-005 is the one exception — it is a zero-product-file-change
verification task, `Risk: low`, whose job is "regression protection, not
construction" per its own Risk Rationale). This mapping table is still
authored **first**, before reading the three `server.ts` files line-by-line,
per the orchestrator's instruction and mirroring the acceptance-first
convention already used by `00-acceptance-first-mapping.md` in `T-001`,
`T-002`, and `T-003` of this same feature — the table below is the plan, the
numbered files after it are the evidence gathered against that plan.

## Source citations re-verified fresh at implementation start (WFI-011)

`tasks.md` T-005's Done-When cites three files by path only (no line
numbers to re-verify), plus one line-range citation inside
`acceptance-tests.md` itself:

```
$ ls mcp
ci-mcp  local-env-mcp  sdd-forge-mcp
$ find mcp -maxdepth 3 -name server.ts
mcp/sdd-forge-mcp/src/server.ts
mcp/local-env-mcp/src/server.ts
mcp/ci-mcp/src/server.ts
```

All three paths named in `tasks.md` T-005's Done-When
(`mcp/sdd-forge-mcp/src/server.ts`, `mcp/local-env-mcp/src/server.ts`,
`mcp/ci-mcp/src/server.ts`) exist exactly as cited. No re-derivation needed.

`acceptance-tests.md:62` cites `mcp/sdd-forge-mcp/src/server.ts:65-219` as
the registered-tool-set range; this range is re-checked against the actual
`registerTool(` line numbers enumerated in `01-sdd-forge-mcp-tool-registry.md`
below (first call at `:64`, last tool-name string inside the final call at
`:219` — the range describes the tool-name strings, not the `registerTool(`
open-parens, and matches once read that way).

## Done-When bullet ↔ AC/TEST mapping and verification method

| # | Done-When bullet (paraphrased) | AC / TEST | Verification method used | Evidence file |
|---|---|---|---|---|
| 1 | Enumerate every `server.registerTool(` in `mcp/sdd-forge-mcp/src/server.ts`; confirm none writes/mutates/advances state | AC-014, TEST-014 | Unit (static, tool registry): `grep -n "server.registerTool("` for an exhaustive call-site count, then a full `Read` of the file to record each tool's exact name, `title`, `description`, and handler body's effect (read/query only vs. any write primitive) | `01-sdd-forge-mcp-tool-registry.md` |
| 2 | Equivalent enumeration for `mcp/local-env-mcp/src/server.ts` | AC-015, TEST-015 | Same method as row 1, applied to the 3-tool file | `02-local-env-mcp-tool-registry.md` |
| 3 | Equivalent enumeration for `mcp/ci-mcp/src/server.ts`, **plus** every outbound HTTP call site in `mcp/ci-mcp/src/` confirmed GET-only | AC-016, TEST-016 | Same registry method as rows 1–2, plus a repo-wide grep across `mcp/ci-mcp/src/**/*.ts` for `method:`, HTTP verb literals (`POST`/`PUT`/`PATCH`/`DELETE`), and any `fetch`/`axios`/`http`/`https`/`request(` call site not routed through the two `GET`-only client functions in `github-client.ts` | `03-ci-mcp-tool-registry-and-http-check.md` |
| 4 | Enumeration output (tool names + registration file + GET-only confirmation) saved as a recorded, reproducible verification artifact under `specs/mcp-readonly-preflight/verification/T-005/`, cited in the implementation report; no new permanent test-suite file | — (artifact-format requirement) | This directory itself; no file under `tests/` is added or edited (confirmed in `04-verification-record.md`'s final diff check) | all files in this directory |
| 5 | No file under `mcp/` is edited (BL-001) | BL-001 | `git status --porcelain -- mcp/` and `git diff --stat -- mcp/` both run empty, before and after this task's writes | `04-verification-record.md` |

## Planned artifact layout

- `00-acceptance-first-mapping.md` — this file.
- `01-sdd-forge-mcp-tool-registry.md` — AC-014 enumeration.
- `02-local-env-mcp-tool-registry.md` — AC-015 enumeration.
- `03-ci-mcp-tool-registry-and-http-check.md` — AC-016 enumeration + TEST-016's HTTP-method check.
- `04-verification-record.md` — closing Done-When checklist, BL-001 diff confirmation, overall change-set scope check.

No new file under `tests/` is planned or created, per `tasks.md` T-005's own
Done-When note that this feature's `tasks.md` names no new suite for this
task and the established convention (also used by T-001–T-004's `Done-When`
prose) of ad hoc, recorded command invocations for a task with no committed
suite of its own.
