# A8 T-004 cross-model contract amendment proposal (local, not applied)

Status: proposal only. This is not a task-plan amendment, task-review verdict, cross-model result, quality-gate result, or Done decision. No panelist was invoked.

## Conflict

- `specs/epic-196-a8-integration/tasks.md` T-004 states `Security-Sensitive: true` and `Cross-Model: not enabled`. Its risk rationale identifies the existing three-OS hook deny/allow regression suite as a security-relevant CI asset whose regression could silently remove automated guard coverage (lines 681-702).
- `plugins/sdd-ship/skills/ship/SKILL.md` Step 4 requires same-invocation cross-model verification before quality-gate for `Security-Sensitive: true`; without a completed run or valid human-gated waiver it stops before quality-gate (lines 296-322).
- `plugins/sdd-quality-loop/skills/cross-model-verify/SKILL.md` requires `Cross-Model: enabled` or a valid SDD_SUDO token, and its bundle preparation fails closed otherwise (lines 15-22, 86-89). No waiver is proposed.

## Minimal proposed task-plan content change

```diff
@@ T-004, currently line 702 @@
-Cross-Model: not enabled
+Cross-Model: enabled
```

Keep `Security-Sensitive: true`, `Risk: high`, all Done When criteria, and the existing approval/status semantics. Do not use a waiver or represent the existing task-review PASS as binding this changed line.

The same one-line change is saved as `reports/verification/a8-t004-cross-model-enable-candidate.patch`, SHA-256 `161d7a8786b438c8fdbdc53fe2784e62693579ee54c24d222a63c3ca3d822e3a`. `git apply --check` against this owner checkout exited 0; the patch was not applied.

The task plan is hash-frozen after task review (AGENTS.md lines 46-59). The current attempt-4 round-1 `task-review-contract.json` binds normalized `tasks_sha256=842ee61b70f024da515f9018b15a3120e37ae62efa604a980f736645738b184e`. A read-only stream calculation using the task-review precheck's status-normalization recipe reproduced that current digest. Applying **only the proposed line change in the stream**, without writing the task plan, produces prospective normalized SHA-256 `0d2e433cc013f886c70b854458dd0d36106d306521b0cfe1d5b26b3f5e1a05e6`; prospective raw SHA-256 is `8c17b0f6b2fa299d23ce6e892a8e80a841ac4ab68d613c84d6c36fe09bbcde66`. These are candidate digests, not persisted review bindings.

The user's existing approval of additional bounded corrections and reviews is treated as authorization to prepare this prospective amendment, without fabricating an `Approval:` field, waiver, or review verdict. The post-implementation provenance re-review route itself does not license frozen-content changes (`task-review-loop/SKILL.md` lines 307-310). Before any task-plan edit, the orchestrator must establish the sanctioned reopening/normal-review route for this specifically authorized one-line content change; a new independent review must bind its resulting hash. Then re-run workflow-state validation before cross-model verification and quality-gate. Do not reuse attempt-4 PASS as proof of the proposed bytes.

## Existing staged-amendment route and current stop

`plugins/sdd-quality-loop/scripts/check-criterion-freeze.py` explicitly permits a frozen task-criterion change only as a **specs-only commit**, separate from implementation; a mixed code/criterion commit is rejected (lines 1-18). The shared reviewer calibration recognizes a human-approved post-implementation task amendment as reviewable, but only when `investigation.md`'s `## Amendment Re-Review Context` records full amendment commit hash(es), amended-document SHA-256, a verbatim dated human-approval quotation, and hash/commit references for later-phase artifacts (`plugins/sdd-review-loop/references/reviewer-calibration.md` lines 124-149; `spec-review-calibration.md` lines 76-106). This A8 feature already has that section for earlier amendments (`investigation.md` lines 109 onward), but it does not cite the proposed T-004 change.

Minimum continuation under existing contracts: preserve earlier review attempts; apply only the checked one-line patch through the normal guarded file edit; make a **separate specs-only commit only when commit authorization exists**; append the exact new amendment provenance and the user's actual dated verbatim approval to the existing investigation section; then run a new attempt of independent task A/B review with complete manifests and fresh reservations. Because tasks already have Approved/Implementation Complete states, do not use the ordinary `--reset` path that sets `Task-Review-Status: Pending`: `check-workflow-state.sh` rejects Pending with approved or advanced task states (lines 1895-1907). Use the post-implementation precheck's lifecycle-validity route, while judging the changed `Cross-Model` line freshly rather than invoking the TYPE-H unchanged-content convergence rule. Re-run workflow-state validation after a fresh PASS. No reviewer may regard this proposal as an existing PASS.

This owner session has no authorization to commit, and the amendment-context evidence bar cannot be met with an uncommitted candidate or a paraphrased approval. Therefore the frozen task file, amendment-context section, and review identities remain untouched. This is a documented stop, not a failed hook that may be retried by another executor.

## Non-Gemini panel feasibility (not executed)

The cross-model skill accepts one Anthropic plus one non-Anthropic vendor (`SKILL.md` line 170). Its policy explicitly gives Anthropic + OpenAI as a conforming two-vendor example (`references/cross-model-verification-policy.md` lines 127-134), and the deterministic gate tests `vendors_distinct >= 2` and `non_anthropic_count >= 1` without a Google-specific slot (`scripts/check-cross-model.sh` lines 135-155). Claude Code 2.1.278 and Codex CLI 0.160.0 answer `--version` on the current host; Gemini does not resolve on PATH. Claude + OpenAI/GPT is therefore a possible non-Gemini composition, conditional on model-run authentication, sanitized-bundle readiness, independent blind execution, and deterministic gate checks. No model or runner was launched and no vendor verdict was produced for this proposal.
