[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$FixtureRoot)
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $repo 'scripts/common.ps1')
$exe = (Get-Process -Id $PID).Path
$version = (Read-JsonFile (Join-Path $repo 'manifests/runtime.lock.json')).runtime.pi.version
$sid = [Security.Principal.WindowsIdentity]::GetCurrent().User
$utf8 = New-Object Text.UTF8Encoding($false)
$passed = 0
$caseNumber = 0
$FixtureRoot = Assert-PrivateLabRoot -LabRoot $FixtureRoot -RepoRoot $repo
$fixtureAcl = Get-Acl -LiteralPath $FixtureRoot
$fixtureOwner = (New-Object Security.Principal.NTAccount($fixtureAcl.Owner)).Translate([Security.Principal.SecurityIdentifier]).Value
$fixtureRules = @($fixtureAcl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]))
if ($fixtureOwner -ne $sid.Value -or $fixtureRules.Count -ne 1 -or $fixtureRules[0].IdentityReference.Value -ne $sid.Value -or $fixtureRules[0].AccessControlType -ne [Security.AccessControl.AccessControlType]::Allow) { throw 'FixtureRoot must be an owner-only private directory.' }
$fixture = Join-Path $FixtureRoot ('stand-tests-' + [guid]::NewGuid().ToString('N'))
$security = New-Object Security.AccessControl.DirectorySecurity
$security.SetAccessRuleProtection($true, $false)
$security.SetOwner($sid)
$security.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule($sid, [Security.AccessControl.FileSystemRights]::FullControl, ([Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [Security.AccessControl.InheritanceFlags]::ObjectInherit), [Security.AccessControl.PropagationFlags]::None, [Security.AccessControl.AccessControlType]::Allow)))
[IO.Directory]::CreateDirectory($fixture, $security) | Out-Null
$runner = Join-Path $fixture 'runner'
foreach ($name in @('home','appdata','localappdata','temp','npm-cache','npm-config')) { [IO.Directory]::CreateDirectory((Join-Path $runner $name)) | Out-Null }
$runnerEnv = Get-LabChildEnvironment -LabRoot $runner -NpmPrefix (Join-Path $runner 'npm-prefix')
$runnerEnv['PATH'] = "$env:SystemRoot\System32;$env:SystemRoot;" + (Split-Path $exe -Parent)

