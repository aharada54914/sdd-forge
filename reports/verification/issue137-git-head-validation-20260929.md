# Issue 137: Git HEAD admission regression

Scope: the shared in-memory `validate` entry for T-001. This is not a task-completion or quality-gate verdict.

`ProjectionV1.head` was incorrectly passed to the SHA-256 digest validator (`plugins/sdd-context/validation.mjs`, pre-fix commit `1d4f7cd34bef139cc3f5d357db6a37ee0905524f`, line 121). A SHA-1 repository therefore rejected its valid 40-character object ID and admitted a 64-character ID with the wrong storage format.

The fix obtains the actual Git storage format after validating the worktree and Git directory, then accepts only the corresponding lowercase object-ID grammar. Unknown formats fail closed. Authority digests remain 64-character SHA-256 values; the existing one-second deadline and final path checks remain unchanged. No dependency or separate caller-specific workaround was added.

## Executed evidence

The same fixed test file was used before and after the production change. Execution environment: macOS, Node v24.13.0, Git 2.54.0.

| Execution | Result | Exit | Output SHA-256 |
|---|---|---|---|
| Before fix: `rtk proxy node --test tests/sdd-context/validation.test.mjs` | 35 passed, 2 failed, 0 skipped | 1 | `f1e5641f252e1c8fd86fe301fd55a84f174a1f8dc529664720b027da630ad613` |
| After fix: the same command | 37 passed, 0 failed, 0 skipped | 0 | `d175ae7c73006dc58e0a945f3ca9c380eb00fa17d12a2035adf08f666034e155` |
| After fix: `rtk proxy node --test tests/sdd-context/json-admission.test.mjs tests/sdd-context/privacy.test.mjs tests/sdd-context/privacy-grammar.test.mjs` | 31 passed, 0 failed, 0 skipped | 0 | `6e75a9f48e8720821b4d1df3500c23298b670939aed93fc4f1671e77c451d4e4` |

The two pre-fix failures were the real SHA-1 positive case and the wrong-format negative case. Tests also create real SHA-256 repositories. Both post-fix executions had empty stderr and unchanged admitted inputs; this correction used one implementation attempt, not repeated unchanged reruns.

Verified source SHA-256: `ff9f7b869ebc439efb809924a5ae19f42476d036824715a2faad990b232c2678`.
Fixed test SHA-256: `14a381d91b4776f99991b0047c33d7048ce577dc4b0226e6b0fc93e401219750`.

Independent Astra ordinary code review found 0 Critical, 0 Major and 0 Minor findings, and checked the source, test, snapshots and real output hashes. It was not a formal SDD gate and changed no verdict or lifecycle state.

## Remaining boundaries

These results do not establish persisted storage, native Windows permission checks, host integration, T-003 freshness, full T-001 completion, CI, merge or Issue resolution. Current call sites are the regression tests. Task approvals, frozen artifacts and historical evidence were preserved.
