# Start-Process joins its ArgumentList array with spaces. Encode each atom for
# the native command-line parser; this is not quoting for cmd.exe or a shell.
function ConvertTo-SddNativeArgumentString {
    param([string[]]$Arguments)
    $quoted = foreach ($argument in $Arguments) {
        $escaped = [regex]::Replace($argument, '(\\*)"', '$1$1\"')
        $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
        '"' + $escaped + '"'
    }
    $quoted -join ' '
}

# Raw-byte native invocation with an owned process and stream deadline.
function Invoke-SddNativeRaw {
    # Runs a native executable as a real subprocess and returns raw bytes for stdout/stderr
    # (never PowerShell's own text/console decoding), reading both streams
    # concurrently via CopyToAsync to avoid a classic redirect deadlock.
    param(
        [string]$FileName,
        [string[]]$Arguments,
        [ValidateRange(1, 2147483647)][int]$TimeoutMilliseconds = 30000
    )
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $FileName
    if ($null -ne $psi.PSObject.Properties['ArgumentList']) {
        foreach ($argument in $arguments) { [void]$psi.ArgumentList.Add($argument) }
    } else {
        $psi.Arguments = ConvertTo-SddNativeArgumentString -Arguments $arguments
    }
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $proc = [System.Diagnostics.Process]::new()
    $proc.StartInfo = $psi
    $stdoutMs = [System.IO.MemoryStream]::new()
    $stderrMs = [System.IO.MemoryStream]::new()
    $cancel = [System.Threading.CancellationTokenSource]::new()
    $started = $false
    $clock = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $started = $proc.Start()
        $outTask = $proc.StandardOutput.BaseStream.CopyToAsync($stdoutMs, 81920, $cancel.Token)
        $errTask = $proc.StandardError.BaseStream.CopyToAsync($stderrMs, 81920, $cancel.Token)
        if (-not $proc.WaitForExit($TimeoutMilliseconds)) {
            throw [System.InvalidOperationException]::new("$FileName inspection exceeded its $($TimeoutMilliseconds / 1000)-second deadline")
        }
        $remaining = [Math]::Max(0, $TimeoutMilliseconds - [int]$clock.ElapsedMilliseconds)
        if (-not [System.Threading.Tasks.Task]::WaitAll([System.Threading.Tasks.Task[]]@($outTask, $errTask), $remaining)) {
            throw [System.InvalidOperationException]::new("$FileName output exceeded its $($TimeoutMilliseconds / 1000)-second deadline")
        }
        return @{ ExitCode = $proc.ExitCode; Stdout = $stdoutMs.ToArray(); Stderr = $stderrMs.ToArray() }
    } catch {
        throw [System.InvalidOperationException]::new("$FileName invocation failed: $($_.Exception.Message)")
    } finally {
        $cancel.Cancel()
        try {
            if ($started -and -not $proc.HasExited) {
                if ($null -ne $proc.GetType().GetMethod('Kill', [type[]]@([bool]))) {
                    $proc.Kill($true)
                } else {
                    $proc.Kill()
                }
                [void]$proc.WaitForExit(5000)
            }
        } finally {
            $proc.Dispose()
            $stdoutMs.Dispose()
            $stderrMs.Dispose()
            $cancel.Dispose()
        }
    }
}

# Preserve the existing Git adapter contract for resolver/precheck consumers.
function Invoke-SddGitRaw {
    param([string]$RepoRoot, [string[]]$GitArgs)
    Invoke-SddNativeRaw -FileName 'git' -Arguments (@('-C', $RepoRoot) + $GitArgs)
}
