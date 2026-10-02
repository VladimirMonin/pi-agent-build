[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$FixtureRoot)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'scripts\lab-preflight.ps1'
$exe = (Get-Process -Id $PID).Path
$passed = 0
$skipped = 0
# Explicit owned private fixture parent, not the checkout sibling or real user home.
$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $repo 'scripts/common.ps1')
$fixtureParent = Assert-PrivateLabRoot -LabRoot $FixtureRoot -RepoRoot $repo
Assert-NoLabReparseTree $fixtureParent
$fixture = Join-Path $fixtureParent ('pi-lab-preflight-' + [guid]::NewGuid().ToString('N'))

function Invoke-Preflight {
    param([string[]]$Extra = @())
    $argsList = @('-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $scriptPath,
        '-LabRoot', (Join-Path $fixture 'lab'), '-RepoRoot', (Join-Path $fixture 'repo')) + $Extra
    $prior = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = & $exe @argsList 2>&1 | Out-String
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $prior }
    return [pscustomobject]@{ Code = $code; Text = $output }
}

function Check {
    param([string]$Name, [bool]$Condition)
    if (-not $Condition) { throw "FAIL $Name" }
    $script:passed++
    Write-Output "PASS $Name"
}

try {
    $lab = Join-Path $fixture 'lab'
    $repo = Join-Path $fixture 'repo'
    $cwd = Join-Path $lab 'test-cwd'
    New-Item -ItemType Directory -Path $repo, (Join-Path $cwd '.pi'), (Join-Path $lab 'pi-root\agent'), (Join-Path $lab 'pi-root\task') -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $cwd '.pi\settings.json'), '{"pi-memory":{"localPath":"../memory"}}')
    $clean = Invoke-Preflight
    Check 'clean fixture and sanitized plan' ($clean.Code -eq 0 -and $clean.Text.Contains('LAB PREFLIGHT PLAN: PASS') -and -not $clean.Text.Contains($fixture))
    Check 'dry-run creates no planned target' (-not (Test-Path -LiteralPath (Join-Path $lab 'npm-prefix')) -and -not (Test-Path -LiteralPath (Join-Path $lab 'memory')) -and -not (Test-Path -LiteralPath (Join-Path $lab 'goal')))
    $outsideResult = Invoke-Preflight @('-NpmPrefix', $fixture)
    Check 'outside-root rejected without echoing path' ($outsideResult.Code -ne 0 -and -not $outsideResult.Text.Contains($fixture))
    Check 'repo-inside target rejected' ((Invoke-Preflight @('-TestCwd', $repo)).Code -ne 0)
    Check 'repo nested inside lab rejected' ((Invoke-Preflight @('-RepoRoot', $cwd)).Code -ne 0)
    $foreign = Join-Path $fixture 'foreign-repo'
    New-Item -ItemType Directory -Path (Join-Path $foreign '.git'), (Join-Path $foreign 'lab') -Force | Out-Null
    Check 'different Git checkout rejected as LabRoot' ((Invoke-Preflight @('-LabRoot', (Join-Path $foreign 'lab'))).Code -ne 0)
    $fakePrefix = Join-Path $lab 'npm-prefix'
    New-Item -ItemType Directory -Path $fakePrefix | Out-Null
    [IO.File]::WriteAllText((Join-Path $fakePrefix 'pi.cmd'), '@echo off')
    Check 'fake installed launcher cannot bypass pre-install gate' ((Invoke-Preflight).Code -ne 0)
    Remove-Item -LiteralPath $fakePrefix -Recurse -Force
    $npmConfig = Join-Path $lab 'npm-config'
    New-Item -ItemType Directory -Path $npmConfig | Out-Null
    [IO.File]::WriteAllText((Join-Path $npmConfig 'user.npmrc'), 'prefix=C:\unsafe')
    Check 'npm config redirect rejected' ((Invoke-Preflight).Code -ne 0)
    Remove-Item -LiteralPath $npmConfig -Recurse -Force
    Check 'Code-only profile accepted' ((Invoke-Preflight @('-Profile', 'Code')).Code -eq 0)
    Check 'Task-only profile accepted' ((Invoke-Preflight @('-Profile', 'Task')).Code -eq 0)
    $mcp = Join-Path $lab 'pi-root\agent\mcp.json'
    [IO.File]::WriteAllText($mcp, '{"mcpServers":{},"settings":{"scriptMode":false}}')
    Check 'empty synthetic MCP accepted' ((Invoke-Preflight).Code -eq 0)
    [IO.File]::WriteAllText($mcp, '{"mcpServers":{"unsafe":{"command":"pi"}},"settings":{"scriptMode":false}}')
    Check 'configured MCP rejected' ((Invoke-Preflight).Code -ne 0)
    Remove-Item -LiteralPath $mcp
    [IO.File]::WriteAllText((Join-Path $cwd '.pi\settings.json'), '{"pi-memory":{"localPath":"../../outside"}}')
    Check 'outside memory.localPath rejected' ((Invoke-Preflight).Code -ne 0)
    [IO.File]::WriteAllText((Join-Path $cwd '.pi\settings.json'), '{"pi-memory":{"localPath":"../memory"}}')
    New-Item -ItemType Directory -Path (Join-Path $lab 'memory') | Out-Null
    $outside = Join-Path $fixture 'outside'
    New-Item -ItemType Directory -Path $outside | Out-Null
    try {
        $dbLink = Join-Path $lab 'memory\memory.db'
        New-Item -ItemType SymbolicLink -Path $dbLink -Target $outside -ErrorAction Stop | Out-Null
        $dbResult = Invoke-Preflight
        Check 'DB file reparse escape rejected' ($dbResult.Code -ne 0 -and $dbResult.Text.Contains('LAB PREFLIGHT FAIL'))
        Remove-Item -LiteralPath $dbLink -Force
    } catch {
        $script:skipped++
        Write-Output 'SKIP symlink creation unavailable on this host'
    }
    $link = Join-Path $lab 'link'
    try {
        New-Item -ItemType SymbolicLink -Path $link -Target $outside -ErrorAction Stop | Out-Null
        $linkResult = Invoke-Preflight @('-NpmPrefix', $link)
        Check 'target directory reparse escape rejected' ($linkResult.Code -ne 0 -and $linkResult.Text.Contains('LAB PREFLIGHT FAIL'))
    } catch {
        $script:skipped++
        Write-Output 'SKIP symlink creation unavailable on this host'
    }
    Write-Output "RESULT: $passed passed, $skipped skipped"
} finally {
    Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue
}
