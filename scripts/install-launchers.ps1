[CmdletBinding()]
param(
    [ValidateSet('Code', 'Task', 'Both')]
    [string]$Profile = 'Both',

    [ValidateSet('Windows', 'Posix', 'Both')]
    [string]$Shell = 'Both',

    [switch]$Apply,

    [string]$TargetDir = $(if ($env:OS -eq 'Windows_NT') { Join-Path $HOME 'bin' } else { Join-Path $HOME '.local/bin' }),

    [string]$PiRoot = (Join-Path $HOME '.pi'),

    [string]$NpmPrefix = $(if ($env:APPDATA) { Join-Path $env:APPDATA 'npm' } else { Join-Path $HOME '.npm-global' }),

    [string]$RepoRoot = (Split-Path $PSScriptRoot -Parent)
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

function Convert-ToPosixPath {
    param([string]$Path)
    $value = $Path.Replace('\', '/')
    return $value.Replace("'", "'\''")
}

function Render-Launcher {
    param([string]$Source, [string]$ProfileDirectory, [string]$ResolvedPiRoot, [string]$ResolvedNpmPrefix)
    $text = [IO.File]::ReadAllText($Source)
    $profilePath = Join-Path $ResolvedPiRoot $ProfileDirectory
    $text = $text.Replace('__PI_PROFILE_DIR_WINDOWS__', $profilePath)
    $text = $text.Replace('__NPM_PREFIX_WINDOWS__', $ResolvedNpmPrefix)
    $text = $text.Replace('__PI_PROFILE_DIR_POSIX__', (Convert-ToPosixPath $profilePath))
    $text = $text.Replace('__NPM_PREFIX_POSIX__', (Convert-ToPosixPath $ResolvedNpmPrefix))
    if ($text -match '__[A-Z0-9_]+__') { throw "Unresolved launcher token in $Source" }
    return $text
}

function Write-RenderedLauncher {
    param([string]$Content, [string]$Destination, [string]$BackupDirectory, [string]$BackupName)
    if (Test-Path -LiteralPath $Destination -PathType Leaf) {
        if ([IO.File]::ReadAllText($Destination) -ceq $Content) { return 'unchanged' }
        [void](Backup-FileIfPresent -Source $Destination -BackupDirectory $BackupDirectory -BackupName $BackupName)
    }
    $parent = Split-Path $Destination -Parent
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    [IO.File]::WriteAllText($Destination, $Content, (New-Object Text.UTF8Encoding($false)))
    return 'written'
}

try {
    $RepoRoot = Resolve-FullPath $RepoRoot
    $TargetDir = Resolve-FullPath $TargetDir
    $PiRoot = Resolve-FullPath $PiRoot
    $NpmPrefix = Resolve-FullPath $NpmPrefix
    $profiles = Get-SelectedProfiles -Profile $Profile
    $items = @()
    foreach ($selected in $profiles) {
        $baseName = if ($selected.Name -eq 'Code') { 'pi-code' } else { 'pi-task' }
        if ($Shell -eq 'Windows' -or $Shell -eq 'Both') {
            $items += [pscustomobject]@{ File = "$baseName.cmd"; ProfileDirectory = $selected.Directory; Posix = $false }
        }
        if ($Shell -eq 'Posix' -or $Shell -eq 'Both') {
            $items += [pscustomobject]@{ File = $baseName; ProfileDirectory = $selected.Directory; Posix = $true }
        }
    }

    $mode = if ($Apply) { 'APPLY' } else { 'PLAN' }
    Write-Host "$mode launcher installation"
    Write-Host "target: $TargetDir"
    Write-Host "Pi root: $PiRoot"
    Write-Host "npm prefix: $NpmPrefix"
    foreach ($item in $items) {
        $source = Join-Path (Join-Path $RepoRoot 'launchers') $item.File
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Launcher source missing: $source" }
        [void](Render-Launcher -Source $source -ProfileDirectory $item.ProfileDirectory -ResolvedPiRoot $PiRoot -ResolvedNpmPrefix $NpmPrefix)
        Write-Host "  RENDER $($item.File)"
    }

    if (-not $Apply) {
        Write-Host 'PLAN complete; no files were written. Re-run with -Apply.'
        exit 0
    }

    $stamp = New-BackupStamp
    $backupDirectory = Join-Path $TargetDir ".pi-agent-build-backups\launchers\$stamp"
    foreach ($item in $items) {
        $source = Join-Path (Join-Path $RepoRoot 'launchers') $item.File
        $destination = Join-Path $TargetDir $item.File
        $content = Render-Launcher -Source $source -ProfileDirectory $item.ProfileDirectory -ResolvedPiRoot $PiRoot -ResolvedNpmPrefix $NpmPrefix
        $status = Write-RenderedLauncher -Content $content -Destination $destination -BackupDirectory $backupDirectory -BackupName $item.File
        if ($item.Posix) {
            $chmod = Get-Command chmod -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($chmod) {
                & $chmod.Source '+x' '--' $destination
                if ($LASTEXITCODE -ne 0) { throw "chmod +x failed for $destination" }
            }
        }
        Write-Host "  $status $destination"
    }
    Write-Host 'Launcher installation complete. Pi was not started.'
    exit 0
} catch {
    Write-Error $_.Exception.Message
    exit 1
}
