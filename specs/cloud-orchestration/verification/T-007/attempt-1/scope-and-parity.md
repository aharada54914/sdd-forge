# T-007 scoped packaging and parity record

## Runtime placement and supported invocation

No provider Python or governed-wrapper execution code was edited. The existing
`CLOUD_SHARED_RUNTIME_ROOT` override is used explicitly by each installed skill.
The installer materializes a selected provider's `runtime/scripts` (all four
shared modules), `runtime/references/cloud-verification-registry.json`, and
`runtime/contracts` (cloud schemas plus verification-contract-v3 and selected-
verification-plan-v2). Source canonical modules and registry remain owned by
T002/T003/T006/T009/T010. No static vendor fork or second implementation is added.
Bash and PowerShell copy only the already staged tracked/archive inputs, before
install-root swap and host registration. Missing cloud_dependencies.py aborts.

A bare independently cached provider checkout without running the installer is
not a self-contained package. The skills explicitly require the installer and
its resulting runtime directory, or the canonical sibling shared root in a
reviewed source checkout. They do not discover arbitrary code on PYTHONPATH or
fall back to /tmp/a development tree. Governed wrappers retain their existing
reviewed full-executor-checkout contract; packaging does not loosen authority.

Both skills retain Python **3.11+**, matching the current Azure local contract.
Their CLI safe-file implementation already requires POSIX primitives. Installer
PowerShell runs were real PowerShell 7 on Linux, not a claim of native Windows
Python cloud compatibility. Windows installer CI and native model/host routing
are root/T011 checks; no platform SKIP was newly enabled or waived here.

## WFI-012 operator sweep (changed production branches)

- install.ps1: plugin ValidateSet remains IgnoreCase=false; dependency switch is
  explicitly -CaseSensitive; closure membership uses -cnotcontains; cloud plugin
  membership for required files and payload placement uses -cin.
- uninstall.ps1: exact ValidateSet; full/partial determination uses -cnotcontains.
  Partial uninstall retains all payloads/agents/MCPs, including other providers
  and unrelated plugins. Removing the last cloud entry does not GC the shared
  quality plugin. Full default uninstall still removes the install root.
- validate-repository.ps1: name/version/export path, marketplace source/policy,
  public skill names and frontmatter values use case-sensitive comparisons.
  Numeric counts and object/type checks have no string-case semantics.
- No new -replace/-split/-like sites were introduced; unchanged unrelated
  legacy comparisons are not claimed as a repository-wide parity rewrite.
- Executed negative inputs SDD-AZURE-CLOUD and sdd-Aws-cloud fail both installers
  before placement (`InstalledLifecycle.test_case_variants_at_operator_and_file_discovery_layers`).
  Every provider/host manifest name uppercase and skills path uppercase is also
  rejected by the actual validator block with a matched control.

## WFI-012 independent cmdlet/language sweep

- Schema discovery uses Get-ChildItem -LiteralPath -File, then -cmatch on Name,
  not PowerShell's case-insensitive -Filter/-Include/-Exclude.
- Skill discovery similarly uses the manifest-exported plugin skills roots and
  Name -ceq SKILL.md. Pinned upstream SKILL.md under references/ is data, not a
  public export. Both old entry consumers remain enforced.
- New Copy-Item/Get-Item/Get-FileHash sites use LiteralPath; no wildcard casing
  is delegated to these cmdlets. Dependency switch uses -CaseSensitive.
- No Select-String, Sort-Object, string case conversion or raw regex API sites
  were introduced in the packaging logic. Existing regex APIs in the untouched
  release-version block retain their existing behavior.
- Actual negative file CLOUD-CASE.schema.json is staged but is NOT copied into
  either Bash or PowerShell runtime/contracts. Lowercase schemas are present
  and byte-equal in the same runs. This is independent of argument comparisons.

## Evidence limits

Six installer cells (Azure, AWS, both × Bash/PowerShell), eight installed provider
payloads and 24 independently cached host-layout copies use real local Python
subprocesses. Cache layout trials model Codex/Claude/Copilot directory isolation;
they are not live host CLI/model invocations (T011). Host registration regression
suites use logging CLI shims. No network/cloud operation is performed.

Installed public route is a positive control. Direct prepare/apply deny at the
existing no-executor gate; this is NOT described as predecessor-guard execution.
Missing/invalid predecessor bodies also deny through installed route validation.
The separately installed shared dependency callable is exercised with matched
controls and a scoped synthetic _verified response: missing/changed receipt-set
checks execute; selectively bypassing the set guard changes the outcome. This
proves installed guard sensitivity, not GitHub provenance or live IAM. Removing
cloud_dependencies.py causes the actual installed import probe to fail.

Positive protected profile selection reads the installed registry; removing it
raises FileNotFoundError, and changing its version reaches PROFILE_REGISTRY_INVALID.
All shared-module paths are asserted to reside in the installed runtime; registry
and schema bytes are compared against current T009/T010 canonical outputs.

No full repository suite, cloud action, quality review, task status update, push,
tag, merge, bootstrap routing, active cloud workflow, or release-wide docs/version
change was performed. Frozen specs and all unrelated initial inputs are unchanged.
