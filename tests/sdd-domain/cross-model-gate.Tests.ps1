# ADR-0051 retires v1's external panel and elevation token. The T-011 suite
# remains at 51eab721:tests/sdd-domain/cross-model-gate.Tests.ps1, with
# specs/sdd-domain and the original quality-gate reports. Exercise the actual
# local decision boundaries exposed by the current domain-model entry.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$domainPlugin = Join-Path $repoRoot 'plugins/sdd-domain'
$softGuard = Join-Path $repoRoot 'plugins/sdd-quality-loop/scripts/v2/sdd-soft-guard.mjs'

Describe 'domain-model review uses the two local perspectives' {
    It 'routes the public host command to the same review skill' {
        $command = Get-Content -Raw -Encoding UTF8 (Join-Path $domainPlugin 'commands/sdd-domain/domain-model.toml')
        $router = Get-Content -Raw -Encoding UTF8 (Join-Path $domainPlugin 'skills/domain-model/SKILL.md')
        $command | Should Match 'skills/domain-model/SKILL\.md'
        $command | Should Match 'never set `Domain-Model-Status: Approved` on behalf of the human'
        $router | Should Match '(?m)^\| `review` \| No \| `domain-review-loop`'
        $router | Should Match 'reports/domain-review/latest\.md'
    }

    It 'retains the local outcome and the owner of the report and review transition' {
        $review = Get-Content -Raw -Encoding UTF8 (Join-Path $domainPlugin 'skills/domain-review-loop/SKILL.md')
        $review | Should Match '各レビュアーには他方の生出力を見せない'
        $review | Should Match '外部クロスモデル送信や権限昇格トークンによるロック解除は行わない'
        $review | Should Match '`Reviewed` 遷移およびレポート出力は親オーケストレータの責務'
        $review | Should Match 'いずれかに Critical / Major あり.*`NEEDS_FIX`.*停止'
    }

    It 'publishes no panel invocation or legacy token instruction on the active route' {
        foreach ($path in 'commands/sdd-domain/domain-model.toml','skills/domain-model/SKILL.md','skills/domain-review-loop/SKILL.md','agents/domain-reviewer-a.md','agents/domain-reviewer-b.md') {
            $active = (Get-Content -Raw -Encoding UTF8 (Join-Path $domainPlugin $path)) -split '(?m)^## Contract Boundary:', 2
            $active[0] | Should Not Match 'prepare-panelist-input|check-cross-model|SDD_SUDO|sdd-panelist-(gpt|gemini)'
        }
    }
}

Describe 'real v2 domain approval guard on each shipped decision protocol' {
    $cases = foreach ($emit in 'exit','copilot','gemini','antigravity') {
        foreach ($next in 'Reviewed','Approved') {
            @{ Emit = $emit; Next = $next }
        }
    }
    It '<Emit> adjudicates a local edit from Pending to <Next> and leaves the file intact' -TestCases $cases {
        param($Emit, $Next)
        $root = Join-Path $TestDrive "$Emit-$Next"
        $domain = New-Item -ItemType Directory -Path (Join-Path $root 'domain') -Force
        $file = Join-Path $domain.FullName 'context-map.md'
        $before = 'Domain-Model-Status: Pending'
        $after = "Domain-Model-Status: $Next"
        [IO.File]::WriteAllText($file, $before)
        switch ($Emit) {
            'copilot' { $payload = @{ toolName='edit'; toolArgs=@{ file_path=$file; old_string=$before; new_string=$after }; cwd=$root } }
            'gemini' { $payload = @{ tool_name='replace'; tool_input=@{ file_path=$file; old_string=$before; new_string=$after }; cwd=$root } }
            'antigravity' { $payload = @{ toolCall=@{ name='edit_file'; args=@{ Path=$file; Target=$before; Replacement=$after } }; cwd=$root } }
            default { $payload = @{ tool_name='Edit'; tool_input=@{ file_path=$file; old_string=$before; new_string=$after }; cwd=$root } }
        }
        $inputJson = $payload | ConvertTo-Json -Depth 6 -Compress
        $previousPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            $output = $inputJson | & node $softGuard --root $root --emit $Emit 2>&1
            $code = $LASTEXITCODE
        } finally { $ErrorActionPreference = $previousPreference }
        $text = $output -join [Environment]::NewLine
        $approved = $Next -ceq 'Approved'
        if ($Emit -eq 'exit') {
            $expectedCode = if ($approved) { 2 } else { 0 }
            $code | Should Be $expectedCode
        } else {
            $code | Should Be 0
            $decision = $text | ConvertFrom-Json
            $expected = if ($approved) { 'deny' } else { 'allow' }
            if ($Emit -eq 'copilot') { $decision.permissionDecision | Should BeExactly $expected }
            else { $decision.decision | Should BeExactly $expected }
        }
        if ($approved) { $text | Should Match 'Domain-Model-Status: Approved' }
        [IO.File]::ReadAllText($file) | Should BeExactly $before
    }
}
