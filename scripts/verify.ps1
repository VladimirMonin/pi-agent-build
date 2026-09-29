[CmdletBinding()]
param(
    [ValidateSet('Code', 'Task', 'Both')]
    [string]$Profile = 'Both',

    [string]$PiRoot = (Join-Path $HOME '.pi'),

    [string]$RepoRoot = (Split-Path $PSScriptRoot -Parent),

    [switch]$RepositoryOnly,

    [switch]$ExternalOnly,

    [switch]$SkipPatchChecks,

    [switch]$SkipExternalChecks
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

$script:Failures = 0
$script:Warnings = 0

function Pass([string]$Message) { Write-Host "PASS $Message" }
function Warn([string]$Message) { $script:Warnings++; Write-Host "WARN $Message" }
function Fail([string]$Message) { $script:Failures++; Write-Host "FAIL $Message" }

function Test-RequiredPath {
    param([string]$Path, [string]$Label, [ValidateSet('Leaf', 'Container')][string]$Type = 'Leaf')
    if (Test-Path -LiteralPath $Path -PathType $Type) { Pass $Label; return $true }
    Fail "$Label missing: $Path"
    return $false
}

function Get-EntrySource {
    param($Item)
    if ($Item -is [string]) { return [string]$Item }
    if ($Item.PSObject.Properties.Name -contains 'source') { return [string]$Item.source }
    return ''
}

function Compare-ProfileTemplate {
    param([string]$ProfileName, [string]$TemplatePath, [psobject]$PackageManifest, [string]$PiVersion)
    try { $settings = Read-JsonFile $TemplatePath } catch { Fail $_.Exception.Message; return }
    if ([string]$settings.lastChangelogVersion -ne $PiVersion) {
        Fail "$ProfileName template Pi version is $($settings.lastChangelogVersion), expected $PiVersion"
    } else { Pass "$ProfileName template Pi version $PiVersion" }

    $expectedEntries = @($PackageManifest.profiles.common)
    if ($ProfileName -eq 'Code') { $expectedEntries += @($PackageManifest.profiles.codeOnly) }
    $expected = @($expectedEntries | ForEach-Object { [string]$_.source })
    $actual = @($settings.packages | ForEach-Object { Get-EntrySource $_ })
    if (($expected -join "`n") -ne ($actual -join "`n")) {
        Fail "$ProfileName template package list differs from pi-packages.lock.json"
    } else { Pass "$ProfileName template package list and exact versions" }
}

function Validate-ManifestSchema {
    param([string]$ManifestPath)
    try {
        $manifest = Read-JsonFile $ManifestPath
        $schemaRelative = [string]$manifest.'$schema'
        $schemaPath = Join-Path (Split-Path $ManifestPath -Parent) $schemaRelative
        if (-not (Test-Path -LiteralPath $schemaPath -PathType Leaf)) {
            Fail "schema target for $(Split-Path $ManifestPath -Leaf)"
            return
        }
        [void](Read-JsonFile $schemaPath)
        $pythonCode = 'import json,sys; from jsonschema import Draft202012Validator as V; i=json.load(open(sys.argv[1])); s=json.load(open(sys.argv[2])); V.check_schema(s); e=list(V(s).iter_errors(i)); print(chr(10).join(x.message for x in e)); raise SystemExit(bool(e))'
        $python = Get-CommandOutput -Command 'python' -Arguments @('-c', $pythonCode, $ManifestPath, $schemaPath)
        if (-not $python.Found) {
            Fail "Python unavailable; jsonschema validation is required for $(Split-Path $ManifestPath -Leaf)"
        } elseif ($python.ExitCode -eq 0) {
            Pass "schema $(Split-Path $ManifestPath -Leaf)"
        } elseif ($python.Output -match 'No module named|ModuleNotFoundError') {
            Fail "jsonschema validator unavailable for $(Split-Path $ManifestPath -Leaf): $($python.Output)"
        } else {
            Fail "schema validation $(Split-Path $ManifestPath -Leaf): $($python.Output)"
        }
    } catch { Fail $_.Exception.Message }
}

function Test-ExactToolVersion {
    param([string]$Command, [string[]]$Arguments, [string]$Expected, [string]$Label, [bool]$Required = $true)
    $result = Get-CommandOutput -Command $Command -Arguments $Arguments
    if (-not $result.Found) {
        if ($Required) { Fail "$Label command not found: $Command" } else { Warn "$Label not installed (optional)" }
        return
    }
    $actual = Get-VersionFromText $result.Output
    if ($result.ExitCode -ne 0 -or $actual -ne $Expected) {
        Fail "$Label expected $Expected, found $actual (exit $($result.ExitCode))"
    } else { Pass "$Label $actual" }
}

function Test-MinimumToolVersion {
    param([string]$Command, [string[]]$Arguments, [string]$Minimum, [string]$Label)
    $result = Get-CommandOutput -Command $Command -Arguments $Arguments
    if (-not $result.Found) { Fail "$Label command not found: $Command"; return }
    $actual = Get-VersionFromText $result.Output
    try { $ok = ([version]$actual -ge [version]$Minimum) } catch { $ok = $false }
    if ($result.ExitCode -ne 0 -or -not $ok) { Fail "$Label expected >= $Minimum, found $actual" }
    else { Pass "$Label $actual" }
}

function Test-DirectSpawn {
    param([string]$Command, [string[]]$Arguments, [string]$Expected, [string]$Label, [bool]$Required = $true)
    $resolved = Get-Command $Command -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $resolved) {
        if ($Required) { Fail "$Label command not found: $Command" } else { Warn "$Label not installed (optional)" }
        return
    }
    $path = [string]$resolved.Source
    if ([System.IO.Path]::GetExtension($path) -match '^\.(?:cmd|bat|ps1)$') {
        Fail "$Label resolves to a shell shim, not a directly spawnable executable: $path"
        return
    }
    try {
        $start = New-Object System.Diagnostics.ProcessStartInfo
        $start.FileName = $path
        $start.Arguments = ($Arguments | ForEach-Object { if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ } }) -join ' '
        $start.UseShellExecute = $false
        $start.RedirectStandardOutput = $true
        $start.RedirectStandardError = $true
        $start.CreateNoWindow = $true
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $start
        if (-not $process.Start()) { throw 'Process.Start returned false' }
        if (-not $process.WaitForExit(15000)) {
            try { $process.Kill() } catch {}
            throw 'version probe timed out after 15 seconds'
        }
        $output = ($process.StandardOutput.ReadToEnd() + "`n" + $process.StandardError.ReadToEnd()).Trim()
        $actual = Get-VersionFromText $output
        if ($process.ExitCode -ne 0) { Fail "$Label direct spawn exited $($process.ExitCode)" }
        elseif ($Expected -and $actual -ne $Expected) { Fail "$Label expected $Expected, found $actual" }
        else { Pass "$Label direct spawn $actual" }
    } catch { Fail "$Label direct spawn: $($_.Exception.Message)" }
}

