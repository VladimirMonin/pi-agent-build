[CmdletBinding()]
param(
    [ValidateSet('Code', 'Task', 'Both')]
    [string]$Profile = 'Both',

    [switch]$Apply,

    [string]$PiRoot = (Join-Path $HOME '.pi'),

    [string]$RepoRoot = '',

    [switch]$SkipPackageInstall,

    [switch]$SkipPatches,

    [switch]$SyncSettingsOnly,

    [switch]$ReplaceProfileConfigs
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
if (-not $RepoRoot) { $RepoRoot = Split-Path $PSScriptRoot -Parent }

function Assert-PinnedPackageEntry {
    param([psobject]$Entry)
    $version = [string]$Entry.version
    if ($version -notmatch '^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$') {
        throw "Package $($Entry.package) is not pinned to an exact semantic version: $version"
    }
    $source = [string]$Entry.source
    if ($source.StartsWith('npm:')) {
        if (-not $source.EndsWith("@$version", [System.StringComparison]::Ordinal)) {
            throw "Package source/version mismatch for $($Entry.package): $source vs $version"
        }
    } elseif ($source -match '^https://github\.com/') {
        if ([string]$Entry.kind -ne 'git-commit' -or [string]$Entry.commit -notmatch '^[0-9a-f]{40}$') {
            throw "Git package $($Entry.package) is not pinned to an exact commit."
        }
        if ([string]$Entry.tagObject -notmatch '^[0-9a-f]{40}$') {
            throw "Git package $($Entry.package) has no immutable annotated tag object metadata."
        }
        if (-not $source.EndsWith("@$($Entry.commit)", [System.StringComparison]::Ordinal)) {
            throw "Git source/commit mismatch for $($Entry.package): $source vs $($Entry.commit)"
        }
        if ([string]$Entry.releaseTag -ne "v$version") {
            throw "Git release tag/version mismatch for $($Entry.package): $($Entry.releaseTag) vs $version"
        }
    } else {
        throw "Unsupported package source: $source"
    }
}

function Assert-ExactCommandVersion {
    param([string]$Command, [string[]]$Arguments, [string]$Expected, [string]$Label)
    $result = Get-CommandOutput -Command $Command -Arguments $Arguments -SanitizeEnvironment
    if (-not $result.Found) { throw "$Label is required but '$Command' was not found." }
    if ($result.ExitCode -ne 0) { throw "$Label version check failed with exit code $($result.ExitCode)." }
    $actual = Get-VersionFromText $result.Output
    if ($actual -ne $Expected) { throw "$Label version mismatch: expected $Expected, found $actual." }
    Write-Host "PASS $Label $actual"
}

function Test-VersionAtLeast {
    param([string]$Actual, [string]$Minimum)
    try {
        $actualVersion = [version]$Actual
        $minimumVersion = [version]$Minimum
        return $actualVersion -ge $minimumVersion
    } catch { return $false }
}

function Assert-MinimumCommandVersion {
    param([string]$Command, [string[]]$Arguments, [string]$Minimum, [string]$Label)
    $result = Get-CommandOutput -Command $Command -Arguments $Arguments -SanitizeEnvironment
    if (-not $result.Found) { throw "$Label is required but '$Command' was not found." }
    $actual = Get-VersionFromText $result.Output
    if (-not $actual -or -not (Test-VersionAtLeast -Actual $actual -Minimum $Minimum)) {
        throw "$Label version mismatch: expected at least $Minimum, found $actual."
    }
    Write-Host "PASS $Label $actual"
}

function Get-ProfilePackages {
    param([string]$ProfileName, [psobject]$Manifest)
    $packages = @($Manifest.profiles.common)
    if ($ProfileName -eq 'Code') { $packages += @($Manifest.profiles.codeOnly) }
    return $packages
}

function Assert-InstalledPackageVersion {
    param([string]$NodeModulesRoot, [string]$PackageName, [string]$Expected)
    $relative = $PackageName.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
    $packageJson = Join-Path (Join-Path $NodeModulesRoot $relative) 'package.json'
    $metadata = Read-JsonFile $packageJson
    if ([string]$metadata.version -ne $Expected) {
        throw "Installed $PackageName version mismatch: expected $Expected, found $($metadata.version)."
    }
    Write-Host "PASS $PackageName $Expected"
}

function Assert-InstalledProfilePackage {
    param([string]$ProfileRoot, [psobject]$Entry)
    $source = [string]$Entry.source
    if ($source.StartsWith('npm:')) {
        Assert-InstalledPackageVersion -NodeModulesRoot (Join-Path $ProfileRoot 'npm\node_modules') -PackageName ([string]$Entry.package) -Expected ([string]$Entry.version)
        return
    }
    if ($source -notmatch '^https://github\.com/([^/]+)/([^@]+)@([0-9a-f]{40})$') {
        throw "Unsupported installed Git package source: $source"
    }
    $repositoryPath = $Matches[2]
    if ($repositoryPath.EndsWith('.git')) { $repositoryPath = $repositoryPath.Substring(0, $repositoryPath.Length - 4) }
    $relative = Join-Path 'git\github.com' (Join-Path $Matches[1] $repositoryPath)
    $packageRoot = Join-Path $ProfileRoot $relative
    if (-not (Test-Path -LiteralPath (Join-Path $packageRoot '.git') -PathType Container)) {
        throw "Installed Git package checkout missing: $packageRoot"
    }
    $metadata = Read-JsonFile (Join-Path $packageRoot 'package.json')
    if ([string]$metadata.version -ne [string]$Entry.version) {
        throw "Installed $($Entry.package) version mismatch: expected $($Entry.version), found $($metadata.version)."
    }
    $head = Get-CommandOutput -Command 'git' -Arguments @('-C', $packageRoot, 'rev-parse', 'HEAD')
    $tagObject = Get-CommandOutput -Command 'git' -Arguments @('-C', $packageRoot, 'rev-parse', "refs/tags/$($Entry.releaseTag)")
    $peeled = Get-CommandOutput -Command 'git' -Arguments @('-C', $packageRoot, 'rev-parse', "$($Entry.tagObject)^{commit}")
    if (-not $head.Found -or $head.ExitCode -ne 0 -or $head.Output.Trim() -ne [string]$Entry.commit) {
        throw "Installed $($Entry.package) HEAD does not match pinned commit."
    }
    if ($tagObject.ExitCode -ne 0 -or $tagObject.Output.Trim() -ne [string]$Entry.tagObject) {
        throw "Installed $($Entry.package) release tag object does not match manifest metadata."
    }
    if ($peeled.ExitCode -ne 0 -or $peeled.Output.Trim() -ne [string]$Entry.commit) {
        throw "Installed $($Entry.package) annotated tag does not peel to pinned commit."
    }
    Write-Host "PASS $($Entry.package)@$($Entry.version) (git $($Entry.commit))"
}

function Get-PackageIdentity {
    param($Item)
    $source = if ($Item -is [string]) { [string]$Item } else { [string]$Item.source }
    if ($source -match '^npm:(@[^/]+/[^@]+|[^@]+)(?:@.+)?$') { return $Matches[1] }
    if ($source -match '(?i)pi-polza(?:-connection-plugin)?(?:@|[\\/]|$)') { return 'pi-polza' }
    return $source
}

function Merge-PreservedSettings {
    param(
        [string]$Destination,
        [string]$Template,
        [psobject[]]$BuildPackages,
        [string]$BackupDirectory
    )
    [void](Backup-FileIfPresent -Source $Destination -BackupDirectory $BackupDirectory -BackupName 'settings.before-merge.json')
    $current = Read-JsonFile $Destination
    $desired = Read-JsonFile $Template
    $buildNames = @{}
    foreach ($entry in $BuildPackages) { $buildNames[[string]$entry.package] = $true }
    $extras = @()
    $currentPackages = if ($null -ne $current.PSObject.Properties['packages'] -and $null -ne $current.packages) { @($current.packages) } else { @() }
    foreach ($item in $currentPackages) {
        $identity = Get-PackageIdentity $item
        if (-not $buildNames.ContainsKey($identity)) { $extras += $item }
    }
    $mergedPackages = @($desired.packages) + @($extras)
    if ($null -ne $current.PSObject.Properties['packages']) {
        $current.packages = $mergedPackages
    } else {
        $current | Add-Member -MemberType NoteProperty -Name packages -Value $mergedPackages
    }
    if ($null -eq $current.PSObject.Properties['memory'] -or $null -eq $current.memory) {
        $current | Add-Member -MemberType NoteProperty -Name memory -Value ([pscustomobject]@{})
    }
    if ($null -ne $current.memory.PSObject.Properties['consolidationModel']) {
        $current.memory.consolidationModel = [string]$desired.memory.consolidationModel
    } else {
        $current.memory | Add-Member -MemberType NoteProperty -Name consolidationModel -Value ([string]$desired.memory.consolidationModel)
    }
    [IO.File]::WriteAllText(
        $Destination,
        (($current | ConvertTo-Json -Depth 100) + "`n"),
        (New-Object Text.UTF8Encoding($false))
    )
}

function Merge-PolzaMemoryProvider {
    param([string]$Destination, [string]$Template, [string]$BackupDirectory)
    $current = Read-JsonFile $Destination
    $desired = Read-JsonFile $Template
    if ($null -eq $current.PSObject.Properties['providers'] -or $null -eq $current.providers) {
        $current | Add-Member -MemberType NoteProperty -Name providers -Value ([pscustomobject]@{})
    }
    if ($null -ne $current.providers.PSObject.Properties['polza-memory']) { return 'preserved' }
    [void](Backup-FileIfPresent -Source $Destination -BackupDirectory $BackupDirectory -BackupName 'models.before-merge.json')
    $provider = $desired.providers.PSObject.Properties['polza-memory'].Value
    $current.providers | Add-Member -MemberType NoteProperty -Name 'polza-memory' -Value $provider
    [IO.File]::WriteAllText(
        $Destination,
        (($current | ConvertTo-Json -Depth 100) + "`n"),
        (New-Object Text.UTF8Encoding($false))
    )
    return 'merged'
}

try {
    $RepoRoot = Resolve-FullPath $RepoRoot
    $PiRoot = Resolve-FullPath $PiRoot
    $runtime = Read-JsonFile (Join-Path $RepoRoot 'manifests\runtime.lock.json')
    $packages = Read-JsonFile (Join-Path $RepoRoot 'manifests\pi-packages.lock.json')
    $external = Read-JsonFile (Join-Path $RepoRoot 'manifests\external-tools.lock.json')
    $profiles = Get-SelectedProfiles -Profile $Profile

    foreach ($entry in @($packages.profiles.common) + @($packages.profiles.codeOnly)) {
        Assert-PinnedPackageEntry $entry
    }

    $mode = if ($Apply) { 'APPLY' } else { 'PLAN' }
    Write-Host "$mode Pi Agent installation"
    Write-Host "profiles: $Profile"
    Write-Host "Pi root: $PiRoot"
    Write-Host "runtime: node@$($runtime.runtime.node), npm@$($runtime.runtime.npm), $($runtime.runtime.pi.package)@$($runtime.runtime.pi.version)"
    foreach ($selected in $profiles) {
        Write-Host "profile $($selected.Name) -> $(Join-Path $PiRoot $selected.Directory)"
        Write-Host "  settings <- profiles/$($selected.Template)/settings.template.json"
        foreach ($entry in (Get-ProfilePackages -ProfileName $selected.Name -Manifest $packages)) {
            Write-Host "  package $($entry.source)"
        }
    }
    if (@($profiles | Where-Object { $_.Name -eq 'Code' }).Count -gt 0) {
        foreach ($tool in $external.codeProfile) { Write-Host "external $($tool.package)@$($tool.version)" }
    }
    Write-Host 'credentials: not read, copied, requested, or written'
    Write-Host "existing profile configs: $(if ($ReplaceProfileConfigs) { 'replace with backup' } else { 'preserve' })"
    if ($SyncSettingsOnly) { Write-Host 'settings-only: verify installed payloads, back up and merge settings; no package/patch/credential writes' }
    else { Write-Host 'Pi interactive/model execution: disabled; Apply uses only the pi install package lifecycle' }

    if (-not $Apply) {
        Write-Host 'PLAN complete; no files or packages were changed. Re-run with -Apply.'
        exit 0
    }

    if ($SyncSettingsOnly) {
        if ($ReplaceProfileConfigs) { throw 'SyncSettingsOnly preserves existing settings; cannot combine with ReplaceProfileConfigs.' }
        foreach ($selected in $profiles) {
            $profileRoot = Join-Path $PiRoot $selected.Directory
            $destination = Join-Path $profileRoot 'settings.json'
            if (-not (Test-Path -LiteralPath $destination -PathType Leaf)) { throw "Existing settings missing: $destination" }
            $expected = @(Get-ProfilePackages -ProfileName $selected.Name -Manifest $packages)
            foreach ($entry in $expected) { Assert-InstalledProfilePackage -ProfileRoot $profileRoot -Entry $entry }
            $template = Join-Path $RepoRoot "profiles\$($selected.Template)\settings.template.json"
            $route = Get-CommandOutput -Command 'node' -Arguments @((Join-Path $RepoRoot 'scripts\check-memory-model.mjs'), $profileRoot, $template)
            if (-not $route.Found -or $route.ExitCode -ne 0) { throw "$($selected.Name) settings sync refused unavailable memory model: $($route.Output)" }
        }
        # Validate BOTH profiles before writing either settings file.
        foreach ($selected in $profiles) {
            $profileRoot = Join-Path $PiRoot $selected.Directory
            $destination = Join-Path $profileRoot 'settings.json'
            $template = Join-Path $RepoRoot "profiles\$($selected.Template)\settings.template.json"
            $expected = @(Get-ProfilePackages -ProfileName $selected.Name -Manifest $packages)
            $backup = Join-Path $profileRoot ".pi-agent-build-backups\install\$(New-BackupStamp)"
            Merge-PreservedSettings -Destination $destination -Template $template -BuildPackages $expected -BackupDirectory $backup
            Write-Host "merged $destination (settings only; packages and patches untouched)"
        }
        exit 0
    }

    # Static polza conflicts with the dynamic pi-polza provider. Do not silently
    # add polza-memory beside it; require an explicit private config migration.
    if (-not $ReplaceProfileConfigs) {
        foreach ($selected in $profiles) {
            $modelsPath = Join-Path (Join-Path $PiRoot $selected.Directory) 'models.json'
            if (Test-Path -LiteralPath $modelsPath -PathType Leaf) {
                $modelsConfig = Read-JsonFile $modelsPath
                if ($modelsConfig.PSObject.Properties['providers'] -and $modelsConfig.providers -and $modelsConfig.providers.PSObject.Properties['polza']) {
                    throw "$($selected.Name) static polza conflicts with pi-polza; back up models.json and migrate its provider to polza-memory before install"
                }
            }
        }
    }

    # An install may replace an existing bundle before patch application.
    # Refuse UNKNOWN/private injector states before any package lifecycle writes.
    if (-not $SkipPackageInstall) {
        foreach ($selected in $profiles) {
            $profileRoot = Join-Path $PiRoot $selected.Directory
            $dist = Join-Path $profileRoot 'npm\node_modules\@samfp\pi-memory\dist\index.js'
            if (Test-Path -LiteralPath $dist -PathType Leaf) {
                $probe = Get-CommandOutput -Command 'python' -Arguments @((Join-Path $RepoRoot 'patches\memory-windows-runtime\apply.py'), '--check', '--agent-dir', $profileRoot)
                if (-not $probe.Found -or $probe.ExitCode -gt 1) { throw "Memory preflight refused $($selected.Name) before reinstall: $($probe.Output)" }
                Write-Host "PASS $($selected.Name) memory preflight (known state; exit $($probe.ExitCode))"
            }
        }
    }

    if (-not $SkipPackageInstall) {
        Assert-ExactCommandVersion -Command 'node' -Arguments @('--version') -Expected ([string]$runtime.runtime.node) -Label 'Node.js'
        Assert-ExactCommandVersion -Command 'git' -Arguments @('--version') -Expected ([string](@($external.common | Where-Object { $_.name -eq 'git' })[0].version)) -Label 'Git'
        $pythonLock = @($external.common | Where-Object { $_.name -eq 'python' })[0]
        Assert-MinimumCommandVersion -Command 'python' -Arguments @('--version') -Minimum ([string]$pythonLock.minimumVersion) -Label 'Python'

        Invoke-CheckedCommand -Command 'npm' -Arguments @('install', '--global', '--no-audit', '--no-fund', "npm@$($runtime.runtime.npm)") -SanitizeEnvironment
        Assert-ExactCommandVersion -Command 'npm' -Arguments @('--version') -Expected ([string]$runtime.runtime.npm) -Label 'npm'
        Invoke-CheckedCommand -Command 'npm' -Arguments @('install', '--global', '--no-audit', '--no-fund', "$($runtime.runtime.pi.package)@$($runtime.runtime.pi.version)") -SanitizeEnvironment
        $globalRoot = Get-CommandOutput -Command 'npm' -Arguments @('root', '--global') -SanitizeEnvironment
        if (-not $globalRoot.Found -or $globalRoot.ExitCode -ne 0) { throw 'Could not resolve the global npm root.' }
        Assert-InstalledPackageVersion -NodeModulesRoot $globalRoot.Output.Trim() -PackageName ([string]$runtime.runtime.pi.package) -Expected ([string]$runtime.runtime.pi.version)
    }

    foreach ($selected in $profiles) {
        $profileRoot = Join-Path $PiRoot $selected.Directory
        $stamp = New-BackupStamp
        $backupRoot = Join-Path $profileRoot ".pi-agent-build-backups\install\$stamp"
        $template = Join-Path $RepoRoot "profiles\$($selected.Template)\settings.template.json"
        $destination = Join-Path $profileRoot 'settings.json'
        $copyStatus = Install-ProfileFile -Source $template -Destination $destination -BackupDirectory $backupRoot -BackupName 'settings.json' -Replace:$ReplaceProfileConfigs
        Write-Host "$copyStatus $destination"

        $modelsTemplate = Join-Path $RepoRoot 'config\models.polza-memory.example.json'
        $modelsDestination = Join-Path $profileRoot 'models.json'
        $modelsStatus = Install-ProfileFile -Source $modelsTemplate -Destination $modelsDestination -BackupDirectory $backupRoot -BackupName 'models.json' -Replace:$ReplaceProfileConfigs
        if ($modelsStatus -eq 'preserved') {
            $modelsStatus = Merge-PolzaMemoryProvider -Destination $modelsDestination -Template $modelsTemplate -BackupDirectory $backupRoot
        }
        Write-Host "$modelsStatus $modelsDestination"

        $ollamaTemplate = Join-Path $RepoRoot 'config\ollama-cloud.example.json'
        $ollamaDestination = Join-Path $profileRoot 'ollama-cloud.json'
        $ollamaStatus = Install-ProfileFile -Source $ollamaTemplate -Destination $ollamaDestination -BackupDirectory $backupRoot -BackupName 'ollama-cloud.json' -Replace:$ReplaceProfileConfigs
        Write-Host "$ollamaStatus $ollamaDestination"

        $skillSource = Join-Path $RepoRoot 'skills\memory-ops'
        $skillDestination = Join-Path $profileRoot 'skills\memory-ops'
        $skillStatus = Install-ProfileDirectory -Source $skillSource -Destination $skillDestination -BackupDirectory $backupRoot -BackupName 'skills\memory-ops' -Replace:$ReplaceProfileConfigs
        Write-Host "$skillStatus $skillDestination"

        if (-not $SkipPackageInstall) {
            if ($copyStatus -eq 'preserved') {
                [void](Backup-FileIfPresent -Source $destination -BackupDirectory $backupRoot -BackupName 'settings.pre-install.json')
            }
            $profilePackages = @(Get-ProfilePackages -ProfileName $selected.Name -Manifest $packages)
            foreach ($entry in $profilePackages) {
                Invoke-CheckedCommand -Command 'pi' -Arguments @('install', [string]$entry.source) -SanitizeEnvironment -Environment @{ PI_CODING_AGENT_DIR = $profileRoot }
                Assert-InstalledProfilePackage -ProfileRoot $profileRoot -Entry $entry
            }
            if ($copyStatus -eq 'preserved') {
                Merge-PreservedSettings -Destination $destination -Template $template -BuildPackages $profilePackages -BackupDirectory $backupRoot
                Write-Host "merged $destination"
            }
        }
    }

    if (-not $SkipPackageInstall -and @($profiles | Where-Object { $_.Name -eq 'Code' }).Count -gt 0) {
        $uvLock = @($external.common | Where-Object { $_.name -eq 'uv' })[0]
        Assert-ExactCommandVersion -Command 'uv' -Arguments @('--version') -Expected ([string]$uvLock.version) -Label 'uv'
        foreach ($tool in $external.codeProfile) {
            if ($tool.PSObject.Properties.Name -contains 'installer' -and [string]$tool.installer -eq 'uv tool') {
                Invoke-CheckedCommand -Command 'uv' -Arguments @('tool', 'install', '--force', '--prerelease=allow', "$($tool.package)==$($tool.version)") -SanitizeEnvironment
            } else {
                Invoke-CheckedCommand -Command 'npm' -Arguments @('install', '--global', '--no-audit', '--no-fund', "$($tool.package)@$($tool.version)") -SanitizeEnvironment
            }
        }

        $astGrep = @($external.codeProfile | Where-Object {
            $_.PSObject.Properties.Name -contains 'windowsSpawnFix' -and
            [string]$_.windowsSpawnFix -eq 'stage-real-executable'
        }) | Select-Object -First 1
        if ($astGrep) {
            $globalRoot = Get-CommandOutput -Command 'npm' -Arguments @('root', '--global') -SanitizeEnvironment
            $globalPrefix = Get-CommandOutput -Command 'npm' -Arguments @('prefix', '--global') -SanitizeEnvironment
            if (-not $globalRoot.Found -or $globalRoot.ExitCode -ne 0 -or -not $globalPrefix.Found -or $globalPrefix.ExitCode -ne 0) {
                throw 'Could not resolve npm global paths for the ast-grep executable.'
            }
            $relativePackage = ([string]$astGrep.package).Replace('/', [System.IO.Path]::DirectorySeparatorChar)
            $sourceExecutable = Join-Path (Join-Path $globalRoot.Output.Trim() $relativePackage) 'ast-grep.exe'
            $targetExecutable = Join-Path $globalPrefix.Output.Trim() 'ast-grep.exe'
            $backupDirectory = Join-Path $PiRoot ('.pi-agent-build-backups\global-tools\' + (New-BackupStamp))
            $stageStatus = Copy-FileWithBackup -Source $sourceExecutable -Destination $targetExecutable -BackupDirectory $backupDirectory -BackupName 'ast-grep.exe'
            Write-Host "$stageStatus $targetExecutable"
        }
    }

    if (-not $SkipPatches) {
        $powerShellExe = (Get-Process -Id $PID).Path
        Invoke-CheckedCommand -Command $powerShellExe -Arguments @('-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $PSScriptRoot 'apply-patches.ps1'), '-Profile', $Profile, '-Mode', 'Apply', '-PiRoot', $PiRoot, '-RepoRoot', $RepoRoot) -SanitizeEnvironment
    }


    # The pi-memory patch selects a local multilingual embedder. The plugin loads
    # it lazily with a 30s timeout; on a cold cache a slow download exceeds that
    # and the plugin silently degrades to FTS-only. Pre-download it here so the
    # first semantic search works. Network speed varies, so this is best-effort:
    # a failure only warns and never aborts the install.
    if (-not $SkipPatches -and -not $SkipPackageInstall) {
        foreach ($selected in (Get-SelectedProfiles -Profile $Profile)) {
            $profileRoot = Join-Path $PiRoot $selected.Directory
            $warmStatus = Warm-MemoryEmbedder -ProfileRoot $profileRoot
            Write-Host "$warmStatus $profileRoot memory embedder"
        }
    }
    Write-Host 'Installation complete. Pi was not started. No credentials were written.'
    exit 0
} catch {
    Write-Error $_.Exception.Message
    exit 1
}
