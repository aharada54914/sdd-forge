# T-002 — Post-staging verification record

All commands below were run from the repository root
(`/Users/jrmag/Projects/active/sdd-forge-wt-phase4`) after staging the
candidate at `specs/mcp-readonly-preflight/human-copy/plugins/sdd-ship/
skills/ship/SKILL.md`. The live `plugins/sdd-ship/skills/ship/SKILL.md` was
never opened for write at any point (see the "Overall change-set scope
check" section, below).

## Done-When bullet 1 — candidate exists, 3 required elements, not produced by a live write (AC-002, TEST-002)

Insertion point: confirmed by direct read — the new `## MCP Preflight
(Advisory)` section starts at candidate line 55, immediately after the blank
line following `## Preconditions`'s body (live body ends line 53, live blank
separator line 54), and `## Step 1 — Target Selection` now starts at
candidate line 77 (shifted down by the 22 inserted lines, same relative
order preserved — everything below is otherwise untouched, confirmed by the
diff in bullet 4 below).

```
$ grep -n '^## Preconditions$\|^## MCP Preflight\|^## Step 1' specs/mcp-readonly-preflight/human-copy/plugins/sdd-ship/skills/ship/SKILL.md
45:## Preconditions
55:## MCP Preflight (Advisory)
77:## Step 1 — Target Selection

$ grep -n "get_next_sdd_command" specs/mcp-readonly-preflight/human-copy/plugins/sdd-ship/skills/ship/SKILL.md
57:Attempt `get_next_sdd_command` with no arguments; if it is unavailable or
60:`get_next_sdd_command` is read-only: it only reads repository state and

$ grep -n "read-only" specs/mcp-readonly-preflight/human-copy/plugins/sdd-ship/skills/ship/SKILL.md
60:`get_next_sdd_command` is read-only: it only reads repository state and

$ grep -n "advisory\|does not decide" specs/mcp-readonly-preflight/human-copy/plugins/sdd-ship/skills/ship/SKILL.md
62:advisory — it does not decide the target, the track, or any step that
```

All three elements present, independently assertable, not a heading over an
empty section, and not element (1) alone (the second paragraph explicitly
states `## Step 1 — Target Selection` remains the sole decision procedure).
**PASS** (AC-002 first half, TEST-002).

The candidate was staged via a direct `Write` tool call to the human-copy
path; the live protected path
(`plugins/sdd-ship/skills/ship/SKILL.md`) was never targeted by a `Write` or
`Edit` tool call at any point in this task (confirmed independently in the
"Overall change-set scope check" section below). **PASS** (AC-002 second
half).

## Done-When bullet 2 — attempt-and-degrade / unconditional / 4 absences / divergence (D-001, OQ-004, AC-004…007 ship leg, AC-027a/AC-027b ship leg)

The inserted text (candidate lines 55-76):

```
## MCP Preflight (Advisory)

Attempt `get_next_sdd_command` with no arguments; if it is unavailable or
the call fails, continue with the file-based flow below.

`get_next_sdd_command` is read-only: it only reads repository state and
returns a suggestion, never writing or mutating anything. Its answer is
advisory — it does not decide the target, the track, or any step that
follows. `## Step 1 — Target Selection` below remains the sole decision
procedure, and nothing this step reads changes what `## Step 1` concludes.

This step is unconditional: apply it the same way regardless of invocation
form (a `specs/<feature>/tasks.md` path argument, an optional `#T-NNN` task
selector, or the zero-argument auto-select form) and regardless of track
(full / lite) — do not skip or gate it by invocation form or track. Do not
surface the unavailability or the failure to the user as a run failure.

If the probe's suggestion and the conclusion `## Step 1 — Target Selection`
reaches disagree, state in the output both that a disagreement occurred and
which source was acted on. Always act on the `## Step 1` conclusion in that
case, never the probe's.
```

**Attempt-and-degrade, not detect-then-branch:**

```
$ grep -ni "registered\|check whether" specs/mcp-readonly-preflight/human-copy/plugins/sdd-ship/skills/ship/SKILL.md
(no match)
```

No sentence instructs checking whether an MCP server is registered before
attempting the call. **PASS.**

**Unconditional across track and invocation form:**

The paragraph names both invocation forms (`specs/<feature>/tasks.md` path
argument / optional `#T-NNN` selector / zero-argument auto-select — matching
`## Step 1`'s own three named forms) and both tracks (full / lite) as
covered, not as a condition gating the paragraph's presence — no `if`,
`only in`, or `except` wraps the step. **PASS** (OQ-004 resolution).

**Four absence assertions (TEST-004…007, ship leg):**