function Test-CommandPresent {
    param([string]$Command, [string]$Label, [bool]$Required = $true)
    $resolved = Get-Command $Command -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $resolved) {
        if ($Required) { Fail "$Label command not found: $Command" } else { Warn "$Label not installed (optional)" }
        return
    }
    Pass "$Label command present"
}

function Test-ExternalTools {
    param([psobject]$Manifest, [psobject[]]$Profiles)
    $npmRoot = $null
    if (@($Profiles | Where-Object { $_.Name -eq 'Code' }).Count -gt 0) {
        foreach ($tool in $Manifest.codeProfile) {
            $arguments = @($tool.probeArguments)
            $kind = [string]$tool.probe
            if ($kind -eq 'npm-root-executable-version') {
                if (-not $npmRoot) {
                    $rootResult = Get-CommandOutput -Command 'npm' -Arguments @('root', '--global')
                    if (-not $rootResult.Found -or $rootResult.ExitCode -ne 0) {
                        Fail 'could not resolve npm global root for external probes'
                        continue
                    }
                    $npmRoot = $rootResult.Output.Trim()
                }
                $path = Join-Path $npmRoot (([string]$tool.npmExecutableRelativePath).Replace('/', [IO.Path]::DirectorySeparatorChar))
                Test-DirectSpawn -Command $path -Arguments $arguments -Expected ([string]$tool.version) -Label ([string]$tool.package) -Required $true
            } elseif ($kind -eq 'direct-version') {
                Test-DirectSpawn -Command ([string]$tool.command) -Arguments $arguments -Expected ([string]$tool.version) -Label ([string]$tool.package) -Required $true
            } else {
                Fail "unsupported external probe '$kind' for $($tool.package)"
            }
        }
    }
    foreach ($tool in $Manifest.mcp) {
        $required = -not [bool]$tool.optional
        $kind = [string]$tool.probe
        if ($kind -eq 'command-present') {
            Test-CommandPresent -Command ([string]$tool.command) -Label ([string]$tool.package) -Required $required
        } elseif ($kind -eq 'command-version') {
            Test-ExactToolVersion -Command ([string]$tool.command) -Arguments @($tool.probeArguments) -Expected ([string]$tool.version) -Label ([string]$tool.package) -Required $required
        } else {
            Fail "unsupported MCP probe '$kind' for $($tool.package)"
        }
    }
}

