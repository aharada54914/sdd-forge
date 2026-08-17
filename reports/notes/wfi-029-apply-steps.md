# WFI-029 apply and verify

Status: Pending human application

Base commit: `fcb363d60d2e7f0b44672e4e558609b3a3b3898e`

Protected targets:
- `plugins/sdd-review-loop/skills/impl-review-loop/SKILL.md`
- `plugins/sdd-review-loop/agents/impl-reviewer-b.md`

Both are in `PROTECTED_GATE_SUFFIXES`, so no agent can write them and sudo does
not lift it. `git apply --check` was run against the live files at the base
commit above and returned 0.

The CI-workflow half of this WFI is staged separately, because
`.github/workflows/test.yml` is a protected gate file under a different
convention: `docs/ci-staging/wfi-029-round2-contract-suite.md`.

## Apply

Run from the checkout that has **branch `claude/nifty-maxwell-928109`** checked
out — the patch file is committed on that branch and exists nowhere else. At the
time of writing that is the worktree
`/Users/jrmag/Projects/active/sdd-forge/.claude/worktrees/nifty-maxwell-928109`;
the primary checkout at `/Users/jrmag/Projects/active/sdd-forge` is on
`claude/adversarial-review-plan-dhzsr1` and will report
`can't open patch ... No such file or directory`. Confirm with
`git worktree list` if the layout has changed since.

Do not apply this in the dhzsr1 checkout even after fetching: that branch is 40
commits behind `main` and carries unrelated in-progress work. These are
repository-wide plugin files, so the change should travel with this branch's PR.

```bash
set -euo pipefail
WFI029_REPO="$(git rev-parse --show-toplevel)"
test "$(git -C "$WFI029_REPO" rev-parse --abbrev-ref HEAD)" = claude/nifty-maxwell-928109
WFI029_PATCH="$WFI029_REPO/reports/notes/wfi-029-impl-review-loop-instructions.patch"
cd "$WFI029_REPO"
test "$(shasum -a 256 "$WFI029_PATCH" | awk '{print $1}')" = c8cc355433a8530b53257e62ba5019567a45409c7a97914d083c4a2b43510214
git apply --check "$WFI029_PATCH"
git apply "$WFI029_PATCH"
bash tests/review-context-boundary.tests.sh
bash tests/review-prompt-calibration.tests.sh
bash tests/review-agent-isolation.tests.sh
bash tests/impl-review-round2-contract.tests.sh
bash tests/task-review-precheck.tests.sh
git diff --check -- plugins/sdd-review-loop/skills/impl-review-loop/SKILL.md plugins/sdd-review-loop/agents/impl-reviewer-b.md
```

`review-context-boundary.tests.sh` is the one to watch: it asserts that
`impl-reviewer-a.md` still carries the `Issue #143` carve-out and that
`impl-review-precheck.sh` still requires reviewer A's previous-round summary.
This patch documents that contract in the SKILL.md rather than changing it, so
the suite must stay green across the application.

## What each hunk closes

### `impl-review-loop/SKILL.md` — WFI-029 defects 1, 2 and 4

**STEP 2 and STEP 4 (defect 1).** The reviewer allowed-input manifests now name
`specs/<feature>/investigation.md` when it exists. `task-review-precheck.sh`
has always required it in *both* manifests; the SKILL.md named it nowhere, so an
orchestrator that followed the SKILL.md exactly produced a contract the task
stage rejected, and could not repair it after the fact without recording an
input the reviewers had been told not to read. The bullets also state that
`investigation.md` is supporting evidence, never authority over
`requirements.md`.

**STEP 2 and STEP 5 (defect 4).** The round-dependent manifest contract is
stated for the first time: reviewer B binds the current round's
`integrated-summary.json` every round; reviewer A additionally binds the
*previous* round's in rounds 2 and 3, and must not in round 1. This ratifies the
resolution already shipped in `fea5ccd0` (2026-08-01) rather than reopening it —
see "On defect 4's premise" below.

