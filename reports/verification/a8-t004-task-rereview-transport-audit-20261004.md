# A8 T-004 task provenance re-review — local-only transport audit (2026-10-04)

## Attempt 5 completion addendum

Attempt 5 round 1 now has independently produced A and B outputs and a persisted
integrated PASS. B retry 3 used actual Claude session
`f782c743-cf5d-47b9-8bca-ce11c6bd1536`, run
`RUN-epic-196-a8-integration-task-a5r1-b-retry3-1791113814`, and ledger sequence
1201, record `089950e974d62ab38c6dc1721da0ee5ead190d6b408e3711c6e0868f65975dff`.
The original stream remains `/tmp/a8-task-a5r1-b-retry3-20261004.stream.jsonl`.
All 14 admitted documents were read; 13 raw digests and the normalized task
digest matched. The first exact receipt command received an ECC fact-forcing
denial; the identical command subsequently succeeded after facts and input
inspection. No permissions were broadened, no out-of-manifest input was read,
and no rejected SDD write was rerouted. Earlier non-adopted reservations remain
unchanged. B returned eight PASS, one SKIP, and no findings.

The sole final JSON was preserved as reviewer-b.json without changing its
verdict. The integrated-verdict.json and task-review-contract.json bind the
current precheck and independent identities. Bash and PowerShell
`check-workflow-state --feature epic-196-a8-integration` both exited 0 after
persistence. The initial PowerShell invocation with `-Feature` was a CLI usage
error; the documented `--feature` invocation succeeded. These results establish
task-stage provenance only, not implementation quality, native activation,
cross-model consensus, CI, merge, or Done.

Status: local-only audit. The initial identity question below was resolved under the task-review contract in the addendum; attempt-4/round-1 integrated artifacts now exist and both workflow-state implementations pass. No quality-gate was run, and T-004 was not set Done. Do not publish this report or characterize the logical identifiers as Claude-issued UUIDs.

## Contract and identity

The task-review-loop skill requires a fresh independent agent, immediate `--verify-inputs` precheck, a one-role `review-context-invocation/v2` manifest, and a successful validator `--reserve` before each launch. Its reviewer roles say the orchestrator provides a fresh run ID and distinct nonblank host-session ID. The task skill, roles, and `review-context-boundary.md` do not explicitly require a host-issued allocation receipt or equality with Claude's actual runtime UUID; equally, that absence does not prove that caller-generated logical IDs are acceptable as host-session identities. The two namespaces below are intentionally reported separately.

| Role | Ledger sequence / record SHA-256 | Reserved run / logical host-session ID | Actual Claude UUID |
| --- | --- | --- | --- |
| A | 1193 / `345d8c19a0f70015a9e1680abb0708d54c62437d78a8a3cb8f386cb98cc37ea7` | `RUN-epic-196-a8-integration-task-a4r1-a-1791042775` / `SESS-epic-196-a8-integration-task-a4r1-a-1791042775` | `98bb8087-17af-4a58-a1bb-75ff11e42161` |
| B | 1194 / `b113ba90c9b3ec08750caa6312f47e8c65296ff4f2f9d4bb0a6e3a5625b3f7b4` | `RUN-epic-196-a8-integration-task-a4r1-b-1791043309` / `SESS-epic-196-a8-integration-task-a4r1-b-1791043309` | `c6eadd50-43b3-43de-9d2e-f7ce9d8a37b3` |

Both immediate `task-review-precheck.sh ... --verify-inputs` calls exited 0. Both `validate-review-context-set.sh ... --reserve` calls returned `REVIEW_CONTEXT_OK` with `identity_unique=yes`; A extends previous record `b7730e623de8d1932e17000b5d7e83cbfcc5504407e1a78c3a67d4675a3dbbbc`, B extends A's record. The persisted invocation manifests are `reports/review-context/epic-196-a8-integration-task-a4r1-a-retry4-invocation.json` and `reports/review-context/epic-196-a8-integration-task-a4r1-b-retry1-invocation.json`. These receipts validate ledger continuity and uniqueness, not host issuance of the logical IDs.

## Output and input preservation

The role/skill output contracts require canonical JSON, but contain no raw-only transport rule forbidding extraction of the sole fenced JSON object. Each original reviewer message is preserved, and the fenced body was copied without changing its content; this is transport normalization, not a new verdict. B's complete original message was recovered from the same run's Stop-hook `last_assistant_message` after the terminal display truncated the large CLI wrapper. Exact comparison of the saved raw text to that hook payload and of the extracted body to its only JSON fence passed.

