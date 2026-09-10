# RT004 PowerShell shared-layer candidate slice

Status: incomplete candidate DATA, not an application package. No protected implementation was edited, copied, loaded or executed.

Candidate: `adr-workflow-powershell-shared-layer-candidate-20260909.patch`.

The helper visits both contract manifests and both reviewer output manifests. It normalizes paths with the existing repository-relocation function, uses an ordinal dictionary, validates lowercase hexadecimal hashes and rejects disagreement for any shared layer path. An absent optional layer remains permitted, preserving the legacy layer-superset compatibility rule. It reads no current layer bytes: historical agreement is distinct from freshness.

Primary static review: no new Critical finding in this helper slice. Comparison operations and layer-name recognition are explicitly case-sensitive; it avoids PS7-only hashing and JSON APIs. This is not independent review or Windows 5.1 execution evidence. The existing relocation helper has its own current-root case-insensitive behavior; this slice neither broadens nor repairs it. The complete history validator must separately enforce canonical paths, exact extension presence, entry uniqueness, complete role sets, precheck pins, verdict/count/summary consistency and safe evidence-file reads.

Integration requirement: invoke only after the ADR-extension pair and manifests are structurally validated, but before `Test-PassedStage` reaches the identity-failure opening return (current source lines 1060–1063). Do not connect this helper alone and present it as the completed ticket: it does not validate or authorize ADRs. The complete PowerShell history binding, current-declaration validation and manifest allowlist changes remain to be assembled against the Bash candidate contract.

Verification: `git apply --numstat` parsed the patch successfully (34 additions, 0 deletions). This is patch-format validation only, not applicability or runtime correctness. The actual original runtimes' RED evidence is in `rt004-shared-layer-regression-red-20260909.md` (4 pass, 8 fail). Formal independent review and applied-runtime GREEN remain required.

Fresh GitHub inventory: PRs 401, 400, 394, 390, 381, 371 and 245 remain open, with unchanged heads compared with the prior recorded inventory. This query does not establish live CI jobs or green checks. No merge or issue closure was performed.
