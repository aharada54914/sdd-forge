# PowerShell

Apply [common rules](common.md), especially CS-001, CS-002, CS-004, CS-009, CS-012, CS-019, CS-025, CS-026.

Use the call operator and argument arrays, not Invoke-Expression. Use single-quoted here-strings for literal embedded programs. Avoid automatic-variable collisions such as $HOME/$PID. Cmdlet terminating errors and native LASTEXITCODE are different channels. Check case-sensitive operators and cmdlets separately. Pin UTF-8/BOM behavior and test PowerShell 7 and Windows PowerShell 5.1 where supported; Linux pwsh is not Windows-native evidence.

For each affected boundary, keep a hostile input, ordinary input and relevant platform control. Intentional negative fixtures remain classified and reviewed; blanket test-directory exclusions are not valid. Executed commands, versions, scope and not-run results belong in the audit evidence, not in an assumed tool capability claim.
