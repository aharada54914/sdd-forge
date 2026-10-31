# T-001 — Post-edit verification record

All commands below were run from the repository root
(`/Users/jrmag/Projects/active/sdd-forge-wt-phase4`) after the single edit to
`plugins/sdd-bootstrap/skills/bootstrap/SKILL.md`.

## Done-When bullet 1 — insertion point + three required elements (AC-001, TEST-001)

Insertion point: confirmed by direct read — the new `## MCP Preflight
(Advisory)` section starts at line 66, immediately after the blank line
following `## Preconditions`'s body (ends line 64, blank separator line 65),
and `## Routing` now starts at line 88 (shifted down by the 22 inserted
lines, same relative order preserved).

```
$ grep -n "get_next_sdd_command" plugins/sdd-bootstrap/skills/bootstrap/SKILL.md
68:Attempt `get_next_sdd_command` with no arguments; if it is unavailable or
71:`get_next_sdd_command` is read-only: it only reads repository state and

$ grep -n "read-only" plugins/sdd-bootstrap/skills/bootstrap/SKILL.md
71:`get_next_sdd_command` is read-only: it only reads repository state and

$ grep -n "advisory\|does not decide" plugins/sdd-bootstrap/skills/bootstrap/SKILL.md
73:advisory — it does not decide the mode, track, or step that follows.
```

All three elements present, independently assertable, not a heading over an
empty section, and not element (1) alone (paragraph 2 explicitly states
`## Routing` remains the sole decision procedure). **PASS.**

## Done-When bullet 2 — attempt-and-degrade, not detect-then-branch; unconditional (D-001, OQ-004)

The added text (lines 66-86):

```
Attempt `get_next_sdd_command` with no arguments; if it is unavailable or
the call fails, continue with the file-based flow below.
```