| Role | Original message SHA-256 | Extracted JSON SHA-256 | JSON checks | Inputs |
| --- | --- | --- | --- | --- |
| A | `f7ca87dd548a5ab5b5a7d9dde40ab085317a93533a42289c0275e0d90f574c63` (`reviewer-a-retry4-raw-output.md`) | `5854e0ce74d26b94137073dea873eb961a095dca2b3ce016fc918281102f5e40` (`reviewer-a.json`) | 14 PASS, 0 findings | 12/12 allowed path+hash pairs, order-independent exact match |
| B | `3e250be76ca6deef41a870cba0b3d8029733e6ecc899c2fc4ff8b29178806994` (`reviewer-b-retry1-raw-output.md`) | `0951f105c2952fc3cf844cc8e3317d67bf2a32a502a0b00b3302e35d4e839ab2` (`reviewer-b.json`) | 8 PASS, 1 SKIP, 0 findings | 14/14 allowed path+hash pairs, exact match |

All paths in the table's output column are under `reports/task-review/epic-196-a8-integration/attempt-4/round-1/`. A's normalized `tasks.md` digest matched the precheck-bound manifest; B's did likewise. Remaining raw input hashes were checked at reservation and by the reviewers' requested `shasum` command. The JSON bodies contain no terminal absolute paths or email addresses.

## Effective tool trace

The unchanged Claude hooks/sandbox were active. A's debug trace `/tmp/a8-task-a4r1-reviewer-a-retry4-20261004.log` shows only `Read` of its 12 manifest paths and two unique Bash commands: the sequence-1193 record-hash `printf ... | shasum -a 256` receipt and `shasum -a 256` over its 11 raw-hash inputs. A's first receipt attempt was blocked by the normal ECC fact-forcing hook; after stating the facts, it retried the same command successfully. B's trace `/tmp/a8-task-a4r1-reviewer-b-retry1-20261004.log` shows only `Read` of its 14 manifest paths and the analogous two specified Bash commands for sequence 1194 and its 13 raw-hash inputs. Neither trace shows a write tool, an out-of-manifest Read, or an extra Bash command. No rejected operation was rerouted through another executor.

## Initial adoption hold (superseded by the addendum)

The reserved `host_session_id` values were caller-created logical identifiers and are not the actual Claude UUIDs. The task-stage text does not explicitly settle whether this is permitted; it must not be silently equated to a host-issued or actual-runtime identity. Therefore the reviewer content and trace are preserved for audit, but this report deliberately does not synthesize an official task-review verdict or assert that the formal provenance re-review has passed. Resolve the identity-contract interpretation through the governing workflow before any integration, then run downstream state validation and the separate independent quality gate as required.

## Integration decision and validation addendum

The task-review-loop's actual launch contract requires a fresh isolated reviewer, immediate input re-verification, a one-role v2 invocation, and `REVIEW_CONTEXT_OK` reservation before launch (`plugins/sdd-review-loop/skills/task-review-loop/SKILL.md`, steps 1-4). Its reviewer roles say the orchestrator supplies a fresh run ID and a distinct nonblank host-session ID (`plugins/sdd-review-loop/agents/task-reviewer-a.md`, Inputs; reviewer B likewise). Step 5 requires distinct nonblank reviewer IDs and complete hash-verified manifests. Unlike the specification-review lane, these task-stage texts do not require a separate host-issued allocation receipt or equality of the reserved logical `host_session_id` with Claude's runtime UUID. The existing reservation receipts, independent CLI invocations, and runtime traces establish the one-to-one mapping in the table above; they do **not** establish that the logical values were issued by Claude. The actual trace shows no identity replay, out-of-manifest Read, or extra command. On that bounded interpretation, both existing reviewer results are adoptable under the task-review contract without new reservations or reviewer reruns.

The orchestrator copied the original A/B run IDs, logical host-session IDs, and canonical manifest path/hash pairs into `attempt-4/round-1/task-review-contract.json` without changing either reviewer output. It created `integrated-verdict.json` and the contract as `PASS`/clean from A's 14 PASS and B's 8 PASS, 1 SKIP, zero findings. B's T-005 TASK-SIZE observation remains a TYPE-H advisory against task-plan content bound by the prior persisted PASS; the only task-plan change relative to that binding is T-004's lifecycle status. The orchestrator's fresh integration ID is distinct from both reserved reviewer run IDs; it is not represented as a reserved reviewer or actual Claude session ID.

Validation on 2026-10-04 JST: standalone `task-review-precheck.sh epic-196-a8-integration 4 1 --verify-inputs` exited 0; JSON schema/count checks and exact (order-independent) A/B manifest plus reserved-ID comparisons exited 0; `check-workflow-state.sh --feature epic-196-a8-integration` and `check-workflow-state.ps1 --feature epic-196-a8-integration` each exited 0 with `workflow-state: ok`. Both validators reported only the accepted spec-stage `investigation.md` amendment-record growth notice. This is task provenance re-review completion, not independent quality-gate PASS or T-004 Done.

## Attempt 5 round 1 transport status (2026-10-04)

