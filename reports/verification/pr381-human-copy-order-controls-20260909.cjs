const fs = require('node:fs');
const { spawnSync } = require('node:child_process');
const root = process.argv[2];
if (!root) throw new Error('checkout required');
const source = fs.readFileSync(`${root}/tests/human-copy-runner-contract.tests.ps1`, 'utf8');
const match = source.match(/^\$RunAllSh = [\s\S]*?(?=^if \(-not \(Test-Path -LiteralPath \$CiDraftPath)/m);
if (!match) throw new Error('actual registration block not found');
const first = 'tests/human-copy-runner-contract.tests.sh';
const second = 'tests/check-risk-upgrade-byte-identical.tests.sh';
const cases = [
  ['real', [first, second], 0], ['exact', [first, second], 0],
  ['failed-list', [first, second], 1], ['reversed', [second, first], 1],
  ['missing-first', [second], 1], ['missing-second', [first], 1],
  ['near-first', [`${first}.bak`, second], 1], ['near-second', [first, `${second}.bak`], 1],
  ['case-first', [first.toUpperCase(), second], 1], ['case-second', [first, second.toUpperCase()], 1],
  ['ps-missing', [first, second], 1], ['ps-reversed', [first, second], 1],
];
let failures = 0;
for (const [name, entries, expected] of cases) {
  const input = `$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$RepoRoot = $env:ROOT
function Ok { }
function Bad { exit 1 }
if ($env:MODE -ne 'real') {
  function bash {
    $global:LASTEXITCODE = if ($env:MODE -eq 'failed-list') { 7 } else { 0 }
    $env:LISTING -split '\\n'
  }
}
function Get-Content {
  param([string]$LiteralPath, [switch]$Raw)
  if ($LiteralPath.EndsWith('run-all.ps1', [StringComparison]::Ordinal)) {
    if ($env:MODE -eq 'ps-missing') { return 'unrelated' }
    if ($env:MODE -eq 'ps-reversed') { return "tests/check-risk-upgrade-byte-identical.tests.ps1 tests/human-copy-runner-contract.tests.ps1" }
  }
  Microsoft.PowerShell.Management\\Get-Content -LiteralPath $LiteralPath -Raw
}
${match[0]}
exit 0
`;
  const run = spawnSync('pwsh', ['-NoProfile', '-NonInteractive', '-Command', input], { encoding: 'utf8', env: { ...process.env, ROOT: root, MODE: name, LISTING: entries.join('\n') } });
  const ok = !run.error && !run.signal && run.status === expected;
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'} ${name}: expected=${expected} actual=${run.status}`);
  if (run.error || run.stderr) console.error(run.error || run.stderr);
}
console.log(`controls: ${cases.length - failures} passed, ${failures} failed`);
process.exitCode = failures ? 1 : 0;