function Check {
    param([string]$Name, [bool]$Condition)
    if (-not $Condition) { throw "FAIL $Name" }
    $script:passed++
    Write-Output "PASS $Name"
}
function Config-File {
    param([string]$Root, [hashtable]$Changes = @{})
    $c = [ordered]@{ schemaVersion=1; repoRoot=$repo; labRoot=$Root; expectedPiVersion=$version }
    foreach ($key in $Changes.Keys) { $c[$key] = $Changes[$key] }
    $p = Join-Path $fixture ('config-' + [guid]::NewGuid().ToString('N') + '.json')
    [IO.File]::WriteAllText($p, ($c | ConvertTo-Json), $utf8)
    return $p
}
function Invoke-Stand {
    param([string]$Path, [switch]$Prepare, [string]$Entry = (Join-Path $repo 'scripts/lab-stand.ps1'))
    $argsList = @('-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$Entry,'-Config',$Path)
    if ($Prepare) { $argsList += '-Prepare' }
    $r = Get-CommandOutput -Command $exe -Arguments $argsList -SanitizeEnvironment -Environment $runnerEnv -WorkingDirectory $runner
    $script:caseNumber++
    [IO.File]::WriteAllText((Join-Path $fixture ('case-' + $script:caseNumber + '.json')), ($r | ConvertTo-Json), $utf8)
    return $r
}
function Snapshot {
    param([string]$Root)
    $map = [ordered]@{}
    foreach ($p in (@(Get-Item -LiteralPath $Root) + @(Get-ChildItem -LiteralPath $Root -Force -Recurse) | Sort-Object FullName)) {
        $data = @($p.PSIsContainer, $p.LastWriteTimeUtc.Ticks, (Get-Acl -LiteralPath $p.FullName).Sddl)
        if (-not $p.PSIsContainer) { $data += (Get-FileHash -LiteralPath $p.FullName -Algorithm SHA256).Hash }
        $map[$p.FullName] = $data
    }
    return ($map | ConvertTo-Json -Compress -Depth 4)
}

try {
    $lab = Join-Path $fixture 'lab with space'
    $config = Config-File $lab
    $plan = Invoke-Stand $config
    # Only caller-owned case receipt is outside the planned lab; no target was created.
    Check 'fresh PLAN pass and no lab creation' ($plan.ExitCode -eq 0 -and $plan.Output.Contains('PLAN_NEW_PASS') -and -not (Test-Path -LiteralPath $lab))
    Check 'PLAN routes redacted and no actor claim' (-not $plan.Output.Contains($fixture) -and $plan.Output.Contains('"actorLaunches":0') -and $plan.Output.Contains('"environmentApplied":false'))
    $prepared = Invoke-Stand $config -Prepare
    Check 'PREPARE exact synthetic state' ($prepared.ExitCode -eq 0 -and $prepared.Output.Contains('PREPARED_SOURCE_ONLY'))
    Check 'only two profile directories' (@(Get-ChildItem -LiteralPath (Join-Path $lab 'pi-root')).Count -eq 2)
    $snapshot = Snapshot $lab
    $noop = Invoke-Stand $config -Prepare
    Check 'verified prepared NO-OP byte/type/ACL/mtime equality' ($noop.ExitCode -eq 0 -and $noop.Output.Contains('VERIFIED_PREPARED_NO_OP') -and $snapshot -eq (Snapshot $lab))
    $inspect = Invoke-Stand $config
    Check 'prepared PLAN zero target writes' ($inspect.ExitCode -eq 0 -and $inspect.Output.Contains('PLAN_PREPARED_PASS') -and $snapshot -eq (Snapshot $lab))
    $lab2 = Join-Path $fixture ('lab-' + [char]0x041F + [char]0x0440 + [char]0x0438 + [char]0x043C + [char]0x0435 + [char]0x0440)
    $config2 = Config-File $lab2
    $second = Invoke-Stand $config2 -Prepare
    Check 'second root Unicode accepted' ($second.ExitCode -eq 0)
    $scope1 = ($prepared.Output | ConvertFrom-Json).intercomScope
    $scope2 = ($second.Output | ConvertFrom-Json).intercomScope
    Check 'unique per-root scope, same both profiles' ($scope1 -ne $scope2 -and (Get-LabChildEnvironment $lab (Join-Path $lab 'npm-prefix') 'task')['PI_INTERCOM_SCOPE_ID'] -eq $scope1)
    $replayLab = Join-Path $fixture 'replay-lab'
    $replayConfig = Config-File $replayLab
    Check 'replay fixture prepared' ((Invoke-Stand $replayConfig -Prepare).ExitCode -eq 0)
    Copy-Item -LiteralPath (Join-Path $lab '.stand-manifest.json') -Destination (Join-Path $replayLab '.stand-manifest.json') -Force
    Check 'state replay under a different root refused' ((Invoke-Stand $replayConfig -Prepare).ExitCode -ne 0)
    $typeLab = Join-Path $fixture 'state-type-lab'
    $typeConfig = Config-File $typeLab
    Check 'state-type fixture prepared' ((Invoke-Stand $typeConfig -Prepare).ExitCode -eq 0)
    $typeStatePath = Join-Path $typeLab '.stand-manifest.json'
    $typeState = Read-JsonFile $typeStatePath
    $typeState.piVersion = @($version, $version)
    [IO.File]::WriteAllText($typeStatePath, ($typeState | ConvertTo-Json -Depth 4), $utf8)
    Check 'array coercion cannot pass state scalar version identity' ((Invoke-Stand $typeConfig -Prepare).ExitCode -ne 0)
    $unknownLab = Join-Path $fixture 'unknown-file-lab'
    $unknownConfig = Config-File $unknownLab
    Check 'unknown-file fixture prepared' ((Invoke-Stand $unknownConfig -Prepare).ExitCode -eq 0)
    [IO.File]::WriteAllText((Join-Path $unknownLab 'memory/memory.db'), 'EXAMPLE_SYNTHETIC_NOT_SQLITE', $utf8)
    $unknownResult = Invoke-Stand $unknownConfig -Prepare
    Check 'unknown synthetic DB refused at metadata gate, not read/hashed' ($unknownResult.ExitCode -ne 0 -and $unknownResult.Output.Contains('PREPARED_STATE_DRIFT'))
    $movedRepo = Join-Path $fixture 'relocated source'
    foreach ($name in @('scripts/lab-stand.ps1','scripts/common.ps1','scripts/lab-preflight.ps1','config/schemas/lab-stand.schema.json','manifests/runtime.lock.json','manifests/pi-packages.lock.json','manifests/external-tools.lock.json','profiles/code/settings.template.json','profiles/task/settings.template.json')) {
        $destination = Join-Path $movedRepo $name
        [IO.Directory]::CreateDirectory((Split-Path $destination -Parent)) | Out-Null
        Copy-Item -LiteralPath (Join-Path $repo $name) -Destination $destination
        Check ('source byte copy ' + $name) ((Get-FileHash -LiteralPath (Join-Path $repo $name)).Hash -eq (Get-FileHash -LiteralPath $destination).Hash)
    }
    $movedLab = Join-Path $fixture 'moved-source-lab'
    $movedConfig = Config-File $movedLab @{ repoRoot=$movedRepo }
    $movedEntry = Join-Path $movedRepo 'scripts/lab-stand.ps1'
    Check 'relocated source entry with separate lab accepted' ((Invoke-Stand $movedConfig -Prepare -Entry $movedEntry).ExitCode -eq 0)
    [IO.File]::AppendAllText((Join-Path $movedRepo 'scripts/common.ps1'), "`n# EXAMPLE_SOURCE_DRIFT`n", $utf8)
    Check 'source byte drift refuses prepared NO-OP' ((Invoke-Stand $movedConfig -Prepare -Entry $movedEntry).ExitCode -ne 0)
    [IO.File]::WriteAllText((Join-Path $movedRepo 'scripts/lab-preflight.ps1'), 'Write-Output "LAB PREFLIGHT PLAN: PASS"; exit 1', $utf8)
    $failedPreflight = Invoke-Stand (Config-File (Join-Path $fixture 'failed-preflight-lab') @{ repoRoot=$movedRepo }) -Prepare -Entry $movedEntry
    Check 'preflight exit1 is fatal even with PASS marker' ($failedPreflight.ExitCode -ne 0 -and $failedPreflight.Output.Contains('PREFLIGHT_REFUSED'))
    Check 'unknown config key refused' ((Invoke-Stand (Config-File (Join-Path $fixture 'bad-key') @{ apiKey='EXAMPLE_MUST_NOT_PROPAGATE' })).ExitCode -ne 0)
    Check 'wrong exact Pi refused' ((Invoke-Stand (Config-File (Join-Path $fixture 'bad-version') @{ expectedPiVersion='999.0.0' })).ExitCode -ne 0)
    Check 'unfilled placeholder refused' ((Invoke-Stand (Config-File '<LAB_ROOT>')).ExitCode -ne 0)
    Check 'drive root refused' ((Invoke-Stand (Config-File ([IO.Path]::GetPathRoot($fixture)))).ExitCode -ne 0)
    Check 'UNC refused' ((Invoke-Stand (Config-File '\\invalid-server\lab')).ExitCode -ne 0)
    Check 'parent traversal refused' ((Invoke-Stand (Config-File ($fixture + '\x\..\other'))).ExitCode -ne 0)
    Check 'repository overlap refused' ((Invoke-Stand (Config-File (Join-Path $repo 'never-created'))).ExitCode -ne 0)
    $liveHome = [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
    Check 'real live home refused despite sanitized child USERPROFILE' ((Invoke-Stand (Config-File (Join-Path $liveHome 'never-created'))).ExitCode -ne 0)
    $foreign = Join-Path $fixture 'foreign-git'
    [IO.Directory]::CreateDirectory((Join-Path $foreign '.git')) | Out-Null
    Check 'foreign Git ancestor refused' ((Invoke-Stand (Config-File (Join-Path $foreign 'never-created'))).ExitCode -ne 0)
    $unknown = Join-Path $fixture 'unknown-root'
    [IO.Directory]::CreateDirectory($unknown) | Out-Null
    [IO.File]::WriteAllText((Join-Path $unknown 'sentinel'), 'EXAMPLE_MUST_NOT_PROPAGATE', $utf8)
    Check 'unknown nonempty root preserved/refused' ((Invoke-Stand (Config-File $unknown) -Prepare).ExitCode -ne 0 -and (Get-Content -LiteralPath (Join-Path $unknown 'sentinel') -Raw) -eq 'EXAMPLE_MUST_NOT_PROPAGATE')
    [IO.Directory]::CreateDirectory((Join-Path $lab2 'extra-empty')) | Out-Null
    Check 'empty-directory drift refused' ((Invoke-Stand $config2 -Prepare).ExitCode -ne 0)
    $mcp = Join-Path $lab 'pi-root/agent/mcp.json'
    [IO.File]::WriteAllText($mcp, '{"mcpServers":{"EXAMPLE":{}},"settings":{"scriptMode":false}}', $utf8)
    $statePath = Join-Path $lab '.stand-manifest.json'
    $state = Read-JsonFile $statePath
    # Claiming a new baseline in mutable state cannot replace the canonical fixture contract.
    $state.inventory = '{}'
    [IO.File]::WriteAllText($statePath, ($state | ConvertTo-Json -Depth 4), $utf8)
    Check 'fixture drift and forged inventory refused without repair' ((Invoke-Stand $config -Prepare).ExitCode -ne 0)
    $aclLab = Join-Path $fixture 'acl-lab'
    $aclConfig = Config-File $aclLab
    Check 'ACL fixture prepared' ((Invoke-Stand $aclConfig -Prepare).ExitCode -eq 0)
    $aclPath = Join-Path $aclLab 'npm-config/user.npmrc'
    $acl = Get-Acl -LiteralPath $aclPath
    $untrusted = New-Object Security.Principal.SecurityIdentifier('S-1-5-11')
    $acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule($untrusted, [Security.AccessControl.FileSystemRights]::Read, [Security.AccessControl.AccessControlType]::Allow)))
    Set-Acl -LiteralPath $aclPath -AclObject $acl
    Check 'child ACL drift refused' ((Invoke-Stand $aclConfig -Prepare).ExitCode -ne 0)
    $unsafe = Join-Path $fixture 'unsafe-parent'
    [IO.Directory]::CreateDirectory($unsafe) | Out-Null
    $acl = Get-Acl -LiteralPath $unsafe
    $acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule($untrusted, [Security.AccessControl.FileSystemRights]::Modify, [Security.AccessControl.AccessControlType]::Allow)))
    Set-Acl -LiteralPath $unsafe -AclObject $acl
    $unsafeLab = Join-Path $unsafe 'never-created'
    Check 'untrusted mutable ancestor refused before write' ((Invoke-Stand (Config-File $unsafeLab) -Prepare).ExitCode -ne 0 -and -not (Test-Path -LiteralPath $unsafeLab))
    $junction = Join-Path $fixture 'junction'
    New-Item -ItemType Junction -Path $junction -Target $unknown | Out-Null
    Check 'junction ancestor refused' ((Invoke-Stand (Config-File (Join-Path $junction 'never-created'))).ExitCode -ne 0)
    $savedExample = [Environment]::GetEnvironmentVariable('PI_LAB_EXAMPLE_CREDENTIAL', 'Process')
    $savedNodeOptions = [Environment]::GetEnvironmentVariable('NODE_OPTIONS', 'Process')
    $env:PI_LAB_EXAMPLE_CREDENTIAL = 'EXAMPLE_MUST_NOT_PROPAGATE'
    $env:NODE_OPTIONS = 'EXAMPLE_MUST_NOT_PROPAGATE'
    try {
        $effective = Get-SanitizedChildEnvironment -Overrides $runnerEnv
        Check 'unknown credentials and NODE_OPTIONS excluded' (-not $effective.ContainsKey('PI_LAB_EXAMPLE_CREDENTIAL') -and -not $effective.ContainsKey('NODE_OPTIONS'))
        $probe = Get-CommandOutput -Command $exe -Arguments @('-NoProfile','-NonInteractive','-Command','if($env:PI_LAB_EXAMPLE_CREDENTIAL -or $env:NODE_OPTIONS){exit 1}; Write-Output $env:TEMP') -SanitizeEnvironment -Environment $runnerEnv -WorkingDirectory $runner
        Check 'actual PowerShell child receives private env without example keys' ($probe.ExitCode -eq 0 -and $probe.Output -eq $runnerEnv['TEMP'])
    } finally {
        [Environment]::SetEnvironmentVariable('PI_LAB_EXAMPLE_CREDENTIAL', $savedExample, 'Process')
        [Environment]::SetEnvironmentVariable('NODE_OPTIONS', $savedNodeOptions, 'Process')
    }
    [ordered]@{ status='FILESYSTEM_PREPARATION_TESTS_PASS'; passed=$passed; portability='same-machine parameterization only'; piNativeRunnerActors=0; fixtureRetained=$true } | ConvertTo-Json -Compress
} finally {
    # Retain this exact owned test tree/failures. Never clear an existing unknown stand.
    Write-Output 'Owned fixture/raw cases retained under supplied private FixtureRoot.'
}
