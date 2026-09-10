# Human-supplied branch evidence — 2026-09-05

Status: exact supplied deltas inspected; no implementation, runtime PASS, ownership release, merge or deletion.

## Remote closure recheck — 2026-09-06

Primary re-read Issues #295 and #380 including comments. Both remain open and cover the Second-Approval correction plus carried-forward CI wiring, installer tar-exit handling, and documentation findings. Exact-head PR queries (`--state all --head auto/improve-20260817` and `--head auto/improve-20260831`) each returned an empty list. Remote main remains `633dcdf6d3289054f832ebbed066e6680e25d645`. These observations do not establish that every individual finding is still present, but do not justify closing either aggregate issue.

A local read-only `rg` command spanning installer/documentation, guard source, and workflow paths was rejected by the active PreToolUse hook with the enforcement-file denial. It produced no source findings. No alternate wrapper, copy, or tool was used to reroute that denied search. Current source-level verification remains incomplete; preserve both pushed candidates and both issue records.

## Provenance

The user supplied a terminal screenshot naming `/tmp/sdd-hook-review.rhDmpQ` after running the maintainer export. The agent read that directory successfully without executing its contents. `context.txt` records executor `jrmag`, timestamp `2026-09-05 09:02:53 UTC`, repository `/Users/jrmag/sdd-forge`, and local HEAD `bdfe69955e5acf8e27aae0b969272f9a3cfef3aa`. This is human-supplied export evidence, not agent-reproduced test evidence.

Both metadata files bind main to `bdfe69955e5acf8e27aae0b969272f9a3cfef3aa`:

| Branch | Head | Merge base |
|---|---|---|
| auto/improve-20260817 | f6e7427c9648085ca86a0d0835fa28df8e5ff300 | d17bc75e4ef7d08bcfe88775d1d2e302c51df772 |
| auto/improve-20260831 | 32a81f5ebe3b71d72ef274c7bc3776b6db12a70c | e00478321327b48e4e4ad21a14391d69e0f1baa9 |

Read-time SHA-256 values (hashes establish file identity, not execution authenticity):

| Supplied file | SHA-256 |
|---|---|
| context.txt | d6f6c3d1cf65efcb64f821008c0ae3941c0ded72e6449d9873121100e7e066a0 |
| improve-20260817-metadata.txt | 777aa32eba3dc62f9ae2aa9e21847a94b34f9fa03c7df3d59a774064a56e0999 |
| improve-20260817.patch | ba2db111328744becfb76b25c2954f6e3479fbf266f8a8a5092e9b4858927520 |
| improve-20260831-metadata.txt | f5ebc799427cbc233ac4c13a591c08ae347df3721df0879034c5410d88e51f71 |
| improve-20260831.patch | 01cc6ddefea60c866646da968572db67ab91e3b0f97aa41b6cde9828db1ada36 |
| local-uncommitted.patch | e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 |

## Exact-delta interpretation

Both patches change only the same four paths: Python and PowerShell guards under `plugins/sdd-quality-loop/scripts/`, `tests/guards.tests.sh`, and `tests/hooks.tests.ps1`. Their implementation hunks make the same semantic edit: `approval_increases` / `Test-ApprovalIncreases` use the existing count helper instead of a raw primary-approval regex match for shell commands. Comments and added regression assertions differ. Neither supplied patch changes the role-directory predicate, shared shell tokenizer, or JavaScript implementation.

This is a duplicate Second-Approval correction candidate, not two independent improvements. Preserve both branches; do not blindly merge or cherry-pick both. Keep this correction separate from the new role-shell grammar/policy workstream, while serializing edits and final-diff tests on their shared files. No existing issue, PR, approved task, or owner release is inferred from these patch contents.

## Review findings and limits

- Warning: the August 31 shell regression suppresses process failure with `|| true`, discards stderr and accepts a localized message substring. Its PowerShell assertion also checks only a substring without an exit-code assertion. Such checks do not establish the full deny decision contract.
- Warning: the August 17 assertions retain exit-code checks for copilot output and cover Node as well, but still use textual substring matching rather than validating the complete structured decision. Neither patch includes mixed primary-plus-secondary approval assertions in its added hunks; existing surrounding coverage has not been certified by this export review.
- Required validation: use the existing formal contract to assert the parsed decision, reason, proper emit-mode exit status, primary-only/secondary-only/mixed cases, and all supported runtimes. Do not execute payload text as shell code. These are review requirements, not new task approval or implemented tests.
- The empty local patch covers tracked modifications in this checkout's requested script/test paths only. It excludes untracked files, installed caches and other worktrees' dirty contents. The context lists other worktrees but does not establish that they are clean or relinquished.
- Merge-base-to-head exports identify branch-introduced hunks, not compatibility with the full current main tree. Recheck exact current heads, relevant main changes, owner/task evidence and final integrated diff before implementation or promotion. No conflict-free claim is made.

## Next step

### Existing-task reconciliation

The similarly named `second-approval-mask` feature does **not** authorize this hook correction. Its task's planned files are workflow-state normalization scripts/tests (`specs/second-approval-mask/tasks.md:33`), and its Out of Scope explicitly excludes the hook guard (`tasks.md:99`). Its requirements preserve the hook's existing second-approval denial (`specs/second-approval-mask/requirements.md:65`), rather than requesting a guard change. The cheap investigator's initial contrary conclusion was rejected after primary review; the investigator corrected it. No matching existing approved hook-classification task was established. Do not reopen its Done task or reuse its historical approval mark.

The missing-export blocker is resolved. Reconcile these candidates against existing Second-Approval task/review/PR records, then select one governed implementation unit. Continue formal specification of the separately accepted restricted role-shell grammar. Protected application/testing and all quality gates remain required. The user's follow-up explicitly requests continuation through main integration with low-cost delegation; it does not extend the earlier PR #386-only administrative exception to other PRs.
