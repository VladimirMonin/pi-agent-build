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
        [hashtable]$Environment = @{}
    )
    $resolved = Get-Command $Command -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $resolved) { return [pscustomobject]@{ Found = $false; ExitCode = 127; Output = '' } }
    $script:ChildCommandOutput = ''
    $script:ChildCommandExitCode = 0
    Invoke-WithChildEnvironment -Sanitize:$SanitizeEnvironment -Environment $Environment -ScriptBlock {
        $priorPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            $script:ChildCommandOutput = (& $resolved.Source @Arguments 2>&1 | Out-String).Trim()
            $script:ChildCommandExitCode = $LASTEXITCODE
        } finally { $ErrorActionPreference = $priorPreference }
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
