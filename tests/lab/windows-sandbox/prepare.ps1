[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Config,
    [Parameter(Mandatory=$true)][string]$NodeExecutable,
    [Parameter(Mandatory=$true)][ValidatePattern('^[a-fA-F0-9]{64}$')][string]$NodeSha256,
    [switch]$Prepare
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
. (Join-Path $repo 'scripts/common.ps1')
$plan=& (Join-Path $repo 'scripts/lab-stand.ps1') -Config $Config
if (-not $? -or ($plan | Out-String) -notmatch 'PLAN_PREPARED_PASS') { throw 'Fresh verified prepared stand required' }
$c=Read-JsonFile $Config
$lab=Assert-PrivateLabRoot -LabRoot $c.labRoot -RepoRoot $repo
Assert-NoLabReparseTree -Root $lab
if ($NodeExecutable -notmatch '^[a-zA-Z]:[\\/]' -or $NodeExecutable -match '\.\.|[<>|*?]') { throw 'Explicit local Node path required' }
$node=[IO.Path]::GetFullPath($NodeExecutable)
if (-not (Test-Path -LiteralPath $node -PathType Leaf) -or (Split-Path $node -Leaf) -ine 'node.exe') { throw 'Explicit Node executable missing' }
$cursor=$node
while ($cursor) {
    if ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Node reparse ancestor refused' }
    $parent=[IO.Directory]::GetParent($cursor); if ($null -eq $parent) { break }; $cursor=$parent.FullName
}
if ((Get-FileHash -LiteralPath $node -Algorithm SHA256).Hash -ine $NodeSha256) { throw 'Node input fingerprint refused' }
$runtime=Read-JsonFile (Join-Path $repo 'manifests/runtime.lock.json')
$sourceHashes=@{}
foreach ($name in @('guest-dummy.ps1','dummy.mjs')) {
    $file=Join-Path $PSScriptRoot $name
    if ((Get-Item -LiteralPath $file).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Source link refused' }
    $sourceHashes[$name]=(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()
}
$result=[ordered]@{
    status='PLAN_VM_CAPSULE_SOURCE_ONLY_PASS'; actors=0; provisioning=$false; featureChanges=$false
    mode='VM_DUMMY_ONLY'; prepared=$false; nodeVersion=$runtime.runtime.node
    limitations=@('No VM launch or runtime acceptance.','Separate owner permission required for host feature enable.','Host launch timeout/source preservation/VM cleanup and independent actual raw review remain mandatory.')
}
if (-not $Prepare) { $result | ConvertTo-Json -Depth 5; return }
$id=[guid]::NewGuid().ToString('N')
$packet=Join-Path (Join-Path $lab 'evidence') ('windows-sandbox-'+$id)
if (Test-Path -LiteralPath $packet) { throw 'Fresh capsule required' }
$inputRoot=Join-Path $packet 'input'; $outputRoot=Join-Path $packet 'output'
foreach ($path in @($packet,$inputRoot,$outputRoot,(Join-Path $inputRoot 'canary'))) { New-Item -ItemType Directory -Path $path | Out-Null }
foreach ($name in $sourceHashes.Keys) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination (Join-Path $inputRoot $name)
    if ((Get-FileHash -LiteralPath (Join-Path $inputRoot $name) -Algorithm SHA256).Hash.ToLowerInvariant() -cne $sourceHashes[$name]) { throw 'Copied source drift' }
}
Copy-Item -LiteralPath $node -Destination (Join-Path $inputRoot 'node.exe')
if ((Get-FileHash -LiteralPath (Join-Path $inputRoot 'node.exe') -Algorithm SHA256).Hash -ine $NodeSha256) { throw 'Copied Node drift' }
[IO.File]::WriteAllText((Join-Path $inputRoot 'canary\working-memory-shaped.txt'),"SYNTHETIC VM CANARY ONLY`r`n")
$guestConfig=@{schemaVersion=1; kind='VM_DUMMY_ONLY'; runId=$id; nodeVersion=$runtime.runtime.node; nodeSha256=$NodeSha256.ToLowerInvariant(); sourceHashes=$sourceHashes; timeoutMs=45000}
[IO.File]::WriteAllText((Join-Path $inputRoot 'config.json'),($guestConfig | ConvertTo-Json -Depth 6))
$finish=@'
@echo off
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\PiLabInput\guest-dummy.ps1 1>C:\PiLabOutput\guest-helper-stdout.txt 2>C:\PiLabOutput\guest-helper-stderr.txt
set RUN_EXIT=%ERRORLEVEL%
echo %RUN_EXIT% > C:\PiLabOutput\helper-exit.txt
C:\Windows\System32\shutdown.exe /s /t 0
exit /b %RUN_EXIT%
'@
[IO.File]::WriteAllText((Join-Path $inputRoot 'finish.cmd'),$finish)
$inXml=[Security.SecurityElement]::Escape($inputRoot)
$outXml=[Security.SecurityElement]::Escape($outputRoot)
$xml=@"
<Configuration>
  <vGPU>Disable</vGPU>
  <Networking>Disable</Networking>
  <AudioInput>Disable</AudioInput>
  <VideoInput>Disable</VideoInput>
  <ProtectedClient>Enable</ProtectedClient>
  <PrinterRedirection>Disable</PrinterRedirection>
  <ClipboardRedirection>Disable</ClipboardRedirection>
  <MemoryInMB>4096</MemoryInMB>
  <MappedFolders>
    <MappedFolder><HostFolder>$inXml</HostFolder><SandboxFolder>C:\PiLabInput</SandboxFolder><ReadOnly>true</ReadOnly></MappedFolder>
    <MappedFolder><HostFolder>$outXml</HostFolder><SandboxFolder>C:\PiLabOutput</SandboxFolder><ReadOnly>false</ReadOnly></MappedFolder>
  </MappedFolders>
  <LogonCommand><Command>C:\Windows\System32\cmd.exe /d /c C:\PiLabInput\finish.cmd</Command></LogonCommand>
</Configuration>
"@
$null=[xml]$xml
[IO.File]::WriteAllText((Join-Path $packet 'dummy.wsb'),$xml)
$inventory=@()
foreach ($file in (Get-ChildItem -LiteralPath $packet -File -Recurse)) {
    $inventory+=@{path=$file.FullName.Substring($packet.Length+1); sha256=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant(); bytes=$file.Length}
}
[IO.File]::WriteAllText((Join-Path $packet 'inputs.json'),(@{schemaVersion=1; kind='PREPARED_VM_CAPSULE_ONLY_NOT_LAUNCH_APPROVAL'; inputs=$inventory} | ConvertTo-Json -Depth 6))
$result.status='PREPARED_VM_CAPSULE_ONLY_NOT_LAUNCH_APPROVAL'
$result.prepared=$true; $result.packet=$packet
$result | ConvertTo-Json -Depth 5
# Intentionally no WindowsSandbox.exe, Start-Process, feature enable or retry.
