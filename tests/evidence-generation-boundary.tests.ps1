$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$scripts = Join-Path $repositoryRoot 'plugins/sdd-quality-loop/scripts'
. (Join-Path $scripts 'lib/native-arguments.ps1')
. (Join-Path $scripts 'lib/evidence-key.ps1')
. (Join-Path $scripts 'lib/evidence-path.ps1')
$hostPath = (Get-Process -Id $PID).Path
$work = Join-Path ([IO.Path]::GetTempPath()) ('evidence boundary ' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $work | Out-Null
function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
    Write-Host "ok: $Message"
}
try {
    $python = Get-Command python3 -ErrorAction SilentlyContinue
    if (-not $python) { $python = Get-Command python -ErrorAction Stop }
    $atoms = @('', 'space atom', 'quote"atom', 'trailing\', "line`nnext")
    $native = Invoke-SddNativeRaw -FileName $python.Source -Arguments (@('-c', 'import json,sys;sys.stdout.write(json.dumps(sys.argv[1:]));sys.stderr.write("diagnostic");sys.exit(7)') + $atoms)
    $received = [Text.Encoding]::UTF8.GetString($native.Stdout) | ConvertFrom-Json
    Assert ($native.ExitCode -eq 7 -and [Text.Encoding]::UTF8.GetString($native.Stderr) -ceq 'diagnostic' -and (ConvertTo-Json -InputObject $received -Compress) -ceq (ConvertTo-Json -InputObject $atoms -Compress)) 'native adapter preserves argv, byte streams and nonzero status'
    $pidFile = Join-Path $work 'child.pid'
    $sleeper = Join-Path $work 'sleep child.ps1'
    [IO.File]::WriteAllText($sleeper, 'param($Receipt); [IO.File]::WriteAllText($Receipt, [string]$PID); Start-Sleep -Seconds 30')
    $timedOut = $false
    $timer = [Diagnostics.Stopwatch]::StartNew()
    try { Invoke-SddNativeRaw -FileName $hostPath -Arguments @('-NoProfile', '-File', $sleeper, $pidFile) -TimeoutMilliseconds 1500 | Out-Null }
    catch { $timedOut = $_.Exception.Message.Contains('deadline') }
    Assert ($timedOut -and $timer.Elapsed.TotalSeconds -lt 8) 'native adapter enforces its process deadline'
    $childId = [int](Get-Content -Raw -LiteralPath $pidFile)
    Assert (-not (Get-Process -Id $childId -ErrorAction SilentlyContinue)) 'native adapter reaps its timed-out child'

    foreach ($name in @('ordinary', 'literal[ab]')) {
        $repo = Join-Path $work $name
        New-Item -ItemType Directory -Path $repo | Out-Null
        & git -C $repo init -q
        & git -C $repo -c user.name=Fixture -c user.email=fixture@example.invalid commit --allow-empty -qm initial
        Assert ($LASTEXITCODE -eq 0) 'fixture repository initialized'
        $contractPath = Join-Path $repo 'T-001.contract.json'
        $report = Join-Path $repo 'report[ab].md'
        [IO.File]::WriteAllText($report, "Task ID: T-001`nFeature: fixture`nVERDICT: PASS`nCritical: 0`nMajor: 0`nMinor: 0`n")
        [IO.File]::WriteAllText((Join-Path $repo 'evidence.txt'), 'real evidence')
        $contract = @{task_id='T-001'; feature='fixture'; checks=@('lint','typecheck','unit-tests','build','placeholder-scan','task-state-check' | ForEach-Object { @{id=$_; required=$true; passes=$true; evidence='evidence.txt'} })}
        $contractJson = $contract | ConvertTo-Json -Depth 5
        [IO.File]::WriteAllText($contractPath, $contractJson)
        $bundle = Join-Path $repo 'bundle[ab].json'
        & $hostPath -NoProfile -File (Join-Path $scripts 'generate-evidence-bundle.ps1') -RepoRoot $repo -ContractPath $contractPath -QualityReport $report -OutputPath $bundle *> $null
        Assert ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $bundle)) "generator preserves literal $name repository/report/output paths"
        $document = Get-Content -Raw -LiteralPath $bundle | ConvertFrom-Json
        Assert ($document.artifacts.Count -eq 3 -and $document.task_id -ceq 'T-001') 'generator records all ordinary artifacts'
        $checkedBundle = Join-Path $repo 'T-001.evidence.json'
        Copy-Item -LiteralPath $bundle -Destination $checkedBundle -Force
        $consumerOutput = & $hostPath -NoProfile -File (Join-Path $scripts 'check-evidence-bundle.ps1') $checkedBundle -RepoRoot $repo 2>&1
        Assert ($LASTEXITCODE -eq 0) "evidence consumer accepts the generated literal-path bundle: $($consumerOutput -join ' ')"

        New-Item -ItemType HardLink -Path (Join-Path $repo 'hardlink.txt') -Target (Join-Path $repo 'evidence.txt') | Out-Null
        $contract.checks[0].evidence = 'hardlink.txt'
        [IO.File]::WriteAllText($contractPath, ($contract | ConvertTo-Json -Depth 5))
        & $hostPath -NoProfile -File (Join-Path $scripts 'generate-evidence-bundle.ps1') -RepoRoot $repo -ContractPath $contractPath -QualityReport $report -OutputPath $bundle *> $null
        Assert ($LASTEXITCODE -eq 0) 'generator preserves ordinary hardlinked artifacts'
        Copy-Item -LiteralPath $bundle -Destination $checkedBundle -Force
        $consumerOutput = & $hostPath -NoProfile -File (Join-Path $scripts 'check-evidence-bundle.ps1') $checkedBundle -RepoRoot $repo 2>&1
        Assert ($LASTEXITCODE -eq 0) 'evidence consumer accepts ordinary hardlinked artifacts'
        if (-not $IsWindows) {
            $outside = Join-Path $work 'outside.txt'
            [IO.File]::WriteAllText($outside, 'outside fixture')
            New-Item -ItemType SymbolicLink -Path (Join-Path $repo 'outside-link.txt') -Target $outside | Out-Null
            $contract.checks[0].evidence = 'outside-link.txt'
            [IO.File]::WriteAllText($contractPath, ($contract | ConvertTo-Json -Depth 5))
            Remove-Item -LiteralPath $bundle
            & $hostPath -NoProfile -File (Join-Path $scripts 'generate-evidence-bundle.ps1') -RepoRoot $repo -ContractPath $contractPath -QualityReport $report -OutputPath $bundle *> $null
            Assert ($LASTEXITCODE -ne 0 -and -not (Test-Path -LiteralPath $bundle)) 'generator rejects evidence linked outside repository'
            New-Item -ItemType SymbolicLink -Path (Join-Path $repo 'inside-link.txt') -Target (Join-Path $repo 'evidence.txt') | Out-Null
            $contract.checks[0].evidence = 'inside-link.txt'
            [IO.File]::WriteAllText($contractPath, ($contract | ConvertTo-Json -Depth 5))
            & $hostPath -NoProfile -File (Join-Path $scripts 'generate-evidence-bundle.ps1') -RepoRoot $repo -ContractPath $contractPath -QualityReport $report -OutputPath $bundle *> $null
            Assert ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $bundle)) 'generator preserves in-repository evidence links'
            # Inject the missing .NET method capability while retaining real
            # filesystem Target data; this is not a Windows-native claim.
            function Get-Item {
                [CmdletBinding()] param([string]$LiteralPath, [switch]$Force)
                $item = Microsoft.PowerShell.Management\Get-Item -LiteralPath $LiteralPath -Force:$Force -ErrorAction Stop
                if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                    return [pscustomobject]@{ Attributes=$item.Attributes; Target=$item.Target; FullName=$item.FullName }
                }
                return $item
            }
            try {
                Assert ((Resolve-SddEvidenceFilesystemPath (Join-Path $repo 'inside-link.txt')) -ceq (Join-Path $repo 'evidence.txt')) 'legacy Target fallback resolves real in-repository links'
                Assert ((Resolve-SddEvidenceFilesystemPath (Join-Path $repo 'outside-link.txt')) -ceq $outside) 'legacy Target fallback exposes the actual external target for caller containment'
            } finally { Remove-Item Function:\Get-Item }

            Copy-Item -LiteralPath $bundle -Destination $checkedBundle -Force
            $consumerOutput = & $hostPath -NoProfile -File (Join-Path $scripts 'check-evidence-bundle.ps1') $checkedBundle -RepoRoot $repo 2>&1
            Assert ($LASTEXITCODE -eq 1 -and ($consumerOutput -join ' ') -match 'reparse point') 'evidence consumer preserves the stricter contract gate policy for in-repository links'

        }
        foreach ($invalid in @("[$contractJson]", '{"task_id":"T-001","checks":{}}', '{"task_id":"T-001","checks":[7]}')) {
            [IO.File]::WriteAllText($contractPath, $invalid)
            Remove-Item -LiteralPath $bundle
            & $hostPath -NoProfile -File (Join-Path $scripts 'generate-evidence-bundle.ps1') -RepoRoot $repo -ContractPath $contractPath -QualityReport $report -OutputPath $bundle *> $null
            Assert ($LASTEXITCODE -ne 0 -and -not (Test-Path -LiteralPath $bundle)) 'generator rejects malformed contract shape before publication'
            [IO.File]::WriteAllText($bundle, 'reset fixture')
        }
    }
    $savedKey = $env:SDD_EVIDENCE_KEY
    $savedKeyFile = $env:SDD_EVIDENCE_KEY_FILE
    try {
        $env:SDD_EVIDENCE_KEY = ''
        $env:SDD_EVIDENCE_KEY_FILE = Join-Path $work 'signing-key.txt'
        [IO.File]::WriteAllBytes($env:SDD_EVIDENCE_KEY_FILE, ([byte[]]@(0xEF,0xBB,0xBF) + [Text.Encoding]::UTF8.GetBytes("test-fixture-key`r`n")))
        $keyInfo = Resolve-EvidenceKey
        Assert ([Text.Encoding]::UTF8.GetString($keyInfo.key) -ceq 'test-fixture-key') 'shared key loader strips only BOM and trailing ASCII whitespace'
        $env:SDD_EVIDENCE_KEY = 'environment-priority'
        Assert ([Text.Encoding]::UTF8.GetString((Resolve-EvidenceKey).key) -ceq 'environment-priority') 'shared key loader preserves environment precedence'
        $env:SDD_EVIDENCE_KEY = ''
        $contract.risk = 'critical'
        $contract.checks = @(@{id='test'; passes=$true; evidence='evidence.txt'})
        [IO.File]::WriteAllText($contractPath, ($contract | ConvertTo-Json -Depth 5))
        & $hostPath -NoProfile -File (Join-Path $scripts 'generate-evidence-bundle.ps1') -RepoRoot $repo -ContractPath $contractPath -QualityReport $report -OutputPath $bundle *> $null
        Assert ($LASTEXITCODE -eq 0) 'generator accepts a BOM-prefixed key file with trailing whitespace'
        $signed = Get-Content -Raw -LiteralPath $bundle | ConvertFrom-Json
        Assert ($signed.signature.alg -ceq 'hmac-sha256' -and $signed.signature.key_ref -ceq "file:$env:SDD_EVIDENCE_KEY_FILE") 'generator records key-file signing provenance'
        Copy-Item -LiteralPath $bundle -Destination $checkedBundle -Force
        $signedConsumer = & $hostPath -NoProfile -File (Join-Path $scripts 'check-evidence-bundle.ps1') $checkedBundle -RepoRoot $repo 2>&1
        # This deliberately minimal critical fixture fails other provenance gates;
        # isolate HMAC interoperability, then prove that its negative oracle fires.
        Assert (($signedConsumer -join ' ') -notmatch 'no evidence key available|HMAC mismatch') 'consumer verifies producer signature using the same normalized key file'
        $env:SDD_EVIDENCE_KEY = 'different-verification-key'
        $wrongKeyConsumer = & $hostPath -NoProfile -File (Join-Path $scripts 'check-evidence-bundle.ps1') $checkedBundle -RepoRoot $repo 2>&1
        Assert ($LASTEXITCODE -ne 0 -and ($wrongKeyConsumer -join ' ') -match 'HMAC mismatch') 'consumer rejects the same signature with a different higher-priority environment key'
    } finally {
        $env:SDD_EVIDENCE_KEY = $savedKey
        $env:SDD_EVIDENCE_KEY_FILE = $savedKeyFile
    }
    New-Item -ItemType Directory -Path (Join-Path $repo 'specs/fixture/adr') -Force | Out-Null
    $structureOutput = & $hostPath -NoProfile -File (Join-Path $repositoryRoot 'plugins/sdd-bootstrap/scripts/check-sdd-structure.ps1') -Root $repo 2>&1
    Assert (($structureOutput -join ' ') -match 'drift: specs/fixture/adr') 'bootstrap advisory scan preserves literal bracket root paths'
    $riskPath = Join-Path $work 'tasks[ab].md'
    [IO.File]::WriteAllText($riskPath, "## T-001`nRisk: high`nRisk Rationale: sensitive`n")
    [IO.File]::WriteAllText((Join-Path $work 'tasksa.md'), "## T-001`nRisk: low`nRisk Rationale: limited`n")
    & $hostPath -NoProfile -File (Join-Path $scripts 'check-risk.ps1') $riskPath *> $null
    Assert ($LASTEXITCODE -eq 1) 'risk gate inspects the literal target instead of a clean wildcard neighbor'
    & $hostPath -NoProfile -File (Join-Path $scripts 'check-risk.ps1') (Join-Path $work 'tasksa.md') -TaskId t-001 *> $null
    Assert ($LASTEXITCODE -eq 1) 'risk task filter preserves exact identity case'
} finally { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
