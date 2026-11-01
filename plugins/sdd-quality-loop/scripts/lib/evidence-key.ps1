# Evidence-signing key acquisition shared by producer and validator.
# This owns byte normalization and lookup priority, not risk/admission policy.
function Read-SddEvidenceKeyBytes([string]$Path) {
    $bytes = [IO.File]::ReadAllBytes($Path)
    $start = if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { 3 } else { 0 }
    $end = $bytes.Length
    while ($end -gt $start -and $bytes[$end - 1] -in @(0x20, 0x09, 0x0D, 0x0A)) { $end-- }
    if ($end -le $start) { return $null }
    return ,([byte[]]$bytes[$start..($end - 1)])
}

function Resolve-EvidenceKey {
    $envKey = [System.Environment]::GetEnvironmentVariable("SDD_EVIDENCE_KEY")
    if (-not [string]::IsNullOrWhiteSpace($envKey)) {
        return @{ key = [System.Text.Encoding]::UTF8.GetBytes($envKey); ref = "env:SDD_EVIDENCE_KEY" }
    }
    $envKeyFile = [System.Environment]::GetEnvironmentVariable("SDD_EVIDENCE_KEY_FILE")
    if (-not [string]::IsNullOrWhiteSpace($envKeyFile)) {
        try {
            $raw = Read-SddEvidenceKeyBytes $envKeyFile
            if ($raw.Length -gt 0) {
                return @{ key = $raw; ref = "file:$envKeyFile" }
            }
        } catch {
            return $null
        }
    }
    # NB: do not name this $home — $HOME is a read-only automatic variable in
    # PowerShell (case-insensitive), and assigning to it throws under -ErrorAction Stop.
    $userHome = $env:HOME
    if ([string]::IsNullOrWhiteSpace($userHome)) { $userHome = $env:USERPROFILE }
    if (-not [string]::IsNullOrWhiteSpace($userHome)) {
        # Windows PowerShell 5.1 accepts only Path and ChildPath for Join-Path.
        $keyPath = Join-Path (Join-Path $userHome ".sdd") "evidence-key"
        if (Test-Path -LiteralPath $keyPath) {
            try {
                $raw = Read-SddEvidenceKeyBytes $keyPath
                if ($raw.Length -gt 0) {
                    return @{ key = $raw; ref = "file:~/.sdd/evidence-key" }
                }
            } catch {
                return $null
            }
        }
    }
    return $null
}

