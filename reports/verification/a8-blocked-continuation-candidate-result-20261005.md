# A8 BLOCKED continuation: candidate-only verification

Date: 2026-10-05
Scope: A8 attempt 9 round 2 precheck stop; no review launch or reservation.
Owner checkout: a8-release-sync-oct01/sdd-forge.
Observed HEAD: `495c88d67af44530687ecea3ce9fb0a90a336539`.
Risk: high; changes admissible review history, so this is a protected candidate, not a routine source apply.

## Ownership and boundaries

The owner checkout was already dirty in AGENTS, guard/context scripts, design/tasks,
identity ledger, tests, and numerous reports. Those changes were retained.
Only this report, the adjacent candidate patch, and its fixture runner were authored.
Product sources, design, historical verdicts, ledger, task states, and approvals were not edited.
No protected refusal was encountered or bypassed. The patch was applied only inside
a newly allocated disposable fixture, never the owner checkout or installed baseline.

## Cause and smallest conservative candidate

`plugins/sdd-review-loop/scripts/impl-review-precheck.sh:436-437` and
`plugins/sdd-review-loop/scripts/impl-review-precheck.ps1:224-227` admit only
NEEDS_WORK in ADR-bound previous contracts. In contrast,
`plugins/sdd-review-loop/skills/impl-review-loop/SKILL.md:283` permits correction
of Critical findings before round 3. A legitimate Critical finding produces BLOCKED;
rewriting that historical verdict would be false evidence.

Do not merely add an OR: `impl-review-precheck.sh:274-277` and its PS1 counterpart
`:685-688` downgrade canonical workflow-state failure to advisory in provenance
re-review. The existing history validator does bind reviewer identities/manifests,
reviewer check results, aggregate counts, and integrated verdict:
`plugins/sdd-quality-loop/scripts/check-workflow-state.sh:321-392` and
`plugins/sdd-quality-loop/scripts/check-workflow-state.ps1:1356-1422`.

Candidate behavior:

- Keep NEEDS_WORK behavior unchanged.
- Accept exact uppercase BLOCKED only when previous round is below 3.
- Before that admission, require the existing canonical workflow-state validation
  to succeed, even in provenance-rereview mode. This intentionally fails closed
  if unrelated canonical validation is broken; it does not grant a new exemption.
- Preserve the existing ADR/core/layer/input-hash binding and unchanged-input checks.

The candidate adds no identity reservation, approval, or runtime installation.

## Reproduction and validation

Commands (run through `rtk proxy`):

```text
git apply --check reports/verification/a8-blocked-continuation-candidate-20261005.patch
python3 reports/verification/a8-blocked-continuation-candidate.tests.py
```

The runner copies the current owner artifacts to disposable storage, then runs
the actual Bash and PowerShell precheck entrypoints against copied A8 history.
Only copied fixture evidence is mutated for negative cases.
It also runs `bash tests/impl-review-adr-inputs.tests.sh --generation-only`
inside that copy. The original historical files are checked byte-for-byte afterward.

The first harness run was invalid: the copy omitted `contracts/`, and the PS1
invocation used the Bash spelling for the provenance flag. It is not acceptance
evidence. The harness was corrected to include contracts and use
`-ProvenanceRereview` for PS1. Product candidate bytes did not change.

The corrected run observed on both runtimes:

| Case | Result |
|---|---|
| Unpatched legitimate BLOCKED history | Exit 1 at historical verdict binding (RED) |
| Candidate + legitimate BLOCKED history | Exit 0, copied round-2 precheck emitted |
| Forged Critical count = 0 | Exit 1, canonical evidence validation required |
| Forged Major count = 0 | Exit 1, canonical evidence validation required |
| Mis-cased `blocked` verdict | Exit 1, previous ADR binding rejected |
| Unknown verdict | Exit 1, previous ADR binding rejected |
| Reviewer manifest pin mismatch | Exit 1, canonical evidence validation required |
| Existing generation regression | 30 passed, 0 failed |

Round-limit negative was then added. Final runner: exit 0, all 16 RED/GREEN
case assertions satisfied, existing generation suite 30 passed / 0 failed,
`owner_history_unchanged=true; failures=0`. Both runtimes rejected round 4
with `previous BLOCKED ADR round exhausted the three-round limit`.
The limit fixture is deliberately malformed historical data at round 3 and
checks that the explicit limit diagnostic occurs before admitting round 4;
it is not a fabricated formal review or a proof of successful round-3 review.

## Hash pins

| Artifact | SHA-256 |
|---|---|
| Owner `plugins/sdd-review-loop/scripts/impl-review-precheck.sh` | `9c79ab9c9cc821a7a4a36df713633063321a34573f320c7b235d5761db89f621` |
| Owner `plugins/sdd-review-loop/scripts/impl-review-precheck.ps1` | `72e03cfad7d35f8eb444fdd8db82b2aab705bdc33882e3dd4750d4a8017a47c4` |
| Candidate patch | `68c5b29b961091e180e6bd7eacf3fbb444610eb166f11bd0e17a15fc8ae78e78` |
| Final fixture runner | `c8aa2eadf2423b7cd6129a71b2789e2111dac26b6311c34d8489173747226c1e` |

## Remaining gates

Not applied to product sources. No owner round-2 precheck rerun, no reviewer
reservation/launch, no independent diff review, no Windows-native execution,
no exact-final-head CI, no baseline promotion. Candidate-local success is not a
formal review PASS or task completion. Source edits require the sanctioned
protected application path and preservation of the above input pins.

Read-only owner dry run: `git apply --check` exited 0. No human-apply helper
was created for this candidate; earlier similarly named helpers target other
changes and must not be reused for this patch.
