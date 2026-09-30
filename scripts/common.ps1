Set-StrictMode -Version 2.0

function Resolve-FullPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [System.IO.Path]::GetFullPath($Path)
}

function Read-JsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Required JSON file not found: $Path"
    }
    try {
        return (Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json)
    } catch {
        throw "Invalid JSON file '$Path': $($_.Exception.Message)"
    }
}

function Get-SelectedProfiles {
    param([Parameter(Mandatory = $true)][ValidateSet('Code', 'Task', 'Both')][string]$Profile)
    $items = @()
    if ($Profile -eq 'Code' -or $Profile -eq 'Both') {
        $items += [pscustomobject]@{ Name = 'Code'; Directory = 'agent'; Template = 'code' }
    }
    if ($Profile -eq 'Task' -or $Profile -eq 'Both') {
        $items += [pscustomobject]@{ Name = 'Task'; Directory = 'task'; Template = 'task' }
    }
    return $items
}

function New-BackupStamp {
    return ('{0}-{1}' -f (Get-Date -Format 'yyyyMMdd-HHmmss-fff'), ([guid]::NewGuid().ToString('N').Substring(0, 8)))
}

function Backup-FileIfPresent {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$BackupDirectory,
        [Parameter(Mandatory = $true)][string]$BackupName
    )
    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) { return $null }
    New-Item -ItemType Directory -Path $BackupDirectory -Force | Out-Null
    $destination = Join-Path $BackupDirectory $BackupName
    $destinationParent = Split-Path $destination -Parent
    if (-not (Test-Path -LiteralPath $destinationParent)) {
        New-Item -ItemType Directory -Path $destinationParent -Force | Out-Null
    }
    Copy-Item -LiteralPath $Source -Destination $destination -Force
    return $destination
}

function Copy-FileWithBackup {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination,
        [Parameter(Mandatory = $true)][string]$BackupDirectory,
        [string]$BackupName = ''
    )
    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) {
        throw "Source file not found: $Source"
    }
    if (Test-Path -LiteralPath $Destination -PathType Leaf) {
        $sourceHash = (Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash
        $destinationHash = (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash
        if ($sourceHash -eq $destinationHash) { return 'unchanged' }
        if (-not $BackupName) { $BackupName = Split-Path $Destination -Leaf }
        [void](Backup-FileIfPresent -Source $Destination -BackupDirectory $BackupDirectory -BackupName $BackupName)
    }
    $parent = Split-Path $Destination -Parent
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Copy-Item -LiteralPath $Source -Destination $Destination -Force
    return 'written'
}

function Install-ProfileFile {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination,
        [Parameter(Mandatory = $true)][string]$BackupDirectory,
        [string]$BackupName = '',
        [switch]$Replace
    )
    if ((Test-Path -LiteralPath $Destination -PathType Leaf) -and -not $Replace) {
        return 'preserved'
    }
    return Copy-FileWithBackup -Source $Source -Destination $Destination -BackupDirectory $BackupDirectory -BackupName $BackupName
}

function Copy-DirectoryWithBackup {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination,
        [Parameter(Mandatory = $true)][string]$BackupDirectory,
        [string]$BackupName = ''
    )
    if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
        throw "Source directory not found: $Source"
    }
    if (Test-Path -LiteralPath $Destination -PathType Container) {
        if (-not $BackupName) { $BackupName = Split-Path $Destination -Leaf }
        New-Item -ItemType Directory -Path $BackupDirectory -Force | Out-Null
        $backup = Join-Path $BackupDirectory $BackupName
        if (Test-Path -LiteralPath $backup) {
            throw "Backup destination already exists: $backup"
        }
        $backupParent = Split-Path $backup -Parent
        if (-not (Test-Path -LiteralPath $backupParent)) {
            New-Item -ItemType Directory -Path $backupParent -Force | Out-Null
        }
        Copy-Item -LiteralPath $Destination -Destination $backup -Recurse
        Remove-Item -LiteralPath $Destination -Recurse -Force
    }
    $parent = Split-Path $Destination -Parent
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Copy-Item -LiteralPath $Source -Destination $Destination -Recurse
    return 'written'
}

function Install-ProfileDirectory {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination,
        [Parameter(Mandatory = $true)][string]$BackupDirectory,
        [string]$BackupName = '',
        [switch]$Replace
    )
    if ((Test-Path -LiteralPath $Destination -PathType Container) -and -not $Replace) {
        return 'preserved'
    }
    return Copy-DirectoryWithBackup -Source $Source -Destination $Destination -BackupDirectory $BackupDirectory -BackupName $BackupName
}

