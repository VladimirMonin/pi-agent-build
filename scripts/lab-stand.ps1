[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Config,
    [switch]$Prepare
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
$currentSid = [Security.Principal.WindowsIdentity]::GetCurrent().User
$trusted = @($currentSid.Value, 'S-1-5-18', 'S-1-5-32-544')
$stage = 'CONFIG'

function Stand-Path {
    param([string]$Value)
    if ($Value -notmatch '^[A-Za-z]:[\\/]' -or $Value.Substring(2) -match '[*?:]' -or $Value -match '[\\/]\.\.(?:[\\/]|$)') { throw 'INVALID_PATH' }
    $full = [IO.Path]::GetFullPath($Value).TrimEnd([char[]]@('\', '/'))
    if ($full -match '^[A-Za-z]:$') { throw 'DRIVE_ROOT_REFUSED' }
    return $full
}
function Stand-Within {
    param([string]$Path, [string]$Root)
    return $Path.Equals($Root, [StringComparison]::OrdinalIgnoreCase) -or $Path.StartsWith(($Root + '\'), [StringComparison]::OrdinalIgnoreCase)
}
function Stand-Sid {
    param([object]$Identity)
    if ($Identity -is [Security.Principal.SecurityIdentifier]) { return $Identity.Value }
    if ([string]$Identity -match '^S-\d-') { return [string]$Identity }
    return (New-Object Security.Principal.NTAccount([string]$Identity)).Translate([Security.Principal.SecurityIdentifier]).Value
}
function Assert-StandAncestors {
    param([string]$Path, [switch]$Owned)
    $cursor = $Path
    $first = $true
    while ($cursor) {
        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction SilentlyContinue
        if ($item) {
            if (-not $item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'UNSAFE_ANCESTOR' }
            if (Test-Path -LiteralPath (Join-Path $cursor '.git')) { throw 'GIT_ROOT_REFUSED' }
            $acl = Get-Acl -LiteralPath $cursor
            $owner = Stand-Sid $acl.Owner
            $ownerTrusted = $owner -in $trusted
            if (-not $ownerTrusted) {
                # Windows volume owner may be this OS service; no service ACE is added.
                try { $installer = (New-Object Security.Principal.NTAccount('NT SERVICE', 'TrustedInstaller')).Translate([Security.Principal.SecurityIdentifier]).Value }
                catch { $installer = '' }
                $ownerTrusted = $owner -eq $installer
            }
            if (-not $ownerTrusted) { throw 'UNTRUSTED_OWNER' }
            if ($first -and $Owned -and ($owner -ne $currentSid.Value -or -not $acl.AreAccessRulesProtected)) { throw 'ROOT_NOT_OWNER_ONLY' }
            $rules = @($acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]))
            if ($rules.Count -eq 0) { throw 'UNKNOWN_DACL' }
            $volume = $cursor.TrimEnd('\') -eq [IO.Path]::GetPathRoot($cursor).TrimEnd('\')
            foreach ($rule in $rules) {
                if ($rule.AccessControlType -ne [Security.AccessControl.AccessControlType]::Allow -or
                    ($rule.PropagationFlags -band [Security.AccessControl.PropagationFlags]::InheritOnly)) { continue }
                $sid = Stand-Sid $rule.IdentityReference
                $mask = [long]$rule.FileSystemRights -band 0x000D0156
                # CreateDirectories alone on a volume cannot delete/replace the protected owned child.
                if ($volume) { $mask = $mask -band (-bnot 4) }
                if ($sid -notin $trusted -and $mask -ne 0) { throw 'UNTRUSTED_ANCESTOR_MUTATION' }
                if ($first -and $Owned -and $sid -ne $currentSid.Value) { throw 'ROOT_NOT_OWNER_ONLY' }
            }
        }
        $parent = [IO.Directory]::GetParent($cursor)
        if (-not $parent) { break }
        $cursor = $parent.FullName
        $first = $false
    }
}
function Stand-Inputs {
    param([string]$Repo)
    $inputs = [ordered]@{}
    foreach ($name in @('scripts/lab-stand.ps1','scripts/common.ps1','scripts/lab-preflight.ps1','config/schemas/lab-stand.schema.json','manifests/runtime.lock.json','manifests/pi-packages.lock.json','manifests/external-tools.lock.json','profiles/code/settings.template.json','profiles/task/settings.template.json')) {
        $p = Join-Path $Repo $name
        if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { throw 'SOURCE_INPUT_REFUSED' }
        $cursor = $p
        while ($cursor) {
            if ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'SOURCE_INPUT_REFUSED' }
            $parent = [IO.Directory]::GetParent($cursor)
            if (-not $parent) { break }
            $cursor = $parent.FullName
        }
        $inputs[$name] = (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    return ($inputs | ConvertTo-Json -Compress)
}
function Assert-StandEntryAcl {
    param([string]$Path, [switch]$RootEntry)
    $acl = Get-Acl -LiteralPath $Path
    $rules = @($acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]))
    if ((Stand-Sid $acl.Owner) -ne $currentSid.Value -or $rules.Count -ne 1 -or
        (Stand-Sid $rules[0].IdentityReference) -ne $currentSid.Value -or
        $rules[0].AccessControlType -ne [Security.AccessControl.AccessControlType]::Allow -or
        $rules[0].FileSystemRights -ne [Security.AccessControl.FileSystemRights]::FullControl) { throw 'ENTRY_ACL_DRIFT' }
    if ($RootEntry) {
        if (-not $acl.AreAccessRulesProtected -or $rules[0].IsInherited) { throw 'ENTRY_ACL_DRIFT' }
    } elseif ($acl.AreAccessRulesProtected -or -not $rules[0].IsInherited) { throw 'ENTRY_ACL_DRIFT' }
}
function Stand-CanonicalJson {
    param([System.Collections.IDictionary]$Map)
    $ordered = [ordered]@{}
    foreach ($key in ($Map.Keys | Sort-Object)) { $ordered[$key] = $Map[$key] }
    return ($ordered | ConvertTo-Json -Compress)
}
function Stand-TextHash {
    param([string]$Text)
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($hasher.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))).Replace('-', '').ToLowerInvariant() }
    finally { $hasher.Dispose() }
}
function Stand-ExpectedInventory {
    $expected = @{}
    foreach ($name in $dirs) {
        $parts = $name.Split('/')
        for ($i = 1; $i -le $parts.Length; $i++) { $expected[($parts[0..($i - 1)] -join '/')] = 'directory' }
    }
    foreach ($name in $fixtureFiles.Keys) { $expected[$name] = 'sha256:' + (Stand-TextHash $fixtureFiles[$name]) }
    return $expected
}
function Stand-Inventory {
    param([string]$Root)
    Assert-NoLabReparseTree $Root
    Assert-StandEntryAcl $Root -RootEntry
    $expected = Stand-ExpectedInventory
    $entries = @(Get-ChildItem -LiteralPath $Root -Force -Recurse)
    if ($entries.Count -ne $expected.Count + 1) { throw 'PREPARED_STATE_DRIFT' }
    $actual = @{}
    # Reject unknown paths/types using metadata before reading any file, including DB/auth.
    foreach ($p in $entries) {
        $relative = $p.FullName.Substring($Root.Length + 1).Replace('\', '/')
        if ($relative -eq '.stand-manifest.json') { if ($p.PSIsContainer) { throw 'PREPARED_STATE_DRIFT' }; continue }
        if (-not $expected.ContainsKey($relative) -or ($p.PSIsContainer -ne ($expected[$relative] -eq 'directory'))) { throw 'PREPARED_STATE_DRIFT' }
        $actual[$relative] = $p
    }
    foreach ($p in $entries) { Assert-StandEntryAcl $p.FullName }
    foreach ($name in @($actual.Keys)) {
        if ($actual[$name].PSIsContainer) { $actual[$name] = 'directory' }
        else { $actual[$name] = 'sha256:' + (Get-FileHash -LiteralPath $actual[$name].FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
    }
    $inventory = Stand-CanonicalJson $actual
    if ($inventory -ne (Stand-CanonicalJson $expected)) { throw 'PREPARED_STATE_DRIFT' }
    return $inventory
}

try {
    $configItem = Get-Item -LiteralPath $Config -Force
    if ($configItem.PSIsContainer -or ($configItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'CONFIG_FILE_REFUSED' }
    $cursor = $configItem.FullName
    while ($cursor) {
        if ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'CONFIG_FILE_REFUSED' }
        $parent = [IO.Directory]::GetParent($cursor)
        if (-not $parent) { break }
        $cursor = $parent.FullName
    }
    $c = Read-JsonFile $Config
    $keys = @($c.PSObject.Properties.Name)
    foreach ($key in $keys) { if ($key -notin @('$schema','schemaVersion','repoRoot','labRoot','expectedPiVersion')) { throw 'CONFIG_KEYS_REFUSED' } }
    foreach ($key in @('schemaVersion','repoRoot','labRoot','expectedPiVersion')) { if ($key -notin $keys) { throw 'CONFIG_KEYS_REFUSED' } }
    if ($c.schemaVersion -isnot [int] -or $c.schemaVersion -ne 1 -or $c.repoRoot -isnot [string] -or $c.labRoot -isnot [string] -or $c.expectedPiVersion -isnot [string]) { throw 'CONFIG_TYPES_REFUSED' }
    if ($c.expectedPiVersion -notmatch '^\d+\.\d+\.\d+$') { throw 'VERSION_REFUSED' }
    $repo = Stand-Path $c.repoRoot
    $lab = Stand-Path $c.labRoot
    if (-not (Test-Path -LiteralPath $repo -PathType Container) -or (Stand-Within $lab $repo) -or (Stand-Within $repo $lab)) { throw 'REPO_OVERLAP_REFUSED' }
    if (-not $repo.Equals([IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent)), [StringComparison]::OrdinalIgnoreCase)) { throw 'ENTRY_SOURCE_MISMATCH' }
    foreach ($homePath in @($HOME, $env:USERPROFILE, [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile))) {
        if ($homePath) {
            $homeFull = Stand-Path $homePath
            if ((Stand-Within $lab $homeFull) -or (Stand-Within $homeFull $lab)) { throw 'HOME_OVERLAP_REFUSED' }
        }
    }
    $parentPath = Split-Path $lab -Parent
    if (-not (Test-Path -LiteralPath $parentPath -PathType Container)) { throw 'PARENT_MUST_EXIST' }
    $stage = 'ANCESTORS'
    Assert-StandAncestors $lab
    $inputs = Stand-Inputs $repo
    $manifest = Read-JsonFile (Join-Path $repo 'manifests/runtime.lock.json')
    if ($manifest.schemaVersion -isnot [int] -or $manifest.schemaVersion -ne 1 -or $manifest.runtime.pi.version -isnot [string] -or
        $manifest.runtime.pi.package -isnot [string] -or $manifest.runtime.pi.package -ne '@earendil-works/pi-coding-agent' -or $manifest.runtime.pi.version -ne $c.expectedPiVersion) { throw 'MANIFEST_VERSION_MISMATCH' }
    $dirs = @('pi-root/agent','pi-root/task','npm-prefix','home','appdata','localappdata','temp','xdg-config','xdg-data','xdg-cache','xdg-state','npm-cache','npm-config','uv-cache','uv-tools','uv-bin','cbm-cache','mcp-oauth','trace','goal','sessions/agent','sessions/task','sessions-archive/agent','sessions-archive/task','memory','test-cwd/.pi','evidence')
    $fixtureFiles = @{
        'pi-root/agent/mcp.json'='{"mcpServers":{},"settings":{"scriptMode":false}}'
        'pi-root/task/mcp.json'='{"mcpServers":{},"settings":{"scriptMode":false}}'
        'test-cwd/.pi/settings.json'='{"pi-memory":{"localPath":"../memory"}}'
        'npm-config/user.npmrc'=''; 'npm-config/global.npmrc'=''
    }
    $envMap = Get-LabChildEnvironment -LabRoot $lab -NpmPrefix (Join-Path $lab 'npm-prefix') -ProfileName agent
    $statePath = Join-Path $lab '.stand-manifest.json'
    if (Test-Path -LiteralPath $lab) {
        $stage = 'PREPARED_STATE'
        Assert-StandAncestors $lab -Owned
        if (-not (Test-Path -LiteralPath $statePath -PathType Leaf)) { throw 'EXISTING_ROOT_REFUSED' }
        Assert-NoLabReparseTree $lab
        $inventory = Stand-Inventory $lab
        if ((Get-Item -LiteralPath $statePath).Length -gt 32768) { throw 'PREPARED_STATE_DRIFT' }
        $state = Read-JsonFile $statePath
        $stateKeys = @($state.PSObject.Properties.Name)
        if ($stateKeys.Count -ne 7 -or @($stateKeys | Where-Object { $_ -notin @('schemaVersion','kind','standId','piVersion','sourceInputs','inventory','intercomScope') }).Count -ne 0 -or
            $state.schemaVersion -isnot [int] -or $state.schemaVersion -ne 1 -or
            @(@('kind','standId','piVersion','sourceInputs','inventory','intercomScope') | Where-Object { $state.$_ -isnot [string] }).Count -ne 0 -or
            $state.kind -ne 'PREPARED_SOURCE_ONLY' -or $state.standId -notmatch '^[a-f0-9]{32}$' -or
            $state.piVersion -ne $c.expectedPiVersion -or $state.sourceInputs -ne $inputs -or $state.inventory -ne $inventory -or
            $state.intercomScope -ne $envMap['PI_INTERCOM_SCOPE_ID']) { throw 'PREPARED_STATE_DRIFT' }
        $status = if ($Prepare) { 'VERIFIED_PREPARED_NO_OP' } else { 'PLAN_PREPARED_PASS' }
    } else {
        $status = 'PLAN_NEW_PASS'
        if ($Prepare) {
            $stage = 'PREPARE'
            $security = New-Object Security.AccessControl.DirectorySecurity
            $security.SetAccessRuleProtection($true, $false)
            $security.SetOwner($currentSid)
            $rule = New-Object Security.AccessControl.FileSystemAccessRule($currentSid, [Security.AccessControl.FileSystemRights]::FullControl, ([Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [Security.AccessControl.InheritanceFlags]::ObjectInherit), [Security.AccessControl.PropagationFlags]::None, [Security.AccessControl.AccessControlType]::Allow)
            $security.AddAccessRule($rule)
            [IO.Directory]::CreateDirectory($lab, $security) | Out-Null
            Assert-StandAncestors $lab -Owned
            if (@(Get-ChildItem -LiteralPath $lab -Force).Count -ne 0) { throw 'ROOT_CREATION_RACE' }
            foreach ($name in $dirs) { [IO.Directory]::CreateDirectory((Join-Path $lab $name)) | Out-Null }
            $utf8 = New-Object Text.UTF8Encoding($false)
            foreach ($name in $fixtureFiles.Keys) { [IO.File]::WriteAllText((Join-Path $lab $name), $fixtureFiles[$name], $utf8) }
            $stage = 'PREFLIGHT'
            $preflightOutput = & (Join-Path $repo 'scripts/lab-preflight.ps1') -LabRoot $lab -RepoRoot $repo -Profile Both
            $preflightSucceeded = $?
            # A successful PowerShell script need not set LASTEXITCODE (no native command).
            if (-not $preflightSucceeded -or -not (($preflightOutput | Out-String).Contains('LAB PREFLIGHT PLAN: PASS'))) { throw 'PREFLIGHT_REFUSED' }
            $state = [ordered]@{ schemaVersion=1; kind='PREPARED_SOURCE_ONLY'; standId=[guid]::NewGuid().ToString('N'); piVersion=$c.expectedPiVersion; sourceInputs=$inputs; inventory=(Stand-CanonicalJson (Stand-ExpectedInventory)); intercomScope=$envMap['PI_INTERCOM_SCOPE_ID'] }
            [IO.File]::WriteAllText($statePath, ($state | ConvertTo-Json -Depth 4), $utf8)
            $null = Stand-Inventory $lab
            $status = 'PREPARED_SOURCE_ONLY'
        }
    }
    $envMap = Get-LabChildEnvironment -LabRoot $lab -NpmPrefix (Join-Path $lab 'npm-prefix') -ProfileName agent
    [ordered]@{ status=$status; mode=$(if ($Prepare) {'PREPARE'} else {'PLAN'}); piVersion=$c.expectedPiVersion; intercomScope=$envMap['PI_INTERCOM_SCOPE_ID']; environmentApplied=$false; actorLaunches=0; provisioning=$false; nativeRuntimeGate='NOT_TESTED'; paths='<LAB_ROOT> private routes'; coverage='filesystem/config/ACL only; not token/Job/SDK/global proof' } | ConvertTo-Json -Compress
    exit 0
} catch {
    $code = if ($_.Exception.Message -match '^[A-Z0-9_]{1,80}$') { $_.Exception.Message } else { 'OS_OR_INPUT_OPERATION_FAILED' }
    [ordered]@{ status='FAIL'; stage=$stage; code=$code; exceptionType=$_.Exception.GetType().Name; sourceLine=$_.InvocationInfo.ScriptLineNumber; actorLaunches=0; provisioning=$false } | ConvertTo-Json -Compress
    exit 1
}
