# T-002 — AC-017…020 dual-runtime grid: recorded manual verification (OQ-009 open method, ship leg)

`tasks.md` T-002 Done-When: "AC-017 / AC-018 / AC-019 / AC-020 (TEST-017 /
TEST-018 / TEST-019 / TEST-020) — ship leg — recorded the same way as
T-001's: no determined method (OQ-009), no fabricated text assertion, an
explicitly recorded manual verification per runtime saved under
`specs/mcp-readonly-preflight/verification/T-002/`."

TEST-017…TEST-020 are the same four AC/TEST identifiers T-001 recorded for
the bootstrap leg (`verification/T-001/03-dual-runtime-manual-verification.md`);
this file records the **ship** leg of the same grid, observed within this
task's own session.

| Test | Cell | Runtime | Path | Observed in this task (ship leg)? |
|---|---|---|---|---|
| TEST-017 | probe available | Claude Code | probe | **No.** Not exercised — this session has no registered `sdd-forge-mcp` server, so the probe-available cell could not be observed here. |
| TEST-018 | probe unavailable | Claude Code | fallback | **Yes.** See below. |
| TEST-019 | probe available | Codex | probe | **No.** No Codex runtime is available in this session. |
| TEST-020 | probe unavailable | Codex | fallback | **No.** No Codex runtime is available in this session. |

## TEST-018 — the one cell actually observed (ship leg)

**Runtime:** Claude Code (this implementation session itself, running as
the CLI documented at `plugins/sdd-ship/skills/ship/SKILL.md:14` under the
"Claude Code:" invocation form).

**Observation method:** the session's own connected MCP server list was
checked (surfaced directly by the runtime, not inferred) and named exactly
four servers — `computer-use`, `pencil`, `context7`, `serena` — none of
which is `sdd-forge-mcp`, and no tool named `get_next_sdd_command` is
present anywhere in this session's available toolset.

**Path observed:** fallback. Under the newly staged `## MCP Preflight
(Advisory)` step's wording, attempting `get_next_sdd_command` in this exact
session would find the tool unavailable and proceed to the file-based flow
(`## Step 1 — Target Selection`) — which is the fallback path, and is in
fact what every verification step in `02-verification-record.md` did: all
checks in this task used direct file reads, `git`/`shasum` shell commands,
and the `Read`/`Write` tools, never an MCP call, because none was available.

**Not claimed:** this is one genuine, first-hand observation of one cell
(Claude Code / fallback), for the ship leg. It is not extrapolated to the
other three cells. A session with `sdd-forge-mcp` actually registered (for
TEST-017) and a Codex runtime (for TEST-019 / TEST-020) were not available
within this task's scope, so those three cells remain open, exactly as
OQ-009 anticipates, and are disclosed here rather than assumed to pass
because the wording is runtime-agnostic.

## Why this is not a text-based substitute

REQ-003 requires the staged wording be identical regardless of runtime,
which is exactly why a text read cannot distinguish the four cells
(`design.md:68`, `acceptance-tests.md` TEST-017-020 detail section). The one
row recorded above (TEST-018) is not a read of the wording — it is a direct,
first-hand fact about this session's actual connected tool set, which
happens to instantiate the fallback condition genuinely. The other three
rows are left unmarked rather than inferred from the wording being
"correct", per the instruction not to fabricate a pass.

## Relationship to T-001's bootstrap-leg record

T-001's `03-dual-runtime-manual-verification.md` recorded the identical
observation (Claude Code / fallback) for the bootstrap leg, in the same
session context (no `sdd-forge-mcp` server registered). The two records are
independent per-skill observations of the same underlying session fact, not
a single observation double-counted across both tasks — each task's Done-When
requires its own leg's evidence, and each is recorded separately under its
own task's verification directory.
