# Issue #423 non-reserving batch-hash diagnostic (2026-10-07)

Status: **incomplete; no formal review, reservation, verdict, or permission proof**.

## Scope and pre-edit boundary

- Owner checkout: `/Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge`; HEAD `3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9`.
- Existing dirty work, frozen evidence and ledger were retained. Risk: high/protected launch-control behavior. The affected contract is exact Bash authorization plus ordered raw SHA-256 proof for invocation, every admitted input and the boundary file, shared by formal and diagnostic paths. No A7 checkout, installation, reservation, Git publication, global hook or permission setting was changed.
- This bounded edit changed only `plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py`, `plugins/sdd-review-loop/scripts/probe-nontty-review.py`, and `tests/quality-nontty-transport.tests.py`. This record is new and non-frozen.

## Batch change and regression

The former launch generated one `rtk proxy shasum -a 256 <path>` Bash call per file. The formal permission list, prompt, policy and transcript verifier now share one standard `shasum` command whose arguments are invocation, manifest entries in order, then boundary. The verifier requires every output path and raw digest in exactly that order, rejecting a missing, extra, reordered or mismatched line. The two receipt/control hash commands remain separately serialized. The probe uses the same batch construction and keeps its individual-hash proof count for caller parity. Historical non-strict spec prompt bytes remain covered by the regression.

- RED before implementation: `rtk proxy python3 tests/quality-nontty-transport.tests.py` failed in two cases (missing batch helper and old per-file permission).
- GREEN after implementation: same command, 13 tests passed. `rtk proxy git diff --check` passed. Local `rtk proxy shasum -a 256 <two paths>` produced ordered per-path output. This is focused local evidence, not CI or native success.
- Source invocation: `reports/verification/issue423-t002-probe-source-b49f1662-d455-4cd7-b5a8-0fab0199bce3.json`, SHA-256 `5c80f53d0a483d2159d6cbeaa215d6dc6b89d519089a11972e08764b77f9314f`, 101 source inputs. Canonical non-reserving `validate-review-context-set.sh` returned `REVIEW_CONTEXT_OK ... sequence=1201 ... identity_unique=yes` before native launch. The probe appends this source as a diagnostic input; its batch therefore covers 104 files including the new invocation and boundary.

## One native diagnostic and unresolved refusal

Exactly one new native probe was launched. Diagnostic session `f7039421-e7ef-4184-9b77-a4bd0c7b3bf3`; transcript `/Users/jrmag/.claude/projects/-Users-jrmag--codex-worktrees-issue423-approved-recovery-sdd-forge/f7039421-e7ef-4184-9b77-a4bd0c7b3bf3.jsonl`, SHA-256 `6cf014d5eafd9bd3cc0f02815a5035e68c09a5ce50f6e796d5fbf2b147f55fe7`. The 300-second subprocess limit expired; there is no live handle now. Observed 4 Bash uses and 38 Read uses, not a completed probe. The first Bash was refused by Fact-Forcing Gate; the identical retry returned a 104-line multi-file hash output. The next ordered-input control-hash Bash was refused in `dontAsk` mode with a permission message (not the pinned guard's out-of-scope denial). The record-text control hash succeeded, but the agent proceeded to Read despite the prior failed hash. Thus the transcript cannot establish complete ordered hash proof, admitted-read coverage, out-of-scope denial or collision rejection. Do not interpret the partial observations as PASS.

The exact cause of the second refusal is not established. `receipt_control` currently grants the `printf` producer and `rtk proxy shasum` separately, while the requested tool command is their full pipeline; that mismatch is a concrete suspect requiring a scoped repair and new negative regression, not permission bypass. No retry of this refusal and no second native launch occurred.

## Read/timeout contract distinction

The product boundary requires raw hash equality for **every** admitted input and forbids Read outside the admitted manifest (`plugins/sdd-review-loop/references/review-context-boundary.md:52-53,281-290`). It does not require the permission probe to execute a separate `Read` on every admitted file. That exhaustive `Read` loop is introduced by `probe-nontty-review.py:87,119-120,158-162,234`; `launch-impl-review.py:346-353` consumes its aggregate booleans and full hash count, not a per-file Read count. The probe's own `subprocess.run(... timeout=300)` at line 128 imposes the 300-second ceiling; this is diagnostic implementation, not a boundary-document limit. Neither the Read checks nor timeout has been changed pending an explicit decision. Formal review still must independently inspect required substantive inputs; reducing a diagnostic probe must never be treated as review completion.

Canonical ledger SHA-256 after this run: `17f5445b0c8c0bc2199daf93b3eed5316f4439b27ccc1f72eafb775350f4662d`, unchanged from pre-run. Formal reservation remains blocked by the observed control-hash refusal and incomplete native permission proof; independent diff review and applicable final-head CI are not yet established for this batch change.
