# Candidate predicate tests only. Never runs a fixture as a command.
 $ErrorActionPreference = 'Stop'
 $data = [Console]::In.ReadToEnd() | ConvertFrom-Json
 $source = [string]$data.source
 $tokens = $null
 $errors = $null
 $tree = [System.Management.Automation.Language.Parser]::ParseInput($source, [ref]$tokens, [ref]$errors)
 if ($errors.Count -gt 0) { throw $errors[0].Message }
 # Initialize actual generated invariants and source globals, without main.
 $prefix = $source.Substring(0, $source.IndexOf('function Get-Count'))
 $prefix = $prefix.Replace('$PSScriptRoot', ("'" + (Split-Path $data.target) + "'"))
 Invoke-Expression $prefix
 foreach ($definition in $tree.FindAll({param($ast) $ast -is [System.Management.Automation.Language.FunctionDefinitionAst]}, $false)) {
     Invoke-Expression $definition.Extent.Text
 }
 $results = @()
 foreach ($case in $data.cases) { $results += [bool](Test-ShellTargetsProtectedGateFile $case.command) }
 ConvertTo-Json -Compress -InputObject $results
