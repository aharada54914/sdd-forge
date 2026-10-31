# A8 PR #513 / T-004 current-state audit (2026-10-04)

Read-only status audit plus existing local checks. This is a non-frozen verification note, not a reviewer verdict, quality-gate result, merge decision, or task-status change. No reservation, formal reviewer, panelist, commit, push, or merge was initiated here.

## Current GitHub and owner state

- GitHub `gh pr view 513` reports current PR head `ac97422d6e347f4899a32d16fa9ceddc51b10416`, OPEN/DRAFT, `REVIEW_REQUIRED`, and `BEHIND`. Its displayed check rollup has 38 SUCCESS results, including `required-checks` from run 37162860278; no current-head CI failure was observed. The PR's displayed base SHA is `3a1afcab243fcebb769dc4314599999af4545050`, while a separate live main-branch API query returned `164767d998240b33f8622849729fb46f55e0a3d3`. A green older merge ref is not current-main integration proof.
- Owner checkout HEAD is detached at `495c88d67af44530687ecea3ce9fb0a90a336539`, with pre-existing tracked and untracked provenance/contract work. It differs from PR head; preserve and reconcile both sides before publishing. `git diff ac97422d6e347f4899a32d16fa9ceddc51b10416 -- tests/cli-hook-enforcement.ps1` was empty, so the T-004 test file itself matches the PR head.
- T-004 is `Status: Implementation Complete` and `Cross-Model: enabled` in `specs/epic-196-a8-integration/tasks.md`. The persisted task provenance re-review at attempt 5 round 1 has an integrated `PASS`. Neither makes T-004 Done.

## Checks rerun in this audit

All commands ran in the owner checkout through `rtk proxy` with shell `login=false`.

| Check | Observed result |
|---|---|
| `bash plugins/sdd-quality-loop/scripts/check-workflow-state.sh --feature epic-196-a8-integration` | exit 0, `workflow-state: ok`; only tolerated investigation amendment-growth notices |
| `pwsh -NoProfile -ExecutionPolicy Bypass -File tests/cli-hook-enforcement.ps1` | exit 0, 17 passed / 0 failed, including all three synthetic TEST-012 cases and TEST-017 continuity |
| `sh plugins/sdd-quality-loop/scripts/check-contract.sh specs/epic-196-a8-integration/verification/T-004.contract.json .` | exit 1: `cross-model-verification` remains `passes=false` |

The PowerShell result is a synthetic direct-invocation regression, not live native-host activation. Existing `verification/T-004/current-ci-20261004.md` records three-OS PR CI logs; this audit did not rerun the three-OS jobs.

## Cross-model and quality-gate boundary

The current task setting and cross-model skill permit Anthropic plus one non-Anthropic vendor; the deterministic checker requires at least two distinct vendors and one non-Anthropic vendor, not Gemini specifically (`cross-model-verify/SKILL.md` lines 17-21, 172; `check-cross-model.sh` lines 135-155). The repository policy gives Anthropic + OpenAI as a conforming example. Thus the Gemini prohibition does not itself block this task.

Existing `T-004.panelist-anthropic.verdict.json` and `T-004.panelist-openai.verdict.json` both report blind PASS on the same input digest `3dc43bd2241d3e746a9cacdb6de3dcdb331f8d9b507b95c3d294cf1c9cfb181a`; the former preserves four Minor findings and the latter zero findings. `verification/panel-collection-T004-20261004/collection-note.md` records actual Claude Sonnet and Codex CLI collection and explicitly says no primary evaluator was supplied. No `T-004.cross-model.json` aggregate or feature-specific T-004 quality-gate report is present. Collection integrity is not consensus or primary quality verification.

The applied recovery-contract regressions and fresh implementation observations are recorded in `verification/T-004/recovery-validation-20261004/readiness.md` and `verification/T-004/recovery-fresh-20261004/observations.md`. The latter stops before a new noncanonical recovery implementation report and task-input manifest. The next authorized boundary is to finish that fresh, hash-pinned implementation provenance; independently verify historical/archive and new report bytes; then have the owner conduct a new formal evaluator reservation and read-only evaluation. Only after the primary result exists can the existing two panel verdicts be checked for aggregate consensus, the contract/evidence bundle be completed, and a Done decision be considered. PR branch reconciliation, current-main CI, review, merge, and post-merge checks remain separate downstream work.
