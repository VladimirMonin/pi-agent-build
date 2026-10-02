[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Config,
    [Parameter(Mandatory=$true)][string]$NodeExecutable,
    [Parameter(Mandatory=$true)][ValidatePattern('^[a-fA-F0-9]{64}$')][string]$NodeSha256,
    [Parameter(Mandatory=$true)][string]$SourceManifest,
    [string]$RepoRoot=(Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent),
    [ValidateRange(5000,300000)][int]$TimeoutMs=45000,
    [ValidateSet('Detached')][string]$ConsoleMode='Detached'
)
Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath($RepoRoot)
. (Join-Path $repo 'scripts/common.ps1')
# This CLI only runs the harmless Node dummy. Pi/SDK entrypoints are deliberately absent.
$result=[ordered]@{status='NOT_LAUNCHED';mode='dummy';native=$null;error=$null;dummyReceipts=@();sourceBefore=@();sourceAfter=@();sourceUnchanged=$false;rootAclUnchanged=$false;canaryUnchanged=$false;limitations=@('Not AppContainer/network/read-secret/full-global syscall containment.','Node dummy only: no Pi/SDK/provider compatibility claim.','Job notifications do not constitute a lossless global process audit.','Compiler/native token and USER-object setup are separate from read-only PLAN.')}
$run=$null;$lab=$null;$rootAclBefore=$null
try{
    $plan=& (Join-Path $repo 'scripts/lab-stand.ps1') -Config $Config
    $ok=$?
    if(-not $ok -or ($plan|Out-String)-notmatch 'PLAN_PREPARED_PASS'){throw 'Verified fresh prepared PLAN required before native attempt'}
    $c=Read-JsonFile $Config
    $lab=Assert-PrivateLabRoot -LabRoot $c.labRoot -RepoRoot $repo
    $rootAclBefore=(Get-Acl -LiteralPath $lab).Sddl
    $node=Resolve-FullPath $NodeExecutable
    if(-not (Test-Path -LiteralPath $node -PathType Leaf)){throw 'Explicit Node executable missing'}
    $cursor=$node
    while($cursor){
        if((Get-Item -LiteralPath $cursor -Force).Attributes-band [IO.FileAttributes]::ReparsePoint){throw 'Node reparse ancestor refused'}
        $parent=[IO.Directory]::GetParent($cursor);if(-not $parent){break};$cursor=$parent.FullName
    }
    if((Get-FileHash -LiteralPath $node -Algorithm SHA256).Hash-ine $NodeSha256){throw 'Explicit Node fingerprint refused'}
    $expected=Read-JsonFile $SourceManifest
    $names=@('run.ps1','NativeBoundary.cs','dummy.mjs')
    if(@($expected.PSObject.Properties).Count-ne 3){throw 'Exact three-source manifest required'}
    foreach($name in $names){
        $p=Join-Path $PSScriptRoot $name
        $property=$expected.PSObject.Properties[$name]
        if($null-eq $property-or $property.Value-isnot [string]-or $property.Value-notmatch '^[a-fA-F0-9]{64}$'){throw 'Source manifest shape refused'}
        if((Get-Item -LiteralPath $p -Force).Attributes-band [IO.FileAttributes]::ReparsePoint){throw 'Source reparse refused'}
        $hash=(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash
        if($hash-ine $property.Value){throw 'Frozen source fingerprint refused'}
        $result.sourceBefore+=@{file=$name;sha256=$hash}
    }
    $run=Join-Path (Join-Path $lab 'evidence') ('native-'+[guid]::NewGuid().ToString('N'))
    $runtime=Join-Path $run 'runtime';$canary=Join-Path $run 'protected-canary';$compileTemp=Join-Path $run 'compile-temp'
    foreach($p in @($run,$runtime,$canary,$compileTemp)){[IO.Directory]::CreateDirectory($p)|Out-Null}
    $result.run=$run;$result.runtime=$runtime;$result.executable=$node;$result.nodeSha256=$NodeSha256;$result.consoleMode=$ConsoleMode;$result.timeoutMs=$TimeoutMs
    $map=Get-LabChildEnvironment -LabRoot $runtime -NpmPrefix (Join-Path $runtime 'npm-prefix') -ProfileName agent
    $map['PATH']="$(Split-Path $node -Parent);$env:SystemRoot\System32;$env:SystemRoot"
    $map['PROGRAMDATA']=Join-Path $runtime 'programdata'
    $map['BOUNDARY_RUNTIME']=$runtime;$map['BOUNDARY_CANARY']=$canary
    foreach($key in $map.Keys){
        $value=[string]$map[$key]
        if($value.StartsWith($runtime+'\',[StringComparison]::OrdinalIgnoreCase)){
            $dir=if($key-in @('npm_config_userconfig','npm_config_globalconfig','PI_GOAL_GLOBAL_SETTINGS_FILE')){Split-Path $value -Parent}else{$value}
            [IO.Directory]::CreateDirectory($dir)|Out-Null
        }
    }
    $environment=Get-SanitizedChildEnvironment -Overrides $map
    $result.environment=$environment
    $dict=New-Object 'System.Collections.Generic.Dictionary[string,string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach($key in $environment.Keys){$dict.Add([string]$key,[string]$environment[$key])}
    $canaryFile=Join-Path $canary 'working-memory-shaped.txt'
    [IO.File]::WriteAllText($canaryFile,"LAB DUMMY ONLY - unchanged`r`n")
    $before=(Get-FileHash -LiteralPath $canaryFile).Hash;$beforeTime=(Get-Item -LiteralPath $canaryFile).LastWriteTimeUtc.Ticks
    $bytes=[guid]::NewGuid().ToByteArray()
    $sid='S-1-5-21-'+([BitConverter]::ToUInt32($bytes,0))+'-'+([BitConverter]::ToUInt32($bytes,4))+'-'+([BitConverter]::ToUInt32($bytes,8))+'-1001'
    $compileEnv=@{};foreach($key in $environment.Keys){$compileEnv[$key]=$environment[$key]};$compileEnv['TEMP']=$compileTemp;$compileEnv['TMP']=$compileTemp
    $nativeSource=Join-Path $PSScriptRoot 'NativeBoundary.cs'
    Invoke-WithChildEnvironment -Sanitize -Environment $compileEnv -ScriptBlock {Add-Type -Path $nativeSource}
    $entry=Join-Path $PSScriptRoot 'dummy.mjs'
    $native=[NativeBoundary]::Run($node,[string[]]@($entry),$runtime,$canary,$sid,$dict,$TimeoutMs,$true,$ConsoleMode,'',$PSCommandPath)
    $result.native=$native
    $result.canaryUnchanged=((Get-FileHash -LiteralPath $canaryFile).Hash-eq $before -and (Get-Item -LiteralPath $canaryFile).LastWriteTimeUtc.Ticks-eq $beforeTime -and @(Get-ChildItem -LiteralPath $canary).Count-eq 1)
    if($native.Status-ne 'NATIVE_RUN_COMPLETE'-or $native.ForcedCleanup-or -not $native.JobEmpty-or -not $result.canaryUnchanged){throw 'Native fixture or cleanup gate refused'}
    foreach($role in @('root','descendant')){
        $receipt=Read-JsonFile (Join-Path $runtime ($role+'-receipt.json'))
        $result.dummyReceipts+=@($receipt)
        $identity=@($native.Processes|Where-Object Pid -eq $receipt.pid)
        if($identity.Count-ne 1-or -not $receipt.naturalExit-or $receipt.PSObject.Properties['failure']-or $identity[0].ExitCode-ne 0-or
            -not $receipt.execPath.Equals($node,[StringComparison]::OrdinalIgnoreCase)-or -not $receipt.modulePath.Equals($entry,[StringComparison]::OrdinalIgnoreCase)-or -not $receipt.cwd.Equals($runtime,[StringComparison]::OrdinalIgnoreCase)){throw 'Dummy identity/natural exit refused'}
        if($receipt.attempts.Count-ne 4-or @($receipt.attempts|Where-Object {$_.allowed-ne $_.expectedAllowed}).Count){throw 'Canary outcome mismatch'}
        foreach($attempt in @($receipt.attempts|Where-Object {-not $_.expectedAllowed})){if($attempt.error.code-notin @('EACCES','EPERM')){throw 'Non-denial failure is not access proof'}}
        $actual=@{};foreach($p in $receipt.environment.PSObject.Properties){$actual[$p.Name]=[string]$p.Value}
        if($actual.Count-ne $environment.Count){throw 'Dummy environment count mismatch'}
        foreach($key in $environment.Keys){if($actual[$key]-cne [string]$environment[$key]){throw 'Dummy environment value mismatch'}}
    }
    if($result.dummyReceipts[0].childPid-ne $result.dummyReceipts[1].pid-or $result.dummyReceipts[1].ppid-ne $native.RootPid){throw 'Actual PID relationship refused'}
    foreach($role in @('root','descendant')){if(Test-Path -LiteralPath (Join-Path $run ($role+'-control-must-not-exist.txt'))){throw 'Control tree write escaped runtime'}}
    $result.status='PASS_DUMMY_BOUNDARY_NOT_SDK'
}catch{$result.status='FAIL';$result.error=$_.Exception.ToString()}
finally{
    if($rootAclBefore){$result.rootAclUnchanged=$rootAclBefore-ceq (Get-Acl -LiteralPath $lab).Sddl;if(-not $result.rootAclUnchanged){$result.status='FAIL';$result.error+='; owner root ACL changed'}}
    foreach($name in @('run.ps1','NativeBoundary.cs','dummy.mjs')){
        $p=Join-Path $PSScriptRoot $name
        if(Test-Path -LiteralPath $p -PathType Leaf){$result.sourceAfter+=@{file=$name;sha256=(Get-FileHash -LiteralPath $p).Hash}}
    }
    $result.sourceUnchanged=($result.sourceBefore.Count-eq 3-and ($result.sourceBefore|ConvertTo-Json -Compress)-ceq ($result.sourceAfter|ConvertTo-Json -Compress))
    if(-not $result.sourceUnchanged){$result.status='FAIL';$result.error+='; source preservation not established'}
    if($run-and (Test-Path -LiteralPath $run)){$result|ConvertTo-Json -Depth 20|Set-Content -LiteralPath (Join-Path $run 'report.json') -Encoding UTF8}
}
Write-Output $result.status
if($result.status-eq 'PASS_DUMMY_BOUNDARY_NOT_SDK'){exit 0}
exit 2
