# PR #406: canonical plugin names and installation documentation

Base: a9567753ce92f4d78b5a41a5c4ac7538a2056e3a.
Review comments: 3984722598, 3984722603, 3984722610.

## Cause and change

PowerShell ValidateSet accepted mixed-case plugin names unchanged. Downstream
CLI arguments therefore differed from the Bash allowlist's canonical names.
Both Plugins attributes now set IgnoreCase=false, rejecting invalid names during
parameter binding, before placement or registration. Default selections and
dependency resolution are unchanged. README, workflow guide and architecture
overview now consistently describe seven allowed names, six default installed
plugins, opt-in domain dependencies and seven default uninstalled plugins.

## Verification

- Before implementation, a FilesOnly/KeepFiles invocation with SDD-DOMAIN was
  accepted and printed successful uninstallation; a rejection assertion exited 1.
  Agent and MCP operations were disabled for this reproduction.
- Existing install and uninstall PowerShell suites now reject not-a-plugin,
  SDD-DOMAIN, Sdd-Domain and SDD-BOOTSTRAP, catching parameter-binding failures
  specifically rather than accepting unrelated errors as evidence.
- Both full suites passed under macOS PowerShell after the fix:
  `pwsh -NoProfile -File tests/install.tests.ps1` (exit 0),
  `pwsh -NoProfile -File tests/uninstall.tests.ps1` (exit 0).
  Existing lowercase domain installation and partial-removal tests remained.
- Initial test execution exposed a nonexistent exception type in the new test;
  corrected to public ParameterBindingException before the successful runs.
- git diff --check passed. Implementation review found no new critical issue:
  the change is restricted to plugin argument validation and documentation.

## Remaining conditions

This is local verification, not independent approval or Windows execution.
Latest-head CI and required third-party approval remain necessary. The separate
unapplied CRLF human batch is preserved; these tests do not establish its repair.
No prior failed test or frozen review verdict was changed to PASS.
