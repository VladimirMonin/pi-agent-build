[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Fixed guest mapping names are an interface, not host-machine paths.
# This is an alternate VM-boundary fixture: no restricted-token/MIC/Job claims.
$inputRoot = 'C:\PiLabInput'
$outputRoot = 'C:\PiLabOutput'
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
if (($identity.Name -split '\\')[-1] -cne 'WDAGUtilityAccount') {
    throw 'Windows Sandbox guest identity required; refusing host execution'
}
$computer = Get-CimInstance Win32_ComputerSystem -OperationTimeoutSec 5
if ($computer.Model -ne 'Virtual Machine') { throw 'Expected fresh Microsoft VM guest' }
if (-not (Test-Path -LiteralPath $inputRoot -PathType Container) -or -not (Test-Path -LiteralPath $outputRoot -PathType Container)) {
    throw 'Explicit Sandbox input/output mappings required'
}
$configFile = Join-Path $inputRoot 'config.json'
if ((Get-Item -LiteralPath $configFile).Length -gt 16384) { throw 'Oversized VM packet' }
$config = Get-Content -LiteralPath $configFile -Raw -Encoding UTF8 | ConvertFrom-Json
$keys = @($config.PSObject.Properties.Name)
if ((($keys | Sort-Object) -join ',') -cne 'kind,nodeSha256,nodeVersion,runId,schemaVersion,sourceHashes,timeoutMs') { throw 'Unknown VM packet structure' }
if ($config.schemaVersion -isnot [int] -or $config.schemaVersion -ne 1 -or $config.kind -cne 'VM_DUMMY_ONLY' -or $config.runId -isnot [string] -or $config.runId -cnotmatch '^[a-f0-9]{32}$' -or $config.nodeSha256 -isnot [string] -or $config.nodeSha256 -cnotmatch '^[a-f0-9]{64}$') { throw 'Invalid VM packet identity' }
if ($config.timeoutMs -isnot [int] -or $config.timeoutMs -ne 45000 -or $config.nodeVersion -isnot [string] -or $config.nodeVersion -notmatch '^\d+\.\d+\.\d+$') { throw 'Unknown VM packet bounds/version' }
if (((@($config.sourceHashes.PSObject.Properties.Name) | Sort-Object) -join ',') -cne 'dummy.mjs,guest-dummy.ps1') { throw 'Unknown guest source inventory' }
foreach ($name in @('guest-dummy.ps1','dummy.mjs')) {
    if ($config.sourceHashes.$name -isnot [string] -or $config.sourceHashes.$name -cnotmatch '^[a-f0-9]{64}$') { throw 'Unknown guest source identity' }
    if ((Get-FileHash -LiteralPath (Join-Path $inputRoot $name) -Algorithm SHA256).Hash.ToLowerInvariant() -cne $config.sourceHashes.$name) { throw "Guest source drift: $name" }
}
if ((Get-FileHash -LiteralPath (Join-Path $inputRoot 'node.exe') -Algorithm SHA256).Hash.ToLowerInvariant() -cne $config.nodeSha256) { throw 'Node input identity mismatch' }
$startedFile = Join-Path $outputRoot 'invocation-started.json'
if (Test-Path -LiteralPath $startedFile) { throw 'VM attempt already consumed; no retry' }
[IO.File]::WriteAllText($startedFile, (@{runId=$config.runId; utc=[DateTime]::UtcNow.ToString('o'); guest=$env:COMPUTERNAME} | ConvertTo-Json))

$root = 'C:\PiLabVM-' + $config.runId
if (Test-Path -LiteralPath $root) { throw 'Fresh guest root required' }
New-Item -ItemType Directory -Path $root | Out-Null
$acl = [Security.AccessControl.DirectorySecurity]::new()
$acl.SetOwner($identity.User)
$acl.SetAccessRuleProtection($true,$false)
$acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($identity.User,'FullControl','ContainerInherit,ObjectInherit','None','Allow'))
Set-Acl -LiteralPath $root -AclObject $acl
foreach ($name in @('runtime','tools','home','appdata','localappdata','temp','cache','xdg-config','xdg-data','xdg-state')) {
    New-Item -ItemType Directory -Path (Join-Path $root $name) | Out-Null
}
$runtime = Join-Path $root 'runtime'
$node = Join-Path $root 'tools\node.exe'
Copy-Item -LiteralPath (Join-Path $inputRoot 'node.exe') -Destination $node
if ((Get-FileHash -LiteralPath $node -Algorithm SHA256).Hash.ToLowerInvariant() -cne $config.nodeSha256) { throw 'Copied Node identity mismatch' }
$modulePath = Join-Path $inputRoot 'dummy.mjs'
$canary = Join-Path $inputRoot 'canary'
$canaryFile = Join-Path $canary 'working-memory-shaped.txt'
$canaryBefore = (Get-FileHash -LiteralPath $canaryFile -Algorithm SHA256).Hash
$envMap = @{
    SYSTEMROOT='C:\Windows'; WINDIR='C:\Windows'; COMSPEC='C:\Windows\System32\cmd.exe'; PATHEXT='.COM;.EXE;.BAT;.CMD'
    PATH=((Split-Path $node -Parent)+';C:\Windows\System32;C:\Windows')
    HOME=(Join-Path $root 'home'); USERPROFILE=(Join-Path $root 'home'); APPDATA=(Join-Path $root 'appdata'); LOCALAPPDATA=(Join-Path $root 'localappdata')
    TEMP=(Join-Path $root 'temp'); TMP=(Join-Path $root 'temp'); XDG_CACHE_HOME=(Join-Path $root 'cache')
    XDG_CONFIG_HOME=(Join-Path $root 'xdg-config'); XDG_DATA_HOME=(Join-Path $root 'xdg-data'); XDG_STATE_HOME=(Join-Path $root 'xdg-state')
    VM_DUMMY_RUNTIME=$runtime; VM_DUMMY_CANARY=$canary
}
$report = [ordered]@{
    schemaVersion=1; kind='VM_DUMMY_ONLY_NOT_SDK'; status='FAIL'; runId=$config.runId
    guest=@{computerName=$env:COMPUTERNAME; model=$computer.Model; identity=$identity.Name; callerPid=$PID}
    rootPid=0; inspected=@{}; rootExit=$null; forcedCleanup=$false; cleanupErrors=@(); error=$null
    coverage='Guest process observations and read-only mapped-input canaries; not token/MIC/Job or full guest/global proof. Host VM lifecycle requires separate evidence.'
}
$process = $null; $stdout = $null; $stderr = $null
try {
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $node
    $info.Arguments = '"' + $modulePath + '" root'
    $info.WorkingDirectory = $runtime
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardInput = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.EnvironmentVariables.Clear()
    foreach ($key in $envMap.Keys) { $info.EnvironmentVariables[$key] = $envMap[$key] }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $info
    if (-not $process.Start()) { throw 'Guest Node start failed' }
    $report.rootPid = $process.Id
    $process.StandardInput.Close()
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    $clock = [Diagnostics.Stopwatch]::StartNew()
    while (-not $process.HasExited) {
        if ($clock.ElapsedMilliseconds -ge $config.timeoutMs) { throw 'Guest root deadline exceeded' }
        foreach ($role in @('root','descendant')) {
            if ($report.inspected.ContainsKey($role)) { continue }
            $startup = Join-Path $runtime ('startup-'+$role+'.json')
            if (-not (Test-Path -LiteralPath $startup -PathType Leaf)) { continue }
            if ((Get-Item -LiteralPath $startup).Length -gt 16384) { throw 'Oversized process fixture receipt' }
            $s = Get-Content -LiteralPath $startup -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($s.pid -le 0 -or $s.role -cne $role -or $s.execPath -ine $node -or $s.modulePath -ine $modulePath -or $s.cwd -ine $runtime -or $s.version -cne ('v'+$config.nodeVersion)) { throw 'Guest process identity mismatch' }
            $parent = if ($role -eq 'root') { $PID } else { $process.Id }
            if ($s.ppid -ne $parent -or ($role -eq 'root' -and $s.pid -ne $process.Id)) { throw 'Guest process lineage mismatch' }
            $actual = Get-CimInstance Win32_Process -Filter ('ProcessId='+$s.pid) -OperationTimeoutSec 5
            if ($null -eq $actual -or $actual.ParentProcessId -ne $parent -or $actual.ExecutablePath -ine $node) { throw 'Actual guest PID/executable verification failed' }
            if (@($s.environment.PSObject.Properties).Count -ne $envMap.Count) { throw 'Unexpected inherited guest environment' }
            foreach ($key in $envMap.Keys) { if ($s.environment.$key -cne $envMap[$key]) { throw "Guest environment route mismatch: $key" } }
            $report.inspected[$role] = @{pid=$s.pid; ppid=$parent; executablePath=$actual.ExecutablePath; creationDate=$actual.CreationDate}
            [IO.File]::WriteAllText((Join-Path $runtime ('verified-'+$s.pid)), 'VM_PROCESS_INSPECTED')
        }
        Start-Sleep -Milliseconds 25
    }
    $process.WaitForExit()
    $report.rootExit = $process.ExitCode
    if ($report.rootExit -ne 0 -or $report.inspected.Count -ne 2) { throw 'Root/descendant natural-zero gate failed' }
    $rootReceipt = Get-Content -LiteralPath (Join-Path $runtime 'root-receipt.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $childReceipt = Get-Content -LiteralPath (Join-Path $runtime 'descendant-receipt.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $rootReceipt.naturalExit -or -not $childReceipt.naturalExit -or $rootReceipt.childExit.code -ne 0 -or $null -ne $rootReceipt.childExit.signal -or $rootReceipt.childPid -ne $report.inspected.descendant.pid -or $childReceipt.pid -ne $rootReceipt.childPid) { throw 'Missing actual descendant/natural-exit evidence' }
    if ($null -ne (Get-CimInstance Win32_Process -Filter ('ProcessId='+$childReceipt.pid) -OperationTimeoutSec 5)) { throw 'Descendant still alive' }
    if ((Get-FileHash -LiteralPath $canaryFile -Algorithm SHA256).Hash -cne $canaryBefore) { throw 'Mapped canary changed' }
    if (@(Get-ChildItem -LiteralPath $canary).Count -ne 1) { throw 'Unexpected mapped canary file' }
    $report.status = 'VM_DUMMY_OBSERVED_NOT_HOST_CLEANUP_OR_SDK_ACCEPTANCE'
} catch {
    $report.error = $_.Exception.ToString()
} finally {
    if ($null -ne $process) {
        if (-not $process.HasExited) { $report.forcedCleanup=$true; try { $process.Kill(); $process.WaitForExit(5000) | Out-Null } catch { $report.cleanupErrors += $_.Exception.ToString() } }
        foreach ($task in @($stdout,$stderr)) { if ($null -ne $task -and -not $task.Wait(5000)) { $report.cleanupErrors += 'Stdio drain deadline exceeded' } }
        if ($null -ne $stdout -and $stdout.IsCompleted -and -not $stdout.IsFaulted) { [IO.File]::WriteAllText((Join-Path $runtime 'root-stdout.txt'),$stdout.Result) }
        if ($null -ne $stderr -and $stderr.IsCompleted -and -not $stderr.IsFaulted) { [IO.File]::WriteAllText((Join-Path $runtime 'root-stderr.txt'),$stderr.Result) }
        $process.Dispose()
    }
    foreach ($name in @('guest-dummy.ps1','dummy.mjs')) {
        if ((Get-FileHash -LiteralPath (Join-Path $inputRoot $name) -Algorithm SHA256).Hash.ToLowerInvariant() -cne $config.sourceHashes.$name) { $report.cleanupErrors += 'Input source drift' }
    }
    if ($report.forcedCleanup -or $report.cleanupErrors.Count -gt 0) { $report.status='FAIL' }
    Copy-Item -LiteralPath $runtime -Destination (Join-Path $outputRoot 'runtime') -Recurse
    [IO.File]::WriteAllText((Join-Path $outputRoot 'report.json'),($report | ConvertTo-Json -Depth 16))
}
if ($report.status -eq 'FAIL') { exit 2 }
# Host actor/VM shutdown and cleanup are separate mandatory gates, not PASS here.
exit 0