**STEP 7 step 4 and the new provenance re-review section (defect 2).**
`--reset` writes `Impl-Review-Status: Pending`, which `check-workflow-state.sh`
rejects once `tasks.md` exists, so the documented reset path was a dead end for
exactly the features most likely to need a re-review. STEP 7 now bounds the
`Pending` write to the pre-`tasks.md` window, and a new
"Post-Implementation Provenance Re-Review" section documents
`impl-review-precheck.sh --provenance-rereview` / `-ProvenanceRereview`, which
already existed in both runtimes and was reachable only by reading the script.

### `impl-reviewer-b.md` — WFI-029 defect 3

`legacy_design: true` relief existed in `impl-reviewer-a.md` and nowhere in its
sibling, although reviewer B's checks are equally template-field-keyed
(`DEPLOYMENT-CONCRETE` keys off `## Deployment / CI Plan`, `MIGRATION-PLANNED`
off `## Data Plan`, `NO-REQ-CONTRADICTION` off `## Constraint Compliance`). The
shared calibration reference delegates the decision back to the role file —
"where the reviewer prompt says so" — and reviewer B's prompt never said so.
The observed result was two fresh instances of the same role treating the same
class of fact oppositely in the same run.

The patch copies impl-reviewer-a's `# Legacy Design Mode` section and its two
calibration/hard-rule bullets verbatim. This is a symmetry fix, not a
relaxation: it changes nothing when `legacy_design` is false, and every
substantive (non-template-field) finding keeps its declared severity.

## On defect 4's premise

WFI-029 records defect 4 as a live contradiction between
`impl-reviewer-a.md:43` and `task-review-precheck.sh:219-222`. **That
contradiction was already resolved on `main` before the WFI was written.**
`fea5ccd0` (2026-08-01, human-applied) removed `integrated-summary.json` from
reviewer A's prohibition and added an explicit Issue #143 carve-out admitting
the previous round's summary, bounded to counts and check IDs. WFI-029 was
authored 2026-08-17 on `claude/adversarial-review-plan-dhzsr1`, which is 40
commits behind `main`, and quotes the pre-`fea5ccd0` text.

So item 7's choice does not need to be made again: option 1 ("reviewer A may see
its own prior-round summary") is the shipped behaviour. What item 7 also asked
for — "either way, the SKILL.md must state the resulting manifest contract for
rounds 2 and 3" — was genuinely outstanding and is what this patch supplies.

Item 8 (document the fresh-attempt workaround "until defect 4 is resolved") is
moot for the same reason and is deliberately not included.

## Item 6: the TYPE-H convergence rule

WFI-029 item 6 asks whether `task-review-loop`'s TYPE-H convergence rule also
applies at the impl stage, and requires the answer to be stated either way. The
patch states that it **does** apply, and copies the rule verbatim including its
TYPE-D carve-out.

This is the one substantive policy call in the patch, so it is flagged here for
the owner to reverse at apply time if the intent was otherwise. The grounds for
applying it: the impl stage exhibits the same non-convergence the rule exists to
prevent — WFI-029's own evidence is attempt 1 returning PASS and attempt 2
returning BLOCKED on design.md content byte-identical modulo the
`Impl-Review-Status:` line, with two of the three findings TYPE-H — and both
impl reviewer role files already tag every check TYPE-H or TYPE-D, so the rule
is well-formed here without further definition. The rule leaves TYPE-D findings
untouched, so it does not suppress the genuine TYPE-D gap that run also found.

## Not included

`Status: Draft` in `docs/workflow-improvements/WFI-029.md` is unchanged.
`sdd-hook-guard` denies any agent write that sets a WFI to `Approved`, and sudo
does not bypass it, so a human must flip that line for the change to be
formally sanctioned. WFI-029 lives on
`claude/adversarial-review-plan-dhzsr1`, not on this branch.
