# RT004: raw-root lexical prerequisite candidate

Date: 2026-09-10
Status: INCOMPLETE / NEEDS_WORK; DATA candidate only, not applied or executed.

## Delta and baseline

The preceding original-path admission run (session 19961) returned 24 passed,
20 failed. Dot, dotdot and doubled-separator roots were accepted after normalizing
away the supplied spelling. Root-symlink cases also failed; lexical validation
does not resolve those cases. See `rt004-root-transport-regression-20260910.md`.

Updated `reports/verification/adr-runtime-lexical-candidate-20260909.patch`:

- Preserve Bash's original root argument separately from its resolved root.
- Check root syntax before the implementation-review precheck dispatch, including
  legacy prechecks, without changing other stages' content validation.
- Add corresponding PowerShell syntax validation using the original parameter.
- Keep failure diagnostics content-free and before the existing reservation.

Prior candidate SHA-256:
`0cfa88d533f22b4940bd90626329846411e09e494b92533fdccd80504e2b9ba1`

Current candidate SHA-256:
`1ffcc69c527fd0ed2a6db47670bb988bb4756a2ad3fd6a5b1e8a1363dd6fdb14`

## Checks and primary review

The initial applicability check rejected incorrect unified-diff hunk counts
(`corrupt patch at line 233`). The counts and following target offsets were
corrected. The final `git apply --check --unidiff-zero` exited 0. It did not
apply the patch. Whole-worktree `git diff --check` also exited 0.

Protected originals remain unchanged:

- Bash: `04e01b60cac4b8ccda12df069013a6052cd6825a1430256d59ccdf837a3af2f8`
- PowerShell: `832a00cbd9d9516f990411a684c5f671e8b8d5e92cc8f96d0ed9de4828c38187`

Primary review disposition: NEEDS_WORK for the complete candidate. The lexical
prerequisite is not no-follow acquisition. Existing early root resolution and
pathname-based input opens remain unsafe under the approved anchored-read
contract. Windows drive/UNC syntax and backend parity still need native tests;
the new syntax functions have not been executed. No independent review PASS is
claimed for this delta. Applicability is neither syntax nor behavioral proof.

## Remaining implementation sequence

Retain ADR-0034's full end state: held OS-root/share anchor; exact-name child
identity; no-follow regular-file acquisition; hash and parse identical private
bytes; bounded rejection before ledger mutation. Add deterministic acquisition
boundary race regressions, resolve/prove the native runtime dependency, and
complete both OS backends before independent security review and human apply.
Do not offer this partial candidate for application or use a renamed executable
to test it. Original-path full regression and native Windows drive/UNC evidence,
formal review and mandatory CI remain required before integration.

GitHub recheck: 11 open PRs, no live check jobs. No CI dispatch, commit, push,
merge, issue closure, or review verdict change was performed in this slice.
