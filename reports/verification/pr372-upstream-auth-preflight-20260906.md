# PR #372 upstream authentication preflight

Observed on 2026-09-06 JST. Read-only source inspection, not a quality-gate verdict.

- PR: https://github.com/aharada54914/sdd-forge/pull/372
- Observed head: `16bc4fa45b51cbf813a76882b0022ae0404dadeb`.
- Observed base: `e00478321327b48e4e4ad21a14391d69e0f1baa9`.
- GitHub state: OPEN / BEHIND. Old checks do not establish integration readiness against current main.
- Proposed upstream action commit: `1f291e1cfe0f5fc21db2aef19af844591600ade7`.

## GitHub authentication path verified by the primary agent

At that exact upstream commit, `action.yml` maps `inputs.github_token` to `OVERRIDE_GITHUB_TOKEN` in the Run Claude Code Action environment. `src/github/token.ts:158-165` returns a supplied override immediately. Without it, lines 167-178 request OIDC and exchange it for an app token; lines 56-65 explain the required `id-token: write` permission on that alternative path.

Local main's `.github/workflows/self-improvement.yml:125` explicitly supplies `secrets.SDD_SESSION_PR_TOKEN || secrets.GITHUB_TOKEN`. Therefore the inspected normal supplied-token path does not need the GitHub-app OIDC exchange. This is conditional source-level evidence, not proof of a successful authenticated workflow run.

The separate Anthropic federation inputs are optional in upstream `action.yml`; the local workflow supplies `claude_code_oauth_token` at line 118 and no federation inputs. The absence of federation alone would NOT prove the GitHub-app OIDC path is unreachable; the explicit token mapping above is the necessary additional evidence.

Sources were fetched through GitHub's contents API at the exact proposed commit, decoded and inspected without reading any credential values. The local permissions commentary at lines 39-54 still names the older pinned commit and a version label inconsistent with the current uses-line label. Reconcile that commentary through the applicable approved change workflow when refreshing the PR; do not present it as current upstream verification.

## Remaining integration conditions

Recheck the current main baseline and applicable task/review gates, refresh the existing PR branch, inspect the final diff, and run all required checks on the resulting exact head. Preserve the no-OIDC-permission design and separately assess any changed execution or installation behavior. No branch update, permission change, workflow dispatch, merge, or issue closure was performed by this preflight.
