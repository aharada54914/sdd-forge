# Independent four-target package review — 2026-10-06

Safety result: PASS for the pinned four-target candidate and bounded application-helper behavior. Critical 0; Major 0; no blocking package-documentation finding. This is not formal SDD approval, a release decision, native-host proof or permission to apply/reserve/launch. `RELEASE_READY=False` remains unchanged.

Owner: `/Users/jrmag/.codex/worktrees/a7-t005-intake/sdd-forge`. No original source, ledger, reservation or verdict was modified. Only this new non-frozen review record was authored by the reviewer.

## Pins and review scope

- Patch: `8359ff939c5da6fc5dfab435ebabb73097c62f7af1283debb1e90508277970ca`.
- Skill candidate: `2b7763cb3b49c5fad4a82b677b70a9d336f0edbd9ed9731e8cafb76584635e3b`.
- Helper: `c19a383971bfa07a7e2d1ca5e7bcc2da96e353bc62c513f338a9a9476f051c49`.
- Three Python candidates match the hashes independently reviewed in `independent-major1-review.md`: failed `438431a8f75ff83d302413ed69c8d66bf0b44aab80d5d7c1ab72cb55b1e74dc5`, fresh `7c61cfdfb92cf885a974881d3264418ef09f10264db2eb87701237cc15cfb6c1`, non-TTY `fe5274cf4f49c324c6ef05efaf079c2d66ab11b05af3ef08e60ffe63b6b71b64`. Their 53-case evidence and independent Major1 rejection remain applicable to those unchanged bytes; those suites were not redundantly rerun in this package review.

The skill delta explicitly confines missing allocation/proposal tolerance to diagnostic malformed-result recovery, forbids backfill/adoption, binds `failed_turn_sha256`, and preserves ordinary launch and completed-round requirements. This is consistent with the reviewed implementation and closes the prior missing-exception explanation.

The helper pins four exact target paths, original/candidate hashes and the patch hash; rejects symlinks/alias paths, wrong owner, unexpected headers and partial application; defaults to read-only `git apply --check`; blocks the human flag while unreleased. The enabled fixture path backs up and verifies all originals, rechecks pins, invokes ordinary `rtk proxy git apply`, then verifies all four resulting hashes. It neither retries via another executor nor silently rolls back. Already-applied exact state is a no-op. No automatic release follows this review.

## Independently executed verification

`rtk proxy env PYTHONDONTWRITEBYTECODE=1 python3 reports/verification/a7-attempt21-recovery-candidate-20261006/human-apply.tests.py` exited 0: 10 fixture cases passed (read-only default; normal four-file apply/no-op; unreleased refusal; patch/candidate/source mismatch; fourth skill-source mismatch; partial apply; symlink; mid-backup mismatch). Only disposable fixture copies were applied. Fixture backup directories printed by the helper remain retained; none is a backup produced by applying owner targets.

Actual candidate/helper hashes were independently calculated. Ordinary git application and exact four-target readback succeeded in the fixture. The owner helper was not run with `--apply-human`, and its release flag was not changed.

## Documentation qualifications and unverified gates

The skill candidate says “exact failed-round regular-file inventory” without repeating the six/23 filenames. Proposal step 7 requires documenting the diagnostic opt-in, not duplicating the complete schema in the skill. The proposal, pinned candidate validators and current `four-target-package.md` supply the inventory details. The skill's bounded exception plus these implementation references are sufficient for this package review; the absence of a repeated filename enumeration is not a blocking defect or a request for another documentation loop.

Independently read `four-target-package.md`: its final paragraph explicitly supersedes the three-target release-package hashes in `human-apply-preparation.md` while preserving that earlier record. The current four-target hashes match this review's readback. There is no unresolved package-identity inconsistency and no need to rewrite the historical preparation note.

Formal SDD/protected-application authority, installed native-host execution, exact-HEAD CI, quality gate and actual A21 admission remain unverified/unperformed. Candidate safety PASS must not be promoted to those states or to `RELEASE_READY=True` automatically.
