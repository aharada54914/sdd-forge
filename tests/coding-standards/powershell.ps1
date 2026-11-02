# Native parser owns PowerShell grammar; paths arrive as data, never source.
$ErrorActionPreference = 'Stop'
try {
    Import-Module PSScriptAnalyzer -RequiredVersion 1.25.0 -ErrorAction Stop
    $Rules = @('PSAvoidUsingInvokeExpression', 'PSAvoidAssignmentToAutomaticVariable', 'PSAvoidUsingPlainTextForPassword', 'PSMisleadingBacktick')
    $Paths = @([Console]::In.ReadToEnd() | ConvertFrom-Json)
    $Findings = @()
    foreach ($Path in $Paths) {
        $Tokens = $null
        $ParseErrors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$Tokens, [ref]$ParseErrors)
        foreach ($Diagnostic in @(Invoke-ScriptAnalyzer -Path $Path -IncludeRule $Rules -ErrorAction Stop)) {
            $Findings += @{path=$Path; line=$Diagnostic.Line; column=$Diagnostic.Column; code=$Diagnostic.RuleName; message=$Diagnostic.Message}
        }
        foreach ($ParseError in $ParseErrors) {
            $Findings += @{path=$Path; line=$ParseError.Extent.StartLineNumber; column=$ParseError.Extent.StartColumnNumber; code=$ParseError.ErrorId; message='PowerShell syntax error'}
        }
    }
    @{version=$PSVersionTable.PSVersion.ToString(); analyzer_version='1.25.0'; findings=@($Findings)} | ConvertTo-Json -Depth 6 -Compress
} catch {
    [Console]::Error.WriteLine('PowerShell analysis failed')
    exit 2
}
