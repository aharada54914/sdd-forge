# Resolve existing evidence paths through every filesystem link component.
# Callers own repository containment, regular-file policy and diagnostics.
function Resolve-SddEvidenceFilesystemPath([string]$Path) {
    $pending = [IO.Path]::GetFullPath($Path)
    $comparer = if ([IO.Path]::DirectorySeparatorChar -eq '\') { [StringComparer]::OrdinalIgnoreCase } else { [StringComparer]::Ordinal }
    $seen = [Collections.Generic.HashSet[string]]::new($comparer)
    # Windows link traversal is already bounded by the OS; this also bounds
    # the PowerShell 5.1 Target fallback without relying on .NET 6 APIs.
    $maximumLinkResolutions = 64
    while ($true) {
        $current = [IO.Path]::GetPathRoot($pending)
        $parts = $pending.Substring($current.Length).Split([IO.Path]::DirectorySeparatorChar, [StringSplitOptions]::RemoveEmptyEntries)
        $restart = $false
        for ($index = 0; $index -lt $parts.Count; $index++) {
            $current = Join-Path $current $parts[$index]
            $item = Get-Item -LiteralPath $current -Force -ErrorAction Stop
            if (-not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { continue }
            if (-not $seen.Add($current) -or $seen.Count -gt $maximumLinkResolutions) {
                throw "cyclic or excessive evidence link traversal: $current"
            }
            if ($item.PSObject.Methods['ResolveLinkTarget']) {
                $resolvedTarget = $item.ResolveLinkTarget($true)
                if ($null -eq $resolvedTarget) { throw "unresolved evidence link: $current" }
                $target = $resolvedTarget.FullName
            } else {
                $target = [string]@($item.Target)[0]
                if ([string]::IsNullOrEmpty($target)) { throw "unresolved evidence link: $current" }
                if ($target.StartsWith('\??\') -or $target.StartsWith('\\?\')) {
                    $target = $target.Substring(4)
                    if ($target.StartsWith('UNC\', [StringComparison]::OrdinalIgnoreCase)) { $target = '\\' + $target.Substring(4) }
                }
                if (-not [IO.Path]::IsPathRooted($target)) { $target = Join-Path (Split-Path -Parent $current) $target }
            }
            $pending = $target
            for ($remaining = $index + 1; $remaining -lt $parts.Count; $remaining++) {
                $pending = Join-Path $pending $parts[$remaining]
            }
            $pending = [IO.Path]::GetFullPath($pending)
            $restart = $true
            break
        }
        if (-not $restart) { return [IO.Path]::GetFullPath($current) }
    }
}
