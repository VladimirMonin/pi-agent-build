[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$PowerShellExe = (Get-Process -Id $PID).Path
$script:Passed = 0
$script:Failed = 0
$script:TempRoots = @()

function New-TestRoot {
    $path = Join-Path ([System.IO.Path]::GetTempPath()) ("pi-agent-build-tests-{0}" -f ([guid]::NewGuid().ToString('N')))
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    $script:TempRoots += $path
    return $path
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Message)
    if ($Expected -ne $Actual) {
        throw "$Message (expected=[$Expected], actual=[$Actual])"
    }
}

function Invoke-PowerShellFile {
    param([string]$Path, [string[]]$Arguments = @())
    $outputFile = Join-Path (New-TestRoot) 'output.txt'
    $argumentList = @('-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $Path) + $Arguments
    $priorPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $PowerShellExe @argumentList *> $outputFile
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $priorPreference
    }
    $output = if (Test-Path -LiteralPath $outputFile) {
        [System.IO.File]::ReadAllText($outputFile)
    } else { '' }
    return [pscustomobject]@{ ExitCode = $exitCode; Output = $output }
}

function Invoke-NativeCapture {
    param([string]$Command, [string[]]$Arguments = @(), [hashtable]$Environment = @{})
    $outputFile = Join-Path (New-TestRoot) 'native-output.txt'
    $saved = @{}
    try {
        foreach ($name in $Environment.Keys) {
            $saved[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
            [Environment]::SetEnvironmentVariable($name, [string]$Environment[$name], 'Process')
        }
        $priorPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            & $Command @Arguments *> $outputFile
            $exitCode = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $priorPreference
        }
    } finally {
        foreach ($name in $Environment.Keys) {
            [Environment]::SetEnvironmentVariable($name, $saved[$name], 'Process')
        }
    }
    $output = if (Test-Path -LiteralPath $outputFile) { [IO.File]::ReadAllText($outputFile) } else { '' }
    return [pscustomobject]@{ ExitCode = $exitCode; Output = $output }
}

