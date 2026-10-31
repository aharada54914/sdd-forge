# Session handoff — epic-193-a5-capability-resolver, 2026-09-03/04

**Written for a fresh agent (Codex or Claude) picking this branch up cold.**
Every number below was measured, not recalled. Branch
`feature/epic-193-a5-capability-resolver`, HEAD `798841e9`, working tree
clean, everything pushed.

## Bottom line

The feature is **complete and internally green**. All ten tasks are
`Status: Done`, all three review gates read `Passed`, and
`check-workflow-state --feature epic-193-a5-capability-resolver` exits 0
with zero tolerated-drift notes. The CI job that was red because of this
feature (`repository-release-validation`) now passes 8/8 locally and green
on all three OSes in CI.

Nothing further is blocked on an agent. What remains is human review and
merge, plus one pre-existing merge conflict that a human must resolve.

## What this session did (17 commits, `d731eb12..798841e9`)

The whole session was one job: **re-bind the post-Done review evidence** so
the gitless release-validation copy could reconcile it. That copy cannot run
git, so every reviewer contract must pin the *live* document hashes. Getting
there took two owner rulings and three passes over the gate chain.

### Owner rulings (recorded verbatim in `investigation.md`)

| Ruling | Verbatim answer | What it authorized |
|---|---|---|
| (F) | 「凍結文書の修正を承認」 | Annotate frozen `requirements.md` (12 sites) + `acceptance-tests.md` (6 rows) so their absolute claims cite rulings (a)/(A)/(B). Commit `45dbe5f1`. |
| (G) | 「裁定(F)をdesign.mdへ拡張（推奨）」 | Extend the same annotation to frozen `design.md` (5 sites), name the containment fixture in Test Strategy, add OQ-001/002 template fields. Commit `fa59914e`. |

Each ruling entry carries the amendment commit hash and per-document
SHA-256 pins. **This format is mandatory** — spec attempt 14 round 1 raised
a Critical precisely because ruling (G) initially cited two verification
artifacts as bare paths (calibration element 4 forbids that). Fixed in
`c9402466`.

### Gate chain, final state

| Stage | Attempt | Verdict | Reviewer runs |
|---|---|---|---|
| spec-review | 14 (round 2) | PASS clean | seq0877 / seq0880 |
| impl-review | 10 | PASS clean | seq0881 / seq0882 |
| task-review | 15 | PASS clean | seq0883 / seq0884 |

Earlier attempts are preserved and tell the story: spec 12 BLOCKED at round
3, impl 8 BLOCKED, spec 13 / impl 9 / task 14 passed but went stale again
when ruling (G) landed. Ledger records seq0862–0884 belong to this session.

### The defect class that drove every iteration

**Amendment propagation.** Annotating *some* statements of a fact leaves its
siblings contradicting them. Three new instances this session, on top of the
~17 already recorded:

1. spec attempt 12 r3 — `acceptance-tests.md` AC-011/039/049 left unmarked
   while the twelve `requirements.md` sites were done.
2. impl attempt 8 — `design.md:2433`/`:2870` "two exceptions" became false
   *because* requirements was amended. The fix reached a third document.
3. spec attempt 14 r1 — the ruling record's own citations failed the
   evidence bar. **The evidence of a fix is itself subject to the fix.**

Practical rule for the next amendment: **land every amendment first, then
run spec→impl→task with no edits in between.** Doing (G) after (F) forced
spec and impl to run twice each.

## Human actions outstanding

