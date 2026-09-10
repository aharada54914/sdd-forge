# RT004 stationary case-alias correction

Scope: `docs/review-tickets/RT-20260908-004.yml`, implementation-review admission only.

## Observed defect and limited change

The original-path admission regression recorded in
`rt004-admission-root-link-red-20260910.md` reports 52 passing cases and eight
failures: stationary case aliases of precheck/design files are admitted in
both runtimes and both reviewer roles, including a synthetic ledger mutation.

`rt004-stationary-case-human-20260911.patch` adds exact directory-entry name
comparison at each repository-relative component before the existing checks.
Bash clears GLOBIGNORE in a subshell and uses nullglob/dotglob enumeration and case-sensitive
basename equality. PowerShell enumerates entries and compares names with
StringComparer.Ordinal. Only the impl-stage branch changes. Existing hardlink,
reparse/symlink, hash and other-stage checks remain intact.

This is NOT atomic acquisition: replacement between enumeration and open is
still possible. Same-captured-bytes acquisition, strict JSON handling and the
remaining ADR0034 requirements remain separate unresolved work. This report
does not resolve the ticket or grant a formal review verdict.

## Application boundary

The original-file apply_patch operation was rejected by the active PreToolUse
SDD guard. No alternate executor or copied validator was run. The data-only
patch was created for human application; original-file hashes were unchanged:

- Bash: `97deb3c9eeec2e8cf3689f547512ad96c6f266a7f28d5875c20d9098a31698b9`
- PowerShell: `b58df1ddfb5ae7d4c8bc31b6a32fe222780b582d529d8759c8d234dd730d2db3`
- Patch: `3d6ba8354fefa0a0d580fc47493a1edba5463037700cd50304cda40b9ab2cdb2`

`git apply --check` exited 0 before and after the GLOBIGNORE correction.
The initial numstat reported 14 Bash and 13 PowerShell added lines, no removed
lines; the correction adds one more Bash line. These checks do not execute the candidate.

Independent static reviewer `rt004_check_contract_review` found no required
Critical/Major correction in the initial limited patch, and recommended clearing
GLOBIGNORE; that recommendation is incorporated. This is not a formal gate PASS.
The same independent reviewer read the final hash above, confirmed the
subshell-local correction, and found no new required correction. No candidate
execution or formal gate verdict was performed by that review.
Compatibility boundary: an otherwise readable known file whose parent forbids
directory enumeration is newly rejected, because its exact entry name cannot be
established by this implementation. Do not hide this as unchanged behavior.

## Verification handoff

After human application, run the original test driver:

`rtk proxy bash tests/impl-review-adr-inputs.tests.sh --admission-path-only`

Require all 60 cases to pass, including both regular-hardlink positive cases
and all wrong-case negative cases; do not count an environment skip as evidence
for a skipped platform. macOS PowerShell results do not prove native Windows
or UNC behavior. Further scoped tests and formal gates remain mandatory before
CI/main integration. No commit, push, merge, task status or review verdict was
changed while preparing this patch.

## Original-path execution after application (2026-09-11)

The original files changed externally after the human application command was
provided. `git apply --reverse --check` of the reviewed patch exited 0.
Before/after the tests the current source hashes were:

- Bash: `f2df74965ec7f6a20871d9bb84e336d4c7be6ae51fe927cd1c50d6a23ba200ce`
- PowerShell: `ec9914633b54f7dd6bf926efc95888c9bafa2c848468fb2c6e5d7bd9de5aaafc`
- Test driver: `ba009da41ae2d6f6216c751e846eb0a2d00163f83aa5e01bb787c70fb61628c2`

Original-path command `rtk proxy bash tests/impl-review-adr-inputs.tests.sh
--admission-path-only`, terminal session 68713: exit 0,
`ADR admission: passed=60 failed=0`. All eight previously failing stationary
case-alias cases now reject; both roles/runtimes retain normal and hardlink
positives. No skipped cases were reported. This is macOS, not native Windows.

The separate original-path command `rtk proxy bash
tests/impl-review-adr-inputs.tests.sh --admission-json-only`, terminal session
21506: exit 1, `ADR admission: passed=20 failed=32`.
Both runtimes still admit duplicate root/escaped/nested members, invalid UTF-8
in precheck/design and root arrays. Bash additionally admits multiple JSON
documents. Each observed failing negative reported exit 0 and mutation of the
test fixture's synthetic ledger. Production review ledger mutation is not
claimed. Legacy, zero-bound, distinct nested members and BOM positives remain
passing. PowerShell rejects the multiple-document cases.

The stationary defect is now regression-verified, not the whole ticket.
Strict parsing and acquisition remain unresolved; no formal PASS, CI dispatch,
commit, push or merge follows from these two local test results.
