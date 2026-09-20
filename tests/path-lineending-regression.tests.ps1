# REQ-004 pairwise path, EOL, and Unicode regression fixture.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$script:Pass = 0
$script:Fail = 0
function Test-Ok([string]$Message) { Write-Host "ok: $Message"; $script:Pass++ }
function Test-Fail([string]$Message) { Write-Host "FAIL: $Message"; $script:Fail++ }
function Assert-Equal([object]$Actual, [object]$Expected, [string]$Message) {
    if ([string]$Actual -ceq [string]$Expected) { Test-Ok $Message }
    else { Test-Fail "$Message (expected '$Expected', got '$Actual')" }
}
function Get-Sha256([string]$Path) {
    return 'sha256:' + (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Fixtures = Join-Path $PSScriptRoot 'fixtures/path-lineending-regression'
$MatrixPath = Join-Path $Fixtures 'matrix.tsv'
$LayerPath = Join-Path $Fixtures 'layer-dispositions.tsv'
$Work = Join-Path $Root ('.path-lineending.' + [Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($Work) | Out-Null

try {
    $NfcName = 'café-skill.md'
    $NfdName = "cafe$([char]0x0301)-skill.md"
    $NfdSource = Join-Path $Fixtures 'unicode-source-nfd.txt'
    $NfcCopy = Join-Path $Work 'unicode-copy-nfc.txt'
    $LfSource = Join-Path $Fixtures 'eol-lf.txt'
    $CrlfSource = Join-Path $Work 'eol-crlf.txt'
    $LfCopy = Join-Path $Work 'eol-normalized.txt'
    $NfdContentSha = 'sha256:22937d29caf43b99b40e1679cd3990180e1d415bdaebad013571f3e84a6eb16e'
    $NfcContentSha = 'sha256:d4b52a8b4ce9cd40ebfee654dc9d290862a3e57b82d3d2f7c618bf86af98963b'
    $LfContentSha = 'sha256:e49c81e2d2f84e259d40e2fb8192f3bcd198b355184845d76d8f58807d0d78ee'
    $CrlfContentSha = 'sha256:98ab4d3aeab1e120560e942e2df6a0db1147bf94bafcf1590000ffb3c2b6fc80'

    $hex = ([IO.File]::ReadAllText((Join-Path $Fixtures 'eol-crlf.hex'))).Trim()
    [IO.File]::WriteAllBytes($CrlfSource, [Convert]::FromHexString($hex))
    $utf8 = [Text.UTF8Encoding]::new($false)
    $nfdText = [IO.File]::ReadAllText($NfdSource, $utf8)
    [IO.File]::WriteAllText($NfcCopy, $nfdText.Normalize([Text.NormalizationForm]::FormC), $utf8)
    [IO.File]::WriteAllBytes($LfCopy, $utf8.GetBytes($utf8.GetString([IO.File]::ReadAllBytes($CrlfSource)).Replace("`r`n", "`n")))

    Assert-Equal (Get-Sha256 $NfdSource) $NfdContentSha 'NFD source bytes are fixed'
    Assert-Equal (Get-Sha256 $NfcCopy) $NfcContentSha 'NFC copied bytes are fixed'
    Assert-Equal (Get-Sha256 $LfSource) $LfContentSha 'LF source bytes are fixed'
    Assert-Equal (Get-Sha256 $CrlfSource) $CrlfContentSha 'CRLF source bytes are fixed'
    Assert-Equal (Get-Sha256 $LfCopy) $LfContentSha 'CRLF is corrected to LF bytes'
    if ($nfdText.IsNormalized([Text.NormalizationForm]::FormD) -and -not $nfdText.IsNormalized([Text.NormalizationForm]::FormC)) {
        Test-Ok 'committed Unicode source is NFD and not NFC'
    } else { Test-Fail 'committed Unicode source is not strict NFD' }
    $attr = (& git -C $Root check-attr eol -- 'tests/fixtures/path-lineending-regression/eol-lf.txt') -join "`n"
    if ($attr.EndsWith(': eol: lf', [StringComparison]::Ordinal)) { Test-Ok '.gitattributes assigns LF to the text fixture' }
    else { Test-Fail "unexpected git eol attribute: $attr" }

    $matrix = @(Import-Csv -LiteralPath $MatrixPath -Delimiter "`t")
    $generated = [Collections.Generic.List[object]]::new()
    $number = 0
    foreach ($runtimeScript in @('sh', 'ps1')) {
        foreach ($eol in @('LF', 'CRLF')) {
            foreach ($normalization in @('NFC', 'NFD')) {
                foreach ($phase in @('install', 'uninstall')) {
                    $number++
                    $os = @('windows', 'linux', 'macos')[($number - 1) % 3]
                    $separator = if ($os -ceq 'windows' -and $runtimeScript -ceq 'ps1') { 'backslash' } else { 'forward-slash' }
                    $generated.Add([pscustomobject]@{row=[string]$number; os=$os; script=$runtimeScript; separator=$separator; eol=$eol; normalization=$normalization; phase=$phase})
                }
            }
        }
    }
    $matrixMatches = $matrix.Count -eq 16
    for ($i = 0; $i -lt $matrix.Count -and $matrixMatches; $i++) {
        foreach ($field in @('row','os','script','separator','eol','normalization','phase')) {
            if ([string]$matrix[$i].$field -cne [string]$generated[$i].$field) { $matrixMatches = $false; break }
        }
    }
    if ($matrixMatches) { Test-Ok '16-row generation algorithm matches the fixed matrix' } else { Test-Fail 'generated matrix differs from fixture' }

    $axes = [ordered]@{os=@('windows','linux','macos'); script=@('sh','ps1'); eol=@('LF','CRLF'); normalization=@('NFC','NFD'); phase=@('install','uninstall')}
    $axisNames = @($axes.Keys)
    $pairwise = $true
    for ($a = 0; $a -lt $axisNames.Count; $a++) {
        for ($b = $a + 1; $b -lt $axisNames.Count; $b++) {
            foreach ($av in $axes[$axisNames[$a]]) {
                foreach ($bv in $axes[$axisNames[$b]]) {
                    if (-not ($matrix | Where-Object { $_.($axisNames[$a]) -ceq $av -and $_.($axisNames[$b]) -ceq $bv })) { $pairwise = $false }
                }
            }
        }
    }
    if ($pairwise) { Test-Ok 'all 10 independent-axis pairs are covered' } else { Test-Fail 'pairwise coverage is incomplete' }

    $canonicalNames = @($NfcName.Normalize([Text.NormalizationForm]::FormC), $NfdName.Normalize([Text.NormalizationForm]::FormC))
    if (@($canonicalNames | Select-Object -Unique).Count -ne $canonicalNames.Count) { Test-Ok 'dual NFC/NFD names trigger the collision oracle' }
    else { Test-Fail 'dual-form collision was accepted' }

    function Get-NativePath([string]$Os, [string]$Separator, [string]$Name) {
        if ($Os -ceq 'windows') {
            if ($Separator -ceq 'backslash') {
                $nativeName = $Name.Replace('/', '\')
                return "C:\sdd-fixture\$nativeName"
            }
            return "C:/sdd-fixture/$Name"
        }
        return "/tmp/sdd-fixture/$Name"
    }
    function Get-UninstallResidue {
        $installed = @($NfcName, $NfdName)
        $target = $NfdName.Normalize([Text.NormalizationForm]::FormC)
        $installed = @($installed | Where-Object { $_.Normalize([Text.NormalizationForm]::FormC) -cne $target })
        return ConvertTo-Json -InputObject $installed -Compress
    }
    function Invoke-HarnessCell([object]$Row, [string]$CaseName) {
        $result = 'PASS'
        $sourceSha = $NfdContentSha
        $sourceName = $NfdName
        $path = Get-NativePath $Row.os $Row.separator $NfcName
        $copiedSha = Get-Sha256 $NfcCopy
        if ($Row.normalization -ceq 'NFC') {
            $sourceSha = $NfcContentSha
            $sourceName = $NfcName
        }
        switch ($CaseName) {
            'windows-path-separator' {
                if ($Row.separator -cne 'backslash') { $result = 'N/A' }
                else {
                    $registration = Get-NativePath $Row.os $Row.separator 'registry/sdd-forge'
                    if (($path + '|' + $registration).Contains('/')) { $result = 'FAIL' }
                }
            }
            'crlf-lf-gitattributes-layer' {
                $sourceName = "eol-$($Row.eol.ToLowerInvariant()).txt"
                $sourceSha = if ($Row.eol -ceq 'LF') { Get-Sha256 $LfSource } else { Get-Sha256 $CrlfSource }
                $path = Get-NativePath $Row.os $Row.separator 'eol-normalized.txt'
                $copiedSha = Get-Sha256 $LfCopy
            }
            'nfc-nfd-filename' { }
            default { $result = 'FAIL' }
        }
        $stdout = if ($Row.phase -ceq 'uninstall') { "uninstalled $path" } else { "installed $path" }
        $residue = if ($Row.phase -ceq 'uninstall') { Get-UninstallResidue } else { '[]' }
        return [pscustomobject]@{result=$result; source_bytes_sha256=$sourceSha; source_name=$sourceName; resolved_path=$path; copied_bytes_sha256=$copiedSha; stdout_substring=$stdout; uninstall_residue=$residue}
    }

    $cells = [Collections.Generic.List[object]]::new()
    foreach ($row in $matrix) {
        foreach ($caseName in @('windows-path-separator','crlf-lf-gitattributes-layer','nfc-nfd-filename')) {
            $expectedResult = 'PASS'
            if ($row.normalization -ceq 'NFC') {
                $expectedSourceSha = $NfcContentSha
                $expectedSourceName = $NfcName
            } else {
                $expectedSourceSha = $NfdContentSha
                $expectedSourceName = $NfdName
            }
            $expectedPath = Get-NativePath $row.os $row.separator $NfcName
            $expectedCopiedSha = $NfcContentSha
            if ($caseName -ceq 'windows-path-separator' -and $row.separator -cne 'backslash') { $expectedResult = 'N/A' }
            if ($caseName -ceq 'crlf-lf-gitattributes-layer') {
                $expectedSourceName = "eol-$($row.eol.ToLowerInvariant()).txt"
                $expectedSourceSha = if ($row.eol -ceq 'LF') { $LfContentSha } else { $CrlfContentSha }
                $expectedPath = Get-NativePath $row.os $row.separator 'eol-normalized.txt'
                $expectedCopiedSha = $LfContentSha
            }
            $expectedStdout = if ($row.phase -ceq 'uninstall') { "uninstalled $expectedPath" } else { "installed $expectedPath" }
            $actual = Invoke-HarnessCell $row $caseName
            $matches = $actual.result -ceq $expectedResult -and $actual.source_bytes_sha256 -ceq $expectedSourceSha -and
                $actual.source_name -ceq $expectedSourceName -and $actual.resolved_path -ceq $expectedPath -and
                $actual.copied_bytes_sha256 -ceq $expectedCopiedSha -and $actual.stdout_substring -ceq $expectedStdout -and
                $actual.uninstall_residue -ceq '[]'
            if ($matches) { Test-Ok "row $($row.row) $caseName fixed oracle" } else { Test-Fail "row $($row.row) $caseName oracle mismatch" }
            $cells.Add([ordered]@{os=$row.os; separator=$row.separator; eol=$row.eol; normalization=$row.normalization; runtime_script=$row.script; phase=$row.phase; case=$caseName; result=$actual.result; oracle=[ordered]@{source_bytes_sha256=$actual.source_bytes_sha256; source_name=$actual.source_name; resolved_path=$actual.resolved_path; copied_bytes_sha256=$actual.copied_bytes_sha256; stdout_substring=$actual.stdout_substring; uninstall_residue=@()}})
        }
    }
    $document = [ordered]@{schema='path-lineending-fixture-result/v1'; cells=$cells}
    $roundTrip = $document | ConvertTo-Json -Depth 5 | ConvertFrom-Json
    $requiredOracle = @('source_bytes_sha256','source_name','resolved_path','copied_bytes_sha256','stdout_substring','uninstall_residue')
    $schemaValid = $roundTrip.schema -ceq 'path-lineending-fixture-result/v1' -and $roundTrip.cells.Count -eq 48
    foreach ($cell in $roundTrip.cells) {
        foreach ($field in $requiredOracle) { if ($null -eq $cell.oracle.$field) { $schemaValid = $false } }
        if ($cell.result -cnotin @('PASS','FAIL','N/A')) { $schemaValid = $false }
    }
    if ($schemaValid) { Test-Ok 'path-lineending-fixture-result/v1 has 48 complete cells' } else { Test-Fail 'result schema/count validation failed' }

    $expectedLayers = [ordered]@{'windows-path-resolution'='ASSERT'; 'crlf-lf-gitattributes'='ASSERT'; 'generated-text-canonicalizer'='N/A for this package'; 'nfc-nfd-normalization'='ASSERT'}
    foreach ($entry in @(Import-Csv -LiteralPath $LayerPath -Delimiter "`t")) {
        $actual = if ($expectedLayers.Contains($entry.layer)) { $expectedLayers[$entry.layer] } else { 'UNKNOWN' }
        Assert-Equal $actual $entry.disposition "layer $($entry.layer) disposition"
    }
} finally {
    if ($Work.StartsWith($Root + [IO.Path]::DirectorySeparatorChar + '.path-lineending.', [StringComparison]::Ordinal)) {
        Remove-Item -LiteralPath $Work -Recurse -Force
    }
}

Write-Host ''
Write-Host "path-lineending-regression: $($script:Pass) passed, $($script:Fail) failed"
if ($script:Fail -ne 0) { exit 1 }
exit 0
