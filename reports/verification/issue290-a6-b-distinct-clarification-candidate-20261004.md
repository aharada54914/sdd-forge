# Issue 290 A6/B6 distinct-identity clarification candidate

Status: candidate only; protected originals unchanged. No attempt 7 reservation or turn.

The normal `apply_patch` edit of both task reviewer roles and the common boundary was rejected by the PreToolUse deterministic gate: “エージェントはゲートスクリプト・フック設定・テストファイルを書き換えられません。これらのファイルは強制チェーンの一部です。sudo でもバイパスできません。” The rejected operation did not apply. No alternate executor or alias was used.

The candidate changes wording only. It preserves both A/B identity distinctness and ledger-wide uniqueness, while clarifying that a host-issued root thread ID can be both fields within one invocation. The canonical validator already accepts that case; this does not alter its judgment.

After an authorized human or the repository's normal protected-file change process applies the candidate, limited regression should check:

1. Both task reviewer roles and the common boundary state the same A/B-versus-within-record distinction. Their other launch requirements remain unchanged.
2. The existing native-launch test `rtk proxy node --test reports/verification/issue290-guarded-task-review-launch.test.mjs` passes, including same-root-thread `verifyIdle`, receipt hash, distinct B manifest inputs and no raw A output.
3. The original validator's existing tests (both Bash and PowerShell, where runnable) still enforce nonblank IDs, ledger-wide uniqueness and A/B distinctness; a within-record equal-ID fixture is accepted only when both fields are genuine host-issued identity, and duplicates across reservations are rejected.
4. A6/B6 original outputs and canonical ledger records remain unchanged. Fresh review, if separately authorized, starts at a new attempt with fresh independent A/B reservations; never reuse B6.

Evidence: `task-review-loop/SKILL.md:206-207`, `review-precheck-common.sh:308-309`, `validate-review-context-set.sh:418-421,479-485,582-590`, canonical ledger sequence 1213/1214. B6's BLOCKED finding is preserved as historical, unevaluated task content.

