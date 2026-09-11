# Hook boundary handoff review — 2026-09-05

Disposition: HOLD source adoption. This is a read-only intake review, not a passed SDD gate, task approval, or permission to modify enforcement controls.

Follow-up: the user requested adversarial remediation and full shell-analysis comparison. Independent Astra review returned NEEDS_WORK; see `hook-adversarial-review.md` and the proposed `hook-safety-integration-plan.md`. The findings are now integrated into mutable `task_plan.md`. No source/cache fix or formal gate PASS has occurred.

## Scope and authority

The repository owner authorized remaining consolidation work and preparing/application of protected-file changes. Runtime enforcement still denied agent-side protected work; that denial is not bypassed. A separate task handed over an already-modified installed cache and requested that SDD source work be owned here. Personal skills/playbooks are outside this scope. No cache or product file was changed during this intake.

The received package lives at `/Users/jrmag/Documents/Codex/2026-09-05/agents-md/`. Its `outputs/hook-fix.diff`, `work/test_hook_boundary.py` and `outputs/hook-boundary-tests.json` were read. The driver writes a PowerShell helper beside itself and writes its result file, so it was not rerun over the sender's artifacts.

## Verified identity

| Runtime | main source SHA-256 | installed cache SHA-256 |
|---|---|---|
| Python | `0202c8f32f8810d77ba438a965f6b57213fb907f1a3c724f318cda9fd7b19d90` | `da37e08d7341f58ee61bbd0aa146486be21a069b4435ccd449114eaf72363889` |
| JavaScript | `2acc80f9449755afab761aa758f1379dbe9a37cf44da6d85fd8c5d6b23d6fb70` | `f91aa098fff0842ddd595330944fc6a47fe03ad8abf599ae56e28491c0cb84a5` |
| PowerShell | `8a20021958d84e1ae7e5a239a2500dc73f15289158a68e905c90d3d5f317d7e1` | `3e76d3965fd2c9c3c503d25b3c5edb7e8760f2175008796ecfe1c3e2080b2971` |

All three source hashes match the sender's before hashes, and cache hashes match its after hashes. The Python source-to-cache diff independently matches the received hunk. Main remains `bdfe69955e5acf8e27aae0b969272f9a3cfef3aa`.

## Review findings

1. **Security review blocker — static finding, not runtime reproduced.** The new target prefilter at cache Python line 1719, JavaScript line 1218 and PowerShell line 268 recognizes a slash or a small set of following delimiters, but excludes substitution introducers immediately after the directory name. It returns non-target before the newly added metacharacter rejection can run. A shell expansion that supplies an empty suffix or a role-file suffix therefore needs an explicit fail-closed test. The old word-boundary prefilter recognized this boundary. Fix direction: preserve conservative handling of unresolved shell expansion while excluding the actual AGENTS.md sibling; do not merely move all commands into an unconditional allow path. Review all three runtime twins and full hook decisions, not only a standalone regex.
2. **Verification gap.** The sender reports 17 successful rows: 14 predicate cases across three runtimes, plus three malformed-role Write CLI cases. This is useful limited evidence, not 17 full end-to-end shell checks and not full plugin validation. Additional controls must include unambiguous reads, actual-role write/redirect denials, compound commands, unresolved boundary expansions, invalid Write/patch inputs, and parity of complete hook decisions. Read-only wrappers remain conservatively denied for actual role paths in the received patch.
3. **Execution limitation.** A new read-only Python predicate probe was denied by PreToolUse before execution because its test-input strings mention role writes. No result from that probe exists. It was not retried using encoding, another tool, an alternate writer, or a changed guard. No test command embedded in the probe was executed.

## Overlap and next governed step

Current GitHub inventory is 26 open Issues and 14 open PRs. Issue #387 / WFI-061 concerns the consent-token predicate, not the agent-role directory predicate. Issues #380 and #295 and the preserved `origin/auto/improve-20260831` / `origin/auto/improve-20260817` branches concern Second-Approval message classification in overlapping guard files. They must not be overwritten or assumed merged. Title/ref-name scanning is not proof of ownership clearance; complete branch-content reconciliation is still required before implementation.

The cheap read-only explorer did not establish a currently Approved task for this exact change. Existing coverage is located in `tests/guards.tests.sh:778`, `tests/hooks.tests.ps1:185`, and `tests/guard-parity.tests.sh:282`; existing historical success logs are not evidence for the new cache bytes. Source behavior is defined at `plugins/sdd-quality-loop/scripts/sdd-hook-guard.py:1714` and called at line 1903.

Next: resolve the static blocker and bind the exact source scope through the repository's approved task/review path; prepare reviewed human-apply artifacts where enforcement requires them; run full existing guard and cross-runtime regressions plus the missing boundary cases in an authorized environment. Do not silently update or revert the installed cache, claim PASS, or combine this work with PR #389.

## Separate PR #389 status

Candidate remains clean at `c5d3230714dd064b3e5a48ac79fb179f45ae3a76`. Latest observed CI snapshot: 18 successful jobs, 2 running, 4 queued, plus CodeRabbit success. Independent findings A-1/A-2/A-3 remain unapplied. The reviewed human handoff is in `docs/ci-staging/pr389-review-remediation/`; its prior hashes and review remain intact. No merge or branch cleanup occurred in this intake.
