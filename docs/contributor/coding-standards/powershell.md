# PowerShell

Apply [common rules](common.md), especially CS-001, CS-002, CS-004, CS-009, CS-012, CS-019, CS-025, CS-026.

Use the call operator and argument arrays, not Invoke-Expression. Use single-quoted here-strings for literal embedded programs. Avoid automatic-variable collisions such as $HOME/$PID. Cmdlet terminating errors and native LASTEXITCODE are different channels. Check case-sensitive operators and cmdlets separately. Pin UTF-8/BOM behavior and test PowerShell 7 and Windows PowerShell 5.1 where supported; Linux pwsh is not Windows-native evidence.

For each affected boundary, keep a hostile input, ordinary input and relevant platform control. Intentional negative fixtures remain classified and reviewed; blanket test-directory exclusions are not valid. Executed commands, versions, scope and not-run results belong in the audit evidence, not in an assumed tool capability claim.

The required `windows-powershell` CI matrix uses fresh Windows Server 2022 VMs
with native Windows PowerShell 5.1 and PowerShell 7.6. The engine and its
`ci-windows-powershell51` or `ci-windows-powershell7` profile are passed to the existing
verification runner. Child processes use the hosting executable, including when
both engines are installed. The runtime check rejects another version, edition,
architecture or OS; PowerShell 7 patch versions follow the hosted image and are
recorded rather than assumed.

The step shell also uses the selected engine. Starting 5.1 through Python from
a PowerShell 7 shell can inherit incompatible module search paths and break
autoloading of standard commands such as `Get-FileHash`; see Microsoft's
[module path guidance](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_psmodulepath#starting-windows-powershell-from-powershell-7).

Common product contracts stay in the existing required PowerShell 7 jobs. The new
7.6 profile only records native parent/child identity. The 5.1 profile adds
FilesOnly install/reinstall/uninstall in temporary directories, the existing
panelist suite's focused runtime boundaries (including BOM/newline byte limits),
and native argument/timeout, evidence producer/consumer and Windows junction
containment checks. Cross-model encoding already tests both native producers in
the existing cross-model suite and is not duplicated here. Each matrix artifact retains runtime,
OS/image, tested commit and per-suite results, including failures. These checks
do not certify desktop interaction, authenticated host registration, every
PowerShell entry point, or every Windows version. Keep the existing broader
PowerShell 7 suites required alongside this profile.
