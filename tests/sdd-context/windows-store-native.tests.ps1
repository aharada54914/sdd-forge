$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'native Windows required; not executed' }
$helper = Join-Path $PSScriptRoot '../../plugins/sdd-context/windows-store.ps1'
$root = Join-Path ([IO.Path]::GetTempPath()) ('sdd-private-' + [Guid]::NewGuid().ToString('N'))
$external = Join-Path ([IO.Path]::GetTempPath()) ('sdd-external-' + [Guid]::NewGuid().ToString('N'))
$junctions = @()
try {
  $parent = Join-Path $root '.sdd'
  [IO.Directory]::CreateDirectory($parent) | Out-Null
  $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User
  $parentAcl = Get-Acl -LiteralPath $parent
  $parentAcl.SetOwner($sid)
  Set-Acl -LiteralPath $parent -AclObject $parentAcl
  if (-not (Get-Acl -LiteralPath $parent).GetOwner([Security.Principal.SecurityIdentifier]).Equals($sid)) {
    throw 'fixture parent owner mismatch'
  }
  $store = Join-Path $parent 'context'
  $result = & pwsh -NoLogo -NoProfile -NonInteractive -File $helper -Store $store
  if ($LASTEXITCODE -ne 0 -or $result -cne 'created') { throw 'fresh creation failed' }
  $acl = Get-Acl -LiteralPath $store
  if (-not $acl.AreAccessRulesProtected -or -not $acl.GetOwner([Security.Principal.SecurityIdentifier]).Equals($sid)) {
    throw 'private owner/protection mismatch'
  }
  $rules = @($acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]))
  if ($rules.Count -ne 1 -or -not $rules[0].IdentityReference.Equals($sid) -or
      $rules[0].AccessControlType -ne [Security.AccessControl.AccessControlType]::Allow -or
      $rules[0].FileSystemRights -ne [Security.AccessControl.FileSystemRights]::FullControl -or
      $rules[0].InheritanceFlags -ne ([Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [Security.AccessControl.InheritanceFlags]::ObjectInherit) -or
      $rules[0].PropagationFlags -ne [Security.AccessControl.PropagationFlags]::None) { throw 'private rights mismatch' }
  $content = Join-Path $store 'synthetic.txt'
  [IO.File]::WriteAllText($content, 'ordinary synthetic fixture')
  $before = $acl.Sddl
  $result = & pwsh -NoLogo -NoProfile -NonInteractive -File $helper -Store $store
  if ($LASTEXITCODE -eq 0 -or $result -or (Get-Acl -LiteralPath $store).Sddl -cne $before -or
      [IO.File]::ReadAllText($content) -cne 'ordinary synthetic fixture') { throw 'existing target changed' }
  [IO.Directory]::CreateDirectory($external) | Out-Null
  $externalContent = Join-Path $external 'synthetic.txt'
  [IO.File]::WriteAllText($externalContent, 'outside synthetic fixture')
  $externalAcl = (Get-Acl -LiteralPath $external).Sddl
  $leafParent = Join-Path $root 'junction-leaf/.sdd'
  [IO.Directory]::CreateDirectory($leafParent) | Out-Null
  $leafParentAcl = Get-Acl -LiteralPath $leafParent
  $leafParentAcl.SetOwner($sid)
  Set-Acl -LiteralPath $leafParent -AclObject $leafParentAcl
  if (-not (Get-Acl -LiteralPath $leafParent).GetOwner([Security.Principal.SecurityIdentifier]).Equals($sid)) {
    throw 'fixture leaf parent owner mismatch'
  }
  $leafStore = Join-Path $leafParent 'context'
  New-Item -ItemType Junction -Path $leafStore -Target $external | Out-Null
  $junctions += $leafStore
  $result = & pwsh -NoLogo -NoProfile -NonInteractive -File $helper -Store $leafStore
  if ($LASTEXITCODE -eq 0 -or $result -or
      [IO.File]::ReadAllText($externalContent) -cne 'outside synthetic fixture' -or
      (Get-Acl -LiteralPath $external).Sddl -cne $externalAcl) {
    throw 'store junction was accepted or external target changed'
  }
  $junctionRoot = Join-Path $root 'junction-parent'
  [IO.Directory]::CreateDirectory($junctionRoot) | Out-Null
  $parentJunction = Join-Path $junctionRoot '.sdd'
  New-Item -ItemType Junction -Path $parentJunction -Target $external | Out-Null
  $junctions += $parentJunction
  $result = & pwsh -NoLogo -NoProfile -NonInteractive -File $helper -Store (Join-Path $parentJunction 'context')
  if ($LASTEXITCODE -eq 0 -or $result -or
      (Test-Path -LiteralPath (Join-Path $external 'context')) -or
      [IO.File]::ReadAllText($externalContent) -cne 'outside synthetic fixture' -or
      (Get-Acl -LiteralPath $external).Sddl -cne $externalAcl) {
    throw 'parent junction was accepted or external target changed'
  }
  $adapterParent = Join-Path $root 'adapter/.sdd'
  [IO.Directory]::CreateDirectory($adapterParent) | Out-Null
  $adapterParentAcl = Get-Acl -LiteralPath $adapterParent
  $adapterParentAcl.SetOwner($sid)
  Set-Acl -LiteralPath $adapterParent -AclObject $adapterParentAcl
  $adapterStore = Join-Path $adapterParent 'context'
  $adapterProbe = Join-Path $PSScriptRoot 'windows-store-adapter-native.mjs'
  & node $adapterProbe $adapterStore
  if ($LASTEXITCODE -ne 0) { throw 'production adapter could not create a fresh store within its deadline' }
  $adapterAcl = Get-Acl -LiteralPath $adapterStore
  if (-not $adapterAcl.AreAccessRulesProtected -or
      -not $adapterAcl.GetOwner([Security.Principal.SecurityIdentifier]).Equals($sid)) {
    throw 'production adapter private owner/protection mismatch'
  }
  $startup = (Measure-Command { & pwsh -NoLogo -NoProfile -NonInteractive -Command 'exit 0' }).TotalMilliseconds
  if ($LASTEXITCODE -ne 0) { throw 'PowerShell startup control failed' }
  $definition = [regex]::Match((Get-Content -LiteralPath $helper -Raw), "(?s)Add-Type -TypeDefinition @'\r?\n(.*?)\r?\n'@")
  if (-not $definition.Success) { throw 'native source definition unavailable' }
  $compile = (Measure-Command { Add-Type -TypeDefinition $definition.Groups[1].Value }).TotalMilliseconds
  Write-Output ('native win32 pwsh_start_ms={0:F1} add_type_ms={1:F1}' -f $startup, $compile)
  $env:SDD_CONTEXT_NATIVE_ISOLATED = '1'
  $validationProbe = Join-Path $PSScriptRoot 'validation.test.mjs'
  & node --test '--test-name-pattern=NEW-STORE-NATIVE-DEADLINE|WINDOWS-NATIVE-COST-DIAGNOSTIC' $validationProbe
  if ($LASTEXITCODE -ne 0) { throw 'isolated native preparation did not satisfy its deadline' }
  Write-Output 'Windows native private creation, existing-directory preservation and junction rejection passed'
} finally {
  Remove-Item Env:SDD_CONTEXT_NATIVE_ISOLATED -ErrorAction SilentlyContinue
  foreach ($junction in $junctions) {
    $item = Get-Item -LiteralPath $junction -Force -ErrorAction Stop
    if (-not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
      throw 'fixture junction changed; recursive cleanup stopped'
    }
    [IO.Directory]::Delete($junction)
  }
  if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
  if (Test-Path -LiteralPath $external) { Remove-Item -LiteralPath $external -Recurse -Force }
}
exit 0
