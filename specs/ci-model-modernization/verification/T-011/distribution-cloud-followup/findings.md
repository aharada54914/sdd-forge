# Follow-up installer audit against 593a7e98

Root source remains unchanged; candidate and test patches are isolated. The user-supplied Claude audit examined older 80b7dff. Existing corrected README/THREAT-MODEL/architecture/cloud/contributor external links were verified, not duplicated.

## Confirmed defects

- install.sh:844 required paths omit four core `.claude-plugin/plugin.json` files and bootstrap/ship SKILL.md; six archive omission scenarios actually succeed incorrectly. Local missing tracked files already fail copying, but explicit parity requirements protect archives and source completeness.
- install.ps1:887 line-oriented `git ls-files` uses Git's quoted path representation. Explicit core.quotePath=true silently loses Japanese filenames; literal quote and tab names also disappear on POSIX. Candidate consumes raw UTF-8 NUL output with fixed process arguments, no shell quoting, and checks exit status. Uses .NET APIs available to Windows PowerShell rather than ArgumentList.
- Manifest includes repository-only maintainer docs, populated project retention history, and manually installed standalone skill. Tests inject fake content at these exact paths and demonstrate old payload leakage; no real private data is included in test evidence.

## Payload decisions

Drop docs/contributor/{release-runbook,weekly-local-codex-audit,self-improvement-measurement-proposal,shared-file-mirrors}.md: repository release/audit/proposal/mirror-maintenance instructions, not plugin runtime. Keep workflow-detail.md and skill-reference-detail.md as operator documentation. External weekly link replaces local link in workflow-detail:554; coordinated README links are separately owned by documentation agent.

Drop docs/workflow-improvements/retention-checklist.md: populated project-specific WFI ledger. workflow-retrospective SKILL refers to the user's project retention input/output, with absence handled; plugin installation must not seed its own repository's history.

Drop skills/adversarial-review/: docs/skill-reference.md:128 explicitly documents manual installation, no plugin manifest distributes it. Its optional developer MCP scripts and history links are therefore not an installed runtime dependency. Do not add MCP development scripts to compensate.

Keep private-ec2/package-lock.json: docs/cloud-orchestration.md:178 explicitly copies it with package.json for the installed operator's CDK preparation.

Keep CHANGELOG.md: USERGUIDE.md:361 and README.md:319/331 promise a version migration guide, not merely internal history.

Keep 45 docs/adr files (~312 KiB filesystem allocation): USERGUIDE:22 references0012; workflow-guide:428 explicitly identifies0023 as normative; skill-reference:788 refers0025 guarantees. README:317 and architecture:360 expose ADR index navigation. Removing all45 breaks documented reference closure. No expansion to specs/reports/test trees is required.

## Evidence

Registered helper additions are tests.patch. Four product/doc paths are products.patch. candidate-manifest.json pins original and candidate SHA-256 hashes. Both patches pass git apply --check against root, with no root modifications.

red-bash.log: six missing-file archive cases fail regression assertions against original code.
red-powershell.log: Unicode tracked file regression fails against original code.
red-docs.log: all six repository-only seeded document/skill paths leak against original code.
rollback-{bash,powershell}.log: reverting isolated installer/manifest products restores regression failures; rollback.json records nonzero statuses and exact restored candidate hashes.
green-after-rollback-{bash,powershell}.log: final complete nine-case helper suites, including local/archive, MCP exact payload, upgrade cleanup, rejected symlinks/invalid manifests/required paths and special-name parity.

Earlier provisional Green attempts were diagnostic and are not acceptance evidence; final after-rollback logs are authoritative. Real Windows PowerShell 5.1 is not available in this Linux environment; native hosted Windows validation remains necessary.