function Get-FileHashes {
    param([string[]]$Paths)
    $result = @{}
    foreach ($path in $Paths) { $result[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
    return $result
}

function Assert-HashesEqual {
    param([hashtable]$Expected, [hashtable]$Actual, [string]$Message)
    foreach ($path in $Expected.Keys) {
        Assert-Equal $Expected[$path] $Actual[$path] "$Message ($path)"
    }
}

function Copy-RepositoryFixture {
    $root = New-TestRoot
    foreach ($name in @('scripts', 'manifests', 'profiles', 'launchers', 'patches')) {
        Copy-Item -LiteralPath (Join-Path $RepoRoot $name) -Destination (Join-Path $root $name) -Recurse
    }
    return $root
}

function New-VersionExecutable {
    param([string]$Path, [string]$Version, [switch]$CbmHelp)
    $parent = Split-Path $Path -Parent
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    $className = 'Program' + ([guid]::NewGuid().ToString('N'))
    $help = if ($CbmHelp) { 'if (joined.Contains("--help")) { Console.WriteLine("--format <tree|json>"); return 0; }' } else { '' }
    $source = @"
using System;
public static class $className {
  public static int Main(string[] args) {
    string joined = String.Join(" ", args);
    $help
    Console.WriteLine("$Version");
    return 0;
  }
}
"@
    Add-Type -TypeDefinition $source -Language CSharp -OutputAssembly $Path -OutputType ConsoleApplication
}

function New-FakeInstallToolchain {
    param([string]$Root)
    $bin = Join-Path $Root 'bin'
    $prefix = Join-Path $Root 'npm-prefix'
    New-Item -ItemType Directory -Path $bin -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $prefix 'node_modules') -Force | Out-Null
    $realNode = (Get-Command node).Source

    $npmJs = @'
const fs = require("fs"), path = require("path");
const root = path.resolve(__dirname, "..");
const prefix = path.join(root, "npm-prefix");
const log = path.join(root, "install-log.jsonl");
const args = process.argv.slice(2);
fs.appendFileSync(log, JSON.stringify({tool:"npm", args, secret:process.env.SECRET_SENTINEL || "", profile:process.env.PI_CODING_AGENT_DIR || ""}) + "\n");
if (args.length === 1 && args[0] === "--version") { console.log("11.11.0"); process.exit(0); }
if (args[0] === "root" && args.includes("--global")) { console.log(path.join(prefix, "node_modules")); process.exit(0); }
if (args[0] === "prefix" && args.includes("--global")) { console.log(prefix); process.exit(0); }
if (args[0] === "install") {
  const specs = args.filter(a => !a.startsWith("-")).slice(1);
  for (const spec of specs) {
    const at = spec.lastIndexOf("@");
    if (at <= 0) continue;
    const name = spec.slice(0, at), version = spec.slice(at + 1);
    const pkg = path.join(prefix, "node_modules", ...name.split("/"));
    fs.mkdirSync(pkg, {recursive:true});
    fs.writeFileSync(path.join(pkg, "package.json"), JSON.stringify({name, version}));
    if (name === "@ast-grep/cli") fs.writeFileSync(path.join(pkg, "ast-grep.exe"), "fake executable");
    if (["@ast-grep/cli", "codebase-memory-mcp"].includes(name) && !args.includes("--ignore-scripts")) {
      fs.writeFileSync(path.join(root, `postinstall-${name.replace(/[^a-z0-9]/gi,"_")}.txt`), "ran");
    }
  }
  process.exit(0);
}
console.error("unsupported fake npm args", args); process.exit(9);
'@
    [IO.File]::WriteAllText((Join-Path $bin 'fake-npm.js'), $npmJs)

    $piJs = @'
const fs = require("fs"), path = require("path");
const root = path.resolve(__dirname, "..");
const args = process.argv.slice(2);
fs.appendFileSync(path.join(root, "install-log.jsonl"), JSON.stringify({tool:"pi", args, secret:process.env.SECRET_SENTINEL || "", profile:process.env.PI_CODING_AGENT_DIR || ""}) + "\n");
if (args[0] !== "install" || !args[1] || !process.env.PI_CODING_AGENT_DIR) process.exit(8);
const source = args[1], agent = process.env.PI_CODING_AGENT_DIR;
const settingsPath = path.join(agent, "settings.json");
const settings = fs.existsSync(settingsPath) ? JSON.parse(fs.readFileSync(settingsPath, "utf8")) : {};
settings.__fakePiTouched = (settings.__fakePiTouched || 0) + 1;
fs.mkdirSync(agent, {recursive:true});
fs.writeFileSync(settingsPath, JSON.stringify(settings));
const failMarker = path.join(root, "fail-pi-install-on.txt");
if (fs.existsSync(failMarker) && source.includes(fs.readFileSync(failMarker, "utf8").trim())) process.exit(7);
if (source.startsWith("npm:")) {
  const spec = source.slice(4), at = spec.lastIndexOf("@");
  const name = spec.slice(0, at), version = spec.slice(at + 1);
  const pkg = path.join(agent, "npm", "node_modules", ...name.split("/"));
  fs.mkdirSync(pkg, {recursive:true});
  fs.writeFileSync(path.join(pkg, "package.json"), JSON.stringify({name, version}));
} else {
  const pkg = path.join(agent, "git", "github.com", "VladimirMonin", "pi-polza");
  fs.mkdirSync(path.join(pkg, ".git"), {recursive:true});
  fs.writeFileSync(path.join(pkg, "package.json"), JSON.stringify({name:"pi-polza", version:"0.2.1"}));
}
'@
    [IO.File]::WriteAllText((Join-Path $bin 'fake-pi.js'), $piJs)

    $nodeQuoted = $realNode.Replace('%', '%%')
    [IO.File]::WriteAllText((Join-Path $bin 'npm.cmd'), "@`"$nodeQuoted`" `"%~dp0fake-npm.js`" %*`r`n")
    [IO.File]::WriteAllText((Join-Path $bin 'pi.cmd'), "@`"$nodeQuoted`" `"%~dp0fake-pi.js`" %*`r`n")
    $gitJs = @'
const fs = require("fs"), path = require("path");
const root = path.resolve(__dirname, "..");
const args = process.argv.slice(2);
const commit = fs.existsSync(path.join(root, "fake-git-head.txt"))
  ? fs.readFileSync(path.join(root, "fake-git-head.txt"), "utf8").trim()
  : "cbc8a61262eb682fc61c9ab1b3b1ab72ef08f139";
if (args.length === 1 && args[0] === "--version") { console.log("git version 2.54.0.windows.1"); process.exit(0); }
if (args[0] === "-C" && args[2] === "rev-parse") {
  const ref = args[3];
  if (ref === "HEAD") console.log(commit);
  else if (ref === "refs/tags/v0.2.1") console.log("a93589ecd0075d3f4c34eb1f13bda891c5983d8c");
  else if (ref === "a93589ecd0075d3f4c34eb1f13bda891c5983d8c^{commit}" || ref === "a93589ecd0075d3f4c34eb1f13bda891c5983d8c{commit}") console.log("cbc8a61262eb682fc61c9ab1b3b1ab72ef08f139");
  else process.exit(7);
  process.exit(0);
}
process.exit(8);
'@
    [IO.File]::WriteAllText((Join-Path $bin 'fake-git.js'), $gitJs)
    [IO.File]::WriteAllText((Join-Path $bin 'git.cmd'), "@`"$nodeQuoted`" `"%~dp0fake-git.js`" %*`r`n")
    [IO.File]::WriteAllText((Join-Path $bin 'uv.cmd'), "@if `"%1`"==`"--version`" (@echo uv 0.9.27& @exit /b 0)`r`n@>>`"%~dp0..\install-log.jsonl`" echo {`"tool`":`"uv`",`"secret`":`"%SECRET_SENTINEL%`"}`r`n@exit /b 0`r`n")
    return [pscustomobject]@{ Bin = $bin; Prefix = $prefix; Log = (Join-Path $Root 'install-log.jsonl') }
}

function Test-Case {
    param([string]$Name, [scriptblock]$Body)
    try {
        & $Body
        $script:Passed++
        Write-Host "PASS $Name"
    } catch {
        $script:Failed++
        Write-Host "FAIL $Name :: $($_.Exception.Message)" -ForegroundColor Red
    }
}

try {
    Test-Case 'all requested scripts and schemas exist' {
        $required = @(
            'scripts/install.ps1',
            'scripts/apply-patches.ps1',
            'scripts/verify.ps1',
            'scripts/safety-check.ps1',
            'scripts/install-launchers.ps1',
            'manifests/schemas/runtime-lock.schema.json',
            'manifests/schemas/pi-packages-lock.schema.json',
            'manifests/schemas/external-tools-lock.schema.json'
        )
        foreach ($relative in $required) {
            Assert-True (Test-Path -LiteralPath (Join-Path $RepoRoot $relative)) "missing $relative"
        }
    }

    Test-Case 'PowerShell parser accepts every script' {
        $files = @(Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'scripts') -Filter '*.ps1' -File) +
            @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.ps1' -File)
        foreach ($file in $files) {
            $tokens = $null
            $errors = $null
            [void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
            Assert-Equal 0 @($errors).Count "syntax errors in $($file.Name)"
        }
    }

    Test-Case 'version parser preserves vendor-qualified exact versions' {
        . (Join-Path $RepoRoot 'scripts\common.ps1')
        Assert-Equal '2.54.0.windows.1' (Get-VersionFromText 'git version 2.54.0.windows.1') 'Git version was truncated'
        Assert-Equal '25.8.1' (Get-VersionFromText 'v25.8.1') 'Node version parse failed'
    }

    Test-Case 'lock manifests reference existing schemas' {
        foreach ($name in @('runtime', 'pi-packages', 'external-tools')) {
            $manifestPath = Join-Path $RepoRoot "manifests\$name.lock.json"
            $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
            Assert-Equal 1 $manifest.schemaVersion "$name schemaVersion"
            $schemaPath = Join-Path (Split-Path $manifestPath -Parent) ([string]$manifest.'$schema')
            Assert-True (Test-Path -LiteralPath $schemaPath) "$name schema target is missing"
            $schema = Get-Content -LiteralPath $schemaPath -Raw | ConvertFrom-Json
            Assert-Equal 'https://json-schema.org/draft/2020-12/schema' $schema.'$schema' "$name schema dialect"
            Assert-Equal $false $schema.additionalProperties "$name root must be closed"
        }
        $packageManifest = Get-Content -LiteralPath (Join-Path $RepoRoot 'manifests\pi-packages.lock.json') -Raw | ConvertFrom-Json
        $polza = @($packageManifest.profiles.common | Where-Object { $_.package -eq 'pi-polza' })[0]
        Assert-Equal '0.2.1' ([string]$polza.version) 'pi-polza package version'
        Assert-Equal 'cbc8a61262eb682fc61c9ab1b3b1ab72ef08f139' ([string]$polza.commit) 'pi-polza commit pin'
        Assert-Equal 'a93589ecd0075d3f4c34eb1f13bda891c5983d8c' ([string]$polza.tagObject) 'pi-polza annotated tag object'
        Assert-Equal 'v0.2.1' ([string]$polza.releaseTag) 'pi-polza release tag metadata'
        Assert-True ([string]$polza.source -match [regex]::Escape([string]$polza.commit)) 'pi-polza source is not pinned to the commit'
    }

    Test-Case 'install defaults to plan and does not create Pi root' {
        $root = New-TestRoot
        $piRoot = Join-Path $root 'pi-home'
        $result = Invoke-PowerShellFile (Join-Path $RepoRoot 'scripts\install.ps1') @(
            '-Profile', 'Code', '-PiRoot', $piRoot
        )
        Assert-Equal 0 $result.ExitCode 'install plan exit code'
        Assert-True (-not (Test-Path -LiteralPath $piRoot)) 'plan created the Pi root'
        Assert-True ($result.Output -match 'PLAN') 'plan marker missing'
        $runtime = Get-Content -LiteralPath (Join-Path $RepoRoot 'manifests\runtime.lock.json') -Raw | ConvertFrom-Json
        Assert-True ($result.Output.Contains("$($runtime.runtime.pi.package)@$($runtime.runtime.pi.version)")) 'Pi exact version missing from plan'
        Assert-True ($result.Output -match 'pi-cbm@1\.2\.1') 'Code package exact version missing from plan'
    }

    Test-Case 'PowerShell entrypoints resolve repository root after parameter binding' {
        $root = New-TestRoot
        $piRoot = Join-Path $root 'pi-home'
        $verify = Invoke-PowerShellFile (Join-Path $RepoRoot 'scripts\verify.ps1') @('-RepositoryOnly', '-PiRoot', $piRoot)
        Assert-Equal 0 $verify.ExitCode 'repository verification without -RepoRoot'
        $launchers = Invoke-PowerShellFile (Join-Path $RepoRoot 'scripts\install-launchers.ps1') @('-Profile', 'Task', '-TargetDir', (Join-Path $root 'bin'), '-PiRoot', $piRoot)
        Assert-Equal 0 $launchers.ExitCode 'launcher plan without -RepoRoot'
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $root 'bin'))) 'launcher plan wrote files'
    }

    Test-Case 'manifest and installed settings enforce goal-x before intercom' {
        $fixture = Copy-RepositoryFixture
        $manifestPath = Join-Path $fixture 'manifests\pi-packages.lock.json'
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        $common = @($manifest.profiles.common)
        $goal = [array]::FindIndex($common, [Predicate[object]]{ param($e) $e.package -eq 'pi-goal-x' })
        $intercom = [array]::FindIndex($common, [Predicate[object]]{ param($e) $e.package -eq 'pi-intercom' })
        Assert-True ($goal -ge 0 -and $intercom -gt $goal) 'fixture order changed unexpectedly'
        $temp = $common[$goal]; $common[$goal] = $common[$intercom]; $common[$intercom] = $temp
        $manifest.profiles.common = $common
        [IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 100))
        $reversed = Invoke-PowerShellFile (Join-Path $fixture 'scripts\verify.ps1') @('-RepositoryOnly', '-RepoRoot', $fixture)
        Assert-True ($reversed.Output -match 'manifest must load pi-goal-x before pi-intercom') 'reversed manifest was not rejected'

        $piRoot = Join-Path (New-TestRoot) 'pi-home'
        $profile = Join-Path $piRoot 'agent'
        New-Item -ItemType Directory -Path $profile -Force | Out-Null
        $settingsPath = Join-Path $profile 'settings.json'
        [IO.File]::WriteAllText($settingsPath, '{"packages":["npm:pi-intercom@0.16.1","npm:pi-goal-x@0.32.3"]}')
        $bad = Invoke-PowerShellFile (Join-Path $RepoRoot 'scripts\verify.ps1') @('-Profile', 'Code', '-PiRoot', $piRoot, '-RepoRoot', $RepoRoot, '-SkipPatchChecks', '-SkipExternalChecks')
        Assert-True ($bad.Output -match 'installed settings must load pinned pi-goal-x before pi-intercom') 'reversed installed order was not rejected'
        [IO.File]::WriteAllText($settingsPath, '{"packages":["npm:pi-goal-x@0.32.3","npm:pi-intercom@0.16.1"]}')
        $good = Invoke-PowerShellFile (Join-Path $RepoRoot 'scripts\verify.ps1') @('-Profile', 'Code', '-PiRoot', $piRoot, '-RepoRoot', $RepoRoot, '-SkipPatchChecks', '-SkipExternalChecks')
        Assert-True ($good.Output -match 'PASS Code installed goal-x/intercom order') 'correct installed order was not accepted'
    }

    Test-Case 'install preserves profile configs unless replacement is explicit' {
        $root = New-TestRoot
        $piRoot = Join-Path $root 'pi-home'
        $common = @('-Profile', 'Code', '-Apply', '-SkipPackageInstall', '-SkipPatches', '-PiRoot', $piRoot, '-RepoRoot', $RepoRoot)
        $first = Invoke-PowerShellFile (Join-Path $RepoRoot 'scripts\install.ps1') $common
        Assert-Equal 0 $first.ExitCode 'first config-only apply failed'
        $codeSettings = Join-Path $piRoot 'agent\settings.json'
        $models = Join-Path $piRoot 'agent\models.json'
        $ollama = Join-Path $piRoot 'agent\ollama-cloud.json'
        Assert-True (Test-Path -LiteralPath $codeSettings) 'Code settings were not installed'
        Assert-True (Test-Path -LiteralPath $models) 'Polza memory model template was not installed'
        Assert-True (Test-Path -LiteralPath $ollama) 'Ollama Cloud config was not installed'
        Assert-True (Test-Path -LiteralPath (Join-Path $piRoot 'agent\skills\memory-ops\SKILL.md')) 'memory-ops skill was not installed'
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $piRoot 'task\settings.json'))) 'Task profile was unexpectedly written'

        [System.IO.File]::WriteAllText($codeSettings, '{"local":"settings"}')
        [System.IO.File]::WriteAllText($models, '{"local":"models"}')
        [System.IO.File]::WriteAllText($ollama, '{"local":"ollama"}')
        $second = Invoke-PowerShellFile (Join-Path $RepoRoot 'scripts\install.ps1') $common
        Assert-Equal 0 $second.ExitCode 'second config-only apply failed'
        Assert-Equal '{"local":"settings"}' ([IO.File]::ReadAllText($codeSettings)) 'settings were silently overwritten'
        $mergedModels = Get-Content -LiteralPath $models -Raw | ConvertFrom-Json
        Assert-Equal 'models' ([string]$mergedModels.local) 'existing models field was not preserved'
        Assert-True ($null -ne $mergedModels.providers.'polza-memory') 'polza-memory was not merged into existing models'
        Assert-Equal '{"local":"ollama"}' ([IO.File]::ReadAllText($ollama)) 'ollama config was silently overwritten'
        Assert-True ($second.Output -match 'preserved|merged') 'preservation/merge was not reported'

        $replace = Invoke-PowerShellFile (Join-Path $RepoRoot 'scripts\install.ps1') ($common + @('-ReplaceProfileConfigs'))
        Assert-Equal 0 $replace.ExitCode 'explicit config replacement failed'
        Assert-True (([IO.File]::ReadAllText($codeSettings)) -notmatch '"local"') 'explicit replacement did not replace settings'
        $backups = @(Get-ChildItem -LiteralPath (Join-Path $piRoot 'agent\.pi-agent-build-backups\install') -Recurse -Filter 'settings.json' -File)
        Assert-True ($backups.Count -ge 1) 'explicit replacement did not back up settings'
        Assert-True (([System.IO.File]::ReadAllText($backups[-1].FullName)) -match '"local"') 'backup did not preserve prior settings'
    }

    Test-Case 'settings-only sync pins all plugins without reinstalling or losing private aliases' {
        $root = New-TestRoot
        $tools = New-FakeInstallToolchain $root
        $piRoot = Join-Path $root 'pi-root'
        $installer = Join-Path $RepoRoot 'scripts\install.ps1'
        $oldPath = $env:PATH
        $keyName = 'POLZA' + '_API_KEY'
        $oldPolzaKey = [Environment]::GetEnvironmentVariable($keyName, 'Process')
        try {
            $env:PATH = "$($tools.Bin);$oldPath"
            $first = Invoke-PowerShellFile $installer @('-Profile', 'Task', '-Apply', '-SkipPatches', '-PiRoot', $piRoot, '-RepoRoot', $RepoRoot)
            Assert-Equal 0 $first.ExitCode 'fixture install failed'
            $settings = Join-Path $piRoot 'task\settings.json'
            $json = Get-Content -LiteralPath $settings -Raw | ConvertFrom-Json
            $json.packages[0] = 'npm:pi-ollama-cloud'
            $json.packages = @($json.packages) + @('npm:private-extra')
            $json.extensions = @('./private-extension.ts')
            $json.memory | Add-Member -MemberType NoteProperty -Name factProjectAliases -Value @(@{ path = 'C:/private'; scope = 'example' })
            $json | Add-Member -MemberType NoteProperty -Name localPreference -Value 'keep'
            [IO.File]::WriteAllText($settings, (($json | ConvertTo-Json -Depth 100) + "`n"))
            $dist = Join-Path $piRoot 'task\npm\node_modules\@samfp\pi-memory\dist\index.js'
            New-Item -ItemType Directory -Path (Split-Path $dist -Parent) -Force | Out-Null
            [IO.File]::WriteAllText($dist, 'private-bundle-must-not-be-read-or-replaced')
            $callsBefore = @([IO.File]::ReadAllLines($tools.Log)).Count
            [Environment]::SetEnvironmentVariable($keyName, $null, 'Process')
            $refused = Invoke-PowerShellFile $installer @('-Profile', 'Task', '-Apply', '-SyncSettingsOnly', '-PiRoot', $piRoot, '-RepoRoot', $RepoRoot)
            Assert-True ($refused.ExitCode -ne 0 -and $refused.Output -match 'unresolved credential') 'settings sync accepted unavailable static memory model'
            Assert-Equal 'npm:pi-ollama-cloud' ([string](Get-Content -LiteralPath $settings -Raw | ConvertFrom-Json).packages[0]) 'preflight modified settings'
            [Environment]::SetEnvironmentVariable($keyName, 'synthetic-test-only', 'Process')
            $sync = Invoke-PowerShellFile $installer @('-Profile', 'Task', '-Apply', '-SyncSettingsOnly', '-PiRoot', $piRoot, '-RepoRoot', $RepoRoot)
            Assert-Equal 0 $sync.ExitCode "settings-only sync failed: $($sync.Output)"
            Assert-Equal $callsBefore @([IO.File]::ReadAllLines($tools.Log)).Count 'settings sync ran a package lifecycle'
            Assert-Equal 'private-bundle-must-not-be-read-or-replaced' ([IO.File]::ReadAllText($dist)) 'settings sync changed private memory bundle'
            $merged = Get-Content -LiteralPath $settings -Raw | ConvertFrom-Json
            $manifest = Get-Content -LiteralPath (Join-Path $RepoRoot 'manifests\pi-packages.lock.json') -Raw | ConvertFrom-Json
            Assert-Equal ([string]$manifest.profiles.common[0].source) ([string]$merged.packages[0]) 'unversioned package not pinned'
            Assert-Equal 'npm:private-extra' ([string]$merged.packages[-1]) 'private package was lost'
            Assert-Equal 'example' ([string]$merged.memory.factProjectAliases[0].scope) 'private aliases were lost'
            Assert-Equal 'keep' ([string]$merged.localPreference) 'private settings were lost'
            Assert-True (@($merged.extensions) -contains './private-extension.ts') 'private extension was lost'
            Assert-True (@($merged.extensions) -contains '-builtin:mcp') 'retained adapter did not disable built-in MCP'
        } finally { $env:PATH = $oldPath; [Environment]::SetEnvironmentVariable($keyName, $oldPolzaKey, 'Process') }
    }

    Test-Case 'installer preflight refuses unknown memory bundle before any install writes' {
        $root = New-TestRoot
        $tools = New-FakeInstallToolchain $root
        $piRoot = Join-Path $root 'pi-root'
        $profile = Join-Path $piRoot 'agent'
        $dist = Join-Path $profile 'npm\node_modules\@samfp\pi-memory\dist\index.js'
        New-Item -ItemType Directory -Path (Split-Path $dist -Parent) -Force | Out-Null
        [IO.File]::WriteAllText($dist, 'unrecognized private bundle')
        $settings = Join-Path $profile 'settings.json'
        [IO.File]::WriteAllText($settings, '{"owner":"untouched"}')
        $oldPath = $env:PATH
        try {
            $env:PATH = "$($tools.Bin);$oldPath"
            $result = Invoke-PowerShellFile (Join-Path $RepoRoot 'scripts\install.ps1') @('-Profile', 'Code', '-Apply', '-SkipPatches', '-PiRoot', $piRoot, '-RepoRoot', $RepoRoot)
            Assert-True ($result.ExitCode -ne 0 -and $result.Output -match 'Memory preflight refused') 'unknown bundle did not fail closed'
            Assert-Equal '{"owner":"untouched"}' ([IO.File]::ReadAllText($settings)) 'preflight changed settings'
            Assert-Equal 'unrecognized private bundle' ([IO.File]::ReadAllText($dist)) 'preflight changed bundle'
            Assert-True (-not (Test-Path -LiteralPath $tools.Log)) 'preflight launched a package lifecycle'
        } finally { $env:PATH = $oldPath }
    }

    Test-Case 'installer refuses a conflicting static Polza provider before package writes' {
        $root = New-TestRoot
        $tools = New-FakeInstallToolchain $root
        $piRoot = Join-Path $root 'pi-root'
        $profile = Join-Path $piRoot 'agent'
        New-Item -ItemType Directory -Path $profile -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $profile 'settings.json'), '{"owner":"untouched"}')
        [IO.File]::WriteAllText((Join-Path $profile 'models.json'), '{"providers":{"polza":{"apiKey":"!private-command"}}}')
        $oldPath = $env:PATH
        try {
            $env:PATH = "$($tools.Bin);$oldPath"
            $result = Invoke-PowerShellFile (Join-Path $RepoRoot 'scripts\install.ps1') @('-Profile', 'Code', '-Apply', '-SkipPatches', '-PiRoot', $piRoot, '-RepoRoot', $RepoRoot)
            Assert-True ($result.ExitCode -ne 0 -and $result.Output -match 'static polza conflicts') 'conflicting static provider did not fail closed'
            Assert-Equal '{"owner":"untouched"}' ([IO.File]::ReadAllText((Join-Path $profile 'settings.json'))) 'conflict preflight changed settings'
            Assert-True (-not (Test-Path -LiteralPath $tools.Log)) 'conflict preflight launched a package lifecycle'
        } finally { $env:PATH = $oldPath }
    }

    Test-Case 'installer uses sanitized official Pi lifecycle with npm and Git layouts' {
        $root = New-TestRoot
        $tools = New-FakeInstallToolchain $root
        $piRoot = Join-Path $root 'pi-root'
        $existingSettings = Join-Path $piRoot 'agent\settings.json'
        $existingModels = Join-Path $piRoot 'agent\models.json'
        New-Item -ItemType Directory -Path (Split-Path $existingSettings -Parent) -Force | Out-Null
        [IO.File]::WriteAllText($existingSettings, '{"keep":"byte-exact"}')
        [IO.File]::WriteAllText($existingModels, '{"providers":{"local-test":{"name":"keep-me"}}}')
        $oldPath = $env:PATH
        $oldSecret = $env:SECRET_SENTINEL
        try {
            $env:PATH = "$($tools.Bin);$oldPath"
            $env:SECRET_SENTINEL = 'must-not-reach-child-processes'
            $result = Invoke-PowerShellFile (Join-Path $RepoRoot 'scripts\install.ps1') @(
                '-Profile', 'Code', '-Apply', '-SkipPatches', '-PiRoot', $piRoot, '-RepoRoot', $RepoRoot
            )
        } finally {
            $env:PATH = $oldPath
            $env:SECRET_SENTINEL = $oldSecret
        }
        Assert-Equal 0 $result.ExitCode "fake lifecycle install failed: $($result.Output)"
        $installedSettings = Get-Content -LiteralPath $existingSettings -Raw | ConvertFrom-Json
        Assert-Equal 'byte-exact' ([string]$installedSettings.keep) 'custom settings field was not preserved'
        Assert-Equal 15 @($installedSettings.packages).Count 'build package list was not merged into preserved settings'
        Assert-Equal 'polza-memory/deepseek/deepseek-v4.1-flash' ([string]$installedSettings.memory.consolidationModel) 'memory model was not merged'
        $background = @($installedSettings.packages | Where-Object { $_ -isnot [string] -and $_.source -match 'pi-background-tasks' })
        Assert-Equal 1 $background.Count 'background-tasks filter missing after merge'
        Assert-Equal 0 @($background[0].extensions).Count 'background-tasks was not kept disabled'
        $trace = @($installedSettings.packages | Where-Object { $_ -isnot [string] -and $_.source -eq 'npm:pi-trace-extension@0.1.16' })
        Assert-Equal 1 $trace.Count 'Trace exact pinned package/filter missing after merge'
        Assert-True ($trace[0].PSObject.Properties.Name -contains 'extensions') 'Trace default-off filter missing'
        Assert-Equal 0 @($trace[0].extensions).Count 'Trace was enabled by installer merge'
        $installedModels = Get-Content -LiteralPath $existingModels -Raw | ConvertFrom-Json
        Assert-Equal 'keep-me' ([string]$installedModels.providers.'local-test'.name) 'existing model provider was not preserved'
        Assert-True ($null -ne $installedModels.providers.'polza-memory') 'polza-memory provider was not merged'
        $records = @([IO.File]::ReadAllLines($tools.Log) | ForEach-Object { $_ | ConvertFrom-Json })
        $piCalls = @($records | Where-Object { $_.tool -eq 'pi' })
        Assert-Equal 15 $piCalls.Count 'not every profile package was installed through pi install'
        foreach ($call in $piCalls) {
            Assert-Equal 'install' ([string]$call.args[0]) 'Pi lifecycle command was not install'
            Assert-Equal '' ([string]$call.secret) 'secret leaked into Pi install child'
            Assert-Equal (Join-Path $piRoot 'agent') ([string]$call.profile) 'PI_CODING_AGENT_DIR was not process-local to Code profile'
        }
        foreach ($record in @($records | Where-Object { $_.tool -in @('npm', 'uv') })) {
            Assert-Equal '' ([string]$record.secret) "secret leaked into $($record.tool) child"
        }
        $profileNpmInstalls = @($records | Where-Object {
            $_.tool -eq 'npm' -and $_.args[0] -eq 'install' -and $_.args -contains '--prefix'
        })
        Assert-Equal 0 $profileNpmInstalls.Count 'installer bypassed pi install with npm --prefix'
        Assert-True (Test-Path -LiteralPath (Join-Path $piRoot 'agent\npm\node_modules\pi-cbm\package.json')) 'npm Pi package layout missing'
        Assert-True (Test-Path -LiteralPath (Join-Path $piRoot 'agent\git\github.com\VladimirMonin\pi-polza\package.json')) 'Git Pi package layout missing'
        Assert-True (Test-Path -LiteralPath (Join-Path $root 'postinstall-_ast_grep_cli.txt')) '@ast-grep/cli postinstall lifecycle was disabled'
        Assert-True (Test-Path -LiteralPath (Join-Path $root 'postinstall-codebase_memory_mcp.txt')) 'codebase-memory-mcp postinstall lifecycle was disabled'
    }

    Test-Case 'installer rejects a Git checkout whose HEAD differs from the pinned commit' {
        $root = New-TestRoot
        $tools = New-FakeInstallToolchain $root
        [IO.File]::WriteAllText((Join-Path $root 'fake-git-head.txt'), '0000000000000000000000000000000000000000')
        $oldPath = $env:PATH
        try {
            $env:PATH = "$($tools.Bin);$oldPath"
            $result = Invoke-PowerShellFile (Join-Path $RepoRoot 'scripts\install.ps1') @(
                '-Profile', 'Task', '-Apply', '-SkipPatches', '-PiRoot', (Join-Path $root 'pi-root'), '-RepoRoot', $RepoRoot
            )
        } finally { $env:PATH = $oldPath }
        Assert-True ($result.ExitCode -ne 0) 'tampered Git checkout unexpectedly passed install postcondition'
        Assert-True ($result.Output -match 'HEAD does not match pinned\s+commit') 'Git checkout rejection was not reported'
    }

    Test-Case 'installer creates pre-install settings backup before a failing pi lifecycle' {
        $root = New-TestRoot
        $tools = New-FakeInstallToolchain $root
        [IO.File]::WriteAllText((Join-Path $root 'fail-pi-install-on.txt'), 'pi-trace-extension')
        $piRoot = Join-Path $root 'pi-root'
        $settings = Join-Path $piRoot 'agent\settings.json'
        New-Item -ItemType Directory -Path (Split-Path $settings -Parent) -Force | Out-Null
        $original = '{"ownerField":"must-survive"}'
        [IO.File]::WriteAllText($settings, $original)
        $oldPath = $env:PATH
        try {
            $env:PATH = "$($tools.Bin);$oldPath"
            $result = Invoke-PowerShellFile (Join-Path $RepoRoot 'scripts\install.ps1') @(
                '-Profile', 'Code', '-Apply', '-SkipPatches', '-PiRoot', $piRoot, '-RepoRoot', $RepoRoot
            )
        } finally { $env:PATH = $oldPath }
        Assert-True ($result.ExitCode -ne 0) 'simulated failing pi install unexpectedly passed'
        $backups = @(Get-ChildItem -LiteralPath (Join-Path $piRoot 'agent\.pi-agent-build-backups\install') -Recurse -Filter 'settings.pre-install.json' -File)
        Assert-True ($backups.Count -ge 1) 'settings backup was not created before package lifecycle'
        Assert-Equal $original ([IO.File]::ReadAllText($backups[-1].FullName)) 'pre-install backup does not contain original settings'
    }

    Test-Case 'launcher installer renders custom roots and preserves executable mode' {
        $root = New-TestRoot
        $target = Join-Path $root 'bin'
        $customPi = Join-Path $root 'custom-pi'
        $customNpm = Join-Path $root 'custom-npm'
        $script = Join-Path $RepoRoot 'scripts\install-launchers.ps1'
        $launcherArgs = @('-Profile', 'Task', '-TargetDir', $target, '-RepoRoot', $RepoRoot, '-PiRoot', $customPi, '-NpmPrefix', $customNpm)
        $plan = Invoke-PowerShellFile $script $launcherArgs
        Assert-Equal 0 $plan.ExitCode 'launcher plan failed'
        Assert-True (-not (Test-Path -LiteralPath $target)) 'launcher plan wrote files'
        $apply = Invoke-PowerShellFile $script ($launcherArgs + @('-Apply'))
        Assert-Equal 0 $apply.ExitCode 'launcher apply failed'
        $cmdLauncher = Join-Path $target 'pi-task.cmd'
        $posixLauncher = Join-Path $target 'pi-task'
        Assert-True (Test-Path -LiteralPath $cmdLauncher) 'Windows Task launcher missing'
        Assert-True (Test-Path -LiteralPath $posixLauncher) 'POSIX Task launcher missing'
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $target 'pi-code.cmd'))) 'Code launcher unexpectedly installed'
        $cmdText = [IO.File]::ReadAllText($cmdLauncher)
        $posixText = [IO.File]::ReadAllText($posixLauncher)
        Assert-True ($cmdText -match [regex]::Escape($customPi)) 'custom Pi root was not rendered into cmd launcher'
        Assert-True ($cmdText -match [regex]::Escape($customNpm)) 'custom npm prefix was not rendered into cmd launcher'
        Assert-True ($posixText -match [regex]::Escape($customPi.Replace('\', '/'))) 'custom Pi root was not rendered into POSIX launcher'
        Assert-True ($posixText -match 'PI_AGENT_BUILD_NPM_PREFIX') 'custom npm environment is not exported by POSIX launcher'
        foreach ($source in @('launchers/pi-code', 'launchers/pi-task')) {
            $modeLine = (& git -C $RepoRoot ls-files --stage -- $source | Out-String).Trim()
            Assert-True ($modeLine -match '^100755 ') "$source is not executable in Git"
        }

        [System.IO.File]::WriteAllText($cmdLauncher, 'local launcher')
        $second = Invoke-PowerShellFile $script ($launcherArgs + @('-Apply'))
        Assert-Equal 0 $second.ExitCode 'launcher replacement apply failed'
        $launcherBackups = @(Get-ChildItem -LiteralPath (Join-Path $target '.pi-agent-build-backups\launchers') -Recurse -Filter 'pi-task.cmd' -File)
        Assert-True ($launcherBackups.Count -ge 1) 'existing launcher was not backed up'
        Assert-True (([System.IO.File]::ReadAllText($launcherBackups[-1].FullName)) -match 'local launcher') 'launcher backup lost prior content'
    }

    Test-Case 'safety scanner separates tracked and tree scans and redacts values' {
        $root = New-TestRoot
        & git -C $root init --quiet
        & git -C $root config user.email 'test@example.invalid'
        & git -C $root config user.name 'Test'
        [System.IO.File]::WriteAllText((Join-Path $root 'clean.txt'), 'portable')
        & git -C $root add clean.txt
        $secret = ('gh' + 'p_' + ('A' * 36))
        [System.IO.File]::WriteAllText((Join-Path $root 'untracked.txt'), "token=$secret")
        $randomBytes = New-Object byte[] 72
        $random = [System.Security.Cryptography.RandomNumberGenerator]::Create()
        try { $random.GetBytes($randomBytes) } finally { $random.Dispose() }
        $randomValue = [Convert]::ToBase64String($randomBytes)
        [System.IO.File]::WriteAllText((Join-Path $root 'payload.json'), ('{"blob":"' + $randomValue + '"}'))
        New-Item -ItemType Directory -Path (Join-Path $root 'sessions') -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $root 'sessions\event.json'), '{}')
        $personalPath = 'C:' + '\Use' + 'rs\ExampleUser\private'
        [System.IO.File]::WriteAllText((Join-Path $root 'path.txt'), $personalPath)
        $scanner = Join-Path $RepoRoot 'scripts\safety-check.ps1'
        $tracked = Invoke-PowerShellFile $scanner @('-Root', $root, '-Scope', 'Tracked')
        Assert-Equal 0 $tracked.ExitCode 'tracked-only scan should ignore untracked fixture'
        $stagedSecret = ('github' + '_pat_' + ('B' * 30))
        [System.IO.File]::WriteAllText((Join-Path $root 'staged.txt'), $stagedSecret)
        & git -C $root add staged.txt
        [System.IO.File]::WriteAllText((Join-Path $root 'staged.txt'), 'clean working-tree replacement')
        $staged = Invoke-PowerShellFile $scanner @('-Root', $root, '-Scope', 'Tracked')
        Assert-True ($staged.ExitCode -ne 0) 'tracked scan missed a secret present only in the Git index'
        Assert-True ($staged.Output -match 'secret-prefix') 'staged secret class missing'
        Assert-True ($staged.Output -notmatch [regex]::Escape($stagedSecret)) 'scanner printed the staged secret value'
        & git -C $root rm --cached --force --quiet staged.txt
        Remove-Item -LiteralPath (Join-Path $root 'staged.txt') -Force
        $tree = Invoke-PowerShellFile $scanner @('-Root', $root, '-Scope', 'Tree')
        Assert-True ($tree.ExitCode -ne 0) 'tree scan did not detect secret fixture'
        Assert-True ($tree.Output -match 'secret-prefix') 'secret finding class missing'
        Assert-True ($tree.Output -match 'long-random-string') 'high-entropy finding class missing'
        Assert-True ($tree.Output -match 'runtime-data-path') 'runtime data finding class missing'
        Assert-True ($tree.Output -match 'personal-absolute-path') 'personal path finding class missing'
        Assert-True ($tree.Output -notmatch [regex]::Escape($secret)) 'scanner printed the secret value'
        Assert-True ($tree.Output -notmatch [regex]::Escape($randomValue)) 'scanner printed the high-entropy value'
    }

    Test-Case 'patch checks stay inside explicitly selected test roots' {
        $root = New-TestRoot
        $piRoot = Join-Path $root 'pi-home'
        New-Item -ItemType Directory -Path $piRoot -Force | Out-Null
        $result = Invoke-PowerShellFile (Join-Path $RepoRoot 'scripts\apply-patches.ps1') @(
            '-Profile', 'Task', '-Mode', 'Check', '-PiRoot', $piRoot, '-RepoRoot', $RepoRoot
        )
        Assert-True ($result.ExitCode -ne 0) 'empty test root unexpectedly passed patch checks'
        Assert-True ($result.Output -match [regex]::Escape($piRoot)) 'selected test root was not reported'
        Assert-True ($result.Output -notmatch [regex]::Escape((Join-Path $HOME '.pi'))) 'patch wrapper fell back to live ~/.pi'
    }

    Test-Case 'memory patch uses 0 patched, 1 needs apply, 2 fatal and profile settings' {
        $root = New-TestRoot
        $agent = Join-Path $root 'task-profile'
        $pkg = Join-Path $agent 'npm\node_modules\@samfp\pi-memory'
        $dist = Join-Path $pkg 'dist\index.js'
        New-Item -ItemType Directory -Path (Split-Path $dist -Parent) -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $pkg 'package.json'), '{"name":"@samfp/pi-memory","version":"1.5.0"}')
        Copy-Item -LiteralPath (Join-Path $RepoRoot 'patches\memory-windows-runtime\stock-index.js') -Destination $dist
        $patcher = Join-Path $RepoRoot 'patches\memory-windows-runtime\apply.py'
        [IO.File]::WriteAllText((Join-Path $pkg 'package.json'), '{"name":"@samfp/pi-memory","version":"1.5.1"}')
        $wrongVersion = Invoke-NativeCapture 'python' @($patcher, '--agent-dir', $agent, '--check')
        Assert-Equal 2 $wrongVersion.ExitCode 'memory patch must reject a newer package version despite identical dist bytes'
        [IO.File]::WriteAllText((Join-Path $pkg 'package.json'), '{"name":"@samfp/pi-memory","version":"1.5.0"}')

        $stock = Invoke-NativeCapture 'python' @($patcher, '--agent-dir', $agent, '--check')
        Assert-Equal 1 $stock.ExitCode 'stock memory check must mean needs apply'
        $apply = Invoke-NativeCapture 'python' @($patcher, '--agent-dir', $agent)
        Assert-Equal 0 $apply.ExitCode "memory apply failed: $($apply.Output)"
        $patched = Invoke-NativeCapture 'python' @($patcher, '--agent-dir', $agent, '--check')
        Assert-Equal 0 $patched.ExitCode 'patched memory check must pass'
        $canonical = [IO.File]::ReadAllText($dist)
        $canonicalHash = (Get-FileHash -LiteralPath $dist -Algorithm SHA256).Hash
        Assert-True ($canonical -match 'PI_CODING_AGENT_DIR') 'canonical memory patch ignores PI_CODING_AGENT_DIR for settings'
        Assert-True ($canonical -match 'memory\.db') 'canonical memory patch unexpectedly removed the shared DB default'
        $runtimeBackups = @(Get-ChildItem -LiteralPath (Join-Path $agent '.pi-agent-build-backups\memory-windows-runtime') -Filter 'index.js.before-apply-*' -File)
        Assert-True ($runtimeBackups.Count -ge 1) 'memory apply did not create a runtime backup'
        [IO.File]::WriteAllText($dist, $canonical + "`n// noncanonical drift`n")
        $drift = Invoke-NativeCapture 'python' @($patcher, '--agent-dir', $agent, '--check')
        Assert-Equal 2 $drift.ExitCode 'noncanonical marker-preserving drift must be fatal'
        $driftHash = (Get-FileHash -LiteralPath $dist -Algorithm SHA256).Hash
        $restoreDrift = Invoke-NativeCapture 'python' @($patcher, '--agent-dir', $agent, '--restore')
        Assert-Equal 2 $restoreDrift.ExitCode 'restore must refuse noncanonical drift'
        Assert-Equal $driftHash (Get-FileHash -LiteralPath $dist -Algorithm SHA256).Hash 'restore overwrote noncanonical drift'
        [IO.File]::WriteAllText($dist, $canonical)
        $settingsRegression = Invoke-NativeCapture 'node' @((Join-Path $RepoRoot 'patches\memory-windows-runtime\tests\test-memory-settings-path.mjs'), $dist)
        Assert-Equal 0 $settingsRegression.ExitCode "Task-only memory settings regression failed: $($settingsRegression.Output)"
        $injectionRegression = Invoke-NativeCapture 'node' @((Join-Path $RepoRoot 'patches\memory-windows-runtime\tests\test-memory-injection.mjs'), $dist)
        Assert-Equal 0 $injectionRegression.ExitCode "scoped memory injection regression failed: $($injectionRegression.Output)"

        $previousCode = 'import importlib.util,pathlib,sys; s=importlib.util.spec_from_file_location(''memory_patch'',sys.argv[1]); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); pathlib.Path(sys.argv[2]).write_bytes(m.build_canonical(m.BACKUP.read_bytes(),m.PREVIOUS_CANONICAL_REPLACEMENTS))'
        $makePrevious = Invoke-NativeCapture 'python' @('-c', $previousCode, $patcher, $dist)
        Assert-Equal 0 $makePrevious.ExitCode "could not create previous canonical fixture: $($makePrevious.Output)"
        $previous = Invoke-NativeCapture 'python' @($patcher, '--agent-dir', $agent, '--check')
        Assert-Equal 1 $previous.ExitCode 'previous canonical memory patch must require migration'
        $migratePrevious = Invoke-NativeCapture 'python' @($patcher, '--agent-dir', $agent)
        Assert-Equal 0 $migratePrevious.ExitCode 'previous canonical memory patch did not migrate'
        $preInjectorCode = 'import importlib.util,pathlib,sys; s=importlib.util.spec_from_file_location(''memory_patch'',sys.argv[1]); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); pathlib.Path(sys.argv[2]).write_bytes(m.build_canonical(m.BACKUP.read_bytes(),injector=False,timers=False))'
        $makePreInjector = Invoke-NativeCapture 'python' @('-c', $preInjectorCode, $patcher, $dist)
        Assert-Equal 0 $makePreInjector.ExitCode 'could not create pre-injector canonical fixture'
        $preInjector = Invoke-NativeCapture 'python' @($patcher, '--agent-dir', $agent, '--check')
        Assert-Equal 1 $preInjector.ExitCode 'pre-injector canonical memory patch must require migration'
        $migratePreInjector = Invoke-NativeCapture 'python' @($patcher, '--agent-dir', $agent)
        Assert-Equal 0 $migratePreInjector.ExitCode 'pre-injector canonical memory patch did not migrate'
        Assert-Equal $canonicalHash (Get-FileHash -LiteralPath $dist -Algorithm SHA256).Hash 'migration did not reproduce canonical memory bytes'

        Copy-Item -LiteralPath (Join-Path $RepoRoot 'patches\memory-windows-runtime\stock-index.js') -Destination $dist -Force
        $winMarker = @($canonical -split "`r?`n" | Where-Object { $_ -match '^\s*// win32:' })[0].Trim()
        [IO.File]::AppendAllText($dist, "`n$winMarker`nglobalThis.__piMemoryTurns = [];`n}`nfunction pushTurn(role, text) {`n}`n", [Text.Encoding]::UTF8)
        $markerShaped = Invoke-NativeCapture 'python' @($patcher, '--agent-dir', $agent, '--check')
        Assert-Equal 2 $markerShaped.ExitCode 'marker-shaped unknown memory state must be fatal'
        $markerHash = (Get-FileHash -LiteralPath $dist -Algorithm SHA256).Hash
        $markerApply = Invoke-NativeCapture 'python' @($patcher, '--agent-dir', $agent)
        Assert-Equal 2 $markerApply.ExitCode 'apply must refuse marker-shaped unknown state'
        Assert-Equal $markerHash (Get-FileHash -LiteralPath $dist -Algorithm SHA256).Hash 'apply overwrote marker-shaped unknown state'

        [IO.File]::WriteAllText($dist, 'unknown distribution')
        $unknown = Invoke-NativeCapture 'python' @($patcher, '--agent-dir', $agent, '--check')
        Assert-Equal 2 $unknown.ExitCode 'unknown memory state must be fatal'
    }

    Test-Case 'schema validation fails closed for invalid data and unavailable validator' {
        $invalidRepo = Copy-RepositoryFixture
        $runtimePath = Join-Path $invalidRepo 'manifests\runtime.lock.json'
        $runtime = Get-Content -LiteralPath $runtimePath -Raw | ConvertFrom-Json
        $runtime.platform.architecture = 'sparc'
        [IO.File]::WriteAllText($runtimePath, ($runtime | ConvertTo-Json -Depth 20), (New-Object Text.UTF8Encoding($false)))
        $invalid = Invoke-PowerShellFile (Join-Path $invalidRepo 'scripts\verify.ps1') @('-RepositoryOnly', '-RepoRoot', $invalidRepo)
        Assert-True ($invalid.ExitCode -ne 0) 'schema-invalid manifest passed verification'
        Assert-True ($invalid.Output -match 'sparc') 'schema validator did not report the invalid value'

        $noValidatorRepo = Copy-RepositoryFixture
        $fakeBin = Join-Path (New-TestRoot) 'bin'
        New-Item -ItemType Directory -Path $fakeBin -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $fakeBin 'python.cmd'), "@echo ModuleNotFoundError: No module named 'jsonschema'`r`n@exit /b 1`r`n")
        $oldPath = $env:PATH
        try {
            $env:PATH = "$fakeBin;$oldPath"
            $missing = Invoke-PowerShellFile (Join-Path $noValidatorRepo 'scripts\verify.ps1') @('-RepositoryOnly', '-RepoRoot', $noValidatorRepo)
        } finally { $env:PATH = $oldPath }
        Assert-True ($missing.ExitCode -ne 0) 'verification passed without the JSON Schema validator'
        Assert-True ($missing.Output -match 'jsonschema') 'missing validator was not identified'
    }

    Test-Case 'Serena CBM and session patchers keep tracked stores immutable and refuse drift' {
        $storeFiles = @(
            (Join-Path $RepoRoot 'patches\serena-tools\store\index.ts.orig-0.9.20'),
            (Join-Path $RepoRoot 'patches\pi-cbm-011\store\client.ts.orig-1.2.1'),
            (Join-Path $RepoRoot 'patches\session-search-profile\store\1.4.3\src\config.ts'),
            (Join-Path $RepoRoot 'patches\session-search-profile\store\1.4.3\src\parser.ts'),
            (Join-Path $RepoRoot 'patches\session-search-profile\store\1.4.3\dist\index.js'),
            (Join-Path $RepoRoot 'patches\serena-tools\store\guidance.ts.orig-0.9.20')
        )
        $before = Get-FileHashes $storeFiles
        $python = (Get-Command python).Source
        $root = New-TestRoot

        $serenaAgent = Join-Path $root 'serena-profile'
        $serenaPkg = Join-Path $serenaAgent 'npm\node_modules\@bacnh85\pi-serena'
        New-Item -ItemType Directory -Path (Join-Path $serenaPkg 'extensions\lib') -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $serenaPkg 'package.json'), '{"version":"0.9.20"}')
        Copy-Item -LiteralPath $storeFiles[0] -Destination (Join-Path $serenaPkg 'extensions\index.ts')
        Copy-Item -LiteralPath $storeFiles[5] -Destination (Join-Path $serenaPkg 'extensions\lib\guidance.ts')
        $serenaPatcher = Join-Path $RepoRoot 'patches\serena-tools\apply.py'
        $serena = Invoke-NativeCapture $python @($serenaPatcher, '--agent-dir', $serenaAgent, '--apply')
        Assert-Equal 0 $serena.ExitCode "Serena apply failed: $($serena.Output)"
        Assert-True (Test-Path -LiteralPath (Join-Path $serenaAgent '.pi-agent-build-backups\serena-tools')) 'Serena runtime backup missing'
        $serenaGuidance = Join-Path $serenaPkg 'extensions\lib\guidance.ts'
        Assert-True (-not ([IO.File]::ReadAllText($serenaGuidance).Contains('serena_find_implementations'))) 'Serena guidance still advertises a hidden tool'
        $serenaHashes = Get-FileHashes @((Join-Path $serenaPkg 'extensions\index.ts'), $serenaGuidance)
        $serenaAgain = Invoke-NativeCapture $python @($serenaPatcher, '--agent-dir', $serenaAgent, '--apply')
        Assert-Equal 0 $serenaAgain.ExitCode 'Serena second apply failed'
        Assert-HashesEqual $serenaHashes (Get-FileHashes @((Join-Path $serenaPkg 'extensions\index.ts'), $serenaGuidance)) 'Serena idempotent apply changed bytes'
        [IO.File]::AppendAllText($serenaGuidance, '// drift')
        $guidanceDrift = Invoke-NativeCapture $python @($serenaPatcher, '--agent-dir', $serenaAgent, '--apply')
        Assert-Equal 2 $guidanceDrift.ExitCode 'Serena guidance drift must fail closed'
        Copy-Item -LiteralPath $storeFiles[5] -Destination $serenaGuidance -Force
        $mixedSerena = Invoke-NativeCapture $python @($serenaPatcher, '--agent-dir', $serenaAgent, '--check')
        Assert-Equal 2 $mixedSerena.ExitCode 'Serena mixed tools/guidance state must fail closed'
        Copy-Item -LiteralPath $storeFiles[0] -Destination (Join-Path $serenaPkg 'extensions\index.ts') -Force
        $serenaApply = Invoke-NativeCapture $python @($serenaPatcher, '--agent-dir', $serenaAgent, '--apply')
        Assert-Equal 0 $serenaApply.ExitCode 'Serena reapply failed'
        $serenaRestore = Invoke-NativeCapture $python @($serenaPatcher, '--agent-dir', $serenaAgent, '--restore')
        Assert-Equal 0 $serenaRestore.ExitCode 'Serena restore failed'
        Assert-Equal (Get-FileHash $storeFiles[0]).Hash (Get-FileHash (Join-Path $serenaPkg 'extensions\index.ts')).Hash 'Serena index restore differs'
        Assert-Equal (Get-FileHash $storeFiles[5]).Hash (Get-FileHash $serenaGuidance).Hash 'Serena guidance restore differs'
        [IO.File]::WriteAllText((Join-Path $serenaPkg 'extensions\index.ts'), 'unknown Serena source')
        $serenaDrift = Invoke-NativeCapture $python @($serenaPatcher, '--agent-dir', $serenaAgent, '--apply')
        Assert-Equal 2 $serenaDrift.ExitCode 'Serena apply did not refuse unknown source'

        $cbmAgent = Join-Path $root 'cbm-profile'
        $cbmPkg = Join-Path $cbmAgent 'npm\node_modules\pi-cbm'
        New-Item -ItemType Directory -Path (Join-Path $cbmPkg 'src\cbm') -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $cbmPkg 'package.json'), '{"version":"1.2.1"}')
        Copy-Item -LiteralPath $storeFiles[1] -Destination (Join-Path $cbmPkg 'src\cbm\client.ts')
        $cbmExe = Join-Path $root 'tools\codebase-memory-mcp.exe'
        New-VersionExecutable -Path $cbmExe -Version '0.11.0' -CbmHelp
        $cbmPatcher = Join-Path $RepoRoot 'patches\pi-cbm-011\apply.py'
        $cbm = Invoke-NativeCapture $python @($cbmPatcher, '--agent-dir', $cbmAgent, '--apply') @{ CODEBASE_MEMORY_MCP_BIN = $cbmExe }
        Assert-Equal 0 $cbm.ExitCode "CBM apply failed: $($cbm.Output)"
        Assert-True (Test-Path -LiteralPath (Join-Path $cbmAgent '.pi-agent-build-backups\pi-cbm-011')) 'CBM runtime backup missing'
        $cbmTarget = Join-Path $cbmPkg 'src\cbm\client.ts'
        $normalized = [IO.File]::ReadAllText($cbmTarget).Replace("`r`n", "`n")
        [IO.File]::WriteAllText($cbmTarget, $normalized, (New-Object Text.UTF8Encoding($false)))
        $groupedCode = 'const fs=require("node:fs"),vm=require("node:vm"),assert=require("node:assert/strict"),{stripTypeScriptTypes}=require("node:module"); const src=fs.readFileSync(process.argv[2],"utf8"); const body=src.slice(src.indexOf("// [local-compat-patch] CBM"),src.indexOf("// [/local-compat-patch]")); const input={cols:["name","label","lines","in","out"],groups:[{qn_prefix:"compat-tiny.synthetic",file:"synthetic.py",rows:[["synthetic_add","Function","1-2",0,0]]}],total:1}; const result=vm.runInNewContext(stripTypeScriptTypes(body)+"normalizeCbm011Result(\"search_graph\", input)",{input}); assert.equal(result.results.length,1); assert.equal(result.results[0].qualified_name,"compat-tiny.synthetic.synthetic_add"); assert.equal(result.results[0].file_path,"synthetic.py"); assert.equal(result.results[0].start_line,1); assert.equal(result.results[0].end_line,2);'
        $groupedTest = Join-Path $root 'cbm-grouped.cjs'
        [IO.File]::WriteAllText($groupedTest, $groupedCode, (New-Object Text.UTF8Encoding($false)))
        $grouped = Invoke-NativeCapture 'node' @($groupedTest, $cbmTarget)
        Assert-Equal 0 $grouped.ExitCode "CBM grouped search lost symbol/location: $($grouped.Output)"
        $normalizedHash = (Get-FileHash -LiteralPath $cbmTarget -Algorithm SHA256).Hash
        $normalizedCheck = Invoke-NativeCapture $python @($cbmPatcher, '--agent-dir', $cbmAgent, '--check') @{ CODEBASE_MEMORY_MCP_BIN = $cbmExe }
        Assert-Equal 0 $normalizedCheck.ExitCode 'exact LF-normalized CBM canonical was not accepted'
        $normalizedApply = Invoke-NativeCapture $python @($cbmPatcher, '--agent-dir', $cbmAgent, '--apply') @{ CODEBASE_MEMORY_MCP_BIN = $cbmExe }
        Assert-Equal 0 $normalizedApply.ExitCode 'LF-normalized CBM apply should be idempotent'
        Assert-Equal $normalizedHash (Get-FileHash -LiteralPath $cbmTarget -Algorithm SHA256).Hash 'idempotent CBM apply rewrote normalized bytes'
        $previousCbm = 'import importlib.util,pathlib,sys; s=importlib.util.spec_from_file_location(''cbm_patch'',sys.argv[1]); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); p=pathlib.Path(sys.argv[2]); p.write_bytes(m.previous_patched(p.read_text()).encode())'
        $makePreviousCbm = Invoke-NativeCapture $python @('-c', $previousCbm, $cbmPatcher, $cbmTarget)
        Assert-Equal 0 $makePreviousCbm.ExitCode 'could not create exact previous CBM canonical'
        $previousCheck = Invoke-NativeCapture $python @($cbmPatcher, '--agent-dir', $cbmAgent, '--check') @{ CODEBASE_MEMORY_MCP_BIN = $cbmExe }
        Assert-Equal 1 $previousCheck.ExitCode 'previous CBM canonical must require migration'
        $previousApply = Invoke-NativeCapture $python @($cbmPatcher, '--agent-dir', $cbmAgent, '--apply') @{ CODEBASE_MEMORY_MCP_BIN = $cbmExe }
        Assert-Equal 0 $previousApply.ExitCode 'previous CBM canonical migration failed'
        $groupedMigrated = Invoke-NativeCapture 'node' @($groupedTest, $cbmTarget)
        Assert-Equal 0 $groupedMigrated.ExitCode 'migrated CBM lost grouped search symbols'
        $normalizedRestore = Invoke-NativeCapture $python @($cbmPatcher, '--agent-dir', $cbmAgent, '--restore') @{ CODEBASE_MEMORY_MCP_BIN = $cbmExe }
        Assert-Equal 0 $normalizedRestore.ExitCode 'LF-normalized CBM restore should accept exact known state'
        Assert-Equal (Get-FileHash -LiteralPath $storeFiles[1] -Algorithm SHA256).Hash (Get-FileHash -LiteralPath $cbmTarget -Algorithm SHA256).Hash 'CBM restore did not recover immutable stock'
        [IO.File]::WriteAllText($cbmTarget, 'unknown CBM source')
        $cbmDrift = Invoke-NativeCapture $python @($cbmPatcher, '--agent-dir', $cbmAgent, '--apply') @{ CODEBASE_MEMORY_MCP_BIN = $cbmExe }
        Assert-Equal 2 $cbmDrift.ExitCode 'CBM apply did not refuse unknown source'

        $sessionAgent = Join-Path $root 'session-profile'
        $sessionPkg = Join-Path $sessionAgent 'npm\node_modules\pi-session-search'
        [IO.File]::WriteAllText((New-Item -ItemType File -Path (Join-Path $sessionPkg 'package.json') -Force).FullName, '{"version":"1.4.3"}')
        foreach ($rel in @('src\config.ts', 'src\parser.ts', 'dist\index.js')) {
            $src = Join-Path (Join-Path $RepoRoot 'patches\session-search-profile\store\1.4.3') $rel
            $dst = Join-Path $sessionPkg $rel
            New-Item -ItemType Directory -Path (Split-Path $dst -Parent) -Force | Out-Null
            Copy-Item -LiteralPath $src -Destination $dst
        }
        $sessionPatcher = Join-Path $RepoRoot 'patches\session-search-profile\apply.py'
        $session = Invoke-NativeCapture $python @($sessionPatcher, '--agent-dir', $sessionAgent, '--apply')
        Assert-Equal 0 $session.ExitCode "session-search apply failed: $($session.Output)"
        Assert-True (Test-Path -LiteralPath (Join-Path $sessionAgent '.pi-agent-build-backups\session-search-profile')) 'session runtime backup missing'
        [IO.File]::WriteAllText((Join-Path $sessionPkg 'src\config.ts'), 'unknown session source')
        $sessionDrift = Invoke-NativeCapture $python @($sessionPatcher, '--agent-dir', $sessionAgent, '--apply')
        Assert-Equal 2 $sessionDrift.ExitCode 'session apply did not refuse unknown source'

        $after = Get-FileHashes $storeFiles
        Assert-HashesEqual $before $after 'tracked pristine store changed during patch apply'
    }

    Test-Case 'verifier applies external probe semantics without executing fetch' {
        $root = New-TestRoot
        $tools = New-FakeInstallToolchain $root
        New-VersionExecutable -Path (Join-Path $tools.Bin 'ast-grep.exe') -Version '0.45.3'
        New-VersionExecutable -Path (Join-Path $tools.Bin 'serena.exe') -Version '1.7.0'
        $cbmExe = Join-Path $tools.Prefix 'node_modules\codebase-memory-mcp\bin\codebase-memory-mcp.exe'
        New-VersionExecutable -Path $cbmExe -Version '0.11.0'
        [IO.File]::WriteAllText((Join-Path $tools.Bin 'context7-mcp.cmd'), "@echo 3.2.2`r`n")
        $braveMeta = Join-Path $tools.Prefix 'node_modules\@brave\brave-search-mcp-server\package.json'
        New-Item -ItemType Directory -Path (Split-Path $braveMeta -Parent) -Force | Out-Null
        [IO.File]::WriteAllText($braveMeta, '{"version":"2.0.85"}')
        $braveMarker = Join-Path $root 'brave-was-executed.txt'
        [IO.File]::WriteAllText((Join-Path $tools.Bin 'brave-search-mcp-server.cmd'), "@echo called>`"$braveMarker`"`r`n@exit /b 9`r`n")
        $fetchMarker = Join-Path $root 'fetch-was-executed.txt'
        [IO.File]::WriteAllText((Join-Path $tools.Bin 'mcp-server-fetch.cmd'), "@echo called>`"$fetchMarker`"`r`n@exit /b 9`r`n")
        $oldPath = $env:PATH
        try {
            $env:PATH = "$($tools.Bin);$oldPath"
            $ok = Invoke-PowerShellFile (Join-Path $RepoRoot 'scripts\verify.ps1') @('-Profile', 'Code', '-ExternalOnly', '-RepoRoot', $RepoRoot)
        } finally { $env:PATH = $oldPath }
        Assert-Equal 0 $ok.ExitCode "external probes failed: $($ok.Output)"
        Assert-True (-not (Test-Path -LiteralPath $fetchMarker)) 'fetch was executed even though it has no version probe'
        Assert-True (-not (Test-Path -LiteralPath $braveMarker)) 'Brave server was executed instead of reading npm metadata'
        Assert-True ($ok.Output -match 'brave-search-mcp-server.*2\.0\.85') 'Brave package version was not checked'
        Assert-True ($ok.Output -match 'codebase-memory-mcp.*0\.11\.0') 'CBM real executable under npm root was not checked'

        $missingRepo = Copy-RepositoryFixture
        $externalPath = Join-Path $missingRepo 'manifests\external-tools.lock.json'
        $externalManifest = Get-Content -LiteralPath $externalPath -Raw | ConvertFrom-Json
        @($externalManifest.mcp | Where-Object { $_.package -eq '@brave/brave-search-mcp-server' })[0].command = 'definitely-missing-brave-probe'
        [IO.File]::WriteAllText($externalPath, ($externalManifest | ConvertTo-Json -Depth 20), (New-Object Text.UTF8Encoding($false)))
        try {
            $env:PATH = "$($tools.Bin);$oldPath"
            $missingOptional = Invoke-PowerShellFile (Join-Path $missingRepo 'scripts\verify.ps1') @('-Profile', 'Code', '-ExternalOnly', '-RepoRoot', $missingRepo)
        } finally { $env:PATH = $oldPath }
        Assert-Equal 0 $missingOptional.ExitCode "missing optional probe became fatal: $($missingOptional.Output)"
        Assert-True ($missingOptional.Output -match 'brave-search.*optional') 'missing optional MCP command was not a warning'

        [IO.File]::WriteAllText((Join-Path $tools.Bin 'context7-mcp.cmd'), "@echo 0.0.0`r`n")
        try {
            $env:PATH = "$($tools.Bin);$oldPath"
            $bad = Invoke-PowerShellFile (Join-Path $RepoRoot 'scripts\verify.ps1') @('-Profile', 'Code', '-ExternalOnly', '-RepoRoot', $RepoRoot)
        } finally { $env:PATH = $oldPath }
        Assert-True ($bad.ExitCode -ne 0) 'installed optional MCP with wrong version was not rejected'

        [IO.File]::WriteAllText((Join-Path $tools.Bin 'context7-mcp.cmd'), "@echo 3.2.2`r`n")
        [IO.File]::WriteAllText($braveMeta, '{"version":"0.0.0"}')
        try {
            $env:PATH = "$($tools.Bin);$oldPath"
            $badBrave = Invoke-PowerShellFile (Join-Path $RepoRoot 'scripts\verify.ps1') @('-Profile', 'Task', '-ExternalOnly', '-RepoRoot', $RepoRoot)
        } finally { $env:PATH = $oldPath }
        Assert-True ($badBrave.ExitCode -ne 0) 'wrong Brave npm metadata version was not rejected'
        Assert-True ($badBrave.Output -match 'brave-search-mcp-server expected 2\.0\.85') 'Brave version failure was not reported'
        Assert-True (-not (Test-Path -LiteralPath $braveMarker)) 'Brave server was started by a failing probe'
    }

    Test-Case 'Trace remains installed but canonical Code and Task filters reject opt-in drift' {
        function Read-JsonFile { param([string]$Path) return ([IO.File]::ReadAllText($Path) | ConvertFrom-Json) }
        $root = New-TestRoot
        $tokens = $null; $errors = $null
        $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $RepoRoot 'scripts\verify.ps1'), [ref]$tokens, [ref]$errors)
        $definition = $ast.Find({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Compare-ProfileTemplate' }, $true).Extent.Text
        $manifest = Read-JsonFile (Join-Path $RepoRoot 'manifests\pi-packages.lock.json')
        $version = [string](Read-JsonFile (Join-Path $RepoRoot 'manifests\runtime.lock.json')).runtime.pi.version
        foreach ($profile in @('Code','Task')) {
            foreach ($state in @('canonical','enabled','empty-item','missing-filter','string')) {
                $settings = Read-JsonFile (Join-Path $RepoRoot "profiles\$($profile.ToLowerInvariant())\settings.template.json")
                $index = 0; while ($index -lt $settings.packages.Count -and ($settings.packages[$index] -is [string] -or [string]$settings.packages[$index].source -ne 'npm:pi-trace-extension@0.1.16')) { $index++ }
                Assert-True ($index -lt $settings.packages.Count) 'Installed Trace package missing'
                if ($state -eq 'enabled') { $settings.packages[$index].extensions = @('extensions/trace') }
                if ($state -eq 'empty-item') { $settings.packages[$index].extensions = @('') }
                if ($state -eq 'missing-filter') { $settings.packages[$index].PSObject.Properties.Remove('extensions') }
                if ($state -eq 'string') { $settings.packages[$index] = [string]$settings.packages[$index].source }
                $file = Join-Path $root "$profile-$state.json"
                [IO.File]::WriteAllText($file, ($settings | ConvertTo-Json -Depth 100))
                $rejected = $false
                try {
                    & {
                        function Pass { param($Message) }
                        function Fail { param($Message) throw $Message }
                        function Get-EntrySource { param($Item) if ($Item -is [string]) { return $Item }; return [string]$Item.source }
                        . ([scriptblock]::Create($definition))
                        Compare-ProfileTemplate $profile $file $manifest $version
                    }
                } catch { $rejected = $true }
                Assert-Equal ($state -ne 'canonical') $rejected "$profile/$state Trace filter decision wrong"
            }
        }
    }

    Test-Case 'repository-only verification performs no profile writes' {
        $root = New-TestRoot
        $piRoot = Join-Path $root 'must-not-exist'
        $result = Invoke-PowerShellFile (Join-Path $RepoRoot 'scripts\verify.ps1') @(
            '-RepositoryOnly', '-PiRoot', $piRoot, '-RepoRoot', $RepoRoot
        )
        Assert-Equal 0 $result.ExitCode "repository verification failed: $($result.Output)"
        Assert-True (-not (Test-Path -LiteralPath $piRoot)) 'repository verification created a Pi root'
        Assert-True ($result.Output -match 'PASS') 'verification emitted no PASS results'
    }

    Test-Case 'verification continues after a failing child patch process' {
        $root = New-TestRoot
        $piRoot = Join-Path $root 'empty-pi-home'
        New-Item -ItemType Directory -Path $piRoot -Force | Out-Null
        $result = Invoke-PowerShellFile (Join-Path $RepoRoot 'scripts\verify.ps1') @(
            '-Profile', 'Task', '-SkipExternalChecks', '-PiRoot', $piRoot, '-RepoRoot', $RepoRoot
        )
        Assert-True ($result.ExitCode -ne 0) 'empty profile unexpectedly verified'
        Assert-True ($result.Output -match 'VERIFY result:') 'child patch script terminated the parent verifier'
    }
} finally {
    foreach ($path in $script:TempRoots) {
        Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "RESULT passed=$script:Passed failed=$script:Failed"
if ($script:Failed -gt 0) { exit 1 }
exit 0
