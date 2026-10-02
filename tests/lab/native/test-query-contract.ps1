[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$FixtureRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=$PSScriptRoot
$repo=Split-Path (Split-Path (Split-Path $root -Parent) -Parent) -Parent
. (Join-Path $repo 'scripts/common.ps1')
$parent=Assert-PrivateLabRoot -LabRoot $FixtureRoot -RepoRoot $repo
$out=Join-Path $parent ('managed-query-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($out)|Out-Null
$map=Get-LabChildEnvironment -LabRoot $out -NpmPrefix (Join-Path $out 'npm-prefix')
foreach($dir in @('temp','home','appdata','localappdata')){[IO.Directory]::CreateDirectory((Join-Path $out $dir))|Out-Null}
Invoke-WithChildEnvironment -Sanitize -Environment $map -ScriptBlock {
$current=[IO.File]::ReadAllText((Join-Path $root 'NativeBoundary.cs')).Replace("`r`n","`n")
# Reconstruct the historical null-sizing algorithm only, not a second obsolete native runner.
$fixed='uint size=4;'+"`n"+'        if(cls!=20) {'
if(([regex]::Matches($current,[regex]::Escape($fixed))).Count-ne 1){throw 'Fixed DWORD branch uniquely required'}
$old=$current.Replace($fixed,'uint size; {')
# Compilation only: never invoke NativeBoundary.Run or any unmocked method.
Add-Type -TypeDefinition $current -OutputAssembly (Join-Path $out 'compile-only.dll')
$stub=@'
    public static int TestLastError, TestSizingError=122, TestReadError=0, TestFreed;
    public static uint TestRequired=16, TestReturned=4, TestValue;
    public static bool TestSizingSuccess=false, TestReadSuccess=true;
    public static List<string> TestCalls=new List<string>();
    public static void ResetTest() {
        TestLastError=0;TestSizingError=122;TestReadError=0;TestFreed=0;
        TestRequired=16;TestReturned=4;TestValue=0;
        TestSizingSuccess=false;TestReadSuccess=true;TestCalls.Clear();
    }
    static bool GetTokenInformation(IntPtr t,int cls,IntPtr data,uint size,out uint needed) {
        bool sizing=data==IntPtr.Zero;
        TestCalls.Add(cls+"|"+(sizing?"null":"buffer")+"|"+size);
        needed=sizing?TestRequired:TestReturned;
        TestLastError=sizing?TestSizingError:TestReadError;
        bool success=sizing?TestSizingSuccess:TestReadSuccess;
        if(success&&!sizing){
            if(cls==6&&size>=16){for(int i=0;i<16;i++)Marshal.WriteByte(data,i,0);Marshal.WriteIntPtr(data,IntPtr.Add(data,8));Marshal.WriteByte(data,8,2);Marshal.WriteInt16(data,10,8);}
            else Marshal.WriteInt32(data,unchecked((int)TestValue));
        }
        return success;
    }
    static void TestFree(IntPtr p) {TestFreed++;Marshal.FreeHGlobal(p);}
'@
function Make-Mock([string]$source,[string]$name) {
    $source=$source.Replace('public static class NativeBoundary {',("public static class $name {`n"+$stub))
    $pattern='\[DllImport\([^\r\n]*\)\]\s*(static extern [^;\r\n]+);'
    $source=[regex]::Replace($source,$pattern,{
        param($match)
        $decl=$match.Groups[1].Value.Replace('static extern ','static ')
        $method=[regex]::Match($decl,'\s(\w+)\(').Groups[1].Value
        if($method -eq 'GetTokenInformation'){return ''}
        return $decl+' {throw new InvalidOperationException("Native API disabled in query unit test: '+$method+'");}'
    })
    $source=$source.Replace('Marshal.GetLastWin32Error()','TestLastError')
    $source=$source.Replace('Marshal.FreeHGlobal(p);','TestFree(p);')
    # Avoid replacing TestFree's own heap release with recursive TestFree.
    $source=$source.Replace('TestFreed++;TestFree(p);','TestFreed++;Marshal.FreeHGlobal(p);')
    if($source.Contains('[DllImport(')){throw 'Native imports remain in managed test copy'}
    [IO.File]::WriteAllText((Join-Path $out ($name+'.cs')),$source)
    Add-Type -TypeDefinition $source
}
Make-Mock $current 'NativeBoundaryQueryContract'
Make-Mock $old 'NativeBoundaryOldQueryContract'
$cases=New-Object 'Collections.Generic.List[object]'
function Check-Case([string]$name,[type]$type,[int]$cls,[hashtable]$setup,[string]$expected,[int]$callCount,[int]$freeCount) {
    $type.GetMethod('ResetTest').Invoke($null,@())|Out-Null
    foreach($key in $setup.Keys){$type.GetField($key).SetValue($null,$setup[$key])}
    $receiptType=$type.GetNestedType('TokenDaclCorrection')
    $receipt=[Activator]::CreateInstance($receiptType)
    $method=$type.GetMethod('DaclInfo',[Reflection.BindingFlags]'Static,NonPublic')
    $pointer=[IntPtr]::Zero;$actual='success';$failure=$null;$value=$null
    try {
        try {$pointer=$method.Invoke($null,@($receipt,[IntPtr]::Zero,$cls,'unit-test'));$value=[Runtime.InteropServices.Marshal]::ReadInt32($pointer)}
        catch {
            $failure=$_.Exception
            while($failure.InnerException){$failure=$failure.InnerException}
            if($failure -is [ComponentModel.Win32Exception]){$actual='Win32:'+ $failure.NativeErrorCode}
            else {$actual=$failure.GetType().Name}
        }
        $calls=@($type.GetField('TestCalls').GetValue($null))
        $freed=$type.GetField('TestFreed').GetValue($null)
        if($actual -ne $expected -or $calls.Count -ne $callCount -or $freed -ne $freeCount){throw "Failed $name actual=$actual calls=$($calls.Count) free=$freed"}
        if($cls -eq 20 -and $type -eq [NativeBoundaryQueryContract] -and ($calls.Count -ne 1 -or $calls[0] -ne '20|buffer|4')){throw 'Fixed DWORD call contract broken'}
        $cases.Add([pscustomobject]@{name=$name;result='PASS';actual=$actual;calls=$calls;exceptionBufferFreed=$freed;value=$value;apiReceipts=@($receipt.ApiResults)})
    } finally {if($pointer -ne [IntPtr]::Zero){[Runtime.InteropServices.Marshal]::FreeHGlobal($pointer)}}
}
$new=[NativeBoundaryQueryContract];$before=[NativeBoundaryOldQueryContract]
Check-Case 'old helper rejects ERROR_BAD_LENGTH sizing' $before 20 @{TestSizingError=24;TestRequired=[uint32]4} 'Win32:24' 1 0
Check-Case 'fixed DWORD zero' $new 20 @{} 'success' 1 0
Check-Case 'fixed DWORD elevated' $new 20 @{TestValue=[uint32]1} 'success' 1 0
Check-Case 'fixed DWORD nonzero' $new 20 @{TestValue=[uint32]4294967295} 'success' 1 0
Check-Case 'real ERROR_BAD_LENGTH remains failure' $new 20 @{TestReadSuccess=$false;TestReadError=24} 'Win32:24' 1 1
Check-Case 'access denied remains failure' $new 20 @{TestReadSuccess=$false;TestReadError=5} 'Win32:5' 1 1
Check-Case 'insufficient buffer remains failure' $new 20 @{TestReadSuccess=$false;TestReadError=122} 'Win32:122' 1 1
foreach($n in @(0,1,8)){Check-Case "success invalid length $n refused" $new 20 @{TestReturned=[uint32]$n} 'InvalidOperationException' 1 1}
Check-Case 'variable class6 unchanged sizing+read' $new 6 @{TestReturned=[uint32]16} 'success' 2 0
Check-Case 'variable class6 BAD_LENGTH not accepted' $new 6 @{TestSizingError=24} 'Win32:24' 1 0
Check-Case 'variable zero required length refused' $new 6 @{TestRequired=[uint32]0} 'Win32:122' 1 0
Check-Case 'variable unexpected sizing success refused' $new 6 @{TestSizingSuccess=$true} 'Win32:0' 1 0
Check-Case 'variable read failure frees buffer' $new 6 @{TestReadSuccess=$false;TestReadError=5} 'Win32:5' 2 1
$result=[pscustomobject]@{status='MANAGED_CONTRACT_PASS_ONLY';caseCount=$cases.Count;cases=$cases;compileOnly=$true;nativeTokenQueries=0;nativeActorLaunches=0;daclSetters=0;liveRunnerStatus='BLOCKED_UNTESTED_CORRECTION';scope='Documented fixed DWORD class20 branch and unchanged fail-closed variable-query behavior; all native API declarations replaced with throwing stubs in unit copies. No actual Windows token/actor validation.'}
$result|ConvertTo-Json -Depth 10|Set-Content -LiteralPath (Join-Path $out 'managed-result.json') -Encoding UTF8
Write-Output "MANAGED_CONTRACT_PASS_ONLY $($cases.Count) cases; native token/actors/setter calls0"
}