```
$ grep -ni "claude mcp" specs/mcp-readonly-preflight/human-copy/plugins/sdd-ship/skills/ship/SKILL.md
(no match)

$ grep -nF '.codex/config.toml' specs/mcp-readonly-preflight/human-copy/plugins/sdd-ship/skills/ship/SKILL.md
(no match)

$ grep -nF '>>> ' specs/mcp-readonly-preflight/human-copy/plugins/sdd-ship/skills/ship/SKILL.md
(no match)
$ grep -ni "marker" specs/mcp-readonly-preflight/human-copy/plugins/sdd-ship/skills/ship/SKILL.md
(no match)

$ grep -ni "mcp.json" specs/mcp-readonly-preflight/human-copy/plugins/sdd-ship/skills/ship/SKILL.md
(no match)
```

All four surfaces are absent. Valid jointly with bullet 1's presence check
above (acceptance-tests.md Notes: "A run in which TEST-001 fails must treat
TEST-004…TEST-007 as inconclusive" — the equivalent TEST-002 passed here, so
these are valid passes). **PASS** (ship leg; T-002's Requirements line scopes
AC-004…007 to the ship leg — the bootstrap leg is T-001's, already landed).

**Divergence reporting and file-based authority (TEST-027a, TEST-027b, ship leg):**

The final paragraph carries two separately assertable elements: (a) "state
in the output ... that a disagreement occurred", and (b) "... and which
source was acted on" — satisfying TEST-027a's "both elements, not one". The
following sentence, "Always act on the `## Step 1` conclusion in that case,
never the probe's," names the file-based flow (`## Step 1 — Target
Selection`) as the conclusion always acted on — satisfying TEST-027b, and
explicitly ruling out the "warn, then follow the probe" failure mode
TEST-027b is designed to catch. **PASS** (wording-level verification, ship
leg). A live divergence-scenario exercise was not additionally performed —
disclosed below alongside bullet 3.

## Done-When bullet 3 — fallback completes normal flow, no error surfaced (TEST-010, TEST-011)

**Wording-level check (both conditions):** the sentence "if it is
unavailable or the call fails, continue with the file-based flow below"
covers both the TEST-010 condition (no MCP server registered) and the
TEST-011 condition (registered, call attempted and fails) with one
instruction, and separately states "Do not surface the unavailability or the
failure to the user as a run failure." Both named failure modes are
explicitly addressed in the text.

**First-hand environmental evidence (TEST-010 condition):** this session's
own connected MCP server list was checked directly by the runtime and names
exactly four servers — `computer-use`, `pencil`, `context7`, `serena` — none
of which is `sdd-forge-mcp`, and no tool named `get_next_sdd_command` is
present anywhere in this session's available toolset. This is a genuine,
unfabricated instance of "no MCP server registered": every verification step
in this record used direct file reads and shell commands, never an MCP call,
because none was available — which is exactly the fallback path the added
wording describes.

**Disclosed limitation (TEST-011):** a live exercise of the
"registered-but-the-call-fails" condition — actually registering
`sdd-forge-mcp` and forcing a call failure inside a real `/sdd-ship:ship`
run — was not performed. That is a genuine runtime exercise outside a
protected-file staging task's scope. Recorded here as an open item for the
quality gate rather than fabricated as observed. The wording-level check
above is real and passes; the live-exercise half of TEST-011 is not claimed.

## Done-When bullet 4 — differential outcome equality (TEST-013)

```
$ diff plugins/sdd-ship/skills/ship/SKILL.md specs/mcp-readonly-preflight/human-copy/plugins/sdd-ship/skills/ship/SKILL.md
53a54,75
> (22 inserted lines: blank line, "## MCP Preflight (Advisory)" section, blank line)
```

The diff is additive-only: line 53 of the live file ("Sudo management is
always a separate human action.") is followed, in the candidate, by 22
inserted lines and then resumes at the live file's line 54 onward
unchanged. Every line of `## Step 1 — Target Selection` and everything below
it (through `## Handoff`) is byte-for-byte identical between the live file
and the candidate. `## Step 1`'s decision logic therefore cannot read the
probe's result — there is no new conditional inside `## Step 1` (or any
later step) referencing it, because that content did not change at all.
This makes outcome equality a structural fact, verifiable by diff, not a
claim resting on the prose: any repository state that reaches `## Step 1`
reaches the identical target-selection conclusion (the same
`specs/<feature>/tasks.md`) whether or not the probe ran, because `## Step
1`'s inputs (the path argument, `AGENTS.md`'s `## Active Spec Directories`,
each feature's `tasks.md` Approval/Status fields) are unchanged and its
logic contains no probe-derived branch. **PASS** (structural verification).
A live two-run empirical differential was not additionally performed —
disclosed alongside bullet 3's TEST-011 disclosure, for the same reason.

## Done-When bullet 5 — MANIFEST.sha256 conformance (AC-025, TEST-025)

