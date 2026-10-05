[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$FixtureRoot)
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$exe = (Get-Process -Id $PID).Path
. (Join-Path $repo 'scripts/common.ps1')
$fixtureParent = Assert-PrivateLabRoot -LabRoot $FixtureRoot -RepoRoot $repo
Assert-NoLabReparseTree $fixtureParent
$fixture = Join-Path $fixtureParent ('pi-lab-installer-' + [guid]::NewGuid().ToString('N'))
$lab = Join-Path $fixture 'lab'
$bin = Join-Path $fixture 'bin'
$installer = Join-Path $repo 'scripts\install.ps1'
$verifier = Join-Path $repo 'scripts\verify.ps1'
$passed = 0
function Check([string]$Label, [bool]$Condition) {
    if (-not $Condition) { throw "FAIL $Label" }
    $script:passed++
    Write-Host "PASS $Label"
}
function Run([string]$Script, [string[]]$Arguments) {
    $old = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $text = (& $exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $Script @Arguments 2>&1 | Out-String)
        return [pscustomobject]@{ Code = $LASTEXITCODE; Text = $text }
    } finally { $ErrorActionPreference = $old }
}
try {
    New-Item -ItemType Directory -Path $bin, (Join-Path $lab 'test-cwd\.pi'), (Join-Path $lab 'pi-root\agent'), (Join-Path $lab 'pi-root\task') -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $lab 'test-cwd\.pi\settings.json'), '{"pi-memory":{"localPath":"../memory"}}')
    $runtime = Get-Content -LiteralPath (Join-Path $repo 'manifests\runtime.lock.json') -Raw | ConvertFrom-Json
    $external = Get-Content -LiteralPath (Join-Path $repo 'manifests\external-tools.lock.json') -Raw | ConvertFrom-Json
    $common = @('-LabRoot', $lab, '-RepoRoot', $repo, '-Profile', 'Both')
    $plan = Run $installer $common
    Check 'fresh lab plan does not create npm prefix' ($plan.Code -eq 0 -and $plan.Text.Contains('both synthetic profiles passed') -and -not (Test-Path (Join-Path $lab 'npm-prefix')))
    Check 'plan shows private candidate and both profile targets' ($plan.Text.Contains((Join-Path $lab 'npm-prefix\pi.cmd')) -and $plan.Text.Contains((Join-Path $lab 'pi-root\agent')) -and $plan.Text.Contains((Join-Path $lab 'pi-root\task')))
    $outside = Run $installer @('-LabRoot', $repo, '-RepoRoot', $repo, '-Apply')
    Check 'outside root rejected before writes' ($outside.Code -ne 0 -and -not (Test-Path (Join-Path $lab 'npm-prefix')))
    [IO.File]::WriteAllText((Join-Path $lab 'pi-root\agent\mcp.json'), '{"mcpServers":{"unsafe":{"command":"pi"}},"settings":{"scriptMode":false}}')
    $badProfile = Run $installer ($common + @('-Apply'))
    Check 'Code profile must pass gate before either profile writes' ($badProfile.Code -ne 0 -and -not (Test-Path (Join-Path $lab 'npm-prefix')))
    Remove-Item -LiteralPath (Join-Path $lab 'pi-root\agent\mcp.json')
    [IO.File]::WriteAllText((Join-Path $lab 'pi-root\task\mcp.json'), '{"mcpServers":{"unsafe":{"command":"pi"}},"settings":{"scriptMode":false}}')
    $badTask = Run $installer ($common + @('-Apply'))
    Check 'Task profile must pass gate before either profile writes' ($badTask.Code -ne 0 -and -not (Test-Path (Join-Path $lab 'npm-prefix')))
    Remove-Item -LiteralPath (Join-Path $lab 'pi-root\task\mcp.json')
    $cache = Join-Path $lab 'npm-cache'
    $outsideCache = Join-Path $fixture 'outside-cache'
    New-Item -ItemType Directory -Path $cache, $outsideCache -Force | Out-Null
    $junction = Join-Path $cache '_cacache'
    New-Item -ItemType Junction -Path $junction -Target $outsideCache -ErrorAction Stop | Out-Null
    try {
        $escaped = Run $installer ($common + @('-Apply'))
        Check 'nested npm cache junction rejected before tool or package writes' ($escaped.Code -ne 0 -and $escaped.Text.Contains('reparse point') -and -not (Test-Path (Join-Path $lab 'npm-prefix')) -and @(Get-ChildItem -LiteralPath $outsideCache -Force).Count -eq 0)
    } finally {
        & $env:ComSpec /d /c "rmdir `"$junction`"" | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Could not remove synthetic cache junction safely.' }
    }
    $node = (Get-Command node).Source.Replace('%', '%%')
    $fake = @'
const fs = require('fs'), path = require('path');
const lab = process.env.FAKE_LAB_PATH;
const args = process.argv.slice(2);
fs.appendFileSync(path.join(lab, 'calls.jsonl'), JSON.stringify({tool:process.env.FAKE_TOOL,args,home:process.env.HOME,profile:process.env.PI_CODING_AGENT_DIR || '',secret:process.env.SECRET_SENTINEL || '',noBytecode:process.env.PYTHONDONTWRITEBYTECODE || '',shellAvailable:(process.env.PATH || '').split(path.delimiter).some(dir => fs.existsSync(path.join(dir, 'powershell.exe')))}) + '\n');
if (args[0] === '--version') { console.log(process.env.FAKE_VERSION); process.exit(0); }
if (process.env.FAKE_TOOL === 'npm' && args[0] === 'install') {
  const prefix = path.join(lab, 'npm-prefix');
  const spec = args[args.length - 1];
  const version = spec.slice(spec.lastIndexOf('@') + 1);
  const pkg = path.join(prefix, 'node_modules', '@earendil-works', 'pi-coding-agent');
  fs.mkdirSync(pkg, {recursive:true});
  fs.writeFileSync(path.join(pkg, 'package.json'), JSON.stringify({name:'@earendil-works/pi-coding-agent',version}));
  fs.writeFileSync(path.join(prefix, 'pi.cmd'), '@set FAKE_TOOL=pi\r\n@set FAKE_VERSION=' + version + '\r\n@set FAKE_LAB_PATH=' + lab + '\r\n@"' + process.execPath + '" "' + __filename + '" %*\r\n');
  process.exit(0);
}
if (process.env.FAKE_TOOL === 'pi' && args[0] === 'install') process.exit(17);
process.exit(9);
'@
    [IO.File]::WriteAllText((Join-Path $bin 'fake.js'), $fake)
    $versions = @{ node = [string]$runtime.runtime.node; npm = [string]$runtime.runtime.npm; git = [string](@($external.common | Where-Object name -eq 'git')[0].version); python = '3.13.0'; uv = [string](@($external.common | Where-Object name -eq 'uv')[0].version) }
    foreach ($tool in $versions.Keys) {
        $command = "@set FAKE_TOOL=$tool`r`n@set FAKE_VERSION=$($versions[$tool])`r`n@set FAKE_LAB_PATH=$lab`r`n@`"$node`" `"%~dp0fake.js`" %*`r`n"
        [IO.File]::WriteAllText((Join-Path $bin "$tool.cmd"), $command)
    }
    $oldPath = $env:PATH
    $oldSecret = $env:SECRET_SENTINEL
    try {
        $env:PATH = "$bin;$oldPath"
        $env:SECRET_SENTINEL = 'synthetic-only'
        $result = Run $installer ($common + @('-Apply'))
        Check 'candidate launcher invoked from private prefix after private npm install' ($result.Code -ne 0 -and $result.Text.Contains('Command failed') -and (Test-Path (Join-Path $lab 'npm-prefix\pi.cmd')))
        $goalSettings = Read-JsonFile (Join-Path $lab 'pi-root\agent\pi-goal-x-settings.json')
        Check 'fresh Code profile receives unlimited implicit Goal X with Oracle and Auditor' ($goalSettings.strictExecutionContract -eq $false -and -not ($goalSettings.PSObject.Properties.Name -contains 'maxAutonomousRuns') -and $goalSettings.disabled -eq $false -and $goalSettings.oracle.enabled -eq $true -and $goalSettings.oracle.maxFailedAttemptsPerBlocker -eq 2)
        Check 'fresh Code profile receives permanent autonomy instructions' ((Get-Content (Join-Path $lab 'pi-root\agent\AGENTS.md') -Raw).Contains('Never set maxAutonomousRuns to 0.'))
        $calls = @((Get-Content -LiteralPath (Join-Path $lab 'calls.jsonl')) | ForEach-Object { $_ | ConvertFrom-Json })
        Check 'exact Pi version installed into private npm prefix' (@($calls | Where-Object { $_.tool -eq 'npm' -and $_.args[-1] -eq "$($runtime.runtime.pi.package)@$($runtime.runtime.pi.version)" -and $_.args -contains '--prefix' }).Count -eq 1)
        Check 'candidate Pi version and install, no global pi fallback' (@($calls | Where-Object { $_.tool -eq 'pi' -and $_.args[0] -eq 'install' }).Count -eq 1)
        Check 'fake children received lab home without provider secret' (@($calls | Where-Object { $_.secret -ne '' -or $_.home -ne (Join-Path $lab 'home') }).Count -eq 0)
        Check 'synthetic install child receives Python bytecode disabled' (@($calls | Where-Object { $_.noBytecode -ne '1' }).Count -eq 0)
        Check 'lab child PATH resolves PowerShell for package lifecycle' (@($calls | Where-Object { -not $_.shellAvailable }).Count -eq 0)
        $verify = Run $verifier @('-LabRoot', $lab, '-RepoRoot', $repo, '-Profile', 'Both')
        Check 'verifier refuses incomplete installed state before claiming success' ($verify.Code -ne 0 -and $verify.Text.Contains('installed-state validation refused') -and -not $verify.Text.Contains('VERIFIED INSTALLED-STATE: PASS'))
        $callsBeforeReapply = @((Get-Content (Join-Path $lab 'calls.jsonl')) | ForEach-Object { $_ | ConvertFrom-Json } | Where-Object { $_.args[0] -eq 'install' }).Count
        $reapplyPlan = Run $installer $common
        $reapply = Run $installer ($common + @('-Apply'))
        $callsAfterReapply = @((Get-Content (Join-Path $lab 'calls.jsonl')) | ForEach-Object { $_ | ConvertFrom-Json } | Where-Object { $_.args[0] -eq 'install' }).Count
        Check 'mixed reapply Plan and Apply refuse before package writes' ($reapplyPlan.Code -ne 0 -and $reapply.Code -ne 0 -and $callsAfterReapply -eq $callsBeforeReapply)
        $skipped = Run $verifier @('-LabRoot', $lab, '-SkipPatchChecks', '-RepoRoot', $repo)
        Check 'lab verifier cannot mask failed patch gate' ($skipped.Code -ne 0)
    } finally { $env:PATH = $oldPath; $env:SECRET_SENTINEL = $oldSecret }
    Write-Host "RESULT $passed passed"
} finally {
    Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue
}
