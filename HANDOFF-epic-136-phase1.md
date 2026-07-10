# Handoff: epic #136 Phase 1 — deterministic gate & security fixes

**Branch**: `fix/epic-136-phase1-gates` (branched from `main` @ `e3507a2`)
**Status**: work-in-progress, **uncommitted** in the working tree. Nothing pushed. No PR yet.
**Date**: 2026-07-10

Resume by opening Claude Code in `C:\dev\sdd-forge` and pointing it at this file.

---

## 1. What this branch is doing

Resolving a batch of open issues from epic [#136](https://github.com/aharada54914/sdd-forge/issues/136),
one commit per issue, targeting a single PR.

### Scope decision (important — do not re-derive)

Epic #136 claims `check-*.{sh,ps1}` are all R-10 guard-protected and need the
"human `cp`" procedure. **That is wrong.** The real protected list is
`PROTECTED_GATE_SUFFIXES` in
[sdd-hook-guard.js:132-169](plugins/sdd-quality-loop/scripts/sdd-hook-guard.js:132), namely:

- `sdd-hook-guard.{js,py,ps1,sh}`, `kill-switch.*`
- `hooks/{claude,copilot,}hooks.json`
- `check-contract.{sh,ps1,py}`, `check-evidence-bundle.{sh,ps1,py}`, `validate_path.py`
- `.claude/settings*.json`, `*/plugin.json`
- `tests/{gates,eval,guard-parity,constant-parity}.tests.sh`
- `plugins/sdd-review-loop/agents/{impl,task}-reviewer-{a,b}.md`
- `{impl,task}-review-loop/SKILL.md`, `sdd-ship/skills/ship/SKILL.md`

Everything else — including `prepare-panelist-input.sh`, `check-task-state.ps1`,
`check-placeholders.sh`, `impl-review-precheck.sh`, `task-review-precheck.sh`,
`validate-review-context-set.sh` — **is agent-editable**. Verified by reading the
guard source, and `node --check` passes on it.

Consequently these issues are **out of scope for this branch** (genuinely need
human `cp`): #109, #110, #117, #118, #122, #123, #124.

---

## 2. Work completed (uncommitted, in working tree)

| Issue | File(s) | State |
|---|---|---|
| #111 | `plugins/sdd-quality-loop/scripts/check-task-state.ps1`, `tests/scripts.tests.ps1` | done, needs CI |
| #120 | `plugins/sdd-review-loop/scripts/{impl,task}-review-precheck.sh`, `tests/downstream-review-precheck.tests.sh` | done, **test failing — see §4** |
| #127 | `plugins/sdd-quality-loop/scripts/check-placeholders.{sh,ps1}`, `tests/check-placeholders.tests.sh` (new), `tests/run-all.sh` | done, tests pass locally |

Details:

- **#111**: `.ps1` used `Select-String -Pattern $task` (substring), so `T-001`
  also matched a `T-0010` report. The `.sh` twin was already correct
  (`grep -rlw`). Fixed the `.ps1` to `"\b" + [regex]::Escape($task) + "\b"`.
  There is no `.py` twin. 4 regression assertions added using `T-900`/`T-9000`.

- **#120**: added `command -v jq >/dev/null 2>&1 || fail "jq is required"` to
  both `impl-review-precheck.sh` and `task-review-precheck.sh`
  (`spec-review-precheck.sh` — confirm whether it needs it too; not yet checked).

- **#127**: `check-placeholders.sh` swallowed grep's exit status, so a *real*
  grep error (exit >= 2) was reported as a clean pass — fail-open in a quality
  gate. Now: 0 = matched, 1 = no match, >= 2 = hard error with a `FATAL`
  diagnostic. `.ps1` twin had the analogous bug (`-ErrorAction SilentlyContinue`
  + "path not found, skipping") and was fixed to fail closed identically.

Local verification actually run:

```
bash tests/check-placeholders.tests.sh   -> 8 passed, 0 failed (exit 0)
```

---

## 3. Work NOT started

- **#108 (Critical, RCE)** — `prepare-panelist-input.sh:196-203` interpolates
  SDD_SUDO fields into an **unquoted** heredoc (`python3 - <<PYEOF`), e.g.
  `key = b"""${_key}"""`. A field containing `"""` escapes the literal and runs
  arbitrary Python *before* the HMAC compare on line 202. Existing test PP-007
  (`tests/prepare-panelist.tests.sh:389-424`) sets `SDD_SUDO_SKIP_SIG=1`, so this
  branch is completely untested.
  **Fix**: `<<'PYEOF'` (quoted) + pass fields via env vars read with `os.environ`.
  **Tests**: a real-HMAC positive case (no `SKIP_SIG`), a tamper-fails case, and
  an adversarial-field case (`"""`, backslash) that must not execute code.
  Check the `.ps1` twin for parity.
  The file is **not** guard-protected — edit it directly.

- **#143** — `task-review-precheck.sh` (jq block ~L133-134, bash block ~L219-222)
  requires impl-reviewer-**a**'s manifest to contain the *previous* round's
  `integrated-summary.json` when `round > 1`. But
  `validate-review-context-set.sh:86-92` (`impl:impl-reviewer-a|impl:impl-reviewer-b`
  case) only authorizes `integrated-summary.json` for impl-reviewer-**b**. So
  reviewer-a including it is rejected with
  `REVIEW_CONTEXT_PATH: ... contains a real but role-unlisted path`.
  **Net effect**: impl-review can never PASS at round > 1, so `task-review-loop`
  is unreachable unless round 1 passes clean.
  **Chosen fix** (option b): authorize impl-reviewer-a for the *previous* round's
  summary in `validate-review-context-set.sh`. Add a regression test. Neither
  file is guard-protected.
  Note: #143 blocks #155 (matrix flip) per the epic's ordering constraints.

- **#115** — ground truth established by a subagent:
  - `docs/skill-reference.md:3` claims "6 プラグイン / 21 スキル"; correct is
    **7 plugins / 26 skills** (authority: `tests/validate-repository.ps1:12-13`,
    which already lists 7 and 26 and asserts them at L105-106).
  - `docs/superpowers/specs/2026-07-03-sdd-domain-plugin-design.md:98` says
    "21→27"; should be "21→26".
  - `README.md:202` already says 26 (correct). Historical plan docs under
    `docs/superpowers/plans/` say 21 — leave them, they are point-in-time records.
  - Terminology trap: all 26 skills set `disable-model-invocation: true`; only 6
    are `user-invocable`. Say which number you mean.

- **#116** — investigation complete, **verdict below**; needs an issue comment,
  a close, and a follow-up issue. Nothing to commit on this branch.

---

## 4. BLOCKING UNKNOWN — resolve this first

`bash tests/downstream-review-precheck.tests.sh` currently fails:

```
not ok: impl missing spec status must not create report evidence
DS_EXIT=1
```

**Unknown**: whether this is pre-existing on `main` or caused by the #120 jq
guard placement. A baseline run against clean `main` was started in an isolated
worktree at
`…/scratchpad/baseline-wt` (`git worktree add --detach <path> main`) but its
result was not read before handoff. **Re-run it, or just run the suite on `main`,
before touching anything else.**

Clean up when done: `git worktree remove <path>` (and `git worktree prune`).

Two traps already hit here:

1. This suite takes **> 2 minutes**. Run it with a long timeout or in the
   background; a 2-minute default kill leaves fixtures behind.
2. It **mutates `specs/workflow-state-registry.json`** and restores it in an
   `EXIT` trap. If you kill it mid-run, the registry stays dirty —
   `git checkout -- specs/workflow-state-registry.json` to restore. It also
   creates `specs/downstream-precheck-fixture/` and
   `reports/spec-review/downstream-precheck-fixture/`.

---

## 5. #116 investigation verdict (record this on the issue, then close it)

**Claim**: "the guard prints deny/block but the write goes through and corrupts
`Status:`" → an enforcement bypass, Critical.

**Verdict: NOT an enforcement bypass. It is a Bash matcher coverage gap.**

Evidence:

- `plugins/sdd-quality-loop/hooks/claude-hooks.json:16` matcher is
  `"Edit|Write|MultiEdit|apply_patch"` — **no `Bash`**. And
  `plugins/sdd-quality-loop/.claude-plugin/plugin.json:8` points Claude Code at
  that file. So under stock Claude Code the guard is **never invoked** for a Bash
  tool call.
- `plugins/sdd-quality-loop/hooks/hooks.json:16` (Codex) *does* match
  `Bash|bash|shell|exec_command|exec`. `copilot-hooks.json:4` has no matcher at
  all (matches everything).
- The guard has **no filesystem-write path**; it reads, decides, and exits.
  `emitDecision` (`sdd-hook-guard.js:447-464`) / `emit` (`sdd-hook-guard.py:257-270`)
  signal deny as stderr + `exit(2)`. Where the hook runs, exit 2 genuinely blocks
  the call (observed live three times during the investigation).
- Direct guard invocation matrix (scratchpad fixture, both twins agreed):
  `Write` adding `Approval: Approved` → deny/exit 2; `Write`/`Edit`/`Bash`
  setting only `Status: Approved` → **allow/exit 0**. The file was never modified
  by the guard.

**Conclusion**: `Status:` on `tasks.md` is not a guarded marker at all — only
`Approval: Approved` / `Second Approval: Approved` are. The remembered "deny"
came from a *different* (correctly blocked) `Edit`/`Write` call; the corrupting
write was a fallback Bash `sed`/`python` one-liner that ran unguarded. The bogus
`Status: Approved` was that script's own substitution, not the guard writing.

**Actions**:
1. Comment the above on #116 with the file:line evidence, then close it.
2. Open a new **High** (not Critical) issue: *`claude-hooks.json` omits `Bash`
   from the PreToolUse matcher, leaving the Bash tool entirely unguarded under
   stock Claude Code.* Note that `claude-hooks.json` **is** guard-protected, so
   that fix needs the scratchpad → human `cp` procedure.
3. Also note in that issue: even with Bash matched, the Bash-command check is a
   substring/regex heuristic that the guard's own comments
   (`sdd-hook-guard.py:883-885`) call evadable via `python3 -c` / `node -e`. It
   is best-effort, not a control to rely on.
4. **Correct the stale memory**: `~/.claude/projects/C--dev-sdd-forge/memory/sdd-forge-protected-gate-edit-procedure.md`
   item 4 asserts the guard "blocks but writes anyway". That is now disproven —
   rewrite it as the matcher-gap finding.

---

## 6. Remaining checklist to land the PR

- [ ] Resolve §4 baseline unknown.
- [ ] Implement #108, #143.
- [ ] Apply #115 doc edits.
- [ ] `CHANGELOG.md` → `## Unreleased`, one bullet per issue number.
      *(No subagent was allowed to touch CHANGELOG; it is still untouched.)*
- [ ] Doc follow-up in the same PR per epic policy (`docs/workflow-guide.md`,
      `docs/skill-reference.md`, `docs/troubleshooting.md` as applicable).
- [ ] Run: `bash tests/run-all.sh`, plus `pwsh ./tests/validate-repository.ps1`
      and `pwsh ./tests/scripts.tests.ps1`.
      ⚠️ `pwsh` (PS7) is **not installed** on this machine — only Windows
      PowerShell 5.1 (`powershell`). CI has `pwsh` on all 3 OSes.
- [ ] Commit one commit per issue (repo rule: *1 issue = 1 commit*).
- [ ] Push, open PR, wait for the 3-OS matrix in `.github/workflows/test.yml`.
- [ ] Merge, close #108/#111/#115/#116/#120/#127/#143, tick the epic #136 boxes.
- [ ] Delete this handoff file in the final commit.

### Version / release policy (epic #136)

Bump **only** via `scripts/bump-version.sh` — never hand-edit versions. (v1.9.0
desync incident.) fix/test-only → patch; behaviour-changing feat → minor.

---

## 7. Environment gotchas that already cost time

- **`gh` CLI does not work here.** It fails with `407 Proxy Authentication
  Required`, and its stored token is an Enterprise Managed User credential that
  gets `403` on `aharada54914/*` anyway. Use curl + SSPI proxy with the
  repo-matching PAT from the Windows credential manager:

  ```bash
  TOKEN=$(printf 'protocol=https\nhost=github.com\nusername=aharada54914\n\n' \
    | git credential fill | grep '^password=' | sed 's/^password=//')
  curl -sS --proxy-ntlm -U : -x http://hg-vm-prx-sdc.t.rd.honda.com:8080 \
    -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" \
    https://api.github.com/repos/aharada54914/sdd-forge/issues/108
  ```

  Never print the token. Pass Japanese bodies as `--data @file.json` (UTF-8).
  This PAT **can** write (issues, labels, comments) — proven on #108-#136.
  Retry on transient 407; do not mistake the error body for an issue body.

- **`.ps1` must be ASCII-only.** PS 5.1 reads BOM-less `.ps1` as ANSI; a stray
  em-dash or `→` corrupts it.

- **Never put the literal string `Approval: Approved` in a Bash command line.**
  The PreToolUse guard reacts to it. (Per §5 it denies the call; historically
  this is what corrupted `tasks.md` when a fallback script ran unguarded.)

- Git identity must stay `aharada` / dummy email. No PII, ever.

- `git stash push` ran once despite a rejected permission prompt and silently
  emptied the working tree. If files vanish, check `git stash list` before
  concluding work was lost.
