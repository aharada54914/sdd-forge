# RT-20260908-004: PowerShell saved manifest candidate

Artifact: `adr-workflow-powershell-manifest-candidate-20260909.patch`.
SHA-256: `9622cec01499942bcef5ef5a32ba9eb50fab6fab31ef0527fbd44d62028092e9`.

This is unapplied patch data, not an installed validator or a complete fix.
`git apply --numstat` accepted the patch format: 93 additions, no deletions.
No candidate code was executed and no applicability or runtime pass is claimed.

The proposed helpers validate role-specific saved manifests, canonical raw ADR
membership, required precheck/design/core/layer/summary pins, normalized path
uniqueness and actual-output supersets. Case-insensitive ADR-like detection is
used only to reject aliases; authorization uses ordinal canonical paths and
case-sensitive hashes. Actual-output extras are limited to layer specifications.

Prerequisites remain owned by the future caller: strict JSON decoding, exact
core and ADR validation, safe artifact snapshots, identity and summary checks,
and cross-manifest shared-layer consistency. These helpers are not yet wired
into persisted-history validation. Combining same-anchor candidate slices also
requires constructing and reviewing a coherent final patch, not concatenation.

Protected production validators were not changed. Full independent review and
the established human application boundary still apply. This report neither
resolves RT-20260908-004 nor upgrades the existing failing regression results.