```
$ shasum -a 256 specs/mcp-readonly-preflight/human-copy/plugins/sdd-ship/skills/ship/SKILL.md
5b978fe405834d1046f3ef0a55384ea0068436f1e691d481846d8786dbd51334  specs/mcp-readonly-preflight/human-copy/plugins/sdd-ship/skills/ship/SKILL.md

$ cat specs/mcp-readonly-preflight/human-copy/MANIFEST.sha256
5b978fe405834d1046f3ef0a55384ea0068436f1e691d481846d8786dbd51334  plugins/sdd-ship/skills/ship/SKILL.md

$ shasum -a 256 -c <manifest-entry-rewritten-to-the-staged-path>
specs/mcp-readonly-preflight/human-copy/plugins/sdd-ship/skills/ship/SKILL.md: OK
```

The staged candidate's SHA-256 matches the `MANIFEST.sha256` entry exactly,
in the two-space-separated form matching
`specs/quality-loop-fixes/human-copy/MANIFEST.sha256`'s precedent. **PASS.**

## Done-When bullet 6 — protected-boundary guarantees (AC-002 2nd half, AC-026, TEST-003, TEST-026)

```
$ git status --porcelain -- plugins/sdd-ship/skills/ship/SKILL.md
(no output)

$ git diff --stat -- plugins/sdd-ship/skills/ship/SKILL.md
(no output)
```

The live protected path carries no agent-authored edit from this feature —
confirmed by both `git status` (nothing staged or modified) and `git diff`
(zero-line diff against `HEAD`). Following
`tests/quality-gate-cycle-limit.tests.sh:356-361`'s "never opens the live
protected path for write" pattern: no `Write`/`Edit` tool call in this task
targeted `plugins/sdd-ship/skills/ship/SKILL.md` at any point — only the
`Read` tool was used against it, once, to derive the candidate's base
content. **PASS** (TEST-003, TEST-026, AC-002 second half, AC-026).

**Expected-red disclosure.** No conformance check in this task opens the
live path for write, and none was attempted twice — the single attempt to
stage a file at the canonical human-copy path
(`specs/mcp-readonly-preflight/human-copy/plugins/sdd-ship/skills/ship/
SKILL.md`) succeeded on the first try (it is not itself the protected path;
only the bare `plugins/sdd-ship/skills/ship/SKILL.md` path, and its listing
in `PHASE2_HUMAN_COPY_TARGETS`, are protected-adjacent). **The live-file
half of AC-026/TEST-026 remains red until a human applies this candidate** —
per `tasks.md` T-002's own Done-When and `infra-spec.md`'s "protected-file
staging leg" framing, mirroring
`tests/quality-gate-cycle-limit.tests.sh:390-392`'s identical, already
shipped precedent. This is the correct pre-human-copy state, not a defect of
this task, and is reported as such rather than treated as a blocker or a
reason to attempt a workaround.

## Done-When bullet 7 — AC-017…020 dual-runtime grid (ship leg)

See `03-dual-runtime-manual-verification.md` in this directory. No
text-based substitute is offered for the undetermined cells.

## Done-When bullet 8 — BL-001, no file under `mcp/` touched

```
$ git status --porcelain -- mcp/
(no output)
```

No file under `mcp/` was touched. **PASS** (BL-001).

## Overall change-set scope check

```
$ git status --porcelain
 M USERGUIDE.md
 M specs/mcp-readonly-preflight/tasks.md
?? specs/mcp-readonly-preflight/human-copy/
?? specs/mcp-readonly-preflight/verification/T-003/
?? specs/mcp-readonly-preflight/verification/T-002/
```

**Disclosure — pre-existing, concurrent changes not made by this task.**
`USERGUIDE.md` (modified), `specs/mcp-readonly-preflight/tasks.md`'s
`Status:` fields for T-002 and T-003 (`Planned` → `In Progress`), and
`specs/mcp-readonly-preflight/verification/T-003/` were **already present in
the working tree before this task began work** and were not created or
edited by this task. `USERGUIDE.md` is T-003's writable target (a different,
disjoint task per `tasks.md`'s "Task independence, by construction"
constraint), and the `Status: In Progress` flip on both tasks' entries is
the kind of state transition `implement-tasks`/`implement-task` is
authorized to make (`tasks.md` Lifecycle) — consistent with a concurrent
T-003 implementation happening in the same shared worktree, per the
`epic-136-phase3` shared-worktree hazard already on record in this
repository's history. **This task never opened `tasks.md` or `USERGUIDE.md`
for write at any point** — both are outside T-002's scope by the "Global
Constraints" task-independence design, and neither appears in any `Write`/
`Edit` tool call this task made. Only
`specs/mcp-readonly-preflight/human-copy/` (this task's two writable
artifacts: the staged candidate and `MANIFEST.sha256`) and
`specs/mcp-readonly-preflight/verification/T-002/` (this record) were
created by this task.
