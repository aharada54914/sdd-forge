# Issue 678: independently controlled CI signing setup

This is a prepared signing route, **not an activated signer or proof of independent key custody**. It uses the existing HMAC issuer and validator, without changing ADR-0019. The workflow can only bootstrap the exact approved Phase-1 candidate from commit `555bfb5f15265f622a353a946e3fd6b04ab575de`; it cannot sign arbitrary inputs, approve promotion, or publish live files.

The owner has already authorized T-001, the registry, the candidate, and completion of the operational work. The remaining prerequisite is independent key/configuration custody. The development-session integration currently receives HTTP 403 from Actions Secrets and branch-protection APIs; the repository had no environments at inspection. No secret has been created by this change, and this workflow has not been successfully dispatched against a configured environment.

## One-time owner-controlled setup

1. Independently review the `context-approval.yml` workflow and `.github/scripts/check-context-signing-environment.py`, including the pinned issuer commit and candidate SHA. Restrict changes to this signing route through repository review controls. A protected environment alone does not prove that the executing code is safe.
2. In repository **Settings → Environments**, create `context-approval` and require the actual owner `aharada54914` as its sole reviewer. Disable administrator bypass. Select custom deployment branches and add exactly one **branch** rule named `main`, with no wildcard or tag rules.
3. For single-owner operation, leave **Prevent self-review** disabled. GitHub may attribute both the development integration's dispatch and the owner's actual review to the same account. This setup does not claim two-person identity separation. The agent must not approve the deployment; the owner must actually inspect and approve the pending environment job. Alternatively enable self-review prevention when a distinct app/bot dispatch identity is available.
4. Generate a fresh signing key in an owner-controlled terminal or secret manager outside the development agent's environment. Store it as the `SDD_CONTEXT_KEY` **environment secret** for `context-approval`. Do not reuse the agent-accessible delegated key from PR #681, paste the key into chat, or store it as a repository/org secret. Retain the key under independent custody for future validation/reissuance. GitHub masking is not the security boundary.

The development agent's credential must not be able to approve the protected deployment or change its protection. When an integration acts as the owner, a required-reviewer setting alone does not distinguish the agent from the person. Use an independently controlled approval route and restrict agent credentials accordingly; the owner can dispatch/review with private credentials while the agent only reads Actions results. This workflow cannot establish that credential separation from API metadata. Do not claim agent-inaccessible custody until it is actually configured.

The API guard verifies the environment/reviewer/deployment configuration and fails closed on unavailable metadata. It cannot inspect a secret's value or prove where a secret was generated. Environment secret placement and independent custody must be established by the owner. A green configuration check alone is insufficient evidence of those facts.

## Run the prepared route

After merging the reviewed workflow, dispatch **Issue 678 Context bootstrap signature** on `main` through Actions or:

```sh
gh workflow run context-approval.yml --repo aharada54914/sdd-forge --ref main
```

The first job has no signing secret. It checks the exact repository, event/ref, required owner reviewer, no admin bypass, exact-main deployment rule, and absence of all three live Context files (content, approval and approved anchor). It requests read-only `contents` and `actions` permissions. If GitHub does not expose environment metadata to that workflow token, the route stops; do not bypass the check or supply a broad token to an unreviewed workflow.

The `sign` job then waits for the real owner's environment review. Before approving, inspect that run's workflow revision and pinned candidate. It rechecks configuration and bootstrap status, checks out the immutable reviewed issuer, verifies the exact candidate SHA, and exposes the key only to the existing issuer/validator step. The upload step receives no key variable and uploads only the staged public approval, snapshot, manifest and nonce. Hidden-file inclusion is necessary for the approved snapshot directory.

Retain the run ID, triggering actor, actual environment approval record, successful validator output and artifact digest. Download only the public artifact. Confirm manifest hashes and candidate identity before composing the existing publication stage. The workflow intentionally does not commit, merge, release, activate Context, or claim completion of #678. Recheck that bootstrap remains applicable immediately before publication; a concurrent live approval requires predecessor-aware reissuance instead.

## Evidence and limits

Local tests exercise rejection of missing/weak environment controls, alternate refs/events/repos, wildcard/tag/multiple deployment rules, unavailable metadata, and an existing live approval. They also cover the valid single-owner configuration. They are deterministic tests, not observations of GitHub's enforcement. An actual protected-environment run, independent key custody and subsequent advisory/release acceptance remain necessary.
