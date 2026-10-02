[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$FixtureRoot,
    [Parameter(Mandatory=$true)][string]$NodeExecutable,
    [Parameter(Mandatory=$true)][ValidatePattern('^[a-fA-F0-9]{64}$')][string]$NodeSha256
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
. (Join-Path $repo 'scripts/common.ps1')
$parent=Assert-PrivateLabRoot -LabRoot $FixtureRoot -RepoRoot $repo
$run=Join-Path $parent ('vm-capsule-tests-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $run | Out-Null
$folder=Join-Path $repo 'tests/lab/windows-sandbox'
$prepare=Join-Path $folder 'prepare.ps1'
$passed=0
function Check([bool]$value,[string]$label) { if (-not $value) { throw $label }; $script:passed++; Write-Host ('PASS '+$label) }
foreach ($file in @($prepare,(Join-Path $folder 'guest-dummy.ps1'))) {
    $tokens=$null; $errors=$null
    [Management.Automation.Language.Parser]::ParseFile($file,[ref]$tokens,[ref]$errors) | Out-Null
    Check ($errors.Count -eq 0) ('PowerShell syntax: '+(Split-Path $file -Leaf))
}
& $NodeExecutable --check (Join-Path $folder 'dummy.mjs')
Check ($LASTEXITCODE -eq 0) 'Node syntax only; fixture not executed'
$hostRefused=$false
try { & (Join-Path $folder 'guest-dummy.ps1') } catch { $hostRefused=$_.Exception.Message -like '*refusing host execution*' }
Check $hostRefused 'Guest driver refuses this non-Sandbox host before fixture writes/actors'
$runtime=Read-JsonFile (Join-Path $repo 'manifests/runtime.lock.json')
$config=Join-Path $run 'machine.json'; $lab=Join-Path $run 'lab space & unicode-демо'
[IO.File]::WriteAllText($config,(@{schemaVersion=1;repoRoot=$repo;labRoot=$lab;expectedPiVersion=$runtime.runtime.pi.version} | ConvertTo-Json))
& (Join-Path $repo 'scripts/lab-stand.ps1') -Config $config -Prepare | Out-Null
$before=@(Get-ChildItem -LiteralPath $lab -Force -Recurse | ForEach-Object FullName)
$result=& $prepare -Config $config -NodeExecutable $NodeExecutable -NodeSha256 $NodeSha256 | Out-String | ConvertFrom-Json
$after=@(Get-ChildItem -LiteralPath $lab -Force -Recurse | ForEach-Object FullName)
Check ($result.status -eq 'PLAN_VM_CAPSULE_SOURCE_ONLY_PASS' -and -not $result.prepared -and @(Compare-Object $before $after).Count -eq 0) 'Default PLAN writes no capsule'
$bad=$false
try { & $prepare -Config $config -NodeExecutable $NodeExecutable -NodeSha256 ('0'*64) | Out-Null } catch { $bad=$_.Exception.Message -like '*fingerprint refused*' }
Check $bad 'Wrong Node identity refused before preparation'
$result=& $prepare -Config $config -NodeExecutable $NodeExecutable -NodeSha256 $NodeSha256 -Prepare | Out-String | ConvertFrom-Json
Check ($result.status -eq 'PREPARED_VM_CAPSULE_ONLY_NOT_LAUNCH_APPROVAL' -and $result.actors -eq 0 -and -not $result.featureChanges) 'Explicit preparation: files only, no VM/feature activation'
$packet=$result.packet; [xml]$xml=Get-Content -LiteralPath (Join-Path $packet 'dummy.wsb') -Raw -Encoding UTF8
$maps=@($xml.Configuration.MappedFolders.MappedFolder)
Check ($maps.Count -eq 2 -and $maps[0].ReadOnly -ceq 'true' -and $maps[1].ReadOnly -ceq 'false' -and $maps[0].HostFolder -ceq (Join-Path $packet 'input') -and $maps[1].HostFolder -ceq (Join-Path $packet 'output')) 'Exact scoped mapping/Unicode/XML escaping'
foreach ($field in @('vGPU','Networking','AudioInput','VideoInput','PrinterRedirection','ClipboardRedirection')) { Check ($xml.Configuration.$field -ceq 'Disable') ($field+' explicitly disabled') }
Check ($xml.Configuration.ProtectedClient -ceq 'Enable') 'Protected client explicitly requested, not inferred as actual proof'
$guest=Read-JsonFile (Join-Path $packet 'input/config.json')
Check ($guest.nodeVersion -ceq $runtime.runtime.node -and $guest.timeoutMs -eq 45000 -and @($guest.sourceHashes.PSObject.Properties).Count -eq 2) 'Generated guest identity/bounds/source inventory'
$inventory=Read-JsonFile (Join-Path $packet 'inputs.json')
Check (@($inventory.inputs).Count -eq 7) 'Only declared source/config/Node/canary/WSB capsule inputs'
Check (@(Get-ChildItem -LiteralPath (Join-Path $packet 'output') -Force).Count -eq 0) 'Output export remains empty: no guest actor ran'
Write-Host ('VM_CAPSULE_FILESYSTEM_TESTS_PASS '+$passed+'; VM/guest/Pi/SDK actors 0; native/VM acceptance NOT TESTED')
