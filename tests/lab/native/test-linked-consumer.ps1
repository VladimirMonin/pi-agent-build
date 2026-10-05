[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$FixtureRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=$PSScriptRoot
$repo=Split-Path (Split-Path (Split-Path $root -Parent) -Parent) -Parent
. (Join-Path $repo 'scripts/common.ps1')
$parent=Assert-PrivateLabRoot -LabRoot $FixtureRoot -RepoRoot $repo
$out=Join-Path $parent ('managed-linked-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($out)|Out-Null
$map=Get-LabChildEnvironment -LabRoot $out -NpmPrefix (Join-Path $out 'npm-prefix')
foreach($dir in @('temp','home','appdata','localappdata')){[IO.Directory]::CreateDirectory((Join-Path $out $dir))|Out-Null}
Invoke-WithChildEnvironment -Sanitize -Environment $map -ScriptBlock {
$source=[IO.File]::ReadAllText((Join-Path $root 'NativeBoundary.cs'))
Add-Type -TypeDefinition $source -OutputAssembly (Join-Path $out 'compile-only-v4.dll')
$stub=@'
    public static int TestLastError,TestLinkedError,TestStatsError,TestCloseError,TestFreed;
    public static uint TestLinkedLength=(uint)IntPtr.Size,TestStatsLength=56,TestElevationType=2;
    public static bool TestLinkedSuccess=true,TestStatsSuccess=true,TestCloseSuccess=true,TestElevationSuccess=true;
    public static int TestElevationError=5;
    public static long TestHandle=0x1122334455667788L,TestTokenId=123,TestAuthId=456,TestModifiedId=789;
    public static List<string> TestCalls=new List<string>();
    public static List<long> TestClosed=new List<long>();
    public static int StatisticsSize() {return Marshal.SizeOf(typeof(TOKEN_STATISTICS));}
    public static void ResetTest() {
        TestLastError=0;TestLinkedError=0;TestStatsError=0;TestCloseError=0;TestFreed=0;
        TestLinkedLength=(uint)IntPtr.Size;TestStatsLength=56;TestElevationType=2;
        TestLinkedSuccess=true;TestStatsSuccess=true;TestCloseSuccess=true;TestElevationSuccess=true;TestElevationError=5;
        TestHandle=0x1122334455667788L;TestTokenId=123;TestAuthId=456;TestModifiedId=789;
        TestCalls.Clear();TestClosed.Clear();
    }
    static bool GetTokenInformation(IntPtr t,int cls,IntPtr p,uint size,out uint needed) {
        TestCalls.Add(cls+"|"+t.ToInt64()+"|"+size);
        if(cls==18) {
            needed=4;
            if(p==IntPtr.Zero){TestLastError=122;return false;}
            if(size!=4)throw new InvalidOperationException("ElevationType capacity wrong");
            TestLastError=TestElevationSuccess?0:TestElevationError;
            if(TestElevationSuccess)Marshal.WriteInt32(p,unchecked((int)TestElevationType));
            return TestElevationSuccess;
        }
        if(p==IntPtr.Zero)throw new InvalidOperationException("Zero-sized linked query forbidden in consumer test");
        if(cls==19) {
            needed=TestLinkedLength;TestLastError=TestLinkedError;
            if(size!=(uint)IntPtr.Size)throw new InvalidOperationException("Linked HANDLE capacity wrong");
            if(TestLinkedSuccess)Marshal.WriteIntPtr(p,new IntPtr(TestHandle));
            return TestLinkedSuccess;
        }
        if(cls==10) {
            needed=TestStatsLength;TestLastError=TestStatsError;
            if(t.ToInt64()!=TestHandle||size!=56)throw new InvalidOperationException("Owned linked-token statistics query wrong");
            if(TestStatsSuccess) {
                for(int i=0;i<56;i++)Marshal.WriteByte(p,i,0);
                Marshal.WriteInt64(p,0,TestTokenId);Marshal.WriteInt64(p,8,TestAuthId);Marshal.WriteInt64(p,48,TestModifiedId);
            }
            return TestStatsSuccess;
        }
        throw new InvalidOperationException("Unrelated token class in bounded managed test");
    }
    static bool CloseHandle(IntPtr h) {TestClosed.Add(h.ToInt64());TestLastError=TestCloseError;return TestCloseSuccess;}
    static bool IsTokenRestricted(IntPtr h) {return true;}
    static void TestFree(IntPtr p) {TestFreed++;Marshal.FreeHGlobal(p);}
'@
$source=$source.Replace('public static class NativeBoundary {',("public static class LinkedConsumerContract {`n"+$stub))
$source=[regex]::Replace($source,'\[DllImport\([^\r\n]*\)\]\s*(static extern [^;\r\n]+);',{
    param($m)
    $decl=$m.Groups[1].Value.Replace('static extern ','static ')
    $name=[regex]::Match($decl,'\s(\w+)\(').Groups[1].Value
    if($name -in @('GetTokenInformation','CloseHandle','IsTokenRestricted')){return ''}
    return $decl+' {throw new InvalidOperationException("Native API disabled in linked unit test: '+$name+'");}'
})
$loop=[regex]::Match($source,'foreach\(TokenInfo infoClass in new\[\]\{[^}]+\}\)').Value
if(([regex]::Matches($source,[regex]::Escape($loop))).Count -ne 1){throw 'Actual consumer loop not uniquely located'}
# Execute actual elevation-type/class19 dispatch/helper; unrelated classes not exercised.
$source=$source.Replace($loop,'foreach(TokenInfo infoClass in new[]{TokenInfo.ElevationType,TokenInfo.LinkedToken})')
$source=$source.Replace('Marshal.GetLastWin32Error()','TestLastError').Replace('Marshal.FreeHGlobal(statistics);','TestFree(statistics);').Replace('Marshal.FreeHGlobal(p);','TestFree(p);')
$source=$source.Replace('TestFreed++;TestFree(p);','TestFreed++;Marshal.FreeHGlobal(p);')
if($source.Contains('[DllImport(')){throw 'Native imports remain in managed linked test'}
[IO.File]::WriteAllText((Join-Path $out 'LinkedConsumerContract.cs'),$source)
Add-Type -TypeDefinition $source
$type=[LinkedConsumerContract]
$struct=$type.GetNestedType('TOKEN_STATISTICS',[Reflection.BindingFlags]'NonPublic')
if([LinkedConsumerContract]::StatisticsSize() -ne 56){throw 'TOKEN_STATISTICS layout mismatch'}
$method=$type.GetMethod('UnchangedTokenFields',[Reflection.BindingFlags]'Static,NonPublic')
$receiptType=$type.GetNestedType('TokenDaclCorrection')
$cases=New-Object 'Collections.Generic.List[object]'
function Check-Linked([string]$name,[hashtable]$setup,[string]$expected,[int]$queries,[int]$closes,[int]$frees) {
    [LinkedConsumerContract]::ResetTest()
    foreach($key in $setup.Keys){$type.GetField($key).SetValue($null,$setup[$key])}
    $receipt=[Activator]::CreateInstance($receiptType);$actual='success';$fields=$null
    try {$fields=$method.Invoke($null,@($receipt,[IntPtr]::Zero,'managed-consumer'))}
    catch {
        $e=$_.Exception;while($e.InnerException){$e=$e.InnerException}
        if($e -is [ComponentModel.Win32Exception]){$actual='Win32:'+$e.NativeErrorCode}else{$actual=$e.GetType().Name}
    }
    $calls=@([LinkedConsumerContract]::TestCalls);$closed=@([LinkedConsumerContract]::TestClosed);$freed=[LinkedConsumerContract]::TestFreed
    if($actual -ne $expected -or $calls.Count -ne $queries -or $closed.Count -ne $closes -or $freed -ne $frees){throw "Failed $name actual=$actual queries=$($calls.Count) closes=$($closed.Count) frees=$freed"}
    if($closes -gt 0 -and $closed[0] -ne [LinkedConsumerContract]::TestHandle){throw 'Wrong owned HANDLE closed'}
    $identity=$null
    if($actual -eq 'success') {
        if($fields.Count -ne 3 -or $fields['IsTokenRestricted'] -ne 'True'){throw 'Consumer dispatch corrupted'}
        $identity=$fields['Class19']
    }
    $cases.Add([pscustomobject]@{name=$name;result='PASS';actual=$actual;calls=$calls;closed=$closed;freed=$freed;identity=$identity;apiReceipts=@($receipt.ApiResults)})
    return $identity
}
$a=Check-Linked 'full pointer HANDLE identity and close' @{} 'success' 4 1 3
$b=Check-Linked 'different numeric HANDLE same token object' @{TestHandle=[long]0x2233445566778899} 'success' 4 1 3
if($a -ne $b){throw 'Numeric HANDLE compared rather than semantic token identity'}
$c=Check-Linked 'changed linked token object detected' @{TestTokenId=[long]124} 'success' 4 1 3
if($a -eq $c){throw 'Changed TokenId undetected'}
$d=Check-Linked 'changed linked token security context detected' @{TestModifiedId=[long]790} 'success' 4 1 3
if($a -eq $d){throw 'Changed ModifiedId undetected'}
Check-Linked 'limited elevation also queries linked identity' @{TestElevationType=[uint32]3} 'success' 4 1 3|Out-Null
$none=Check-Linked 'documented default elevation has no linked token' @{TestElevationType=[uint32]1;TestLinkedSuccess=$false;TestLinkedError=1312} 'success' 2 0 1
if($none -ne 'NO_LINKED_TOKEN:TokenElevationTypeDefault' -or $none -eq $a){throw 'Absence/elevation transition comparison wrong'}
foreach($elevation in @(0,4)){Check-Linked "unknown elevation $elevation refused" @{TestElevationType=[uint32]$elevation} 'InvalidOperationException' 2 0 1|Out-Null}
Check-Linked 'failed elevation query remains fatal before linked query' @{TestElevationSuccess=$false} 'Win32:5' 2 0 1|Out-Null
foreach($nativeError in @(5,24,1312)){Check-Linked "linked genuine API error $nativeError remains fatal" @{TestLinkedSuccess=$false;TestLinkedError=$nativeError} "Win32:$nativeError" 3 0 2|Out-Null}
Check-Linked 'zero HANDLE refused' @{TestHandle=[long]0} 'InvalidOperationException' 3 0 2|Out-Null
Check-Linked 'INVALID_HANDLE_VALUE refused' @{TestHandle=[long]-1} 'InvalidOperationException' 3 0 2|Out-Null
Check-Linked 'malformed successful HANDLE length still closes owned handle' @{TestLinkedLength=[uint32]0} 'InvalidOperationException' 3 1 2|Out-Null
Check-Linked 'statistics query failure closes linked handle' @{TestStatsSuccess=$false;TestStatsError=5} 'Win32:5' 4 1 3|Out-Null
foreach($n in @(0,1,64)){Check-Linked "statistics invalid length $n refused" @{TestStatsLength=[uint32]$n} 'InvalidOperationException' 4 1 3|Out-Null}
Check-Linked 'CloseHandle failure remains fatal and buffers freed' @{TestCloseSuccess=$false;TestCloseError=6} 'Win32:6' 4 1 3|Out-Null
$result=[pscustomobject]@{status='MANAGED_CONSUMER_PASS_ONLY';caseCount=$cases.Count;cases=$cases;statisticsSize=56;pointerSize=[IntPtr]::Size;compileOnly=$true;nativeTokenQueries=0;nativeActorLaunches=0;daclSetters=0;scope='Actual UnchangedTokenFields documented class19 branch and helper with managed APIs; consumer loop narrowed to18,19 in test copy only. Native behavior, other classes, no-linked-token handling, functional runner/SDK/global containment not established.'}
$result|ConvertTo-Json -Depth 10|Set-Content -LiteralPath (Join-Path $out 'managed-result.json') -Encoding UTF8
Write-Output "MANAGED_CONSUMER_PASS_ONLY $($cases.Count) cases; no native token/actor/setter calls"
}