function Format-CommandLine {
    param([string]$Command, [string[]]$Arguments)
    $formatted = @($Command)
    foreach ($argument in $Arguments) {
        if ($argument -match '[\s"]') {
            $formatted += ('"{0}"' -f ($argument -replace '"', '\"'))
        } else {
            $formatted += $argument
        }
    }
    return ($formatted -join ' ')
}

function Get-SanitizedChildEnvironment {
    param([hashtable]$Overrides = @{})
    $allowed = @(
        'PATH', 'PATHEXT', 'SystemRoot', 'WINDIR', 'COMSPEC', 'TEMP', 'TMP',
        'USERPROFILE', 'HOME', 'APPDATA', 'LOCALAPPDATA', 'PROGRAMDATA',
        'ProgramFiles', 'ProgramFiles(x86)', 'CommonProgramFiles', 'CommonProgramFiles(x86)',
        'PROCESSOR_ARCHITECTURE', 'PROCESSOR_IDENTIFIER', 'NUMBER_OF_PROCESSORS', 'OS'
    )
    $result = @{}
    foreach ($name in $allowed) {
        $value = [Environment]::GetEnvironmentVariable($name, 'Process')
        if ($null -ne $value -and $value -ne '') { $result[$name] = $value }
    }
    foreach ($name in $Overrides.Keys) { $result[$name] = [string]$Overrides[$name] }
    return $result
}

