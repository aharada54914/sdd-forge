# T-007 second-approver package (human execution required)

T-007 is the epic's only **Risk: critical** task. Its Done-When carries a
human-only clause that SDD_SUDO does not and cannot bypass (verbatim from
`specs/epic-189-a1-project-context/tasks.md`, T-007 Done When):

> TDD Red/Green evidence recorded in the implementation report; an
> independent quality-gate verdict (a named second reviewer, not the
> implementing agent) records PASS; **a second, distinct named approver
> additionally reviews and signs the evidence bundle** (Risk: critical,
> `risk-classification-policy.md:17`).

The first two clauses are discharged by the agent chain (implementation
report + independent quality-gate evaluation). **The third clause is
yours.** No agent may perform it.

## Why the tooling forces this

`plugins/sdd-quality-loop/scripts/check-evidence-bundle.sh` applies two
extra rules when the contract's risk is `critical` (they do not apply to
the `high`-risk tasks completed so far):

1. `git_generated_dirty` must be **false** — a critical bundle may not be
   generated from a dirty working tree (the flag is set from any non-empty
   `git status --porcelain`, INCLUDING untracked files).
2. The bundle must carry a `signature` object; with `alg: hmac-sha256`
   the checker recomputes the HMAC over the bundle's canonical form using
   the evidence key and rejects a mismatch (`alg: sigstore` is the
   alternative, gated on `SDD_EVIDENCE_SIGSTORE_VERIFIED`).

`generate-evidence-bundle` signs automatically **when an evidence key
resolves in its environment** — so the signature is produced by whoever
runs the generator, which is exactly why the second approver runs it.

## Prerequisites (check before starting)

1. **T-007's quality gate has returned PASS** (seq0357) and the
   coordinator has persisted the report under `reports/quality-gate/`.
   The orchestrator will supply the exact report path.
2. **The working tree is clean** — `git status --porcelain` must print
   NOTHING. This currently fails: another session's untracked files live
   under `specs/epic-189-a1-project-context/human-copy/`. Resolve that
   first (commit them, or have that session finish), otherwise the
   critical bundle will be rejected at check time.
3. **You are a distinct, named approver** — not the implementing agent
   and not the quality-gate evaluator. Record your name/identifier in the
   commit body.
4. **An evidence key is available to you** — one of:
   `SDD_EVIDENCE_KEY` (env), `SDD_EVIDENCE_KEY_FILE` (env, path), or the
   repository's documented home-path key location. Never paste key
   material into a commit, a report, or a chat message.

## Steps

```
cd /Users/jrmag/Projects/active/sdd-forge-wt-epic-189

# 0. Preconditions
git status --porcelain          # MUST be empty
git log --oneline -1            # note the commit the bundle will bind to

# 1. Review what you are signing (this is the substance of the clause —
#    the signature attests that YOU reviewed it, not that a script ran)
#    - the implementation report:
#        reports/implementation/epic-189-a1-project-context/T-007.md
#    - the quality-gate report the orchestrator names (PASS, seq0357)
#    - the verification contract:
#        specs/epic-189-a1-project-context/verification/T-007.contract.json
#    - the crash-injection evidence:
#        specs/epic-189-a1-project-context/verification/T-007/crash-injection-sh.log
#        specs/epic-189-a1-project-context/verification/T-007/crash-injection-ps1.log

# 2. Make the evidence key available to THIS shell only (example forms;
#    use whichever your setup uses — do not echo the value)
#    export SDD_EVIDENCE_KEY_FILE="$HOME/.sdd/evidence-key"
#    (or) export SDD_EVIDENCE_KEY='...'

# 3. Generate the SIGNED bundle (regenerates T-007.evidence.json with a
#    signature object; must be run with the clean tree from step 0)
sh plugins/sdd-quality-loop/scripts/generate-evidence-bundle.sh \
  specs/epic-189-a1-project-context/verification/T-007.contract.json \
  <QUALITY-GATE-REPORT-PATH> .

# 4. Verify it passes the critical-tier checks
sh plugins/sdd-quality-loop/scripts/check-evidence-bundle.sh \
  specs/epic-189-a1-project-context/verification/T-007.evidence.json .
#    Expect: "Evidence bundle passed for task T-007." and exit 0, with NO
#    dirty-tree warning. If it reports a missing/invalid signature or a
#    dirty tree, STOP and report — do not work around it.

# 5. Commit the signed bundle (explicit path; record WHO signed)
git add specs/epic-189-a1-project-context/verification/T-007.evidence.json
git commit -m "chore(epic-189-a1): T-007 evidence bundle signed by second approver

Second, distinct named approver (Risk: critical Done-When clause):
<YOUR NAME / IDENTIFIER>. Reviewed: implementation report, quality-gate
PASS report, verification contract, and both crash-injection evidence
logs. Bundle regenerated from a clean tree and verified with
check-evidence-bundle (signature valid, no dirty-tree warning)."
```

## After you finish

Tell the coordinator: the commit SHA, your approver identifier, and the
`check-evidence-bundle` output line. The orchestrator then records T-007's
Done transition (the Done write itself remains the coordinator's step, as
for every other task).

If any step fails — dirty tree that cannot be cleaned, no resolvable
evidence key, signature verification failure — stop and report rather
than bypassing; the critical-tier rules exist precisely to make this
clause unfakeable.
