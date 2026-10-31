# A8 combined human-application package

Candidate preparation only. APPLY_READY: false. RELEASE_READY: false.
No owner application, reservation, native reviewer launch or verdict/status change.

## Composition

Owner: /Users/jrmag/.codex/worktrees/a8-release-sync-oct01/sdd-forge
HEAD: 495c88d67af44530687ecea3ce9fb0a90a336539

The digest candidate patch f73564abaa6382d3a02e0198fd1f7eaed2bf5bc7f18fd42488a88c616bc6f8f7 and idle-identity patch 2dd88a0a4e6eb5b8754a194b118ac8b6b4f6477a560660647a13038ae4cc5d0d were applied only inside one disposable composition tree. The combined SKILL contains exactly the earlier three identity spans plus the earlier digest appendix. Seven other product files are byte-identical to the independently reviewed digest candidate. No new runtime behavior was added by combining.

Eight fixed targets (pre/post hashes: pins.json):

- plugins/sdd-quality-loop/scripts/validate-review-context-set.sh
- plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1
- plugins/sdd-quality-loop/scripts/reviewer-receipt.py (new; preimage must be absent)
- plugins/sdd-review-loop/agents/spec-reviewer-a.md
- plugins/sdd-review-loop/agents/spec-reviewer-b.md
- plugins/sdd-review-loop/references/review-context-boundary.md
- plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md
- tests/review-context-boundary.tests.sh

Combined patch SHA256: 37a711d5131e29f3ecdafaac983c2593f3559146cba5abc671473358a56027ea
Human helper SHA256: 4267df606fff069eddd3174192cf38e3f935293e92ce1f9094a45077a38fd554

The prior human helper is reused with eight fixed pins, an absence pin for the new file, and the combined patch. It verifies owner/HEAD/patch/all preimages before writing, refuses links, requires interactive confirmation, backs up all existing originals with readback and records new-file absence, rechecks target and patch bytes, uses ordinary `rtk proxy git apply`, and verifies every postimage. Reapplication refuses mismatched preimages. No automatic rollback or permission bypass. Backup is recoverable, but rollback is not automatically executed.

## Limited validation

All commands used rtk proxy, login=false in owner:

- `python3 -B reports/verification/a8-combined-launch-candidate-20261006/build.py`: exit 0; source hashes/preimages verified, eight-file composition and seven unchanged bytes asserted.
- `python3 -B reports/verification/a8-combined-launch-candidate-20261006/helper_test.py`: exit 0; ten disposable cases: check, wrong patch, preimage, HEAD, symlink, hardlink, new file already exists, non-TTY, confirmation mismatch, full apply/readback/backup and repeat rejection. Owner hashes/absence unchanged. See helper-test.stdout.txt.
- `python3 -B reports/verification/a8-combined-launch-candidate-20261006/human_apply.py --check`: exit 0, `READ-ONLY CHECK OK; NOT APPLIED; no authorization inferred`.

Executable behavior is unchanged from the digest candidate whose focused tests and shared boundary suite passed (see ../a8-reviewer-digest-candidate-20261006/results.md); those tests were not rerun without cause. The combined SKILL was verified as a mechanical union rather than counted as native execution proof.

## Single human command, pending required release review

Do not run until the governing contract/application review has admitted these combined bytes. This file does not itself grant that approval. Parent reported independent component artifact reviews with no Major, which is distinct from formal contract approval and the new helper's independent review.

```sh
rtk proxy python3 -B /Users/jrmag/.codex/worktrees/a8-release-sync-oct01/sdd-forge/reports/verification/a8-combined-launch-candidate-20261006/human_apply.py --apply
```

Interactive phrase: `APPLY A8 COMBINED CONTRACT`.

Remaining: independent combined helper/delta review and required formal contract/application admission; native exact-command/inherited-permission boundary and real host identity/receipt correspondence; original-path post-application regression. New calculation mode's Windows runtime is unsupported/fail-closed; normal Windows path is source-preserved but not natively tested. The helper applies product files only, not launcher permission settings, installed controls or baseline. Native launch remains separately gated; application alone is not formal A/B review or A8 completion.

Coder/tester guidance kept the change to composition and focused disposable helper tests. No additional framework or new feature was introduced.
