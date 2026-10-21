"""Bounded native .NET ZIP long-path probe; standalone child per mode."""
import json,os,pathlib,subprocess,tempfile,zipfile
names=['top/'+'/'.join(['historical-evidence']*16)+'/file.txt', 'top/'+'/'.join(['日本語']*30)+'/日本語.txt']
script=r'''
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$destination=$env:ZIP_PROBE_DEST
if ($env:ZIP_PROBE_MODE -eq 'extended') { $destination='\\?\'+$destination }
if ($env:ZIP_PROBE_MODE -eq 'switches') {
 [AppContext]::SetSwitch('Switch.System.IO.UseLegacyPathHandling', $false)
 [AppContext]::SetSwitch('Switch.System.IO.BlockLongPaths', $false)
}
try {
 [IO.Compression.ZipFile]::ExtractToDirectory($env:ZIP_PROBE_ARCHIVE,$destination)
 $names=Get-Content -Raw -Encoding UTF8 -LiteralPath $env:ZIP_PROBE_NAMES | ConvertFrom-Json
 $checks=@($names | ForEach-Object { $path=[IO.Path]::Combine($destination,$_); [ordered]@{length=$path.Length;exact=([Convert]::ToBase64String([IO.File]::ReadAllBytes($path)) -ceq 'cGF5bG9hZA==')} })
 [ordered]@{mode=$env:ZIP_PROBE_MODE;ps=$PSVersionTable.PSVersion.ToString();success=$true;checks=$checks} | ConvertTo-Json -Depth 4 -Compress
} catch {
 [ordered]@{mode=$env:ZIP_PROBE_MODE;ps=$PSVersionTable.PSVersion.ToString();success=$false;exception=$_.Exception.ToString()} | ConvertTo-Json -Compress
}
'''
with tempfile.TemporaryDirectory(prefix='sdd-zip-long-') as raw:
 root=pathlib.Path(raw);archive=root/'input.zip'
 with zipfile.ZipFile(archive,'w') as z:
  for name in names:z.writestr(name,b'payload')
 (root/'names.json').write_text(json.dumps(names),encoding='utf-8');(root/'probe.ps1').write_text(script,encoding='utf-8')
 for mode in ['normal','extended','switches']:
  env=dict(os.environ,ZIP_PROBE_ARCHIVE=str(archive),ZIP_PROBE_DEST=str(root/mode),ZIP_PROBE_MODE=mode,ZIP_PROBE_NAMES=str(root/'names.json'))
  p=subprocess.run([os.environ.get('PWSH','pwsh'),'-NoProfile','-NonInteractive','-File',str(root/'probe.ps1')],env=env,capture_output=True,text=True,errors='replace')
  print(json.dumps({'mode':mode,'exit':p.returncode,'stdout':p.stdout,'stderr':p.stderr},ensure_ascii=True),flush=True)