function Test-InstalledProfile {
    param([psobject]$Selected, [string]$Root, [psobject]$PackageManifest)
    $profileRoot = Join-Path $Root $Selected.Directory
    $settingsPath = Join-Path $profileRoot 'settings.json'
    if (-not (Test-RequiredPath -Path $settingsPath -Label "$($Selected.Name) settings")) { return }
    try { [void](Read-JsonFile $settingsPath); Pass "$($Selected.Name) settings JSON" } catch { Fail $_.Exception.Message }
    $entries = @($PackageManifest.profiles.common)
    if ($Selected.Name -eq 'Code') { $entries += @($PackageManifest.profiles.codeOnly) }
    foreach ($entry in $entries) {
        $source = [string]$entry.source
        if ($source.StartsWith('npm:')) {
            $relative = ([string]$entry.package).Replace('/', [System.IO.Path]::DirectorySeparatorChar)
            $packageJson = Join-Path (Join-Path (Join-Path $profileRoot 'npm\node_modules') $relative) 'package.json'
            if (-not (Test-Path -LiteralPath $packageJson -PathType Leaf)) {
                Fail "$($Selected.Name) package missing: $($entry.package)"
                continue
            }
            try {
                $metadata = Read-JsonFile $packageJson
                if ([string]$metadata.version -eq [string]$entry.version) { Pass "$($Selected.Name) $($entry.package)@$($entry.version)" }
                else { Fail "$($Selected.Name) $($entry.package) expected $($entry.version), found $($metadata.version)" }
            } catch { Fail $_.Exception.Message }
            continue
        }
        if ($source -notmatch '^https://github\.com/([^/]+)/([^@]+)@([0-9a-f]{40})$') {
            Fail "$($Selected.Name) unsupported package source: $source"
            continue
        }
        $owner = $Matches[1]
        $repo = $Matches[2]
        if ($repo.EndsWith('.git')) { $repo = $repo.Substring(0, $repo.Length - 4) }
        $gitRoot = Join-Path (Join-Path (Join-Path $profileRoot 'git\github.com') $owner) $repo
        $packageJson = Join-Path $gitRoot 'package.json'
        if (-not (Test-Path -LiteralPath (Join-Path $gitRoot '.git') -PathType Container) -or -not (Test-Path -LiteralPath $packageJson -PathType Leaf)) {
            Fail "$($Selected.Name) Git package missing: $gitRoot"
            continue
        }
        try {
            $metadata = Read-JsonFile $packageJson
            if ([string]$metadata.version -ne [string]$entry.version) {
                Fail "$($Selected.Name) $($entry.package) expected $($entry.version), found $($metadata.version)"
                continue
            }
            $tagObject = Get-CommandOutput -Command 'git' -Arguments @('-C', $gitRoot, 'rev-parse', "refs/tags/$($entry.releaseTag)")
            $peeled = Get-CommandOutput -Command 'git' -Arguments @('-C', $gitRoot, 'rev-parse', "$($entry.tagObject)^{commit}")
            $head = Get-CommandOutput -Command 'git' -Arguments @('-C', $gitRoot, 'rev-parse', 'HEAD')
            if ($tagObject.ExitCode -ne 0 -or $tagObject.Output.Trim() -ne [string]$entry.tagObject) {
                Fail "$($Selected.Name) $($entry.package) release tag object differs from metadata"
            } elseif ($peeled.ExitCode -ne 0 -or $peeled.Output.Trim() -ne [string]$entry.commit -or $head.ExitCode -ne 0 -or $head.Output.Trim() -ne [string]$entry.commit) {
                Fail "$($Selected.Name) $($entry.package) checkout/tag does not resolve to pinned commit"
            } else { Pass "$($Selected.Name) $($entry.package)@$($entry.version) git $($entry.commit)" }
        } catch { Fail $_.Exception.Message }
    }
}

