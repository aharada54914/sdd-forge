# A8 combined launch contract: direct application and regression

Owner checkout: `/Users/jrmag/.codex/worktrees/a8-release-sync-oct01/sdd-forge`  
HEAD: `495c88d67af44530687ecea3ce9fb0a90a336539` (detached)  
Scope/risk: high-risk shared review identity, input-digest and tool boundary repair; eight fixed targets in `a8-combined-launch-candidate-20261006/pins.json`. All prior dirty work and review/ledger records remain in place. The user's later direct-application instruction superseded the candidate's human-operator restriction for this fixed patch; it did not authorize a new review verdict or installation.

Before writing, `human_apply.py --check` returned `READ-ONLY CHECK OK` for the pinned HEAD, patch and all seven existing preimages plus one absent new target. The seven preimages were archived to `/tmp/a8-combined-backup-WHIxaKpc/preimages.tar`; archive members were read back and all SHA-256 values match `pins.json`. The fixed candidate patch (`37a711d5131e29f3ecdafaac983c2593f3559146cba5abc671473358a56027ea`) was applied once via `apply_patch` in the owner checkout. All eight resulting file SHA-256 values match the pinned postimages; `git diff --check` on the seven tracked targets passed. No refused operation was rerouted, and no hooks were changed.

Behavioral evidence (all via `rtk proxy`, `login=false`):

- Candidate digest tests: exit 0; Bash and PowerShell valid A/B, mutation, path, receipt, link and ordinary-mode negatives passed. This executes candidate bytes proven identical to the applied postimages, not a native host permission test.
- Candidate helper tests: exit 0; ten check/refusal/apply-readback cases passed in disposable checkouts. The owner originals were unchanged by those tests.
- Digest overlay regression: exit 0, `PASS: 84; FAIL: 0`, plus three Python tests.
- Original checkout `bash tests/review-context-boundary.tests.sh`: exit 0, 32 source anchors and `PASS: 84; FAIL: 0`, plus three Python tests. Fixture reservations stayed inside disposable roots.
- `bash tests/review-prompt-calibration.tests.sh`: exit 0. New Python source parsed successfully.

Still unverified: effective live host exact-command permission rejection and inherited policy; fresh idle host-session allocation and actual input delivery; independent formal review on changed admitted bytes; native Windows behavior of the new calculation branch (it fails closed there); latest-head CI, merge and post-merge behavior. No identity reservation, task-status change, quality verdict, installed-baseline promotion, commit, push or PR was performed.