Following the prospective T-004 Cross-Model amendment, attempt 5 round 1 is a new provenance re-review, not a reuse of attempt 4. Earlier attempt-5 A launches at ledger sequences 1195 and 1196 remain non-adopted with their original raw evidence. The corrected independent A launch at sequence 1197, record SHA-256 `a0341449b8d8fc8109d55fe966e48e959d0e75b8d00b42ef01c5a59430173d3f`, used actual Claude session UUID `7dfa619e-4042-49e2-a125-cc384c91e261`. Its sole fenced canonical JSON body is preserved unchanged in `reports/task-review/epic-196-a8-integration/attempt-5/round-1/reviewer-a.json`; 14 checks PASS, zero findings. Its original CLI wrapper remains `/tmp/a8-task-a5r1-reviewer-a-retry2-20261004.raw.json` (SHA-256 `15cb1793b09f3d010c8b704b2eee991b6b3f6e2d4305931505a6b86619e8d371`). The initial exact hash command received an ECC fact-forcing denial, then the same command succeeded after facts were supplied; no out-of-manifest read or extra command occurred.

Independent B was reserved once at sequence 1198, record SHA-256 `5ba486a148740e5bea71e6b6a754b2fbd95b10941310b4e78e3d2918f88581b3`, run `RUN-epic-196-a8-integration-task-a5r1-b-1791047885`, and actual Claude session UUID `b5412181-ea09-490f-b640-874fd6a186de`. The immediate `--verify-inputs` precheck exited 0. Original CLI wrapper `/tmp/a8-task-a5r1-reviewer-b-20261004.raw.json` has SHA-256 `90574333d6250d3593661b42ea05b6bfa31623a99d19e7fd786a1f8cfc4f02ab`; debug log `/tmp/a8-task-a5r1-reviewer-b-20261004.debug.log` has SHA-256 `2773e410483c02a864f278c82612b44f067c08c5d5320ae0d36fb0c9dc552129`. The response says PASS with eight PASS, one SKIP, and zero findings, but is **not adopted**: the actual tool trace ran a combined receipt pipeline (`printf ... | rtk proxy sha256sum`) outside the launch's component-by-component exact-command instruction, and the reviewer read only a subset of the manifest's substantive documents despite its role's read-yourself requirement. The first exact raw-hash command's ECC fact-forcing denial was followed by an identical successful retry; the receipt pipeline itself executed successfully but was still outside the agreed launch contract. No `reviewer-b.json`, integrated verdict, or task-review contract was created from this output. A/B integration, quality-gate PASS, and T-004 Done remain unclaimed.

### B retry 1 permission stop and unused reservation

B retry 1 had a new invocation at ledger sequence 1199 (receipt SHA-256 `bf99714904b2b1558dc78a1659d520fea23a748f1805b483d33787a036d73a62`), run `RUN-epic-196-a8-integration-task-a5r1-b-retry1-1791048477`, and actual Claude session UUID `96b280be-9335-45d7-b575-fd395cf90d83`. Immediate input verification and reservation both exited 0. The trace in `/tmp/a8-task-a5r1-reviewer-b-retry1-20261004.debug.log` (SHA-256 `10d8c49ba82d8baf70f794232227fff05afd60d41c1c4d46ad2942f24b94749e`) shows actual Read calls for all 14 inputs. Its raw wrapper `/tmp/a8-task-a5r1-reviewer-b-retry1-20261004.raw.json` has SHA-256 `6bb49c17d52a54bc029d3aaa77cb4164d5751428d4a31e7800ad6a090e2b11ed`. The exact raw-input hash received an ECC fact-forcing denial and then succeeded after facts were supplied. The exact receipt pipeline `printf '%s' '<receipt>' | rtk proxy sha256sum` was denied twice with `Permission to use Bash has been denied because Claude Code is running in don't ask mode`. This was a real Claude CLI execution-permission refusal, not an SDD hook rejection. The reviewer reported it could not verify the receipt and produced no canonical JSON. Therefore B retry 1 is **not adopted**; no component-command reformulation or alternate executor is used to get around the denial.

Before the permission boundary was classified, B retry 2 was reserved at ledger sequence 1200 with receipt SHA-256 `c0513c67d2106561d2e7183e2ed4c85a092f3718cac4ec27ab067eafcd576489`, run `RUN-epic-196-a8-integration-task-a5r1-b-retry2-1791048729`, and reserved session `6ff70f23-db6d-4697-9b3e-81ad86fe14f7`. Its invocation is `reports/review-context/epic-196-a8-integration-task-a5r1-b-retry2-invocation.json`. **No reviewer process was launched for this reservation**. Preserve it as consumed/unused ledger history; do not reuse it or claim a review result. The installed `claude --help` documents `--allowedTools` for named tool permissions and `--permission-prompts host` for host-managed permission requests; the launch's `--permission-mode dontAsk` denied the receipt command. Any future B launch requires an authorized host permission decision/configuration for that exact command, then a fresh compliant identity and reservation; broad Bash permission, bypass mode, hook changes, or re-expression of the denied operation are not inferred here. Formal B and integration remain pending.