try {
    $RepoRoot = Resolve-FullPath $RepoRoot
    $PiRoot = Resolve-FullPath $PiRoot
    $requiredRepositoryPaths = @(
        'manifests\runtime.lock.json', 'manifests\pi-packages.lock.json', 'manifests\external-tools.lock.json',
        'manifests\schemas\runtime-lock.schema.json', 'manifests\schemas\pi-packages-lock.schema.json',
        'manifests\schemas\external-tools-lock.schema.json', 'profiles\code\settings.template.json',
        'profiles\task\settings.template.json', 'scripts\install.ps1', 'scripts\apply-patches.ps1',
        'scripts\verify.ps1', 'scripts\safety-check.ps1', 'scripts\install-launchers.ps1',
        'launchers\pi-code.cmd', 'launchers\pi-task.cmd', 'launchers\pi-code', 'launchers\pi-task'
    )
    foreach ($relative in $requiredRepositoryPaths) {
        [void](Test-RequiredPath -Path (Join-Path $RepoRoot $relative) -Label $relative)
    }

    $runtime = Read-JsonFile (Join-Path $RepoRoot 'manifests\runtime.lock.json')
    $packages = Read-JsonFile (Join-Path $RepoRoot 'manifests\pi-packages.lock.json')
    $external = Read-JsonFile (Join-Path $RepoRoot 'manifests\external-tools.lock.json')
    foreach ($name in @('runtime', 'pi-packages', 'external-tools')) {
        Validate-ManifestSchema -ManifestPath (Join-Path $RepoRoot "manifests\$name.lock.json")
    }
    Compare-ProfileTemplate -ProfileName 'Code' -TemplatePath (Join-Path $RepoRoot 'profiles\code\settings.template.json') -PackageManifest $packages -PiVersion ([string]$runtime.runtime.pi.version)
    Compare-ProfileTemplate -ProfileName 'Task' -TemplatePath (Join-Path $RepoRoot 'profiles\task\settings.template.json') -PackageManifest $packages -PiVersion ([string]$runtime.runtime.pi.version)

    $patchNames = @()
    foreach ($entry in @($packages.profiles.common) + @($packages.profiles.codeOnly)) {
        if ($entry.PSObject.Properties.Name -contains 'patch') { $patchNames += [string]$entry.patch }
        if ($entry.PSObject.Properties.Name -contains 'taskProfilePatch') { $patchNames += [string]$entry.taskProfilePatch }
    }
    foreach ($patchName in @($patchNames | Select-Object -Unique)) {
        [void](Test-RequiredPath -Path (Join-Path $RepoRoot "patches\$patchName\apply.py") -Label "patch $patchName")
    }

    $profiles = Get-SelectedProfiles -Profile $Profile
    if ($ExternalOnly) {
        if ($RepositoryOnly) { throw '-ExternalOnly cannot be combined with -RepositoryOnly.' }
        if (-not $SkipExternalChecks) { Test-ExternalTools -Manifest $external -Profiles $profiles }
    } elseif (-not $RepositoryOnly) {
        Test-ExactToolVersion -Command 'node' -Arguments @('--version') -Expected ([string]$runtime.runtime.node) -Label 'Node.js'
        Test-ExactToolVersion -Command 'npm' -Arguments @('--version') -Expected ([string]$runtime.runtime.npm) -Label 'npm'
        $gitLock = @($external.common | Where-Object { $_.name -eq 'git' })[0]
        Test-ExactToolVersion -Command 'git' -Arguments @('--version') -Expected ([string]$gitLock.version) -Label 'Git'
        $pythonLock = @($external.common | Where-Object { $_.name -eq 'python' })[0]
        Test-MinimumToolVersion -Command 'python' -Arguments @('--version') -Minimum ([string]$pythonLock.minimumVersion) -Label 'Python'

        $globalRootResult = Get-CommandOutput -Command 'npm' -Arguments @('root', '--global')
        if ($globalRootResult.Found -and $globalRootResult.ExitCode -eq 0) {
            $piRelative = ([string]$runtime.runtime.pi.package).Replace('/', [System.IO.Path]::DirectorySeparatorChar)
            $piPackageJson = Join-Path (Join-Path $globalRootResult.Output.Trim() $piRelative) 'package.json'
            if (Test-Path -LiteralPath $piPackageJson -PathType Leaf) {
                $piMetadata = Read-JsonFile $piPackageJson
                if ([string]$piMetadata.version -eq [string]$runtime.runtime.pi.version) { Pass "Pi package $($piMetadata.version)" }
                else { Fail "Pi package expected $($runtime.runtime.pi.version), found $($piMetadata.version)" }
            } else { Fail "global Pi package missing: $piPackageJson" }
        } else { Fail 'could not resolve global npm root' }

        foreach ($selected in $profiles) { Test-InstalledProfile -Selected $selected -Root $PiRoot -PackageManifest $packages }

        # memory embedder cache: the pi-memory patch selects a local multilingual
        # model. If it is not cached, the plugin still works but the first semantic
        # search falls back to FTS-only until the model downloads. Network speed
        # varies, so a missing cache is a WARN (run the warm-up helper), not a FAIL.
        if (-not $SkipPatchChecks) {
            foreach ($selected in $profiles) {
                $profileRoot = Join-Path $PiRoot $selected.Directory
                $dist = Join-Path $profileRoot 'npm\node_modules\@samfp\pi-memory\dist\index.js'
                if (-not (Test-Path -LiteralPath $dist -PathType Leaf)) { continue }
                $model = $null
                foreach ($line in (Get-Content -LiteralPath $dist -Encoding UTF8)) {
                    if ($line -match '^var MODEL = "(.+)";$') { $model = $Matches[1]; break }
                }
                if (-not $model) { continue }
                $cache = Join-Path $profileRoot "npm\node_modules\@xenova\transformers\.cache\$model"
                if (Test-Path -LiteralPath $cache -PathType Container) {
                    Pass "$($selected.Name) memory embedder cached ($model)"
                } else {
                    Warn "$($selected.Name) memory embedder not cached ($model); run scripts/warm-memory-embedder.mjs $profileRoot"
                }
            }
        }

        if (-not $SkipPatchChecks) {
            $powerShellExe = (Get-Process -Id $PID).Path
            & $powerShellExe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'apply-patches.ps1') -Profile $Profile -Mode Check -PiRoot $PiRoot -RepoRoot $RepoRoot
            $patchExit = $LASTEXITCODE
            if ($patchExit -eq 0) { Pass 'installed patch checks' }
            elseif ($patchExit -eq 1) { Fail 'one or more installed patches require application' }
            else { Fail "patch checks failed with exit code $patchExit" }
        }

        if (-not $SkipExternalChecks) {
            Test-ExternalTools -Manifest $external -Profiles $profiles
        }
    }

    Write-Host "VERIFY result: failures=$script:Failures warnings=$script:Warnings"
    if ($script:Failures -gt 0) { exit 1 }
    exit 0
} catch {
    Fail $_.Exception.Message
    Write-Host "VERIFY result: failures=$script:Failures warnings=$script:Warnings"
    exit 2
}
