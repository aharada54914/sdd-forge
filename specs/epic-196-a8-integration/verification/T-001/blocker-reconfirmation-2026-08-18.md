# T-001 Blocker Reconfirmation

Date: 2026-08-18

Run ID: a8-t001-run-2026-08-17-01

Task Attempt Count: 2 (attempt 1: `preflight-blocker.md` /
`epic196-a8-t001-codex-20260809-01`, 2026-08-09, GPT-5 Codex, blocked at
preflight for the identical reason reconfirmed below)

## Purpose

Before authoring any Planned File, this attempt independently re-verified
attempt 1's own preflight finding (a hard conflict between T-001's approved
acceptance contract and `design.md`'s SKIP Allowlist Activation Gate),
rather than trusting a nine-day-old report. The conflict is still fully
present today, and the repository state has moved further in the direction
that entrenches it (additional Epic A1 fix commits have landed since
attempt 1's own re-verification). A second, independent OQ-001 investigation
(REQ-001/AC-005, Scope bullet 1) was also performed and is recorded below;
it does not resolve the blocker but is new information relevant to whoever
resolves it.

## Re-verification evidence (independent of attempt 1, 2026-08-18)

- `git fetch origin main` then `git rev-parse origin/main` →
  `9608f327d29e8db755d565996dbeb426e961541c` (`Merge pull request #300 from
  aharada54914/ci/mcp-node-22-baseline`).
- `git merge-base HEAD origin/main` → `9608f327d29e8db755d565996dbeb426e961541c`
  — identical to `origin/main`'s own tip, i.e. `origin/main` is fully
  contained in this worktree's `HEAD` history.
- `git rev-parse HEAD` → `57e421f8b0777f44cd3c196ed3721459ed30443a`
  (`Merge origin/main into feature/epic-196`, committer date
  `2026-08-17T20:39:11+09:00`).
- `git log -1 --format='%H %cI %s' a8d65c73` →
  `a8d65c7316f53787121874968e14878bc90c75aa 2026-08-08T18:10:04+09:00 Merge
  pull request #229 from aharada54914/feature/epic-189-a1-project-context`
  — Epic A1's own merge commit, present on `HEAD`.
- `git log -1 --format='%H %cI %s' c8ac93a2` →
  `c8ac93a27e2f8fc351100fb8fa76958781532797 2026-08-11T19:31:50+09:00
  fix(epic-189-a1): evict the shared-workflow snapshot from the bundle
  (class fix)` — a *later* Epic A1 fix commit, also present on `HEAD`,
  confirming Epic A1's own artifacts have kept moving on `main` since
  attempt 1's 2026-08-09 finding, not merely stayed merged.
- `ls plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.*`
  → all three of `.py`/`.sh`/`.ps1` exist at their canonical path on this
  worktree's `HEAD` (which contains all of `origin/main`).
- `grep -rl "check-hook-activation-handshake" plugins/*/skills/` → all five
  of Epic A1's own migrated consumer entry points (INV-007) reference it:
  `plugins/sdd-bootstrap/skills/bootstrap/SKILL.md`,
  `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md`,
  `plugins/sdd-lite/skills/lite-gate/SKILL.md`,
  `plugins/sdd-lite/skills/lite-spec/SKILL.md`,
  `plugins/sdd-ship/skills/ship/SKILL.md`.

This reproduces, with fresh commands and a fresh worktree state ten days
later, every material fact attempt 1's `preflight-blocker.md` recorded.

## The conflict (unchanged from attempt 1; restated for this attempt's own record)

- `design.md`'s SKIP Allowlist Activation Gate (`specs/epic-196-a8-integration/
  design.md:1230-1277`) defines a case (`AC-006`, `AC-015`, or `AC-016`) as
  "activated" — meaning its own `SKIP` becomes a non-zero-exit hard failure
  if still present — "exactly when every canonical artifact that case
  depends on exists at its own fixed repo-relative path on main". AC-006's
  own dependency is Epic A1's hook-activation handshake surface (the same
  surface AC-015/AC-016 depend on); that surface now exists on `main` per
  the evidence above, so AC-006 is activated.
- T-001's own approved contract (`tasks.md` Planned Files/Scope/Done
  When/Out of Scope for T-001) requires the opposite outcome for the
  identical case: TEST-006 must emit the canary as a **non-failing** `SKIP`
  ("Named `SKIP` (citing Epic A1's tracking issue) until Epic A1 merges",
  AC-006; "registered in `a8-skip-allowlist.json`" as the Done-When
  condition for TEST-006 to *pass*), and T-001's own Out of Scope section
  explicitly forbids doing the one thing that would resolve this
  ("Un-skipping AC-006 or exercising Epic A1's own artifacts — that is a
  follow-up task once Epic A1 merges").
- Both clauses read literally: T-001 cannot produce a suite where TEST-006
  passes (SKIP, non-failing) without producing a suite that, per the
  identical design document's own activation-gate logic (which
  `design.md`'s Stale/unknown/drift-handling paragraph explicitly assigns
  to `tests/cross-runtime-handoff.tests.sh` itself, i.e. this same task's
  own file, to implement), would have to treat that same SKIP as a hard
  failure the moment the suite runs against today's repository state.
  There is no single, honest implementation of TEST-006 that satisfies both
  halves of its own approved contract simultaneously; this is not an
  implementer's misreading, it is the literal, currently-true state of two
  clauses in the same approved document.
- Un-skipping AC-006 (the one code path that would resolve this) is
  explicitly listed under T-001's own Out of Scope section, so this task
  cannot resolve the conflict by choosing that branch on its own authority
  either.

## New in this attempt: OQ-001 investigation (REQ-001/AC-005; does not resolve the blocker above)

T-001's Scope requires investigating, at implementation start, whether any
of the three CLIs now expose a confirmed, scripted headless/non-interactive
invocation contract (OQ-001), rather than assuming `investigation.md`'s own
2026-07-22 "unconfirmed" finding (INV-021, which was itself scoped to
in-repo documentation, not to each CLI's actual current capability) still
holds without re-checking. It does not.

- `claude --version` → `2.1.233 (Claude Code)`; `claude --help` documents
  `-p, --print` explicitly: "starts an interactive session by default, use
  -p/--print for non-interactive output".
- `/opt/homebrew/bin/codex --version` → `codex-cli 0.144.6`; `codex --help`
  lists `exec` as a top-level subcommand: "Run Codex non-interactively
  [aliases: e]".
- `copilot --help` (`/opt/homebrew/bin/copilot`, the standalone GitHub
  Copilot CLI, distinct from the `gh copilot` extension) documents
  `-p/--prompt` explicitly: "use -p/--prompt for non-interactive scripting"
  and separately documents `--allow-all-tools ... required for
  non-interactive mode".

So, as of 2026-08-18, on this machine, all three CLIs do expose a
documented, scripted, non-interactive invocation flag — a materially
different finding from `investigation.md`'s INV-021 and from
`design.md`'s Design Decisions text for OQ-001 ("this package does not
claim any of the three CLIs' headless contracts are confirmed").

This does **not**, however, satisfy OQ-001's own bar as `design.md` states
it: a contract "suitable for CI automation" (requirements.md OQ-001's own
wording). Actually exercising any of these three flags against a live
model backend inside `tests/cross-runtime-handoff.tests.sh`/`.ps1` would be
a live LLM/Provider API network call, which this same feature's own Global
Constraints (`tasks.md`, "CI resilience") and `design.md`'s own External
Integrations section both scope out of any suite registered in
`tests/run-all.*`/CI ("no live LLM, Provider API, or network call beyond
what `install.sh`'s own existing `gh`-authenticated path already makes").
A GitHub Actions runner would additionally need three separate providers'
live credentials provisioned as repository secrets, with real per-run cost
and non-determinism risk, none of which this task is authorized to
provision. Per `acceptance-tests.md`'s own instruction ("a Phase 2/3
confirmation upgrades the affected row in both `design.md`'s table and this
column in the same commit, never in only one of the two"), this attempt
therefore does **not** upgrade AC-002/AC-003/AC-004's
`automated-pending-confirmation` classification: the underlying CLI flags
exist, but a CI-automatable session contract does not, and only the latter
is what that classification's own gating fact names. This finding is
recorded here so the next attempt does not have to re-run the same
investigation, and so it is visible rather than silently re-discovered or
silently assumed away.

## Disposition

No Planned File was authored by this attempt, matching attempt 1's own
restraint, for the same reason: any of the concrete implementation choices
for TEST-006 (emit SKIP; emit PASS by exercising AC-006; omit the case)
either fails the suite the moment it runs (SKIP, given today's true
activation state), does work explicitly placed Out of Scope (exercise
AC-006), or silently drops a mandatory case (omit) — precisely the
"never silently drops" failure mode `tasks.md`'s Done When for TEST-006
itself forbids. Authoring the *rest* of the suite (TEST-001/002/003/004/005)
while leaving TEST-006 unresolved was considered and rejected: `design.md`'s
own Fixture Contract schema requires every trace to carry the canary case,
and registering a suite in the shared `tests/run-all.sh`/`.ps1` — which
other worktrees' CI runs depend on — with a permanently-failing or
permanently-Out-of-Scope-violating case built in would be a worse outcome
than leaving the task blocked and clearly reported.

## Decision required (unchanged from attempt 1)

1. Amend/re-review T-001 (and, in the same commit, `design.md`'s
   Classification Table row and `acceptance-tests.md`'s Test Type column
   per that document's own "same commit" rule, if the OQ-001 finding above
   is also to be reflected) for the post-Epic-A1 state, allowing AC-006 to
   be exercised as part of T-001 (or reassigning that exercise to an
   explicit follow-up task, matching Main Workflows step 7); or
2. Preserve the frozen task literally and accept that T-001 remains
   blocked until a decision is made — the suite and the `a8-skip-
   allowlist.json` AC-006 entry cannot both exist and both pass under the
   contract as currently approved.

This is a human/orchestrator decision, not one this task is authorized to
make on its own by silently picking a side (post-review artifact-freeze
convention; `tasks.md`'s own Lifecycle text reserves `Status` changes other
than `Blocked`/`In Progress`/`Implementation Complete` to humans, and
neither of those three states resolves *which* of the two paths above is
correct — only a human can pick one).
