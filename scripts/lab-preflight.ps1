[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$LabRoot,
    [string]$RepoRoot = (Split-Path $PSScriptRoot -Parent),
    [string]$PiRoot = '',
    [string]$NpmPrefix = '',
    [string]$TestCwd = '',
    [ValidateSet('Both', 'Code', 'Task')][string]$Profile = 'Both',
    [switch]$RequireInstalledPi
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Assert-AbsolutePath {
    param([string]$Value, [string]$Label)
    # Reject drive-relative, root-relative, UNC and device paths; all planned targets use local drive paths.
    if ($Value -notmatch '^[A-Za-z]:[\\/]' -or $Value.Substring(2) -match '[*?:]' -or
        $Value -match '[\\/]\.\.[\\/]') {
        throw "$Label must be an absolute local-drive path without parent traversal."
    }
    $full = [IO.Path]::GetFullPath($Value).TrimEnd([char[]]@('\', '/'))
    if ($full -match '^[A-Za-z]:$') { throw "$Label cannot be a drive root." }
    return $full
}

function Test-Within {
    param([string]$Path, [string]$Root)
    return $Path.StartsWith(($Root.TrimEnd([char[]]@('\', '/')) + '\'), [StringComparison]::OrdinalIgnoreCase)
}

function Assert-NoReparseAncestors {
    param([string]$Path, [string]$Label)
    $cursor = $Path
    while ($cursor) {
        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction SilentlyContinue
        if ($null -ne $item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "$Label contains a reparse point."
        }
        $parent = [IO.Directory]::GetParent($cursor)
        if ($null -eq $parent) { break }
        $cursor = $parent.FullName
    }
}

function Assert-OutsideGitTree {
    param([string]$Path)
    $cursor = $Path
    while ($cursor) {
        if (Test-Path -LiteralPath (Join-Path $cursor '.git')) {
            throw 'LabRoot is inside a Git checkout.'
        }
        $parent = [IO.Directory]::GetParent($cursor)
        if ($null -eq $parent) { break }
        $cursor = $parent.FullName
    }
}

function Assert-LabTarget {
    param([string]$Path, [string]$Label)
    if (-not (Test-Within $Path $lab)) { throw "$Label must be inside LabRoot." }
    if ($Path -eq $repo -or (Test-Within $Path $repo)) { throw "$Label overlaps RepoRoot." }
    foreach ($liveHome in $liveHomes) {
        if ($Path -eq $liveHome -or (Test-Within $Path $liveHome)) { throw "$Label overlaps the live home." }
    }
    Assert-NoReparseAncestors $Path $Label
}

function Assert-SyntheticMcp {
    param([string]$Path, [string]$Label)
    Assert-LabTarget $Path $Label
    if (-not (Test-Path -LiteralPath $Path)) { return }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "$Label is not a file." }
    try { $config = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json }
    catch { throw "$Label must contain valid JSON." }
    if ($null -eq $config -or @($config.PSObject.Properties).Count -ne 2 -or
        $null -eq $config.PSObject.Properties['mcpServers'] -or
        $null -eq $config.PSObject.Properties['settings'] -or
        $null -eq $config.mcpServers -or @($config.mcpServers.PSObject.Properties).Count -ne 0 -or
        $null -eq $config.settings -or @($config.settings.PSObject.Properties).Count -ne 1 -or
        $null -eq $config.settings.PSObject.Properties['scriptMode'] -or
        $config.settings.scriptMode -isnot [bool] -or $config.settings.scriptMode) {
        throw "$Label is not an empty synthetic MCP configuration."
    }
}

function Assert-SyntheticNpmConfig {
    param([string]$Path, [string]$Label)
    Assert-LabTarget $Path $Label
    if (-not (Test-Path -LiteralPath $Path)) { return }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "$Label is not a file." }
    foreach ($line in (Get-Content -LiteralPath $Path -Encoding UTF8)) {
        if ($line -notmatch '^\s*(?:[#;]|$)') {
            throw "$Label contains an npm directive."
        }
    }
}

function Assert-SyntheticSettings {
    param([string]$Path, [string]$Label, [switch]$Required)
    Assert-LabTarget $Path $Label
    if (-not (Test-Path -LiteralPath $Path)) {
        if ($Required) { throw "$Label is missing." }
        return
    }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "$Label is not a file." }
    try { $settings = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json }
    catch { throw "$Label must contain valid JSON." }
    if ($null -eq $settings -or @($settings.PSObject.Properties).Count -ne 1 -or
        $null -eq $settings.PSObject.Properties['pi-memory'] -or
        $null -eq $settings.'pi-memory' -or
        @($settings.'pi-memory'.PSObject.Properties).Count -ne 1 -or
        $null -eq $settings.'pi-memory'.PSObject.Properties['localPath'] -or
        $settings.'pi-memory'.localPath -isnot [string] -or
        [string]::IsNullOrWhiteSpace($settings.'pi-memory'.localPath)) {
        throw "$Label must contain only pi-memory.localPath."
    }
    $value = [string]$settings.'pi-memory'.localPath
    if ([IO.Path]::IsPathRooted($value) -or $value -match '^[A-Za-z]:' -or $value -match '^[\\/]{2}') {
        throw "$Label localPath must be relative."
    }
    $memory = [IO.Path]::GetFullPath((Join-Path (Split-Path (Split-Path $Path -Parent) -Parent) $value))
    Assert-LabTarget $memory "$Label memory directory"
    foreach ($name in @('memory.db', 'memory.db-wal', 'memory.db-shm')) {
        Assert-LabTarget (Join-Path $memory $name) "$Label memory database"
    }
    if (Test-Path -LiteralPath $memory) {
        if (-not (Test-Path -LiteralPath $memory -PathType Container)) { throw "$Label memory directory is not a directory." }
        if (@(Get-ChildItem -LiteralPath $memory -Force).Count -gt 0) {
            throw "$Label memory directory is not empty."
        }
    }
}

try {
    if ($RequireInstalledPi) {
        if ($Profile -ne 'Both' -or $PiRoot -or $NpmPrefix -or $TestCwd) { throw 'Installed gate requires fixed Both private destinations.' }
        . (Join-Path $PSScriptRoot 'common.ps1')
        $installedLab = Assert-PrivateLabRoot -LabRoot $LabRoot -RepoRoot $RepoRoot
        Assert-LabInstalledState -LabRoot $installedLab -RepoRoot $RepoRoot -Mcp
        Write-Output 'LAB PREFLIGHT INSTALLED: PASS (fully verified; no package/launcher writes)'
        exit 0
    }
    $lab = Assert-AbsolutePath $LabRoot 'LabRoot'
    $repo = Assert-AbsolutePath $RepoRoot 'RepoRoot'
    if (-not (Test-Path -LiteralPath $lab -PathType Container) -or
        -not (Test-Path -LiteralPath $repo -PathType Container)) {
        throw 'LabRoot and RepoRoot must be existing directories.'
    }
    Assert-NoReparseAncestors $lab 'LabRoot'
    Assert-NoReparseAncestors $repo 'RepoRoot'
    Assert-OutsideGitTree $lab
    $liveHomes = @()
    foreach ($homeValue in @($HOME, [Environment]::GetEnvironmentVariable('USERPROFILE'))) {
        if ($homeValue -and $homeValue -match '^[A-Za-z]:[\\/]') {
            $liveHomes += Assert-AbsolutePath $homeValue 'live home'
        }
    }
    foreach ($liveHome in $liveHomes) {
        if ($lab -eq $liveHome -or (Test-Within $lab $liveHome)) { throw 'LabRoot overlaps the live home.' }
    }
    if ($lab -eq $repo -or (Test-Within $lab $repo) -or (Test-Within $repo $lab)) {
        throw 'LabRoot and RepoRoot overlap.'
    }
    if (-not $PiRoot) { $PiRoot = Join-Path $lab 'pi-root' }
    if (-not $NpmPrefix) { $NpmPrefix = Join-Path $lab 'npm-prefix' }
    if (-not $TestCwd) { $TestCwd = Join-Path $lab 'test-cwd' }
    $targets = @{
        PiRoot = Assert-AbsolutePath $PiRoot 'PiRoot'
        NpmPrefix = Assert-AbsolutePath $NpmPrefix 'NpmPrefix'
        TestCwd = Assert-AbsolutePath $TestCwd 'TestCwd'
    }
    foreach ($label in $targets.Keys) {
        Assert-LabTarget $targets[$label] $label
        if ((Test-Path -LiteralPath $targets[$label]) -and
            -not (Test-Path -LiteralPath $targets[$label] -PathType Container)) {
            throw "$label is not a directory."
        }
    }
    $names = @('PiRoot', 'NpmPrefix', 'TestCwd')
    for ($i = 0; $i -lt $names.Count; $i++) {
        for ($j = $i + 1; $j -lt $names.Count; $j++) {
            $a = $targets[$names[$i]]; $b = $targets[$names[$j]]
            if ($a -eq $b -or (Test-Within $a $b) -or (Test-Within $b $a)) {
                throw 'PiRoot, NpmPrefix and TestCwd must be disjoint.'
            }
        }
    }
    if (Test-Path -LiteralPath $targets.PiRoot) {
        foreach ($entry in @(Get-ChildItem -LiteralPath $targets.PiRoot -Force)) {
            if ($entry.Name -notin @('agent', 'task')) { throw 'PiRoot contains non-synthetic content.' }
        }
    }
    if (Test-Path -LiteralPath $targets.NpmPrefix -PathType Container) {
        if (@(Get-ChildItem -LiteralPath $targets.NpmPrefix -Force).Count -gt 0) {
            throw 'NpmPrefix is not empty; use RequireInstalledPi only after a separate installation gate.'
        }
    }
    $profileNames = if ($Profile -eq 'Both') { @('agent', 'task') } elseif ($Profile -eq 'Code') { @('agent') } else { @('task') }
    foreach ($name in $profileNames) {
        $profilePath = Join-Path $targets.PiRoot $name
        Assert-LabTarget $profilePath "profile $name"
        if (Test-Path -LiteralPath $profilePath) {
            if (-not (Test-Path -LiteralPath $profilePath -PathType Container)) { throw "profile $name is not a directory." }
            $entries = @(Get-ChildItem -LiteralPath $profilePath -Force)
            foreach ($entry in $entries) {
                if ($entry.Name -ne 'mcp.json') { throw "profile $name contains non-synthetic content." }
            }
        }
        Assert-SyntheticMcp (Join-Path $profilePath 'mcp.json') "profile $name MCP"
    }
    if (-not (Test-Path -LiteralPath $targets.TestCwd -PathType Container)) { throw 'TestCwd must exist.' }
    foreach ($entry in @(Get-ChildItem -LiteralPath $targets.TestCwd -Force)) {
        if ($entry.Name -ne '.pi') { throw 'TestCwd contains non-synthetic content.' }
    }
    $projectPi = Join-Path $targets.TestCwd '.pi'
    Assert-LabTarget $projectPi 'project .pi'
    if (-not (Test-Path -LiteralPath $projectPi -PathType Container)) { throw 'Project .pi directory is missing.' }
    foreach ($entry in @(Get-ChildItem -LiteralPath $projectPi -Force)) {
        if ($entry.Name -ne 'settings.json') { throw 'Project .pi contains non-synthetic content.' }
    }
    $projectSettings = Join-Path $projectPi 'settings.json'
    Assert-SyntheticSettings $projectSettings 'project settings' -Required
    # Exact intended lab invocation destinations; this plan does not set process env.
    $destinations = @{
        USERPROFILE = (Join-Path $lab 'home'); HOME = (Join-Path $lab 'home')
        APPDATA = (Join-Path $lab 'appdata'); LOCALAPPDATA = (Join-Path $lab 'localappdata')
        TEMP = (Join-Path $lab 'temp'); TMP = (Join-Path $lab 'temp')
        XDG_CONFIG_HOME = (Join-Path $lab 'xdg-config'); XDG_DATA_HOME = (Join-Path $lab 'xdg-data')
        XDG_CACHE_HOME = (Join-Path $lab 'xdg-cache'); XDG_STATE_HOME = (Join-Path $lab 'xdg-state')
        npm_config_prefix = $targets.NpmPrefix; npm_config_cache = (Join-Path $lab 'npm-cache')
        npm_config_userconfig = (Join-Path $lab 'npm-config\user.npmrc')
        npm_config_globalconfig = (Join-Path $lab 'npm-config\global.npmrc')
        PI_AGENT_BUILD_NPM_PREFIX = $targets.NpmPrefix
        PI_CBM_CACHE_DIR = (Join-Path $lab 'cbm-cache')
        CBM_CACHE_DIR = (Join-Path $lab 'cbm-cache')
        MCP_OAUTH_DIR = (Join-Path $lab 'mcp-oauth')
        PI_TRACE_PARENT_DIR = (Join-Path $lab 'trace')
        PI_GOAL_ROOT = (Join-Path $lab 'goal')
        PI_GOAL_GLOBAL_SETTINGS_FILE = (Join-Path $lab 'goal\settings.json')
        UV_CACHE_DIR = (Join-Path $lab 'uv-cache'); UV_TOOL_DIR = (Join-Path $lab 'uv-tools')
        UV_TOOL_BIN_DIR = (Join-Path $lab 'uv-bin')
    }
    foreach ($name in $profileNames) {
        $profileRoot = Join-Path $targets.PiRoot $name
        foreach ($key in @('PI_CODING_AGENT_DIR')) { Assert-LabTarget $profileRoot "$key $name" }
        $sessions = Join-Path (Join-Path $lab 'sessions') $name
        $archives = Join-Path (Join-Path $lab 'sessions-archive') $name
        foreach ($key in @('PI_CODING_AGENT_SESSION_DIR', 'PI_SESSION_DIR')) {
            Assert-LabTarget $sessions "$key $name"
        }
        Assert-LabTarget $archives "PI_SESSION_ARCHIVE_DIR $name"
    }
    foreach ($key in $destinations.Keys) { Assert-LabTarget $destinations[$key] $key }
    foreach ($key in @('npm_config_userconfig', 'npm_config_globalconfig')) {
        Assert-SyntheticNpmConfig $destinations[$key] $key
    }
    $piCommand = Join-Path $targets.NpmPrefix 'pi.cmd'
    Assert-LabTarget $piCommand 'planned Pi launcher'
    Write-Output 'LAB PREFLIGHT PLAN: PASS (read-only; no installer or Pi invoked)'
    foreach ($name in @('PiRoot', 'NpmPrefix', 'TestCwd')) {
        Write-Output ("{0}=<LAB_ROOT>/{1}" -f $name, $targets[$name].Substring($lab.Length + 1).Replace('\', '/'))
    }
    Write-Output ("profiles={0}; launcher=<LAB_ROOT>/{1}" -f ($profileNames -join ','), $piCommand.Substring($lab.Length + 1).Replace('\', '/'))
    Write-Output ('pinned destinations (not applied): ' + (($destinations.Keys | Sort-Object) -join ', '))
    Write-Output 'profiles: PI_CODING_AGENT_DIR, PI_CODING_AGENT_SESSION_DIR, PI_SESSION_DIR, PI_SESSION_ARCHIVE_DIR; MCP discovery must be exclusive with empty lab-only config.'
    Write-Output 'NOT TESTED: actual Pi runtime, DB/WAL writes, child processes, MCP/trace/session and global-write attribution; installation is not authorized.'
} catch {
    # Expected failures must not reveal supplied paths, JSON contents or PowerShell source locations.
    Write-Output 'LAB PREFLIGHT FAIL: invalid or unsafe lab target'
    exit 1
}