function Assert-PrivateLabRoot {
    param([string]$LabRoot, [string]$RepoRoot)
    if ($LabRoot -notmatch '^[A-Za-z]:[\\/]' -or $LabRoot -match '[\\/]\.\.[\\/]') { throw 'LabRoot must be an absolute local path without parent traversal.' }
    $lab = [IO.Path]::GetFullPath($LabRoot).TrimEnd([char[]]@('\', '/'))
    $repo = [IO.Path]::GetFullPath($RepoRoot).TrimEnd([char[]]@('\', '/'))
    if (-not (Test-Path -LiteralPath $lab -PathType Container) -or $lab.Equals($repo, [StringComparison]::OrdinalIgnoreCase) -or
        $lab.StartsWith(($repo + '\'), [StringComparison]::OrdinalIgnoreCase) -or $repo.StartsWith(($lab + '\'), [StringComparison]::OrdinalIgnoreCase)) { throw 'LabRoot missing or overlapping repository.' }
    foreach ($homePath in @($HOME, $env:USERPROFILE)) {
        if ($homePath) {
            $homeFull = [IO.Path]::GetFullPath($homePath).TrimEnd([char[]]@('\', '/'))
            if ($lab.Equals($homeFull, [StringComparison]::OrdinalIgnoreCase) -or $lab.StartsWith(($homeFull + '\'), [StringComparison]::OrdinalIgnoreCase)) { throw 'LabRoot overlaps live home.' }
        }
    }
    $cursor = $lab
    while ($cursor) {
        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction SilentlyContinue
        if ($item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'LabRoot includes reparse point.' }
        if (Test-Path -LiteralPath (Join-Path $cursor '.git')) { throw 'LabRoot overlaps Git checkout.' }
        $parent = [IO.Directory]::GetParent($cursor)
        if (-not $parent) { break }
        $cursor = $parent.FullName
    }
    foreach ($relative in @('pi-root', 'pi-root/agent', 'pi-root/task', 'npm-prefix', 'npm-prefix/pi.cmd', 'test-cwd')) {
        $target = Join-Path $lab $relative
        $item = Get-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
        if ($item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Lab target includes reparse point.' }
    }
    return $lab
}

function Assert-NoLabReparseTree {
    param([string]$Root)
    if (-not (Test-Path -LiteralPath $Root)) { return }
    $pending = New-Object 'System.Collections.Generic.Stack[string]'
    $pending.Push($Root)
    while ($pending.Count -gt 0) {
        $current = $pending.Pop()
        $item = Get-Item -LiteralPath $current -Force
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Lab tree contains a reparse point.' }
        if ($item.PSIsContainer) {
            foreach ($child in (Get-ChildItem -LiteralPath $current -Force)) { $pending.Push($child.FullName) }
        }
    }
}

function Get-LabChildEnvironment {
    param([string]$LabRoot, [string]$NpmPrefix, [string]$ProfileName = '')
    $paths = @{
        HOME = 'home'; USERPROFILE = 'home'; APPDATA = 'appdata'; LOCALAPPDATA = 'localappdata'
        TEMP = 'temp'; TMP = 'temp'; XDG_CONFIG_HOME = 'xdg-config'; XDG_DATA_HOME = 'xdg-data'
        XDG_CACHE_HOME = 'xdg-cache'; XDG_STATE_HOME = 'xdg-state'
        npm_config_cache = 'npm-cache'; npm_config_userconfig = 'npm-config/user.npmrc'
        npm_config_globalconfig = 'npm-config/global.npmrc'; UV_CACHE_DIR = 'uv-cache'
        UV_TOOL_DIR = 'uv-tools'; UV_TOOL_BIN_DIR = 'uv-bin'; PI_CBM_CACHE_DIR = 'cbm-cache'
        CBM_CACHE_DIR = 'cbm-cache'; MCP_OAUTH_DIR = 'mcp-oauth'; PI_TRACE_PARENT_DIR = 'trace'
        PI_GOAL_ROOT = 'goal'; PI_GOAL_GLOBAL_SETTINGS_FILE = 'goal/settings.json'
    }
    $envMap = @{}
    foreach ($key in $paths.Keys) { $envMap[$key] = Join-Path $LabRoot $paths[$key] }
    $envMap['npm_config_prefix'] = $NpmPrefix
    $envMap['PI_AGENT_BUILD_NPM_PREFIX'] = $NpmPrefix
    $envMap['PI_MCP_CONFIG_MODE'] = 'exclusive'
    $envMap['PYTHONDONTWRITEBYTECODE'] = '1'
    $envMap['PI_INTERCOM_SCOPE_ID'] = 'pi-lab-synthetic'
    if ($ProfileName) {
        $envMap['PI_CODING_AGENT_DIR'] = Join-Path (Join-Path $LabRoot 'pi-root') $ProfileName
        $envMap['PI_CODING_AGENT_SESSION_DIR'] = Join-Path (Join-Path $LabRoot 'sessions') $ProfileName
        $envMap['PI_SESSION_DIR'] = $envMap['PI_CODING_AGENT_SESSION_DIR']
        $envMap['PI_SESSION_ARCHIVE_DIR'] = Join-Path (Join-Path $LabRoot 'sessions-archive') $ProfileName
    }
    return $envMap
}

function Assert-LabToolPath {
    param([string]$Name, [string]$NpmPrefix)
    $tool = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $tool -or -not [IO.Path]::IsPathRooted([string]$tool.Source)) { throw "Lab tool unavailable: $Name" }
    $directory = Split-Path $tool.Source -Parent
    foreach ($candidate in @('pi.cmd', 'pi.exe', 'pi.bat')) {
        $path = Join-Path $directory $candidate
        if ((Test-Path -LiteralPath $path) -and -not $directory.Equals($NpmPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Lab tool directory contains a non-lab Pi launcher: $directory"
        }
    }
    return [string]$tool.Source
}

function Get-LabToolEnvironment {
    param([string]$LabRoot, [string]$NpmPrefix, [string]$ProfileName = '')
    $map = Get-LabChildEnvironment -LabRoot $LabRoot -NpmPrefix $NpmPrefix -ProfileName $ProfileName
    $directories = @($NpmPrefix, "$env:SystemRoot\System32", "$env:SystemRoot")
    foreach ($name in @('node', 'npm', 'git', 'python', 'uv')) {
        $toolPath = Assert-LabToolPath -Name $name -NpmPrefix $NpmPrefix
        $directory = Split-Path $toolPath -Parent
        if ($directory -notin $directories) { $directories += $directory }
    }
    foreach ($directory in $directories) {
        if ($directory -eq $NpmPrefix) { continue }
        foreach ($candidate in @('pi.cmd', 'pi.exe', 'pi.bat')) {
            if (Test-Path -LiteralPath (Join-Path $directory $candidate)) { throw 'Lab PATH includes a non-lab Pi launcher.' }
        }
    }
    $map['PATH'] = $directories -join [IO.Path]::PathSeparator
    return $map
}

function Invoke-WithChildEnvironment {
    param(
        [Parameter(Mandatory = $true)][scriptblock]$ScriptBlock,
        [switch]$Sanitize,
        [hashtable]$Environment = @{}
    )
    $saved = [Environment]::GetEnvironmentVariables('Process')
    if ($Sanitize) { $effective = Get-SanitizedChildEnvironment -Overrides $Environment }
    else { $effective = $Environment }
    try {
        if ($Sanitize) {
            foreach ($name in @($saved.Keys)) { [Environment]::SetEnvironmentVariable([string]$name, $null, 'Process') }
        }
        foreach ($name in $effective.Keys) {
            [Environment]::SetEnvironmentVariable([string]$name, [string]$effective[$name], 'Process')
        }
        & $ScriptBlock
    } finally {
        $current = [Environment]::GetEnvironmentVariables('Process')
        foreach ($name in @($current.Keys)) { [Environment]::SetEnvironmentVariable([string]$name, $null, 'Process') }
        foreach ($name in $saved.Keys) { [Environment]::SetEnvironmentVariable([string]$name, [string]$saved[$name], 'Process') }
    }
}

function Invoke-CheckedCommand {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [string[]]$Arguments = @(),
        [string]$WorkingDirectory = '',
        [switch]$SanitizeEnvironment,
        [hashtable]$Environment = @{}
    )
    $resolved = Get-Command $Command -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $resolved) { throw "Required command not found: $Command" }
    Write-Host ('RUN  ' + (Format-CommandLine -Command $Command -Arguments $Arguments))
    $oldLocation = Get-Location
    $script:ChildCommandExitCode = 0
    try {
        if ($WorkingDirectory) { Set-Location -LiteralPath $WorkingDirectory }
        Invoke-WithChildEnvironment -Sanitize:$SanitizeEnvironment -Environment $Environment -ScriptBlock {
            $priorPreference = $ErrorActionPreference
            try {
                $ErrorActionPreference = 'Continue'
                & $resolved.Source @Arguments
                $script:ChildCommandExitCode = $LASTEXITCODE
            } finally { $ErrorActionPreference = $priorPreference }
        }
    } finally {
        if ($WorkingDirectory) { Set-Location -LiteralPath $oldLocation.Path }
    }
    $code = $script:ChildCommandExitCode
    if ($null -eq $code) { $code = 0 }
    if ($code -ne 0) { throw "Command failed with exit code ${code}: $Command" }
}

function Get-CommandOutput {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [string[]]$Arguments = @(),
        [switch]$SanitizeEnvironment,
        [hashtable]$Environment = @{},
        [string]$WorkingDirectory = ''
    )
    $resolved = Get-Command $Command -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $resolved) { return [pscustomobject]@{ Found = $false; ExitCode = 127; Output = '' } }
    $script:ChildCommandOutput = ''
    $script:ChildCommandExitCode = 0
    $oldLocation = Get-Location
    try {
        if ($WorkingDirectory) { Set-Location -LiteralPath $WorkingDirectory }
        Invoke-WithChildEnvironment -Sanitize:$SanitizeEnvironment -Environment $Environment -ScriptBlock {
            $priorPreference = $ErrorActionPreference
            try {
                $ErrorActionPreference = 'Continue'
                $script:ChildCommandOutput = (& $resolved.Source @Arguments 2>&1 | Out-String).Trim()
                $script:ChildCommandExitCode = $LASTEXITCODE
            } finally { $ErrorActionPreference = $priorPreference }
        }
    } finally {
        if ($WorkingDirectory) { Set-Location -LiteralPath $oldLocation.Path }
    }
    $code = $script:ChildCommandExitCode
    if ($null -eq $code) { $code = 0 }
    return [pscustomobject]@{ Found = $true; ExitCode = $code; Output = $script:ChildCommandOutput; Path = $resolved.Source }
}

function Get-VersionFromText {
    param([string]$Text)
    if ($Text -match '(?<!\d)(\d+\.\d+(?:\.[0-9A-Za-z-]+)*(?:[-+][0-9A-Za-z.-]+)?)(?!\d)') {
        return $Matches[1]
    }
    return $null
}

# Warm-MemoryEmbedder <ProfileRoot> [TimeoutMs] [Retries]
# Pre-downloads the pi-memory local embedding model into the profile's
# @xenova/transformers cache. The plugin loads the model lazily with a 30s
# timeout; a cold download on a slow link can exceed it and the plugin then
# silently falls back to FTS-only search. Network speed varies, so this uses a
# generous timeout with bounded retries and never fails the whole install.
# Returns: warmed | already-cached | skipped | failed
function Warm-MemoryEmbedder {
    param(
        [Parameter(Mandatory = $true)][string]$ProfileRoot,
        [int]$TimeoutMs = 600000,
        [int]$Retries = 3
    )
    $dist = Join-Path $ProfileRoot 'npm\node_modules\@samfp\pi-memory\dist\index.js'
    if (-not (Test-Path -LiteralPath $dist -PathType Leaf)) { return 'skipped' }
    if (-not (Get-Command 'node' -ErrorAction SilentlyContinue)) {
        Write-Warning 'node not found; skipping memory embedder warm-up'
        return 'skipped'
    }
    $helper = Join-Path $PSScriptRoot 'warm-memory-embedder.mjs'
    if (-not (Test-Path -LiteralPath $helper -PathType Leaf)) {
        Write-Warning "warm-up helper missing: $helper"
        return 'skipped'
    }
    $result = Get-CommandOutput -Command 'node' -Arguments @($helper, $ProfileRoot, '--timeout-ms', [string]$TimeoutMs, '--retries', [string]$Retries)
    if ($result.Output) { Write-Host $result.Output }
    if ($result.ExitCode -eq 0) { return 'warmed' }
    Write-Warning "memory embedder warm-up failed (exit $($result.ExitCode)); semantic memory search stays FTS-only until the model downloads"
    return 'failed'
}
