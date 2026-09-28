[CmdletBinding()]
param(
    [ValidateSet('Code', 'Task', 'Both')]
    [string]$Profile = 'Both',

    [ValidateSet('Check', 'Apply', 'Restore')]
    [string]$Mode = 'Check',

    [string]$PiRoot = (Join-Path $HOME '.pi'),

    [string]$RepoRoot = (Split-Path $PSScriptRoot -Parent)
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

function Get-PythonInvocation {
    $python = Get-Command python -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($python) { return [pscustomobject]@{ Command = $python.Source; Prefix = @() } }
    $py = Get-Command py -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($py) { return [pscustomobject]@{ Command = $py.Source; Prefix = @('-3') } }
    throw 'Python 3 is required to check or apply local patches.'
}

function Get-PatchesForProfile {
    param([string]$ProfileName, [psobject]$Manifest)
    $result = New-Object System.Collections.Generic.List[string]
    foreach ($entry in $Manifest.profiles.common) {
        if ($entry.PSObject.Properties.Name -contains 'patch') { $result.Add([string]$entry.patch) }
        if ($ProfileName -eq 'Task' -and $entry.PSObject.Properties.Name -contains 'taskProfilePatch') {
            $result.Add([string]$entry.taskProfilePatch)
        }
    }
    if ($ProfileName -eq 'Code') {
        foreach ($entry in $Manifest.profiles.codeOnly) {
            if ($entry.PSObject.Properties.Name -contains 'patch') { $result.Add([string]$entry.patch) }
        }
    }
    return @($result | Select-Object -Unique)
}

try {
    $RepoRoot = Resolve-FullPath $RepoRoot
    $PiRoot = Resolve-FullPath $PiRoot
    $manifest = Read-JsonFile (Join-Path $RepoRoot 'manifests\pi-packages.lock.json')
    $python = Get-PythonInvocation
    $profiles = Get-SelectedProfiles -Profile $Profile
    $needsApply = $false
    $fatal = $false

    Write-Host "PATCH $Mode"
    foreach ($selected in $profiles) {
        $agentDir = Join-Path $PiRoot $selected.Directory
        Write-Host "profile $($selected.Name): $agentDir"
        foreach ($patchName in (Get-PatchesForProfile -ProfileName $selected.Name -Manifest $manifest)) {
            $patcher = Join-Path $RepoRoot "patches\$patchName\apply.py"
            if (-not (Test-Path -LiteralPath $patcher -PathType Leaf)) {
                Write-Host "FAIL $patchName patcher missing: $patcher"
                $fatal = $true
                continue
            }
            $arguments = @($python.Prefix) + @($patcher, '--agent-dir', $agentDir)
            if ($Mode -eq 'Check') { $arguments += '--check' }
            elseif ($Mode -eq 'Restore') { $arguments += '--restore' }
            elseif ($patchName -ne 'memory-windows-runtime') { $arguments += '--apply' }

            Write-Host "  $patchName"
            $output = (& $python.Command @arguments 2>&1 | Out-String).TrimEnd()
            $exitCode = $LASTEXITCODE
            if ($output) { Write-Host $output }

            if ($Mode -eq 'Check') {
                if ($exitCode -eq 0) {
                    Write-Host "PASS $patchName"
                } elseif ($exitCode -eq 1) {
                    Write-Host "NEEDS-APPLY $patchName"
                    $needsApply = $true
                } else {
                    Write-Host "FAIL $patchName check exited $exitCode"
                    $fatal = $true
                }
            } elseif ($exitCode -ne 0) {
                Write-Host "FAIL $patchName $Mode exited $exitCode"
                $fatal = $true
            } else {
                Write-Host "PASS $patchName $Mode"
            }
        }
    }

    if ($fatal) { exit 2 }
    if ($Mode -eq 'Check' -and $needsApply) { exit 1 }
    exit 0
} catch {
    Write-Error $_.Exception.Message
    exit 2
}
