# A8 post-apply verification and attempt 9 round 2 A interruption (2026-10-05)

This is a non-frozen operational record, not an implementation-review verdict. Owner checkout: `/Users/jrmag/.codex/worktrees/a8-release-sync-oct01/sdd-forge`; HEAD at verification: `495c88d67af44530687ecea3ce9fb0a90a336539`. Existing unrelated dirty state was preserved. The old attempt 9 round 1 BLOCKED evidence remains unchanged.

## Human application readback

The four post-apply SHA256 values matched the approved v3 human-apply helper's expected values:

| Path | SHA256 |
|---|---|
| `plugins/sdd-review-loop/scripts/impl-review-precheck.sh` | `8a9a8833b9acae777276fe67dd00b8b74a60890146674aaef57134714d2a136a` |
| `plugins/sdd-review-loop/scripts/impl-review-precheck.ps1` | `6d066329e1675c77c06e780a842400514ec7d0d788b04cdeb8e854fff9c00cba` |
| `plugins/sdd-quality-loop/scripts/check-workflow-state.sh` | `f621d2e2f2a468fadf378d28b398c7ff3f531847d0ec39c1ce9af6fd60b4b647` |
| `plugins/sdd-quality-loop/scripts/check-workflow-state.ps1` | `7f189e25938644825f7f24295a91b99f06ba8d41c2216814af351b6bf3342993` |

Commands in the owner checkout, via `rtk proxy`, with shell `login=false`:

- `bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh epic-196-a8-integration 9 2 --provenance-rereview`: exit 0; `workflow-state: ok`, `workflow-state: impl-history: ok`; persisted the round-2 `precheck-result.json` (design SHA `c2a30f22f833f9a30ffeff01960d7f5304af262ba9ab4f0b9aad67f75b604cca`).
- `bash tests/impl-review-adr-inputs.tests.sh --generation-only`: exit 0; `ADR generation: passed=30 failed=0`.
- `bash plugins/sdd-quality-loop/scripts/check-workflow-state.sh --feature epic-196-a8-integration --impl-history 9:1`: exit 0; `workflow-state: impl-history: ok`. The PowerShell twin also exited 0 with the same status.
- `bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh epic-196-a8-integration 9 2 --verify-inputs`: exit 0; `impl-review-precheck: inputs verified for reviewer invocation.`

An attempted in-memory adapted v3 candidate regression runner was denied by PreToolUse *before execution*: `SDD決定論ゲート: エージェントはゲートスクリプト・フック設定・テストファイルを書き換えられません。これらのファイルは強制チェーンの一部です。sudo でもバイパスできません。 [EN] SDD deterministic gate: agents must not modify gate scripts, hook configuration, or critical test files. These are part of the enforcement chain and cannot be bypassed by sudo.` It was not rerun through another executor. The earlier candidate-patch 92/92 is not a post-apply test run.

## Reservation and A dispatch

The A8 canonical ledger was device `16777232`, inode `251623623`, separate from A7's device `16777232`, inode `251557887`. Before reservation its tip was sequence 1205, record SHA `309aff762e5abc5829cd413935f064b4c607be935c510815a88fdf7def940e69`. The role-A one-role manifest is `reports/impl-review/epic-196-a8-integration/attempt-9/round-2/review-context-impl-reviewer-a.json`. Its non-reserving validation exited 0; the immediate `--verify-inputs` exited 0; then the same validator with `--reserve` exited 0 and returned:

```text
REVIEW_CONTEXT_OK fd74af8909cc49d951b35a41a1e711de976d7df0e16e9a830979fa6e67766c03 sequence=1206 previous_record_sha256=309aff762e5abc5829cd413935f064b4c607be935c510815a88fdf7def940e69 pre_append_tip_sequence=1205 identity_unique=yes
```

The ledger tip readback is sequence 1206, record SHA `fd74af8909cc49d951b35a41a1e711de976d7df0e16e9a830979fa6e67766c03`, run ID `RUN-epic196-impl-a9r2-a-ba101901`, session `ba101901-0e4c-4400-be4d-beddb6537f16`. Do not reserve this identity again.

The fresh Sonnet A delivery used the checkout's installed-equivalent `sdd-review-loop:impl-reviewer-a` role, hooks enabled. The shell command was `rtk proxy claude -p --plugin-dir ./plugins/sdd-review-loop --agent sdd-review-loop:impl-reviewer-a --model sonnet --effort medium --permission-mode dontAsk --permission-prompts none --tools Read,Grep,Glob,Bash --allowedTools Read,Grep,Glob,Bash --output-format json --no-session-persistence '<review prompt>'`. The prompt identified the feature, attempt 9, round 2, absolute repository root, precheck and manifest paths, the exact receipt above, and required receipt/input hash verification, self-reading of admitted inputs, no ledger/raw reviewer reads, no post-reservation validator call, no file writes, and canonical JSON return. CLI exit 0, elapsed API 156160 ms, session `716ccf32-79f6-476f-92c1-11df03127bec`, model `claude-sonnet-5-5`. No output file was written.

The transport result contained `permission_denials` for one Bash request. Its denied command was a compound `jq` manifest loop with `shasum -a 256` over inputs; a `printf | shasum` receipt computation; and `grep -c 'x' /dev/null; shasum -a 256 specs/epic-196-a8-integration/design.md`. The exact denial authority (CLI permission rule versus hook) is **not established** by the transport field because this invocation had no debug file or persisted tool trace. The requested `/dev/null` read is outside the admitted input list, and the compound shell command exceeds the role's narrow read-only-command wording; neither should be relabelled a successful authorized check. The existing prior task-stage launch diagnostic documents the same ambiguity for `permission_denials` in this environment.

The returned text claimed 13 matching hashes and a matching receipt, and proposed a `NEEDS_WORK` JSON with one DATA-COVERAGE Major. It also explicitly said it had **not read** `ux-spec.md`, `frontend-spec.md`, or `infra-spec.md`. Those are mandatory admitted inputs. This violates the reviewer's self-read contract, so the proposed JSON is **not a formal finding or verdict**. It was not persisted as `reviewer-a.json`; no integrated summary, reviewer B launch, or merged verdict followed. Sequence 1206 is consumed, not reusable. The candidate semantic allegation may be inspected in a later independent formal review but is not promoted here.

## Static diagnosis and next bounded action

The launch granted the built-in `Read`, `Grep`, `Glob`, and `Bash` tools; local Claude settings also include `Bash(jq *)`, `Bash(printf *)`, `Bash(grep *)`, and `Bash(cut *)`, but the compound command contains assignments, a loop, a pipeline, and an unadmitted `/dev/null` read. Without hook stderr/tool trace, no exact denial layer can be assigned. Independently of that denial, the conclusive missing step is the reviewer's own complete reading of three required layer files; their hashes in the manifest do not substitute for reading their contents. The correct repair is a **new** unique reservation (never seq1206) after unchanged-input verification, a fresh A session with an explicit full-input read checklist and narrow read-only hash commands that each touch admitted paths only, retaining all hooks and receipt-chain verification. Capture debug/tool evidence and reject output if any required read or calculation is unproven. A successful A is prerequisite to counts-only summary and separate fresh B. No protected script or hook change is authorized by this diagnostic, and A7's checkout/ledger remains untouched.

The v3 protected precheck/workflow-state repair has application readback and limited regression evidence, but its own post-apply candidate runner was refused. It is not independently/formally verified, not CI-proven, not merged, and not Done. Round-2 A/B formal review is likewise not completed.