matches the permitted shape `design.md:63` names verbatim in structure
("attempt `<tool>`; if it is unavailable or the call fails, continue with
the file-based flow below"). No sentence instructs checking whether an MCP
server is registered before attempting the call (grepped for "registered"
and "check whether" — neither appears in the added text).

Unconditional application:

```
$ sed -n '66,86p' plugins/sdd-bootstrap/skills/bootstrap/SKILL.md | grep -ni "if mode\|when mode\|only in\|except\|full track\|lite track\|--lite"
(no output)
```

No mode name (`feature`/`bugfix`/`refactor`/`project`/`adopt`/`investigate`)
or track name (full/lite) gates the paragraph's presence — all six mode
names appear only inside the explicit "apply it the same way for every
mode ... and every track" sentence, listing them as covered, not as a
condition. **PASS.**

## Done-When bullet 3 — four absence assertions, bootstrap leg (TEST-004…007)

```
$ grep -ni "claude mcp" plugins/sdd-bootstrap/skills/bootstrap/SKILL.md
(no match — pre-existing "claude" occurrences in the file, e.g. "Claude
Code:" at line 16, do not co-occur with "mcp"; grep confirmed no match at
all)

$ grep -nF '.codex/config.toml' plugins/sdd-bootstrap/skills/bootstrap/SKILL.md
(no match)

$ grep -nF '>>> ' plugins/sdd-bootstrap/skills/bootstrap/SKILL.md
(no match)
$ grep -ni "marker" plugins/sdd-bootstrap/skills/bootstrap/SKILL.md
(no match)

$ grep -ni "mcp.json" plugins/sdd-bootstrap/skills/bootstrap/SKILL.md
(no match)
```

All four surfaces are absent. Valid jointly with bullet 1's presence check
above (acceptance-tests.md Notes: "A run in which TEST-001 fails must treat
TEST-004 … TEST-007 as inconclusive" — TEST-001 passed, so these are valid
passes, not inconclusive). **PASS** (bootstrap leg; T-001's Requirements
line scopes AC-004…007 to the bootstrap leg only — the ship leg is T-002's).

## Done-When bullet 4 — fallback completes normal flow, no error surfaced (TEST-008, TEST-009)

**Wording-level check (both conditions):** the single sentence "if it is
unavailable or the call fails, continue with the file-based flow below"
covers both the TEST-008 condition (no MCP server registered — the call is
never reachable) and the TEST-009 condition (registered, call attempted and
fails) with one instruction, and separately states "Do not surface the
unavailability or the failure to the user as a run failure." Both named
failure modes are explicitly addressed in the text.

**First-hand environmental evidence (TEST-008 condition):** this coding
session's own available toolset was checked and contains no
`get_next_sdd_command` MCP tool (no `sdd-forge-mcp` server is connected in
this session — confirmed by the system's own MCP server list, which names
only `computer-use`, `pencil`, `context7`, and `serena`). This is a genuine,
unfabricated instance of "no MCP server registered": had this preflight
step's wording been followed in this session, the attempt would find the
tool unavailable and proceed to the file-based flow exactly as written —
which is what happened in practice while performing this task (all
verification below used the file-based `scripts/check-sdd-structure.sh` /
direct-read approach, with no MCP call attempted or available).

**Disclosed limitation (TEST-009):** a live exercise of the
"registered-but-the-call-fails" condition — actually registering
`sdd-forge-mcp` and forcing a call failure inside a real
`/sdd-bootstrap:bootstrap` run — was not performed. That is a genuine
runtime exercise outside a single-file documentation task's scope (it would
require standing up a registered server, forcing a failure injection, and
running the full skill end-to-end, none of which is a "read this file /
edit this file" action). Recorded here as an open item for the quality gate
rather than fabricated as observed. The wording-level check above is real
and passes; the live-exercise half of TEST-009 is not claimed.

## Done-When bullet 5 — differential outcome equality (TEST-012)

```
$ git diff --stat -- plugins/sdd-bootstrap/skills/bootstrap/SKILL.md
 plugins/sdd-bootstrap/skills/bootstrap/SKILL.md | 22 ++++++++++++++++++++++
 1 file changed, 22 insertions(+)

$ git diff -- plugins/sdd-bootstrap/skills/bootstrap/SKILL.md
(see 02-verification-record.md's companion `git diff` output captured
during implementation; the diff is a pure insertion between the existing
`## Preconditions` body and the existing `## Routing` heading — zero lines
inside or after `## Routing` are touched)
```

The diff is additive-only: every line of `## Routing` and everything below
it (`### adopt mode` through `## Handoff`) is byte-for-byte unchanged.
`## Routing`'s decision logic therefore cannot read the probe's result —
there is no new conditional inside `## Routing` referencing it, because
`## Routing`'s content did not change at all. This makes outcome equality a
structural fact, verifiable by diff, not a claim resting on the prose: any
repository state that reaches `## Routing` reaches the identical
mode/track routing conclusion whether or not the probe ran, because
`## Routing`'s inputs (mode argument, `--lite` flag, `AGENTS.md
spec_profile`) are unchanged and its logic contains no probe-derived
branch. **PASS** (structural verification). A live two-run empirical
differential (actually invoking `/sdd-bootstrap:bootstrap` twice, once with
and once without a registered MCP server, and diffing the observed routing
decision) was not additionally performed — disclosed as an open item
alongside bullet 4's TEST-009 disclosure, for the same reason.

## Done-When bullet 6 — divergence reporting and file-based authority (TEST-027a, TEST-027b)

```
$ sed -n '83,86p' plugins/sdd-bootstrap/skills/bootstrap/SKILL.md
If the probe's suggestion and the conclusion `## Routing` reaches disagree,
state in the output both that a disagreement occurred and which source was
acted on. Always act on the `## Routing` conclusion in that case, never the
probe's.
```

Two separate, independently assertable elements are present in one
sentence: (a) "state in the output ... that a disagreement occurred", and
(b) "... and which source was acted on" — satisfying TEST-027a's "both
elements, not one" requirement. The following sentence, "Always act on the
`## Routing` conclusion in that case, never the probe's," names the
file-based flow (`## Routing`) as the conclusion always acted on —
satisfying TEST-027b, and explicitly ruling out the "warn, then follow the
probe" failure mode TEST-027b is designed to catch (the wording never
directs following the probe in the divergence case). **PASS** (wording-level
verification). A live divergence-scenario exercise (constructing a real
repository state where the probe's answer and the file-based conclusion
actually differ, running bootstrap, and observing the reported output) was
not additionally performed — disclosed as an open item alongside bullets
4 and 5.

## Done-When bullet 7 — AC-017…020 dual-runtime grid (OQ-009, no determined method)

See `03-dual-runtime-manual-verification.md` in this directory. No
text-based substitute is offered for the undetermined cells.

## Done-When bullet 8 — closing guarantees (AC-027/TEST-027, BL-001)

```
$ bash tests/workflow-documentation.tests.sh
ok: full SDD documentation names the three independent review stages in order
$ echo "exit=$?"
exit=0
```

`tests/workflow-documentation.tests.sh` was run **unmodified** (no edit was
made to it at any point in this task) and passed. **PASS** (AC-027,
TEST-027).

```
$ git status --porcelain -- mcp/
(no output)
$ git diff --stat -- mcp/
(no output)
```

No file under `mcp/` was touched. **PASS** (BL-001).

## Overall change-set scope check

```
$ git status --porcelain
 M plugins/sdd-bootstrap/skills/bootstrap/SKILL.md
?? specs/mcp-readonly-preflight/verification/
```

Only the one permitted writable target
(`plugins/sdd-bootstrap/skills/bootstrap/SKILL.md`) and this new
verification directory were touched. No protected file, no other skill
file, no `tasks.md`/`traceability.md`/`requirements.md`/`design.md`/
`acceptance-tests.md`/`investigation.md` was opened for write.