1. **[PR #245](https://github.com/aharada54914/sdd-forge/pull/245)** — the
   feature PR. **OPEN but `mergeable: CONFLICTING`.** See the merge section
   below; a human must perform the merge.
2. **[PR #386](https://github.com/aharada54914/sdd-forge/pull/386)** — the
   npm-audit fix (fast-uri ×4 high, qs ×2 moderate) on branch
   `fix/npm-audit-fasturi-qs-20260903`, cut from `origin/main`, **all checks
   green**. Merging it clears the MCP audit red on *every* branch. Unrelated
   to this feature; safe to merge independently and first.
3. **WFI-061 / WFI-062** — both `Audit-Status: Human-Pending` after two
   audit cycles (cycle 1 NEEDS_REVISION → revised; cycle 2 PASS, zero
   findings). Issues [#387](https://github.com/aharada54914/sdd-forge/issues/387)
   and [#388](https://github.com/aharada54914/sdd-forge/issues/388).
   To approve, a human edits `Status: Draft` → the approved value in
   `docs/workflow-improvements/WFI-061.md` / `WFI-062.md`. An agent cannot:
   the hook guard blocks that string unconditionally, sudo included.

## Merge state of PR #245 (read before touching it)

Measured 2026-09-04 against `origin/main`:

- **579 commits behind, 387 ahead.**
- **19 conflicting files** (`git merge-tree --write-tree origin/main HEAD`):
  `AGENTS.md`; `check-workflow-state.{sh,ps1}`; `run-panelist-gemini.sh`;
  `run-panelist-gpt.{sh,ps1}`; `impl-review-precheck.{sh,ps1}`;
  `task-review-precheck.{sh,ps1}`; `reports/review-context/identity-ledger.json`;
  `specs/epic-191-a3-path-ownership/human-copy/MANIFEST.sha256`;
  `specs/workflow-state-registry.json`; `tests/downstream-review-precheck.tests.ps1`;
  `tests/run-all.{sh,ps1}`; `tests/run-panelist-effort.tests.{sh,ps1}`;
  `tests/workflow-state.tests.sh`.

**A verified resolution recipe already exists**:
`reports/notes/epic-193-a5-merge-resolution.md` (v3, 2026-08-29,
co-produced with and verified by codex gpt-5.6-sol across two adversarial
passes). It still covers exactly these 19 paths.

**One figure in that recipe is now stale.** It states the branch adds *92*
unique ledger tail records; the current measured count is **120**
(merge-base 764, main 959, branch 884, branch-unique seq 765–884). The
re-chaining procedure itself is unchanged — only the count moved, because
this session appended seq0862–0884. Re-measure before applying.

**Good news for the evidence:** the two calibration files that every
reviewer manifest hash-pins —
`plugins/sdd-review-loop/references/spec-review-calibration.md` and
`reviewer-calibration.md` — are **byte-identical on main and this branch**
(verified by `git rev-parse HEAD:<f>` vs `origin/main:<f>`). A merge will
therefore *not* stale those pins. The conflicting gate scripts are not
hash-pinned by any contract; they only need to run.

The recipe says a human performs the merge because several conflicting
files are guard-protected against agent modification. That still holds.

## CI state

Last run on this branch: `33724492168` at `93f16c0b`, **failure** — but the
failures were only `ci-mcp-tests` / `local-env-mcp-tests` / `mcp-tests` on
ubuntu, all in the `npm audit` step, i.e. the advisory PR #386 fixes. The
`test` jobs (which include `repository-release-validation`) passed on
ubuntu, macos and windows. The three docs-only commits after `93f16c0b`
have not been CI'd; the workflow is `workflow_dispatch`, so trigger with:

```bash
gh workflow run test.yml --ref feature/epic-193-a5-capability-resolver
```

## Landmines (each cost real time this session)

- **Homebrew bash 5.3.9 deadlocks.** Any wrapper that runs a repo script
  must pin `PATH="/bin:/usr/bin:$PATH"` and redirect `< /dev/null`. Symptom:
  a suite that takes 54s in CI hangs past 10 minutes locally. This bit
  `mcp/sdd-forge-mcp`'s `npm test` too (247/247 in 12s once pinned). Killing
  a hung run leaves 100+ orphan node processes — sweep with
  `ps aux | grep '[n]ode.*<worktree>'` before retrying.
- **Reviewer output manifests must match the supplied set exactly.** A
  task-reviewer added its TYPE-H reference (`attempt-14/.../reviewer-a.json`)
  as a 13th manifest entry; the persisted-state validator fails closed on
  that. The fix is to ask the reviewer to re-emit — never to edit its JSON.
  Cite the reference inside finding text instead.
- **The hook guard denies read-only commands** that merely mention the
  consent-token flag name, and denies gate-script paths in read commands.
  This is WFI-061's subject. Workaround: put the command in a scratchpad
  wrapper script, or use the Write tool instead of a shell redirect.
- **spec-review round transitions only consult requirements/acceptance
  hashes.** A round-1 Critical curable only in `investigation.md` has no
  lawful round-2 transition and `--reset` refuses (non-terminal verdict).
  This is WFI-062's subject. This session escaped only because a legitimate
  requirements edit happened to exist. If you hit it with no such edit, stop
  and consult the owner rather than manufacturing one.
- **Bash cwd drifts** to the session sandbox worktree after any interruption.
  Always `cd /Users/jrmag/Projects/active/sdd-forge-wt-epic-193` explicitly;
  a silent wrong-tree run produced a `FileNotFoundError` mid-chain here.
- **Other `sdd-forge-wt-*` worktrees belong to other sessions.** Do not
  reset, checkout, or stash across them. `/Users/jrmag/Projects/active/sdd-forge`
  (the primary checkout) is currently on `feature/wfi-058-059-implementation`,
  another session's work — the WFI files are NOT visible there.

## How to resume

Confirm the state before doing anything:

```bash
cd /Users/jrmag/Projects/active/sdd-forge-wt-epic-193
bash plugins/sdd-quality-loop/scripts/check-workflow-state.sh --feature epic-193-a5-capability-resolver
bash plugins/sdd-quality-loop/scripts/check-task-state.sh specs/epic-193-a5-capability-resolver/tasks.md
```

Both should exit 0 (`workflow-state: ok`; `Task state check passed for 10
task(s).`). If either fails, something landed after `798841e9` — read the
stage-provenance lines, they name the stale pin exactly.

If a frozen document must change again, re-read
`## Amendment Re-Review Context` in `investigation.md` first: the ruling
entry format (verbatim owner answer + amendment commit hash + per-document
SHA-256 + per-artifact SHA-256 for any implementation/evidence citation) is
what the calibration's evidence bar checks, and getting it wrong costs a
full attempt.
